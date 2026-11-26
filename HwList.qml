import QtQuick
import QtQuick.Controls
import qs.Commons

// HwList — the hardware table: a ListView (not a ColumnLayout — ~35 rows
// cannot clip in the 616px page). Delegates are 14px narrower than the
// viewport so the attached ScrollBar's lane never covers text.
// Row heights: section header 34 (hairline except the first), key row 27,
// wrapped key rows grow with the value text.
ListView {
  id: list
  required property var owner
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(list.fg, 1.5)

  anchors.fill: parent
  anchors.rightMargin: 14   // scrollbar lane — content never covered
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  boundsMovement: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
  model: owner.rows

  delegate: Rectangle {
    id: drow
    required property var modelData
    required property int index
    width: ListView.view.width - 14
    height: drow.modelData.t === "s" ? 34 : (valueText.lineCount > 1 ? valueText.implicitHeight + 12 : 27)
    color: "transparent"

    // section header
    Item {
      visible: drow.modelData.t === "s"
      anchors.fill: parent
      Hair {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: drow.index > 0
      }
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        text: drow.modelData.t === "s" ? drow.modelData.label.toUpperCase() : ""
        color: list.muted
        font.family: Style.font.family
        font.pixelSize: 12
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2
      }
    }

    // key : value row (label column 150, value wraps)
    Row {
      visible: drow.modelData.t === "k"
      anchors.fill: parent
      Item {
        width: 150
        height: parent.height
        Text {
          anchors.fill: parent
          anchors.leftMargin: 2
          verticalAlignment: Text.AlignVCenter
          text: drow.modelData.t === "k" ? drow.modelData.label : ""
          textFormat: Text.PlainText
          color: list.muted
          font.family: Style.font.family
          font.pixelSize: 12
          elide: Text.ElideRight
        }
      }
      Text {
        id: valueText
        width: parent.width - 150
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: drow.modelData.t === "k" ? drow.modelData.value : ""
        textFormat: Text.PlainText
        color: drow.modelData.t === "k" && drow.modelData.muted ? list.muted : list.fg
        font.family: Style.font.family
        font.pixelSize: 13
        wrapMode: Text.WordWrap
      }
    }
  }

  // skeleton until hwinfo lands (one-shot fetch on first popup open)
  Column {
    parent: list
    anchors.fill: parent
    anchors.margins: 8
    visible: !list.owner.sysmon.hwinfo
    spacing: 14
    Repeater {
      model: 14
      SkeletonRow { w: 240 + (index % 5) * 120 }
    }
  }
}
