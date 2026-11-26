import QtQuick
import qs.Commons
import qs.Ui

// ProcRow — one 26px process row: NAME(fill)/USER/S/PID/CPU%/MEM%/RSS/1m.
// v0.8: no per-row kill pill (the scrollbar overlay covered it); kill lives in
// the tab footer's End-process bar, driven by row selection (click = select,
// double-click = straight to the confirm bar).
// Column widths mirror ProcsTab.procCols (fixed sum 444; NAME gets the rest).
Rectangle {
  id: row
  required property var owner
  required property var modelData   // [pid, user, name, pcpu, pmem, rss_kb, state, args]
  readonly property var m: modelData
  readonly property bool selected: row.m[0] === owner.selectedPid
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(row.fg, 1.5)

  // 14px narrower than the viewport: the ScrollBar overlays the flickable's
  // right edge, so this reserve is its lane — content can never sit under it.
  width: ListView.view ? ListView.view.width - 14 : 0
  height: 26
  color: selected ? Qt.alpha(owner.cGreen, 0.10)
      : (rowMa.containsMouse ? Qt.alpha(row.fg, 0.05) : "transparent")

  // one table cell: fixed width, 12px text, tnum unless told otherwise
  component PCell: Item {
    id: pc
    property real w: 60
    property string text: ""
    property color col: row.fg
    property int align: Text.AlignRight
    property bool bold: false
    property bool tnum: true
    property bool elide: false
    property real leftPad: 0
    width: pc.w
    height: parent.height
    Text {
      anchors.fill: parent
      anchors.leftMargin: pc.leftPad
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: pc.align
      text: pc.text
      textFormat: Text.PlainText
      color: pc.col
      font.family: Style.font.family
      font.pixelSize: 12
      font.bold: pc.bold
      font.features: pc.tnum ? ({ "tnum": 1 }) : ({ })
      elide: pc.elide ? Text.ElideRight : Text.ElideNone
    }
  }

  Rectangle {  // selection left rail
    width: 2
    height: parent.height
    color: owner.cGreen
    visible: row.selected
  }

  // whole-row select. Declared BEFORE content so text/hover areas stack above
  // it; the tooltip MouseAreas below use acceptedButtons: NoButton so presses
  // fall through to this one (a hover-only MouseArea that accepts buttons
  // would swallow the click).
  MouseArea {
    id: rowMa
    anchors.fill: parent
    hoverEnabled: true
    onClicked: owner.selectedPid = row.m[0]
    onDoubleClicked: {
      owner.selectedPid = row.m[0]
      owner.sysmon.killTermed = false
      owner.sysmon.killTarget = row.m[0]
    }
  }

  Row {
    anchors.fill: parent

    // NAME (fill) — tooltip carries the full command line
    Item {
      width: row.width - owner.fixedW
      height: parent.height
      PCell {
        w: parent.width
        align: Text.AlignLeft
        elide: true
        leftPad: 8
        text: row.m[2]
      }
      PanelToolTip {
        visible: nameMa.containsMouse
        text: row.m[7] !== "" ? row.m[7] : row.m[2]
        delay: 500
      }
      MouseArea {
        id: nameMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton   // hover-only; clicks reach rowMa
      }
    }

    // USER
    Item {
      width: 84
      height: parent.height
      PCell { align: Text.AlignLeft; elide: true; col: row.muted; tnum: false; text: row.m[1] }
    }

    // S(tate)
    Item {
      width: 24
      height: parent.height
      PCell {
        align: Text.AlignHCenter
        tnum: false
        text: row.m[6]
        col: owner.stateColor(row.m[6])
        bold: row.m[6] === "D" || row.m[6] === "Z"
      }
      PanelToolTip {
        visible: stateMa.containsMouse
        text: {
          const mm = { R: "running", S: "sleeping", D: "uninterruptible disk sleep",
                       Z: "zombie", T: "stopped", I: "idle (kernel thread)" }
          return mm[row.m[6]] || row.m[6]
        }
      }
      MouseArea {
        id: stateMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }
    }

    // PID
    Item {
      width: 60
      height: parent.height
      PCell { col: row.muted; text: String(row.m[0]) }
    }

    // CPU%
    Item {
      width: 60
      height: parent.height
      PCell { text: Number(row.m[3]).toFixed(1); col: owner.cpuColor(Number(row.m[3])) }
    }

    // MEM%
    Item {
      width: 60
      height: parent.height
      PCell { text: Number(row.m[4]).toFixed(1) }
    }

    // RSS
    Item {
      width: 68
      height: parent.height
      PCell { text: owner.sysmon.fmtRss(Number(row.m[5])) }
    }

    // 1m spark — logical coords only, no dpr in the paint path
    Item {
      width: 88
      height: parent.height
      Canvas {
        id: miniSpark
        anchors.centerIn: parent
        width: 80
        height: 16
        property string series: owner.sysmon.pidHist[String(row.m[0])] || ""
        onSeriesChanged: requestPaint()
        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const parts = series === "" ? [] : series.split(",")
          if (parts.length < 2) return
          ctx.strokeStyle = owner.cBlue
          ctx.lineWidth = 1
          ctx.beginPath()
          for (let i = 0; i < parts.length; i++) {
            const x = 1 + (i / (parts.length - 1)) * (width - 2)
            const y = height - 2 - (Math.min(100, Number(parts[i])) / 100) * (height - 4)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.stroke()
        }
      }
    }
  }
}
