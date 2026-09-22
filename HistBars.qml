import QtQuick

// HistBars — histogram of a {t, v} series as a row of Repeater rectangles.
// 12 fixed-width bins over [lo, hi] (default 0..100 for percent series).
// Bins tint with the section's active color, opacity scaled by count (heat);
// the current-value bin sits at full opacity. logScale maps v through the
// same log activity curve the bar uses (1 Gbit/s = 100).
Item {
  id: root
  property var series: []
  property int bins: 12
  property real lo: 0
  property real hi: 100
  property bool logScale: false
  property color activeColor: "#3fb950"
  property real barW: 10
  property real gap: 3
  property real maxH: 30

  function mapV(v) {
    return logScale ? (Math.log(1 + v) / Math.log(1 + 125000000)) * 100 : v
  }

  readonly property var counts: {
    const c = new Array(bins).fill(0)
    if (series && series.length > 0) {
      for (let i = 0; i < series.length; i++) {
        let b = Math.floor(((mapV(series[i].v) - lo) / (hi - lo)) * bins)
        if (b < 0) b = 0
        if (b >= bins) b = bins - 1
        c[b]++
      }
    }
    return c
  }
  readonly property real maxCount: {
    let m = 0
    for (let i = 0; i < counts.length; i++) if (counts[i] > m) m = counts[i]
    return m > 0 ? m : 1
  }
  readonly property int currentBin: {
    if (!series || series.length === 0) return -1
    let b = Math.floor(((mapV(series[series.length - 1].v) - lo) / (hi - lo)) * bins)
    if (b < 0) b = 0
    if (b >= bins) b = bins - 1
    return b
  }

  implicitWidth: bins * barW + (bins - 1) * gap
  implicitHeight: maxH

  Row {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    spacing: root.gap

    Repeater {
      model: root.bins

      Rectangle {
        required property int index
        readonly property real c: root.counts[index] || 0
        width: root.barW
        radius: 2
        color: root.activeColor
        opacity: index === root.currentBin ? 1.0 : (c === 0 ? 0.10 : 0.18 + 0.72 * (c / root.maxCount))
        height: c === 0 ? 3 : Math.max(4, (c / root.maxCount) * (root.maxH - 2))
        anchors.bottom: parent.bottom
      }
    }
  }
}
