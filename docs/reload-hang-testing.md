# Reload hang — probe v0.2.19 / Dev Panel v0.2.3

## Evidence and limits

The user confirmed the v0.2.18 Default fallback, hover/page-exit cancellation,
and two-minute timeout. Reload All Mods with a live picker then hung the game
for several minutes, requiring a force close. No new game crash directory or
UE4SS dump was found for this event.

At 2026-09-16 00:43:19 UTC, logs confirm timeout restored the RGB preview, reset
the display handoff, explicitly equipped Default, and closed CP. At 00:45:19,
the failed reload reached Colors+Probe's fresh bootstrap (`generation=1`), but
logged no subsequent hook installation, recovery, or picker cleanup. DP's
deferred startup did not log completion either. This narrows the failure to
reload/startup, not a proven native call or proven deadlock. The restarted
00:49:13 UE4SS.log replaced the shared log from the hang; per-mod logs retain
the earlier timeline.

The fresh process then cleared the old RGB journal after finding no original
character, but retained the selection journal because the old SlotVM_560 no
longer existed. That stale record was moved, not deleted:

`debug/reload-hang-20260916/default_selection_recovery.txt`

Copies of both per-mod logs are beside it. These local evidence files are
ignored by Git. No game saves, RGB settings or action counters were edited.

## Changes

- A namespaced scalar string in `ModRef` shared variables survives Lua reloads.
  A monotonic disk counter supplies its identifier; a disk stamp tags both RGB
  and temporary-selection journals. A stamp alone never authorizes replay.
- `SESSION | CLASSIFIED | same-process-reload` plus `recovery_authorized=true`
  permits the existing strict identity checks and cleanup. It does not guarantee
  that an old editor/character still exists inside that process.
- `first-attach/new-process` means no shared marker existed. This may also mean
  the first installation of this version in an already-running game, hence the
  required full restart for this upgrade. Recognized prior-session records are
  archived without resolving any UObjects; unstamped or conflicting in-process
  records also place a shared hold on further writes until the game restarts.
- Missing shared APIs, corrupt metadata, archive/write failure, or an unfinished
  metadata replacement fail closed. No fallback to matching transient names.
- Archives append `.archive-<session>-<number>` to the original recovery filename
  in `DevPanel/`. Existing archives are never overwritten. New metadata uses a
  temporary file and recoverable `.previous` swap, compatible with Windows rename.
- Both mods flush dedicated log checkpoints before sending them to UE4SS output.
  `BOOTSTRAP`, scheduling/dispatch, deferred `RUN`, hook registration and same-Lua
  teardown now have entry/return markers. Only startup/recovery jobs are traced;
  normal 33ms UI polling is not logged each tick. DP UI behavior is unchanged.

The find-docs lookup confirmed [ModRef shared variables](https://github.com/ue4ss-re/re-ue4ss/blob/main/docs/lua-api/classes/mod.md)
persist across hot reloads, and the installed UE4SS DLL exposes the relevant
method names. The gate still requires successful live API calls/readback; string
presence in a DLL is not proof of runtime behavior. Only strings are shared,
never UObjects or callbacks.

## First live test

1. **Fully exit and restart the game** for this upgrade. The stale record was
   archived on disk, but the already-running v0.2.18 Lua state may still hold it.
2. Confirm Probe v0.2.19 and DP v0.2.3 load. Open Clone 8 → Primary Accent →
   Default, open CP once, then Cancel. Confirm Default returns.
3. Close DP with F6. With **both CP and DP closed**, use Reload All Mods once.
4. If responsive, open DP and perform another Default → CP → Cancel check.
   Report whether reload, reopening and restoration each worked. Do not save.

Do **not** repeat active-preview reload yet. If the closed-window baseline passes,
inspect its logs before testing DP-open/CP-closed and then live-preview reload
separately. If it hangs, report the time and preserve the tail of UE4SS.log
before restarting if convenient; per-mod logs append across restarts. No need
to wait several minutes repeatedly once the same hang is evident.

Useful checkpoints:

- `SESSION | SHARED READ BEGIN/RETURN`, `CLASSIFIED`, `READY` or `BLOCKED`.
- `STARTUP | DISPATCH BEGIN/RETURN` versus `RUN BEGIN/END` identify scheduling
  versus callback progress; a returned dispatch is not a completed callback.
- `STARTUP | REGISTER HOOK BEGIN/RETURN | <path>` narrows a registration boundary.
- `STARTUP | RUN BEGIN | tint:recovery`, `selection:recovery`, or `picker:startup`
  distinguishes recovery and widget cleanup from hook setup.
- DP also identifies UEHelpers, module initialization, keybind setup, old UI
  cleanup and registry scanning separately.

An unmatched marker narrows the boundary; it is not a native stack trace and
could include a stalled logging call. Lua mock tests cannot certify engine
locking, mod unloading, GC, or Slate behavior. This release is diagnostic
hardening, not a claim that the hang is resolved.

## Local verification

Eleven Colors+ suites and two DP suites pass. New coverage includes a reset Lua
state with surviving shared storage, a new process with reused object names,
legacy and mismatched provenance holds, archive collisions, missing APIs,
failed read/write/flush/rename, Windows destination semantics, interrupted
metadata replacement, and startup checkpoint presence. Compile-only Lua checks
do not execute the installed entrypoints or touch live recovery files.
