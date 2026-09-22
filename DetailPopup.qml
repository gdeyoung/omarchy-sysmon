import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// DetailPopup — the sysmon panel. PopupCard anchored under the bar widget,
// opened by left-click on the bar or via IPC open/toggle. Sections are added
// incrementally below the header as they verify.
PopupCard {
  id: popup

  required property var host
  readonly property var w: host

  anchorItem: host
  bar: host.bar
  owner: host
  open: host.popupOpen

  contentWidth: popup.fittedContentWidth(Style.space(560))
  contentHeight: popup.fittedContentHeight(scrollCol.implicitHeight, Style.space(800))

  readonly property color fg: host && host.bar ? host.bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(popup.fg, 1.5)

  function tempColor(c) {
    if (c >= 85) return "#f7768e"
    if (c >= 70) return "#e5c07b"
    return "#3fb950"
  }

  function levelColor(pct) {
    if (pct >= 90) return "#f7768e"
    if (pct >= 70) return "#e5c07b"
    return "#3fb950"
  }

  Flickable {
    id: flick
    anchors.fill: parent
    contentHeight: scrollCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
      id: scrollCol
      width: flick.width
      spacing: Style.space(10)

      // ---- Header: title + temps ----------------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "SysMon"
          color: popup.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
          visible: w.cpuTempC >= 0
          text: "CPU " + Math.round(w.cpuTempC) + "°"
          color: popup.tempColor(w.cpuTempC)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          visible: w.gpuTempC >= 0
          text: "GPU " + Math.round(w.gpuTempC) + "°"
          color: popup.tempColor(w.gpuTempC)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          visible: w.nvmeTempC >= 0
          text: "NVMe " + Math.round(w.nvmeTempC) + "°"
          color: popup.tempColor(w.nvmeTempC)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      // ---- M · Memory -----------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        title: "M · Memory"
        summary: w.fmtGb(w.ramUsedMb) + " / " + w.fmtGb(w.ramTotalMb)

        // Master gauge: used % as a rounded bar with pct text.
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            radius: 5
            color: "#232733"
            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * Math.min(1, w.ramPct / 100)
              height: parent.height
              radius: 5
              color: popup.levelColor(w.ramPct)
            }
          }
          Text { text: Math.round(w.ramPct) + "%"; color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        }
        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 46
          series: w.histRam
          stroke: "#e0af68"          // amber — memory's color
          fill: "#e0af68"
        }
        HistBars { series: w.histRam; activeColor: "#e0af68" }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)
          Text { text: "used " + w.fmtGb(w.ramUsedMb); color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: "buff " + w.fmtGbB(w.buffersKb); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: "cache " + w.fmtGbB(w.cachedKb); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { visible: w.swapUsedKb > 1024; text: "swap " + w.fmtGbB(w.swapUsedKb); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // ---- C · CPU ---------------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        title: "C · CPU"
        summary: w.cpuPct < 0 ? "--%" : Math.round(w.cpuPct) + "%"

        // Master gauge.
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            radius: 5
            color: "#232733"
            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * Math.min(1, Math.max(0, w.cpuPct) / 100)
              height: parent.height
              radius: 5
              color: popup.levelColor(w.cpuPct)
            }
          }
          Text { text: w.cpuPct < 0 ? "--%" : Math.round(w.cpuPct) + "%"; color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        }
        // Total % (green) + busiest core % (violet) overlaid.
        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 46
          series: w.histCpu
          seriesB: w.histCoreMax
          stroke: "#9ece6a"
          strokeB: "#bb9af7"
          fill: "#9ece6a"
        }
        HistBars { series: w.histCpu; activeColor: "#9ece6a" }
        Text {
          text: "load " + w.load1.toFixed(2) + " / " + w.load5.toFixed(2) + " / " + w.load15.toFixed(2)
            + "   ·   " + w.corePcts.length + " threads"
          color: popup.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        // Rainbow per-core histogram.
        CoreGrid {
          Layout.fillWidth: true
          corePcts: w.corePcts
          perRow: 12
          barH: 30
        }
      }

      // ---- N · Network -----------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        title: "N · Network"
        summary: w.netDownBps < 0 ? "--" : "↓" + w.fmtRate(w.netDownBps) + " ↑" + w.fmtRate(w.netUpBps)

        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 46
          series: w.histNetDown
          seriesB: w.histNetUp
          autoScale: true
          stroke: "#7aa2f7"          // down = blue
          strokeB: "#bb9af7"         // up = violet
          fill: "#7aa2f7"
        }
        // Per-interface live rates (names + arrows, muted).
        Column {
          Layout.fillWidth: true
          spacing: 2
          Repeater {
            model: Object.keys(w.ifRates)
            Text {
              required property string modelData
              readonly property var r: w.ifRates[modelData]
              text: modelData + "   ↓" + w.fmtRate(r ? r[0] : 0) + "   ↑" + w.fmtRate(r ? r[1] : 0)
              color: popup.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
        Text {
          text: "histogram: log-scale activity, 1 Gbit/s = right edge"
          color: popup.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        HistBars {
          series: w.histNetDown
          logScale: true
          activeColor: "#7aa2f7"
        }
      }

      // ---- D · Disk --------------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        title: "D · Disk"
        summary: w.fmtDisk(w.diskUsedB) + " / " + w.fmtDisk(w.diskTotalB)

        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          series: w.histDiskR
          stroke: "#e5c07b"
          fill: "#e5c07b"
          autoScale: true
        }
        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          series: w.histDiskW
          stroke: "#f7768e"
          fill: "#f7768e"
          autoScale: true
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)
          Text { text: "R " + w.fmtRate(Math.max(0, w.diskReadBps)); color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: "W " + w.fmtRate(Math.max(0, w.diskWriteBps)); color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: Math.round(Math.max(0, w.diskReadIops)) + "/" + Math.round(Math.max(0, w.diskWriteIops)) + " iops"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Item { Layout.fillWidth: true }
          Text { text: Math.round(w.diskPct) + "% full"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // ---- G · GPU ---------------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        visible: w.gpuBusyPct >= 0
        title: "G · GPU"
        summary: w.gpuBusyPct < 0 ? "--" : Math.round(w.gpuBusyPct) + "%"

        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: 46
          series: w.histGpuBusy
          stroke: "#7aa2f7"
          fill: "#7aa2f7"
        }
        HistBars { series: w.histGpuBusy }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)
          Text { text: "power " + (w.gpuPowerMw >= 0 ? (w.gpuPowerMw / 1000).toFixed(1) + "W" : "--"); color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: "VRAM " + (w.vramUsedB >= 0 ? w.fmtRate(w.vramUsedB).replace("0K", "0") + " / " + w.fmtRate(w.vramTotalB) : "--"); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: "GTT " + (w.gttUsedB >= 0 ? w.fmtRate(w.gttUsedB) + " / " + w.fmtRate(w.gttTotalB) : "--"); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Item { Layout.fillWidth: true }
        }
        // VRAM + GTT percent bars
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Text { text: "VRAM"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Rectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 6
            radius: 3
            color: "#2c313a"
            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * Math.min(1, (w.vramUsedB > 0 && w.vramTotalB > 0 ? w.vramUsedB / w.vramTotalB : 0))
              height: parent.height
              radius: 3
              color: "#7aa2f7"
            }
          }
          Text { text: w.vramTotalB > 0 ? Math.round(100 * w.vramUsedB / w.vramTotalB) + "%" : "--"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Item { Layout.fillWidth: true }
          Text { text: "GTT"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Rectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 6
            radius: 3
            color: "#2c313a"
            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * Math.min(1, (w.gttUsedB > 0 && w.gttTotalB > 0 ? w.gttUsedB / w.gttTotalB : 0))
              height: parent.height
              color: "#bb9af7"
              radius: 3
            }
          }
          Text { text: w.gttTotalB > 0 ? Math.round(100 * w.gttUsedB / w.gttTotalB) + "%" : "--"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // ---- P · Processes ----------------------------------------------------
      SysSection {
        Layout.fillWidth: true
        title: "P · Processes"
        summary: w.procs.length + " top by " + (w.procSort === "mem" ? "MEM" : "CPU")

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Text { text: "PID"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Item { Layout.fillWidth: true }
          Text { text: "sort: "; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text {
            text: w.procSort === "mem" ? "MEM%" : "CPU%"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            MouseArea { anchors.fill: parent; onClicked: w.procSort = (w.procSort === "cpu" ? "mem" : "cpu") }
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: 2

          Repeater {
            model: w.sortedProcs

            Rectangle {
              id: procRow
              required property var modelData
              readonly property bool mine: modelData[1] === "gdeyoung"
              readonly property bool isTarget: w.killTarget === modelData[0]
              width: parent ? parent.width : 0
              height: 22
              radius: 3
              color: isTarget ? "#2a2e3a" : (rowMouse.containsMouse ? "#22262e" : "transparent")

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: w.killTarget = (w.killTarget === procRow.modelData[0] ? 0 : procRow.modelData[0])
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: Style.space(6)

                Text { text: String(procRow.modelData[0]); color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Text {
                  Layout.fillWidth: true
                  text: procRow.modelData[2]
                  elide: Text.ElideRight
                  color: procRow.mine ? popup.fg : Qt.darker(popup.fg, 1.6)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Text { text: Number(procRow.modelData[w.procSort === "mem" ? 4 : 3]).toFixed(1) + "%"; color: popup.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Rectangle {
                  visible: procRow.mine
                  width: 42
                  height: 16
                  radius: 3
                  color: "#3b2430"
                  Text { anchors.centerIn: parent; text: "kill"; color: "#f7768e"; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; onClicked: w.killTarget = procRow.modelData[0] }
                }
              }
            }
          }
        }

        // Inline confirm strip (no nested dialog inside the Flickable).
        Rectangle {
          Layout.fillWidth: true
          visible: w.killTarget > 0
          height: 40
          radius: 4
          color: "#2a1e24"
          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: Style.space(8)
            Text {
              Layout.fillWidth: true
              text: "Kill " + w.killName + " (" + w.killTarget + ")?"
              elide: Text.ElideRight
              color: popup.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Rectangle {
              width: 96; height: 22; radius: 3; color: "#3b2430"
              Text { anchors.centerIn: parent; text: w.killAlive ? "Force kill (9)" : "Kill (TERM)"; color: "#f7768e"; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; onClicked: w.doKill(w.killTarget, w.killAlive ? 9 : 15) }
            }
            Rectangle {
              width: 60; height: 22; radius: 3; color: "#232733"
              Text { anchors.centerIn: parent; text: "Cancel"; color: popup.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; onClicked: w.killTarget = 0 }
            }
          }
        }
      }

      Text {
        Layout.topMargin: Style.space(4)
        text: "click a section header to collapse — " + w.histMax + " sample history"
        color: popup.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
