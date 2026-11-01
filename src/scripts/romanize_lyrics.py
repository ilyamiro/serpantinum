#!/usr/bin/env python3
"""Pronunciation (romanization) for song lyrics.

Usage: romanize_lyrics.py '<JSON array>'
Each item is a line ("text") or {"t": text, "r": romanization it already has}.
Prints a JSON array of the same length: the romanized line, or "" when the
line is already in Latin script (English, Spanish...) or can't be romanized.
A given romanization is kept, except a syllable-by-syllable one ("ka to chi
ni", as NetEase sends) when cutlet can redo it word by word, and for Korean,
where the built-in reading is used instead.

Works with plain Python 3 on any distro; optional extras improve it:
- Korean: Revised Romanization with the sound changes inside a word, so it
  reads as pronounced (사랑해요 = saranghaeyo). Built in.
- Cyrillic and Greek: built-in tables.
- Japanese (the song has kana anywhere): `cutlet` (MeCab: real word
  boundaries and readings) if installed, else `pykakasi`, else kana with a
  built-in Hepburn table.
- Chinese: pinyin with `pypinyin`, or ICU's `uconv` if present.
- Anything else (Arabic, Hebrew, Thai, Devanagari...): ICU's `uconv` if present.
"""
import json
import re
import shutil
import subprocess
import sys

KANA = re.compile(r"[぀-ヿㇰ-ㇿｦ-ﾟ]")
HAN = re.compile(r"[㐀-䶿一-鿿豈-﫿]")


def non_latin(line):
    """True if the line has letters outside Latin / common punctuation."""
    for ch in line:
        if ch.isalpha() and not ("A" <= ch <= "z" or "À" <= ch <= "ɏ"
                                 or "Ḁ" <= ch <= "ỿ"):
            return True
    return False


def icu(lines):
    """Romanize several lines with a single uconv call."""
    if not lines or not shutil.which("uconv"):
        return [""] * len(lines)
    text = "\n".join(l.replace("\n", " ") for l in lines) + "\n"
    try:
        out = subprocess.run(["uconv", "-x", "Any-Latin"], input=text, capture_output=True,
                             text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return [""] * len(lines)
    res = out.split("\n")[:len(lines)]
    return res + [""] * (len(lines) - len(res))


# Revised Romanization of Korean, with the usual sound changes inside a word
# (liaison, ㄹ between vowels = r, nasalization), so it reads as pronounced.
_KO_INI = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj",
           "ch", "k", "t", "p", "h"]
_KO_VOW = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo",
           "u", "wo", "we", "wi", "yu", "eu", "ui", "i"]
_KO_FIN = ["", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l",
           "m", "p", "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"]
# final consonant carried to the next syllable when it starts with a vowel (ㅇ)
_KO_LIAISON = {1: "g", 2: "kk", 4: "n", 7: "d", 8: "r", 16: "m", 17: "b", 19: "s", 20: "ss",
               22: "j", 23: "ch", 24: "k", 25: "t", 26: "p", 27: ""}
_KO_NASAL = {"k": "ng", "p": "m", "t": "n"}


def _ko_syllables(word):
    out = []
    for ch in word:
        c = ord(ch) - 0xAC00
        out.append((c // 588, (c % 588) // 28, c % 28) if 0 <= c < 11172 else ch)
    return out


def korean(line):
    res = []
    for word in re.split(r"(\s+)", line):
        syl = _ko_syllables(word)
        buf = []
        for i, s in enumerate(syl):
            if isinstance(s, str):
                buf.append(s)
                continue
            ini, vow, fin = s
            prev = syl[i - 1] if i > 0 else None
            if isinstance(prev, tuple) and prev[2] in _KO_LIAISON and ini == 11:
                start = ""                               # the final already carries it
            elif isinstance(prev, tuple) and prev[2] == 8 and ini == 5:
                start = "l"                              # ㄹㄹ = ll
            elif isinstance(prev, tuple) and prev[2] == 4 and ini == 5:
                start = "l"                              # ㄴㄹ = ll
            elif isinstance(prev, tuple) and prev[2] == 8 and ini == 2:
                start = "l"                              # ㄹㄴ = ll (설날 = seollal)
            else:
                start = _KO_INI[ini]
            nxt = syl[i + 1] if i + 1 < len(syl) else None
            if fin and isinstance(nxt, tuple) and nxt[0] == 11 and fin in _KO_LIAISON:
                end = _KO_LIAISON[fin]
            else:
                end = _KO_FIN[fin]
                if isinstance(nxt, tuple) and nxt[0] in (2, 6) and end in _KO_NASAL:
                    end = _KO_NASAL[end]                 # 합니다 = hamnida
                elif isinstance(nxt, tuple) and nxt[0] == 5 and fin == 4:
                    end = "l"                            # ㄴㄹ = ll
            buf.append(start + _KO_VOW[vow] + end)
        res.append("".join(buf))
    return "".join(res)


HANGUL = re.compile(r"[\uac00-\ud7a3]")
CYRILLIC_GREEK = re.compile(r"[\u0370-\u03ff\u0400-\u04ff]")

_CYR = dict(zip("абвгдеёжзийклмнопрстуфхцчшщъыьэюяіїєґў",
                ["a", "b", "v", "g", "d", "e", "yo", "zh", "z", "i", "y", "k", "l", "m", "n", "o",
                 "p", "r", "s", "t", "u", "f", "kh", "ts", "ch", "sh", "shch", "", "y", "",
                 "e", "yu", "ya", "i", "yi", "ye", "g", "w"]))
_GRK = dict(zip("αβγδεζηθικλμνξοπρσςτυφχψωάέήίόύώϊϋΐΰ",
                ["a", "v", "g", "d", "e", "z", "i", "th", "i", "k", "l", "m", "n", "x", "o", "p",
                 "r", "s", "s", "t", "y", "f", "ch", "ps", "o", "á", "é", "í", "í", "ó", "ý", "ó",
                 "i", "y", "í", "ý"]))


_GRK_PAIRS = {"ου": "ou", "ού": "oú", "ΟΥ": "OU", "Ου": "Ou"}


def table(line):
    """Cyrillic / Greek by table, keeping the case of each letter."""
    for pair, r in _GRK_PAIRS.items():
        line = line.replace(pair, r)
    out = []
    for ch in line:
        low = ch.lower()
        r = _CYR.get(low, _GRK.get(low))
        if r is None:
            out.append(ch)
        else:
            out.append(r.capitalize() if ch != low and r else r)
    return "".join(out)


# Hepburn for kana (hiragana; katakana is mapped onto it)
_KANA = {}
for row, cons in (("あいうえお", ["a", "i", "u", "e", "o"]), ("かきくけこ", ["ka", "ki", "ku", "ke", "ko"]),
                  ("がぎぐげご", ["ga", "gi", "gu", "ge", "go"]), ("さしすせそ", ["sa", "shi", "su", "se", "so"]),
                  ("ざじずぜぞ", ["za", "ji", "zu", "ze", "zo"]), ("たちつてと", ["ta", "chi", "tsu", "te", "to"]),
                  ("だぢづでど", ["da", "ji", "zu", "de", "do"]), ("なにぬねの", ["na", "ni", "nu", "ne", "no"]),
                  ("はひふへほ", ["ha", "hi", "fu", "he", "ho"]), ("ばびぶべぼ", ["ba", "bi", "bu", "be", "bo"]),
                  ("ぱぴぷぺぽ", ["pa", "pi", "pu", "pe", "po"]), ("まみむめも", ["ma", "mi", "mu", "me", "mo"]),
                  ("やゆよ", ["ya", "yu", "yo"]), ("らりるれろ", ["ra", "ri", "ru", "re", "ro"]),
                  ("わゐゑを", ["wa", "i", "e", "wo"]), ("ぁぃぅぇぉ", ["a", "i", "u", "e", "o"]),
                  ("ゔ", ["vu"])):
    _KANA.update(zip(row, cons))
_KANA["ん"] = "n"
_SMALL_Y = {"ゃ": "a", "ゅ": "u", "ょ": "o"}


def kana(text):
    """Hiragana/katakana to Hepburn: きゃ = kya, っ doubles, ー lengthens."""
    t = "".join(chr(ord(c) - 0x60) if "\u30a1" <= c <= "\u30f6" else c for c in text)
    out, i = [], 0
    while i < len(t):
        c = t[i]
        nxt = t[i + 1] if i + 1 < len(t) else ""
        if c in _KANA and nxt in _SMALL_Y:
            base = _KANA[c]
            stem = base[:-1] if base[:-1] in ("sh", "ch", "j") else base[:-1] + "y"
            out.append(stem + _SMALL_Y[nxt])
            i += 2
            continue
        if c == "っ" and nxt in _KANA:
            r = _KANA[nxt]
            out.append("t" if r.startswith("ch") else r[0])
            i += 1
            continue
        if c == "ー" and out:
            out.append(out[-1][-1])
        else:
            out.append(_KANA.get(c, c))
        i += 1
    return "".join(out)


def chinese(lines):
    try:
        from pypinyin import lazy_pinyin, Style
        return [" ".join(w for w in lazy_pinyin(l, style=Style.TONE) if w.strip()) for l in lines]
    except ImportError:
        return icu(lines)
# particles read differently from how they are written
_JA_PARTICLES = {"は": "wa", "へ": "e"}
_JA_KEEP_APART = set("はがをにでとものへやかねよ") | {"から", "まで", "より", "けど"}


def _cutlet():
    try:
        import cutlet
        k = cutlet.Cutlet()
        k.use_foreign_spelling = False
        return k
    except Exception:                   # not installed, or no dictionary
        return None


def japanese(lines):
    k = _cutlet()
    if k is not None:
        return [k.romaji(l).strip().lower() if l.strip() else "" for l in lines]
    try:
        import pykakasi
    except ImportError:
        # no dictionary: only lines without kanji (half-romanized looks worse)
        return [kana(l) if not HAN.search(l) else "" for l in lines]
    kks = pykakasi.kakasi()
    hira = re.compile(r"^[\u3040-\u309f]+$")
    out = []
    for l in lines:
        words = []
        double = False                                   # a small っ is pending
        for w in kks.convert(l):
            orig, rom = w["orig"], (w["hepburn"] or w["orig"]).strip()
            if double and rom:
                rom = ("t" if rom.startswith("ch") else rom[0]) + rom   # 待って = matte
                double = False
            if orig[-1:] in ("っ", "ッ") and rom.endswith("tsu"):
                rom, double = rom[:-3], True
            if orig in _JA_PARTICLES and words:
                rom = _JA_PARTICLES[orig]
            elif words and hira.match(orig) and len(orig) <= 2 and orig not in _JA_KEEP_APART:
                words[-1] += rom                         # okurigana: 駆け+る = kakeru
                continue
            words.append(rom)
        out.append(re.sub(r"\s+", " ", " ".join(words)).strip())
    return out


def syllabic(rom):
    """'ka to chi ni na tte' (one syllable per token) rather than words."""
    toks = re.sub(r"[^\w\s]", " ", rom).split()     # 「sa yo」da: brackets apart
    return len(toks) >= 4 and sum(len(t) for t in toks) / len(toks) <= 2.6


def main():
    try:
        lines = json.loads(sys.argv[1])
    except (IndexError, ValueError):
        print("[]")
        return
    given = [l.get("r", "") if isinstance(l, dict) else "" for l in lines]
    lines = [str((l.get("t", "") if isinstance(l, dict) else l) or "") for l in lines]
    is_japanese = any(KANA.search(l) for l in lines)
    result = [""] * len(lines)
    jp_idx = [i for i, l in enumerate(lines)
              if is_japanese and (KANA.search(l) or HAN.search(l))]
    done = set(jp_idx)
    ko_idx = [i for i, l in enumerate(lines) if i not in done and HANGUL.search(l)]
    done |= set(ko_idx)
    zh_idx = [i for i, l in enumerate(lines) if i not in done and HAN.search(l)]
    done |= set(zh_idx)
    tb_idx = [i for i, l in enumerate(lines) if i not in done and CYRILLIC_GREEK.search(l)]
    done |= set(tb_idx)
    other_idx = [i for i, l in enumerate(lines) if i not in done and non_latin(l)]
    for i, r in zip(jp_idx, japanese([lines[i] for i in jp_idx])):
        result[i] = r
    for i in ko_idx:
        result[i] = korean(lines[i])
    for i, r in zip(zh_idx, chinese([lines[i] for i in zh_idx])):
        result[i] = r
    for i in tb_idx:
        result[i] = table(lines[i])
    for i, r in zip(other_idx, icu([lines[i] for i in other_idx])):
        result[i] = r
    # keep a romanization the line already had, unless it is syllable by
    # syllable and cutlet can read it word by word (pykakasi misreads kanji
    # like 日/君, so it doesn't replace one), or it is Korean: the built-in
    # reading follows the sound changes, NetEase's does not ("zeo gi" for 저기)
    redo = _cutlet() is not None
    jp_set, ko_set = set(jp_idx), set(ko_idx)
    for i, g in enumerate(given):
        if not g or i in ko_set:
            continue
        if not (redo and i in jp_set and syllabic(g)):
            result[i] = g
    # nothing to add if it came out the same as the original
    result = [r.strip() if r.strip() and r.strip() != lines[i].strip() else ""
              for i, r in enumerate(result)]
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
