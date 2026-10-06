# UI lifecycle review — 2026-09-15

Follow-up: SWZC Dev Panel v0.2.2 supersedes the conservative close-on-every-screen
behavior below. It preserves the panel across ordinary menu changes, pauses
owned polling, invalidates queued clicks, and resumes only after fresh identity
and attachment checks. World travel/controller loss still closes it. The current
UE4SS hook/action documentation was rechecked through find-docs for this change.
Colors+Probe v0.2.16 adds a separate Default backend; see `live-picker-testing.md`.
The user subsequently confirmed panel persistence and picker re-entry. Default
still failed on the invalid auxiliary root. v0.2.17 replaces that dependency
with a verified character slot tree/Style association; Dev Panel is unchanged.
That field was also missing in-game. v0.2.18 supersedes new Default attempts
with a journaled temporary editor-swatch selection and ordered restoration;
see `live-picker-testing.md`. The historical review remains unchanged below.
The historical review below describes v0.2.15/v0.2.1, not the new Default behavior.

Scope: Colors+Probe v0.2.15 and sibling SWZC Dev Panel v0.2.1, reviewed against
the local `Zero_Company_UE4SS_Lua_Guide.md` (identical copies in both projects).
The find-docs lookup confirmed owned game-thread delayed actions and retaining
both hook IDs in the official UE4SS documentation:
[delayed actions](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/delayedactions.md),
[RegisterHook](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/registerhook.md).
Native lifecycle function names also exist in the local game reference dumps.

## Crash evidence and limits

The reported re-entry crash is `UECC-Windows-0945BA3940BC59A9EF76169E51BF8073_0000`:
GameThread access violation reading `0x18`, with the first frame in UE4SS.
The picker had already cancelled on the slot change and cleared recovery.
The shared panel recorded three successful picker actions, but no fourth action
at the reported crash. No new picker-open or RGB-write marker preceded the fault.
This makes panel/UI lifetime handling a reasonable first target, not a proven
native root cause. No source-line symbols or native GC simulation are available.

## Corrected findings

- Panel polling used `LoopAsync` → unowned `ExecuteInGameThread` callbacks.
  Both panel and bundled client now retain cancellable game-thread action handles.
- Queued mouse/F6 callbacks were not tied to a UI generation. Navigation,
  close/rebuild, and runtime replacement now invalidate prior work.
- Panel UI state and its cached controller survived screen transitions. Native
  `CommonActivatableWidget:DeactivateWidget` and `PlayerController:ClientTravel`
  pre-hooks retire panel sessions. Both IDs are retained and unregistered on reload.
  The panel deliberately closes on any activatable-screen deactivation, not just
  customization. It never restores an old input mode during that transition.
- Button hover/press reads lacked point-of-use validity checks. Retained widget
  identities are now resolved before access, with root attachment gating children.
  Missing identities never fall back to an old wrapper.
- Generic cached `require("ui")`/`require("registry")` modules and persistent
  keybind closures had no runtime owner. Modules now load by explicit source path;
  same-state keybind dispatchers route only to the current runtime. Failed hook
  or action cleanup blocks replacement and retains cleanup information.
- Failed/partial construction or removal could abandon panel state. Root identity
  now survives failures; child references are discarded and duplicate creation is
  blocked until cleanup succeeds. Cold-reload orphan discovery is bounded and
  restricted to this mod's root class/name pattern.
- Picker reopen rescanned every old UserWidget and removed even detached roots.
  Cleanup now runs once per runtime and removes only attached owned roots. The
  page-close hook ends the picker immediately, rather than waiting for polling.
- Client handler replacement could leave queued old callbacks active; dispatch
  now checks handler identity. `Shutdown()` retires jobs and reload replaces the
  previous per-mod client. Missing owned scheduling APIs disable integration.

## Verification and remaining work

Nine Colors+ suites plus two panel suites pass locally. Coverage includes delayed
invalid objects, scalar-identity reacquisition, removed viewports, queued old
clicks, page close, reload, cleanup failure/retry, input ownership, owned-root
filtering, client replacement, and all existing tint recovery tests.

The installed mod directories resolve to these source trees. No game save,
registry, counter, RGB configuration, or recovery file was intentionally changed.
The supplied/example/Colors+ client copies match; unrelated projects' helper
copies and any pre-existing ZIP packages are not updated by this pass.

An initial syntax-check command accidentally executed bootstrap outside the
game before the corrected compile-only check passed. The resulting log entries
at `2026-09-15T23:31:57Z` report missing UE4SS APIs and disabled integration;
they are offline test output, not a new game failure. No engine API was available.

Restart fully for this upgrade. Then follow `live-picker-testing.md`, especially
Databank exit/re-entry with both windows open. Native GC, Slate hit testing, and
the reported crash must be verified in-game; passing mocks is not that proof.
Exact prior gameplay input mode remains unqueryable. Navigation therefore yields
input ownership to the game rather than forcing a saved mode onto another screen.
