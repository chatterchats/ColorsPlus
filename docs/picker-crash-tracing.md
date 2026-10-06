# Picker crash capture — v0.2.40

Current-build note (v0.2.73): detailed tracing is opt-in. Open the target picker
with `colors_picker trace` to record one opening; normal openings do not start
a trace. The older RGB-slider reproduction below is retained as historical
context; the current integrated picker uses SV/hue/hex controls.

v0.2.40 fixes the tracing helper's `unpack` compatibility error seen in v0.2.39.
It uses `table.unpack` when available, falling back to the Lua 5.1 global.
This fixes the diagnostic-induced opening refusal, not the original crash.

## Evidence and limits

The 2026-09-17 12:02 UTC crash followed repeated Twi'lek marking interaction,
then tattoo picker opening. Tattoo installation/refresh/readback and PICKER OPEN
completed; no first RGB UPDATE VALIDATE BEGIN followed. This does not establish
whether opening, polling, a deferred snapshot or clicking the slider caused it.
A simpler subsequent test worked. The user then reproduced a different failure:
at 12:11:39 the selected-slot traversal refused a cycle at slot VM 238. Restore
completed at 12:11:42, but subsequent openings still refused the cycle. This is
a guarded Lua failure, not proof of the native crash's cause or failed Restore.

The existing cycle guard and mutation/ownership behavior are unchanged.

## Capture

1. Fully restart to load v0.2.40; do not use Reload All Mods. No save is needed.
2. Repeat the Twi'lek marking interactions that preceded the failure. Restore
   the tracked custom color before moving to Tattoo Color.
3. Open tattoo CP and wait about two seconds without touching its controls.
4. If it remains open, immediately click the red slider once. Report whether
   failure occurred before the click, during it, or not at all. Cancel/Restore
   after a successful test. Avoid starting other diagnostic traces concurrently.
5. If it refuses to open, stop there and report the error; repeated retries are
   not needed. If it crashes, leave the logs untouched and report the step.

In v0.2.40 tracing started on every opening; v0.2.73 requires `colors_picker trace`.
The trace ends on close, after 10 seconds or at 6,000 calls. The timer is game-thread-owned
and can be delayed under load; the call cap still bounds output. A busy capture
can exhaust the call cap before the timer. Logging may cause hitches or change
reproduction timing, so a successful test does not prove a fix.

## Reading the log

`src/Colors+Probe/colors_plus_probe.log` and UE4SS output contain `CALL TRACE`
records with runtime generation, window ID, call number and BEGIN/RETURN/ERROR.
Pair by generation/window/call, not just the last line: nested callbacks may
start other calls. Lua exceptions produce ERROR and preserve existing handling;
an unmatched BEGIN near a native crash narrows the suspect call but is not
proof by itself. Trace expiry/cap and interrupted logging must be considered.

UI reads/updates trace native lookup, validity, identity, viewport, button,
slider, text and brush calls separately. Widget construction is only partially
instrumented. Snapshot helpers additionally have grouped read boundaries;
fragment GetFragments/GetClass/GetColor calls have their own markers. Snapshot
capture BEGIN now precedes collection, even when the existing payload log is
deduplicated. Deferred job markers identify which owned callback was running.
This is not an exhaustive trace of all native calls in the mod or engine.

The trace stores only plain counters/window state. It introduces no native
inspection solely for logging, no permanent poll and no new hook. Existing
cancelled/retired-job checks run before tracing. Only Colors+ files change;
the installed SWZC Dev Panel application is untouched.
