#!/usr/bin/env node
// probe.test.mjs — contract tests for the three SysMon probes (v0.6 / KDE-parity).
// Run: node --test tests/probe.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawn, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { performance } from "node:perf_hooks";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const sh = (script, args = [], timeout = 10_000) =>
  execFileSync("/usr/bin/bash", [path.join(root, script), ...args], { encoding: "utf8", timeout });
const oneJson = (script, args = []) => {
  const lines = sh(script, args).split("\n").filter((l) => l.trim());
  assert.equal(lines.length, 1, `${script}: expected exactly one line, got ${lines.length}`);
  return JSON.parse(lines[0]);
};
const validate = (script, extra = []) =>
  spawnSync("python3", [path.join(root, "tests/validate_probe.py"), path.join(root, script), ...extra], { encoding: "utf8" });

// --- sysmon.sh -----------------------------------------------------------------
test("sysmon.sh: validator green over 3 runs", () => {
  const r = validate("sysmon.sh", ["--count", "3"]);
  assert.equal(r.status, 0, r.stderr || r.stdout);
  assert.match(r.stdout, /OK cores=\d+ vols=\d+ disks=\d+/);
});

test("sysmon.sh: vols carry a filesystem type as the 4th element", () => {
  const d = oneJson("sysmon.sh");
  assert.ok(d.vols.length >= 1, "no volumes");
  for (const v of d.vols) {
    assert.ok(Array.isArray(v) && v.length >= 4, `vol row arity ${v?.length}`);
    assert.equal(typeof v[0], "string");
    assert.ok(Number.isInteger(v[1]) && Number.isInteger(v[2]), "used/size must be ints");
    assert.equal(typeof v[3], "string");
    assert.ok(v[3].length > 0, `empty fstype for ${v[0]}`);
  }
});

test("sysmon.sh: disks[] lists whole disks only — never partitions", () => {
  const d = oneJson("sysmon.sh");
  assert.ok(Array.isArray(d.disks));
  assert.ok(d.disks.length >= 1, "no whole disks reported");
  for (const x of d.disks) {
    assert.match(x.n, /^(nvme\d+n\d+|[sh]d[a-z]+|vd[a-z]+|mmcblk\d+)$/, `partition leaked: ${x.n}`);
    for (const f of ["rs", "ws", "ri", "wi"]) assert.ok(Number.isInteger(x[f]) && x[f] >= 0, `${x.n}.${f}`);
  }
});

test("sysmon.sh: whole-disk IO counters advance the disk section, not a partition", () => {
  const d = oneJson("sysmon.sh");
  assert.equal(typeof d.disk_dev, "string");
  assert.ok(d.disks.some((x) => x.n === d.disk_dev), `disk_dev ${d.disk_dev} missing from disks[]`);
});

// --- procprobe.sh v2 -----------------------------------------------------------
test("procprobe.sh: validator green over 3 runs", () => {
  const r = validate("procprobe.sh", ["--count", "3"]);
  assert.equal(r.status, 0, r.stderr || r.stdout);
});

test("procprobe.sh: row shape [pid,user,name,pcpu,pmem,rss_kb,state,args]", () => {
  const d = oneJson("procprobe.sh");
  assert.ok(d.procs.length > 0);
  for (const [pid, user, name, pcpu, pmem, rss, state, args] of d.procs) {
    assert.ok(Number.isInteger(pid) && pid > 0, `pid ${pid}`);
    assert.equal(typeof user, "string");
    assert.equal(typeof name, "string");
    assert.ok(name.length > 0, "empty name");
    assert.ok(!/\s/.test(name), `name must be single-token, got "${name}"`);
    assert.ok(typeof pcpu === "number" && typeof pmem === "number");
    assert.ok(Number.isInteger(rss) && rss >= 0, `rss_kb ${rss}`);
    assert.match(state, /^[RSDZTtWXIKP?]$/, `state "${state}"`);
    assert.equal(typeof args, "string");
  }
});

test("procprobe.sh: names carry no spaces even when the command does", () => {
  // `ps comm` for "tmux: server" used to shift every later column (v0.7 audit).
  const d = oneJson("procprobe.sh");
  assert.ok(d.procs.every((r) => !/\s/.test(r[2])), JSON.stringify(d.procs.filter((r) => /\s/.test(r[2])).slice(0, 3)));
});

test("procprobe.sh: a kernel thread keeps its full name (migration/0 is not \"0\")", () => {
  // The basename rule is for absolute paths (/usr/bin/sleep -> sleep). Kernel
  // threads arrive as "[migration/0]"; taking the text after the last slash
  // produced rows named "0", "1", "2"… at the top of an a–z list.
  // The name is the FIRST token (some thread names carry a space, e.g.
  // "[mt76-tx phy0]"); the full text lives in the args column.
  const d = oneJson("procprobe.sh");
  const threads = d.procs.filter((r) => /^\[.*\]$/.test(r[7]));
  assert.ok(threads.length > 10, `expected kernel threads on this host, saw ${threads.length}`);
  const broken = threads.filter((r) => r[2] !== r[7].slice(1, -1).split(/\s/)[0]);
  assert.deepEqual(broken.map((r) => `${r[2]} <- ${r[7]}`).slice(0, 5), []);
});

test("procprobe.sh: a 0%-CPU process is findable through the filter argument", async () => {
  // Rename argv0 so the row is findable by name; a plain `sleep 30` sits at 0% CPU.
  // The test process owns the child directly — a `bash -c '... &'` job does not
  // survive its parent on every host (it did not on the Omarchy dev box).
  const marker = `sysmon-probe-test-${process.pid}`;
  const planted = spawn("/usr/bin/sleep", ["30"], { argv0: marker, stdio: "ignore" });
  await new Promise((resolve, reject) => {
    planted.once("spawn", resolve);
    planted.once("error", reject);
  });
  try {
    const d = oneJson("procprobe.sh", [marker]);
    const row = d.procs.find((r) => r[0] === planted.pid);
    assert.ok(row, `pid ${planted.pid} (argv0 ${marker}) not in filtered output`);
    assert.equal(row[2], marker);
    assert.equal(row[6], "S", "a sleeping process reports state S");
  } finally {
    planted.kill();
  }
});

test("procprobe.sh: JSON.parse + sort stays under 8 ms", () => {
  const raw = sh("procprobe.sh");
  const t0 = performance.now();
  const d = JSON.parse(raw);
  d.procs.sort((a, b) => b[3] - a[3]);
  const ms = performance.now() - t0;
  assert.ok(ms < 8, `parse+sort took ${ms.toFixed(2)} ms for ${d.procs.length} rows`);
});

test("procprobe.sh: per-process values match a parallel ps capture", () => {
  const d = oneJson("procprobe.sh");
  // pid, %cpu (lifetime average), %mem, elapsed seconds
  const ps = execFileSync("/usr/bin/ps", ["-eo", "pid=,pcpu=,pmem=,etimes=", "--no-headers"], { encoding: "utf8" });
  const rows = new Map();
  let n = 0;
  for (const line of ps.split("\n")) {
    if (!line.trim()) continue;
    const [pid, c, m, age] = line.trim().split(/\s+/).map(Number);
    if (Number.isFinite(pid)) { rows.set(pid, [c, m, age]); n++; }
  }
  // A lifetime average moves fast for a process that just started (the test runner
  // itself reads ~99% for its first seconds), so compare only processes alive for
  // more than 30 s; take the 20 heaviest of those by CPU. Rows carry one decimal.
  const stable = d.procs
    .filter((r) => rows.has(r[0]) && rows.get(r[0])[2] > 30)
    .sort((a, b) => rows.get(b[0])[0] - rows.get(a[0])[0])
    .slice(0, 20);
  assert.ok(stable.length >= 5, `only ${stable.length} long-lived processes to compare`);
  for (const r of stable) {
    const [c, m] = rows.get(r[0]);
    assert.ok(Math.abs(r[3] - c) <= 0.05 + c * 0.005, `pid ${r[0]} ${r[2]}: cpu row ${r[3]} vs ps ${c}`);
    assert.ok(Math.abs(r[4] - m) <= 0.05 + m * 0.005, `pid ${r[0]} ${r[2]}: mem row ${r[4]} vs ps ${m}`);
  }
  // Processes come and go between two captures a few ms apart; allow a little churn.
  assert.ok(Math.abs(d.procs.length - n) <= Math.max(3, n * 0.02), `row count ${d.procs.length} vs ps ${n} (cap hit?)`);
});

// --- sysinfo-probe.sh v3 -------------------------------------------------------
test("sysinfo-probe.sh: reports the running shell stack (Omarchy/Quickshell or Plasma)", () => {
  const d = oneJson("sysinfo-probe.sh");
  for (const k of ["plasma", "hyprland", "quickshell", "qt"]) {
    assert.equal(typeof d.os[k], "string", `os.${k} missing`);
  }
  const runningOmarchy = readFileSync("/etc/os-release", "utf8").includes("Omarchy");
  if (runningOmarchy) {
    assert.match(d.os.hyprland, /^\d+\.\d+/, `hyprland "${d.os.hyprland}"`);
    assert.match(d.os.quickshell, /^\d+\.\d+/, `quickshell "${d.os.quickshell}"`);
    assert.equal(d.os.plasma, "");
  }
});

test("sysinfo-probe.sh: identity carries board + serial fields (root-gated allowed)", () => {
  const d = oneJson("sysinfo-probe.sh");
  for (const k of ["board_vendor", "board_version", "board_serial", "product_version", "product_serial", "bios_vendor"]) {
    assert.equal(typeof d.identity[k], "string", `identity.${k} missing`);
  }
  assert.ok(d.disks.every((x) => typeof x.serial === "string" && typeof x.transport === "string" && typeof x.dev === "string"));
});
