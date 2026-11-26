import QtQuick
import qs.Commons

// TempPill — header temperature chip (white 4% fill, micro-caps label,
// tnum value colored by threshold: >=85 crit, >=70 warn).
Rectangle {
  id: pill
  property string label: ""
  property real temp: -1
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(pill.fg, 1.5)
  readonly property color cWarn: "#e5c07b"
  readonly property color cCrit: "#f4405c"

  visible: temp >= 0
  radius: height / 2
  implicitWidth: row.implicitWidth + 12
  implicitHeight: 20
  color: Qt.alpha(pill.fg, 0.04)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 4

    MicroLabel {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.label
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(pill.temp) + "\u00B0"
      color: pill.temp >= 85 ? pill.cCrit : (pill.temp >= 70 ? pill.cWarn : pill.fg)
      font.family: Style.font.family
      font.pixelSize: 12
      font.features: ({ "tnum": 1 })
    }
  }
}
