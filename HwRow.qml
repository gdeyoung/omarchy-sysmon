import QtQuick
import QtQuick.Layouts
import qs.Commons

// HwRow — label/value hardware row (v0.7: micro-caps label at fixed 84px so
// values align in columns; body-tier value, elided).
RowLayout {
  id: hwRow
  property string label: ""
  property string value: ""
  property bool show: true
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(hwRow.fg, 1.5)
  visible: show
  spacing: 8
  Layout.fillWidth: true

  Text {
    text: hwRow.label
    color: hwRow.muted
    font.family: Style.font.family
    font.pixelSize: 11
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    Layout.preferredWidth: 84
  }
  Text {
    text: hwRow.value
    textFormat: Text.PlainText
    color: hwRow.fg
    font.family: Style.font.family
    font.pixelSize: 12
    elide: Text.ElideRight
    Layout.fillWidth: true
  }
}
