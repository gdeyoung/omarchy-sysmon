import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SysMon bar widget (gdeyoung.sysmon) — forked from vm.sysmem by jhonoryza (MIT).
//
// Four stat groups:  M = RAM   C = CPU   N = net rate   D = /home volume
// The probe (sysmon.sh) emits cumulative counters; this widget computes CPU% and
// net rates from deltas between ticks. Values turn amber above 70%, red above 90%.
// The N group has no natural percent — its bar is a log-scale activity meter
// (0 B/s = 0%, 1 Gbit/s = 100%).
//
// The probe also carries detail fields (per-core jiffies, load, swap, temps,
// GPU load/VRAM/GTT/power, disk IO, per-interface counters). apply() folds them
// into ring buffers (histMax samples) whether or not a detail view is open, so
// the panel opens with warm history. GPU data is popup-only: the bar renders
// nothing for it.
BarWidget {
  id: root
  moduleName: "gdeyoung.sysmon"

  // ---- History ring buffers ({t, v} arrays, appended every probe tick) -----
  readonly property int histMax: 180

  property var histCpu: []
  property var histRam: []
  property var histNetDown: []
  property var histNetUp: []
  property var histGpuBusy: []
  property var histVram: []
  property var histGtt: []
  property var histDiskR: []
  property var histDiskW: []
  property var histCoreAvg: []      // mean of per-core % (kept for status)
  property var histCoreMax: []      // busiest core % — violet overlay line

  function pushHist(arr, t, v) {
    // Return a NEW array each tick: property var change notification only
    // fires on reassignment of a different reference — in-place mutation
    // leaves bound charts frozen.
    const out = arr.length >= histMax ? arr.slice(1) : arr.slice()
    out.push({ t: t, v: v })
    return out
  }

  // ---- Latest probe values ------------------------------------------------
  property real ramUsedMb: 0
  property real ramTotalMb: 1
  property real cpuPct: -1
  property real netDownBps: -1
  property real netUpBps: -1
  property real diskUsedB: 0
  property real diskTotalB: 1

  // Detail values (panel-facing; the bar shows none of these)
  property real buffersKb: 0
  property real cachedKb: 0
  property real swapTotalKb: 0
  property real swapUsedKb: 0
  property real load1: 0
  property real load5: 0
  property real load15: 0
  property real cpuTempC: -1
  property real gpuTempC: -1
  property real nvmeTempC: -1
  property real gpuBusyPct: -1
  property real vramUsedB: -1
  property real vramTotalB: -1
  property real gttUsedB: -1
  property real gttTotalB: -1
  property real gpuPowerMw: -1
  property real diskReadBps: -1
  property real diskWriteBps: -1
  property real diskReadIops: -1
  property real diskWriteIops: -1
  property var corePcts: []
  property var ifRates: ({})
  property var vols: []              // [{mnt, usedB, sizeB, pct}, ...] from probe vols

  // ---- Processes (popup only) ----------------------------------------------
  property var procs: []            // [[pid,user,comm,pcpu,pmem,state],...]
  property string procSort: "cpu"
  property int killTarget: 0
  readonly property var killRow: {
    for (let i = 0; i < procs.length; i++)
      if (procs[i][0] === killTarget) return procs[i]
    return null
  }
  readonly property string killName: killRow ? killRow[2] : ""
  readonly property bool killAlive: killRow !== null

  readonly property var sortedProcs: {
    const col = procSort === "mem" ? 4 : 3
    const arr = procs.slice()
    arr.sort((a, b) => Number(b[col]) - Number(a[col]))
    return arr
  }

  function doKill(pid, sig) {
    Quickshell.execDetached(["kill", "-" + sig, String(pid)])
    killTarget = 0
    Qt.callLater(refreshProcs)
  }

  function refreshProcs() {
    if (!procProbe.running) procProbe.running = true
  }

  function applyProcs(line) {
    let data
    try {
      data = JSON.parse(String(line).trim())
    } catch (e) {
      return
    }
    if (data && data.procs) procs = data.procs
  }

  function applyVols(data) {
    const v = data.vols || []
    const out = []
    for (let i = 0; i < v.length; i++) {
      const used = Number(v[i][1]) || 0
      const size = Number(v[i][2]) || 1
      out.push({ mnt: v[i][0], usedB: used, sizeB: size, pct: size > 0 ? (used / size) * 100 : 0 })
    }
    vols = out
  }

  // Previous counters for delta math
  property real prevCpuTotal: -1
  property real prevCpuIdle: -1
  property real prevNetRx: -1
  property real prevNetTx: -1
  property real prevStampMs: 0
  property var prevCores: []
  property var prevIf: ({})
  property real prevDiskRsec: -1
  property real prevDiskWsec: -1
  property real prevDiskReads: -1
  property real prevDiskWrites: -1

  readonly property int refreshSeconds: Math.max(1, Math.min(10, Number(setting("refreshSeconds", 2)) || 2))
  // "compact" = letter + 5px level bar only (numbers live in the hover tooltip
  // and the detail popup); "values" = the original full readouts.
  readonly property bool compactMode: setting("barMode", "compact") !== "values"
  readonly property real ramPct: ramTotalMb > 0 ? (ramUsedMb / ramTotalMb) * 100 : 0
  readonly property real diskPct: diskTotalB > 0 ? (diskUsedB / diskTotalB) * 100 : 0
  readonly property real netActPct: netDownBps < 0 ? 0 :
      100 * Math.log(1 + netDownBps + netUpBps) / Math.log(1 + 125000000)

  function fmtGb(mb) { return (mb / 1024).toFixed(1) + "G" }
  function fmtGbB(kb) { return (kb / 1048576).toFixed(1) + "G" }
  function fmtDisk(b) { return Math.round(b / 1073741824) + "G" }
  function fmtRate(bps) {
    if (bps < 0) return "0K"
    if (bps < 1000000) return Math.round(bps / 1000) + "K"
    if (bps < 1000000000) return (bps / 1000000).toFixed(1) + "M"
    return (bps / 1000000000).toFixed(1) + "G"
  }

  readonly property string ramText: fmtGb(ramUsedMb) + "/" + fmtGb(ramTotalMb)
  readonly property string cpuText: cpuPct < 0 ? "--%" : Math.round(cpuPct) + "%"
  readonly property string netText: netDownBps < 0 ? "↓--↑--" : "↓" + fmtRate(netDownBps) + "↑" + fmtRate(netUpBps)
  readonly property string diskText: fmtDisk(diskUsedB) + "/" + fmtDisk(diskTotalB)

  readonly property string tooltip:
      "RAM  " + ramText + " (" + Math.round(ramPct) + "%)"
    + "\nCPU  " + (cpuPct < 0 ? "--" : Math.round(cpuPct)) + "%"
    + "\nNet  ↓" + (netDownBps < 0 ? "--" : fmtRate(netDownBps)) + "  ↑" + (netUpBps < 0 ? "--" : fmtRate(netUpBps))
    + "\nDisk " + diskText + " (" + Math.round(diskPct) + "%)"

  // Fixed widths measured from the widest string per column so the bar never shifts.
  Text {
    id: measureValue
    visible: false
    text: "99.9/99.9G"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
  Text {
    id: measureCpu
    visible: false
    text: "100%"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
  Text {
    id: measureNet
    visible: false
    text: "↓888M↑888M"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
  Text {
    id: measureDisk
    visible: false
    text: "999G/9999G"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
  Text {
    id: measureIcon
    visible: false
    text: "M"
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  readonly property real iconW: measureIcon.implicitWidth
  readonly property real wMV: measureValue.implicitWidth
  readonly property real wC: measureCpu.implicitWidth
  readonly property real wN: measureNet.implicitWidth
  readonly property real wD: measureDisk.implicitWidth

  function levelColor(pct) {
    if (pct >= 90) return "#f7768e"
    if (pct >= 70) return "#e5c07b"
    return "#3fb950"
  }

  function apply(line) {
    let data
    try {
      data = JSON.parse(String(line).trim())
    } catch (e) {
      return
    }
    if (!data) return

    root.ramUsedMb = Number(data.ram_used_mb) || 0
    root.ramTotalMb = Number(data.ram_total_mb) || 1
    root.diskUsedB = Number(data.disk_used_b) || 0
    root.diskTotalB = Number(data.disk_total_b) || 1
    root.applyVols(data)
    root.buffersKb = Number(data.mem_buffers_kb) || 0
    root.cachedKb = Number(data.mem_cached_kb) || 0
    root.swapTotalKb = Number(data.swap_total_kb) || 0
    root.swapUsedKb = Number(data.swap_used_kb) || 0
    root.load1 = Number(data.load1) || 0
    root.load5 = Number(data.load5) || 0
    root.load15 = Number(data.load15) || 0
    root.cpuTempC = data.cpu_temp_mc >= 0 ? data.cpu_temp_mc / 1000 : -1
    root.gpuTempC = data.gpu_temp_mc >= 0 ? data.gpu_temp_mc / 1000 : -1
    root.nvmeTempC = data.nvme_temp_mc >= 0 ? data.nvme_temp_mc / 1000 : -1
    root.gpuBusyPct = Number(data.gpu_busy_pct)
    root.vramUsedB = Number(data.vram_used_b)
    root.vramTotalB = Number(data.vram_total_b)
    root.gttUsedB = Number(data.gtt_used_b)
    root.gttTotalB = Number(data.gtt_total_b)
    root.gpuPowerMw = Number(data.gpu_power_mw)

    const now = Date.now()
    const dt = (now - root.prevStampMs) / 1000

    const cTotal = Number(data.cpu_total)
    const cIdle = Number(data.cpu_idle)
    if (root.prevCpuTotal >= 0 && dt > 0.4) {
      const dTotal = cTotal - root.prevCpuTotal
      const dIdle = cIdle - root.prevCpuIdle
      if (dTotal > 0 && dIdle >= 0)
        root.cpuPct = Math.max(0, Math.min(100, 100 * (1 - dIdle / dTotal)))
    }
    root.prevCpuTotal = cTotal
    root.prevCpuIdle = cIdle

    // Per-core % from the cpu_cores array of [total, idle] jiffy pairs.
    const cores = data.cpu_cores || []
    if (root.prevCores.length === cores.length && cores.length > 0 && dt > 0.4) {
      const pcts = []
      for (let i = 0; i < cores.length; i++) {
        const dT = cores[i][0] - root.prevCores[i][0]
        const dI = cores[i][1] - root.prevCores[i][1]
        pcts.push(dT > 0 ? Math.max(0, Math.min(100, 100 * (1 - dI / dT))) : 0)
      }
      root.corePcts = pcts
    } else if (cores.length > 0) {
      root.corePcts = new Array(cores.length).fill(0)
    }
    root.prevCores = cores

    const rx = Number(data.net_rx)
    const tx = Number(data.net_tx)
    if (root.prevNetRx >= 0 && dt > 0.4) {
      const dRx = rx - root.prevNetRx
      const dTx = tx - root.prevNetTx
      if (dRx >= 0 && dTx >= 0) {
        root.netDownBps = dRx / dt
        root.netUpBps = dTx / dt
      }
    } else if (root.prevNetRx < 0) {
      root.netDownBps = 0
      root.netUpBps = 0
    }
    root.prevNetRx = rx
    root.prevNetTx = tx

    // Per-interface rates for the panel.
    const ifc = data.net_if || {}
    const rates = {}
    for (const name in ifc) {
      const cur = ifc[name]
      const prev = root.prevIf[name]
      if (prev && dt > 0.4) {
        const d0 = cur[0] - prev[0]
        const d1 = cur[1] - prev[1]
        rates[name] = [d0 >= 0 ? d0 / dt : 0, d1 >= 0 ? d1 / dt : 0]
      } else {
        rates[name] = [0, 0]
      }
    }
    root.ifRates = rates
    root.prevIf = ifc

    // Disk IO rates from cumulative diskstats counters.
    const rsec = Number(data.disk_rsec) || 0
    const wsec = Number(data.disk_wsec) || 0
    const reads = Number(data.disk_reads) || 0
    const writes = Number(data.disk_writes) || 0
    if (root.prevDiskRsec >= 0 && dt > 0.4) {
      const dR = rsec - root.prevDiskRsec
      const dW = wsec - root.prevDiskWsec
      root.diskReadBps = dR >= 0 ? (dR * 512) / dt : 0
      root.diskWriteBps = dW >= 0 ? (dW * 512) / dt : 0
      root.diskReadIops = Math.max(0, (reads - root.prevDiskReads) / dt)
      root.diskWriteIops = Math.max(0, (writes - root.prevDiskWrites) / dt)
    }
    root.prevDiskRsec = rsec
    root.prevDiskWsec = wsec
    root.prevDiskReads = reads
    root.prevDiskWrites = writes
    root.prevStampMs = now

    // ---- History append (always, so the panel opens warm) -----------------
    if (root.cpuPct >= 0) root.histCpu = pushHist(root.histCpu, now, root.cpuPct)
    if (root.corePcts.length > 0) {
      let sum = 0, mx = 0
      for (let i = 0; i < root.corePcts.length; i++) {
        sum += root.corePcts[i]
        if (root.corePcts[i] > mx) mx = root.corePcts[i]
      }
      root.histCoreAvg = pushHist(root.histCoreAvg, now, sum / root.corePcts.length)
      root.histCoreMax = pushHist(root.histCoreMax, now, mx)
    }
    root.histRam = pushHist(root.histRam, now, root.ramPct)
    if (root.netDownBps >= 0) {
      root.histNetDown = pushHist(root.histNetDown, now, root.netDownBps)
      root.histNetUp = pushHist(root.histNetUp, now, root.netUpBps)
    }
    if (root.gpuBusyPct >= 0) root.histGpuBusy = pushHist(root.histGpuBusy, now, root.gpuBusyPct)
    if (root.vramUsedB >= 0 && root.vramTotalB > 0)
      root.histVram = pushHist(root.histVram, now, (root.vramUsedB / root.vramTotalB) * 100)
    if (root.gttUsedB >= 0 && root.gttTotalB > 0)
      root.histGtt = pushHist(root.histGtt, now, (root.gttUsedB / root.gttTotalB) * 100)
    if (root.diskReadBps >= 0) {
      root.histDiskR = pushHist(root.histDiskR, now, root.diskReadBps)
      root.histDiskW = pushHist(root.histDiskW, now, root.diskWriteBps)
    }
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  visible: true
  implicitWidth: root.vertical ? Style.bar.statusSlot
    : (root.compactMode ? (compactRow.implicitWidth + 12) : (row.implicitWidth + 16))
  implicitHeight: root.vertical ? (col.implicitHeight + 12) : root.barSize

  // ---- Detail popup state --------------------------------------------------
  property bool popupOpen: false

  IpcHandler {
    target: "gdeyoung.sysmon"

    function refresh(): void {
      root.broadcast("refresh")
    }

    function open(): void { detailPopup.open = true }
    function close(): void { detailPopup.close() }
    function toggle(): void { detailPopup.open ? detailPopup.close() : detailPopup.open = true }
    function tab(name: string): void { detailPopup.tab = name }

    function status(): string {
      return JSON.stringify({
        opened: root.popupOpen,
        tab: detailPopup.tab,
        popupH: detailPopup.height,
        contentH: detailPopup.contentHeight,
        colH: detailPopup.scrollColH,
        hist: {
          cpu: root.histCpu.length,
          ram: root.histRam.length,
          netDown: root.histNetDown.length,
          gpuBusy: root.histGpuBusy.length,
          vram: root.histVram.length,
          gtt: root.histGtt.length,
          diskR: root.histDiskR.length
        },
        last: {
          cpuPct: Math.round(root.cpuPct),
          ramPct: Math.round(root.ramPct),
          netDownBps: Math.round(root.netDownBps),
          gpuBusyPct: root.gpuBusyPct,
          gpuPowerMw: root.gpuPowerMw,
          cpuTempC: root.cpuTempC,
          cores: root.corePcts.length,
          ifaces: Object.keys(root.ifRates),
          procs: root.procs.length,
          vols: root.vols.map(v => v.mnt + " " + Math.round(v.pct) + "%")
        }
      })
    }
  }

  Process {
    id: probe
    command: ["/bin/bash", Qt.resolvedUrl("sysmon.sh").toString().replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Process {
    id: procProbe
    command: ["/bin/bash", Qt.resolvedUrl("procprobe.sh").toString().replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProcs(text)
    }
  }

  Timer {
    // Process table refresh: only while the popup is open.
    interval: 2000
    running: popupOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshProcs()
  }

  Timer {
    // 1s while the popup is open (smooth charts), refreshSeconds otherwise.
    interval: (popupOpen ? 1000 : refreshSeconds * 1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  component StatGroup: Row {
    property string icon
    property string value
    property real pct: 0
    property real iconWidth: 0
    property real valueWidth: 0
    property color barColor: "#3fb950"
    property real textWidth: iconWidth + 4 + valueWidth
    width: 5 + 4 + textWidth
    spacing: 4
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      width: 5
      height: 16
      radius: 2
      color: "#2c313a"
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height * Math.max(0, Math.min(100, pct)) / 100
        radius: 2
        color: barColor
      }
    }

    Row {
      width: textWidth
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: iconWidth
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: icon
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: valueWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: value
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Compact mode: letter + level bar only. Fixed width per group (iconW + 4 +
  // 5 + spacing) so the bar never shifts between ticks; values live in the
  // hover tooltip and the detail popup.
  Row {
    id: compactRow
    visible: !root.vertical && root.compactMode
    anchors.centerIn: parent
    spacing: 8

    component CompactGroup: Row {
      id: grp
      property string icon
      property real pct: 0
      property color barColor: "#3fb950"
      width: iconW + 4 + 5
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: root.iconW
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: grp.icon
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 5
        height: 16
        radius: 2
        color: "#2c313a"
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width
          height: parent.height * Math.max(0, Math.min(100, grp.pct)) / 100
          radius: 2
          color: grp.barColor
        }
      }
    }

    CompactGroup {
      icon: "M"
      pct: root.ramPct
      barColor: root.levelColor(root.ramPct)
    }
    CompactGroup {
      icon: "C"
      pct: root.cpuPct
      barColor: root.levelColor(root.cpuPct)
    }
    CompactGroup {
      icon: "N"
      pct: root.netActPct
      barColor: "#7aa2f7"
    }
    CompactGroup {
      icon: "D"
      pct: root.diskPct
      barColor: root.levelColor(root.diskPct)
    }
  }

  Row {
    id: row
    visible: !root.vertical && !root.compactMode
    anchors.centerIn: parent
    spacing: 8

    StatGroup {
      icon: "M"
      value: root.ramText
      pct: root.ramPct
      iconWidth: root.iconW
      valueWidth: root.wMV
      barColor: root.levelColor(root.ramPct)
    }
    StatGroup {
      icon: "C"
      value: root.cpuText
      pct: root.cpuPct
      iconWidth: root.iconW
      valueWidth: root.wC
      barColor: root.levelColor(root.cpuPct)
    }
    StatGroup {
      icon: "N"
      value: root.netText
      pct: root.netActPct
      iconWidth: root.iconW
      valueWidth: root.wN
      barColor: "#7aa2f7"
    }
    StatGroup {
      icon: "D"
      value: root.diskText
      pct: root.diskPct
      iconWidth: root.iconW
      valueWidth: root.wD
      barColor: root.levelColor(root.diskPct)
    }
  }

  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 2

    Repeater {
      model: [
        { t: "M " + root.ramText, p: root.ramPct },
        { t: "C " + root.cpuText, p: root.cpuPct },
        { t: "N " + root.netText, p: root.netActPct },
        { t: "D " + root.diskText, p: root.diskPct }
      ]

      Row {
        spacing: 6
        Text {
          text: modelData.t
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: Color.foreground
          anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
          width: 30
          height: 3
          radius: 2
          color: root.levelColor(modelData.p)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (detailPopup.open) detailPopup.close()
        else detailPopup.open = true
      } else {
        root.refresh()
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  DetailPopup {
    id: detailPopup
    host: root
  }
}
