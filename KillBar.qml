import QtQuick
import QtQuick.Layouts
import qs.Commons

// KillBar — in-place kill confirmation (the popup closes on focus loss, so no
// modal dialogs). TERM -> Force-9 escalation, restyled to a FIXED 28px height
// so its appearance never reflows the fixed frame. The kill's real exit code
// is surfaced ("\u2717 no permission" on EPERM) instead of failing silently.
Rectangle {
  id: bar
  required property var sysmon

  readonly property color cRed: "#f4405c"
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(bar.fg, 1.5)

  visible: sysmon.killTarget > 0
  height: 28
  radius: 4
  color: Qt.alpha(bar.cRed, 0.12)

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 8

    Text {
      Layout.fillWidth: true
      text: sysmon.killExit !== 0
          ? ("\u2717 no permission \u2014 " + sysmon.killName + " (" + sysmon.killTarget + ")")
          : ("Kill " + sysmon.killName + " (" + sysmon.killTarget + ")?")
      textFormat: Text.PlainText
      color: sysmon.killExit !== 0 ? bar.cRed : bar.fg
      font.family: Style.font.family
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Rectangle {
      implicitWidth: killBtn.implicitWidth + 12
      implicitHeight: 20
      radius: 3
      color: Qt.alpha(bar.cRed, 0.3)
      Text {
        id: killBtn
        anchors.centerIn: parent
        text: sysmon.killTermed ? "Force kill (9)" : "Kill (TERM)"
        color: bar.cRed
        font.family: Style.font.family
        font.pixelSize: 11
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sysmon.doKill(sysmon.killTarget, sysmon.killTermed ? 9 : 15)
      }
    }

    Rectangle {
      implicitWidth: cancelBtn.implicitWidth + 12
      implicitHeight: 20
      radius: 3
      color: Qt.alpha(bar.fg, 0.10)
      Text {
        id: cancelBtn
        anchors.centerIn: parent
        text: "Cancel"
        color: bar.muted
        font.family: Style.font.family
        font.pixelSize: 11
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { sysmon.killTarget = 0; sysmon.killTermed = false }
      }
    }
  }
}
