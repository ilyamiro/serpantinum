#!/usr/bin/env node
// Tests for src/quickshell/clipboard/PasteKeys.js
// Run: node install/tests/paste_keys_test.js
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const file = path.resolve(__dirname, "../../src/quickshell/clipboard/PasteKeys.js");
const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma library\s*$/m, "");
const pk = {};
vm.runInNewContext(source, pk);

const CTRL_V = ["-M", "ctrl", "v", "-m", "ctrl"];
const CTRL_SHIFT_V = ["-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"];

const tests = {
    terminal_exact_match() {
        assert.deepEqual(Array.from(pk.pasteCommand("kitty", pk.DEFAULT_TERMINALS)), CTRL_SHIFT_V);
    },
    terminal_reverse_dns_suffix() {
        assert.ok(pk.isTerminal("com.mitchellh.ghostty", pk.DEFAULT_TERMINALS));
        assert.ok(pk.isTerminal("org.wezfurlong.wezterm", pk.DEFAULT_TERMINALS));
    },
    case_insensitive() {
        assert.ok(pk.isTerminal("Alacritty", pk.DEFAULT_TERMINALS));
    },
    regular_app_gets_ctrl_v() {
        assert.deepEqual(Array.from(pk.pasteCommand("google-chrome", pk.DEFAULT_TERMINALS)), CTRL_V);
    },
    no_substring_match() {
        assert.ok(!pk.isTerminal("steam", pk.DEFAULT_TERMINALS));
    },
    no_target_no_paste() {
        for (const c of ["", "Desktop", "Quickshell", "Unknown"]) {
            assert.deepEqual(Array.from(pk.pasteCommand(c, pk.DEFAULT_TERMINALS)), [], c);
        }
    },
    user_terminal_list() {
        assert.ok(pk.isTerminal("my-term", ["my-term"]));
    },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
    try {
        fn();
    } catch (e) {
        failed++;
        console.error(`FAIL ${name}: ${e.message}`);
    }
}
if (failed) process.exit(1);
console.log("ok");
