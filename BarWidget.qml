import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SysMon bar widget (gdeyoung.sysmon) — forked from vm.sysmem by jhonoryza (MIT).
//
// Five stat groups:  M = RAM   V = GPU VRAM   C = CPU   N = net rate   D = /home volume
// The probe (sysmon.sh) emits cumulative counters; this widget computes CPU% and
// net rates from deltas between ticks. Values turn amber above 70%, red above 90%.
// The N group has no natural percent — its bar is a log-scale activity meter
// (0 B/s = 0%, 1 Gbit/s = 100%).
BarWidget {
  id: root
  moduleName: "gdeyoung.sysmon"

  // Latest probe values
  property real ramUsedMb: 0
  property real ramTotalMb: 1
  property real cpuPct: -1
  property real netDownBps: -1
  property real netUpBps: -1
  property real diskUsedB: 0
  property real diskTotalB: 1

  // Previous counters for delta math
  property real prevCpuTotal: -1
  property real prevCpuIdle: -1
  property real prevNetRx: -1
  property real prevNetTx: -1
  property real prevStampMs: 0

  readonly property int refreshSeconds: Math.max(1, Math.min(10, Number(setting("refreshSeconds", 2)) || 2))
  readonly property real ramPct: ramTotalMb > 0 ? (ramUsedMb / ramTotalMb) * 100 : 0
  readonly property real diskPct: diskTotalB > 0 ? (diskUsedB / diskTotalB) * 100 : 0
  readonly property real netActPct: netDownBps < 0 ? 0 :
      100 * Math.log(1 + netDownBps + netUpBps) / Math.log(1 + 125000000)

  function fmtGb(mb) { return (mb / 1024).toFixed(1) + "G" }
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
    root.prevStampMs = now
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  visible: true
  implicitWidth: root.vertical ? Style.bar.statusSlot : (row.implicitWidth + 16)
  implicitHeight: root.vertical ? (col.implicitHeight + 12) : root.barSize

  IpcHandler {
    target: "gdeyoung.sysmon"

    function refresh(): void {
      root.broadcast("refresh")
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

  Timer {
    interval: root.refreshSeconds * 1000
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

  Row {
    id: row
    visible: !root.vertical
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
    onClicked: root.refresh()
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
