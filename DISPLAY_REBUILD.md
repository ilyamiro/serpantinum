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
- `python3 -m unittest discover -s tests/display` — 41 offline tests (fake hyprctl).
- Nested Hyprland with a HEADLESS output (never the real session): timeout revert,
  confirm, revert-on-request, disable+revert, watcher SIGKILL (setsid: healed by
  `status`; systemd: unit restarts and reverts), all-off rejected.
  Recipe: `Hyprland -c nested.lua &`, then `HYPRLAND_INSTANCE_SIGNATURE=<new sig>`
  `hyprctl output create headless`. ABORT if the signature equals the real session.

## Next steps (UI — follow the mockup image the user provided)
1. `DisplayMainState.qml` (hyprland only; leave niri/sway/mango code as upstream):
   - read monitors via `display_txn.py state` (has modes, validScales, description);
   - keep a `draftPlan` (deep copy of state as plan); edits change the draft only;
   - "Apply" runs `display_txn.py apply - --timeout 15` with the plan on stdin;
   - while pending: poll `status` every 1 s, show banner "Keep these changes?
     Reverting in N s" with Keep (`confirm`) / Revert (`revert`);
   - call `status` once on load (heals a transaction whose reverter died);
   - show validation errors from the JSON (map error codes to translated text).
   - Upstream `applyMonitorPower`/`applyMonitorScale` for hyprland must go through
     the transaction too (upstream lets you disable the last monitor and forces
     `position = "auto"` on scale changes).
2. `DisplayMonitorCard.qml`: resolution + refresh dropdowns from `modes`,
   orientation (transform 0/1/2/3), scale slider snapped to `validScales`,
   enable toggle disabled when it is the only enabled monitor. Keep blue light
   filter / schedule / temperature exactly as upstream (not part of transactions).
3. Arrangement map: numbered draggable rectangles (logical size), snap to edges,
   refresh rate on top, `name  WxH` at the bottom, star = focused; Refresh button.
4. Profiles: Save / Load (Config key `display.profiles`); loading = apply via txn.
5. Translations: new keys in `src/assets/languages/en.json` and `es.json` first.

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

## Open
- Physical test on real hardware with TTY3 open as backup (use Opus), including the
  first real `desc:` match check described above.
