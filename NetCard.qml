import QtQuick
import QtQuick.Layouts
import qs.Commons

// NetCard — Performance, right column (344x172): hero down/up rates, the two
// busiest interfaces, dual-line auto-scale spark (blue down / cyan up).
SectionCard {
  id: card
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color cBlue: "#7aa2f7"
  readonly property color cCyan: "#7dcfff"

  Layout.fillWidth: true
  Layout.preferredHeight: 172
  Layout.fillHeight: true
  title: "Network"
  rightText: sysmon.netDownBps < 0 ? "" : sysmon.fmtRate(sysmon.netDownBps)

  // Top two interfaces by combined activity this tick.
  function topIfs() {
    const arr = []
    for (const k in sysmon.ifRates) arr.push([k, sysmon.ifRates[k][0] + sysmon.ifRates[k][1]])
    arr.sort((a, b) => b[1] - a[1])
    return arr.slice(0, 2).map(e => e[0])
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 4

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: "\u2193 " + (card.sysmon.netDownBps < 0 ? "\u2014" : card.sysmon.fmtRateLong(card.sysmon.netDownBps))
        color: card.cBlue
        font.family: Style.font.family
        font.pixelSize: 20
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Text {
        Layout.leftMargin: 8
        Layout.alignment: Qt.AlignBaseline
        text: "\u2191 " + (card.sysmon.netUpBps < 0 ? "\u2014" : card.sysmon.fmtRateLong(card.sysmon.netUpBps))
        color: card.cCyan
        font.family: Style.font.family
        font.pixelSize: 14
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Item { Layout.fillWidth: true }
    }

    Repeater {
      model: card.topIfs()

      RowLayout {
        id: ifRow
        required property string modelData
        Layout.fillWidth: true

        MicroLabel { text: ifRow.modelData }
        Item { Layout.fillWidth: true }
        Text {
          text: {
            const r = card.sysmon.ifRates[ifRow.modelData]
            return "\u2193" + card.sysmon.fmtRate(r ? r[0] : 0) + "  \u2191" + card.sysmon.fmtRate(r ? r[1] : 0)
          }
          color: card.fg
          font.family: Style.font.family
          font.pixelSize: 12
          font.features: ({ "tnum": 1 })
        }
      }
    }

    Sparkline {
      Layout.fillWidth: true
      Layout.fillHeight: true
      autoScale: true
      series: card.sysmon.histNetDown
      seriesB: card.sysmon.histNetUp
      stroke: card.cBlue
      strokeB: card.cCyan
    }
    MicroLabel { text: "down \u00B7 up" }
  }
}
