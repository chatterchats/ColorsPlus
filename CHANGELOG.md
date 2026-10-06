# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Tester release: the in-game character editor — v0.4.0

- Custom colors work in the in-game (hub/barracks) character editor as well
  as the main-menu creator. Confirmed in game: skin and tattoo (Hawks),
  Rodian swap skin (recruit), armor with stock swatches, armor wearing
  swatches the palette no longer offers, and a Default slot. Applied colors
  are kept when the hub editor closes and persisted through leaving the
  barracks and save > main menu > load.
- The install folder is renamed `Colors_Probe` -> `ColorsPlus`; the display
  name is "Colors+ — Custom Color Picker". There is no migration: testers
  delete the old folder (see the tester guide).

### Install folder renamed to `ColorsPlus` — v0.4.0

- The packager's root folder is `ColorsPlus/` (`Colors_Probe/` through
  v0.3.0). `modinfo.json`/`zcom-mod.json` use the display name "Colors+ —
  Custom Color Picker". The tester guide asks updaters to delete the old
  `Colors_Probe` (or `Colors+Probe`) folder: two copies would both hook the
  editor. A planned in-mod migration (disable the old copy through its
  `enabled.txt` and `mods.txt`) was dropped for three testers.
- Unchanged: log file names, the `[Colors+Probe]` log prefix and the
  `ColorsPlusProbe.*` Lua/shared-variable keys.

### Tester release: opening timings and click-driven launcher — v0.3.0

First tester build since the performance work (v0.2.114-v0.2.120): lookup
reuse, quieter logs, on-demand zones, picker opening without object scans,
lookup hints across non-structural events, swatch input paused at launch and
the player-only package.

- Preview setup is now itemised in the performance log. The ~160ms of each
  opening that had no label is split into `open.settle`, `open.proxy`,
  `open.prepare`, `open.activate`, `open.proxy_donor`, `open.verify_display`,
  `open.clone`, `open.write_clone`, `open.install`, `open.verify_install`,
  `open.refresh`, `open.verify_refresh`, `open.verify_settled` and
  `open.journal`, plus inclusive per-layer `begin.zabrak`, `begin.editor`,
  `begin.default_selection` and `begin.regular`.
  Timing only; no behaviour change. The per-interval label budget is 192.
- The Custom Color launcher is the game's CommonUI button (as used by the
  picker's Apply/Cancel) instead of a plain UMG Button polled for `IsPressed`
  every 33ms. Clicks arrive through the existing `HandleButtonClicked` hook;
  the callback only schedules a 1ms launch job, which pauses swatch input and
  queues the usual 100ms-deferred opening. Retiring the launcher unbinds its
  click route. A 500ms validation backstop replaces the input poll (skipped
  while the picker owns the pane). The rainbow gradient sits beside the
  button; the native button's caption is set after attachment.
- Launcher layout (from in-game review; tree measured with a diagnostics
  build). The game caps the swatch SizeBox (`MaxDesiredHeight` 550, or 455
  with Maddie's character-creator overhaul rows) so the palette exactly fills
  its 563x793 background, and the launcher used to add height below it. The
  overhaul re-applies its cap continuously, so the cap is never written.
  Instead the launcher sits in the column's overlay, aligned to the bottom,
  over a 52px band reserved by bottom padding on the swatch grid's own slot:
  total height is unchanged and the grid scrolls within the capped area. The
  band is restored when the picker opens and when the launcher retires (only
  if it still holds our value), re-reserved if another widget resets the
  padding (backing off after three corrections), and skipped when the
  column's overlay is not where expected (the launcher then stays below the
  swatches and never covers them). The launcher spans just the swatch row:
  the column width (465 = 563 panel - 68 - 30 padding) is derived from the
  live chain's desired sizes and slot padding (`palette_layout.lua`), then
  64px tiles with 10px spacing give a 434px row starting 5px in. Slots are
  read through `WidgetLayoutLibrary`. One `LAUNCHER LAYOUT` line records the
  values used.
- The widget library lookup uses a plain validity check: `a.live` rejects
  class default objects by design (caught by the launcher test).

### In-game (hub) character editor — v0.4.0

- The hub's character editor is a separate editor with the same slots. A
  survey there found the same item page and slot view models, but a
  different host (`WBP_CentralUITabs_C` in the game stack, with
  `WBP_Customization_MasterPage_C` as its active tab) and edits applied to
  the selected squad member's live `HUB_Root` actor
  (`Char_Hero_HAWKS_Control_C`, `Char_Hero_Humanoid_C` for a recruit).
- `creator_lifetime` accepts that host: the hub menu counts as the creator
  only while customization is its active tab; another tab, a rebuilt master
  page or a closed menu ends the visit.
- `editor_worlds` holds the creator and hub identity checks (owner, preview,
  container, display) that were main-menu patterns in five modules. One
  edit never mixes objects from both editors.
- `button_class` loads the launcher/picker button class through UE4SS
  `LoadAsset` when it is missing (the hub does not load it).
- Leaving the hub editor keeps an applied color instead of restoring it:
  the first in-game test showed Apply working, then Colors+ restoring the
  original as the editor closed, because the hub has no Save step. A hub
  visit end (aux-VM clear, closed menu, another tab) now verifies the source
  still holds the color, releases ownership and clears the journals. An open
  draft ends first (the Zabrak route returns to the applied color), a later
  stock edit is left alone, explicit Restore still restores, and a failed
  keep falls back to restoring. `AFTER KEEP` lines at +2s/+10s log whether
  the game kept the color. Apply refuses a character from the other editor.
  Confirmed in game: hub skin and tattoo colors persist outside the editor
  and through save > main menu > load; Rodian (swap) skin works.
- Hub armor slots wearing a swatch the palette does not offer refused to
  open (`Equipped item absent from active palette`): Hawks' Main Color
  (`NeutralGrey_10`) and Tertiary Accent (`Blue_16`), with no palette item
  of either asset, likely equipped under a swatch-unlocker mod and kept in
  the save. Picking a stock swatch made them work. The grid is already bound
  to the slot by the exact page/panel/tiles walk and slot tag, the preview
  borrows another swatch, and Cancel/Restore write the source RGB, so an
  unoffered equipped swatch is now logged (`not a palette item`) instead of
  refused. Default selection keeps the strict check (it re-equips the
  Default item from the palette). The survey counts alternatives as other
  swatches.

### Dev Panel integration removed; journals move to `Recovery/`

- Removed the SWZC Dev Panel client, bridge and action catalog
  (`DevPanel/actions.lua`). Developer tools remain console commands:
  `colors_picker`, `colors_compat`, `colors_screens`. The picker console now
  owns its queued action and cancels it on page/creator exit.
- Recovery journals and session metadata live in `Recovery/`, which ships
  with a README so the folder exists after extraction. A `DevPanel/` folder
  from an older version is no longer read; its journals were from a previous
  game process, which are archived rather than replayed anyway. The tester
  guide says it can be deleted.

### Source split: the mod in `src/ColorsPlus`, dev tools in `src/Colors+Probe`

- `src/ColorsPlus` holds the mod (37 scripts, assets, manifests, tester guide,
  `DevPanel/actions.lua`) and is exactly the Testers package. It replaces the
  0.1.0 bootstrap placeholder (`src/Colors+`) and its test.
- `src/Colors+Probe/Scripts` keeps only developer tools (`dev_tools`,
  `call_trace`, `screen_trace`, `color_compatibility`, `picker_console`, the
  Dev Panel client and bridge). The Dev package overlays them into the mod's
  `Scripts/` folder; a separate UE4SS mod would run in its own Lua state and
  could not reach the picker's runtime.
- The packager checks that every mod script is reachable from `main.lua` and
  that none needs a developer script. `tools/run-tests.sh` runs the tests
  against the Dev layout in a temporary folder and accepts test names.
- Manifests now name the mod "ColorsPlus - Custom Color Picker"
  (`community.colors-plus`). The install folder stays `Colors_Probe/` until
  the v0.4 rename.

### Retired dev probes; faster, tidier tests

- Removed diagnostic probes from finished investigations (Dev package only):
  click/SV input experiments, material and stock-hover traces, Zabrak
  capture/dispatch research, eye preview and skin-target save experiments,
  with their tests, console commands, Dev Panel actions and the guards that
  referred to them. About 3,900 lines. The Dev package keeps call/screen
  tracing, the compatibility survey, the picker console and the Dev Panel.
- Tests load each script once and share the module table, as `main.lua` does
  in game (`tests/helpers.lua`). They had recompiled scripts on every factory
  call: race_bundle_test made 29,307 loadfile calls. Suite: ~13s -> ~8s, with
  race_bundle_test 10.4s -> 5.8s. Shared journal-name map; stale Clone 8 and
  version-stamped comments updated.

### Docs cleanup

- `docs/` keeps only current material: `architecture.md` (how a color edit
  works; formerly `flatten-plan.md`), `status-history.md`,
  `practical-ue4ss-ui-modding-notes.md`, `implementation-strategy-review.md`
  and `skin-persistence-findings.md`. 40 superseded per-version test
  procedures, experiment logs and the review's evidence index were removed;
  older entries below still name them, and they remain in git history at
  commit 39c0233.

### Flattening, steps 3-5: one zone instead of four wrapper layers — v0.3.0

- New `color_zone.lua` owns each zone and sequences its steps explicitly:
  opening (applied-record check, temporary Default selection, preview, skin
  display), Apply (record, hold Default, end preview, write source, verify,
  watch) and Restore (Zabrak route, preview, applied source, Default).
- `default_selection`, `editor_session` and `zabrak_picker` are components
  (native reads/writes and their own journals) instead of wrappers; no
  metatable fall-through or patched restore remains. A preview ending on its
  own (timeout, context change, failed update) still returns a temporary
  selection to Default, now through an explicit `after_restore` hook.
- The Zabrak source route is the zone's backend choice: it claims Zabrak
  skins with material swaps at opening, and its drafts are dispatched to it.
- No change to journals, formats or recovery order. One journal per zone was
  planned and not done: the Apply journal's atomic replacement would either
  be lost or added to every drag tick (see `docs/architecture.md`).
- Tests run the production zone. Cases that combined layers in ways players
  never run (Default without the Apply layer; a Zabrak swap skin on the
  regular backend) were changed to the production behaviour or removed where
  the real path has its own coverage.

### Flattening, steps 1-2: one code path — v0.3.0

What players run is now the only path in the code and the tests (plan:
`docs/architecture.md`). About 1,000 production and 1,100 test lines removed.

- Removed `default_tint`/`default_owner`, an unreachable Clone 8 "Default"
  backend (`default_selection` always handled Default first).
- Removed the `generic_colors` flag (always on) with the Clone 8 accent
  resolution, the cyan and owner-level handoff modes, `apply_rgb`/`cycle_rgb`
  and the RGB file reader, and the wrapper gates that only blocked them.
- Journal readers accept only the formats this path writes (`proxy-v7`..`v12`,
  `editor-v2`..`v7`, `selection-v2`). Older formats came only from the removed
  path; previous-process journals are archived, never replayed.
- Fixed: a preview install that changed nothing (`SetFragmentInstances`
  no-op) left the palette donor hovered on rollback. Rollback in the
  `installing` phase now resets the donor when the live fragment is the exact
  donor object this session activated.
- Tests: the install/restore safety cases from the legacy section run on the
  donor path (`skin_test`); `tint_test` is generic-only (every supported
  profile, Default integration, editor Apply on the real stack); the
  Default-selection, editor and compatibility tests use realistic
  active-page fixtures.

### Player/dev split and cleanup — v0.2.120

- Separate player and dev builds. `ColorsPlus-Testers` contains only the
  scripts reachable from `main.lua` without `dev_tools.lua` (37 of 56): the
  picker, editing backend, recovery and performance log. `ColorsPlus-Dev`
  adds probes, traces, console commands and the SWZC Dev Panel integration.
  The packager derives the player set from module references and refuses to
  overwrite a released version with different contents.
- The production context-event route (skin-enable stop, backend
  invalidation) moved from the Dev Panel bridge into `context_events.lua`;
  dev tools wrap it via `runtime.dev_context`, isolated with `pcall`.
- Track `DevPanel/actions.lua` (it was git-ignored although every package,
  and the journal folder it keeps present, depends on it).
- Removed the unexposed legacy Dev Panel writes (`apply_cyan`,
  `apply_handoff`, `apply_blue`, `apply_rgb`) and a duplicate copy of the
  bridge tests inside `tint_test`.
- Tests: `tools/run-tests.sh` runs each test against its target folder; the
  two long-standing "failures" were invocation errors (scaffold folder,
  trailing slash) and now pass. `race_bundle_test` uses indexed fakes
  (~52s -> ~9s); the whole suite runs in ~13s. New `context_events_test`.
- README reduced to current status, packages and development; the former
  running status notes moved to `docs/status-history.md`. The tester guide
  no longer promises Dev Panel diagnostics.
- Deliberately not changed yet: the `generic_colors` flag and legacy Clone 8
  path (removed in v0.3.0, after porting its transaction tests).

### Swatches ignore the mouse while the picker launches — v0.2.119

- About 1 in 7 openings (v0.2.107-v0.2.118 logs) closed immediately with
  `preview ended`: moving the mouse over the swatches during launch made the
  game preview a swatch, or hiding a hovered swatch made Slate deliver its
  mouse-leave reset on a later frame. Either arrived after the preview
  session started, read as a context change and force-restored.
- On the launch press the swatch grid becomes HitTestInvisible (still drawn),
  so those events land during the 100ms launch delay, before any session.
  `hide_palette` restores the stock value first in the same synchronous call,
  so the hidden-palette record and restore keep the original. A refused,
  failed or abandoned launch, and launcher retirement, restore it too.

### Lookup hints survive non-structural events — v0.2.118

- v0.2.117 openings (developer machine, 5 opens) still spent ~180ms of ~431ms
  in full page/auxiliary-VM `FindAllOf` discoveries (~37ms each, 4-5 per
  opening): every native notification discarded the scalar route hints,
  including the picker's own donor activation and the game's follow-up
  `UpdateCurrentCustomizationSlotVM`.
- Separate the two meanings of an event. `context_revision` (tint) and
  `lookup_revision` (selection) still advance on every event and still make
  any lookup in flight refuse its result and block draft-route promotion.
  Stored hints are retired only by structural events: `page closed`,
  `creator closed`, `UpdateRootCustomizationSlotVM`, or an unknown reason
  (`color_rules.structural_context`). Routes carry `epoch`; a missing or old
  epoch falls back to full discovery.
- Hints remain lookup shortcuts only: every use revalidates the active page
  and creator stack, auxiliary VM identity, current slot VM (and identity/tag
  for selection), source, owner, target and colors; any failure rediscovers.
- Tests: non-structural events keep routes; structural events rediscover;
  reentrant structural and non-structural events both refuse in-flight
  lookups.

### Opening without first-lookup scans — v0.2.117

- Source of the installed UE4SS (`a1e7f571`, UEPseudo `885ba757`): string
  `StaticFindObject` answers repeat lookups from UE4SS's own name cache, but
  each first lookup of a never-found object scans the whole object array.
  v0.2.116 opening captures showed 38-67 of our lookups per opening; picker
  widgets are new every opening and were each looked up by name after the
  construction frame (and again after preview-setup hook invalidation).
- `object_cache.remember` records wrappers the mod already holds. Constructed
  picker widgets (and the player controller) are recorded at construction;
  mod-owned widgets are pinned for the picker session: they survive hook
  invalidation but not release, a failed IsValid/exact-name recheck or the
  1s verification window. Launcher widgets, the active page, palette grid,
  ancestry and hidden siblings are recorded unpinned at discovery/install.
- The launcher holds the cache from the start of `install` (released by
  `retire`, which every failed install runs).
- Startup builds an extra zone only for a non-empty zone journal or any
  `.previous` file; readers treat empty journals as nothing to recover, so
  leftover empty files no longer force zones 2-N at every launch.
- Not yet changed: preview setup's own hook events still discard the scalar
  route hints, so each opening repeats 3-5 `FindAllOf` discoveries (~35-40ms
  each on the developer machine).

### Background, logging and startup cost cuts — v0.2.116

- Hold the object lookup cache while an Apply is owned. The post-Apply
  `editor:watch` (every 250ms per edited zone, for the whole creator visit)
  measured ~60ms per run on a tester machine outside the picker's cache scope.
- Log only the first live update, first RGB checkpoint trace and first Zabrak
  verification per session. Every probe log line is flushed and mirrored to
  the UE4SS console; drags previously wrote one or more lines per update.
- Create editor zones on demand instead of 32 complete backend stacks at
  startup. Zones with journals on disk (and lower zones, keeping the list
  contiguous) are still built before recovery starts.
- Memoize this mod's own Scripts in `main.lua`; each module runs once per
  bootstrap. Stubbed bootstrap: 2,432 -> 69 disk loads, ~326ms -> ~10ms CPU.
  Reload keeps the original `loadfile` and recompiles edited files.

### Self-describing performance captures — v0.2.115

- Each performance capture now logs one `ENV` line after `START`: UE4SS
  version (`UE4SS.GetVersion`), Unreal version (`UnrealVersion`), Lua version
  and whether Proton/Wine was detected. Host API scalars only; no UObject reads.
  Testers no longer need to send `UE4SS.log` for version comparisons.
- Time every real `StaticFindObject` issued through `object_cache` (misses and
  unheld calls) as `lookup.static_find`, giving each machine's raw lookup cost.
  v0.2.114 testing on the developer machine: ~99% cache hits; drag ticks
  29.2ms -> 6.5ms avg vs v0.2.112, but lookups there were already ~0.5ms
  versus ~18-22ms on the tester machine, which still needs a v0.2.114+ capture.

### Session-scoped object lookup reuse — v0.2.114

- v0.2.113 tester captures showed each full-path `StaticFindObject` costs
  ~11-20ms in this game, while every other validation step costs <1ms. An
  idle 16ms picker poll did ~12 lookups (`ui.read` avg 202ms, `job.picker:tick`
  avg 230ms, so ~4 fps with the picker open), and each preview update ran three
  context validations of ~61ms (`tint.preview_update` avg 217ms). The 33ms
  launcher poll repeated ~4 lookups whenever a color palette was shown.
- Add `object_cache`: reuse lookup results only while the color UI launcher or
  picker holds the cache. Every native hook callback, any release, and any
  failed recheck drops all entries. Each hit is rechecked with `IsValid` and
  its exact full name; entries not verified within 1s are looked up again
  without being touched. All caller ownership/identity checks are unchanged.
- Route picker/launcher/palette-visibility widget reacquisition, creator stack,
  auxiliary VM, display container, skin actor, editor/default VMs and Zabrak VM
  lookups through the cache. Recovery-time and manual-probe lookups stay direct.
- Report per-interval `object_cache` hits/misses in performance summaries
  (`update-stages-v3`). Expected: idle ticks and preview updates no longer
  dominated by lookups; remaining update cost is native `RefreshCustomization`.

### Context lookup reuse and preview cadence — v0.2.113

- Replace repeated selected-slot/global tint discovery with scalar lookup hints
  scoped to a validated live creator page. Reacquire native objects each call;
  preserve all source, palette, owner and material checks. Failed hints fall
  back to full discovery; callbacks during lookup refuse rather than promote
  stale state. Invalidate inactive zone hints on context events as well.
- Reuse opening discovery for the first update and measure implicit route
  reads as `tint.resolve_lookup`. No native wrappers or validation cache.
- Lower the post-update latest-only preview cooldown from 100ms to 75ms.
  Keep immediate first updates, coalescing, Apply flush, stale-job cancellation
  and the separate 495ms idle-health gate.
- Record user-confirmed Zabrak 4/5/10 round-trip, Cancel/Restore and persistence
  results for v0.2.112. New performance changes await in-game comparison.

### Separate Zabrak donor targets and Tone 10 swap support — v0.2.112

- Replace Tone 5's native no-op self-preview with the active palette's exact
  `0B0` donor. Track its head/body stock target separately from the selected
  head-only source. Keep strict source-target checks after clone installation.
- Persist the separate donor target in validated `proxy-v12` recovery records.
  Stock cleanup checks donor RGB/target; owned clone restoration uses source
  RGB/target. Retain older recovery readers and test malformed new records,
  pre-install failure/cleanup, reload, Apply/Cancel and Restore.
- Accept the captured `MI_Head0` swap target only for Tone 10 (`1B0`), without
  changing that string or reading material pointers. Test cloned/in-place
  setters, Cancel/Restore, saved-layout edits and recovery with this target.
- Tone 4's donor fix is user-confirmed, including radial navigation. Tone 5
  and Tone 10 native confirmation remains pending.

### Zabrak preview routing and swap diagnostics — v0.2.111

- Route captured Tone 4 (`0B0`) to compatible `0B2` rather than head-only
  `0B1`. Require that donor to belong to the verified active palette.
- Test a same-swatch preview for Tone 5 (`0B1`), whose head-only target has no
  matching alternative in the captured palette. Restrict same-swatch recovery
  to its validated three-fragment layout. Native activation and all subsequent
  ownership/target checks remain required; native confirmation is pending.
- Log swap parameter, mesh tags and material-slot strings before rejection,
  without reading replacement-material pointers or relaxing accepted targets.
  Tone 10 remains a diagnostic test, not a claimed fix.
- Test donor routing, Apply/Cancel/recovery, missing donors, native self-preview
  refusal and read-only diagnostics on an unsupported swap target.

### Swap-first Zabrak source support — v0.2.110

- Accept the captured `Hum_Zabrak_1B0` swap/tags/color/scalar source order in
  opening and recovery validation. Preserve its exact baseline order and
  already-expanded or outfit-only scalar target for Cancel/Restore.
- Keep the existing verified tags/swap/color/scalar working order, journaled
  setter handoff, fresh replacement validation and holds after interruption.
  Unknown permutations, duplicate roles and malformed journals still fail
  closed. No swatch substitution or material-pointer access.
- Log the actual restored role order. Cover cloned/in-place setters, preview,
  Apply/radial/reopen/Cancel, Restore, same-process recovery, invalid orders and
  interrupted restore handoffs. Native first-open/color confirmation pending.

### Opening lookup reduction — v0.2.109

- Seed UI controls inside the construction frame using the already-read scalar
  starting color. Reuse only owned widgets with current validity/identity checks;
  release all wrappers before native preview setup and before delayed callbacks.
- Compare against the independently verified preview color and reinitialize
  through fresh lookups if it changed. Preserve a fresh attachment validation
  even when the seed matches. Preserve RGB clipping and signed scar HSV values.
- Reuse a scalar page/aux/creator route for repeated opening source checks;
  native context events invalidate it and force full discovery. Keep source,
  target, mesh, clone/install/refresh validation and recovery writes unchanged.
- Add aggregate opening context/donor/source-check, seed and readiness timings.
  Test same-call lookup reduction, changed/dead widgets, changed color/mode,
  detached-pane rollback, fresh reopening and native-event invalidation.
  No hidden prebuilt UI or change to stock-swatch hover cancellation. Native
  opening latency improvement remains to be measured.

### Validation reads and aggregate substages — v0.2.108

- Add nine aggregate validation labels for source fragment/profile/target/mesh
  reads, companion matching, preview fragment/color/mesh checks and display
  links. Raise the fixed per-interval label budget to 128; retain five-second
  batched output and existing parent-stage error/timing behavior.
- Compare bundle colors from the fresh read's scalar snapshot instead of
  calling GetColor again; combine preview bundle traversal and matching.
  Read each companion's class once. No native/result cache across callbacks,
  setters or refreshes; source VM and owning-slot reads remain independent.
- Preserve the three validation checkpoints, native refresh and recovery
  journal writes. Test per-read call counts, fresh subsequent reads, changed
  companion rejection, distinct original colors and substage coverage.
  Native performance improvement remains to be measured.

### Stock-swatch and idle-check overhead — v0.2.107

- Remove automatic detailed snapshots from stock selection, equip, preview and
  page activation. Preserve context/lifecycle notifications and bounded hook
  installation retries; explicit console and Dev Panel captures remain.
- Reuse the validated live-draft scalar route for idle and delayed display
  checks. Freshly read all native objects, targets, colors and relationships;
  discover once for an untouched draft and invalidate on native events, failed
  health checks or retirement. Avoid the display check's duplicate discovery.
- Retain health-check cadence, recovery, save behavior and automatic performance
  summaries. Test quiet stock events, explicit diagnostics, cold/warm idle
  routes, event invalidation, reentrant events and changed native ownership.
  Native speed/lifecycle confirmation remains pending.

### Tester diagnostics — v0.2.106

- Add successful-opening target metadata to the standalone performance log:
  exact selected asset, regular/source-swap/default-preview backend, Default
  handoff marker and preview donor, from existing scalar session data only.
- Split completed picker-tick work into editing/idle/unclassified summaries,
  using existing input changes, SV capture state and pending updates. Do not
  confuse these script-clock samples with wall-time activity or FPS.
- Add inclusive 50/100/250 ms counters to every stage, retaining existing
  timing fields, bounded labels and batched output. No new object scans,
  per-input file writes, verbose trace, or tint/save/scheduling changes.
- Cover threshold boundaries, nil/error propagation, metadata sanitation,
  Default/source-swap metadata, activity hints and stale-window isolation.

### Opening construction polish — v0.2.105

- Following successful ST1/ST8 testing with automatic tracing off, trim the
  redundant white HSV initialization before the selected color is initialized.
  Reuse validated factory/class resources only within the synchronous build
  and use its freshly resolved controller for action-button creation.
- Retain post-attachment widget reacquisition, native caption refresh, all
  lifecycle/ownership checks and full-path-only lookup. No cross-callback
  widget cache, tint/save change or verbose automatic tracing.
- Add aggregate construction/resource, heading/button, attachment and label
  timings. Test one selected-color initialization, resource lookup reuse and
  release after failure/reopen. Native opening-speed improvement needs testing.

### Verbose opening tracing off — v0.2.104

- Following successful native Skin Tone 1 opening, color editing and Cancel
  on v0.2.103, disable automatic per-call initialization tracing. Keep manual
  tracing, automatic performance logging, full-path lookups and skin behavior.
- Cover trace-disabled opening with performance capture still active, plus
  explicit tracing with the automatic flag off. Opening performance without
  verbose tracing and this preset's Save/restart remain to be verified.

### Full-path picker lookup — v0.2.103

- Remove the root-relative StaticFindObject branch after the v0.2.102 native
  crash trace stopped at its hue-slider call (31). Use the previous full-path
  overload only; retain same-frame reuse, attachment/identity/validity checks,
  native action buttons, Zabrak routing and bounded opening diagnostics.
- Regression tests reject every attempted multi-argument lookup, including
  attempts hidden by a Lua fallback, and retain cache-boundary/cleanup checks.
  Native confirmation is pending; no new skin or save behavior changes.

### Opening-crash diagnostics — v0.2.102

- Preserve v0.2.101 routing and root-relative lookups; no speculative workaround.
  Automatically trace the post-build opening region with paired BEGIN/RETURN
  (or Lua ERROR) call IDs using the flushed probe logger. Bound capture by the
  existing 6,000 calls/10 seconds and stop it on opening success/failure; do not
  replace or terminate a separately requested trace.
- Add stage markers for preview startup, color conversion, mode validation,
  UI initialization and polling setup. Distinguish scoped/full/cached widget
  lookup, attachment checks, HSV conversion and marker native setters.
- Test successful opening, failed initialization/rollback, no continuous-input
  tracing and explicit-trace ownership. This is a diagnostic build, not a fix
  for the v0.2.101 Skin Tone 1 native crash.

### Zabrak skin routing — v0.2.101

- Inspect the verified live bundle before selecting the Zabrak source backend.
  No-swap skins (including the tester's three-fragment Hum_Zabrak_0A0 shape)
  delegate to the regular race-bundle path instead of failing its four-fragment
  assertion. Keep all existing source-swap order/target/recovery checks; never
  fall back after a failed transaction. No forced preset selection was added.
- Log backend, part, fragment/swap counts and validated layout once per opening.
  Cover no-swap routing, unsupported swap ordering and missing layout evidence;
  exercise three-fragment preview/Apply/Cancel/recovery through the real wrapper
  and editor modules. In-game confirmation remains required.

### Tester input/performance update — v0.2.100

- Replace picker action press-state polling with native TopNav CommonUI buttons
  and a shared, identity-scoped click router. Latch intent only in native hooks;
  defer UI/tint work to the existing owned picker tick. Cancel takes precedence,
  and closed/replaced views discard queued actions. Keep the read-only click
  probe compatible with the shared handler. No raw UMG delegate binding.
- Skip hidden-launcher validation while the picker validates its own context.
  Reuse already resolved grid references within validation. Scope lookup and
  attachment caches to one synchronous picker tick/initialization, and share
  class lookups during construction. Reacquire on every later callback; retain
  full identity checks and a full-path fallback for root-relative lookup.
- Log click receipt, consumption delay (Lua CPU clock), invalid input, Apply
  begin/completion and removal result in the probe/performance logs. Preserve
  native preview/Apply/Save behavior and recovery safeguards.
- Add quick-click, duplicate/stale/foreign event, shared hook, frame cleanup,
  lookup fallback and hidden-launcher regression coverage. Native testing is
  still required before claiming a measured performance improvement.

### Tester hotfix — v0.2.99

- Remove the live picker's dependency on developer-only DevPanel/rgb.txt,
  which was excluded from the clean tester ZIP and caused opening to fail.
  Read the initial color inside the normal freshly validated apply path;
  preserve alpha, exact restoration baselines and native scar HSV values.
  Clip out-of-range RGB values only for the bounded initial picker draft.
- Remove the same file dependency from legacy Default startup, using its
  verified stock donor color instead. Keep file-driven developer RGB probes
  explicit and unchanged; no save or Zabrak skin backend changes.
- Cover missing, malformed and conflicting developer inputs, the exact Zabrak
  horn color tag, regular armor/appearance, Default, skin and race bundles.
  Bump tester metadata and include a short end-user update note.

### Tester diagnostics

- Refresh the v0.2.98 tester ZIP's guide, mod descriptions and optional Dev
  Panel help text for end users. Replace the internal regression checklist
  with everyday customization and feedback guidance; retain installation,
  save-backup, restart and log-privacy advice. No runtime behavior changes.

- Colors+Probe v0.2.98 starts performance capture at the Custom Color press,
  before deferred opening, and retains it until Cancel, Apply, navigation or
  failure. Console/DP opens also capture; automatic windows have no timer and
  cannot be interrupted by manual colors_perf start/stop commands.
- Append UTC/build/window context, picker outcomes and five-second bounded
  timing summaries to colors_plus_performance.log. Batch each summary into one
  write/flush, avoid per-input IO and normal UE4SS mirroring, and fall back to
  UE4SS output if the file fails. Runtime teardown closes both log handles.
- Add lifecycle, long-session, stale callback, file failure and batching tests;
  provide tester instructions and an allowlisted ZIP builder excluding local
  logs/recovery state. No tint mutation or save behavior changes.

### UI

- Colors+Probe v0.2.97 hides Custom Color on vanilla Eyes.Color presets and
  armor-piece/style selectors. Remove the material-color-fragment fallback:
  a selected asset carrying tint data does not make its grid a color palette.
  Keep actual tint palettes, Default, added iris/sclera controls, Vitiligo and
  Scar Look eligible. Recheck eligibility when validating a picker binding.
  Add regressions for preset/style grids with and without material-color
  fragments, armor tint palettes and queued clicks across selector changes.

- Colors+Probe v0.2.94 wraps the combined hex input, eight-unit gap and color
  preview in a centered 400-unit SizeBox matching the SV area and hue strip.
- Replace the integrated picker's plain Custom Color title with a new instance
  of the game's SlotSubItemName heading Blueprint, including its branch marker,
  font and spacing. Initialize its WidgetTree via WidgetBlueprintLibrary.Create;
  set Caption before attachment and reacquire/set text after native Construct.
  Keep the decorative heading hit-test invisible and remove it with the owned
  picker root. Existing native headings retain their original contents.
- Add regressions for native heading initialization/call arity, owned caption,
  matching combined row widths and cleanup if creation or post-attachment text
  setup fails. All 42 programs pass; native heading rendering needs a restart/test.

- Colors+Probe v0.2.93 removes the duplicate Back to Swatches button. Cancel
  returns to the palette. Center the hue strip at the same 400-unit width as
  the SV area and add 12 units of padding above the Cancel/Apply row.
- Remove the footer message and two-minute draft expiry from regular previews,
  Default armor fallback and source-backed Zabrak skin. Cancel the regular
  preview's initial diagnostic timer when it becomes a live draft; a stale
  diagnostic callback also refuses to expire that live session. Keep native
  context checks, Cancel, Apply, navigation and recovery behavior.
- Show invalid hex/HSV guidance above the actions only while needed, without
  reserving a normal footer row. Extend tests for layout, input correction,
  all live backends without expiry and three-minute idle Zabrak drafts. All 42
  regression programs pass; the revised native layout needs an in-game check.

- Colors+Probe v0.2.92 hides the complete lower palette UI while the picker
  is open: swatches, both lower labels, injected slider rows and our Custom
  Color launcher. Discover disjoint sibling branches along the native grid's
  ancestry and validate each panel parent; injected widgets can have an outer
  outside the native WidgetTree. Keep the upper slot header/preview and picker
  host visible, retaining layout and native slider values.
- Snapshot all original visibility values before the first setter. Restore
  each surviving, still-owned target on Back, Cancel, Apply and cleanup, with
  partial hide/restore recovery and compatibility with v0.2.91 grid-only records.
- Extend integrated UI and recovery regressions for two labels, a nested slider,
  hidden launcher, injected widget paths, exact per-control restoration and
  interrupted multi-control operations. All 42 programs pass; native layout
  still needs an in-game test.

- Colors+Probe v0.2.91 temporarily sets the exact native palette grid to Hidden
  while the picker is open, retaining layout space and disabling drawing/input.
  Remove the integrated picker's dark backdrop by making its brush transparent;
  keep the full-host transparent input shield and the native slot header.
- Restore the original visibility on Back, Cancel, Apply, navigation, teardown
  and stale-picker cleanup. Publish a bounded scalar UE4SS shared-string record
  before changing visibility; it survives Lua reload within the same process
  and disappears on game restart. Validate exact grid/parent/picker identities,
  reacquire after setters, and preserve native visibility changes or reparenting.
- Add visibility restoration, partial setter/shared-state failure and Lua/game
  recovery regressions, plus transparent pane and Apply/Cancel integration checks.
  All 42 programs pass; native presentation/input needs an in-game test.


- Colors+Probe v0.2.90 fills the picker root across the complete verified swatch
  Overlay, keeping 560 units as its desired height for short palettes. Taller
  grids are covered instead of exposing hoverable rows below the picker.
- Add an owned non-focusable input shield behind the controls across the full
  pane. Palette pointer input cannot cancel the preview by activating a stock
  hover; closing removes the shield with the picker root. Native grid layout,
  visibility, items, focus and hover handlers remain unchanged.
- Extend integrated UI regressions for full-height alignment, stretched opaque
  background/input shield, inert blank-space clicks and ordinary close/reopen.

### Compatibility

- Colors+Probe v0.2.89 enables the normal Custom Color launcher for Vitiligo
  Tint and Scar Look, including empty selections and Dev Panel opening.
- Support Character Suite 10-01 scar palettes as the captured three-fragment
  `COS Swatch` / `MM Scar Tint` / `MM Scar Tint Strength` bundle. Edit only the
  second fragment and clone/preserve the display swatch and strength. Validate
  their exact face/horns targets and separate material names before any write.
- Preserve finite nonnegative scar tint baselines above 1 through preview,
  Apply, Cancel, Restore and recovery, with normalized RGB picker inputs.
  Rebuilt RGB Look and Tint presets can be preview donors; earlier RGB pairs
  and native HSV adjustment Looks retain their existing behavior.
- Extend regression coverage for captured Fresh Pink/Pale Silvery values,
  HDR donor recovery, None restoration, automatic launchers, immutable helpers,
  and refusal/retry after changed targets. All 41 programs pass; native
  vitiligo/scar rendering needs an in-game test.

- Colors+Probe v0.2.88 supports Character Suite 10-01 shared, left, right and
  inner iris colors through the standard Custom Color launcher and Dev Panel.
  Validate the captured color/amount pairs: outer `MM Iris Color Outer` with
  `MM Iris Recolour`, and inner `MM Iris Color Inner` with `MM Iris Inner Amount`.
  Preserve exact side-specific material targets and unchanged amount values,
  including when the preview donor has another amount. Shared/inner affect both
  eyes; left/right outer slots target their corresponding eye only.
- Enable the launcher and reversible None fallback for all four exact iris slot
  tags. Limit iris donors/fallbacks to their captured outer/inner asset families.
  Keep existing preview, Apply, Cancel, timeout and recovery journal formats;
  reject missing/changed companions, wrong eye targets and malformed values.
- Extend lifecycle/recovery regressions across all four iris layouts and None,
  plus donor amounts, cross-family palette entries and retry after target changes.
  All 41 regression programs pass; native shader rendering needs an in-game test.

- Colors+Probe v0.2.85 adds native HSV adjustment editing for Scar Look presets.
  Raw Red, Fresh Pink, Pale Silvery, Aged Brown and Dark keep their selected
  asset and open three H/S/V sliders with numeric inputs through the manual
  Dev Panel action, now named **Open live color picker**. Opening uses the exact
  current `Scar HSV Shift`, including negative/fractional values. RGB scar tints
  and vitiligo retain the color wheel; the None fallback remains RGB.
- Preserve raw adjustment values through preview, Apply, Cancel, timeout and
  reload recovery. Use same-kind HSV preview donors in mixed scar palettes;
  validate the exact scar slot/parameter and bounded finite values. No RGB,
  gamma or hex conversion is applied to native HSV shifts. Invalid input blocks
  both picker and Dev Panel Apply while retaining the last valid draft.
- Add regression coverage for all five HSV Looks, unchanged preset selection,
  exact numeric input despite native slider rounding, malformed recovery,
  partial Apply rollback, mode changes during opening and fresh widget lookup.
  All 40 regression programs pass; native HSV rendering needs an in-game test.

- Colors+Probe v0.2.84 adds manual Dev Panel/console picker opening for Character
  Suite Vitiligo Tint and RGB scar tint presets under Scar Look. The verified
  native selector host no longer requires an installed palette launcher for
  these two slots; automatic launcher installation remains unchanged elsewhere.
- Edit `Vitilago Color Override` or the scar `MM Scar Tint`/`MM Scar Tint Strength`
  pair. Preserve tint strength, including when the preview donor has another
  value. Keep HSV Look presets unchanged and skip them for scar donors and None
  fallback. None restoration, Apply/Cancel/Restore and reload recovery retain
  the existing journals and ownership checks.
- Extend lifecycle regressions for both manual slots, mixed scar palettes,
  preserved strength, missing optional horn/lekku meshes, manual pane cleanup
  and rejection of HSV/scalar selectors. Native rendering still needs testing.

- Colors+Probe v0.2.83 enables ordinary material-color editing for Character
  Suite sclera and lashes. Preserve the exact native lash material selectors
  in live validation and recovery records. Accept native None palette entries
  and restore them through the existing reversible selection fallback.
- Preserve the game's exact 0.99 alpha on Natural freckles while changing RGB.
  Other slots retain their existing opaque-color requirement; donor alpha is
  measured and restored independently from the selected source.
- Support blush's observed color/scalar pair. Edit `Cheek / Blush Color` while
  cloning and validating the unchanged `MM Blush Blend Mode`. Preview donors
  may use a different mode; source mode survives preview, Apply and Restore.
- Keep vitiligo and scars deferred for upcoming palette changes. Scar HSV is
  the game's existing behavior, not a Character Suite encoding change.
- Extend regression coverage for preview, Apply, Cancel, timeout, reload
  recovery, optional absent horn meshes, Native None and changed blush
  companions. All 40 regression programs pass; native rendering is unverified.

### Performance

- Colors+Probe v0.2.96 extends draft-scoped lookup reuse and elapsed-time
  latest-only scheduling to every supported picker profile, including armor,
  marking/horn/hair/cosmetic colors and native scar HSV controls. The first
  update discovers once; stable later updates freshly validate the exact route
  without global discovery. Retain 100ms post-update cooldowns, 495ms idle health
  checks, validated receipts, Apply flush and Cancel priority.
- Preserve all target/companion/mesh/ownership checks, context invalidation,
  restoration and recovery. HSV values keep their native range and precision;
  no RGB conversion or new compatibility allowance. Legacy profile-less probes
  and Zabrak's separate source-backed implementation retain their behavior.
- Extend discovery-count and event-invalidation tests across captured layouts,
  warm companion-mutation guards, four scheduler policies and raw HSV coalescing.
  All 42 regression programs and 52 Lua syntax checks pass. Native performance
  remains to be verified with the all-slot retest.

- Colors+Probe v0.2.95 extends draft-scoped scalar lookup reuse to shared
  SkinTone RGB updates. Human and race bundles reacquire and validate the exact
  route on subsequent drag updates instead of globally discovering it each time.
  Retain every source/preview, selected part, fragment, companion and mesh guard.
- Invalidate on every context notification, even while busy, and on Restore,
  new drafts and failed synchronous consumers. Reject reentrant pre-validation
  events before journaling or writing; notifications during setters still force
  full post-write/refresh checks and next-update discovery. No UObject cache or
  serialized route. Opening, idle health/display checks, Apply/Restore, recovery,
  preview cadence, armor and Zabrak retain their existing behavior.
- Cover warm Human face enabling and race-bundle discovery counts, unnotified
  between-update changes, reentrant validation, busy events, consumer failures
  and lifecycle recovery. All 42 regression programs pass, and all 52 Lua
  modules pass syntax checks. Native smoothness remains to be verified.

- Colors+Probe v0.2.87 applies transaction-local discovery reuse to outfit color
  previews: one full page/auxiliary VM discovery, followed by fresh bound checks
  after mutation and refresh. Native context events force rediscovery. Armor
  also uses skin's latest-only elapsed-time gate (100ms post-update cooldown),
  validated update receipts and 495ms idle health checks instead of poll counts.
- Zabrak keeps a scalar selected-context route only for the current draft. Every
  use reacquires the native route and validates creator/page, selection, source,
  owner, part and target relationships. All context notifications invalidate it,
  even during busy source writes; reentrant events during validation refuse the
  result. Source guards, journal ordering, refreshes and Apply/Restore stay intact.
- Add `zupdate.context_discover`, `zupdate.context_bound` and
  `zupdate.source_guard` timings. Cover armor scan counts, event fallback, both
  scheduler policies, stale routes and notification-free/reentrant changes.
  All 41 regression programs pass. Native speedup remains to be measured.

- Colors+Probe v0.2.86 replaces repeated global preview-container searches in
  handoff verification with exact lookup of the recorded identity. Revalidate
  storage, source/data/display links, instance ownership, preview mode and meshes
  on every call. Missing lookup falls back to unique discovery without adopting
  replacement identities. Initial discovery, activation and restore keep scans.
- Pass an expiring synchronous context reader from the validated skin update to
  face-tint enabling. Reacquire and verify all context/fragment/mesh links; native
  notifications force full discovery. Revoke readers on success, false results
  and errors; leave busy mode before enabling to preserve event handling. No
  cross-tick binding/native-result cache, journal changes or skipped refreshes.
- Add exact-lookup/fallback/replacement tests and integrated Human discovery-count,
  event-invalidation, expired-reader and consumer-failure regressions. Existing
  stage labels remain; `skin.resolve_bound` identifies the new reader path.
  Actual performance improvement still requires an in-game capture.

- Add opt-in `update-stages-v1` capture detail for shared skin and source-backed
  Zabrak updates: validation, recovery journals, color writes, refresh and face
  tint cleanup/re-enabling. Retain mutation ordering and all guards; this pass
  measures remaining costs and makes no new speedup claim. Increase the bounded
  label budget to 96 and test stage order, error propagation and successful
  return behavior. No timing-related native calls or per-update timing log IO.
- User verified v0.2.82 across tested skins, with brief lag remaining. Captures
  averaged 177.38ms Human, 157.48ms Twi'lek and 157.00ms Ovissian preview updates.
  Bound context resolution averaged 1.68ms and SV input 0.38ms across captures.
  Keep shared version metadata unchanged during parallel appearance work;
  `PERF | START | update-stages-v1` identifies this instrumentation patch.

- Colors+Probe v0.2.82 applies transaction-local context discovery reuse to the
  shared SkinTone backend, covering supported race layouts rather than a Human
  special case. Core updates perform one full page/auxiliary VM discovery instead
  of three. Both post-mutation checks freshly reacquire the bound route and retain
  creator/page, selected slot, source, fragment, material and mesh checks. Native
  context notifications invalidate reuse, including during busy writes. No
  binding or UObject is retained across updates. Non-skin zones, source-backed
  Zabrak, face tint-enabling, journals and recovery writes remain unchanged.
- Add regression coverage for changed page/VM/slot/source/target/mesh/creator
  during SetColor, page changes during refresh, event-triggered full rediscovery,
  fresh discovery on the next update and shared race-layout scan counts.
- v0.2.81 native captures measured preview-update averages of 85.05ms for Zabrak
  and 296.48ms for Human; user verified all lifecycle tests but reported choppy
  Human dragging. These are inclusive profiler-clock measurements, not controlled
  wall/frame benchmarks. v0.2.82 native improvement is pending verification.

### Added

- Colors+Probe v0.2.79 adds a separate read-only `colors_click start|stop`
  diagnostic for existing CommonUI/game UFunction press/release/click handlers.
  Hooks are opt-in, runtime-owned and inert outside bounded 60-second/500-event
  windows. Reports distinguish page-scoped from unscoped pooled buttons; no
  delegate-signature hooks, event-reply overrides or input-mode writes. Native
  event delivery remains unverified and is not wired into production SV input.
- Expand performance labels for native object lookup, SV child lookup/hover/press,
  HSV operations, selected-slot resolution and launcher binding reuse/discovery.
  Normalize per-panel serial and snapshot labels to preserve bounded summaries.

- Colors+Probe v0.2.78 integrates the native-verified desktop-delta SV drag
  into the normal Custom Color picker. Retain the 24x16 native click seed grid
  to avoid previously failed opaque geometry conversion; a held press tracks
  only its captured cell. Center an owned 400x240 area for known delta scaling.
  SV drag is continuous/clamped, suspends on coordinate loss/UI-scale changes,
  and requires release before rearming. Poll HSV input at 16ms, but keep preview
  writes coalesced (~208ms) and context checks near 500ms. Existing restoration,
  Apply flush, save paths and fixed timeout remain unchanged. Native integration
  still needs verification; initial clicks remain quantized to the seed grid.
- Add opt-in `colors_perf start|report|stop`: 120-second captures with bounded
  five-second aggregate summaries for construction/gradient/grid costs, input,
  redraw, tint start/update/Apply/restore, scheduled callbacks and queue-clock
  lateness. Report count/average/maximum/total/>=16ms/errors, preserve nil returns
  and errors, and stop on runtime teardown. No per-pointer logging or extra
  native profiling calls. Timings use platform-dependent `os.clock`, not GPU or
  guaranteed wall/frame timings; nested inclusive totals must not be added.
- User verified v0.2.77 isolated drag, rapid clicking and focus return. Desktop
  movement increased while viewport coordinates remained fixed under capture.
  This validates the desktop-delta path, not native delivery of the event hook.

- Colors+Probe v0.2.75 adds opt-in `colors_sv start|stop`, an isolated UI-only
  SV input experiment. One transparent native Button provides capture; a scoped
  UserWidget preview-down observer latches quick clicks without modifying event
  replies. DPI-scaled scalar mouse outputs drive a marker at 16 ms while held.
  Show event/fallback/press/release counters, clamp outside drags, freeze on
  release and cancel on page changes/90-second timeout/runtime teardown. No
  tint, save, geometry conversion or input-mode writes. Normal CP is mutually
  exclusive with this probe and otherwise unchanged. Native bridge verification
  is pending; mocks cover quick clicks, drag state, lifetimes and failures.
- Colors+Probe v0.2.70 adds a native 24-by-16 clickable saturation/value area,
  continuous rainbow hue slider, position marker and editable six-digit hex
  field. Pure byte-sRGB/HSV math preserves hue through greys/black; exact hex
  accepts arbitrary RGB. Invalid/partial text holds the last draft and blocks
  the UI Apply action. No saved swatches or free two-axis drag are included.
- Bound gradient repaint to two rows per poll, use hovered-row input scoping
  and reacquire all widget identities. Existing coalesced RGB/backend Apply,
  timeout, Cancel and save behavior remain unchanged. Extend real view/coordinator
  tests for exact/invalid hex, Apply flush, Cancel priority and bounded repaint.
- Colors+Probe v0.2.68 starts the rainbow-switch UI redesign with an automatic
  Custom Color launcher appended only to the active native color selector.
  The existing RGB picker occupies the measured lower swatch pane, with Back
  to Swatches/Cancel and Apply Color. HSV/hex controls remain a later step.
- Native list/visibility/focus/switcher state is unchanged. Owned roots use
  exact ancestor, page/slot and generation checks, bounded event-driven
  readiness, deferred click dispatch and explicit context/reload cleanup.
  Added scoped launcher and real picker-view integration regression tests.
- User verified v0.2.67 Zabrak native Save/full-restart persistence and editing
  a saved custom color followed by Cancel restoring its saved orange baseline.

### Fixed

- Colors+Probe v0.2.81 changes SkinTone preview scheduling, including Zabrak:
  send the first changed sample immediately, then use a 100ms post-update
  readiness timer instead of waiting for 13 slow UI polls. Write only the latest
  sampled RGB, never a backlog. Rearm the 495ms idle check only when the backend
  explicitly confirms a successful validated update; retain idle checks without
  that receipt. Every update keeps its existing ownership checks/journal writes.
  Timer tickets plus picker identity prevent retired callbacks from releasing
  newer gates. Apply flushes latest input during cooldown; Cancel/Apply clean up
  all three owned picker jobs. Other slots retain existing scheduling. Extend
  regression tests for throttling, latest-only input, receipt failures, idle
  checks, Apply/Cancel, replacements and stale timers. Native retest pending.
- User verified v0.2.80 opening/closing improvement, radial round trip and Restore.

- Colors+Probe v0.2.80 addresses Zabrak CP closing just after opening over a
  hovered stock swatch. Treat `ResetPreviewedPart` as a context-validation event,
  keeping a draft only after current source/slot/owner/page/creator checks pass.
  Retain other event cancellations and exact replacement retirement; guard
  dispatched callbacks against Cancel/reopen or Apply. Avoid a duplicate source
  membership check in the same context callback without caching across ticks.
  Add regression coverage for reset/no writes/deadline preservation, stale jobs,
  slot/page/creator changes and external replacements. Preview cadence and all
  write/save/recovery paths remain unchanged; native verification is pending.

- v0.2.79 targets v0.2.78 native input/validation stalls: reacquire one SV grid
  and traverse its immediate native children with identity/order/count checks,
  rather than globally finding every row/cell. Retain no wrappers across ticks.
  Replace repeated full palette enumeration during selected-slot resolution
  with exact equipped-item/index/owner membership checks; full donor validation
  remains. Reuse launcher bindings only after fresh lifetime/ancestry/VM/palette
  checks. No tint write, save or recovery algorithm changes. All 40 regression
  programs pass; native performance gains and click delivery need testing.

- Colors+Probe v0.2.77 tests desktop-delta SV dragging after v0.2.76 opened
  but usually held its initial coordinates during capture. Native logs showed
  zero press-event callbacks, 65 fallback presses and a later mouse-position
  unavailable error; rapid-click success did not verify the event bridge.
  Anchor each drag to its starting viewport/desktop coordinates and UI scale;
  count desktop and viewport movement separately and display capture state.
  Coordinate loss/scale changes suspend the drag until release rather than
  closing the probe. Frozen-viewport and focus-loss mocks pass; native input
  behavior remains to be verified. Production picker/tint code is unchanged.
- Colors+Probe v0.2.76 fixes the isolated SV probe's `Ambiguous mouse X`
  opening refusal. Pass one shared output table for both scalar coordinates
  and read the exact `LocationX`/`LocationY` fields. UE4SS writes scalar outs
  by property name and its current implementation can reuse the first table.
  Tests now include both axes in that table, unrelated numeric fields, missing
  axes, non-finite coordinates and independent-output behavior. No color or
  production-picker changes; native SV input test still pending.
- Colors+Probe v0.2.74 replaces the launcher's six colored blocks with one
  smooth gradient image at the same 42-by-24 size. Share the scalar-identity
  texture loader between launcher and picker, avoiding a duplicate hue import.
  Native v0.2.73 SV/hue rendering, hex contrast and Back/Cancel are user-verified.
- Make Zabrak CP's separate BEGIN/RETURN call diagnostics opt-in through the
  existing picker trace window. Latest native logs still contained these
  synchronous writes during ordinary opens/edits. Preserve errors, milestones,
  validation bounds, journaling and all tint/recovery behavior. Additional lag
  improvement is not yet verified in-game.
- Colors+Probe v0.2.73 replaces 384 child-Border cell paints with a hue base
  and two alpha-gradient UImages, separate from the transparent hit buttons.
  Replace 36 hue chips with one smooth PNG strip; use dark hex input text.
  Three reproducible packaged assets total 2,463 bytes. Reacquire imported
  textures by identity; brushes own references, and missing/collected textures
  reimport. Hue changes require one base tint update, not a grid repaint.
- Picker call tracing is now opt-in via `colors_picker trace`; ordinary opens
  retain stage logs without thousands of synchronous per-call flushes. The
  v0.2.72 native test verified clicks, hue, timeout and cancellation but exposed
  invisible SV drawing, low text contrast and a large opening hitch. Native
  v0.2.73 rendering/performance verification remains pending. Tint/save logic
  and the Dev Panel app are unchanged.
- Colors+Probe v0.2.72 fixes hue-strip construction: the UI `linear` helper
  returned both color and diagnostic text from `rgb_input.parse`, which Lua
  expanded into two `SetBrushColor` arguments. Native v0.2.71 logs confirm all
  SV cells built without crashing, then opening failed with expected-one/
  received-two and removed its owned root before preview writes. Return exactly
  one color; strict-arity mocks reproduce the failure before the fix and pass
  after it. No other controls, tint backend or save changes. Native open pending.
- Colors+Probe v0.2.71 removes the new HSV cell `SetStyle(FButtonStyle)` call.
  v0.2.70 native trace ended at its first BEGIN with no RETURN; both September 30
  crash reports share an access-violation stack hash. No HSV-ready/view-ready or
  tint-preview-start checkpoint was reached. The precise native struct-copy
  fault is not symbolized. Keep stock button input with transparent backgrounds
  and paint owned non-hit-testable child Borders using `SetBrushColor` instead.
  Regression tests prohibit whole-style calls, verify Border ownership/fill,
  white/black corners and bounded repaint. Add SV/hue/hex build checkpoints.
  Native opening confirmation is still required; no tint/save/backend changes.
- v0.2.70 gives the owned picker Canvas a 560-unit desired height so short horn
  lists do not truncate its opaque background. Bottom-align the launcher in an
  owned fill-sized footer instead of its previous auto-sized row. No stock
  list/visibility/focus sizing is changed; native placement still needs testing.
- User verified v0.2.69 launcher/picker opening and Back/Cancel restoration;
  screenshots showed variable footer placement and a short background on Horns.
- Colors+Probe v0.2.69 fixes the rainbow launcher opening path after native logs
  confirmed clicks reached CP but `AbsoluteToLocal` returned an unreadable host
  point. Fill the exact SelectionTiles Overlay with native anchors instead of
  passing opaque cached geometry through reflected coordinate conversions.
  Retain ancestry/lifetime guards, native list state and the proven tint backend.
  Correct rainbow decoration from Hidden to visible/non-hit-testable. Tests
  reject geometry access and verify fill anchors, margins and decoration;
  native visual layout and picker opening remain pending user verification.
- Colors+Probe v0.2.67 integrates the native-verified Zabrak source handoff into
  normal CP, replacing its transient face-MID RGB/enable workaround. Other
  slots and the opt-in console probe remain unchanged.
- Arbitrary source RGB updates journal both accepted colors before setters.
  Draft Cancel/timeout restores the previous Apply or original visit baseline;
  Apply/radial/native hover retain source RGB without periodic repaint. Creator
  exit and Restore verify RGB, enable targets and order before clearing recovery.
- Corrected saved layouts may be reopened with their own baseline. Independent
  per-zone source journals are process-gated; interrupted handoffs hold evidence,
  and Reload All Mods is refused while a Zabrak CP source edit is owned. No MID,
  stock-reference or save APIs are added. Native Zabrak Save/restart remains a test.
- Tests cover the actual picker coordinator, rebuilt source/restore arrays,
  arbitrary RGB, reopen/Cancel/Apply, fixed timeout, radial/hover no repaint,
  creator exit, native edits, saved-layout baselines, recovery/journal failures,
  multi-zone reload guards and cold-process quarantine.

- Colors+Probe v0.2.66 resumes the opt-in 60-second Zabrak source-dispatch
  experiment after the native v0.2.65 test verified four fresh identities,
  preserved supported payloads/ownership and the requested array order.
  A synchronous before/after handoff validates each own array setter, including
  restoration, and journals returned identities before subsequent native writes.
- Bounded v3 recovery records store owned/in-flight phases and expected order.
  Failed or interrupted handoffs retain evidence and block further mutation;
  later UI/RGB/refresh replacements are never adopted. Retired source instances
  no longer produce a false successful restoration or clear the journal.
- Known-owned partial failures remain restorable; stock RGB/enable targets/order
  and post-refresh ownership must verify before recovery is cleared. Tests cover
  rebuilding Start/Stop, unchanged identities, copy mismatches, journal failures,
  later replacements, exact recovery, stale jobs and opaque-reference read traps.
  The normal picker and installed Dev Panel application remain unchanged.

- Colors+Probe v0.2.65 changes `colors_zabrak start` to a one-shot before/after
  array-setter inspection. Native v0.2.64 returned different fragment identities
  and refused before RGB/enable/refresh calls; the log did not show the new set.
  The new read-only inspector logs every bounded returned fragment's identity,
  class, owning instance/slot and supported payload. Canonical layout/RGB/swap
  target comparisons and actual/requested order are reported without adoption.
- Unknown/duplicate classes and foreign owners skip payloads. Per-item Lua
  failures keep earlier field evidence and continue to later items. Traced
  getter boundaries narrow native faults. Neither material-reference property
  is read, and there are no RGB/target/MID/refresh setters in this probe path.
- Plain `zabrak-inspection-v1` intent is persisted before the single array
  setter and retained afterward. Stop, transitions, reload/recovery and timeout
  cannot perform another setter or adopt the returned objects. Restart without
  saving after the test: original order is not claimed restored. Old dispatch
  journals also hold unchanged without native recovery. Normal CP and the
  installed Dev Panel app are unchanged. Tests cover copies, ignored order,
  foreign/unknown/invalid fragments, getter failures, partial setter errors,
  journal holds and one-setter-only behavior.

- Colors+Probe v0.2.64 restores the opt-in 60-second Zabrak source-order/RGB/
  enable-target experiment without reading either replacement-material
  reference. The user completed v0.2.63 capture with all 56 boundaries returned;
  the swap's captured target is Skin Coloration, the RGB bundle's six mesh tags,
  and MI_Head. This narrows suspicion but does not prove the old crash cause.
- The proven read-only path lives in `zabrak_capture.lua`; `capture` still makes
  no engine mutations or recovery-file writes. Start, source readback, each
  setter/refresh and restoration have flushed BEGIN/RETURN/ERROR checkpoints.
  Helpers are traced as boundaries, not every internal native call.
- Target-only `zabrak-dispatch-v2` recovery records preserve original RGB,
  stock order/enable layout and exact four fragment identities. Legacy v1
  records block unchanged without native recovery. Stop/deadline/creator exit,
  partial failures, source replacement and foreign RGB/target guards remain.
  Reference-only edits by another mod cannot be detected and are never repaired.
  New tests trap hard/soft reads and cover capture, traced setters, target guards,
  journal routing and rollback. Normal CP and the installed Dev Panel app remain
  unchanged. Source rendering/persistence still require native tests; do not save.

- Colors+Probe v0.2.63 makes the Zabrak console probe read-only following two
  matching native null-read crashes before its first source-write checkpoint.
  `start` refuses without engine calls; `capture` traces bounded identity and
  swap-target reads with flushed BEGIN/RETURN/ERROR boundaries. Neither hard
  nor soft replacement-material properties are accessed or stringified.
  The existing picker resolver and array helpers are traced as boundaries, not
  as individual internal native calls; the exact crash cause remains unproven.
- The diagnostic contains no source/MID setters, refresh calls, timeout edits
  or journal writes. Old dispatch recovery records remain untouched and block
  native recovery until a restart without saving; human source-journal routing
  is unchanged. Automated tests cover disabled start, forbidden pointer reads,
  zero mutation, paired checkpoints, Lua-error retries and retained recovery.
  The normal picker, face RGB handoff and installed Dev Panel app are unchanged.

- Colors+Probe v0.2.62 adds the opt-in `colors_zabrak start/stop/capture` source
  experiment. The exact captured Zabrak bundle is reordered tags/swap/RGB/scalar,
  Enable Tinting targets its six captured meshes, and source RGB becomes orange
  for 60 seconds. Only normal native refresh renders this test: no display MID
  writes, post-refresh repair or periodic reapplication. Native results remain
  required; ordering and targeting are tested together, not diagnosed separately.
- Original RGB, order, target layout, swap evidence and exact source identities
  use a bounded `zabrak-dispatch-v1` write-ahead record in the existing
  process-gated source journal. Stop/timeout/creator exit restore owned source
  values; radial transitions retain them without setters. Unknown replacements
  and external edits are not adopted or overwritten. Installation that copies
  fragments refuses before RGB/target setters; restart without saving in that case.
- The source-test router shares existing CP/eye/DP exclusions and Restore. Human
  target/save commands remain unchanged. Reload is blocked while dispatch state
  remains owned or unrecovered. New tests cover journal routing, partial writes,
  retryable restoration, source replacement, foreign changes and no reapply.
- Native v0.2.61 results confirmed hands/face RGB, unchanged horn-base skin,
  Apply success and transient face restoration/reapplication on radial navigation.
  The normal picker workaround remains in place until source rendering is proven.

- Colors+Probe v0.2.61 adds a reversible post-refresh `Skin Coloration` write
  to the uniquely visible Zabrak face MID. Native v0.2.60 traces showed custom
  RGB on the arm but stock RGB on face/horn-base skin despite face enable=1.
  The swap companion is a hypothesis, not a diagnosed cause. This face-only
  handoff does not change source targets or establish saved rendering support.
- RGB and enable restoration are independently attempted with original MID,
  outer, parent and assignment checks. Partial failures remain retryable;
  foreign RGB is preserved and replacement materials are untouched. Captured
  parent declaration and normalized opaque color checks gate the vector write.
- Automated tests cover post-refresh RGB, no-write repeated checks, Apply,
  radial/hover, Cancel/timeout/Restore, invalid outers/parameters/colors, foreign
  edits, setter-triggered replacements and independently failed restoration.
  Human scalar-only behavior and all source bundle companions remain unchanged.

- Colors+Probe v0.2.60 replaces Zabrak's actor-wide `MI_Head` uniqueness gate
  with a uniquely visible exact face-tag component lookup. Retained ownership
  reacquires and checks that component, MID, index and parent; hidden old faces
  can be restored but are not reused for an active preview. Human behavior is
  unchanged. Source scalar targeting and game saves remain untouched.
- Face discovery refusals log candidate counts, bounded component identities,
  visibility and slot names. v0.2.59 logged only a failed uniqueness assertion,
  so its native failure did not establish whether candidates were absent or
  duplicated. Tests cover unrelated MI_Head components, hidden faces, missing
  targets and multiple visible faces without choosing an arbitrary material.

- Colors+Probe v0.2.59 adds a reversible Zabrak face-enable test through normal
  CP preview/Apply. The captured four-fragment six-mesh head/body RGB bundle
  has an Outfit-only enable target; only its verified assigned display face MID
  receives the transient enable switch. Source scalar targets, swaps and race
  tags are untouched. This is not a native Save/persistence fix.
- Captured-layout, ownership, refresh/navigation, hover, Cancel/timeout/Restore,
  destroyed material and partial-enable-failure tests cover the Zabrak extension.
  Other race bundles and the manual Skin Tone 5 command remain unchanged.
- Togruta marking pairs and Ovissian Skin Tone 1/2 passed the user's v0.2.58
  in-game preview/Apply/radial/Restore and timeout checks.

- Colors+Probe v0.2.58 supports the captured Togruta face/lekku marking
  `Tattoo Color` + `Enable Tinting=1` pairs. Only RGB is edited; the matching
  scalar, material and mesh targets are retained and verified throughout recovery.
- Ovissian skin accepts the captured read-only `IrisUVRadius` companion on
  `MI_EyeRight`. Skin Tone 1/2 can serve as sources and preview donors despite
  their differing companion counts. The iris scalar is cloned unchanged, not
  exposed as an eye-color edit. Unknown or changed companions still refuse.
- Automated fixtures cover both marking targets, asymmetric Ovissian donors,
  parameter/target guards and retryable companion validation. Native testing
  remains required. Zabrak's no-visible-skin-tint correction is separate.

- Colors+Probe v0.2.57 supports captured nonhuman skin/horn tint bundles:
  material-swap companions, varying mesh/material targets, empty horn scalar
  material lists, scar HSV and hue-shift companions, and Twi'lek's three RGB
  fragments. Only `Skin Coloration` colors are changed; Restore journals and
  restores each RGB fragment's own baseline. Human source-target recovery is
  unchanged. New proxy-v11/editor-v7 records remain bounded plain data and older
  journals are still readable.
- A verified original character losing its edited slot on a race change retires
  that edit without writing into the replacement or globally blocking the
  picker. Replaced bundle companions are also retired by exact identity.
- Compatibility capture and Dev Panel descriptions recognize race tint bundles.
  Automated race fixtures cover grouped preview, Apply, Cancel, timeout, repeated
  Apply, Restore, hot recovery, partial-write rollback, and setter replacement.
  Native rendering/save validation for these new targets is still pending.

- Colors+Probe v0.2.56 removes the single-applied-zone limit using independent
  editor/Default/preview journals and cancellable action namespaces. Cancel ends
  the current draft; Restore restores all owned edited zones. Up to 32 concurrent
  records are bounded for safety. Cold-process quarantine covers every journal.
- Ordinary color targets are discovered from their actual one/multi-mesh data
  rather than a tattoo slot allowlist. Removed human skin asset and Skin Tone 5
  source-correction gates; verified skin fragment/race/target structure remains
  mandatory. Preview face-material ownership is captured dynamically. Eyes remain
  excluded; the old explicit diagnostic probes remain narrow.
- Default handoff accepts compatible non-outfit None palettes as well as outfit
  defaults, preserving exact original widget identity and selected source ownership.

- Colors+Probe v0.2.55 integrates the verified Skin Tone 5 source scalar target
  correction into normal picker Apply. An editor-v6 record journals the exact
  companion scalar and original Outfit target before writing; Restore repairs
  target and RGB together, including partial-write recovery. Existing v1-v5
  recovery formats remain readable. Saved five-mesh skins retain that layout
  when editing/restoring; no custom persistence or automatic reapplication.
- Regression coverage includes partial target mutation, native replacement
  preservation, saved custom skin Cancel/Apply/Restore, source-only applied
  rendering, navigation gaps and same-process recovery.

- Colors+Probe v0.2.54 adds opt-in `colors_target save` (120-second window)
  and read-only `colors_target check`. Save mode does not restore on context
  transitions or reapply after reconstruction; normal start remains 15 seconds
  with transition cancellation. Explicit stop, deadline and recovery remain.
  Checks log source identity, layout and RGB without claiming disk persistence.

- Colors+Probe v0.2.53 avoids the failed whole-struct SetMaterialTarget argument:
  the isolated target probe writes only the scalar target's tag-array field,
  with immediate full target readback. Normal picker behavior is unchanged.
- Recovery validates exact ownership and untouched companions independently of
  damaged scalar target fields, then repairs parameter, materials and tags with
  per-field tracing/readback. Regression tests cover corrupt parameter/materials,
  partial write exceptions, retryable restore failure and same-process recovery.
  Native leaf-array assignment still needs the in-game no-save test.

### Added

- Colors+Probe v0.2.52 adds isolated colors_target start/stop. On verified Skin
  Tone 5 source scalar only, replace Outfit targeting with the observed five-mesh
  target through SetMaterialTarget, then refresh. No RGB, direct MID, stock preset
  or save writes. A separate versioned write-ahead journal owns restoration to
  Outfit; Stop/context/15-second timeout restore, exact-source replacement is
  preserved, partial failures retain recovery, and cold-process journals are
  quarantined by the existing session gate. Block overlapping write probes.
  Tests cover normal restoration, partial setter failure, recovery and malformed
  journals. This first native test does not authorize saving the changed target.
- Colors+Probe v0.2.51 adds read-only colors_save baseline/before/after snapshots
  using the bounded material observer. Label source RGB, scalar targets, rendered
  getters/overrides and runtime Apply/enable state. Capture before only for the
  matching applied source; refuse baseline/after with active mod ownership or
  any stage with a live draft/blocked recovery. No material, preset, source or
  save mutations. One-shot captures do not arm timers or disturb material windows.
  Capture commands are game-thread deferred and cancelled on navigation/reload.
- Colors+Probe v0.2.50 separates applied RGB ownership from display availability.
  Idle skin rendering verifies the source actor without requiring a hover
  instance/data object that radial navigation may retire. Rendering failures
  retain verified source RGB, retry at most eight times, then wait for a context
  event; source/visit validation continues independently. Initial Apply failure,
  source replacement and editor exit retain their rollback/cleanup behavior.
  Regression tests cover missing hover data, display gaps and navigation recovery.
- Colors+Probe v0.2.49 integrates the verified Skin Tone 5 face-enable operation
  into normal picker preview/update/check/Cancel and editor Apply/Restore.
  Automatic ownership has no separate ten-second timer; preview uses its existing
  deadline, and applied rendering follows the verified editor source/visit.
  Suspend for stock hover and resume the still-owned custom source afterward.
  Reopen/Cancel preserves a previous Apply; failed Apply rolls back RGB and the
  switch. Existing target, clothing, creator and material checks remain. Only
  CPD_H_SkinTone_Human_0B1 with the captured MI_HF00_Race0B parent is opted in.
  No preset, scalar-fragment, or save writes; persistence of the enable switch
  is not implemented. Restore applied skin before reload. DP startup unchanged.
- Colors+Probe v0.2.48 reacquires the skin test's exact face component through
  its actor instead of a dotted component path. Preserve MID identity, parent,
  timeout and restoration guards; test failed direct lookup with live enumeration.
  Defer local panel client initialization/counter baseline to owned game-thread
  startup, trace startup and first-poll execution, and preserve missing-API
  fallback and stale-click suppression. Installed DP unchanged. Native tests pending.
- Colors+Probe v0.2.47 adds `colors_skin_enable start/stop`: a narrow 10-second
  Skin Tone 5 displayed-face MID experiment, with original scalar readback,
  cancellation, material replacement checks, failed-restore ownership and Apply
  blocking. Parent assets, skin fragments and saves are never written. Active
  experiments refuse runtime teardown; stop before reload. The local Dev Panel
  client now uses the probe runtime's owned scheduler and is recreated on reload
  instead of retaining a retired scheduler. Installed DP and clothing guards
  remain unchanged. Native rendering and panel delivery need in-game verification.
- Colors+Probe v0.2.46 adds read-only skin material comparisons and console
  `colors_materials start/sample/stop`, with Skin Coloration/Enable Tinting
  getters, three-fragment observations and bounded parent overrides. Preserve
  exact linked display access, target material filtering, capture budgets and
  navigation/reload cancellation. Add local panel-client delivery stages and
  read-only `colors_panel status`; report polling errors and retry failed state
  parses without consuming changed bytes/resetting counters. Logging tolerates
  timestamp/output failures. Installed DP, tint writes and clothing guards are
  unchanged. Native skin rendering and missing DP delivery remain under diagnosis.
- Colors+Probe v0.2.45 supports the observed Outfit-parent tint-enable scalar
  on equipped human skin (Skin Tone 5), not only stock donors. Capture its exact
  layout in the target profile; preserve/check it through clones, installed
  preview/display, Apply and restoration. Color targets remain five-mesh with
  unchanged material, race, scalar-value, ownership and clothing-change guards.
  Parent-layout recovery records use proxy-v10/editor-v5 with a validated marker;
  legacy five-mesh records retain their existing semantics. Tests cover both
  layouts, differing donors, Cancel/reopen/timeout, Apply/Restore, recovery,
  malformed journals and layout tampering. Skin Tone 5 native testing pending.
- Colors+Probe v0.2.44 handles cyclic category-slot references during displayed
  color selection. Record identities before descending, validate each repeated
  reference and its tag, and skip only its already-visited subtree. Continue
  scanning other branches for ambiguous candidates; retain bounds, ownership,
  current-slot membership and active palette checks. Log back-edge counts.
  Regression tests cover self/ancestor/multi-node loops, repeated reopen,
  ambiguity beyond loops and invalid or changed repeated nodes. No native write,
  recovery or installed Dev Panel app changes. v0.2.43 skin preview/slider updates
  passed live; v0.2.44 reopen verification remains pending.
- Colors+Probe v0.2.43 accepts the observed human skin stock donor scalar variant:
  Enable Tinting=1 on the Outfit parent tag with the same three material names.
  Restrict this exception to stock proxy/hover and donor display checks plus
  pre-install cleanup. Preserve five-mesh color, source, cloned bundle, owned
  preview/display and editor checks. Pre-install skin recovery resets stock hover
  without recoloring it. Tests use the real donor layout and displayed copy,
  cover pending/verified/prepared recovery, and reject wrong parent targets or
  leaked stock layouts in custom/source fragments. No new APIs/hooks, recovery
  formats or installed Dev Panel app changes. Native retest is pending.
- Colors+Probe v0.2.42 adds bounded diagnostics for the first live human-skin
  refusal. Log source/requested/actual donor identity and, on target validation
  failure, the parameter, mesh/material counts and indexed actual/expected names.
  Reuse already-read arrays, sanitize/cap output, and preserve refusal/rollback
  if diagnostic logging fails. Tests reproduce mismatched donor color/scalar
  targets, verify no custom-color writes and successful cleanup, and cover
  bounded output, silent successful validation and unreadable names. No guards,
  recovery formats, write sequence or installed Dev Panel app changes.
- Colors+Probe v0.2.41 adds guarded human Skin Tone support. Validate the exact
  ordered gameplay-tags/color/scalar bundle, preserve its single race tag and
  Enable Tinting=1, and clone/install all three fragments while recoloring only
  the material-color fragment. Validate all five mesh assets in source, preview
  and display. Same-family human stock donor selection is checked against the
  actual companion tag before custom writes. Reject aliased clones, companion
  changes, missing/replaced meshes, unknown layouts and non-human source assets.
  Proxy-v9/editor-v4 journals retain the skin race tag and five-target profile;
  existing journal formats remain supported. Compatibility capture and local
  panel descriptions cover the new candidate. Real backend integration tests
  exercise preview, Apply, Cancel/Restore, timeout/exit, Lua recovery, malformed
  journals, copy-on-install failures and changed companions. Native verification
  is pending; no new hooks, companion setters or installed Dev Panel app edits.
- Colors+Probe v0.2.40 fixes the v0.2.39 tracing helper's reliance on global
  `unpack`, which is absent in the game runtime. Prefer `table.unpack` with a
  Lua 5.1 fallback. Reproduce the failure in a regression test and cover both
  standard-library layouts, including zero, nil and multiple return values.
  No target, lifetime or mutation behavior changes; original crash still under
  investigation.
- Colors+Probe v0.2.39 adds temporary per-call crash diagnostics: matched
  BEGIN/RETURN/ERROR markers for picker lookup/validity, button/slider reads,
  readout/swatch updates, attachment/removal, snapshot reads and owned deferred
  jobs. Each picker opening arms a 10-second/6,000-call window; close stops it.
  No extra native object reads, new hooks, target changes or Dev Panel app edits.
  The latest native crash followed tattoo OPEN but preceded its first RGB update
  marker. A separate later attempt safely refused a selected-slot-tree cycle
  even after Restore succeeded; that guard remains intact. Tests cover tracing
  transparency, limits, nesting, cancellation, UI errors and snapshot errors.
  Native crash cause remains unconfirmed; logging can affect reproduction timing.
- Colors+Probe v0.2.38 hardens active picker lifetime handling after the 11:47 UTC
  UE4SS crash (native cause still unconfirmed). Retain scalar widget identities,
  gate read/show/set paths on fresh root attachment, allow already-destroyed root
  cleanup, and prevent re-entrant old polls/errors from acting on a replacement
  picker. Verify the exact owned preview after SetColor before refreshing it;
  apply the same reacquisition rule to editor Apply/Restore. Add bounded stage
  markers for the first eight RGB updates and deduplicate identical palette
  discovery logs without caching validation. Regression tests cover removed/
  destroyed widgets, wrapper replacement, re-entrant closure and changed preview
  links during SetColor. Reviewed against the local Lua guide and current UE4SS
  delayed-action docs. No new hooks, skin/horn write support or Dev Panel app edits.
- Colors+Probe v0.2.37 starts skin/tattoo work with the observed Tattoo Color
  face/horns pair. Record every target's equipped asset or explicit optional
  horn absence; validate source, preview and display rather than only the first
  mesh. Keep one-fragment, ownership, palette, timing and source-write guards.
  Multi-mesh proxy-v8/editor-v3 journals retain the pair through recovery;
  single-mesh journal formats remain supported. Test preview, Apply, cancellation,
  timeout, recovery, malformed records, target/presence changes and FName checks.
  Skin writes remain disabled: read-only compatibility capture now records its
  gameplay tags, scalar value/target and absent mesh slots for preservation work.
  Default fallback and the installed Dev Panel application are unchanged.
  The user confirmed all v0.2.36 tests passed; tattoo live verification is pending.
- Colors+Probe v0.2.36 distinguishes shared completed slot VMs from real
  traversal cycles. Deduplicate shared identities with unchanged tags; reject
  active-path back-edges and distinct VMs matching the displayed slot tag.
  Preserve depth/node/child, game-instance, palette and mutation guards. Log
  unique/shared counts on successful retargeting and the node on loop refusal.
  Tests cover diamond/repeated references, order independence, self/longer
  cycles, tag changes, limits and shared-slot picker/compatibility integration.
  v0.2.35 lipstick passed live; hair root refused at cycle/alias before writes.
  Whether that live reference is a harmless alias remains to be verified.
- Colors+Probe v0.2.35 resolves a simple panel's displayed color slot when the
  auxiliary selection remains on its parent Style. Use CurrentSlotTag from the
  active page's owned selection tiles, then match an exact slot in the explicit
  RootCustomizationSlotVM child tree. Require category membership for both VMs,
  matching game-instance/class, bounded acyclic traversal and equipped palette
  membership. Recheck the palette before returning; no global VM scan, guessed
  child index, auxiliary setter or new hook. Share resolution between regular
  picker targeting, Default selection coordination and read-only compatibility
  capture. Combined/list panels retain exact-tag matching. Keep single-fragment
  and single-mesh mutation guards unchanged. Add stale-Style hair/lipstick
  preview/restore and compatibility regressions plus resolver refusal tests.
  Automated checks pass; focused in-game verification remains pending.
- Colors+Probe v0.2.34 fixes registration after a Dev Panel reinstall removes
  registry.txt. The local helper checks for the installed panel entry script
  before creating a missing registry in append mode. Preserve other entries,
  avoid duplicates, distinguish missing files from read failures, and report
  write/flush/close errors without starting the client poll. Tests cover fresh
  registration and action delivery, absent panel, existing registrations and
  I/O failures. No changes to the separately installed Dev Panel application.
- Colors+Probe v0.2.33 refreshes the Dev Panel catalog: separate Picker and
  Diagnostics groups; add Apply, Cancel, compatibility capture and screen-trace
  Start/Stop. Remove superseded cyan/handoff/RGB-cycle buttons and outdated
  Clone 8-only descriptions. Keep eye experiments console-only; eye texture
  customization is deferred to a separate mod. Keep existing picker semantics
  and Dev Panel screen-transition behavior. Cancel queued writes on Cancel,
  Restore, stock capture and page exit; recheck exclusions at execution time.
  Stop actions cancel queued starts. Read-only compatibility/screen actions
  remain available when tint initialization is disabled. Add bridge/catalog
  regression tests. User verified v0.2.32 scalar effects and restoration on
  Light Brown and Rodian Star Blue; no arbitrary eye RGB claim.
- Colors+Probe v0.2.32 adds `colors_eyes texture`: opt-in display-only scalar
  pulses for Light Brown and Rodian Star Blue. Test IrisSaturation=0, restore,
  IrisBrightness=25% of its original value, restore (5 seconds per stage).
  Require the exact captured asset/parent pair and explicit scalar overrides;
  preserve all textures, masks, shader switches, source data and saves. Reuse
  eye ownership, CP exclusion, 20-second timeout, context cancellation and
  compare-before-restore guards. Add strictly typed eye-scalar-v1 journal
  recovery alongside unchanged eye-v1 vector recovery. Cover scalar failures,
  wrong/missing targets, malformed records, case folding, shared Rodian slot,
  external changes and restoration with mocked native calls. Live visual
  verification remains pending; arbitrary texture-based RGB is not implemented.
  v0.2.31 live capture confirmed readable switches: Color TEX/GEN false on
  Light Brown, true on Dark Brass; no recorded switches on Albino/Star Blue.
- Colors+Probe v0.2.31 extends the read-only `colors_compat` eye material survey
  with runtime static switch names, association/index, values and override flags
  on loaded replacement/parent instances. Preserve false and non-overridden
  entries; distinguish missing/malformed data from empty arrays. Cap switch
  rows independently at 32 per material / 64 per swap without reducing existing
  scalar/texture evidence. No new hooks, setters, loads or shader recompilation.
  Add missing/false/inherited-field/malformed-row/budget tests. Document confirmed
  Dark Brass/Albino effects, Light Brown/Rodian Star Blue no-effect results, and
  the four-preset recapture. Require a fresh restart while the post-reload
  navigation crash remains unresolved. Live switch-field readability is pending.
- Colors+Probe v0.2.30 corrects the eye probe's case-sensitive FName round-trip
  guard. Share a narrow ASCII eye slot/parameter whitelist across discovery,
  vector reads/writes and recovery; accept case-only differences, pass the actual
  FName to native calls, and log requested/returned values on genuine mismatches.
  Normalize only known reflected slot/parameter names; keep UObject identities,
  material parents, ownership and journal format unchanged. Add case-preserving
  object mocks, normalized-name cycle/reload tests and wrong/None/suffix guards.
  v0.2.29 logs confirm eyebrow Apply/Restore/reopen; eye testing stopped before
  writes at the round-trip guard. Case normalization is the suspected cause,
  not yet confirmed by live returned-name evidence. Retest Dark Brass first.
- Colors+Probe v0.2.29 verifies and resets the selected slot's stock hover before
  the generic donor handoff; inactive stale proxy colors no longer block opening
  after a verified equipped display baseline. Unrelated/ambiguous hovers still
  refuse. Add `colors_eyes [start|stop]`: a separate 20-second display-only MID
  parameter cycle (iris 1 cyan, baseline, iris 2 magenta, baseline; 5s each).
  Explicit eye swap parameters, exact parent/mesh ownership, native source and
  display agreement, shared-slot alias guards, CP exclusion, context cancellation
  and process-authorized atomic recovery protect the experiment. Support explicit
  IrisColor1/2, Rodian MI_Eyes targets and Albino CloudyIrisColor; do not edit
  source fragments, shared assets or save data. Expand special-eye scalar survey
  within its existing total bound. Add lifecycle/failure/recovery/target tests,
  eyebrow active/stale hover cases and updated test instructions. Live tests pending.
- Colors+Probe v0.2.28 replaces global palette/parent-chain discovery with exact
  active-page -> SlotWidgetSwitcher.GetActiveWidget -> verified panel reference
  -> owned selection tiles / combined CustomizationSlots / SlotList.SlotStack.
  Bounded, whitelisted child traversal excludes inactive panels without requiring
  UUserWidget parent links. Missing links, transitions, duplicate matches and
  stale/mismatched palette VMs still refuse; log root/routes/selected grid.
  Expand read-only nested material-swap inspection: target material slots/mesh
  tags, loaded replacement identity, up to four material-instance levels, and
  vector/scalar/texture overrides with name/association/index. No soft loads,
  guessed getters, material setters or eye write support. Tests cover all panel
  modes, stale palettes, absent page links, traversal bounds, transitions, eye
  chains, missing assets and nested survey integration. v0.2.27 logs confirm
  successful Eye Shadow Apply and console Restore; subsequent appearance failures
  were palette ambiguity, not a retained recovery journal. Eyes contain hidden
  left/right slots with material swaps. See `docs/appearance-palette-testing.md`.
- Colors+Probe v0.2.27 generalizes the picker to discovered, single-fragment,
  opaque, single-mesh color zones. Record the actual slot tag, parameter, mesh
  tag and equipped mesh asset in preview (`proxy-v7`), Apply (`editor-v2`) and
  outfit-Default (`selection-v2`) recovery; retain legacy recovery readers.
  Select an alternative non-Default swatch from the verified palette, measure
  and verify its preview/display RGB, and persist that baseline before any
  custom-color write. Interrupted activation restores through the recorded slot
  VM without guessing a donor RGB. Prefer palettes attached to the active page
  over stale visible widgets; refuse unresolved ambiguity. Keep one applied zone
  at a time. `colors_compat` now walks bounded nested slot fragments and logs
  UI visibility plus underlying color targets for eye research. No nested or
  multi-mesh writes, new save/discard hooks, saved-swatch library, or DP changes.
  Offline tests cover dynamic armor/hair/makeup targets, donor measurement,
  failure rollback, dynamic Apply/Default/reload, palette ambiguity and nested
  cycles. Live verification remains pending; see `docs/dynamic-color-testing.md`.
- Colors+Probe v0.2.26 adds `colors_compat`, a one-shot read-only survey of any
  selected color slot in the verified creator stack. Record dynamic slot tags,
  fragment classes/owners/RGBA, material parameters, mesh targets/parts and
  visible-palette membership. Bound scans, expose diagnostic gaps and refuse
  active/applied picker sessions. No new write support or recovery changes yet;
  the live survey will inform removal of the hardcoded target/Blue_14 assumptions.
  v0.2.25's clean-baseline Apply/navigation/Cancel/exit test passed; user-observed
  saved RGB also survived a fresh process without mod reapplication.
- Colors+Probe v0.2.24 adds `colors_screens [start|stop]`, a read-only navigation
  trace independent of CP/DP and tint recovery. Sample known creator pages and
  native widget stacks on owned game-thread jobs for 60 one-second samples;
  record changes, active stack screens, membership, activation and attachment.
  Bound scans, report omitted/unreadable candidates, skip template identities,
  retain only text between samples, and cancel pending jobs on stop/reload.
  v0.2.23 found a matching master that was inactive and unattached during editing;
  the next test discovers the actual active screens without weakening Apply.
- Colors+Probe v0.2.23 adds bounded, failure-only creator-candidate diagnostics
  for the v0.2.22 Apply regression. Log the item page/layout, candidate names and
  layout matches, viewport/parent attachment, activation and candidate counts.
  Read errors remain visible; logger failures cannot prevent rollback. No new
  hooks, polling or relaxed binding rules. Tests cover absent/mismatched/detached
  candidates, diagnostic failures/limits and stock/Default rollback before source
  writes. This is an evidence-gathering build, not a fix for Apply.
- Colors+Probe v0.2.21 adds **Apply (session)** plus `colors_picker apply` and
  `colors_picker restore`. Apply ends the hover preview and changes only the
  verified character-owned Clone 8 accent fragment, retaining an independent
  write-ahead recovery record. Reopening starts at the last applied RGB;
  Cancel/edit timeout retain it. Slot selection does not itself discard Apply;
  editor exit/Restore returns to the pre-Apply color or Default. Later stock
  changes win. Source/display verification failures roll back or retain blocked,
  retryable recovery. No save integration; do not save this experiment.
  Add ownership, rollback, recovery, UI/console, and real tint/handoff/Default
  integration tests. Native Apply/display propagation still needs live testing;
  see `docs/editor-session-testing.md`. The DP reload issue remains deferred.
- Colors+Probe v0.2.20 adds `colors_picker [open|close]` in the in-game
  console, independent of the Dev Panel UI. Reuse the existing picker checks,
  owned game-thread dispatch and navigation cancellation; close supersedes a
  queued open. Add command and same-state reload regression coverage. No saving
  or native Reload All Mods crash fix is included.

### Fixed

- Colors+Probe v0.2.25 replaces the creator-screen attachment assumption with
  exact `GameLayer_Stack` membership, using the v0.2.24 live navigation trace.
  Initial Apply requires the active item page immediately above one same-layout
  creator; the watcher accepts that creator or its immediate item page as the
  active top. Creator removal/replacement, lost stack, ambiguity and unreadable
  membership fail closed. Keep existing bounded transition grace, source ownership,
  later-stock-edit precedence and journaled rollback. Store only scalar stack and
  creator identities; no recovery-format or DP changes. Add observed parentless
  screen fixtures and removal/replacement/round-trip/Default regressions. Live
  Apply and navigation confirmation is still required.
- Colors+Probe v0.2.22 separates closing the customization item page from leaving
  the full creator. Cancel an open picker draft on item-page exit but retain
  Apply through the radial selector and reopened item pages. Bind to the exact
  attached `WBP_CustomCharacter_Master` in the same layout; allow master/child
  activation handoffs and two inactive watcher polls. Restore on creator
  CloseMenu, cleared customization data, detached/lost creator, or sustained
  inactivity. Keep character/armor/fragment and later-stock-edit protections.
  Add lifecycle and boundary regression tests. v0.2.21 Apply/hover/stock selection
  passed live; its radial-selector reset was our `page closed` rollback, not
  lost RGB. The v0.2.22 live test subsequently failed before Apply with
  `No attached creator for item page`; v0.2.23 instruments this unresolved guard.
- Colors+Probe v0.2.19 gates all tint recovery behind a UE4SS shared-string
  process marker and disk provenance stamp. Same-process reload retains
  recovery for normal validation; fresh-process records are archived without
  touching UObjects. Unstamped/in-process conflicts are quarantined and held
  until game restart; missing APIs, corrupt metadata and I/O failures disable
  tint writes. Add independent-file-first startup/teardown, delayed-job and
  hook-registration checkpoints, alongside DP v0.2.3 diagnostic checkpoints.
  Archive the stale record from the September 16 reload hang (recoverable in
  `debug/reload-hang-20260916`). The hang itself is not yet fixed or reproduced
  locally; see `docs/reload-hang-testing.md` for the staged live test.
- Colors+Probe v0.2.18 replaces new Default-picker attempts with a temporary
  editor-swatch selection. Read the ordered Primary Accent palette, journal
  Default before equipping its first non-Default entry, and use the regular RGB
  backend. Restore RGB/display handoff first, then explicitly equip Default;
  include open failure, timeout, page/slot exit and reload. Preserve a later
  stock choice and refuse stale/ambiguous recovery targets. A separate
  `selection-v1` journal retains the selection obligation after RGB cleanup.
  Old `default-v1/v2` records remain recoverable. No save APIs or DP changes.
  Add standalone failure/recovery tests and integration coverage through the
  actual regular tint/handoff modules. This path still needs in-game validation.
- Colors+Probe v0.2.17 removes Default discovery's dependency on the invalid
  auxiliary root VM. Traverse the selected character VM's bounded slot tree,
  require the exact selected accent and one Clone 8 torso Style slot, and verify
  Style fragment owner/slot identities before preview activation. Revalidate
  those scalar identities during updates and recovery. Journal the tree/Style
  association in `default-v2`, retaining read compatibility with `default-v1`.
  Add regression coverage for invalid/nil auxiliary roots, missing/cyclic/mixed
  associations, context changes, cancellation, timeout and reload. Dev Panel
  remains v0.2.2; its menu persistence and picker re-entry passed the user's test.
- Colors+Probe v0.2.16 adds an isolated live-picker backend for Default's empty
  accent slot. Bind the source through the selected auxiliary VM's root, activate
  verified Blue_14, require the native setter to produce a distinct preview copy,
  and tint only that copy. Journal Default absence and each mutation phase in
  `default-v1`; Cancel/timeout/reload reset the stock preview without equipping
  or assigning an invented default RGB. Existing proxy-v1–v6 behavior is unchanged.
  Support is initially limited to the live picker, not the older cyan/RGB-cycle actions.
  Pair with SWZC Dev Panel v0.2.2 persistent menu navigation and held-click guards.
- Colors+Probe v0.2.15 closes its picker immediately on customization page exit,
  resolves retained widget identities before use, and scans leftover roots only
  once per runtime. Add opening-stage checkpoints and guarantee a UI removal
  attempt even when tint restoration throws. Update the supplied Dev Panel client
  to owned game-thread polling/dispatch with replacement and shutdown guards.
  Coordinate with SWZC Dev Panel v0.2.1 navigation/reload hardening; see
  `docs/ui-lifecycle-review.md`. Native crash resolution remains unverified in-game.
- Colors+Probe v0.2.8 follows the matched container's exact display-actor reference
  across levels for read-only diagnostics. Retain main-menu source/data/container
  restrictions, verify display-instance ownership and prioritize display captures
  within the existing material budget. Cover cross-level and stale/invalid links;
  no tint mutation or refresh behavior changes.
- Colors+Probe v0.2.6 retains cyan across redundant slot-update notifications
  only after revalidating the live context against scalar apply-time identities.
  It never extends the 15-second timer. Other events still restore, with a
  latched reason so later coalesced slot updates cannot suppress cleanup.
  Tests cover duplicate notifications, changed/unreadable context, event ordering,
  stale callbacks, and reload recovery without a live baseline.
- Colors+Probe v0.2.5 validates and tracks the actual installed copy immediately
  after SetFragmentInstances, persisting its identity before explicit refresh.
  Restore verifies the live slot after refresh. Untracked non-original fragments
  now retain recovery and block further applies instead of claiming cleanup.
  Add phase-marked recovery and tests using the observed copying-setter behavior.
- Colors+Probe v0.2.3 removes metatable inspection from the constructor gate:
  UE4SS hides it with `__metatable=false`. Inspect/apply now verify actual FName
  construction and the recovery slot lookup on the game thread before cloning
  or color writes. Tests cover protected metatables, constructor failures,
  round-trip/lookup refusal, and recovery retention if the constructor fails.
- Colors+Probe v0.2.2 accepts UE4SS's callable-userdata `FName` constructor
  shape, but its metatable gate still disabled the live tint module (see v0.2.3).
  Reports exact missing APIs at startup
  and on panel actions; regression tests now exercise the actual bootstrap and
  restoration with callable userdata rather than only function mocks.
- Colors+Probe v0.2.1 now uses the existing linked customization proxy instead
  of rejecting it. Restores only the probe clone's original color, preserves
  the game proxy, and checks for replaced fragments or external edits.
- Unwrap type-identified parameter wrappers inside returned Lua arrays, matching
  the installed UE4SS array/object property pushers. Log entry types and validity
  errors, and report unknown totals for unreadable entries or truncated arrays.
- Read the Lua tables actually returned by `GetFragments()` without calling
  `ForEach` or unwrapping their UObject values; retain the Unreal array path.
  Cover both array formats, unexpected table shapes, and bounded inspection.
- Preserve fragment-call, array-iteration, and color-read errors in the probe,
  including return types and visited counts, instead of swallowing their cause.
- Report unreadable fragment color counts as unavailable rather than zero;
  add diagnostic regression coverage and the next in-game capture checklist.

### Added

- Colors+Probe v0.2.14 prototype live RGB picker, opened by a Dev Panel action.
  Own a separate stock UMG window with three sRGB sliders, numeric/hex readout,
  a swatch, orange/violet/green presets and Cancel/Restore. Poll on the owned
  game-thread scheduler and coalesce writes to approximately 5 Hz. Reuse the
  tested in-place transition and v5/v6 recovery; fixed two-minute safety timeout,
  source/context checks, no equip/save or input-mode/cursor writes. Clean only
  probe-owned native UI roots after reload; do not resume live sessions.
  Add UMG-view/controller tests and backend live-lifetime regression coverage.
- Colors+Probe v0.2.13 one-shot custom RGB cycle: configured rgb.txt color,
  violet and green for five seconds each, then restore. Update the same tracked
  installed fragment in place; verify source, context, ownership and live color
  around every change and the display after 750 ms. Cancel on restore/context
  failure; guard stale callbacks with session, step and color revision identities.
  Keep an independent 20-second watchdog. Add transitional proxy-v6 recovery
  containing both previous and next RGB, persisted before writing; cold reload
  restores either accepted color without resuming the cycle. Preserve v1–v5.
- Colors+Probe v0.2.12 configurable RGB preview through the proven blue handoff.
  Read three integer 0–255 sRGB channels from DevPanel/rgb.txt per click, convert
  to linear RGB, and retain opaque alpha. Verify/restore the actual target
  instead of assuming cyan. Persist that target in a fourteen-line proxy-v5
  journal; preserve v1–v4 compatibility and reject malformed targets.
  Add parser/conversion, multiple-color, context, timeout, reload, reset-failure,
  stale-callback and input-isolation regression tests. No picker UI or saving yet.
- Colors+Probe v0.2.11 separate blue-swatch cyan action through the observed
  SlotVM.PreviewCustomizationPart entry point. Resolve one cached Blue_14 VM
  in the selected slot's game instance; verify blue data/display and unchanged
  equipped source before cloning cyan. Restore the distinct blue baseline before
  SlotVM.ResetPreviewedPart; no native-owner fallback or equip/save calls.
  Add thirteen-line proxy-v4 recovery with separate source and preview baselines,
  strict blue asset/color/slot validation, and backward-compatible v1/v2/v3 reads.
  Cover success, failed activation, cache ambiguity, alpha refusal, copied
  fragments, reload recovery, invalid journals, reset retries and displaced hovers.
- Colors+Probe v0.2.10 opt-in read-only stock-hover call timeline. Capture native
  pre/post arguments, Blueprint post callbacks and the existing slot-VM preview
  argument, scoped to the armed character/container/display. Reacquire link and
  fragment state at coalesced 50/250/1000 ms checkpoints; retain scalar state only.
  Report missing hooks, bound events/samples/window and cancel on page close or
  reload. Block panel cyan actions while the stock trace is armed. Add native
  pre-callback support to the owned hook registry and regression coverage.
- Colors+Probe v0.2.9 separate stock-hover cyan action. Journal handoff intent,
  preview the equipped stock swatch, require the display to follow the linked
  data actor, then use the existing cloned-fragment cyan test. Verify display
  color after 750 ms; restore color before resetting an owned handoff, validating
  the restored display link and fragment. Retain recovery on reset/verification
  failures and leave displaced game previews alone. Add ten-line proxy-v3
  recovery while preserving v1/v2 and the old data-only action. No direct flag,
  material, equip, actor-clone or save calls.
- Colors+Probe v0.2.7 opt-in, read-only material trace: follow the matched preview
  container from ProxyDataStorage to ProxyCharacter, compare fragment and
  Color 01/Color 02 material values, slots, visibility hints and parent overrides.
  Capture stock UI changes and cyan/restore boundaries for at most 60 seconds or
  20 captures, with bounded enumeration and no retained Unreal objects.
  Add mock coverage for actor linkage, slot indices, read failures, read-only
  enforcement, limits, stale callbacks and optional-trace failure isolation.
- Colors+Probe v0.2.4 per-field checkpoints after fragment installation and
  preview refresh, with reacquired live preview/slot identities and equipped
  source auditing even on mismatch. Stop before explicit refresh if installation
  verification fails. Cover no-op setters, refresh replacement/color reset,
  replaced slots, unreadable fragments, and target-change rollback safeguards.
- Colors+Probe v0.2.0 SWZC Dev Panel actions for target inspection, a 15-second
  cloned-fragment cyan accent preview, and restoration. Includes strict Clone 8
  targeting, original-fragment readback, rollback/recovery, and mocked tests.
- Unchanged optional Dev Panel client helper and data-only action manifest;
  game-thread action routing, ignored runtime state, and a live test checklist.
- Initial UE4SS and ZCOM Mod Manager-compatible repository scaffold.
- Hot-reload-safe Lua bootstrap and local bootstrap regression test.
- Research notes for the armor tint-zone color-picker prototype.
- Separate Colors+Probe development mod with read-only slot/part/fragment
  snapshots, linear RGBA and material-target logging, and a `colors_probe`
  console command.
- Owned hooks and delayed actions, session cancellation, reload cleanup, and
  regression tests covering late-loaded functions and invalid objects.
