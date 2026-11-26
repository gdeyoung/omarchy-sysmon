import QtQuick
import QtQuick.Layouts

// PerfTab — Performance: 568 | 16 | 344 two-column card layout.
// LEFT: CPU (hero + numbered core grid + avg/busiest spark) and Memory
// (stacked bar + legend + spark + swap micro-bar). RIGHT: RightCards
// (GPU / Network / Disk). No collapsing, no footer — the fixed frame fits all.
Item {
  id: tab
  required property var sysmon

  RowLayout {
    anchors.fill: parent
    spacing: 16

    // ---- left 568: CPU + Memory -----------------------------------------
    ColumnLayout {
      Layout.preferredWidth: 568
      Layout.fillHeight: true
      spacing: 12

      CpuCard { sysmon: tab.sysmon }
      MemCard { sysmon: tab.sysmon }
    }

    // ---- right 344: GPU / Network / Disk ---------------------------------
    RightCards {
      Layout.preferredWidth: 344
      Layout.fillHeight: true
      sysmon: tab.sysmon
    }
  }
}
