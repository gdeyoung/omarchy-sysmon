import QtQuick
import QtQuick.Layouts
import qs.Commons

// Gauge — labeled horizontal percent gauge for the GPU section (VRAM / GTT).
// 6px bar, micro-caps label left, percent right.
Item {
  id: g
  property string label: ""
  property real pct: 0
  property color color: "#7aa2f7"
  readonly property color muted: Qt.darker(Color.popups.text, 1.5)

  implicitHeight: 18
  Layout.fillWidth: true

  ColumnLayout {
    anchors.fill: parent
    spacing: 1

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: g.label
        color: g.muted
        font.family: Style.font.family
        font.pixelSize: 11
      }
      Item { Layout.fillWidth: true }
      Text {
        text: Math.round(Math.min(100, Math.max(0, g.pct))) + "%"
        color: g.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
      }
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 6
      radius: 3
      color: Qt.alpha(Color.popups.text, 0.12)
      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1, Math.max(0, g.pct / 100))
        radius: 3
        color: g.color
      }
    }
  }
}
