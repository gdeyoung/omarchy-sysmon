import QtQuick
import QtQuick.Layouts
import qs.Commons

// MemCard — Performance, left column (568x220): hero used / total + percent,
// stacked used/buff/cache bar, legend, ram% spark, swap micro-bar when in use.
SectionCard {
  id: card
  required property var sysmon
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(card.fg, 1.5)
  readonly property color cBlue: "#7aa2f7"
  readonly property color cViolet: "#bb9af7"

  // The probe defines used = total - MemAvailable, so "avail" is simply the
  // remainder. Cache is reclaimable and sits INSIDE avail, not beside it —
  // the KDE original computed avail = total - used - buff - cache, which
  // double-subtracts the page cache and reads ~0 on a well-cached machine.
  readonly property real availMb: Math.max(0, sysmon.ramTotalMb - sysmon.ramUsedMb)

  // memory bar fractions [used, buff, cache, rest], clamped so the segments
  // never exceed the bar (cache overlaps avail)
  readonly property var memFracs: {
    const t = sysmon.ramTotalMb
    if (t <= 0) return [0, 0, 0, 1]
    const u = Math.min(1, sysmon.ramUsedMb / t)
    const b = Math.min(1 - u, (sysmon.buffersKb / 1024) / t)
    const c = Math.min(1 - u - b, (sysmon.cachedKb / 1024) / t)
    return [u, b, c, Math.max(0, 1 - u - b - c)]
  }

  Layout.fillWidth: true
  Layout.fillHeight: true
  title: "Memory"
  rightText: sysmon.swapUsedKb > 1024
      ? ("swap " + sysmon.fmtGbB(sysmon.swapUsedKb) + " \u00B7 "
         + Math.round(100 * sysmon.swapUsedKb / Math.max(1, sysmon.swapTotalKb)) + "%")
      : ""

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 8

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: sysmon.fmtSizeP(sysmon.ramUsedMb * 1048576)
        color: card.fg
        font.family: Style.font.family
        font.pixelSize: 24
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
      }
      Text {
        Layout.leftMargin: 8
        Layout.alignment: Qt.AlignBaseline
        text: "/ " + sysmon.fmtSizeP(sysmon.ramTotalMb * 1048576)
        color: card.muted
        font.family: Style.font.family
        font.pixelSize: 14
        font.features: ({ "tnum": 1 })
      }
      Item { Layout.fillWidth: true }
      ValueText {
        text: Math.round(sysmon.ramPct) + "%"
        color: sysmon.levelColor(sysmon.ramPct)
      }
    }

    // stacked used / buff / cache / avail bar
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 14
      radius: 7
      color: Qt.alpha(card.fg, 0.08)

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width

        Item {
          width: parent.width * card.memFracs[0]
          height: parent.height
          Rectangle { anchors.fill: parent; color: card.cBlue }
        }
        Item {
          width: parent.width * card.memFracs[1]
          height: parent.height
          Rectangle { anchors.fill: parent; color: Qt.alpha(card.cViolet, 0.55) }
        }
        Item {
          width: parent.width * card.memFracs[2]
          height: parent.height
          Rectangle { anchors.fill: parent; color: Qt.alpha(card.cViolet, 0.3) }
        }
      }
    }

    MicroLabel {
      Layout.fillWidth: true
      text: "used " + sysmon.fmtGb(sysmon.ramUsedMb)
          + " \u00B7 buff " + sysmon.fmtGbB(sysmon.buffersKb)
          + " \u00B7 cache " + sysmon.fmtGbB(sysmon.cachedKb)
          + " \u00B7 avail " + sysmon.fmtGb(card.availMb)
    }

    Sparkline {
      Layout.fillWidth: true
      Layout.preferredHeight: 60
      series: card.sysmon.histRam
      stroke: card.cBlue
      fill: card.cBlue
    }

    // swap micro-bar (only while swap is in use)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 6
      radius: 3
      visible: sysmon.swapUsedKb > 1024
      color: Qt.alpha(card.fg, 0.08)
      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1, sysmon.swapUsedKb / Math.max(1, sysmon.swapTotalKb))
        radius: 3
        color: card.cViolet
      }
    }
  }
}
