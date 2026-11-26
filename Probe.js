.pragma library
// Probe.js — how the widget starts a probe. Pure JS so the command shape and
// the deadlines are unit-tested without QML (tests/deadline.test.mjs).
//
// v0.6.1, marketplace review #16029: probe runs had no hard deadline, so a
// stalled helper kept its probe "running" forever and the refresh guards
// never let it recover. Every run now goes through timeout(1):
//
//   timeout -k 1 <deadline> /bin/bash <probe.sh> [args]
//
// timeout puts itself and the probe in one process group; at the deadline the
// whole group gets SIGTERM, a second later SIGKILL — a stalled helper takes
// its children with it. The run then exits non-zero (124, or 137 after a
// KILL), its output is incomplete (JSON.parse rejects it, so nothing partial
// is applied) and `running` clears on process death, which re-arms the
// widget's busy guard for the next tick.
//
// Deadlines are per probe and sit at least 5x above the runtime measured on
// the reference machine (sysmon ~150 ms, procprobe ~30 ms, sysinfo ~800 ms).

var TIMEOUT = "/usr/bin/timeout"
var KILL_AFTER_S = 1

// Milliseconds a run may take before it is terminated.
var DEADLINE_MS = {
  sys: 3000,      // sysmon.sh — the bar tick
  procs: 3000,    // procprobe.sh — process table, popup only
  hw: 5000,       // sysinfo-probe.sh — hardware inventory, once per open
  kill: 2000      // kill(1) from the confirm strip
}

// [timeout, -k, 1, <seconds>, argv…]. The deadline rounds UP to whole seconds.
function wrap(deadlineMs, argv) {
  var out = [TIMEOUT, "-k", String(KILL_AFTER_S), String(Math.ceil(deadlineMs / 1000))]
  for (var i = 0; i < argv.length; i++) out.push(argv[i])
  return out
}

// A probe script under /bin/bash, its own arguments after the path.
function script(deadlineMs, scriptPath, args) {
  var argv = ["/bin/bash", scriptPath]
  if (args) {
    for (var i = 0; i < args.length; i++) argv.push(args[i])
  }
  return wrap(deadlineMs, argv)
}
