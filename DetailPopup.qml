import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// DetailPopup — the SysMon v0.6 shell, ported from the KDE plasmoid's Details.qml.
// FIXED frame for ALL four tabs (v0.5.1 self-sized its height per tab, so the
// popup jumped on every tab switch). Sizing lives HERE and ONLY here: the
// content area is 928x608 logical; the card adds its own padding and border
// (14*2 + 2*2 = 32 per axis), which makes the VISIBLE CARD exactly 960x640 —
// the fixed frame from the v0.6 spec. Check with `status`: popupW x popupH.
//
//   header 32   "SysMon" ... [CPU 79°][GPU 41°][NVMe 48°]  ● as of 15:22:41
//   tabbar 36   Performance · Disks · Processes · Hardware
//   pages  524  one frame for every tab (608 - 32 header - 36 tabs - 12 gap)
//
// Header: title + temp pills (the only temps in the popup) + provenance stamp.
PopupCard {
  id: popup

  required property var host
  readonly property var w: host

  anchorItem: host
  bar: host.bar
  owner: host
  // No `open:` binding on purpose: PopupCard's outside-click close assigns
  // to `open`, which would break a binding and leave the popup unable to
  // reopen. The host drives open imperatively; this syncs state back.
  onOpenChanged: {
    host.popupOpen = open
    if (open && !host.hwinfo) host.refreshHwinfo()
  }

  readonly property int frameW: 928
  readonly property int frameH: 608
  // contentWidth/Height are the CARD's size; the content holder is inset by
  // padding + border. fittedContentHeight already adds the vertical inset;
  // width needs it added explicitly or the page renders that much too narrow.
  readonly property real hInset: popup.padding * 2
      + Border.left(popup.borderSpec) + Border.right(popup.borderSpec)
  contentWidth: popup.fittedContentWidth(popup.frameW + popup.hInset)
  contentHeight: popup.fittedContentHeight(popup.frameH)

  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(popup.fg, 1.5)
  readonly property color cAmber: "#e5c07b"

  // Tabs in bar order; keys keep the v0.5.1 IPC contract (perf | disk | procs | hw).
  readonly property var tabKeys: ["perf", "disk", "procs", "hw"]
  readonly property var tabLabels: ["Performance", "Disks", "Processes", "Hardware"]
  property string tab: "perf"
  readonly property int tabIndex: Math.max(0, popup.tabKeys.indexOf(popup.tab))
  // The process probe ticks only while its tab is on screen.
  onTabIndexChanged: host.procTabActive = popup.tabIndex === 2

  // Provenance stamp: green dot while live, amber half-disc once the probe has
  // missed more than three ticks (last values stay on screen).
  readonly property bool probeStale: w.probeStampMs <= 0 ? false
      : w.clockNow - w.probeStampMs > w.refreshSeconds * 3000
  readonly property string stampText: {
    const d = new Date(w.probeStampMs)
    const p = n => String(n).padStart(2, "0")
    const s = w.probeStampMs <= 0 ? "\u2014"
        : p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds())
    return probeStale ? "\u25D0 stale \u00B7 " + s : "\u25CF as of " + s
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8

    // ---- header 32 ------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      spacing: 8

      Text {
        text: "SysMon"
        color: popup.fg
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.DemiBold
      }
      Item { Layout.fillWidth: true }

      Repeater {
        model: [
          { label: "CPU", temp: popup.w.cpuTempC },
          { label: "GPU", temp: popup.w.gpuTempC },
          { label: "NVMe", temp: popup.w.nvmeTempC }
        ]
        TempPill {
          required property var modelData
          label: modelData.label
          temp: modelData.temp
        }
      }

      Text {
        // 10, not 4: the pills end with their own 6px inner padding, so the
        // freshness dot was touching the last temperature pill.
        Layout.leftMargin: 10
        text: popup.stampText
        textFormat: Text.PlainText
        color: popup.probeStale ? popup.cAmber : popup.muted
        font.family: Style.font.family
        font.pixelSize: 11
        font.letterSpacing: 0.4
        font.features: ({ "tnum": 1 })
      }
    }

    // ---- tab bar 36: text tabs, bold + underline when active -------------
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 36

      Row {
        id: tabBar
        spacing: 4

        Repeater {
          id: tabRepeater
          model: popup.tabLabels

          Rectangle {
            id: tabBtn
            required property string modelData
            required property int index
            readonly property bool active: popup.tabIndex === index
            width: tabText.implicitWidth + 16
            height: 32
            radius: 4
            color: tabBtn.active || tabMouse.containsMouse ? Qt.alpha(popup.fg, 0.07) : "transparent"

            Text {
              id: tabText
              anchors.centerIn: parent
              text: tabBtn.modelData
              color: tabBtn.active ? popup.fg : popup.muted
              font.family: Style.font.family
              font.pixelSize: 13
              font.weight: tabBtn.active ? Font.DemiBold : Font.Normal
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: popup.tab = popup.tabKeys[tabBtn.index]
            }
          }
        }
      }

      Rectangle {
        // Underline follows the active tab.
        anchors.bottom: parent.bottom
        height: 2
        radius: 1
        color: popup.fg
        readonly property var cur: tabRepeater.count > popup.tabIndex ? tabRepeater.itemAt(popup.tabIndex) : null
        x: cur ? cur.x + 8 : 0
        width: cur ? cur.width - 16 : 0
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }
    }

    // ---- pages ------------------------------------------------------------
    StackLayout {
      id: pages
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: popup.tabIndex

      PerfTab { sysmon: popup.host }
      DisksTab { sysmon: popup.host }
      ProcsTab { id: procsTab; sysmon: popup.host }
      HwTab { sysmon: popup.host }
    }
  }

  // IPC status reads the Processes page through this (filtered view size,
  // selection, totals).
  readonly property var procsPage: procsTab

  // IPC status keeps the v0.5.1 field: colH = active page height. pageSize is
  // the real content area (must be frameW x frameH minus header + tab bar).
  readonly property real scrollColH: pages.height
  readonly property size pageSize: Qt.size(pages.width, pages.height)
  readonly property real cardW: popup.width
  readonly property real cardH: popup.height
}
