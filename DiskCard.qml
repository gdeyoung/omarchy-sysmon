import QtQuick
import QtQuick.Layouts
import qs.Commons

// DiskCard — Performance, right column (344x172): names the disk, hero used%
// + used/total, usage bar, R/W rates + iops, dual spark (blue read / red write).
SectionCard {
  id: card
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(card.fg, 1.5)
  readonly property color cBlue: "#7aa2f7"
  readonly property color cRed: "#f4405c"

  Layout.fillWidth: true
  Layout.preferredHeight: 172
  Layout.fillHeight: true
  title: sysmon.diskDev !== "" ? "Disk \u00B7 " + sysmon.diskDev : "Disk"
  rightText: Math.round(sysmon.diskPct) + "%"

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 4

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: Math.round(card.sysmon.diskPct) + "%"
        color: card.sysmon.levelColor(card.sysmon.diskPct)
        font.family: Style.font.family
        font.pixelSize: 20
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Item { Layout.fillWidth: true }
      Text {
        text: card.sysmon.fmtDisk(card.sysmon.diskUsedB) + " / " + card.sysmon.fmtDisk(card.sysmon.diskTotalB)
        color: card.muted
        font.family: Style.font.family
        font.pixelSize: 12
        font.features: ({ "tnum": 1 })
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 8
      radius: 4
      color: Qt.alpha(card.fg, 0.08)
      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1, card.sysmon.diskPct / 100)
        radius: 4
        color: card.sysmon.levelColor(card.sysmon.diskPct)
      }
    }

    MicroLabel {
      text: "R " + card.sysmon.fmtRateLong(Math.max(0, card.sysmon.diskReadBps))
          + " \u00B7 W " + card.sysmon.fmtRateLong(Math.max(0, card.sysmon.diskWriteBps))
          + " \u00B7 " + Math.round(Math.max(0, card.sysmon.diskReadIops)) + "/"
          + Math.round(Math.max(0, card.sysmon.diskWriteIops)) + " iops"
    }

    Sparkline {
      Layout.fillWidth: true
      Layout.fillHeight: true
      autoScale: true
      series: card.sysmon.histDiskR
      seriesB: card.sysmon.histDiskW
      stroke: card.cBlue
      strokeB: card.cRed
    }
    MicroLabel { text: "read \u00B7 write" }
  }
}
