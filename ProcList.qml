import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

// ProcList — the scrolling process list: array-reset model with a contentY
// restore (fixed 26px rows make the restore exact, so scrolling survives the
// 2s model ticks), skeleton rows until the first fetch, empty-filter state.
ListView {
  id: list
  required property var owner
  readonly property color muted: Qt.darker(Color.popups.text, 1.5)

  Layout.fillWidth: true
  Layout.fillHeight: true
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  boundsMovement: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Component.onCompleted: model = owner.view

  Connections {
    target: list.owner
    function onViewChanged() {
      const y = list.contentY
      list.model = list.owner.view
      list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height))
    }
  }

  // skeleton until the first process probe finishes. v0.6.1: a run that died
  // (at its deadline or otherwise) is not drawn as "still loading" — the
  // probe-died notice below says what happened; the next tick retries anyway.
  Column {
    parent: list
    anchors.fill: parent
    anchors.margins: 8
    visible: list.owner.sysmon.procs.length === 0 && list.owner.sysmon.procsProbeExit === -1
    spacing: 14
    Repeater {
      model: 16
      SkeletonRow { w: 240 + (index % 5) * 120 }
    }
  }

  // empty-filter state
  Item {
    parent: list
    anchors.fill: parent
    visible: list.owner.sysmon.procs.length > 0 && list.owner.view.length === 0
    Text {
      anchors.centerIn: parent
      text: "no matches for \u201C" + list.owner.sysmon.procFilter + "\u201D"
      textFormat: Text.PlainText
      color: list.muted
      font.family: Style.font.family
      font.pixelSize: 12
    }
  }

  // probe-died state (v0.6.1): no rows because the last run did not finish.
  Item {
    parent: list
    anchors.fill: parent
    visible: list.owner.sysmon.procs.length === 0 && list.owner.sysmon.procsProbeExit !== -1
    Text {
      anchors.centerIn: parent
      text: {
        const s = list.owner.sysmon
        const code = s.procsProbeExit
        return code === 124 || code === 137
          ? "no process data \u2014 the last probe hit its " + (s.procsProbeDeadlineMs / 1000) + " s limit; retrying"
          : "no process data \u2014 the last probe exited " + code + "; retrying"
      }
      textFormat: Text.PlainText
      color: list.muted
      font.family: Style.font.family
      font.pixelSize: 12
    }
  }

  delegate: ProcRow { owner: list.owner }
}
