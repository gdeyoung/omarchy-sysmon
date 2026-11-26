#!/usr/bin/env python3
"""Validate probe output: exactly one strict-JSON line with the expected shape.

Usage: validate_probe.py <probe-script> [--count N]
Runs the probe N times (default 3), fails on any parse error, wrong row
arity, non-numeric numerics, or control characters leaking into strings.
Gate before blaming QML when a model comes up empty (spec risk 9).
"""
import json
import os
import subprocess
import sys

ROW = ["pid", "user", "comm", "pcpu", "pmem", "rss_kb", "state", "args"]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: validate_probe.py <probe-script> [--count N]", file=sys.stderr)
        return 2
    script = sys.argv[1]
    count = 3
    if "--count" in sys.argv:
        count = int(sys.argv[sys.argv.index("--count") + 1])
    fails = 0
    for run in range(count):
        out = subprocess.run(["bash", script], capture_output=True, text=True, timeout=10)
        lines = [l for l in out.stdout.splitlines() if l.strip()]
        if out.returncode != 0:
            print(f"run {run}: exit {out.returncode}: {out.stderr[:200]}", file=sys.stderr)
            fails += 1
            continue
        if len(lines) != 1:
            print(f"run {run}: expected exactly 1 line, got {len(lines)}", file=sys.stderr)
            fails += 1
            continue
        try:
            data = json.loads(lines[0])
        except json.JSONDecodeError as e:
            print(f"run {run}: JSON parse error: {e}", file=sys.stderr)
            fails += 1
            continue
        procs = data.get("procs")
        if not isinstance(procs, list) or not procs:
            print(f"run {run}: no procs array", file=sys.stderr)
            fails += 1
            continue
        bad = 0
        for i, row in enumerate(procs):
            if len(row) != len(ROW):
                print(f"run {run}: row {i} arity {len(row)} != {len(ROW)}", file=sys.stderr)
                bad += 1
                break
            if not isinstance(row[0], int) or isinstance(row[0], bool):
                print(f"run {run}: row {i} pid not int: {row[0]!r}", file=sys.stderr)
                bad += 1
                break
            for j in (3, 4, 5):
                if not isinstance(row[j], (int, float)):
                    print(f"run {run}: row {i} field {ROW[j]} not numeric: {row[j]!r}", file=sys.stderr)
                    bad += 1
                    break
            if bad:
                break
            for j in (1, 2, 6, 7):
                if any(ord(ch) < 0x20 for ch in str(row[j])):
                    print(f"run {run}: row {i} field {ROW[j]} has control chars", file=sys.stderr)
                    bad += 1
                    break
            if bad:
                break
        if bad:
            fails += 1
            continue
        print(f"run {run}: OK {len(procs)} rows")
    return 1 if fails else 0


INTS = ["ram_used_mb", "ram_total_mb", "cpu_total", "cpu_idle", "net_rx", "net_tx",
        "disk_used_b", "disk_total_b", "disk_reads", "disk_rsec", "disk_writes", "disk_wsec"]
NUMS = ["load1", "load5", "load15", "cpu_temp_mc", "gpu_temp_mc", "nvme_temp_mc", "gpu_busy_pct",
        "vram_used_b", "vram_total_b", "gtt_used_b", "gtt_total_b", "gpu_power_mw"]
# Cumulative counters that may never go backwards. net_* are excluded on purpose:
# an interface leaving (tailscale0 down) legitimately lowers the sum.
MONOTONIC = ["cpu_total", "disk_reads", "disk_writes"]


def validate_sysmon(script: str, count: int) -> int:
    """sysmon.sh contract: one strict-JSON line, typed fields, counters never decrease."""
    fails = 0
    prev = None
    for run in range(count):
        out = subprocess.run(["bash", script], capture_output=True, text=True, timeout=10)
        lines = [l for l in out.stdout.splitlines() if l.strip()]
        if out.returncode != 0 or len(lines) != 1:
            print(f"run {run}: exit {out.returncode}, {len(lines)} line(s): {out.stderr[:200]}", file=sys.stderr)
            fails += 1
            continue
        try:
            d = json.loads(lines[0])
        except json.JSONDecodeError as e:
            print(f"run {run}: JSON parse error: {e}", file=sys.stderr)
            fails += 1
            continue
        bad = []
        for k in INTS:
            if not isinstance(d.get(k), int) or isinstance(d.get(k), bool):
                bad.append(f"{k}={d.get(k)!r} not int")
        for k in NUMS:
            if not isinstance(d.get(k), (int, float)) or isinstance(d.get(k), bool):
                bad.append(f"{k}={d.get(k)!r} not numeric")
        if not (isinstance(d.get("cpu_cores"), list) and d["cpu_cores"]
                and all(isinstance(c, list) and len(c) == 2 for c in d["cpu_cores"])):
            bad.append("cpu_cores not [[total,idle],...]")
        if not (isinstance(d.get("vols"), list) and d["vols"]
                and all(isinstance(v, list) and len(v) >= 3 and isinstance(v[0], str) for v in d["vols"])):
            bad.append("vols not [[mount,used,size,(fstype)],...]")
        if not (isinstance(d.get("disks"), list) and all(
                isinstance(x, dict) and isinstance(x.get("n"), str)
                and all(isinstance(x.get(f), int) for f in ("rs", "ws", "ri", "wi")) for x in d["disks"])):
            bad.append("disks not [{n,rs,ws,ri,wi},...]")
        if d.get("ram_total_mb", 0) <= 0 or d.get("disk_total_b", 0) <= 0:
            bad.append("ram_total_mb/disk_total_b must be > 0")
        if prev is not None:
            bad += [f"{k} decreased across runs" for k in MONOTONIC
                    if k in d and k in prev and d[k] < prev[k]]
        if bad:
            print(f"run {run}: FAIL " + "; ".join(bad[:6]), file=sys.stderr)
            fails += 1
        else:
            print(f"run {run}: OK cores={len(d['cpu_cores'])} vols={len(d['vols'])} disks={len(d['disks'])}")
        prev = d
    return 1 if fails else 0


if __name__ == "__main__":
    # Match the file NAME, never the whole path: a parent directory called
    # "sysmon-port" once routed procprobe.sh into the sysmon checks.
    if len(sys.argv) >= 2 and os.path.basename(sys.argv[1]).startswith("sysmon"):
        n = int(sys.argv[sys.argv.index("--count") + 1]) if "--count" in sys.argv else 3
        sys.exit(validate_sysmon(sys.argv[1], n))
    sys.exit(main())
