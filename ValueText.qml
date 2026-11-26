import QtQuick
import qs.Commons

// ValueText — 14px semibold tabular numerals (spec typography: value tier).
Text {
  color: Color.popups.text
  textFormat: Text.PlainText
  font.family: Style.font.family
  font.pixelSize: 14
  font.weight: Font.DemiBold
  font.features: ({ "tnum": 1 })
}
