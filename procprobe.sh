#!/bin/bash
# Process probe for com.gdeyoung.plasma.sysmon v0.7 (popup only).
#
# v2 — full list instead of top-14-by-CPU. The old shape made MEM-sort
# re-sort a CPU-biased subset and hid mem-hungry idle processes entirely.
# Row: [pid,user,name,pcpu,pmem,rss_kb,state,args]
#   rss_kb and args are new; user/state were captured since v0.1 but never
#   displayed. args truncated to 120 chars, JSON-escaped (args carry quotes).
#
# COLUMN RULE: ps `comm` can contain spaces ("tmux: server") which would
# shift every later column — so comm is NOT requested. All requested fields
# before `args` are guaranteed single-token; the display name is derived
# from basename(args[0]) (bracket-stripped for kernel threads/zombies).
#
# v2.1 — completeness fix: hosts can exceed any fixed cap (tower runs
# ~1000 procs), and a 0%-CPU target (the thing you most often want to find
# and kill) sorts LAST by CPU — a plain head cap makes search miss it.
# Rows kept = top-1500 by CPU UNION any row matching the filter substring
# (arg 1). Emitted when the Processes tab is visible, on a 2s tick.
#
# v2.2 — producer-side caps (v0.6.1, marketplace #16029): the widget buffers
# the whole output, so the caps have to hold here. The top CAP rows by CPU
# UNION filter matches, up to HCAP rows and BCAP bytes of JSON in total;
# user, name and args are cut to fixed widths. The object ends with
# "truncated":true whenever a cap dropped a row the rules would have kept.
set -u
FILTER="${1:-}"
CAP=1500      # rows from the top of ps's -pcpu sort: always kept
HCAP=2000     # hard total: those rows plus filter matches
BCAP=1048576  # hard total bytes of JSON
ps -eo pid,user,pcpu,pmem,rss,state,args --no-headers --sort=-pcpu \
  | awk -v F="$FILTER" -v CAP=$CAP -v HCAP=$HCAP -v BCAP=$BCAP '
BEGIN { printf "{\"procs\":[" }
{
  if (NR > CAP) {
    if (F == "") { trunc = 1; exit }                  # unfiltered: a top-CAP view
    if (index(tolower($0), tolower(F)) == 0) next     # the filter excluded it, not a cap
  }
  if (emitted >= HCAP) { trunc = 1; exit }            # hard row cap
  u = substr($2, 1, 32); pcpu = $3; pmem = $4; rss = $5; st = $6
  a = ""
  for (i = 7; i <= NF; i++) a = a (i > 7 ? " " : "") $i
  n = a; sub(/ .*/, "", n); gsub(/^\[|\]$/, "", n)
  if (n ~ /^\//) sub(/.*\//, "", n)
  if (n == "") n = "?"
  n = substr(n, 1, 64)
  a = substr(a, 1, 120)
  gsub(/\\/, "\\\\", a); gsub(/"/, "\\\"", a); gsub(/[[:cntrl:]]/, " ", a)
  gsub(/\\/, "\\\\", u); gsub(/"/, "\\\"", u)
  gsub(/\\/, "\\\\", n); gsub(/"/, "\\\"", n)
  row = sprintf("[%d,\"%s\",\"%s\",%.1f,%.1f,%d,\"%s\",\"%s\"]", $1, u, n, pcpu, pmem, rss, st, a)
  if (bytes + length(row) + 1 > BCAP) { trunc = 1; exit }   # hard byte cap
  bytes += length(row) + 1
  printf "%s%s", (emitted++ > 0 ? "," : ""), row
}
END { printf "],\"truncated\":%s}\n", (trunc ? "true" : "false") }
'
