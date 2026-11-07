# Display manager rebuild — continuity notes

Branch `feature/display-manager-v2`, worktree `~/Proyectos/serpantinum-display-v2`,
based on upstream `ilyamiro/serpantinum` 2.4.0. Replaces the abandoned v0600 branch
(278 Python scripts, never applied a physical change). Do NOT port code from it;
only the QML look of `serpantinum-v0600-physical-execution-lab/src/quickshell/guide/display/`
may be used as visual reference.

Scope: Arch + Hyprland (Lua config, 0.57) first; Niri/Sway/Mango later.
Never touch the user's live install (2.2.0) or `~/.config/hypr/*` while developing.

## Safety design (done)
`src/quickshell/guide/display/display_txn.py` — single stdlib-only script, JSON out.
validate -> snapshot -> arm reverter (systemd-run --user, Restart=on-failure; setsid fallback)
-> `hyprctl eval` (enables before disables) -> verify against `hyprctl -j monitors all`
-> confirm within timeout, else restore snapshot -> if restore fails, safe layout
(all outputs on, best mode, left-to-right, scale 1).
Validation: every monitor listed, identity by description (catches eDP-1->eDP-2),
mode in availableModes, scale gives integral logical size, transform 0-7, no overlap,
>=1 enabled; gaps are only a warning. One transaction at a time (flock).
State: `$XDG_RUNTIME_DIR/serpantinum-display/txn.json`,
`~/.local/state/serpantinum/display/{last-good.json,display.log}`.
Emergency (TTY): `python3 <qsDir>/guide/display/display_txn.py rescue`
(auto-detects the Hyprland instance; restores last-good, else safe layout).

## Verified
- `python3 -m unittest discover -s tests/display` — 55 offline tests (fake hyprctl).
- Nested Hyprland with a HEADLESS output (never the real session): timeout revert,
  confirm, revert-on-request, disable+revert, watcher SIGKILL (setsid: healed by
  `status`; systemd: unit restarts and reverts), all-off rejected.
  Recipe: `Hyprland -c nested.lua &`, then `HYPRLAND_INSTANCE_SIGNATURE=<new sig>`
  `hyprctl output create headless`. ABORT if the signature equals the real session.

## UI status (Hyprland only; niri/sway/mango code is untouched upstream code)
DONE (steps 1-2 and 5 for en/es):
- `DisplayMainState.qml`: Hyprland reads monitors through `display_txn.py state`
  (modes, validScales, description, x/y, transform, focused). If the backend fails it
  falls back to the old read-only `hyprctl` detector and `txnAvailable=false`.
  `txnChange(name, patch)` -> `apply <inline JSON> --timeout 15 --reflow <name>`;
  `txnConfirm/txnRevert/txnCheckStatus`; 1 s status poll while pending; `status` is
  also called on load (heals a dead reverter, resumes the countdown). Error codes
  `code:a:b` map to `guide.display.txn.err_<code>` with `{a}`/`{b}`.
  `applyMonitorPower/Scale` for Hyprland go through `txnChange`.
- `DisplayNotice.qml` (new, in qmldir): banner. `DisplayMainTab.qml` shows (1) the
  "Keep these display settings?" banner with countdown + Revert / Keep, (2) result
  notices, (3) the persistence hint with `require("serpantinum/monitors")` when
  `persistence.included` is false.
- `DisplayMonitorCard.qml`: Resolution, Refresh rate and Orientation dropdowns (from
  `modes`), power toggle driven by the compositor and disabled for the last enabled
  monitor, scale slider uses the backend `validScales`. Controls are disabled while a
  transaction is pending. Blue light filter group is upstream code.
- Backend `reflow_plan`: a size/scale/rotation change shifts neighbours so the layout
  stays attached (otherwise the validator would reject overlaps / warn about gaps).
- i18n: `guide.display.txn.*`, `resolution.*`, `refresh.*`, `orientation.*` in en/es
  only; the other 21 languages fall back to English via `I18n.t`.

DONE (step 3): arrangement map.
- `DisplayLayoutMath.js` (`.pragma library`): pure geometry in LOGICAL pixels. `resolveDrop`
  = edge magnet (threshold ~10 px on screen) -> push out of overlaps -> if it floats free
  or would cut another screen off, nearest spot that touches a neighbour AND keeps the
  whole layout connected. Tested with `node --test tests/display/` (15 tests).
- `DisplayArrangementMap.qml`: enabled monitors at logical size on a grid; number, refresh
  on top, `name  W×H` below, star on the focused one; a ghost rectangle shows where the drop
  will land (red when rejected). Drop -> `tab.txnChange(name, {x, y})` (same confirm banner).
  Disabled while a transaction is pending/busy or with a single monitor.
  `dropMonitor(name, lx, ly)` is the testable entry point. Refresh button = `reloadMonitors`.
- i18n en/es: `guide.display.map.*`, `txn.err_layout_overlap`, `txn.err_layout_disconnected`.

TODO (in order):
4. Profiles: Save profile / Load profile... next to the map's Refresh button (see mockup).
   Store each monitor WITH `description` in Config key `display.profiles`; load with
   `apply <json> --partial` (absent monitors dropped with a warning).
5. Translations for the other 21 languages (optional, English fallback works).
6. Physical test (below).

KNOWN GAP: the map's VISUAL rendering and real mouse dragging have not been seen. The
harness drove `dropMonitor` (snap to (950,1080), push-out to the free side, revert) and
the component loads with no QML errors, but screenshots failed: a nested Hyprland's window
is only rendered while it is visible on the host desktop, so `grim` and `grabToImage` hang
or return nothing. To see it yourself run `tests/display/try-ui.sh`: nested Hyprland + 2 virtual
monitors + the Display page, fully isolated (temp HOME/config/state, deleted on exit).
The user can drag the monitors with the mouse; nothing real is touched. Do not call `hyprctl dispatch` from
scripts without confirming which instance it targets.

## How the UI was verified (repeat this after UI changes)
Throwaway `qs -p` harness (never commit it) with a `Loader` that does
`setSource("guide/display/DisplayMainTab.qml", {rootObj, tabIndex:0})` and a Timer
driving `tab.txnChange/txnConfirm/txnRevert`, run against a NESTED Hyprland with
`hyprctl output create headless` x2. Isolation env: HOME, XDG_CONFIG_HOME,
XDG_STATE_HOME, XDG_CACHE_HOME, QS_SETTINGS, QS_CACHE_DIR, QS_STATE_DIR, QS_RUN_DIR,
IPC_SOCKET and SERPANTINUM_DISPLAY_RUNTIME all point to a temp dir; set
HYPRLAND_INSTANCE_SIGNATURE and WAYLAND_DISPLAY to the nested ones (find the new
`wayland-N` socket by diffing `$XDG_RUNTIME_DIR`). Do NOT use `serpantinumd` for this:
it can stop the running shell. Screenshot with `WAYLAND_DISPLAY=<nested> grim -o WAYLAND-1`.
Seen working: apply, countdown banner, block while pending, confirm keeps + persists,
revert on request (~2 s), timeout revert (15 s), unsupported-mode error in Spanish,
reflow (HEADLESS-2 x 2870 -> 2230 when HEADLESS-1 went 1.0 -> 1.5).
Bug found by it and fixed: the systemd reverter did not inherit
`SERPANTINUM_DISPLAY_RUNTIME`, read another txn.json and exited; now `spawn_watcher`
forwards every variable the script reads and the resolved runtime dir.

## Persistence (decided by user: own module, like nwg-displays)
On confirm, `display_txn.py` writes `~/.config/hypr/serpantinum/monitors.lua`
(atomic, previous kept as `.bak`, gated by `Hyprland --verify-config`). The user's
files are never written; they opt in with `require("serpantinum/monitors")` placed
AFTER their own monitor rules. Disabled monitors are never persisted (a missing
screen at boot must not leave zero enabled outputs). `state` returns
`persistence: {path, exists, included}` — the UI must show a hint with that exact
require line when `included` is false. Tests set XDG_CONFIG_HOME to a temp dir;
keep it that way.

## Monitor identity: panel description, not connector name
Connector names change between boots (the user's laptop flips eDP-1/eDP-2). Rules:
- Persistence (`render_lua`): `output = "desc:<description>"` when the description is
  unambiguous (`desc_unique`: non-empty and not equal/prefix of another monitor's
  description, because Hyprland matches `desc:` by PREFIX); otherwise the connector
  name. Strings go through `lua_str` (json.dumps emits `\uXXXX`, invalid in Lua).
- last-good, profiles and any stored plan go through `resolve_plan(plan, state, partial)`
  (called by `apply`, `validate` and `rescue`): panel description is the identity;
  the name only breaks ties between identical panels and is the fallback for plans
  with no description. Strict (default): any absent/changed monitor is an error.
  `--partial` (profiles, rescue): absent monitors are dropped with a
  `profile_monitor_absent:<name>` warning and connected monitors the plan does not
  mention keep their current setup.
- UI contract: profiles must store each monitor WITH its `description` (the `state`
  output already has it) and load with `apply - --partial`.
- Verified: `hl.monitor{output="desc:..."}` passes `Hyprland --verify-config` and is
  processed by the compositor (nested: a non-matching `desc:` changes nothing, an
  empty `desc:` prefix matches every output). NOT verified: a match against a real
  panel description, because nested/headless outputs have empty descriptions. That
  needs one check on real hardware (part of the physical test, TTY open).
- Tests: renamed connector, exchanged names between panels, identical panels,
  prefix descriptions, empty description, tricky characters (quotes, backslash, ñ,
  CJK, control char) validated with the real `Hyprland --verify-config`, rescue after
  a rename, partial profile with an absent monitor.

## Layout draft + Apply (latest UI change)

- Monitor card is two columns (GridLayout, `uniformCellWidths`): Enable | Vertical alignment, Resolution | Refresh,
  Blue light | Automatic schedule, then Color temperature and UI scale full width.
- "Vertical alignment" is a toggle (portrait yes/no, transform 1/0); flipped orientations are no longer exposed.
- Drag root cause: the page `Flickable` stole vertical drags, and the map was locked while a transaction was pending.
  Fixed with `preventStealing: true` and by making drops local.
- Dropping only stores a snapped position in `layoutDraft` (peach border = moved). Nothing runs until "Apply changes"
  (`layoutApply()` -> one transaction -> keep/revert banner). Discard / Refresh drop the draft.
- Per-monitor controls are blocked (`err_layout_draft`) while the draft is dirty.
- Verified headless against a nested Hyprland: move -> draft only; second move replaces first; apply -> pending,
  draft cleared; apply while pending refused; confirm keeps; revert restores. Visual look/drag feel: user must check
  with `tests/display/try-ui.sh`.

## Profiles

- `DisplayProfilesBar.qml` (registered in `guide/display/qmldir`): Save profile (inline name field), profile dropdown,
  Load, Delete. Stored in Config `display.profiles[name] = {monitors:[...]}` with each monitor's panel `description`.
- Load = `apply <plan> --partial` through the normal keep/revert transaction (absent monitors are dropped with a warning).
- Save/Load are refused while a layout draft is dirty or a transaction is pending.
- Verified headless: save, empty name refused, save while dirty refused, load restores layout as pending, confirm,
  missing profile refused, delete.
- Insert-between drops work on both axes (`insertBeside` in DisplayLayoutMath.js).

## Physical test (2026-11-05, real laptop eDP-1 "AU Optronics B156HAN15.H" + HDMI-A-1 Dell Inspiron 3043)

Backend run from the repo against the real Hyprland, isolated state, SERPANTINUM_DISPLAY_NO_PERSIST=1, TTY3 open
with `~/rescate-pantalla.sh` (rescue, then `hyprctl reload`). All passed:
1. move HDMI y=200, no confirm -> independent reverter restored it at 15 s (systemd-run on the real session).
2. move + confirm -> stayed; restored manually.
3. HDMI 1280x720 no confirm -> back to 1920x1080 at 15 s.
4. HDMI disabled no confirm -> re-enabled at 15 s, windows/workspaces returned to it.
5. `desc:` FIRST REAL MATCH: `render_lua` output passes `--verify-config`; `hyprctl eval` of the
   `desc:Dell Inc. Inspiron 3043 0x00000001` rule moved the HDMI; restore by `desc:` too.
6. UI window (`_try_real.qml`, temporary) on the real monitors: map drag/apply, card controls, profiles,
   keep/revert all worked (user report). Colours come from ThemeBackend (isolated run shows the default palette).
Follow-up: action row (profiles + discard/apply + refresh) moved under the map, buttons spread evenly over its width.

## Upstream sync (2026-11-06, base 2.4.2 / 08ab420)

- Rebased onto upstream 2.4.2 (22 new commits). Only conflict: upstream renamed the `BlueLight` singleton to `Gamma`
  and the i18n keys `guide.display.bluelight.*` to `guide.display.gamma.*`; the two-column card now uses both new names.
- Page load re-verified with the isolated harness (no QML errors, backend available, monitors detected).
- Local install updated by copying only `guide/display/` and `assets/languages/` (backup in
  `~/.local/share/serpantinum-backup-display-<date>`); the user's own `Sounds.qml` is untouched.
- After every upstream release the official updater overwrites `DisplayMainState.qml`, `DisplayMonitorCard.qml` and the
  language files with upstream's copies until this branch is merged: re-copy them from this branch.

## Multi-distro (NixOS, Fedora, Void; 2026-11-06)

The module lives in `src/`, which the AUR package, the installer and `nix/package.nix` copy whole, so it ships everywhere
without packaging changes (python3 and util-linux are already runtime deps; `wrapProgram` puts them in PATH on Nix).
Hyprland 0.57 only reads Lua: a `.conf` is parsed as Lua and fails, so no hyprlang output is needed.

- `serpantinum display <rescue|status|revert|confirm>` (bin/serpantinum): the stable rescue entry point. The script path
  changes with every `/nix/store` hash, so the CLI is what to type from a TTY.
- TTY rescue picks a live, NON-nested Hyprland (`find_hyprland_instances`: lock PID alive, no `WAYLAND_DISPLAY` in its
  environment, newest wins). The old "most recent instance" could repair a test window instead of the real screens.
- `runtime_dir()`: no `XDG_RUNTIME_DIR` and no writable `/run/user/<uid>` (Void without elogind) -> private
  `$TMP/serpantinum-display-<uid>` (0700, owned by the user, symlinks and foreign owners refused).
- `persist_info()` also returns `managed` (config dir or hyprland.lua links into `/nix/store`) and `writable`; the page shows
  `persist_managed_message` (add the line from the Nix configuration). Arch behaviour is unchanged.
- `verify_lua()` looks for `Hyprland` next to `hyprctl` when it is not in PATH (systemd user service); if still missing it logs
  "verify skipped" and persists anyway.
- `tests/display/containers.sh [fedora|void|nixos]`: the suite in read-only podman containers (81 tests each) + Void smoke
  (private runtime dir, `setsid` reverter) + NixOS check (a real store symlink is detected as managed; a copy of `src/`
  shaped like installPhase keeps `display_txn.py` executable).
- NOT verifiable without those systems: a full `nix build`/Home Manager switch, a real Hyprland on Fedora/Void/NixOS (no
  physical monitors in containers), the `hyprctl keyword` fallback on a Hyprland without `eval`.

## Compositor backends (branch feature/display-compositors)

Step 0: `find_hyprland_instances` asks each live instance for its outputs (`hyprctl -j monitors all`, 2 s timeout): a real
session has an output that is not `WAYLAND|HEADLESS|X11-n`; the process environment is only a tie-breaker when the query fails.
Verified live with the real session and a nested one running at once: the TTY picks the real one.

Step 1: `Backend` base class in display_txn.py (the interface every compositor implements: detect, discover, state, apply,
safe_plan, valid_scales, persist_path/render/verify/info/persist). `HyprlandBackend` is the first implementation; module-level
functions (`render_lua`, `persist`, `verify_lua`, ...) stay as its helpers so nothing observable changed. `BACKENDS` is the
registry; `display_txn.py backends` lists it; `state` now carries `"supported": true`; `persist_file()` is the shared atomic
write + verify + `.bak`; `validate()` takes the scale rule from `state["backend"]` (`scales_for`).
`DisplayMainState.qml` `txnBackends` must equal `BACKENDS` (a test enforces it); other compositors keep upstream's code.
Hyprland regression check: screenshots of the page (normal / naming / dirty) are identical to the previous branch (0 pixels
differ at 3 % fuzz) and apply / unconfirmed revert / confirm / rescue behave the same on a nested Hyprland.

To add a compositor: subclass `Backend`, implement the five required methods, register it in `BACKENDS`, add its name to
`txnBackends` in the QML, and cover it with a fake CLI built from captured JSON.

### Step 2: Sway (SwayBackend)

- State: `swaymsg -r -t get_outputs`. `refresh` is mHz; `transform` string maps to the Hyprland numbering (0-3 rotations,
  4-7 flipped); position is `rect.x/y` (logical); a disabled output has no `current_mode`, so it reports its best mode
  (otherwise it could not be switched back on); `non_desktop` outputs are skipped; description is `make model serial`
  and is empty when sway says `Unknown` (headless), which makes the connector name the identity.
- Headless/virtual outputs list no modes: the backend synthesises a few and sends `mode --custom` for them.
- Apply: one `swaymsg -r -- "output A enable mode ... position ... scale ... transform ...; output B disable"`; enables first,
  disables last; any `success:false` raises. Output names are validated before being put in a command.
- Scale: quarter steps in the UI, but `accepts_scale` takes any finite 0.25-4 so an existing `1.1` stays valid.
- Persistence: `~/.config/sway/serpantinum/monitors`, blocks `output "<make model serial>" {...}` (connector name when the
  identity is ambiguous or contains quote/brace/newline), checked with `sway --validate -c`, `.bak` kept, user adds
  `include ~/.config/sway/serpantinum/monitors` at the END of their config. `persist_info` scans the sway config dir (config.d too).
- Discovery from a TTY: `$XDG_RUNTIME_DIR/sway-ipc.<uid>.<pid>.sock`, dead pids skipped, same real-vs-nested ranking.
  `detect_backend()` now compares the best candidate of EVERY compositor by rank, so a nested test window of one kind never
  beats a real session of another.

**Bug found while testing, fixed (safety):** the reverter runs in `systemd-run --user`, whose environment is the user
manager's, not the caller's. It held the real Hyprland's `HYPRLAND_INSTANCE_SIGNATURE`, so the reverter of a Sway test
transaction operated on the REAL Hyprland (it moved the real monitors; put back by hand). Fixes: `spawn_watcher` passes
`SWAYSOCK` and `SERPANTINUM_DISPLAY_BACKEND` explicitly (`detect_backend` honours that variable and ignores the other
compositors' variables); `restore()` refuses (returns `failed`, logs why) when the compositor reached is not the one of the
snapshot or none of its outputs exist now. Both are covered by tests (`tests/display/test_sway.py`).
Lesson: test scripts run from inside the real session must `unset HYPRLAND_INSTANCE_SIGNATURE` AND never rely on the user manager's env.

Tested on a headless sway 1.12 (outputs HEADLESS-n): move, resolution+scale, revert, power off/on, confirm, unconfirmed
timeout (restores), `rescue` with broken screens, `serpantinum display rescue/status` from the CLI, the page in an isolated
window against that sway (map, include hint, keep/revert banner, confirm). Not testable there: real EDIDs (make/model/serial,
`output "<make model serial>"` matching at boot), real mode lists, VRR/HDR, disabling the output that holds focus/workspaces,
a real reload with the `include` line.

### Step 3: Niri (NiriBackend)

- State: `niri msg -j outputs` (a dict keyed by connector). `current_mode` is an INDEX into `modes` (null = off), `logical`
  is null when off, `refresh_rate` is mHz, `transform` is `Normal|_90|..|Flipped180` (parser strips `_`/`-` and is
  case-insensitive; unknown -> normal + log). Description = `make model serial` with `Unknown` for a missing part, exactly
  as niri spells it for `output "<...>"` matching; empty when all three are unknown.
- Apply: no batch in `niri msg`: per output `on`, `mode WxH@R`, `scale`, `transform`, `position set X Y`; enables first, `off`
  last. **niri exits 0 for an unknown output and for a bad mode** (it only prints "will apply when it is connected"), so
  `apply` raises on that text and the engine's `wait_for(state)` is the real check.
- Logical sizes are truncated (measured: 950/1.4 -> 678, 593.75 -> 593), same as Sway, so the floor in `validate` is right.
- Persistence: `~/.config/niri/serpantinum/monitors.kdl`, `output "<make model serial>" { mode "WxH@R" scale S transform "t"
  position x= y= }`, checked with `niri validate -c`. niri 26.04 supports `include "relative/path"` (relative to the including
  file; `~` expands; a missing file is an error unless `optional=true`). The hint uses the relative form. Reload is live.
- Discovery: `$XDG_RUNTIME_DIR/niri.<wayland-display>.<pid>.sock`; nested niri's only output is `winit` (added to
  `VIRTUAL_OUTPUT`). The socket name encodes the Wayland display, so `inside_niri()` can tell a process that is a client of
  that niri from one that merely inherited NIRI_SOCKET (Sway/Hyprland nested in niri): Hyprland/Sway `detect()` return false
  when `inside_niri()`.
- `NIRI_SOCKET` is passed to the reverter.

Nested niri (winit) limits: ONE output, and it ignores `transform` (always Flipped180) and `off/on`; its mode list has one
mode. Tested there: state, move + scale, confirm, revert, unconfirmed timeout, rescue (CLI too), persisted file accepted by
`niri validate`, `include` + live reload applying position/scale, page in an isolated window. NOT tested: multi-monitor
layout, resolution/refresh change, rotation, power off/on, the `off` JSON (assumed `current_mode: null`, `logical: null` from
niri-ipc), `_90` spelling in JSON, matching `output "make model serial"` against real EDIDs.

Opus review of step 3 (no code change needed): niri reloads its config live and "forgets temporary changes" of an output
whose config changed. Confirming a layout with an output OFF rewrites monitors.kdl without that output (disabled outputs are
never saved), so if monitors.kdl is included niri may switch that output back ON after the confirm. That is the safe
direction (a screen comes back, never goes dark) and the next state read shows it; documented, not "fixed", because saving
`off` could leave zero outputs at a boot where the other screen is missing. Verified: apply order, unknown-output rc=0
handling, socket ownership (st_uid), inside_niri() for nested compositors, KDL escaping + identity fallback, validate fallback.

**Test-harness lesson #2:** a script run from inside the real session is a client of the real Hyprland, so with
`SERPANTINUM_DISPLAY_BACKEND` unset the discovery correctly picked the real Hyprland and `rescue` moved the real monitors
again (restored by hand). Test harnesses must force `SERPANTINUM_DISPLAY_BACKEND=<backend>` and abort before applying if
`state` does not report that backend (nirie2e.sh does).

### Step B: Mango (MangoBackend), facts verified against mango 0.18.4 source and a headless mango

- State/apply use `wlr-randr` (JSON state; `mmsg get all-monitors` has no modes/make/model/serial and its `active` is FOCUS).
  Dependency added to nix/package.nix, both PKGBUILDs, the installer list and the dnf map (Void uses the same name). Without it
  `state` fails with `wlr_randr_missing`; the page stays on upstream's read-only code and shows a notice.
- Target pinning: `MangoBackend` created without an injected runner records the PID of `MANGO_INSTANCE_SIGNATURE`
  (`$XDG_RUNTIME_DIR/mango-<pid>.sock`) and, before EVERY wlr-randr call, checks with `SO_PEERCRED` that the socket named by
  `WAYLAND_DISPLAY` is served by that PID (`mango_target_mismatch` otherwise). `detect()` = `inside_mango()` (same check);
  from a TTY `candidate()` finds each mango's display by scanning `wayland-N` sockets for that owner PID, skips instances it
  cannot resolve, and ranks real/nested like the others. `SwayBackend.detect` now also requires `not inside_mango()`.
  `MANGO_INSTANCE_SIGNATURE` is passed to the reverter.
- Apply (mango applies outputs one by one, continues after a failure, does not stop all-off): `--dryrun` of every phase first
  (a rejected plan applies nothing), then (1) enable/reconfigure `--on --mode --pos --scale --transform`, (2) a position-only
  request for outputs that were off (mango AUTO-PLACES a re-enabled output to the right and ignores `--pos` of the same request,
  seen on the headless mango), (3) `--off` last. A plan with no enabled output is refused before any call. Refresh 0 Hz (virtual
  outputs) is shown as 60 and sent as `WxH` without `@`; an output with no modes (virtual output while off) gets no `--mode`.
- Negative positions: `Backend.allow_negative_positions = False` for Mango, validation error `position_negative` (QML key added).
- Persistence: `~/.config/mango/serpantinum/monitors.conf` (HOME based: mango ignores XDG_CONFIG_HOME), `monitor_rule=` lines
  `make:..,model:..,serial:..` when all three are present, safe for the one-line parser (no `, : # $ " ' = \`), unique among the
  outputs, else `name:^<escaped connector>$` (name is a PCRE regex). Width/height/refresh must be given together (a rule with only
  width is a parse error). Checked with `mango -p -c <copy named monitors.conf>`; `.bak` kept.
- **First vs last rule (found in the source, then confirmed on two headless mangos):** at STARTUP the first matching
  `monitor_rule` wins (`manage/monitor.c`), on CONFIG RELOAD the LAST one wins (`config/reapply.c`). So the include line is
  needed twice (first and last line of config.conf) or the user's rules win after the next reload. `source_optional=` exists and
  tolerates a missing file; `./` is relative to the config dir. `persist_info` returns `included` (any) and `complete` (first and
  last). Page text (23 languages) tells the user to add the line twice.
- Tests: `tests/display/test_mango.py` (71) with a fake wlr-randr that reproduces the observed behaviour, real JSON in
  `fixtures/mango_wlr_randr_headless.json`; a real `mango -p` test is skipped when mango is not installed.
- E2E only through the sandbox on a headless mango (`WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2`, no nesting in the real
  session): `e2e_run.py` all passed (move, scale, manual revert, timeout revert, rescue, power off/on, last-output refused,
  persisted file) and the page screenshots render the Mango persistence hint.
- Not testable without hardware: real EDID make/model/serial matching at boot, several real monitors, rotation on a panel,
  turning off the focused screen, config reload with the added lines on a real session, `serpantinum display rescue` from a TTY.

#### Opus review of Step B and its fixes (B1-B4)
- **B1 `Backend.after_persist(confirmed)`** (called by `finish()` right after `persist`, exceptions only logged): Mango's override
  waits 0.6 s (reload fires 150 ms after a watched file changes), reads the state and re-applies the confirmed plan with
  `guarded_apply` if the reload changed it. Reason: a reload re-applies every rule, so a user rule that wins or an output we
  turned off (never written) would undo a confirmed change. Proven with `tests/display/mango_reload_e2e.sh [first|both]`
  (real headless mango, config in a throw-away HOME, SANDBOX_EXTRA=HOME=...): passes with the hook, FAILS without it (even with
  the line first AND last, power-off is undone). Mango only watches files that existed at startup, so the script seeds
  `serpantinum/monitors.conf` like a second session; on a first-ever run nothing reloads.
- **B3**: `apply` always reads fresh state first; when any output wakes up, `--pos` of EVERY enabled output is re-sent.
- **B4 `serves_display(pid)`** (SO_PEERCRED; None when it cannot be told, e.g. a TTY): Hyprland (PID in hyprland.lock), Sway (PID in
  the socket name) and Niri (PID in the socket name) refuse a variable whose Wayland socket is served by another PID, so an
  environment imported from another session cannot select the wrong compositor.

### How to test against a compositor (Step A, mandatory)

Never run display_txn.py, the page or an e2e script against a test compositor by hand: a process started inside your real
session is a client of the real compositor (twice a test moved the real monitors). Two layers now prevent it:

1. Engine: `SERPANTINUM_DISPLAY_VIRTUAL_ONLY=1` makes `guarded_apply()` (the ONLY place that calls `backend.apply`; a test
   greps the source for any other call) read the state first and refuse, with `virtual_only_refused`, when any output is not
   `WAYLAND-n|HEADLESS-n|X11-n|winit`, or the plan names one, or the state cannot be read. It covers apply, profiles, restore,
   safe layout and rescue, and is forwarded to the reverter.
2. `tests/display/sandbox.sh <backend> <compositor-id> <wayland-display> -- cmd`: `env -i` with an isolated HOME/XDG_*/runtime,
   only the test compositor's variable, backend forced, VIRTUAL_ONLY=1; refuses a display or signature equal to the real
   session's, and refuses unless `state` reports the expected backend with only virtual outputs; snapshots the real Hyprland
   before/after (read only), and if it changed prints before/after, restores it (PID of the lock verified) and exits 3.
   `tests/display/sandbox_selftest.sh` checks all that with a fake hyprctl. `e2e_run.py` and `page_shot_run.sh` refuse to run
   outside it; use `tests/display/page_shot.sh` for page screenshots.

## Open
- Native review of the machine-made translations (all 23 languages exist).
