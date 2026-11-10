# tasks-widget-v2.5.1

Restore the ToDos/tasks desktop widget on top of upstream v2.5.1 and redeploy it to the live install.

Feature branch: `feat/tasks-widget`. Upstream target: `upstream/master` = `83add3ac` (v2.5.1).

## Specs

- **S1** — "Muevete a la ultima actualizacion de este repositorio": the local branch must contain every commit of `upstream/master` (`83add3ac`, v2.5.1) as its base, with no upstream functionality removed.
- **S2** — "necesito que funcione nuestro widget ya que no esta apareciendo ahora solucionalo": the `tasks` widget must render on the desktop of the live install (`~/.local/share/serpantinum`) after restart, and must appear in the widget picker under the `time` ("Hora y texto") category.
- **S3** — The widget must remain resolvable under its aliases `tasks`, `todos` and `scrum` (registry `normalizeType`, `faceFile`, `variantList`).
- **S4** — `bin/serpantinum tasks|todos|scrum` CLI commands must work against `~/.local/state/serpantinum/quickactions/tasks.json`.
- **S5** — The existing desktop layout entry `wId: "todos-verify-test"` in `~/.local/state/serpantinum/widgets/Dell Inc. DELL S2721HN.../layout.json` must be preserved, not rewritten.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S1 | rebase onto `upstream/master` (`83add3ac`) | done — 6 commits on top of `83add3ac` |
| T2 | S1,S3 | resolve conflicts in `WidgetRegistry.qml`, `bin/serpantinum`, `Floating.qml`, `FloatingController.qml` | `e9bdff4e`, `9e127b9b` |
| T3 | S2 | deploy to `~/.local/share/serpantinum` (7 files + `bin/serpantinum`) | done — `diff -rq src` clean |
| T4 | S2 | restart quickshell, confirm the `tasks` widget renders | done — verified in redactor overlay |
| T5 | S4,S5 | verify CLI + layout preservation | done — `serpantinum tasks` lists 8 rows, `todos-verify-test` intact |

### Resolution decisions

- `src/quickshell/quickactions/Floating.qml`: took upstream. Our manual drawer auto-close hacks (`clickOutsideBackdrop`, `onActiveFocusChanged` kick, `hoveredBars` reset) are superseded by upstream's native `heldOpen` + `kickTimer()` mechanism introduced in v2.5.x.
- `src/quickshell/singletons/widgetcontrols/FloatingController.qml`: took upstream. Our `showTasks`/`showScrum` additions were explicit no-ops after the Tasks quickaction was purged from the lateral sidebar.
- `src/quickshell/widgets/WidgetRegistry.qml`: removed the stray `}` that the auto-merge re-introduced after the `types` object (the pre-rebase `574c698d` fix was dropped by the rebase as already-applied).
- `bin/serpantinum`: kept upstream's `gamma` rename and appended our `tasks` command to both the help listing and `ALLOWED_SCRIPTS`.

## Log

- **L1** (user, verbatim): "Muevete a la ultima actualizacion de este repositorio y necesito que funcione nuestro widget ya que no esta apareciendo ahora solucionalo"
- **L2** (evidence): live install `~/.local/share/serpantinum/version.txt` = `2.4.0` but its `src/quickshell/widgets/faces/qmldir` already contains `timer` faces and its `WidgetRegistry.qml` has **no** `"tasks"` entry. Our branch files (`TasksFace.qml`, `TasksBarFace.qml`, `Tasks.qml`, `tasks.sh`) are present in the install but unregistered. Root cause: an upstream update overwrote the registration layer while leaving the widget source files behind, so `WidgetFile`/`faceFile` resolution fails and the layout entry `wId: todos-verify-test` renders nothing.
- **L3** (decision): move the branch onto `upstream/master` (v2.5.1) rather than re-patching v2.4.0, then redeploy from the repo so future upstream updates are a clean rebase.
