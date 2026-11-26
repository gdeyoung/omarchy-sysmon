import QtQuick
import QtQuick.Layouts
import qs.Commons

// CpuCard — Performance, left column (568x300): hero CPU% + busiest core,
// numbered core grid, avg/busiest-core spark (0-100 fixed).
SectionCard {
  id: card
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(card.fg, 1.5)
  readonly property color cGreen: "#3fd18b"
  readonly property color cViolet: "#bb9af7"

  readonly property real busiestCore: {
    let m = 0
    const p = sysmon.corePcts
    for (let i = 0; i < p.length; i++) if (p[i] > m) m = p[i]
    return m
  }

  Layout.fillWidth: true
  Layout.preferredHeight: 300
  title: "CPU"
  rightText: sysmon.load1.toFixed(2) + " \u00B7 " + sysmon.load5.toFixed(2) + " \u00B7 " + sysmon.load15.toFixed(2)

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 8

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: sysmon.cpuPct < 0 ? "\u2014" : Math.round(sysmon.cpuPct) + "%"
        color: card.fg
        font.family: Style.font.family
        font.pixelSize: 24
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Item { Layout.fillWidth: true }
      ColumnLayout {
        spacing: 0
        MicroLabel { text: "busiest core" }
        ValueText { text: Math.round(card.busiestCore) + "%" }
      }
    }

    CoreGrid {
      Layout.fillWidth: true
      Layout.fillHeight: true
      corePcts: card.sysmon.corePcts
      perRow: 16
      cellH: 56
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      MicroLabel { text: "avg \u00B7 busiest" }
      Item { Layout.fillWidth: true }
      Text {
        text: card.sysmon.corePcts.length > 0 ? card.sysmon.corePcts.length + " logical" : ""
        color: card.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.features: ({ "tnum": 1 })
      }
    }

    Sparkline {
      Layout.fillWidth: true
      Layout.preferredHeight: 72
      series: card.sysmon.histCoreAvg
      seriesB: card.sysmon.histCoreMax
      stroke: card.cGreen
      strokeB: card.cViolet
      fill: card.cGreen
    }
  }
}
