#!/usr/bin/env node
// hw-model.test.mjs — validate sysinfo-probe.sh JSON + formatting rules the
// Hardware tab depends on. Run: node tests/hw-model.test.mjs
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
let pass = 0, fail = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { pass++; console.log(`  ok ${name}`); }
  else { fail++; console.log(`  FAIL ${name} ${extra}`); }
};

// --- probe runs and yields one JSON line -----------------------------------
const out = execFileSync("/usr/bin/bash", [path.join(root, "sysinfo-probe.sh")], {
  encoding: "utf8", timeout: 10_000,
});
const lines = out.trim().split("\n");
ok("one line", lines.length === 1, `got ${lines.length}`);
let d = null;
try { d = JSON.parse(lines[0]); ok("parses", true); }
catch (e) { ok("parses", false, e.message); process.exit(1); }

// --- top-level shape ---------------------------------------------------------
ok("identity block", d.identity && typeof d.identity.product === "string");
ok("bios version", typeof d.identity.bios_version === "string" && d.identity.bios_version.length > 0);
ok("cpu block", d.cpu && typeof d.cpu.model === "string" && d.cpu.model.length > 0);
ok("cpu threads", Number.isInteger(d.cpu.threads) && d.cpu.threads > 0);
ok("mem total", Number.isInteger(d.mem.total_mb) && d.mem.total_mb > 0);
ok("gpu string", typeof d.gpu === "string");
ok("os block", d.os && typeof d.os.kernel === "string" && d.os.kernel.length > 0);
ok("uptime", Number.isInteger(d.os.uptime_s) && d.os.uptime_s > 0);

// --- arrays are arrays (never [null] — regression: old [null] bug) -----------
for (const k of ["displays", "disks", "net", "audio"]) {
  ok(`${k} is array`, Array.isArray(d[k]) && !d[k].some((x) => x === null || x === undefined));
}

// --- array element shape ------------------------------------------------------
if (d.disks.length) ok("disk shape", d.disks.every((x) => typeof x.name === "string" && typeof x.size === "string"));
if (d.displays.length) ok("display shape", d.displays.every((x) => typeof x.connector === "string" && typeof x.mode === "string"));
if (d.net.length) ok("net shape", d.net.every((x) => typeof x.name === "string" && typeof x.driver === "string"));
if (d.audio.length) ok("audio strings", d.audio.every((x) => typeof x === "string"));

// --- zram/loop excluded from storage -------------------------------------------
ok("no zram in disks", !d.disks.some((x) => /^\/dev\/zram|^zram/.test(x.name) || /zram/i.test(x.name)));

// --- no vendor-bracket bloat in gpu (regression: "(rev c1)" / "Advanced Micro") --
ok("gpu concise", !/rev [0-9a-f]|Advanced Micro|NVIDIA Corporation|Intel Corp/i.test(d.gpu), `got "${d.gpu}"`);

// --- net names are concise (no "Network Adapter" suffix bloat) ------------------
if (d.net.length) ok("net concise", d.net.every((x) => x.name.length < 60), JSON.stringify(d.net.map((x) => x.name)));

// --- battery: object or null, never partial -------------------------------------
ok("battery shape", d.battery === null || (typeof d.battery === "object" &&
  (typeof d.battery.health_pct === "number" || d.battery.health_pct === null)));

// --- lscpu L3 unit handling (regression: MiB parsed as KiB → "0 MiB") ------------
if (d.cpu.l3_kb !== null) {
  ok("l3 sane", d.cpu.l3_kb >= 256 && d.cpu.l3_kb <= 4 * 1024 * 1024, `got ${d.cpu.l3_kb}`);
}

// --- QML contract: keys referenced by DetailPopup.qml exist in probe output ------
const qml = readFileSync(path.join(root, "DetailPopup.qml"), "utf8");
const need = ["identity.bios_version", "identity.bios_date", "cpu.model", "mem.total_mb",
  "io.usb_devices", "io.pci_devices", "os.pretty", "os.kernel", "os.uptime_s"];
ok("qml keys present", need.every((k) => k.split(".").reduce((o, p) => (o ? o[p] : undefined), d) !== undefined));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
