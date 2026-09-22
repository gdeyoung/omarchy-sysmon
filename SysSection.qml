import QtQuick
import QtQuick.Layouts
import qs.Commons

// SysSection — collapsible panel section. Header row (letter badge, title,
// right-aligned summary, chevron); children below when expanded. The default
// slot holds the section body.
ColumnLayout {
  id: sec
  property string title: ""
  property string summary: ""
  property bool expanded: true
  default property alias body: bodyHolder.children

  spacing: Style.space(6)

  function toggle() { sec.expanded = !sec.expanded }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: headerRow.implicitHeight + Style.space(8)
    radius: Style.space(4)
    color: "#22262e"

    MouseArea {
      anchors.fill: parent
      onClicked: sec.toggle()
      hoverEnabled: true
    }

    RowLayout {
      id: headerRow
      anchors.fill: parent
      anchors.margins: Style.space(4)
      spacing: Style.space(8)

      Text {
        text: sec.title
        color: "#c0caf5"
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Item { Layout.fillWidth: true }
      Text {
        text: sec.summary
        color: "#9aa5ce"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        text: sec.expanded ? "▾" : "▸"
        color: "#565f89"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  ColumnLayout {
    id: bodyHolder
    visible: sec.expanded
    Layout.leftMargin: Style.space(4)
    Layout.rightMargin: Style.space(4)
    spacing: Style.space(6)
  }
}
