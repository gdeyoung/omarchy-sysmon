import QtQuick
import QtQuick.Layouts

// RightCards — Performance right column (344px): GPU (conditional) / Network
// / Disk cards. When the GPU card hides, NET and DISK grow equally
// (fillHeight). Every card = hero + graph + detail row — no bare numbers.
ColumnLayout {
  id: col
  required property var sysmon

  spacing: 12

  GpuCard { sysmon: col.sysmon }
  NetCard { sysmon: col.sysmon }
  DiskCard { sysmon: col.sysmon }
}
