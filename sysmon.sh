#!/bin/bash
# SysMon probe for gdeyoung.sysmon.
# Forked from sysmem.sh in vm.sysmem by jhonoryza (MIT).
#
# Prints exactly one JSON line so the QML widget can JSON.parse it:
#   {"ram_used_mb":1234,"ram_total_mb":31319,
#    "cpu_total":123456,"cpu_idle":65432,
#    "net_rx":123456789,"net_tx":9876543,
#    "disk_used_b":47000000000,"disk_total_b":999000000000}
#
# cpu_* are cumulative jiffies and net_* are cumulative bytes: the widget
# computes CPU% and net rate from deltas between ticks.
set -u

mem_total=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
ram_used=$((mem_total - mem_avail))

# GPU VRAM omitted by design: on iGPU machines the carve-out is tiny, pinned
# near full, and says nothing about real memory pressure. M covers it.

# CPU jiffies: user+nice+system+idle+iowait+irq+softirq+steal ; idle = idle+iowait
read -r cpu_total cpu_idle < <(awk 'NR==1 { print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6 }' /proc/stat)

# Network: cumulative rx/tx bytes across all interfaces except loopback
net_rx=0
net_tx=0
for iface in /sys/class/net/*; do
  [[ $(basename "$iface") == "lo" ]] && continue
  rx=$(cat "$iface/statistics/rx_bytes" 2>/dev/null) || continue
  tx=$(cat "$iface/statistics/tx_bytes" 2>/dev/null) || continue
  net_rx=$((net_rx + rx))
  net_tx=$((net_tx + tx))
done

# Disk: the physical disk backing /home — one number, no per-volume breakdown.
#   disk_total = size of the whole disk (resolved from /home's device upward)
#   disk_used  = used bytes of the main filesystem on that disk (/home's fs)
disk_used=0
disk_total=0
resolve_disk() {  # $1 = device name; echoes whole-disk name (e.g. nvme0n1)
  local cur="/dev/$1" parent
  case "$1" in
    /dev/*) cur="$1" ;;
  esac
  [ -e "$cur" ] || return 1
  while :; do
    parent=$(lsblk -no PKNAME "$cur" 2>/dev/null) || break
    [ -n "$parent" ] || break
    cur="/dev/$parent"
  done
  basename "$cur"
}
if src=$(findmnt -no SOURCE /home 2>/dev/null); then
  src="${src%%\[*}"                      # strip btrfs subvol: /dev/mapper/root[/@home]
  if read -r u _ < <(df -B1 --output=used,size "$src" 2>/dev/null | tail -n 1); then
    [[ $u =~ ^[0-9]+$ ]] && disk_used=$u
  fi
  if disk_dev=$(resolve_disk "$(basename "$src")" 2>/dev/null) && [ -e "/dev/$disk_dev" ]; then
    t=$(lsblk -bno SIZE "/dev/$disk_dev" 2>/dev/null)
    [[ $t =~ ^[0-9]+$ ]] && disk_total=$t
  fi
fi
if [ "$disk_total" -eq 0 ]; then
  # fallback: plain filesystem numbers for /home
  if read -r u t < <(df -B1 --output=used,size /home 2>/dev/null | tail -n 1); then
    [[ $u =~ ^[0-9]+$ ]] && disk_used=$u
    [[ $t =~ ^[0-9]+$ ]] && disk_total=$t
  fi
fi

printf '{"ram_used_mb":%d,"ram_total_mb":%d,"cpu_total":%s,"cpu_idle":%s,"net_rx":%s,"net_tx":%s,"disk_used_b":%s,"disk_total_b":%s}\n' \
  "$ram_used" "$mem_total" "$cpu_total" "$cpu_idle" "$net_rx" "$net_tx" "$disk_used" "$disk_total"
