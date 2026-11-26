import QtQuick
import qs.Commons

// HwTab — one full-width neofetch-style table: section headers + label:value
// rows, everything the system will tell us — host, shell stack, CPU, memory,
// GPU with driver/module/vBIOS, displays, disks with serials+transport, NICs
// with drivers, audio, board identity, BIOS, I/O counts, battery.
// Data is the one-shot hwinfo probe (static facts; refreshed on first popup
// open). Uptime ticks via sysmon.upS (the 2s probe tick).
Item {
  id: tab
  required property var sysmon

  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.darker(tab.fg, 1.5)

  readonly property string uptime: {
    const up = sysmon.upS || 0
    const d = Math.floor(up / 86400)
    const h = Math.floor((up % 86400) / 3600)
    const m = Math.floor((up % 3600) / 60)
    return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
  }

  function ghz(mhz) { return mhz > 0 ? (Math.round(mhz / 100) / 10) + "GHz" : "" }
  function g(memB) {
    const u = ["B", "KiB", "MiB", "GiB", "TiB"]
    let v = memB, i = 0
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
    return (i === 0 ? v : v.toFixed(v < 10 ? 2 : 1)) + " " + u[i]
  }

  // ---- row model: [{t:"s",label} | {t:"k",label,value,muted?}] ------------
  readonly property var rows: {
    const w = sysmon.hwinfo
    const r = []
    const sect = (label) => r.push({ t: "s", label: label })
    const kv = (label, value, isMuted) => {
      if (value !== "" && value !== undefined) r.push({ t: "k", label: label, value: value, muted: !!isMuted })
    }
    if (!w) return r
    const os = w.os || {}
    const cpu = w.cpu || {}
    const mem = w.mem || {}
    const id = w.identity || {}
    const io = w.io || {}
    const s = (v) => (v === undefined || v === null) ? "" : String(v)

    sect("host")
    kv("hostname", s(os.hostname))
    kv("os", s(os.pretty) + " \u00B7 " + s(cpu.arch))
    kv("kernel", s(os.kernel))
    kv("uptime", tab.uptime)
    kv("boot", s(os.boot) + (s(os.virt) !== "" && os.virt !== "none" ? " \u00B7 " + s(os.virt) + " guest" : " \u00B7 bare metal"))

    sect("desktop")
    const shell = []
    if (s(os.hyprland) !== "") shell.push("Hyprland " + s(os.hyprland))
    if (s(os.quickshell) !== "") shell.push("Quickshell " + s(os.quickshell))
    kv("shell", shell.join(" \u00B7 "))
    kv("plasma", s(os.plasma) !== "" ? "KDE Plasma " + s(os.plasma) : "")
    kv("toolkit", (s(os.qt) !== "" ? "Qt " + s(os.qt) : "") + (s(os.kf6) !== "" ? (s(os.qt) !== "" ? " \u00B7 " : "") + "Frameworks " + s(os.kf6) : ""))

    sect("cpu")
    kv("model", s(cpu.model))
    kv("topology", cpu.cores !== null && cpu.cores !== undefined
       ? cpu.cores + " cores \u00B7 " + cpu.threads + " threads \u00B7 " + tab.ghz(cpu.max_mhz)
         + (cpu.l3_kb ? " \u00B7 L3 " + Math.round(cpu.l3_kb / 1024) + "M" : "")
       : s(cpu.threads) + " threads")

    sect("memory")
    kv("installed", tab.g((mem.total_mb || 0) * 1048576)
       + (s(mem.type) !== "" ? " \u00B7 " + s(mem.type) + (s(mem.speed) !== "" ? " @ " + s(mem.speed) : "") : "")
       + (mem.banks !== null && mem.banks !== undefined ? " \u00B7 " + mem.banks + " DIMM" + (mem.banks === 1 ? "" : "s") : ""))
    kv("swap", sysmon.swapTotalKb > 0 ? tab.g(sysmon.swapTotalKb * 1024) + " total" : "none")

    sect("graphics")
    kv("gpu", s(w.gpu) !== "" ? s(w.gpu) : "\u2014")
    kv("driver", (s(w.gpu_driver) !== "" ? s(w.gpu_driver) : "")
       + (s(w.gpu_module) !== "" ? " " + s(w.gpu_module) : "")
       + (s(w.gpu_vbios) !== "" ? " \u00B7 vBIOS " + s(w.gpu_vbios) : ""), s(w.gpu_driver) === "")
    const displays = w.displays || []
    for (let i = 0; i < displays.length; i++)
      kv(i === 0 ? "displays" : "", s(displays[i].connector) + " \u00B7 " + s(displays[i].mode))

    sect("storage")
    const disks = w.disks || []
    for (let i = 0; i < disks.length; i++) {
      const d = disks[i]
      kv(i === 0 ? "disks" : "",
         s(d.dev) + " \u00B7 " + s(d.name) + " \u00B7 " + s(d.size)
         + (s(d.serial) !== "" ? " \u00B7 " + s(d.serial) : "")
         + (s(d.transport) !== "" ? " \u00B7 " + s(d.transport) : ""))
    }

    sect("network")
    const net = w.net || []
    for (let i = 0; i < net.length; i++)
      kv(i === 0 ? "controllers" : "", s(net[i].name) + (net[i].driver ? " \u00B7 " + s(net[i].driver) : ""))

    const audio = w.audio || []
    if (audio.length > 0) {
      sect("audio")
      for (let i = 0; i < audio.length; i++)
        kv(i === 0 ? "cards" : "", s(audio[i]))
    }

    sect("board")
    kv("board", (s(id.board_vendor) !== "" ? s(id.board_vendor) + " " : "")
       + s(id.board) + (s(id.board_version) !== "" ? " \u00B7 " + s(id.board_version) : ""))
    kv("serial", s(id.board_serial) !== "" ? s(id.board_serial) : "root-gated", s(id.board_serial) === "")
    if (s(id.product) !== "" && id.product !== "System Product Name")
      kv("product", s(id.product) + (s(id.product_version) !== "" && id.product_version !== "System Version" ? " \u00B7 " + s(id.product_version) : ""))
    kv("bios", (s(id.bios_vendor) !== "" ? s(id.bios_vendor) + " " : "")
       + s(id.bios_version) + (s(id.bios_date) !== "" ? " \u00B7 " + s(id.bios_date) : ""))

    sect("i/o")
    kv("devices", s(io.usb_devices) + " USB \u00B7 " + s(io.pci_devices) + " PCI" + (w.bluetooth ? " \u00B7 Bluetooth" : ""))
    if (w.battery)
      kv("battery", s(w.battery.manufacturer) + " " + s(w.battery.model) + " \u00B7 " + s(w.battery.tech)
         + " \u00B7 " + s(w.battery.health_pct) + "% health")
    return r
  }

  HwList { owner: tab }
}
