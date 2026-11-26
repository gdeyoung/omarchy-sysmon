import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// ProcsTab — the real process manager.
// The root fix is the probe (full list, not top-N-by-CPU); this tab adds:
// filter, USER/S/RSS columns, sort on every column with a visible arrow,
// ListView scroll that survives the 2s model resets, totals over the filtered
// set, and row selection driving the End-process bar + kill confirm strip.
Item {
  id: tab
  required property var sysmon

  readonly property var sortCol: ({ name: 2, user: 1, pid: 0, cpu: 3, mem: 4, rss: 5 })
  readonly property int fixedW: 444

  // selection lives on the tab and is mirrored to the host (IPC status/tests)
  property int selectedPid: sysmon.procSelectedPid
  onSelectedPidChanged: if (sysmon.procSelectedPid !== selectedPid) sysmon.procSelectedPid = selectedPid

  // the currently selected row's data (or null) — drives the footer action bar
  readonly property var sel: {
    if (!selectedPid) return null
    for (let i = 0; i < view.length; i++)
      if (Number(view[i][0]) === selectedPid) return view[i]
    return null
  }

  // filter is routed through the host so IPC and tests can drive it; the
  // state also survives tab switches.
  readonly property string filter: sysmon.procFilter

  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(tab.fg, 1.5)
  readonly property color cBlue: "#7aa2f7"
  readonly property color cGreen: "#3fd18b"
  readonly property color cAmber: "#e5c07b"
  readonly property color cRed: "#f4405c"

  // Column contract shared by header + ProcRow delegate so they cannot
  // drift. Fixed cols sum 444; NAME gets the remaining ~470 of 928.
  readonly property var procCols: [
    { key: "name",  label: "NAME",  w: -1 },
    { key: "user",  label: "USER",  w: 84 },
    { key: "state", label: "S",     w: 24 },
    { key: "pid",   label: "PID",   w: 60 },
    { key: "cpu",   label: "CPU%",  w: 60 },
    { key: "mem",   label: "MEM%",  w: 60 },
    { key: "rss",   label: "RSS",   w: 68 },
    { key: "hist",  label: "1m",    w: 88 }
  ]

  readonly property var view: {
    const src = sysmon.procs
    const q = filter.trim().toLowerCase()
    let arr = q === "" ? src.slice() : src.filter(r =>
        String(r[2]).toLowerCase().indexOf(q) >= 0 ||
        String(r[1]).toLowerCase().indexOf(q) >= 0 ||
        String(r[0]).indexOf(q) >= 0)
    const ci = sortCol[sysmon.procSort] === undefined ? 3 : sortCol[sysmon.procSort]
    const text = sysmon.procSort === "name" || sysmon.procSort === "user"
    arr.sort((a, b) => {
      const d = text ? String(a[ci]).localeCompare(String(b[ci]))
                     : Number(b[ci]) - Number(a[ci])
      return d !== 0 ? d : Number(a[0]) - Number(b[0])   // tiebreak pid asc
    })
    return arr
  }

  readonly property var totals: {
    let cpu = 0, mem = 0, rss = 0
    for (let i = 0; i < view.length; i++) {
      cpu += Number(view[i][3]) || 0
      mem += Number(view[i][4]) || 0
      rss += Number(view[i][5]) || 0
    }
    return { cpu: cpu, mem: mem, rss: rss }
  }

  function cpuColor(v) { return v >= 60 ? cRed : (v >= 15 ? cAmber : fg) }
  function stateColor(s) { return s === "D" ? cAmber : (s === "Z" ? cRed : muted) }
  function headerArrow(key) {
    if (sysmon.procSort !== key) return ""
    return (key === "name" || key === "user") ? " \u25B4" : " \u25BE"
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ---- toolbar 36: search always visible (finding one process IS the job)
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 36
      spacing: 8

      TextField {
        id: search
        width: 240
        placeholderText: "Filter \u00B7 name, user, pid"
        font.pixelSize: 12
        onTextEdited: tab.sysmon.procFilter = text
        Keys.onEscapePressed: { text = ""; tab.sysmon.procFilter = "" }
      }
      Item {
        width: 22
        height: search.height
        visible: tab.sysmon.procFilter !== ""
        Text {
          anchors.centerIn: parent
          text: "\u2715"
          color: tab.muted
          font.pixelSize: 11
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { search.text = ""; tab.sysmon.procFilter = ""; search.forceActiveFocus() }
        }
      }
      Item { Layout.fillWidth: true }
      Text {
        text: tab.view.length === tab.sysmon.procs.length
              ? "showing " + tab.view.length
              : "showing " + tab.view.length + " / " + tab.sysmon.procs.length
        color: tab.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
      }
    }

    ProcHeader { owner: tab }
    Hair { Layout.fillWidth: true }

    // list (shrinks by 28 while the confirm strip is up — the frame never moves)
    ProcList { owner: tab }

    KillBar {
      Layout.fillWidth: true
      sysmon: tab.sysmon
    }

    // ---- action bar 32: selection drives the kill affordance ---------------
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 2
      Layout.rightMargin: 2
      Layout.preferredHeight: 32
      spacing: 10

      Text {
        Layout.fillWidth: true
        elide: Text.ElideMiddle
        text: tab.sel
              ? tab.sel[2] + "  \u00B7  pid " + tab.sel[0]
                + "  \u00B7  " + tab.sel[1]
                + "  \u00B7  " + tab.sysmon.fmtRss(Number(tab.sel[5]))
              : "click a row to select \u00B7 double-click to kill"
        textFormat: Text.PlainText
        color: tab.sel ? tab.fg : tab.muted
        font.family: Style.font.family
        font.pixelSize: 12
        font.features: ({ "tnum": 1 })
        verticalAlignment: Text.AlignVCenter
      }
      Rectangle {
        visible: tab.sel !== null
        implicitWidth: endBtn.implicitWidth + 24
        implicitHeight: 24
        radius: 4
        color: Qt.alpha(tab.cRed, 0.18)
        border.color: Qt.alpha(tab.cRed, 0.55)
        border.width: 1
        Text {
          id: endBtn
          anchors.centerIn: parent
          text: "End process"
          color: tab.cRed
          font.family: Style.font.family
          font.pixelSize: 12
          font.bold: true
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            tab.sysmon.killTermed = false
            tab.sysmon.killTarget = tab.selectedPid
          }
        }
      }
    }

    // ---- totals 28 ---------------------------------------------------------
    Hair { Layout.fillWidth: true }
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 28
      Item { Layout.fillWidth: true }
      Text {
        text: "\u03A3 CPU " + tab.totals.cpu.toFixed(1) + "%"
            + " \u00B7 \u03A3 MEM " + tab.totals.mem.toFixed(1) + "%"
            + " \u00B7 \u03A3 RSS " + tab.sysmon.fmtRss(tab.totals.rss)
            + " \u00B7 " + ((tab.sysmon.procSort === "name" || tab.sysmon.procSort === "user") ? "a\u2013z" : "high\u2013low")
        color: tab.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.letterSpacing: 0.3
        font.features: ({ "tnum": 1 })
      }
    }
  }
}
