# Omarchy SysMon

![SysMon — one panel, four tabs](preview.png)

Live system stats in the [Omarchy](https://omarchy.org/) bar — a compact letter+meter strip that expands into a fixed-frame, four-tab task-manager popup: performance cards (CPU + per-core grid, memory, GPU, network, disk), per-volume and per-device disk I/O, a filterable process table with a one-minute CPU history per process, and a fastfetch-grade hardware inventory.

```
bar (compact):   ▎M  ▎C  ▎N  ▎D        ← click to open
                 └ hover for values
```

## Screenshots

### The bar

One letter, one 5px meter per stat — the numbers live in the hover tooltip. Zero noise until you click:

![bar widget — compact M C N D strip](docs/panel-bar.png)

### Performance tab

Everything, live-scrolling: CPU as total % (green) with the busiest core overlaid (violet) over a per-core grid, memory with a used / buffers / cache / available legend, GPU load with power draw and VRAM/GTT meters, network, and disk. Ring buffers run whether or not the popup is open, so it opens with minutes of warm history already drawn:

![Performance tab](docs/panel-performance.png)

### Disks tab

A gauge for every mounted volume with the backing device's live read/write rate, and a per-device R/W spark beside it — local filesystems only, deduped by source device, so multi-mountpoint btrfs shows once:

![Disks tab](docs/panel-disks.png)

### Processes tab

The task-manager view: filter by name, user or pid; click a column to sort; a one-minute CPU spark per process. Select a row, press **End process**, and a confirm strip offers TERM first — if the process survives, it becomes **Force kill (9)**. There is no kill control on the rows, so nothing misfires on a hover. Footer totals follow the filter:

![Processes tab](docs/panel-processes.png)

### Hardware tab

Fastfetch-grade machine inventory, probed once when the popup opens — no root, no Python, no extra dependencies: vendor/product/board, BIOS version + date, CPU (model, cores/threads, max clock, L3), memory, GPU, displays + native mode, physical storage + size, network controllers with their kernel drivers, audio cards, battery model/technology/health, Bluetooth, USB/PCI device counts, OS + kernel, and uptime. Anything your hardware doesn't expose just hides.

![Hardware tab](docs/panel-hardware.png)

### What's new

- **v0.6.1** — Every probe run has a hard deadline. The widget starts each probe under `timeout(1)` (3 s for the bar tick and the process table, 5 s for the hardware inventory), so a stalled helper is terminated together with all of its descendants and the next tick retries; a run that hit its deadline keeps the previous sample instead of applying partial JSON. The process probe enforces its caps in the producer — the top 1500 by CPU plus filter matches, at most 2000 rows and 1 MiB, user/name/args cut to fixed widths — and reports `"truncated":true`, which the Processes footer shows. Each hardware helper gets a 1 s bound, so one hung helper costs its own field, never the inventory. `install.sh` is gone: the standard `omarchy plugin add` is the only install path. `status` gains a `probe` block (exit codes, failures, deadlines, truncation). From the marketplace review, #16029.
- **v0.6.0** — Look-and-feel pass modeled on the KDE Plasma SysMon plasmoid. Fixed 960×640 frame. Performance rebuilt as cards: CPU total + busiest core, 24-cell per-core grid, memory legend, GPU power/VRAM/GTT, network, disk. Processes: filter box, six sortable columns, one-minute CPU history per row, kill-confirm strip (TERM → Force kill). Disks: per-device R/W sparks. Hardware: one fastfetch-style list. IPC gains `tab hw`, `filter`, `sort`, `select`, `scroll` and a richer `status`. Probe fixes: disk resolution through LUKS (`lsblk -s` inverse walk), kernel-thread names (`migration/0` no longer renders as `0`), Qt version via `qtpaths`. `Text.PlainText` extended to every text fed by device, interface or process strings.
- **v0.5.1** — Security: hardware-derived strings (DMI product/board, device names) rendered with `textFormat: Text.PlainText` so markup-shaped device strings can never trigger rich-text loading. Probe: concise GPU name on bracketless-vendor devices (Intel). Tests green.
- **v0.5.0** — Hardware tab: fastfetch-grade unprivileged inventory (new `sysinfo-probe.sh`, popup widened to fit).

Forked from [vm.sysmem](https://github.com/jhonoryza/omarchy-sysmem) by jhonoryza (MIT).

## Bar

Four groups, one letter + one 5px level meter each (numbers live in the hover tooltip and the popup). `barMode: values` in the plugin settings restores the original full readouts (`M 10.5/30.5G  C 12%  N ↓1.2M↑240K  D 44G/930G`).

| Letter | Stat | Bar fill | Source |
|---|---|---|---|
| M | RAM used % | green/amber/red (70/90) | `/proc/meminfo` |
| C | CPU utilization | green/amber/red | `/proc/stat` jiffy deltas |
| N | ↓/↑ rate | blue, log-scale activity (1 Gbit/s ≈ full) | `/sys/class/net/*/statistics` deltas |
| D | whole-disk used % | green/amber/red | `df` + `lsblk` |

Left-click opens the detail popup. Right/middle-click refreshes.

## Popup

A task-manager view anchored under the widget: a fixed 960×640 frame, four tabs — **Performance / Disks / Processes / Hardware**. Only the process and hardware lists scroll; everything else fits.

- **Header** — CPU/GPU/NVMe temperatures, threshold-colored, plus the sample time.
- **Performance** — left column: **C · CPU** (total % green + busiest core violet, per-core grid, load averages) and **M · Memory** (master gauge, amber time-series, used/buffers/cache/available legend). Right column: **G · GPU** (load, power draw, VRAM and GTT meters — hides when no GPU reports), **N · Network** (down + up, top interfaces), **D · Disk**.
- **Disks** — a gauge per mounted volume with the device's live R/W, and per-device R/W sparks.
- **Processes** — filter, sortable columns, a one-minute CPU spark per process, and a two-step kill behind a confirm strip: TERM first; if the process survives, **Force kill (9)**. A process you don't own ends in a visible *no permission* line, never a silent failure. The list is the top 1500 by CPU plus your filter's matches, capped at 2000 rows and 1 MiB; the footer says when a cap applied.
- **Hardware** — the inventory in one fastfetch-style list.

While the popup is open the charts tick at 1 s and the process table at 2 s; history ring buffers (180 samples) are kept whether or not the popup is open, so it opens with ~3–6 minutes of warm history. The per-process CPU history is kept only while the popup is open, so the `1m` column fills in over its first minute.

VRAM is popup-only on purpose: on the machine this was built on the 512 MB carve-out sits pinned near full, which makes it noise in a bar but useful context in a detail view.

## IPC

```bash
omarchy-shell gdeyoung.sysmon open            # open the popup
omarchy-shell gdeyoung.sysmon close
omarchy-shell gdeyoung.sysmon toggle
omarchy-shell gdeyoung.sysmon tab perf        # perf | disk | procs | hw
omarchy-shell gdeyoung.sysmon refresh         # all instances
omarchy-shell gdeyoung.sysmon filter sleep    # processes: substring on name / user / pid ("" clears)
omarchy-shell gdeyoung.sysmon sort rss        # cpu | mem | pid | name | user | rss
omarchy-shell gdeyoung.sysmon select 411987   # processes: select the row for a pid
omarchy-shell gdeyoung.sysmon scroll 600      # processes: scroll the list to y (clamped)
omarchy-shell gdeyoung.sysmon status          # JSON: open state, tab, frame geometry, series head,
                                               #      last probe values, process view + kill state, hardware,
                                               #      probe lifecycle (exit codes, failures, deadlines, truncation)
```

The verbs exist for scripts and tests. Killing is deliberately not one of them: it takes a click on the confirm strip.

## Requirements

- Omarchy 4.x with its Quickshell bar (uses `qs.Commons` / `qs.Ui` and the `BarWidget` base)
- Bash + coreutils (`awk`, `df`) — no other dependencies

## Install

```bash
omarchy plugin add https://github.com/gdeyoung/omarchy-sysmon.git --enable
```

That is the whole install. The plugin lands under `~/.config/omarchy/plugins/gdeyoung.sysmon`, is enabled, joins the bar's right section (the manifest's `defaultSection`) in the running shell, and updates with `omarchy plugin update`. To move it: `omarchy bar move gdeyoung.sysmon --section right --index 3`. SysMon supersedes `vm.sysmem`; disable that widget if it is present (`omarchy plugin disable vm.sysmem`).

There is no `install.sh`. The v0.6.0 one had drifted from the tree — it copied five files, then stopped on a sixth that no longer existed — so an install from a clone could leave a partial plugin behind. One install path, the standard one.

## Uninstall

```bash
omarchy plugin remove gdeyoung.sysmon
omarchy restart shell
```

## How it works

A `Process` runs `sysmon.sh` every tick; the script prints exactly one JSON line (32 keys: per-core jiffies, load, swap, temps, GPU counters, disk IO, per-interface bytes, mounted volumes) and the widget parses it. Cumulative counters are converted to rates in the widget between ticks — the probe stays stateless (~150 ms per run). While the popup is open a second probe (`procprobe.sh`, ~30 ms) feeds the process table every 2 s, and `sysinfo-probe.sh` runs once per open (~0.7 s) for the Hardware tab. Charts are one `Canvas` sparkline each; no extra processes while idle.

Every probe run has a hard deadline (`Probe.js`): the widget starts it under `timeout(1)`, so a stalled helper is terminated with all of its descendants, incomplete output is never applied, and the next tick retries. The hardware inventory's own helpers are each bounded to 1 s.

## License

MIT
