import QtQuick
import qs.Commons

// VolRow — one 32px volume row (Disks left column): usage bar 224, used/size
// 112, pct 40, mount · fs right-aligned elide-LEFT (the tail of a mount path
// is what distinguishes volumes). Fixed x/widths so the columns line up.
Item {
  id: row
  required property var owner
  required property var modelData   // {mount, usedB, totalB, fs}
  readonly property real pct: modelData.totalB > 0 ? 100 * modelData.usedB / modelData.totalB : 0
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(row.fg, 1.5)

  width: ListView.view ? ListView.view.width : 0
  height: 32

  // usage bar
  Rectangle {
    x: 0
    y: 11
    width: 224
    height: 10
    radius: 5
    color: Qt.alpha(row.fg, 0.08)
    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.min(1, row.pct / 100)
      radius: 5
      color: row.owner.sysmon.levelColor(row.pct)
    }
  }

  // used / size
  Text {
    x: 236
    y: 0
    width: 112
    height: 32
    verticalAlignment: Text.AlignVCenter
    text: row.owner.sysmon.fmtDisk(modelData.usedB) + " / " + row.owner.sysmon.fmtDisk(modelData.totalB)
    textFormat: Text.PlainText
    color: row.fg
    font.family: Style.font.family
    font.pixelSize: 12
    font.features: ({ "tnum": 1 })
  }

  // pct
  Text {
    x: 360
    y: 0
    width: 40
    height: 32
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignRight
    text: row.pct.toFixed(0) + "%"
    color: row.owner.sysmon.levelColor(row.pct)
    font.family: Style.font.family
    font.pixelSize: 12
    font.bold: true
    font.features: ({ "tnum": 1 })
  }

  // mount · fs — elide-LEFT so the distinguishing tail of the path survives
  Text {
    x: 410
    y: 0
    width: Math.max(0, row.width - 412)
    height: 32
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideLeft
    text: modelData.mount + "  \u00B7  " + modelData.fs
    textFormat: Text.PlainText
    color: row.muted
    font.family: Style.font.family
    font.pixelSize: 12
  }

  Hair {
    anchors.bottom: parent.bottom
    width: parent.width
  }
}
