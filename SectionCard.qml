import QtQuick
import QtQuick.Layouts
import qs.Commons

// SectionCard — flat card atom: white 4% fill, radius 8, 12px padding,
// micro-caps title + right value in the header, body content below.
// Default children are re-parented into the body column.
Rectangle {
  id: card
  default property alias content: body.data
  property string title: ""
  property string rightText: ""

  radius: 8
  color: Qt.alpha(Color.popups.text, 0.04)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      MicroLabel { text: card.title }
      Item { Layout.fillWidth: true }
      ValueText {
        visible: card.rightText !== ""
        text: card.rightText
      }
    }

    ColumnLayout {
      id: body
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 4
    }
  }
}
