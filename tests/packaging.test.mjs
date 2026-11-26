#!/usr/bin/env node
// packaging.test.mjs — one install path.
//
// v0.6.0 shipped an install.sh whose file list had drifted from the tree: it
// copied five files, then died on a sixth that no longer existed, leaving a
// partial plugin behind (marketplace #16029). The standard Omarchy path is
// the only one now. Run: node --test tests/packaging.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

test("the standard install path is the only install path", () => {
  assert.equal(existsSync(path.join(root, "install.sh")), false,
    "install.sh is back: its file list drifted from the tree once and left partial plugins behind");
  const readme = readFileSync(path.join(root, "README.md"), "utf8");
  assert.match(readme, /omarchy plugin add https:\/\/github\.com\/gdeyoung\/omarchy-sysmon\.git --enable/);
  // The README may say the installer is gone; it must not tell anyone to run it.
  assert.doesNotMatch(readme, /\.\/install\.sh/);
});
