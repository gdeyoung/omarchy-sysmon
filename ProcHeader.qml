import QtQuick
import QtQuick.Layouts
import qs.Commons

// ProcHeader — the sticky column header (28): the shared procCols contract,
// bold + arrow on the active sort column. rightMargin 14 = the scrollbar lane,
// the same reserve the rows carry, so header and cells stay aligned.
RowLayout {
  id: hdr
  required property var owner

  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(hdr.fg, 1.5)

  Layout.fillWidth: true
  Layout.rightMargin: 14
  Layout.preferredHeight: 28
  spacing: 0

  Repeater {
    model: owner.procCols

    Item {
      id: hcell
      required property var modelData
      Layout.fillWidth: hcell.modelData.w < 0
      Layout.preferredWidth: hcell.modelData.w > 0 ? hcell.modelData.w : 0
      Layout.preferredHeight: 28

      Text {
        anchors.fill: parent
        anchors.leftMargin: hcell.modelData.key === "name" ? 8 : 0
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: {
          const k = hcell.modelData.key
          return (k === "name" || k === "user") ? Text.AlignLeft
              : k === "state" ? Text.AlignHCenter
              : Text.AlignRight
        }
        text: hcell.modelData.label
            + (hdr.owner.sortCol[hcell.modelData.key] !== undefined ? hdr.owner.headerArrow(hcell.modelData.key) : "")
        color: hdr.owner.sysmon.procSort === hcell.modelData.key ? hdr.fg : hdr.muted
        font.family: Style.font.family
        font.bold: hdr.owner.sysmon.procSort === hcell.modelData.key
        font.pixelSize: 11
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
      }

      MouseArea {
        anchors.fill: parent
        enabled: hdr.owner.sortCol[hcell.modelData.key] !== undefined
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: hdr.owner.sysmon.procSort = hcell.modelData.key
      }
    }
  }
}
