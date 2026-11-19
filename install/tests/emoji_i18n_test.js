#!/usr/bin/env node
// Tests for install/emoji_i18n.js
// Run: node install/tests/emoji_i18n_test.js
"use strict";

const assert = require("node:assert/strict");
const { buildLanguage } = require("../emoji_i18n.js");

const tests = {
    uses_tts_and_default() {
        const out = buildLanguage([{ emoji: "😀" }], { "😀": { tts: ["rosto"], default: ["feliz"] } }, {});
        assert.deepEqual(out, { "😀": { name: "rosto", keywords: ["feliz"] } });
    },
    falls_back_without_fe0f() {
        const out = buildLanguage([{ emoji: "❤️" }], { "❤": { tts: ["coração vermelho"], default: ["amor"] } }, {});
        assert.deepEqual(out, { "❤️": { name: "coração vermelho", keywords: ["amor"] } });
    },
    uses_derived() {
        const out = buildLanguage([{ emoji: "👍🏽" }], {}, { "👍🏽": { tts: ["polegar: pele morena"], default: ["ok"] } });
        assert.deepEqual(out, { "👍🏽": { name: "polegar: pele morena", keywords: ["ok"] } });
    },
    skips_missing() {
        const out = buildLanguage([{ emoji: "😀" }, { emoji: "🫠" }], { "😀": { tts: ["rosto"], default: [] } }, {});
        assert.deepEqual(Object.keys(out), ["😀"]);
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
