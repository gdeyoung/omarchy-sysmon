#!/usr/bin/env node
// deadline.test.mjs — every probe run has a hard deadline (v0.6.1).
//
// Marketplace review (#16029) on v0.6.0: "recurring probe processes have no
// hard deadline, output cap, or timeout cleanup. A stalled local helper
// leaves that probe permanently running; the refresh guards then prevent
// recovery." These tests pin the contract that fixes it:
//   1. the widget starts no probe without timeout(1) in front of it,
//   2. a stalled helper is TERM'd at its deadline and KILL'd a second later,
//      together with every descendant it spawned,
//   3. a run that hit its deadline never looks like a success (non-zero exit),
//   4. the real probes finish far inside their deadlines.
// The producer-side row/byte/field caps of the process probe live next to the
// other procprobe tests in probe.test.mjs. Run: node --test tests/deadline.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const TIMEOUT = "/usr/bin/timeout";

// Probe.js is a QML JS library (`.pragma library`), not an ES module: evaluate
// it the way the QML engine does — one shared, stateless scope.
const Probe = vm.createContext({});
vm.runInContext(
  readFileSync(path.join(root, "Probe.js"), "utf8").replace(/^\.pragma library\s*$/m, ""),
  Probe, { filename: "Probe.js" });

// Probe.js is evaluated in its own realm, so its arrays carry another
// Array.prototype; copy them into this one before a strict deepEqual.
const argv = (a) => [...a];
const run = (argv_, timeout = 20_000) =>
  spawnSync(argv_[0], argv_.slice(1), { encoding: "utf8", timeout });

const withScript = (source, fn) => {
  const dir = mkdtempSync(path.join(tmpdir(), "sysmon-deadline-"));
  const file = path.join(dir, "probe.sh");
  writeFileSync(file, source);
  try {
    return fn(file);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

// --- the command the widget starts ---------------------------------------------
test("Probe.wrap: timeout(1) with --kill-after goes in front of the argv", () => {
  assert.deepEqual(argv(Probe.wrap(3000, ["/bin/bash", "/p/sysmon.sh"])),
    [TIMEOUT, "-k", "1", "3", "/bin/bash", "/p/sysmon.sh"]);
  // whole seconds, rounded up: a 2.5 s deadline must not shorten to 2
  assert.deepEqual(argv(Probe.wrap(2500, ["/usr/bin/kill", "-15", "42"])),
    [TIMEOUT, "-k", "1", "3", "/usr/bin/kill", "-15", "42"]);
});

test("Probe.script: /bin/bash, the script path, then the probe's own arguments", () => {
  assert.deepEqual(argv(Probe.script(3000, "/p/procprobe.sh", ["sleep"])),
    [TIMEOUT, "-k", "1", "3", "/bin/bash", "/p/procprobe.sh", "sleep"]);
  assert.deepEqual(argv(Probe.script(3000, "/p/sysmon.sh")),
    [TIMEOUT, "-k", "1", "3", "/bin/bash", "/p/sysmon.sh"]);
});

// --- the deadline itself --------------------------------------------------------
test("a stalled probe is terminated at its deadline, with every descendant, and reports failure", () => {
  const marker = `sysmon-deadline-test-${process.pid}`;
  withScript(
    `#!/bin/bash
# a helper that hangs, with a child of its own hanging alongside
exec -a ${marker} /usr/bin/sleep 30 &
wait
`, (file) => {
    const t0 = Date.now();
    const r = run(Probe.script(1000, file));
    const ms = Date.now() - t0;
    assert.equal(r.status, 124, `exit ${r.status} signal ${r.signal}: a stalled run must not look like a success`);
    assert.ok(ms >= 900 && ms < 5000, `deadline 1 s + 1 s grace, the run took ${ms} ms`);
    // The TERM lands on the whole process group. Allow a moment for the reap.
    let left = "";
    for (let i = 0; i < 20; i++) {
      left = spawnSync("/usr/bin/pgrep", ["-f", marker], { encoding: "utf8" }).stdout.trim();
      if (left === "") break;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
    }
    assert.equal(left, "", `a descendant of the stalled probe survived: pid(s) ${left}`);
  });
});

test("a healthy probe passes through untouched: same output, exit 0", () => {
  withScript(`#!/bin/bash\necho '{"ok":1}'\n`, (file) => {
    const r = run(Probe.script(3000, file));
    assert.equal(r.status, 0, `exit ${r.status} signal ${r.signal}`);
    assert.equal(r.stdout, `{"ok":1}\n`);
    assert.equal(r.stderr, "");
  });
});

test("the real probes finish well inside their deadlines", () => {
  const plan = [
    ["sysmon.sh", Probe.DEADLINE_MS.sys],
    ["procprobe.sh", Probe.DEADLINE_MS.procs],
    ["sysinfo-probe.sh", Probe.DEADLINE_MS.hw],
  ];
  for (const [script, deadlineMs] of plan) {
    assert.ok(Number.isInteger(deadlineMs) && deadlineMs > 0, `${script}: no deadline`);
    const t0 = Date.now();
    const r = run(Probe.script(deadlineMs, path.join(root, script)));
    const ms = Date.now() - t0;
    assert.equal(r.status, 0, `${script}: exit ${r.status} signal ${r.signal}`);
    assert.equal(r.stdout.trim().split("\n").length, 1, `${script}: one JSON line`);
    assert.doesNotThrow(() => JSON.parse(r.stdout), `${script}: JSON`);
    assert.ok(ms * 5 < deadlineMs, `${script}: ${ms} ms against a ${deadlineMs} ms deadline (want >= 5x headroom)`);
  }
});

// --- the widget side -----------------------------------------------------------
test("BarWidget.qml starts no probe without the deadline wrapper", () => {
  const qml = readFileSync(path.join(root, "BarWidget.qml"), "utf8");
  // plain `import`, the form every stock plugin uses; Qt 6.12 rejects `.import`
  assert.match(qml, /^import "Probe\.js" as Probe$/m);
  const bare = [...qml.matchAll(/command:\s*\[\s*"(?:\/bin\/bash|\/usr\/bin\/(?:bash|kill|timeout))"/g)]
    .map((m) => m[0].trim());
  assert.deepEqual(bare, [], "build every Process command through Probe.js; bare: " + bare.join(" | "));
});
