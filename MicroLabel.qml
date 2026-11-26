import QtQuick
import qs.Commons

// MicroLabel — 11px CAPS tracking label (spec typography: micro tier).
// Text color comes from the Omarchy theme; size and tracking from the KDE build.
Text {
  color: Qt.darker(Color.popups.text, 1.5)
  // Text defaults to AlignTop inside its box. Callers give this label a
  // preferredHeight taller than the glyphs (section headers sit in 24px rows),
  // which pinned it ~4px above its neighbours. Centre whenever it is stretched.
  verticalAlignment: Text.AlignVCenter
  textFormat: Text.PlainText
  font.family: Style.font.family
  font.pixelSize: 11
  font.capitalization: Font.AllUppercase
  font.letterSpacing: 0.6
}
