#!/usr/bin/env bash
# SysMon installer for Omarchy 4.x
# Installs the bar widget, enables it, places it in the bar's right section,
# and disables vm.sysmem when present (SysMon supersedes it).
# Non-destructive: the plugin dir is copied, never deleted on upgrade.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="gdeyoung.sysmon"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

say()  { printf '%s\n' "$*"; }

# --- 1. Install files ---------------------------------------------------------
mkdir -p "$plugin_dir"
install -m 644 "$repo_dir/BarWidget.qml"   "$plugin_dir/BarWidget.qml"
install -m 644 "$repo_dir/DetailPopup.qml" "$plugin_dir/DetailPopup.qml"
install -m 644 "$repo_dir/Sparkline.qml"   "$plugin_dir/Sparkline.qml"
install -m 644 "$repo_dir/HistBars.qml"    "$plugin_dir/HistBars.qml"
install -m 644 "$repo_dir/CoreGrid.qml"    "$plugin_dir/CoreGrid.qml"
install -m 644 "$repo_dir/SysSection.qml"  "$plugin_dir/SysSection.qml"
install -m 644 "$repo_dir/manifest.json"   "$plugin_dir/manifest.json"
install -m 644 "$repo_dir/README.md"       "$plugin_dir/README.md"
install -m 755 "$repo_dir/sysmon.sh"       "$plugin_dir/sysmon.sh"
install -m 755 "$repo_dir/procprobe.sh"    "$plugin_dir/procprobe.sh"
say "installed: $plugin_dir"

# --- 2. Probe sanity check ----------------------------------------------------
if probe_out=$("$plugin_dir/sysmon.sh" 2>/dev/null) && command -v python3 >/dev/null; then
  if printf '%s' "$probe_out" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
    say "probe ok: $probe_out"
  else
    say "WARNING: probe did not emit valid JSON: $probe_out" >&2
  fi
fi

# --- 3. Enable + place --------------------------------------------------------
omarchy plugin enable "$plugin_id" 2>/dev/null || say "NOTE: run 'omarchy plugin enable $plugin_id' after shell restart"
omarchy bar put "$plugin_id" --section right 2>/dev/null || true

# --- 4. Retire vm.sysmem if present -------------------------------------------
if omarchy plugin list 2>/dev/null | grep -q "vm.sysmem"; then
  omarchy plugin disable vm.sysmem 2>/dev/null && say "disabled: vm.sysmem (superseded by SysMon)" || true
fi

say ""
say "Done. Restart the shell to load the widget:  omarchy restart shell"
