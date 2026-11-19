#!/usr/bin/env node
// Generates src/assets/emoji/<lang>.json (emoji names and keywords per UI language)
// from Unicode CLDR annotations. Data: Unicode CLDR 49.0.0, Unicode License v3.
//
// Usage:
//   npm pack cldr-annotations-full@49.0.0 cldr-annotations-derived-full@49.0.0
//   (extract both tarballs)
//   node install/emoji_i18n.js <cldr-annotations-full/package> <cldr-annotations-derived-full/package>
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.resolve(__dirname, "..");
const EMOJI_DATA = path.join(ROOT, "src/quickshell/launcher/EmojiData.js");
const LANG_DIR = path.join(ROOT, "src/assets/languages");
const OUT_DIR = path.join(ROOT, "src/assets/emoji");

// Serpantinum UI language code -> CLDR locale, where they differ.
const CLDR_CODES = { ua: "uk", zh_tw: "zh-Hant" };

function lookup(table, emoji) {
    return table[emoji] || table[emoji.replace(/️/g, "")] || null;
}

function buildLanguage(emojis, annotations, derived) {
    const out = {};
    for (const e of emojis) {
        const entry = lookup(annotations, e.emoji) || lookup(derived, e.emoji);
        if (!entry || !entry.tts || !entry.tts[0]) continue;
        out[e.emoji] = { name: entry.tts[0], keywords: entry.default || [] };
    }
    return out;
}

function loadEmojis() {
    const source = fs.readFileSync(EMOJI_DATA, "utf8").replace(/^\s*\.pragma library\s*$/m, "");
    const ctx = {};
    vm.runInNewContext(source, ctx);
    return ctx.emojis;
}

function readJson(file) {
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

function main(fullDir, derivedDir) {
    if (!fullDir || !derivedDir) {
        console.error("usage: node install/emoji_i18n.js <cldr-annotations-full dir> <cldr-annotations-derived-full dir>");
        process.exit(2);
    }
    const emojis = loadEmojis();
    const langs = fs.readdirSync(LANG_DIR)
        .filter((f) => f.endsWith(".json"))
        .map((f) => f.slice(0, -5))
        .filter((l) => l !== "en")
        .sort();
    fs.mkdirSync(OUT_DIR, { recursive: true });
    for (const lang of langs) {
        const code = CLDR_CODES[lang] || lang;
        const annotations = readJson(path.join(fullDir, "annotations", code, "annotations.json")).annotations.annotations;
        const derived = readJson(path.join(derivedDir, "annotationsDerived", code, "annotations.json")).annotationsDerived.annotations;
        const out = buildLanguage(emojis, annotations, derived);
        fs.writeFileSync(path.join(OUT_DIR, lang + ".json"), JSON.stringify(out) + "\n");
        console.log(`${lang}: ${Object.keys(out).length}/${emojis.length}`);
    }
}

if (require.main === module) {
    main(process.argv[2], process.argv[3]);
}

module.exports = { buildLanguage };
