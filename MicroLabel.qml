import QtQuick
import qs.Commons

// MicroLabel — 11px CAPS tracking label (spec typography: micro tier).
// Text color comes from the Omarchy theme; size and tracking from the KDE build.
Text {
  color: Qt.darker(Color.popups.text, 1.5)
  font.family: Style.font.family
  font.pixelSize: 11
  font.capitalization: Font.AllUppercase
  font.letterSpacing: 0.6
}
