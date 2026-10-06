# Picker preview performance tests

## v0.2.98 automatic tester capture

No console setup is needed for normal picker testing. Capture starts on the
Custom Color press (or a console/DP open) and appends to
`ue4ss/Mods/Colors_Probe/colors_plus_performance.log` until the picker closes.
Verify Cancel, Apply, navigation and failed-open outcomes, then reopen and check
for a new window. Leave a draft open for more than two minutes to confirm there
is no capture timeout. Opening and cleanup timings should be present alongside
the existing update stages. Full procedures and report contents are in
[TESTING.md](../src/Colors+Probe/TESTING.md).

Historical manual-capture instructions below apply to older builds. In v0.2.98,
`colors_perf start` still provides a 120-second diagnostic window outside the
picker. Inside the picker, automatic ownership prevents start/stop commands
from truncating the tester capture; `colors_perf report` may flush a summary.

## v0.2.96 priority test: every supported picker slot

The user confirmed Human, Twi'lek and Ovissian skin now feel as smooth as Zabrak.
October 1 v0.2.95 timed captures show Human at 29.53ms/update and Ovissian at
34.35ms/update. The remaining captured RGB slots still perform three global
context searches per update and use the old poll-count cadence:

| Target | Updates | Average update ms |
| --- | ---: | ---: |
| Twi'lek lekku markings | 13 | 177.62 |
| Zabrak horns | 9 | 233.89 |
| Tattoo | 22 | 163.77 |
| Lipstick | 12 | 175.58 |
| Eyeliner | 14 | 176.07 |
| Eye shadow | 10 | 150.70 |
| Eyebrow | 12 | 200.33 |
| Eyelash | 10 | 222.40 |
| Armor Main Color | 91 | 86.92 |

Armor has the elapsed-time scheduler and bound post-write checks, but still
spends about 61ms/update on its initial validation. No timed blush window was
found in this session, although the picker was opened there. No dropped labels
or preview-update errors occurred in these captures. Armor's capture includes
four separate discovery-label errors, not RGB update errors. These inclusive
profiler-clock averages are not frame timings or controlled benchmarks.

v0.2.96 removes both performance-policy restrictions for supported profiles.
RGB and native HSV picker drafts now discover once on the first update, reuse
only scalar route identities thereafter, and keep all fresh native checks and
event invalidation. Scheduling uses the same immediate-first/latest-only gate
with a 100ms post-update cooldown and 495ms idle health checks. Apply flushes the
latest input; Cancel wins. Native HSV bypasses RGB conversion as before.
Source-backed Zabrak and compatibility gates are unchanged; no changes are made
for the reported old-model Eyes Color rejection.

1. Fully restart into v0.2.96. Capture the previously choppy slots, with separate
   `colors_perf start` / `colors_perf stop` windows where practical. Drag SV or
   hue for 10–15 seconds, then release and pause. Include armor, blush and hair
   root/tip; native scar HSV is a useful additional scheduling regression.
2. Check Apply → radial round trip → Restore and changed-draft Cancel on a
   simple color, a companion-bearing color (e.g. blush) and armor from Default.
   Switch slots/leave customization during a draft, then reopen another slot.
3. Briefly check Human/Twi'lek/Ovissian and Zabrak skin remain smooth. Confirm
   companion settings (e.g. blush mode/scar strength) remain unchanged.

Every supported picker OPEN should report latest-only preview. Stable updates
should use `tint.resolve_bound` for all three validation stages; first updates,
context events, opening and idle/display checks can still discover globally.
Compare `tint.preview_update` and `update.validate_*` against the table above.
No native speedup is claimed for this build until results arrive.

## v0.2.95 priority test: shared skin draft lookup

The October 1 v0.2.94 captures at 19:04–19:06 UTC confirm the user-reported
smooth Zabrak/armor result and slower shared skins:

| Target | Updates | Average update ms | Peak ms | Full context search average ms |
| --- | ---: | ---: | ---: | ---: |
| Zabrak | 103 | 35.86 | 117 | Bound route 2.60; one full rediscovery |
| Armor | 41 | 58.78 | 79 | 46.63 |
| Human | 41 | 100.71 | 162 | 68.10 |
| Ovissian | 83 | 80.28 | 181 | 49.08 |
| Twi'lek | 34 | 108.62 | 198 | 62.42 |

These are sample-weighted, inclusive profiler-clock costs, not frame timings or
a controlled benchmark. No dropped labels occurred. Human's capture includes
selection/discovery error counts around picker/page closure, not RGB update
errors; do not interpret those nested counters as eight independent failures.

v0.2.95 keeps the shared skin route between updates in the same live draft.
It contains scalar page/auxiliary VM/creator identities, never native objects
or cached validation results. All selected source, preview, companion and mesh
checks still execute. Every context event invalidates it, including events
during a write. Reentrant pre-validation events refuse the update before any
write. Opening/reopening, Restore/recovery and idle/display checks keep their
existing discovery paths; consumer failure also discards the route. Armor,
Zabrak, UI layout, no-draft-timeout behavior and saved-color handling are unchanged.

1. Fully restart into v0.2.95. Capture Human, Twi'lek and Ovissian separately:
   `colors_perf start`, close the console, drag SV slowly/quickly for 15–20 seconds,
   release and pause, then `colors_perf stop`.
2. For each, check Apply → radial round trip → Restore and changed-draft Cancel.
   Switch slot/leave customization during a draft and reopen on another skin:
   the old preview must close/restore and the new draft must target its own skin.
3. Smoke-test armor and Zabrak to confirm their smoothness is unchanged.

The first skin RGB update should still discover globally. Stable later updates
should use `tint.resolve_bound` for all three validation stages, with Human also
using `skin.resolve_bound` for face enabling. Events and idle/display checks can
legitimately add full discovery. Compare `tint.preview_update`,
`update.validate_before`, `update.skin_enable` and `update.write_color` with the
table above. No native speedup is claimed until these results arrive.

## v0.2.87 priority test: armor and Zabrak

The v0.2.86 captures averaged 78.11ms Human, 83.95ms Ovissian and 104.49ms
Twi'lek updates. Zabrak averaged 134.51ms (105.4ms validation, including 66.41ms
context resolution; core 29.11ms). Armor averaged 166.75ms, with three full
validation passes totaling roughly 154ms. SV input remained below 0.5ms on
average. These are inclusive profiler-clock measurements from different
sessions, not controlled frame-time benchmarks; do not sum nested labels.

Armor now discovers context once per update and freshly verifies the exact
route after writing and refreshing. Context events force full rediscovery.
It also uses skin's elapsed-time schedule: first changed input immediately,
latest-only samples with a 100ms post-update cooldown, and 495ms idle health
checks. Successful validated updates rearm health checks. Apply flushes the
latest input; Cancel and context invalidation retain priority.

Zabrak keeps scalar identities for the current draft's selected context, not
native wrappers or validation results. Each use reacquires and checks the exact
active creator/page, VM, owner, part, source and targets. Every native context
notification discards the route, including notifications while busy. A context
event during validation rejects that read. Opening and the first read after an
event still discover fully. Other appearance scheduling, recovery journals,
source guards, native refresh order and saved-color behavior are unchanged.

1. Fully restart into v0.2.87. On armor Main Color, run `colors_perf start`,
   close the console, drag SV slowly/quickly for 15–20 seconds, release and pause,
   then `colors_perf stop`. Repeat for an accent; include a Default entry.
2. Make a separate capture on Zabrak skin with the same drag/pause pattern.
   Note first movement, continuous drag and release separately; compare a short
   unprofiled drag if profiling changes the feel.
3. On both paths check Apply → radial round trip → Restore, plus changed-draft
   Cancel. Switch slot/leave customization during a draft: it must close and
   restore. Check a Human skin draft as a shared-backend regression.

Armor should show one `tint.resolve` and two `tint.resolve_bound` calls per
ordinary update, with `tint.resolve_fallback` allowed after context events.
Compare `update.validate_*` and total `tint.preview_update`. Zabrak should use
`zupdate.context_bound` after the first `zupdate.context_discover` of a draft
or event; compare `zupdate.validate`, `zupdate.source_guard` and `zupdate.core`.
Report failures and dropped labels as well as times. No native speedup is yet
claimed for this build.

## v0.2.86 priority test: exact handoff lookup and scoped face context

September 30 stage captures (22:51–22:53 UTC) averaged 204.67ms per Human update,
148.66ms Ovissian, 160.07ms Twi'lek and 92.78ms Zabrak. Human's three core
validation stages totaled about 123ms/update; face enabling added 72.89ms, of
which 70.61ms was context discovery. Ovissian/Twi'lek validation totaled about
137/139ms. Refresh averaged 4.61–11.50ms, and recovery writes about 1ms/update.
No failures or dropped labels appeared in these captures. These are inclusive
profiler-clock measurements, not frame times or a controlled comparison.

v0.2.86 changes lookup work, not what must be validated. Handoff verification
reacquires the recorded container, validates every live ownership/storage/display
link and retains mesh checks. If lookup is missing, original unique discovery
runs and must still match the recorded identity. Initial open, activation and
restore keep full discovery; a mismatched link fails rather than selecting a
replacement container.

Shared SkinTone updates offer a synchronous reader to the face-enabling helper.
It reacquires context through the transaction's scalar route, reruns ownership,
source, preview and mesh checks, and falls back to full discovery after a native
context notification. It runs after busy mode ends, and is revoked when the
consumer returns or throws. No native result/binding is cached across ticks.
Opening, idle checks, manual probes and applied-mode enabling keep their existing
paths. Recovery writes, native refreshes and saved-color behavior are unchanged.

1. Fully restart into v0.2.86. Run `colors_perf start`, drag Human skin SV slowly
   and quickly for 15–20 seconds, pause briefly, then `colors_perf stop`.
2. Repeat on Ovissian or Twi'lek, then Zabrak as a regression/baseline comparison.
   Record whether brief pauses remain, with a short unprofiled drag if useful.
3. Check Apply → radial round trip → Restore, plus Cancel on a changed draft.
   Change a slot or leave customization during another draft: it must still
   close/restore. Smoke-test one armor color because it shares handoff validation.

Compare `update.validate_*`, `update.skin_enable` and `skin.resolve_bound` against
the earlier capture. Normal Human RGB updates should use `skin.resolve_bound`;
opening/idle checks can still report `skin.resolve_context`. Context notifications
can legitimately produce `tint.resolve_fallback`. `update.core` now measures the
core transaction directly, excluding its success log and consumer; compare its
children and `tint.preview_update` for continuity. No speedup is claimed until
these native results arrive.

## Previous capture: update-stage profiling (`update-stages-v1`)

The user verified all v0.2.82 test steps, with brief lag remaining. The September
30 captures at 22:35–22:36 UTC measured Human updates at 177.38ms average/242ms
peak, Twi'lek at 157.48/212ms and Ovissian at 157.00/219ms. Human's previous
average was 296.48ms; these are different sessions, not a controlled benchmark.
Across the new captures, bound resolution averaged 1.68ms and SV input 0.38ms.

The next pass instruments update stages; it does not yet change update behavior
or claim another speedup. Profiling retains the normal 120-second/5-second
capture windows and now allows at most 96 labels per interval. A capture start
includes `update-stages-v1`; the shared package version is left unchanged while
separate appearance/HSV development is in progress. Only stage instrumentation
is deployed from this pass, not unrelated work-in-progress source changes.

| Label | Measured work |
| --- | --- |
| `update.skin_stop` | Restore/retire previous face-tint ownership |
| `update.core` | Shared preview transaction, containing the stages below |
| `update.validate_before`, `update.bind_creator` | Pre-write verification and exact creator binding |
| `update.journal_intent`, `update.journal_complete` | Recovery record encoding, open/write/flush/close |
| `update.write_color` | Fragment color write, including companion handling |
| `update.validate_after_write`, `update.validate_after_refresh` | Fresh ownership/readback checks |
| `update.refresh` | Preview RefreshCustomization call, including synchronous callbacks |
| `update.skin_enable` | Reacquire/re-enable the displayed face tint |
| `skin.resolve_context`, `skin.assigned` | Nested face-enabling discovery and assigned-material validation |
| `zupdate.*` | Separate Zabrak validation/core, source checks, journal, write and refresh |

Native call ordering, validation, journal ordering, ownership, refreshes, watcher
scheduling, save behavior and restoration are unchanged. No extra native calls
are made to obtain timings. With profiling off there are no clock samples or
timing records. With profiling on, aggregate records add some overhead. Errors
count thrown Lua errors, not every `false`/`nil` refusal; inspect workflow logs
as well. Inclusive parents overlap their children: do not add `update.core` to
its validation/refresh/journal rows or sum `skin.assigned` into `skin_enable`.
These are profiler-clock costs, not guaranteed frame/wall timings.

1. Fully restart. On Human skin, run `colors_perf start`, close the console and
   drag SV continuously for 15–20 seconds. Release, wait a few seconds, then run
   `colors_perf stop`. Keep the heavy per-call trace off.
2. Repeat with a fresh capture on Twi'lek or Ovissian, then on Zabrak. Note the
   race/order and whether pauses happen during dragging or after release.
3. Check Apply → radial round trip → Restore and one Cancel. This pass should
   behave identically, including existing saved colors and the draft timeout.
4. If profiling noticeably changes the feel, compare a short unprofiled drag.

Use these captures to choose the next optimization. In particular, distinguish
native refresh from full context resolution, face ownership work and file IO
before changing any of them. Any `dropped` labels must be accounted for when
interpreting missing stages.

## v0.2.82 priority test: shared skin update discovery

The v0.2.81 native captures averaged 85.05ms per Zabrak preview update (123
samples, max 177ms) and 296.48ms per Human update (29 samples, max 410ms).
SV input averaged 0.39ms and 0.48ms respectively. The user confirmed Zabrak felt
more responsive, Human remained choppy, and Apply/radial/Cancel/Restore passed.
Timings use the platform-dependent profiler clock; nested inclusive totals must
not be added, and these sessions are not controlled frame-time benchmarks.

v0.2.82 reduces core shared SkinTone context discovery from three full scans to
one per RGB update. The two post-mutation checks instead reacquire the exact
page and auxiliary VM route inside the same synchronous transaction. The creator
stack must still contain that exact active page. Slot, source/preview ownership,
RGB, companion fragments, target profile and mesh checks still run. A native
context notification invalidates the shortcut and forces full discovery. The
next update always starts with fresh full discovery; no native wrapper or route
is cached across ticks. All supported shared SkinTone layouts use this path.

The face tint-enabling helper retains its additional discovery; the separate
source-backed Zabrak backend and non-skin zones are unchanged. Refreshes, journal
writes, recovery and the v0.2.81 preview scheduler are also unchanged. All 40
regression programs pass, but actual speedup remains unverified.

1. Fully restart into v0.2.82. On Human skin, run `colors_perf start`, close the
   console, open Custom Color and drag SV slowly and quickly for 10–15 seconds.
   Run `colors_perf stop`. Compare character smoothness and marker responsiveness.
2. Repeat on Twi'lek and Ovissian skin to cover multi-target and swap-bundle
   layouts. Other supported race skins take the same shared path; report any
   race that is noticeably slower or fails to update.
3. On each tested skin, release and Apply, go out to radial and back, then Restore.
   Reopen, change a draft and Cancel. Check Zabrak once as an unchanged-path
   regression. Retest timeout/creator exit if convenient.
4. Captures expire at 120 seconds; start a fresh capture per race. Compare an
   unprofiled drag too if logging affects the feel.

Inspect `tint.preview_update`, `tint.resolve`, `tint.resolve_bound` and
`tint.resolve_fallback`. Bound calls still do full ownership/target checks; they
skip only redundant global discovery. Fallbacks indicate a native notification
invalidated reuse and are not automatically failures. Any remaining large costs
in refresh, enabling or journals need separate evidence before further changes.

## v0.2.81 priority test: skin dragging

The user verified v0.2.80 opening/closing improvement, radial round trip and
Restore. v0.2.81 changes only SkinTone preview cadence; other zones retain their
tested cadence. A fresh changed value is sent immediately. Then a 100ms owned
timer releases the next update, using the latest input sample. This removes
poll-count delay and does not retain an RGB queue. Timers themselves only set
Lua readiness flags; native work stays in the validated picker tick.

After a successful update, the backend explicitly reports that it completed its
existing validation/write path. Only this receipt rearms the 495ms idle health
timer, avoiding a separate full check while validated updates are flowing.
Unconfirmed updates still get the independent health check. No write-time
validation, recovery IO, source watch or two-minute timeout is removed. Apply
still flushes the newest value before closing, even during cooldown. Cancellation
owns all picker jobs, and stale timer tickets cannot affect a later draft.

1. Fully restart into v0.2.81. Run `colors_perf start`, close the console, and
   open Zabrak skin. Drag SV slowly and quickly for 10–15 seconds each. Compare
   the character's stepping and whether the marker/hex stays responsive.
2. Stop moving briefly, then change color again: the first edit after cooldown
   should respond without waiting for 13 input polls. Release and immediately
   Apply: the retained color must match the final picker value.
3. Check radial retention and Restore, then repeat on a non-Zabrak skin tone
   (e.g. Human). Cancel a draft and leave customization during another draft.
4. Run `colors_perf stop`; capture expires after 120 seconds, so restart it if
   necessary. Compare an unprofiled drag if profiling changes the feel.

Expected log: `skin latest-only preview; 100ms post-update cooldown`. Inspect
`tint.preview_update` and `tint.context_check` alongside input and queue costs;
context checks should fall during sustained validated edits and resume at idle.
`job.picker:preview-ready` / `job.picker:health-ready` are readiness callbacks,
not extra native writes. Retest the fixed draft timeout if convenient.

All 40 regression programs pass. Native improvement remains unverified. The
cooldown starts after synchronous write work, so this is neither 10 guaranteed
updates per second nor a claim of frame-rate rendering. Expensive backend work
can still create visible steps; this pass measures the safe scheduling change
before attempting to optimize the mutation path itself.

## v0.2.80 priority test: opening over a swatch

The user verified v0.2.79 responsive SV input, improved opening/closing and
Apply/radial/Restore. New capture averages were 0.42ms for SV input (previously
11.48ms), 80.7ms for preview updates and 61.2ms for context checks. Workloads differ;
these are profiler-clock observations, not controlled frame-time benchmarks.
The skin preview still updates in chunks at the existing throttled cadence.

The log at 19:28:17 UTC on September 30 showed `ResetPreviewedPart` cancelling
the Zabrak draft immediately after opening. v0.2.80 validates that event rather
than cancelling unconditionally. It does not ignore source or page changes, and
it does not relax `PreviewCustomizationPart`, selection, reset-to-default or exit
cancellation. No source RGB/refresh/write occurs merely to handle a valid reset.

1. Fully restart into v0.2.80. On Zabrak skin, click Custom Color and immediately
   move over a stock swatch before the pane appears. Repeat several times. It
   should stay open; look for `HOVER RESET | kept verified draft` when that event
   occurs. Report if it still closes, so the exact event can be identified.
2. Change the draft RGB, then Back/Cancel. Reopen and test actual slot changes
   and leaving customization: the picker must still close and restore.
3. Check Apply, radial round trip and Restore. Existing saved baselines and the
   fixed two-minute deadline are unchanged. The normal timeout should still work.

All 40 regression programs pass. This patch removes a duplicate source check
inside the event handler, not the expensive full checks before tint writes.
Preview scheduling optimization remains a separate follow-up after this test.

## Latest evidence and changes

The v0.2.78 user test verified consistent held dragging, but short clicks were
unreliable. Two native captures included two Zabrak skin opens and one horn open.
Across those captures, `sv.input` averaged 11.48ms and reached 657ms, while
`sv.pointer` averaged 0.225ms. Context checks averaged about 59–69ms; tint preview
updates averaged 101ms. Total opens were 430/395/705ms; SV grid construction was
only 7/9/8ms. These are inclusive `os.clock` timings, not wall/frame measurements.
No profiler errors or dropped labels occurred. The logs do not prove why any
individual short click was missed.

v0.2.79 replaces per-row/cell global object lookup with direct child traversal
from one freshly acquired grid. Child identity, order and count are still checked.
Selected-slot resolution now verifies the exact equipped item in the active
palette instead of walking all swatches; donor selection still walks the palette.
Launcher binding reuse retains fresh page/slot/creator/palette/ancestry checks.
No tint/save/recovery algorithms are changed. Native improvement is unverified.

## Priority retest

1. Fully restart into v0.2.79. Run `colors_perf start`, close the console, then
   open Custom Color on Zabrak skin. Try short clicks and held drags separately.
2. Cancel and reopen several times; compare opening hitches. Repeat on horns.
   Apply a draft, check radial navigation, then Restore. Report whether the
   marker/hex lagged as well as the character preview, and which slot was active.
3. Run `colors_perf stop`. Compare with one unprofiled pass if necessary.

Short clicks still use polling: reduced stalls may help, but a press and release
entirely between samples can still be missed. The following is a separate test,
not an already-verified fix for that limitation.

## Optional native click-event test

With CP closed and ordinary stock color swatches visible, run `colors_click start`,
close the console, and make several quick clicks on stock swatches. Then run
`colors_click stop`. This observer makes no tint/input/widget changes itself;
your stock swatch clicks still perform their normal game actions. Avoid saving
those selections unless wanted.

The log reports `CLICK EVENTS` counts for CommonUI/game press, release and click
handlers, distinguishing page-prefixed buttons from unscoped pooled controls.
It retains only four scalar name samples, stops on page/slot changes, 60 seconds
or 500 handler observations, and is inactive normally. Hooks remain runtime-owned
and inert after Stop until teardown. Native delivery is unverified; counts from
unscoped controls alone do not establish a usable picker event route. This does
not retry the unsuccessful plain UserWidget preview-event bridge or hook delegate
signatures. The 40 Lua regression programs pass, but cannot verify native dispatch.

## Earlier integrated-drag test context

The v0.2.77 input-only test passed: desktop coordinates moved while viewport
coordinates froze under native capture; fast clicks and focus return worked.
This build ports desktop-delta dragging into **Custom Color**. No tint/save
backend logic or SWZC Dev Panel files are changed.

## Native test

1. Fully restart. Enter a normal color selector (start with armor). Leave the
   isolated `colors_sv` probe closed. Run `colors_perf start`, close the console.
2. Open **Custom Color**. Drag across SV horizontally, vertically and diagonally.
   Marker, hex and preview swatch should follow; the character preview is still
   coalesced to roughly five updates/second, not one write per mouse sample.
3. Drag beyond each edge, release outside, move back without clicking. Color
   must stay still until a fresh press. Try fast clicks, hue changes and hex.
   Click placement still has the existing 24x16 quantization; dragging is continuous.
4. Switch to chat/back during a held drag, release, then click again. Coordinate
   loss/UI-scale changes suspend the old drag until release; no jump on return.
5. Test Back/Cancel, reopen, drag and Apply. Apply must flush the latest value
   even before the next scheduled preview write. Check radial navigation and
   Restore. Try skin (including Zabrak) and horns, noting which slot was slow.
6. Run `colors_perf stop` after the sequence. It writes the remaining summary.
   Capture expires after 120 seconds; restart it for longer testing. Test the
   independent two-minute draft timeout on a new opening if desired.

The SV area is now an owned, centered 400x240 UI-unit rectangle. Report clipping,
misalignment, incorrect drag distance, missed clicks, or any crash. Native
verification is still needed; mocks cannot prove engine rendering/capture.

## Performance log

- `colors_perf start`: enable a 120-second window, with summaries every 5 seconds.
- `colors_perf report`: flush/reset the current interval without ending capture.
- `colors_perf stop`: final summary and cancel owned profiling jobs.
- Normal operation leaves profiling off: no clock sampling or per-input IO.
- Use the usual `colors_plus_probe.log` / UE4SS log; filter for `PERF |`.
  Keep `colors_picker trace` off during performance testing because its detailed
  flushed call logs materially alter timings.

Each interval reports count, average, maximum, total, >=16ms count and errors.
Rows are bounded to 64 labels per interval and ordered by total cost. Excess
samples for new labels are counted as dropped. No mouse coordinates, character
identifiers, native wrappers or returned function values are retained in stats.

Important rows:

- `ui.open`, `ui.cleanup`, `ui.prepare_pane`, `ui.hsv_build`, `ui.sv_grid_build`,
  `ui.gradient_bind`: initial/reopen costs (the 384 click-seeding buttons remain).
- `ui.read`, `ui.hsv_read`, `sv.input`, `sv.pointer`: polling/native lookup costs.
- `ui.object_lookup`, `sv.grid_lookup`, `sv.child_lookup`, `sv.hovered`,
  `sv.pressed`, `hsv.*`: finer input/control attribution in v0.2.79.
- `context.selected_slot`, `context.reuse_binding`, `context.discover`,
  `tint.resolve`: repeated validation and opening target-resolution costs.
- `ui.show`, `ui.initialize`: preview swatch/initial control work. HSV marker,
  hex synchronization and gradient painting are included in `ui.hsv_read`.
- `tint.begin`, `tint.preview_update`, `tint.context_check`, `tint.final_update`,
  `tint.apply`, `tint.cancel_restore`: synchronous backend calls, including their
  recovery file IO and native work. No new backend writes are introduced.
- `job.*`: owned scheduled callback cost, including color UI and editor watchers.
- `queue_clock_late.*`: sampled dispatch-clock time beyond the requested delay.

**Clock limitation:** all values are `os.clock` milliseconds. This clock's
semantics/resolution depend on the runtime/platform; it can measure CPU time
rather than wall elapsed time. Queue-clock lateness is therefore only a diagnostic
hint, not a reliable frame/latency measurement across platforms. No GPU timing,
FPS measurement, percentile estimate or attribution to a native thread is claimed.
Intervals follow owned game-thread timers and may be late if that thread stalls.
Timings are inclusive: nested phase totals overlap and must not be added. Reports
and instrumentation have overhead; compare an unprofiled pass if lag changes.

## Safety and implementation

The normal pane's earlier FGeometry bridge returned unreadable coordinates.
Instead of retrying it in the real picker, native grid cells locate the first
click; a held press then checks only its original cell and desktop cursor deltas
divided by `GetViewportScale`. Fixed owned dimensions convert those deltas to S/V.
No new geometry, Slate style struct or input-mode calls are added to this path.
The opt-in click-event observer above is separate from production SV input.

The native-tested event hook delivered zero events, so this path deliberately
uses native button polling, not an assumed quick-click event bridge. Very short
presses entirely between samples can still be missed. HSV polling is 16ms, tint
updates are latest-value-only every 13 polls (~208ms), and backend health checks
are every 31 polls (~496ms). Native callback time adds to these requested delays.
Cancel/back bypass input reads. Context changes, timeout, close/reopen and reload
retain existing lifetime/restoration gates. No UObject wrappers survive a tick.

Regression coverage includes frozen viewport coordinates, clamping without
drift, hover/no edit, fresh wrappers, focus/scale suspension, actual HSV/hex/marker
integration, 16ms coalescing/Apply flush, profiler nil/error behavior, bounded
windows/labels, same-state console reuse, scheduler tracing and teardown.
