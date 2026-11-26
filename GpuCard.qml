import QtQuick
import QtQuick.Layouts
import qs.Commons

// GpuCard — Performance, right column (344x168, only when the GPU reports):
// hero GPU% + VRAM, amber busy spark, VRAM + GTT gauges.
SectionCard {
  id: card
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color cBlue: "#7aa2f7"
  readonly property color cViolet: "#bb9af7"
  readonly property color cAmber: "#e5c07b"

  visible: sysmon.gpuBusyPct >= 0 || sysmon.gpuTempC >= 0
  Layout.fillWidth: true
  Layout.preferredHeight: 168
  title: "GPU"
  rightText: sysmon.gpuPowerMw >= 0 ? (sysmon.gpuPowerMw / 1000).toFixed(1) + " W" : ""

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 4

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: card.sysmon.gpuBusyPct >= 0 ? Math.round(card.sysmon.gpuBusyPct) + "%" : "\u2014"
        color: card.fg
        font.family: Style.font.family
        font.pixelSize: 20
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Item { Layout.fillWidth: true }
      MicroLabel {
        text: card.sysmon.vramUsedB >= 0
            ? ("vram " + card.sysmon.fmtRate(card.sysmon.vramUsedB) + "/" + card.sysmon.fmtRate(card.sysmon.vramTotalB))
            : ""
      }
    }

    Sparkline {
      Layout.fillWidth: true
      Layout.fillHeight: true
      series: card.sysmon.histGpuBusy
      stroke: card.cAmber
      fill: card.cAmber
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Gauge {
        Layout.fillWidth: true
        label: "VRAM"
        pct: card.sysmon.vramTotalB > 0 ? 100 * card.sysmon.vramUsedB / card.sysmon.vramTotalB : 0
        color: card.cBlue
      }
      Gauge {
        Layout.fillWidth: true
        label: "GTT"
        pct: card.sysmon.gttTotalB > 0 ? 100 * card.sysmon.gttUsedB / card.sysmon.gttTotalB : 0
        color: card.cViolet
      }
    }
  }
}
