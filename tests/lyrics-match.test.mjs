import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createContext, runInContext } from "node:vm";
import test from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = readFileSync(
  join(root, "src/quickshell/singletons/audio/LyricsMatch.js"),
  "utf8"
);

// QML `.pragma library` is not valid JS — strip it for Node.
const ctx = createContext({ console });
runInContext(src.replace(/^\.pragma library\s*/m, ""), ctx);

const {
  cleanString,
  normalizeForMatch,
  durationSecondsFromMpris,
  scoreTitleArtist,
  scoreLrclibCandidate,
  pickBestLrclibResult,
  pickBestNetEaseSong,
  buildLrclibSearchQueries,
  MIN_ACCEPT_SCORE,
} = ctx;

test("cleanString strips feat/official noise", () => {
  assert.equal(cleanString("Track (feat. Foo)"), "Track");
  assert.equal(cleanString("Track - Official Music Video"), "Track");
  assert.equal(cleanString("Смотри"), "Смотри");
});

test("normalizeForMatch lowercases and strips quotes", () => {
  assert.equal(normalizeForMatch('  "Hello"  '), "hello");
  assert.equal(normalizeForMatch("дмитревна"), "дмитревна");
});

test("durationSecondsFromMpris handles us/ms/sec", () => {
  assert.equal(durationSecondsFromMpris(202000000), 202); // µs
  assert.equal(durationSecondsFromMpris(202000), 202); // ms
  assert.equal(durationSecondsFromMpris(202), 202); // sec
  assert.equal(durationSecondsFromMpris(0), 0);
});

test("scoreTitleArtist rejects wrong artist", () => {
  assert.ok(scoreTitleArtist("Смотри", "Someone Else", "Смотри", "дмитревна") < 0);
  assert.ok(scoreTitleArtist("Смотри", "дмитревна", "Смотри", "дмитревна") >= 55);
});

test("pickBestLrclibResult requires confident match (score >= 55)", () => {
  const session = {
    title: "Смотри",
    artist: "дмитревна",
    album: "",
    durationSec: 202,
  };
  const list = [
    {
      trackName: "Смотри",
      artistName: "Totally Different",
      duration: 202,
      syncedLyrics: "[00:01.00]nope",
    },
    {
      trackName: "Смотри",
      artistName: "дмитревна",
      duration: 202,
      syncedLyrics: "[00:01.00]yes",
    },
  ];
  const best = pickBestLrclibResult(list, session);
  assert.ok(best);
  assert.equal(best.artistName, "дмитревна");
  assert.ok(scoreLrclibCandidate(best, session) >= MIN_ACCEPT_SCORE);

  // Weak / wrong-artist only list → null
  assert.equal(pickBestLrclibResult([list[0]], session), null);
});

test("pickBestLrclibResult does not pick first random hit", () => {
  const session = {
    title: "Hello",
    artist: "Adele",
    durationSec: 295,
  };
  const list = [
    {
      trackName: "Hello",
      artistName: "Cover Band",
      duration: 180,
      syncedLyrics: "[00:01.00]cover",
    },
    {
      trackName: "Hello",
      artistName: "Adele",
      duration: 295,
      syncedLyrics: "[00:01.00]real",
    },
  ];
  const best = pickBestLrclibResult(list, session);
  assert.equal(best.artistName, "Adele");
});

test("pickBestNetEaseSong uses title+artist not only duration", () => {
  const songs = [
    { id: 1, name: "Hello", ar: [{ name: "Cover Band" }], dt: 295000 },
    { id: 2, name: "Hello", ar: [{ name: "Adele" }], dt: 294000 },
  ];
  const best = pickBestNetEaseSong(songs, "Hello", "Adele", 295);
  assert.ok(best);
  assert.equal(best.id, 2);

  // Duration-only would pick songs[0] if artist ignored — ensure rejection of weak artist
  assert.equal(
    pickBestNetEaseSong(
      [{ id: 9, name: "Hello", ar: [{ name: "Nope" }], dt: 295000 }],
      "Hello",
      "Adele",
      295
    ),
    null
  );
});

test("buildLrclibSearchQueries de-duplicates variants", () => {
  const q = Array.from(
    buildLrclibSearchQueries({
      artist: "Adele",
      title: "Hello",
      rawArtist: "Adele",
      rawTitle: "Hello",
    })
  );
  assert.deepEqual(q, ["Adele Hello", "Hello Adele", "Hello"]);
});

test("MIN_ACCEPT_SCORE is 55", () => {
  assert.equal(MIN_ACCEPT_SCORE, 55);
});
