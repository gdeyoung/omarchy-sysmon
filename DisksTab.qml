import QtQuick
import QtQuick.Layouts
import qs.Commons

// DisksTab — read-only capacity + throughput view, "explorer style": left
// column = all mounted volumes as rows (usage bar, used/size, pct, mount · fs),
// right column = per-disk R/W with a 1m spark. A disk tab has ONE job: show
// what's mounted and how full it is — no click actions.
Item {
  id: tab
  required property var sysmon

  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(tab.fg, 1.5)

  readonly property var volModel: {
    const out = []
    const vols = sysmon.vols || []
    for (let i = 0; i < vols.length; i++) {
      const v = vols[i]
      out.push({ mount: v.mnt, usedB: v.usedB, totalB: v.sizeB, fs: v.fs || "" })
    }
    return out
  }

  RowLayout {
    anchors.fill: parent
    spacing: 24

    // ---- left ~60%: volumes ---------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 0

        Text {
          Layout.fillHeight: true
          verticalAlignment: Text.AlignVCenter
          text: "volumes \u00B7 " + tab.volModel.length + " mounted"
          color: tab.muted
          font.family: Style.font.family
          font.pixelSize: 11
          font.capitalization: Font.AllUppercase
          font.letterSpacing: 0.6
        }
        Item { Layout.fillWidth: true }
        Text {
          visible: tab.sysmon.diskDev !== ""
          text: tab.sysmon.diskDev + " \u00B7 R " + tab.sysmon.fmtRateLong(Math.max(0, tab.sysmon.diskReadBps))
              + " \u00B7 W " + tab.sysmon.fmtRateLong(Math.max(0, tab.sysmon.diskWriteBps))
          textFormat: Text.PlainText
          color: tab.muted
          font.family: Style.font.family
          font.pixelSize: 11
          font.features: ({ "tnum": 1 })
        }
      }

      ListView {
        id: volList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 0
        model: tab.volModel
        delegate: VolRow { owner: tab }
      }
    }

    // ---- right ~40%: per-disk io -----------------------------------------
    DiskIoList { sysmon: tab.sysmon }
  }
}
