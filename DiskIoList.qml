import QtQuick
import QtQuick.Layouts
import qs.Commons

// DiskIoList — Disks right column: per-device read/write rates with a 1m dual
// spark (blue read / red write). Empty state names the reason (no disk
// resolved), instead of leaving a blank column.
ColumnLayout {
  id: col
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(col.fg, 1.5)
  readonly property color cBlue: "#7aa2f7"
  readonly property color cRed: "#f4405c"

  Layout.fillWidth: true
  Layout.fillHeight: true
  Layout.maximumWidth: Math.round(col.parent.width * 0.4)
  spacing: 0

  MicroLabel {
    Layout.fillWidth: true
    Layout.preferredHeight: 24
    text: "disk io \u00B7 per device"
  }

  ListView {
    id: ioList
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 0
    model: col.sysmon.diskNames
    delegate: Item {
      id: drow
      required property string modelData
      readonly property var io: col.sysmon.diskIo[modelData] || [0, 0]
      width: ioList.width
      height: 44

      Text {
        x: 0
        y: 6
        text: drow.modelData
        textFormat: Text.PlainText
        color: col.fg
        font.family: Style.font.family
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Text {
        anchors.right: parent.right
        y: 8
        text: "R " + col.sysmon.fmtRateLong(Math.max(0, drow.io[0]))
            + "  W " + col.sysmon.fmtRateLong(Math.max(0, drow.io[1]))
        color: col.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
      }
      Canvas {
        id: spark
        x: 0
        y: 20
        width: drow.width
        height: 20
        property var series: col.sysmon.diskHistR[modelData] || []     // [{t, v}]
        property var seriesB: col.sysmon.diskHistW[modelData] || []
        onSeriesChanged: requestPaint()
        onSeriesBChanged: requestPaint()
        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const a = series.map(s => Number(s.v))
          const b = seriesB.map(s => Number(s.v))
          const maxV = Math.max(1, ...a.map(Number), ...b.map(Number))
          const line = (parts, color) => {
            if (parts.length < 2) return
            ctx.strokeStyle = color
            ctx.lineWidth = 1
            ctx.beginPath()
            for (let i = 0; i < parts.length; i++) {
              const x = (i / (parts.length - 1)) * width
              const y = height - 1 - (Number(parts[i]) / maxV) * (height - 2)
              if (i === 0) ctx.moveTo(x, y)
              else ctx.lineTo(x, y)
            }
            ctx.stroke()
          }
          line(a, "#7aa2f7")
          line(b, "#f4405c")
        }
      }
      // hairline at 5% (lighter than the shared Hair's 10% — rows sit tight)
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(col.fg, 0.05)
      }
    }
  }

  Text {
    Layout.fillWidth: true
    Layout.topMargin: 6
    visible: col.sysmon.diskNames.length === 0
    text: "no physical disk resolved"
    color: col.muted
    font.family: Style.font.family
    font.pixelSize: 12
  }
}
