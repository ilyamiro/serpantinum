#!/usr/bin/env node
// Tests for search() in src/quickshell/launcher/EmojiData.js
// Run: node install/tests/emoji_search_test.js
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const file = path.resolve(__dirname, "../../src/quickshell/launcher/EmojiData.js");
const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma library\s*$/m, "");
const data = {};
vm.runInNewContext(source, data);

const PT = {
    "❤️": { name: "coração vermelho", keywords: ["amor", "coração", "coração vermelho", "s2"] },
    "☀️": { name: "sol", keywords: ["brilhante", "raios", "sol"] },
};

// search("heart", 50) before translations existed: [emoji, score].
const HEART_BEFORE = [["💟",3000],["❣️",3000],["🫶",3000],["❤️‍🔥",3000],["♥️",3000],["💘",3000],["💝",3000],["😘",2000],["🫀",1500],["💓",1500],["🖤",1500],["💙",1500],["💔",1500],["🤎",1500],["💑",1500],["👨‍❤️‍👨",1500],["👩‍❤️‍👨",1500],["👩‍❤️‍👩",1500],["💚",1500],["🩶",1500],["💗",1500],["🩵",1500],["❤️‍🩹",1500],["🧡",1500],["🩷",1500],["💜",1500],["❤️",1500],["💞",1500],["😻",1500],["😍",1500],["🥰",1500],["💖",1500],["💕",1500],["🤍",1500],["💛",1500]];

function withPt(fn) {
    data.setTranslations(PT);
    try { fn(); } finally { data.setTranslations(null); }
}

const tests = {
    english_unchanged() {
        data.setTranslations(null);
        const got = JSON.parse(JSON.stringify(data.search("heart", 50).map((r) => [r.emoji, r.score])));
        assert.deepEqual(got, HEART_BEFORE);
    },
    translated_with_and_without_accent() {
        withPt(() => {
            assert.equal(data.search("coração")[0].emoji, "❤️");
            assert.equal(data.search("coracao")[0].emoji, "❤️");
            assert.equal(data.search("CORACAO")[0].emoji, "❤️");
        });
    },
    translated_name_shown() {
        withPt(() => {
            const r = data.search("coracao").find((x) => x.emoji === "❤️");
            assert.equal(r.name, "coração vermelho");
            assert.equal(r.nameEn, "red heart");
        });
    },
    exact_translation_beats_english_substring() {
        withPt(() => {
            assert.equal(data.search("sol")[0].emoji, "☀️");
        });
    },
    english_still_works_in_pt() {
        withPt(() => {
            assert.ok(data.search("heart", 150).some((r) => r.emoji === "❤️"));
        });
    },
    empty_query_uses_translated_names() {
        withPt(() => {
            const all = data.search("", 2000);
            const heart = all.find((r) => r.emoji === "❤️");
            assert.equal(heart.name, "coração vermelho");
            assert.equal(all[0].name, data.emojis[0].name);
        });
    },
    normalize_keeps_non_latin() {
        assert.equal(data.normalize("йога"), "йога");
        assert.equal(data.normalize("が"), "が");
        assert.equal(data.normalize("Coração"), "coracao");
    },
    reset_to_english() {
        withPt(() => {});
        assert.equal(data.search("coracao").length, 0);
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
