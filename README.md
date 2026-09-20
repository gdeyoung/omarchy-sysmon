# Omarchy SysMon

Live system stats in the [Omarchy](https://omarchy.org/) bar: memory, CPU, network rate, and whole-disk usage — four compact groups, one widget.

```
▎M 10.5/30.5G  ▎C 12%  ▎N ↓1.2M↑240K  ▎D 44G/930G
```

Forked from [vm.sysmem](https://github.com/jhonoryza/omarchy-sysmem) by jhonoryza (MIT).

## Groups

| Icon | Stat | Source | Notes |
|---|---|---|---|
| M | RAM used/total | `/proc/meminfo` | `MemTotal − MemAvailable` |
| C | CPU utilization | `/proc/stat` jiffy deltas | computed in the widget between ticks |
| N | ↓down ↑up rate | `/sys/class/net/*/statistics` deltas | sums every interface except `lo` (includes `tailscale0`); bar = log-scale activity meter (1 Gbit/s ≈ full) |
| D | whole-disk used/total | `df` + `lsblk` | used bytes of the main filesystem vs. the size of the physical disk it lives on — one number for "how full is the drive" |

VRAM is deliberately not shown: on integrated-GPU machines (like the laptop this was built on) the dedicated carve-out is tiny, pinned near 100%, and says nothing about real memory pressure. `M` covers memory; if you want VRAM, see [vm.sysmem](https://github.com/jhonoryza/omarchy-sysmem).

## Requirements

- Omarchy 4.x with its Quickshell bar (uses `qs.Commons` / `qs.Ui` and the `BarWidget` base)
- Bash + coreutils (`awk`, `df`) — no other dependencies

## Install

```bash
git clone https://github.com/gdeyoung/omarchy-sysmon.git
cd omarchy-sysmon
./install.sh
omarchy restart shell
```

The installer is idempotent and non-destructive (backs up replaced files with `.bak.<timestamp>`). It installs the widget, enables it, places it in the bar's right section, and — if the `vm.sysmem` widget is present — disables it (SysMon supersedes it: RAM was its only non-overlapping stat).

## Uninstall

```bash
omarchy plugin remove gdeyoung.sysmon
omarchy restart shell
```

## How it works

Same architecture as vm.sysmem: a `Process` runs `sysmon.sh` every `refreshSeconds`, the script prints exactly one JSON line, and the widget parses it. Cumulative counters (CPU jiffies, network bytes) are kept as previous-tick state in the widget and converted to rates there — so the probe stays stateless.

One probe for five stats instead of five widgets for five stats: fewer processes per tick, fixed-width columns so the bar never shifts, one tooltip with everything.

## License

MIT
