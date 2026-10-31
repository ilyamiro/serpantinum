# Media source and visibility checks

Run from the repository root:

```sh
python3 tests/media/run.py
```

Requires Qt 6 `qmltestrunner`, Quickshell, and Python 3 with `dbus-python` and
PyGObject. The runner does not install anything. It creates a temporary HOME,
settings and source tree, uses a private session bus, launches only test
entrypoints offscreen, and never starts or restarts the desktop shell.

Run `python3 tests/media/run.py wayland-imports` separately to check components
that require a live Wayland session, without instantiating their windows.

## Coverage

- `tst_selection.qml`: automatic/manual selection, stable application keys,
  incomplete metadata, instance grouping, unavailable selections and deterministic
  instance retention. Plain JavaScript player fixtures.
- `lyrics.qml`: independent `LyricsProvider` contexts, stale responses,
  A→B→A requests, the same song from two sources, immediate metadata
  invalidation, paused-content availability and subscriber removal. No network
  requests.
- `lyrics_io.qml`: asynchronous cache and local-file processes, cancelled
  track requests and local-file precedence. Temporary files only.
- `mpris.qml` / `mpris_fixture.py`: real Quickshell MPRIS discovery against
  synthetic D-Bus services. Exercises discovery, strict manual selection,
  playback controls, paused instances, metadata updates and reconnection.
- `source_settings.qml` / `source_settings.py`: native Settings controls,
  updates in a second process, unavailable labels and restoration in a fresh
  process. Only the runner's temporary settings file is used.
- `components.qml`: bar Media visibility, fade and layout animation reversal,
  preview immunity, disabled input, retained lyrics subscriptions and QML
  component imports.
- `cross_process.py` with `settings_reader/writer.qml`: two real QML engines
  apply the source and visibility options through the native Settings controls;
  Media and lyrics react without restarting.
- `persistence.qml`: the selected values and a probe are written and restored by
  a fresh process.

The tests do not drive Spotify or a real browser UI, and do not verify every
visual layout. Check those manually in a development session before publishing.
