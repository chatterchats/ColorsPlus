# Colors+Probe status history

The README's former running status notes, kept verbatim for reference
(v0.2.x development). Current changes are recorded in `CHANGELOG.md`. The
per-version test and research notes these entries cite were removed from
`docs/` in the v0.3.0 cleanup; they remain in git history (commit 39c0233).


**Current build: Colors+Probe v0.2.119 (swatches ignore the mouse while the picker launches).**

Hovering the swatches while pressing Custom Color could preview a swatch just
after the picker's preview session began, closing the picker. The swatch grid
now ignores the mouse from the press until the picker hides it.

Previously (v0.2.118):

Scalar page/VM lookup hints are now retired only when the page, creator or
slot category changes; other notifications still refuse lookups in flight.
Every hint use is fully revalidated, so openings and updates skip repeated
whole-object `FindAllOf` discovery.

Previously (v0.2.117):

UE4SS answers repeat name lookups from its own cache, but a first lookup of a
new object scans every UObject. v0.2.117 records the widgets the picker builds
(and stock widgets it already holds) instead of looking them up by name.

Previously (v0.2.116):

v0.2.116 keeps the lookup cache during applied edits (post-Apply watch),
logs only the first update per session, builds editor zones on demand and
runs each script once per bootstrap (~2,400 -> ~70 file loads at startup).

Previously (v0.2.115):

Performance captures now include an `ENV` line (UE4SS/Unreal/Lua versions,
Proton detection) and a `lookup.static_find` row with each machine's raw
lookup cost, so no separate UE4SS.log is needed.

v0.2.113 captures showed the picker's cost was almost entirely full-path
`StaticFindObject` calls (~11-20ms each): ~12 per 16ms idle poll and ~12 per
preview update. v0.2.114 reuses lookup results only while the launcher/picker
holds a session cache; every native hook callback, release or failed recheck
drops it, and each hit is rechecked by `IsValid` and exact name within a 1s
verification window. Performance summaries report `object_cache` hits/misses.
Native measurement pending.

Previously (v0.2.113):

Selected-slot discovery and tint context reads now reuse scalar page/auxiliary
VM/creator identities while reacquiring native objects and checking the live
page, palette and source on every call. Failed hints use full discovery; native
context events invalidate hints for inactive zone workers too. No native object
wrappers or successful validation results are cached. Opening discovery can
also serve the first drag update. `tint.resolve_lookup` measures this path.
The latest-only preview cooldown is 75ms instead of 100ms; Apply still flushes
the newest input and idle health checks keep their existing cadence.

Native v0.2.110 testing found Tone 4 (`0B0`) and Tone 5 (`0B1`) choose
incompatible preview donors: `MI_Head,MI_Body` versus `MI_Head`. Tone 4 now
prefers the observed matching `0B2` from its live palette, confirmed working
including the radial round trip in v0.2.111. Tone 5's same-swatch preview was a
native no-op. It now uses `0B0`, with the stock donor's `MI_Head,MI_Body` target
recorded separately from the editable source's `MI_Head` target in `proxy-v12`.
Stock validation/cleanup uses the donor baseline; installed clones and their
restoration require the original source profile/color. This exception is
limited to the captured head-only `0B1` layout and exact `0B0` donor. Older
recovery records remain readable. No automatic equip or material-pointer reads.

Tone 10 (`1B0`) passed the order check but refused its swap target in v0.2.110.
The v0.2.111 diagnostic captured `MI_Head0` instead of `MI_Head`, with the same
parameter and six mesh targets. Accept that exact additional swap target only
for `1B0`, preserving its signature and slot string through restoration and
recovery. Unrecognized targets still refuse; no material pointers are read.
Tones 4, 5 and 10 passed native round-trip, Cancel/Restore and save/restart tests
on v0.2.112. Performance improvements in v0.2.113 need native measurement.

The captured `CPD_H_SkinTone_Hum_Zabrak_1B0` source starts with swap/tags/color/
scalar (`4,1,2,3`). Its source transaction now accepts that exact additional
order, preserving the captured original order and scalar targeting in the
journal for Cancel/Restore and same-process recovery. Arbitrary permutations
remain rejected; all ownership/target/role checks and interrupted-handoff holds
remain. No automatic swatch switch or material-pointer access. Native visual
confirmation of the combined order/target support passed on v0.2.112.

Opening seeds the controls from scalar color values during the construction
frame, reusing only the just-built, identity/validity-checked owned widgets.
Those wrappers are released before native preview setup. The verified preview
color remains authoritative: if it differs, the controls are initialized again
through fresh lookups; otherwise a fresh attachment check still runs. No hidden
prebuilding or cross-frame UI cache. Preview setup reuses its scalar page/aux
route for repeated source validation, with native events forcing rediscovery.
New `opening.*`, `ui.seed` and `ui.ready` aggregate timings separate these costs;
`ui.open` now includes the construction-time seed. Native latency confirmation
showed successful v0.2.109 openings of 309–740 ms across different Zabrak swatches
(not a controlled comparison). Swatch-hover cancellation behavior is unchanged.

Validation now reports `validate.source_fragments`, `source_profile`,
`source_target`, `source_meshes`, `source_companions`, `preview_fragments`,
`preview_color_target`, `preview_meshes` and `display_links` (all with the
`validate.` prefix). These are inclusive substages, batched with existing
five-second summaries; the fixed label budget is 128. No per-call trace added.

Bundle matching uses colors already gathered by its fresh native read, and
preview validation performs one matched bundle traversal instead of two.
Each companion class is also read once per traversal. Scalar snapshots are
consumed inside the same synchronous read; no validation result is reused
across writes, refreshes or callbacks. Source VM/owning-slot checks remain
separate. Recovery journal writes and the native refresh are unchanged.
The v0.2.108 Zabrak Tone 12 capture averaged 24.3 ms per update (90 ms maximum),
versus 27.6 ms (81 ms maximum) on Tone 8 previously. This is not a controlled
same-swatch comparison; occasional update spikes remain.

Detailed snapshots no longer run automatically on stock hover, equip, selection
or page activation. Explicit `colors_probe` / Dev Panel diagnostics remain;
context notifications, lifecycle guards and automatic picker performance capture
are unchanged. Idle checks and the delayed display check reuse the live draft's
scalar lookup route, reacquiring and validating native objects each time. An
untouched draft discovers once, then reuses that route. Native events, failed
checks and draft retirement invalidate it. No cross-callback UObject cache or
relaxed color/ownership validation. Local v0.2.107 testing found zero automatic
snapshots and idle context checks averaging 6.2 ms (49 ms maximum) in the
second Zabrak Skin Tone 8 session, with clean Cancel/restoration. The user
confirmed navigation caused the earlier preview exit and responsiveness felt
good, but first opening and editing still had spikes.

The performance log now includes the exact selected asset ID and backend
after successful opening, plus Default handoff and preview-donor context.
These use already-resolved scalar session data; no diagnostic object scans
or preset-name guesses. Unknown metadata is explicit.

`picker.sample.editing` and `picker.sample.idle` summarize completed picker
tick work separately. Editing means a detected input change/action, active SV
capture, or unapplied pending color. Unchanged invalid text is idle; failed
reads before classification are unclassified. These are script-clock work
samples, not wall-time activity durations, FPS, or proof of missed clicks.
Ticks that end their capture are excluded from these rows, like other enclosing
timings; their close/restore stages remain recorded. Existing stage rows remain
inclusive aggregates. All rows add inclusive `ge50ms`, `ge100ms`, `ge250ms`
counters alongside `ge16ms`; nested counters/totals must not be summed.
Metrics stay bounded and batched in five-second summaries, with no per-input
file writes, new native reads, mouse-coordinate recording, or verbose tracing.
The v0.2.106 manual stock-swatch capture showed 89 snapshots averaging 5.6 ms
(26 ms maximum), while idle picker context checks repeatedly cost tens of
milliseconds through full discovery. v0.2.107 targets those measured paths.

User testing confirmed Zabrak Skin Tone 1 opening/editing/Cancel on v0.2.103
and similar responsiveness to Skin Tone 8 with tracing off on v0.2.104. The
latest ST1 captures show 959/799 ms total opening, including 322/267 ms UI
construction and 544/439 ms tint startup (inclusive script-clock timings, not
frame times). This preset's Save/restart still needs separate verification.

v0.2.105 removes redundant pre-attachment white HSV initialization, shares
validated class/factory lookups within the synchronous build, and passes the
freshly resolved controller directly to action-button construction. Native
post-attachment label updates and fresh widget lookups remain unchanged; no
widgets are cached across callbacks or reopenings. Aggregate timings now split
resource lookup, construction, heading/buttons, attachment and label updates.
Local v0.2.105 testing reported good responsiveness, with ST8/ST1 construction
at 338/184 ms and overall opening at 713/779 ms in the short capture. Automatic performance capture
remains active, verbose tracing stays off, and `colors_picker trace` remains
available for troubleshooting. Tint/update/save behavior is unchanged.

The v0.2.102 trace reached call 31, the hue slider's root-relative
StaticFindObject, without returning. v0.2.103 removes that lookup path and uses
the previous one-argument full-path lookup. Same-frame reuse, full-identity and
validity checks, click capture and Zabrak routing remain.

The v0.2.102 diagnostic build identified the failing lookup without changing
skin behavior. Its paired call markers remain available for manual tracing.

Zabrak skin opening now examines the freshly validated fragment layout. Skins
without a MaterialSwap use the regular race-bundle backend; swap-based skins
retain the strict source-order/target correction and recovery path. Opening
logs the chosen route and layout. No stock swatch is forcibly equipped by this
fix. The tester's three-fragment case is covered by regression tests and the
local preview/Cancel test; Save/restart still needs verification on that preset.

Apply/Cancel and the legacy RGB preset actions now use native CommonUI buttons.
Their completed click events latch scalar actions until the next picker tick;
they no longer depend on observing a held button. Context is still checked
before consuming an action, and closing retires all routes and pending input.
The isolated click probe shares the same native hook without replacing routing.

The hidden rainbow launcher skips duplicate validation/input polling while the
picker owns its pane. A synchronous UI-frame cache shares validated lookups and
attachment checks, uses full-path lookup for owned children, and releases every
native wrapper before returning.
Construction class lookups are shared only during the same opening callback.
No cross-frame widget cache or tint/save validation relaxation was added.

Both logs now distinguish click receipt/consumption, invalid-input refusal,
Apply begin/completion and verified picker removal. These changes pass mocked
regressions; native button layout/input and performance still need in-game
verification. The launcher itself retains its existing press polling while
visible; this change targets the missed Apply/Cancel reports.

The picker no longer reads the developer-only `DevPanel/rgb.txt` when opening.
Regular RGB drafts start from the freshly verified selected color, with exact
source alpha/recovery baselines preserved; native scar HSV values remain raw.
RGB values above the UI range are clipped for the initial draft only. The legacy
Default backend starts from its verified temporary donor. Explicit developer
RGB commands still use their input file. This fixes the missing-file refusal
in clean tester installs, including Zabrak horns, without changing save handling
or the separate Zabrak skin path. Test the new ZIP after a full game restart.

Clicking Custom Color automatically captures opening, editing and cleanup into
`Colors_Probe/colors_plus_performance.log`. Five-second aggregate summaries are
flushed in batches without per-input file writes or normal UE4SS mirroring.
Capture has no timeout and ends on Cancel, Apply, navigation or failure.
Reopens and restarts append new windows; console/DP opens are captured too.
See the packaged [tester instructions](src/Colors+Probe/TESTING.md).

Custom Color is hidden on vanilla eye presets and armor-piece/style selectors,
even when the selected asset contains material-color fragments. Actual tint
palettes, including Default, added iris/sclera controls, Vitiligo Tint and Scar
Look, retain their launcher. Retest eyes and Clone helmet/top/arm/leg/boot style
lists, then open their actual color palettes to verify the button is available
only there. This is a UI eligibility change, not a tint or save-path change.

All supported picker slots now reuse scalar lookup routes between updates and
use elapsed-time, latest-only scheduling: immediate first change, then a 75ms
post-update cooldown. This includes armor, markings, horns, hair, cosmetics and
native scar HSV adjustments as well as skin. Every update freshly validates
source/preview, selection, ownership, colors, companions and meshes; context
events invalidate reuse even during writes. Cancel/Restore, reopening and failed
consumers retire the route. Opening, idle/display checks and recovery retain
full discovery. Native HSV values remain unconverted, and Zabrak's existing
source-backed path is unchanged. This does not expand slot compatibility or
change save behavior. See the all-slot retest.

The picker title uses the game's `WBP_Customization_SlotSubItemName` heading
widget, including its branch marker, font and spacing. The hex input and color
preview share a centered 400-unit row, matching the SV area and hue strip.
Create the native heading through `WidgetBlueprintLibrary.Create` so its
Blueprint WidgetTree is initialized; set the owned caption before attachment
and its text after native Construct. Existing palette headings are untouched.

The picker uses **Cancel** to return to swatches; the duplicate Back button is
removed. The hue strip, SV area and combined hex/preview row share the same centered width, and the action
row has extra padding below hex input. There is no footer message or two-minute
draft expiry. Drafts remain open until Cancel, Apply, navigation or a failed
context/ownership check. Invalid input shows guidance above the action row only
while needed.

While the picker is open, its native swatch grid, lower palette labels, slider
branches and our Custom Color launcher use Unreal's `Hidden` visibility. They
stop drawing and receiving input but retain their layout space. The picker's
background stays transparent, and the upper slot header and preview remain
visible. Cancel, Apply or closing restores each control's exact original
visibility without changing native slider values. Injected Character Suite
widgets are included through their verified panel parents, even when their
object paths are outside the native WidgetTree.

A transparent input shield covers the picker host. A process-local scalar
recovery record handles interrupted visibility changes and same-process Lua
cleanup, without replaying native object names after a game restart. All 42
regression programs pass, including indefinite live drafts and the remaining
Cancel/context/recovery paths. Check the layout and leave a draft open for
more than two minutes in the picker retest.

**Vitiligo Tint** and **Scar Look** now get the normal **Custom Color** button,
including from None; the Dev Panel action also works. The 10-01 scar palettes
edit `MM Scar Tint` while preserving the separate `COS Swatch` and
`MM Scar Tint Strength`. Fresh Pink and Pale Silvery have native RGB multipliers
above 1: clone, Cancel, Restore and recovery retain those values exactly, while
picker inputs keep their normal RGB range. Earlier two-fragment RGB scars and
native HSV Looks remain supported. Choose a visible pattern before testing.
All 41 regression programs pass; native rendering needs the
vitiligo/scar retest.

The 10-01 Character Suite eye shader exposes RGB iris colors through the normal
Custom Color picker: **Iris Colour** for matching eyes, **Left Iris Colour**,
**Right Iris Colour** and **Inner Iris Colour**. Left/right affect their own outer
iris; shared outer and inner affect both eyes. Preserve the selected preset's
`MM Iris Recolour` or `MM Iris Inner Amount` while editing RGB. None uses the
existing reversible stock-swatch fallback, with the launcher available while
empty. This support requires Character Suite's rebuilt eye shader and captured
color/amount pairs; native material-swap eye presets keep their existing behavior.
All 41 regression programs pass; native eye rendering needs the
iris retest.

v0.2.87 optimized armor and Zabrak preview updates.

Armor now uses one full context discovery per RGB update, with freshly validated
exact lookups after writes/refreshes, and the same elapsed-time, latest-only
preview scheduling as skin. Zabrak retains a scalar lookup route for the current
draft, freshly validates its native objects and relationships on every use, and
discards the route on every context event, including events during source writes.
No UObject is cached. Save, recovery journals, source/mesh guards and native
refresh ordering are unchanged. Other appearance controls retain their cadence.
All 41 regression programs pass; native performance still needs the
armor/Zabrak retest.

Stage profiling identified repeated discovery/validation as the dominant skin
update cost, not refresh or recovery-file writes. v0.2.86 verifies the known
preview container through fresh exact lookup and live-link checks, with unique
discovery as a missing-lookup fallback. Initial discovery/activation/restoration
retain their full scans. Human face-tint enabling uses a freshly checked route
within the same synchronous update; the reader expires on return or error and
native context events force full rediscovery. No UObject is cached across ticks,
and journals, source/mesh checks and save behavior remain unchanged. Native
captures improved Human/Ovissian/Twi'lek averages, but armor and Zabrak retained
expensive global discovery; v0.2.87 targets those remaining paths.

For the 09-30 Character Suite layouts, **Custom Color** or F6 → Colors+ Picker →
**Open live color picker** works on **Vitiligo Tint** and **Scar Look**.
HSV scar Looks (Raw Red, Fresh Pink, Pale Silvery, Aged Brown and Dark) open
native hue, saturation and value adjustment sliders with numeric inputs. The
selected Look stays equipped, and opening starts at its exact current values.
Cancel/Restore recover the original adjustments. RGB scar tints retain the
color wheel and unchanged `MM Scar Tint Strength`; None uses the existing
reversible RGB stock-swatch fallback. Select a visible vitiligo/scar pattern
first to judge the result. See the Dev Panel controls.
The regression suite covers HSV preview, Apply, Cancel, timeout and recovery;
native HSV rendering remains pending verification.

The Character Suite captures exposed four Colors+ validation gaps. v0.2.83
handles sclera and lashes through the ordinary material-color path, accepts
lashes' native material selectors, and preserves the game's exact 0.99 alpha
when editing Natural freckles. Blush edits only `Cheek / Blush Color` and retains
the selected preset's `MM Blush Blend Mode` through preview, Apply and Restore,
even when the preview donor uses another mode. Native None palette entries use
the existing reversible stock-swatch fallback. Scars' HSV behavior is a game
convention; v0.2.85 edits those native adjustments directly.
All 40 regression programs pass; in-game rendering is pending verification.
See the Character Suite retest.

The v0.2.81 native test confirmed smoother Zabrak dragging, but Human remained
choppy. Apply, radial round trip, Cancel and Restore passed for both. v0.2.82
optimizes the shared SkinTone backend across supported race layouts: each core
RGB update discovers context once, then reacquires the exact page/auxiliary VM
route for its two post-mutation checks. Source, fragment, target, mesh and creator
checks remain fresh. Native context notifications force full rediscovery. No
native wrappers or bindings are cached across updates. Non-skin zones and the
separate source-backed Zabrak path are unchanged. The face tint-enabling helper
still performs its own discovery. All 40 regression programs pass; native speedup
is not yet verified. See the skin performance retest.

The user verified improved opening/closing, radial retention and Restore in
v0.2.80. v0.2.81 opts SkinTone sessions (including Zabrak) into an immediate
first-change preview followed by a 75ms post-update cooldown using owned
game-thread timers. It reads the latest color after cooldown, with no queued
history, instead of waiting for 13 UI polls. Successful, fully validated backend
updates rearm a 495ms idle health check; failed/unconfirmed updates never suppress
validation. Write-time checks, journals, source watchers and Apply flush remain
intact. v0.2.93 removes the two-minute draft deadline. Other slots keep their
existing cadence.
All 40 regression programs pass; Human backend cost remains a tuning target.
This is not a 10 FPS guarantee: update work and game-thread delays add to cooldown.
See skin preview retest.

The user verified much more responsive SV clicks and opening/closing in v0.2.79,
plus Apply/radial/Restore. Character updates still happen in chunks. Native logs
showed `ResetPreviewedPart` cancelling a Zabrak draft just after opening over a
stock swatch. v0.2.80 keeps that draft only when source ownership, selected slot,
owner, page and creator remain valid. Other event types retain cancellation;
stale callbacks cannot operate on replacement drafts. The handler no longer
checks source membership twice in the same callback. Native retest is pending.
Preview throttling, write-time validation, persistence and recovery are unchanged;
this patch does not claim smooth character updates yet.

The v0.2.78 native capture and user feedback confirmed consistent dragging but
unreliable short clicks. The largest input stalls were in SV scanning, not cursor
sampling; repeated context resolution also cost substantially more than grid
construction. v0.2.79 reacquires one SV grid and follows validated native children
instead of globally looking up every row/cell. Repeated selected-slot resolution
checks exact equipped-item membership instead of traversing every palette item;
donor selection retains the full palette validation. Launcher reconciliation
reuses a binding only after fresh creator, ancestry, palette and VM checks.

These changes target stalls and some opening costs; native improvement is not
yet measured. Short presses entirely between polls can still be missed. Separate
`colors_click start|stop` observes existing CommonUI/game button handlers while
stock swatches are shown, to test a future event-latching route without changing
input, widgets or tint state. See the current
performance and click-event test steps.

The user verified the v0.2.77 drag probe: desktop coordinates move while viewport
coordinates freeze under capture; dragging, rapid clicks and focus return worked.
v0.2.78 brings that delta path into the actual picker at 16ms sampling. The native
24x16 grid still seeds the first click (quantized); captured dragging is continuous
and only polls that cell. Its owned SV area is now centered at 400x240 UI units,
avoiding the previously failed host geometry API. Backend preview remains ~5Hz.
The user subsequently verified dragging; integrated short clicks remained unreliable.

Use `colors_perf start` before opening Custom Color, then `colors_perf stop`
after testing. Bounded five-second summaries separate construction, input, UI,
tint/backend and scheduled work; captures expire after 120 seconds. The clock is
platform-dependent `os.clock`, not a GPU/frame-time measurement. See
integrated SV and performance tests.

v0.2.76 opened and rapid clicking worked, but held movement usually froze.
The native log counted 65 fallback presses and zero event presses; the quick
click event hook is therefore not verified. v0.2.77 anchors desktop cursor
movement to the viewport position at each press, divided by the UI scale.
Visible desktop/viewport movement counters and capture status distinguish a
frozen coordinate source from input-state trouble. Mouse-coordinate loss or a
scale change ends only the drag and requires release before another press.
That build was UI-only; v0.2.78 integrates the successful movement path.

The first v0.2.75 native attempt stopped at `Ambiguous mouse X` before input.
v0.2.76 uses one shared scalar-output table and reads `LocationX`/`LocationY`
explicitly, matching UE4SS's property-named output handling. It no longer
assumes each output table contains exactly one number. Native event delivery
remains unverified; the character-color backend is unchanged.

`colors_sv start` opens a fixed-layout, UI-only SV test on an active color
selector. It uses one native capture button, a scoped press-event hook and
16 ms desktop-delta drag sampling, with visible event/fallback/release counters. It does not
change character colors or replace the existing picker. `colors_sv stop`,
Close, leaving the color page or 90 seconds ends it. Native event delivery
remains unverified; see
SV input probe testing.

The user verified v0.2.73 SV rendering/hue changes, smooth hue strip, readable
hex text and Back/Cancel restoration. Opening improved but still hitches.
v0.2.74 replaces the launcher's six rainbow blocks with the same smooth hue
texture used by the picker; their loader shares scalar texture identities.
The Zabrak source path's separate per-call logging now also requires an active
`colors_picker trace` window. Milestones, errors, call bounds, journaling and
source writes are unchanged. Native launcher appearance and further lag
improvement still need testing.

Next native test: rainbow launcher and pane switching.
The color-wheel redesign appends a rainbow **Custom Color** launcher
to the active native color selector. Its own fill-sized, bottom-aligned footer
uses available selector space without modifying stock list sizing. It opens
a transparent pane in the verified lower selector Overlay, leaving the
slot/zone header outside that selector untouched. A saturation/value area with
24-by-16 click seeding and continuous dragging, hue slider and editable `#RRGGBB` field replace
the temporary RGB controls. Exact hex input supports arbitrary RGB; incomplete
or invalid input holds the last valid draft and blocks the UI Apply action.
Cancel cancels the draft; Apply Color retains the edit and reveals the native
swatches again. v0.2.93 removes the duplicate Back button and draft expiry.

The SV and hue visuals now use three tiny packaged PNG gradients, imported
through KismetRenderingLibrary and drawn by hit-test-invisible UImages. The SV
hue base changes with one tint update; transparent native buttons remain on top
for click seeding, followed by continuous desktop-delta dragging. Saved palettes
and controller UI are not implemented. No cached geometry is sampled.
v0.2.68 native logs confirmed launcher attachment and clicks on Skin Tone/Horns,
but coordinate conversion failed with `Unreadable geometry: host point` before
preview started. v0.2.69 removes those geometry calls and corrects the hidden
rainbow decoration. User screenshots and tests verified v0.2.69 opening and
Back/Cancel restoration, but short horn lists exposed the Canvas background's
missing desired height. v0.2.70 adds an owned 560-unit SizeBox and footer fill.
v0.2.70 native opening crashed during the first HSV button's `SetStyle`, before
preview writes. Both new crash reports have the same stack hash. v0.2.71
removes that whole `FButtonStyle` argument: stock buttons supply hit testing,
and owned hit-test-invisible child Borders draw the cell colors with the already
used `SetBrushColor` API. Regression mocks forbid `SetStyle`, but do not reproduce
the native marshalling crash. The v0.2.71 native attempt built all SV cells
without crashing but refused the first hue-strip `SetBrushColor`: the UI helper
expanded both `rgb_input.parse` return values into that single-argument call.
v0.2.72 returns only the color and adds strict native-arity mocks, which reproduce
the old failure and pass with the correction. The user verified v0.2.72 input,
timeout and Back/Cancel, but its SV drawing was invisible, hue was visibly tiled,
hex text had poor contrast and opening hitched. v0.2.73 separates drawing from
the transparent buttons, removes per-cell painting, uses dark hex text on the
native light field and makes heavy UI per-call logging opt-in. The user has now
verified texture import/rendering and improved (but still noticeable) opening lag.
Unsupported or unsettled trees refuse attachment rather than
borrowing another screen's container. The existing console/DP open routes use
the same lower-pane path. No native list rebuilding, swatch replacement,
visibility/focus writes, new save calls or changes to the Dev Panel app.

Previous build: Zabrak CP lifecycle and persistence.
The user verified v0.2.66 renders orange on hands, face and horn-base skin;
manual Stop and 60-second timeout restore, radial navigation retains orange,
and native swatch hover returns to orange when the mouse leaves.
v0.2.67 routes Zabrak skin CP through an independent source transaction using
the same verified array-setter handoff, rather than the transient face-MID path.
It supports arbitrary RGB, a fixed 120-second draft deadline, Apply, reopening,
Cancel back to the prior Apply, and Restore/creator exit back to the visit's
original RGB/order/enable targets. Applied source edits require no repaint loop.
Saved corrected layouts are accepted as a later visit's baseline, but native
Save/full-restart persistence for Zabrak passed the user's tests, including
editing a saved custom color and Cancel restoring its saved baseline. Source drafts change
editor source data; do not Save while a draft is open.
Per-zone journals are process-gated and hold interrupted handoffs. Reload is
explicitly refused until Zabrak CP is closed and applied edits are Restored.
Other slots, the timed console probe and installed Dev Panel app are unchanged.

Previous probe evidence:
The user verified v0.2.61 changes hands and face, but not horn-base skin. Apply
was verified and radial navigation restored/reapplied the face RGB, producing
a visible flash. A later display reacquisition exhausted its retry budget.
v0.2.62 crashed during capture before any completed capture or source-setter
checkpoint; its recovery journal remained empty. Both reports have the same
native null-read stack. The precise reflected call is not yet identified.
The user completed v0.2.63 read-only capture: all 56 traced calls returned,
with no new crash report or recovery-journal write. The swap targets
`Skin Coloration` on `MI_Head` across the same six mesh tags as RGB.
The skipped hard/soft reference reads remain suspect, not proven causal.
v0.2.64's source-array setter returned, but readback had different fragment
identities. The ownership guard stopped before RGB/enable/refresh calls, so no
color change was expected. It did not establish how those fragments were rebuilt.
The user completed v0.2.65: all four returned instances had fresh identities,
correct classes and unchanged owning instance/slot, supported payloads and swap
targets. The requested tags/swap/color/scalar order was honored.
v0.2.66 uses that evidence for a scoped synchronous handoff immediately after
our own array setter, including the stock-order restoration setter. Before/after
checks verify source identity, four roles, layout, RGB, scalar, race tags, swap
targets and requested order. New identities must be durably journaled before
RGB/enable/refresh writes. Later UI/refresh replacements are never adopted.
Plain v3 records track stock/reordered state and in-flight handoffs. Interrupted
or unverified handoffs retain the journal and require restart without saving;
exact owned records can restore in-process. Successful Stop clears recovery only
after stock RGB, targets, order and refresh readback are verified.
The opt-in test returns to orange RGB with expanded enable targets, one native
refresh, manual Stop and a fixed 60-second restoration deadline. No MID,
reference-property, save or periodic reapplication writes are added. Reference-
only changes remain opaque and cannot be verified or repaired. Rendering and
native restoration of a rebuilt array still require the next in-game test.
Fully restart without saving to retire v0.2.65's held inspection before testing.
The normal picker's v0.2.61 workaround remains unchanged.

Previous rendering test: Zabrak face RGB handoff.
v0.2.60 opened CP and enabled the uniquely visible face MID, but the native
trace showed Violet RGB on the bare arm while face and horn-base skin retained
stock RGB. Face Enable Tinting reached 1; Cancel restored it to 0. The bundle's
material swap may explain the dispatch difference, but is not proven causal.
v0.2.61 writes the chosen RGB directly to that verified face MID after refresh,
alongside the transient enable switch. Both values have separate original
baselines and restore ownership checks; a replaced material receives no writes.
Normal CP preview, editor Apply/navigation, stock hover and Restore use this
temporary rendering handoff. Horn-base skin is not directly written. Source
scalar targets, companions, stock assets and recovery formats are unchanged.
This is a rendering test, not a persistence fix; do not save it yet.
Togruta markings and Ovissian skin passed the user's v0.2.58 tests.

The user confirmed most v0.2.57 race skin/horn targets render and Restore.
v0.2.58 adds Togruta's face/lekku `Tattoo Color` + enable-scalar pairs and
preserves Ovissian Skin Tone 1's extra `IrisUVRadius` companion unchanged.
Both Ovissian swatches are tested as sources and donors with different fragment
counts. These additions passed automated and native lifecycle checks. Zabrak
source rendering remains unresolved pending source-dispatch validation; lekku-style mesh
changes still trigger the existing reset guard.

The user verified v0.2.56 multi-slot edits and native Save/restart persistence.
Its nonhuman skin/horn failures exposed different fragment layouts, not missing
RGB support. v0.2.57 uses the captured layouts, changes all selected
`Skin Coloration` fragments together, and preserves material swaps/scar/hue
companions. Twi'lek Restore retains the different original head/body/lekku RGBs.
Removed/replaced race slots retire without recoloring their replacements.
These targets have automated lifecycle/recovery coverage; the user verified
most render in-game. Broader race save/restart persistence still requires
validation. Eyes remain excluded.

The isolated Skin Tone 5 source-target test passed rendering, restoration,
Save/reopen and full-restart persistence. v0.2.55 normal-picker integration passed
the user's five checks. v0.2.56 adds independent multi-slot edits, broader
data-driven color/skin eligibility, and generic multi-mesh targets. It retains
exact ownership, race/bundle and lifecycle checks; eyes remain excluded.
The new race-specific skin/horn compatibility behavior needs in-game validation.
The installed Dev Panel application is untouched.
Earlier Skin Tone 5 diagnostics showed RGB reaching the linked display copy
without a visible change, which led to the enable/target probes above.
The material trace reads `Skin Coloration` and `Enable Tinting`
on assigned MI_Head/MI_Body/MI_Neck materials and their bounded parent overrides.
Use `colors_materials start/sample/stop` without DP; zero/default getter values
alone do not prove a parameter exists. See the comparison test.

DP dispatch failure is not yet reproduced locally. `colors_panel status` reports
poll/delivery counters without consuming clicks. Client/bridge stage logs expose
where delivery stops; failed state reads/parses are reported and not marked read.
Timestamp errors no longer abort logging callers. The installed DP app is unchanged.

Human skin source discovery accepts either observed `Enable Tinting=1` layout:
the five mesh tags or the exact `Outfit` parent tag. The equipped layout is recorded
and preserved through cloning, preview, Apply and Restore. Color targets still
require all five meshes and the same three material names. Unexpected layout
changes are refused; clothing-change guards are unchanged.
Parent-layout recovery uses proxy-v10/editor-v5; existing five-mesh records remain
proxy-v9/editor-v4. See the Skin Tone 5 test.

Human Skin Tone now accepts the observed three-fragment bundle, preserving the
race tag and `Enable Tinting=1` while changing only its color. Source, preview
and display verify all five mesh targets; unsupported layouts remain refused.
Skin Tone 16 reopening, timeout and Cancel passed live; Apply was also recorded.
Switching gloves to bare arms triggered the expected mesh-change restoration;
that behavior is deliberately retained for now. Both scalar layouts pass automated
lifecycle/recovery tests. Skin Tone 5 native verification and skin save/restart
persistence remain pending.

The trace return helper now prefers `table.unpack`, with a Lua 5.1 fallback.
v0.2.39 incorrectly required global `unpack` and refused picker opening in-game;
regression tests now cover both layouts, including nil and multiple returns.
`colors_picker trace` opens one picker with a temporary trace of UI polling/update calls,
deferred job boundaries and snapshot reads, with matched BEGIN/RETURN/ERROR
markers. It stops on close, after 10 seconds or at 6,000 calls, whichever comes
first (the game-thread timer can run late under load). Existing snapshot payloads
still deduplicate. Normal button/DP/console openings keep lightweight stage logs
but no longer start this heavy trace. Logging may cause hitches; this is diagnostic,
not a crash fix.
See the focused crash-capture test.

Tattoo and Twi'lek marking colors passed the user's visual tests. A subsequent
UE4SS native crash during an active Twi'lek picker remains unproven at the
Lua-call level. This build uses scalar-only widget state, attachment gates on
all picker read/write entry points, re-entrant session guards and fresh preview/
source verification between native setters and refreshes. Repeated palette
success logs are deduplicated; the first eight RGB updates have bounded stage
markers. This is hardening, **not a confirmed crash fix**. See
the lifetime/guide review and focused retest.

The user confirmed all v0.2.36 hair-root/lipstick regression checks passed.
This build enables the observed Tattoo Color fragment targeting face and horns.
Preview, Apply and recovery record both mesh assets, including explicit absence
of optional horns. Changed targets refuse; other multi-mesh layouts and mixed
fragment writes remain disabled. Existing single-mesh colors are unchanged.
Tattoo rendering passed v0.2.37 live verification from an existing swatch.

Non-human skin and mixed-fragment horn colors remain **read-only** at this
checkpoint. `colors_compat` records companion tags/scalars and reports a human
skin candidate only after bundle, mesh and same-family donor checks. See
the earlier tattoo/skin evidence.

After a panel reinstall, the local Colors+ helper can recreate a missing
`registry.txt` after confirming the panel's `Scripts/main.lua` exists. It appends
without replacing other registrations; read/write errors leave integration
disabled with an explicit reason. The installed panel application is unchanged.
Fully restart to load the updated helper, then open F6 (Refresh if needed).
F6 now groups picker Open/Apply/Cancel/Restore separately from read-only
diagnostics. Compatibility capture and screen-trace Start/Stop are available
there alongside target inspection, material tracing and stock-hover tracing.
Obsolete cyan/handoff/RGB-cycle experiments are no longer menu options.
See current Dev Panel controls and checks.

Character Suite iris color slots use the main picker in v0.2.88. Other eye
material-swap experiments remain available as development
tools; the following describes those experiments, not the current test plan.
`colors_eyes texture` tests desaturation and reduced brightness on **Light Brown**
and **Rodian Star Blue** only. It does not provide arbitrary RGB or replace any
textures: the original iris pattern, masks and shader switches are untouched.
Four 5-second stages test saturation=0, baseline, brightness=25% of baseline,
baseline; a 20-second timeout ends the test. Use `colors_eyes stop` to restore
early. See the current focused test.
`colors_compat` now captures recorded runtime static switch names, values and
override flags, separately bounded from the existing vector/scalar/texture
survey. Missing data is logged as a gap, not false. **Fully restart;
avoid Reload All Mods while the post-reload navigation crash is unresolved.**
The picker now discovers the selected color slot, material parameter, target
mesh and an alternative swatch from its active palette. Preview, Apply and
recovery retain that exact target instead of assuming Clone 8/Primary Accent.
Single opaque color fragments with one mesh target, plus the exact face/horns
Tattoo Color pair and the exact human skin bundle, are eligible for CP.
Other mixed layouts and ambiguous palettes remain diagnostic-only. The temporary
Default fallback remains outfit-only.
Eyes now have a separate **display-only**, reversible `colors_eyes [start|texture|stop]`
experiment, not picker Apply/save support.
Only one applied zone is supported at a time: use `colors_picker restore`
between zones. See the current focused test.
`colors_compat` remains read-only and now inspects nested slots (including their
UI visibility). v0.2.27's outfit Apply/Restore tests and Eye Shadow Apply worked,
but appearance reopening found duplicate global palettes. v0.2.28 follows the
page's active panel and owned lists instead of global visibility/parent chains.
Eyes were confirmed as hidden left/right material-swap slots; the read-only
survey now records replacement materials and parent vector/scalar/texture
overrides. v0.2.28 logs confirm Apply/Restore for hair tips, eye shadow, eyeliner,
lipstick and facial hair. Eyebrows found the palette but refused an outstanding
stock hover. v0.2.29 verifies and settles that selected-slot hover before donor
activation; an idle stale proxy is no longer required to match the source color.
Twenty eye captures all shared M_EyeRefractive. Neimoidian iris overrides vary
between presets; Rodian Star uses MI_Eyes and Albino exposes CloudyIrisColor.
The new 20-second probe edits only verified per-mesh display MIDs, journals
restoration, cancels on native changes and restores after reload. Presets without
explicit tested parameter names still refuse. v0.2.29 logs confirm eyebrow
Apply/Restore/reopen, but eyes refused before writes at an exact-text FName guard.
v0.2.30 accepts case-only differences for whitelisted eye names and logs both
requested/returned strings on failure. Ownership and recovery guards are unchanged.
Live v0.2.30 confirmed the case-only mismatch and visible, reversible colors on
Dark Brass and Albino. Light Brown and Rodian Star Blue accepted IrisColor1/2
changes without visible effect. v0.2.31 captured Color TEX/GEN overridden false
for Light Brown and true for Dark Brass, supporting different color paths.
Rodian Star Blue and Albino had no recorded switches; parent defaults remain
unknown. v0.2.32 tests the explicitly recorded saturation/brightness controls
on the two non-working presets. The user confirmed visible changes and
successful Stop/restore on both Light Brown and Rodian Star Blue.

The standalone picker passed
stock-color/Default opening, editor exit and timeout in v0.2.20. The new
**Apply (session)** action keeps the chosen RGB for this editor visit, supports
reopening/cancelling edits, and restores the original on exit or
`colors_picker restore`. Apply and stock-hover/selection behavior passed in v0.2.21.
v0.2.22 regressed Apply: the creator binding refuses with `No attached creator for
item page`, before writing the source color. v0.2.23 found one matching master,
but it was inactive with no viewport attachment or valid parent. v0.2.24's
`colors_screens` trace proved that the creator remains in `GameLayer_Stack` under
the color page, becomes active on the radial selector, and leaves the stack at
Databank exit. v0.2.25 uses that exact stack membership instead of screen
attachment, keeping the existing character/fragment checks and rollback.
The user confirmed Apply, radial navigation, Cancel and exit restoration from a
clean Saturated Red 1 baseline. A separately saved custom color also survived a
full game restart with no mod reapplication. These results cover the tested
accent, not other slots. **Do not save during the compatibility survey.** See
the session-Apply test.

Colors+ remains a scaffold. A separate development mod, **Colors+Probe**, now
successfully reads customization tint fragments. v0.2.8 traced cyan to the hidden
data actor while the display actor remained linked to the red equipped character;
stock hovering did switch that display link. v0.2.9 attempted native activation
with the equipped swatch but failed its immediate link check before cyan.
v0.2.10 captured a working Blue_14 hover through the slot view model, while
hovering the equipped red swatch did not activate the display preview.
v0.2.11 confirmed visible cyan through that blue-hover entry point, with
automatic restoration and unchanged equipped red. v0.2.12 confirmed visible
orange from configurable 0–255 sRGB values and automatic return to red.
v0.2.13 confirmed orange/violet/green cycling on the same owned fragment and
restoration. v0.2.14 adds a small in-game RGB-slider picker with a hex readout,
presets and Cancel/Restore, launched from the Dev Panel. Sliders, presets and
slot cancellation have been confirmed in-game. v0.2.15 hardens page-exit/re-entry
alongside SWZC Dev Panel v0.2.1; the user reports the changes worked well.
v0.2.16 adds an isolated, preview-only Default/no-override path. Dev Panel v0.2.2
stays open during ordinary menu navigation while invalidating old clicks.
The user confirmed panel persistence, picker cancellation and reopening after a
Databank round trip. Default failed because the auxiliary root VM is invalid on
this screen. v0.2.17 instead verifies Style and selected accent membership in the
character VM's slot tree, then resolves ownership through Style fragments.
That attempt also failed: `CharacterCustomizationVM` is unavailable. At the
user's request, v0.2.18 temporarily selects the first non-Default stock swatch,
uses the working regular RGB preview, then explicitly equips Default again on
close. This changes the editor's working selection, not the saved character
unless the editor is saved. The mod never calls save APIs. Default selection
recovery is journaled separately from RGB recovery. Default opening, hover/page
exit cancellation and two-minute timeout have passed in-game. Reload All Mods
with CP open hung the game. v0.2.19 adds a process-session recovery gate and
startup checkpoints; Dev Panel v0.2.3 adds matching diagnostic checkpoints only.
This does not establish that the native reload hang is fixed. Start with the
closed-window reload procedure in `docs/reload-hang-testing.md`.
There is no saved-swatch library or mod-driven save operation; native character
saving retained the tested custom accent. See
the live-picker test,
the next Dev Panel test and
the read-probe results.

v0.2.20 adds a standalone in-game console entry point: `colors_picker`
(or `colors_picker open`), and `colors_picker close` to cancel the current edit.
v0.2.21 adds `colors_picker apply` and `colors_picker restore` (undo the session's
Apply as well as any open edit). v0.2.25 replaces the failed v0.2.22 attachment
guard with verified stack ownership, to retain Apply through the radial selector
and restore on full creator exit. That flow passed the clean-baseline in-game test.
SWZC Dev Panel does not need to be installed or open. The generalized picker
has no timed draft expiry as of v0.2.93. An applied color also has no timed
expiry; editor exit ends it.
Close the game console after entering the command to use the picker. Both-open
CP/DP reload crashed during live testing; close both windows before Reload All
Mods. The console entry point does not fix that native reload issue.

See the research notes for the current reference findings
and implementation boundaries.

