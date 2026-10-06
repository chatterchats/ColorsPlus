# Clone 8 accent preview — SWZC Dev Panel

Historical experiments only: several buttons below were removed in v0.2.33.
Use [current Dev Panel controls](dev-panel-controls.md) for today's menu and
restart instructions, not the old Reload All Mods steps below.

This documents the earlier regular-swatch experiments. The picker introduced
in `live-picker-testing.md` v0.2.18 temporarily equips a stock swatch when
opening from Default, then explicitly re-equips Default on cleanup. The no-equip
statements below describe the older preview actions, not that new fallback.

## Status

Implemented in **Colors+Probe v0.2.14**, linked directly to the game's Mods
folder. The main Colors+ mod is unchanged. SWZC Dev Panel is already installed
locally; its source and installed files were not changed. The mod uses the
supplied client helper unchanged, plus its own data-only action manifest.

Local mock tests pass. In-game inspection, installed-copy tracking, post-refresh
cyan readback and restoration readback have succeeded. Visible cyan and return
to red were confirmed with v0.2.11. v0.2.8 captured cyan in the hidden preview material but red
on the display actor. v0.2.9 refused the handoff before cyan. The v0.2.10 timeline
captured a working Blue_14 stock hover through the slot view model, unlike a
hover of the equipped red swatch. v0.2.11's blue-first action succeeded.
v0.2.12 confirmed visible orange from arbitrary RGB input and return to red.
v0.2.13 confirmed all three colors in the five-second cycle and restoration.
v0.2.14 adds the interactive picker prototype; earlier probes remain available.

The first in-game write attempt was refused before writing: the main character
already links to `BP_CustomizationPreviewProxyCharacter_C_4.CustomizationInstance`.
The original test incorrectly treated any existing preview as a conflict.
v0.2.1 uses that linked proxy after validating its armor, swatch, fragment
ownership, color, and target against the equipped character. It does not call
`PreviewPart` or `ResetPreview` and does not destroy or replace the game proxy.

The v0.2.1 retest at 13:18:27/29 UTC on September 15 never reached inspection
or mutation: both actions logged `TINT | Disabled`. Its new API gate required
`type(FName) == "function"`, but the installed UE4SS revision registers a
callable userdata constructor. This is confirmed by the revision's
[global registration](https://github.com/UE4SS-RE/RE-UE4SS/blob/a1e7f571/UE4SS/src/Mod/LuaMod.cpp)
and [FName __call implementation](https://github.com/UE4SS-RE/RE-UE4SS/blob/a1e7f571/UE4SS/src/LuaType/LuaFName.cpp).
v0.2.2 attempted to validate callability without invoking Unreal during startup,
but the 13:24 UTC retest was still disabled: the constructor was userdata and
its callable metatable was not exposed. The installed revision's
[LuaMadeSimple binding](https://github.com/UE4SS-RE/RE-UE4SS/blob/a1e7f571/deps/first/LuaMadeSimple/src/LuaMadeSimple.cpp)
explicitly sets `__metatable=false`. No color write was reached in that test.

v0.2.3 checks only constructor presence/type at startup. Inspect/apply actually
call `FName(ACCENT)` inside protected game-thread work, verify its text equals
the accent tag, and confirm the reconstructed recovery tag resolves to the
same preview slot. These checks precede cloning, recovery writes, and color
writes. Restore uses the same checked constructor helper. No metatable access
or attempt to bypass the binding's protection is required.

At 13:28:08 UTC on September 15, v0.2.3 inspection passed for Clone 8 Primary
Accent and the linked `_C_9` proxy. At 13:28:09, a cyan attempt passed clone
SetColor/readback, then failed the combined post-install/refresh verification.
Rollback reported the clone/swatches already replaced and cleared its recovery
record. That log cannot distinguish a setter problem from a refresh rebuild.

v0.2.4 adds `after-install` and `after-refresh` checkpoints. Both reacquire the
linked preview and accent slot, log actual field values and individual matches,
and audit the equipped source even if the proxy fails verification. The test
stops before explicit refresh if the installation checkpoint fails. It still
never changes the equipped source, clears the game preview, or skips refresh
as a workaround to force a visible result.

The v0.2.4 captures at 13:37:53 and 13:39:52 UTC on September 15 both show a
different fragment after SetFragmentInstances, but matching cyan RGBA, target,
owner, slot, swatch and unchanged equipped source. Only identity failed, before
explicit refresh. This is consistent with the setter copying its input; the
generated native CPP body is a stub, not evidence of its implementation.
The old rollback then incorrectly discarded recovery while leaving that copy
cyan in the transient slot. Restart without saving is required to clear those
untracked old tests before trying this update.

v0.2.5 accepts an installed copy only at the immediate post-setter checkpoint,
after every other validation passes. It must belong to the same preview and
accent slot, retain the exact target and cyan/alpha, and not be the previous
stock fragment or equipped source. The installed identity is persisted before
explicit refresh. Later replacement identities are not automatically adopted.
Restoration verifies the current live slot after refresh, not a detached object.

At 13:51:29 UTC on September 15, v0.2.5 passed both checkpoints and logged
`PREVIEW APPLIED`. At 13:51:32 it restored in response to
`UpdateCurrentCustomizationSlotVM`, not the 15-second timer. The following
snapshot still showed Primary Accent, Saturated Red 1, and the same equipped
fragment. Live restoration readback succeeded and the recovery file was empty.
This early cleanup limits the visual test; it does not prove cyan ever reached
the visible armor material.

v0.2.6 compares live state for that one potentially redundant slot notification.
The same page, slot view model, character, swatch, source fragment/slot/color/
target, linked preview, installed cyan fragment/owner/slot and armor must still
match. Otherwise it restores using the existing ownership safeguards. The
baseline contains only scalar identities, is not persisted, and cannot prolong
a recovered session. No new hooks or engine APIs are introduced.

## What to test now

**Current checkpoint: [v0.2.14 live RGB picker](live-picker-testing.md).**
Use Open live RGB picker, drag the sliders and test Cancel/Restore. The cycle
instructions below are retained as a diagnostic fallback, not the current test.

### Previous checkpoint: five-second RGB cycle
See [RGB configuration and recovery](arbitrary-rgb-testing.md) and
[the confirmed blue-first handoff](blue-first-handoff.md).
The v0.2.6 run at 13:58:37–13:58:52 UTC on September 15 passed installation and
refresh checks, then restored on the 15-second timeout with an empty recovery
file. This removes early restoration as the explanation for that run.

The reference Blueprint types distinguish the container's data-side
ProxyDataStorage from its ProxyCharacter. The trace follows this link only
when the data actor matches the equipped character's linked preview. It compares
that display candidate with the equipped actor and data preview. The link is a
hypothesis about the visible preview, not yet runtime proof of screen ownership.
The v0.2.7 capture at 14:17:17 UTC confirmed cyan in both the hidden data actor's
accent fragment and its torso material Color 02 getter/override. The container
linked a Hawks display proxy in a separate customization level, which the
main-menu-only trace filter excluded. Stock hover toggled IsPreviewing true;
the cyan attempt left it false. Restore succeeded at 14:17:32 UTC.
v0.2.8 follows that exact linked actor across levels, reads it first, and keeps
all tint mutation safeguards unchanged. See [trace details](material-trace-testing.md).

At 14:25:12 UTC, v0.2.8 stock blue hovering set IsPreviewing=true, switched the
display's ClonedFromCharacter to the data actor, and produced blue in its fragment
and torso material. At 14:25:26–28, cyan appeared only on the data actor:
IsPreviewing=false, display still following the equipped character, display
fragment/material still red. Restore succeeded at 14:25:41 with empty recovery.
The new action uses native PreviewPart/ResetPreview, not manual flag edits or
guessed Blueprint event calls. See [handoff design and recovery](stock-preview-handoff.md).

v0.2.9 attempts at 14:39:56 and 14:44:35 UTC passed baseline validation but
PreviewPart of the equipped swatch did not satisfy the immediate display-link
check. Both stopped before cyan and rolled back; recovery was empty. The later
snapshots followed rollback, so they cannot exclude an asynchronous handoff.
The new [stock-hover timeline](stock-hover-call-trace.md) observes natural game
calls without invoking preview/reset or writing color.

1. **Reload All Mods**, or restart without saving. The successful orange test
   restored red and left no pending tint recovery.
   Open the same main-menu character customization.
2. Equip **Tops → Clone 8**, choose **Primary Accent**, and select a stock red
   swatch so a custom color change will be obvious. Move the pointer away from swatches.
3. Press **F6**. Use **Refresh** if **Colors+ Probe** is not listed.
4. Run **Trace materials (60 seconds)**. Do not arm the stock-hover trace;
   it blocks cyan actions while recording.
5. Run **Preview custom RGB (5s/color)** once. It uses the configured orange
   (255, 128, 32), then violet (160, 64, 224), then green (64, 208, 112).
   Do not use one of the older cyan buttons for this run.
6. Close F6, keep the pointer off swatches, and watch for about 15 seconds:
   orange for five seconds, violet for five, green for five, then equipped red.
7. Report whether all three colors appeared and whether red returned automatically.
   Blue may appear only briefly because its verification precedes custom RGB in the
   same game-thread action. Not seeing a blue flash does not prove failure.

This test invokes the stock Blue_14 hover without equipping it. Both the hidden
data preview and linked display must verify blue before any custom color write.
It updates that same installed fragment in place for each cycle step, then
restores the test color to blue and resets back to the equipped source.
If a required identity, color or link is wrong, the test stops and logs why.

Do not accept/save a character or reload mods while the first live test is
showing a test color. Use Restore first. Reload recovery is implemented as a fallback,
but is not the initial validation target. On a crash or restore failure, stop
and report it; leave/reopen customization or restart without saving.

## Controls and logs

- **Open live RGB picker**: current UI test; three sRGB sliders, readout,
  presets, Cancel/Restore and a fixed two-minute safety timeout.
- **Trace stock hover calls (60 seconds)**: read-only native/Blueprint argument
  timeline, with delayed link and fragment readback.
- **Stop stock hover trace**: stops that timeline and its scheduled checks.
- **Preview custom RGB (5s/color)**: current test; reads the first color from
  DevPanel/rgb.txt, then cycles through violet and green using the same preview.
- **Preview cyan via blue swatch (15 seconds)**: successful cyan control; activates
  stock Blue_14 through the selected slot VM, verifies blue, then tests cyan.
- **Trace materials (60 seconds)**: arms bounded read-only snapshots.
- **Stop material trace**: stops diagnostics only, not the cyan experiment.
- **Inspect tint target**: read-only validation and original linear RGBA.
- **Preview cyan via stock hover (15 seconds)**: earlier native-preview handoff plus
  cyan, with link/color verification and owned reset on cleanup.
- **Preview cyan (15 seconds)**: opt-in temporary color change; it is not an
  equip, save, default-setting, or custom-swatch operation.
- **Restore original appearance**: restores the original RGBA on the probe's
  tracked installed accent fragment. For the new handoff action, also resets
  the owned stock preview and verifies the display returns to the equipped source.

`colors_plus_probe.log` and `UE4SS.log` include `TINT |` messages. Expected
markers include `Target verified`, `PREVIEW APPLIED`, `source unchanged`, and
`Restored owned clone color; game preview retained`. API return/readback success is not visual proof.
Startup should log `Loaded v0.2.14` and `TINT | API presence checks passed | FName=userdata`.
This is not proof of a working constructor: the action must also log
`Recovery lookup verified | FName round-trip and proxy slot match`.
`APPLY REFUSED/FAILED` and `RESTORE FAILED` retain the specific exception.

`EXPECT` identifies the clone, previous fragment, expected proxy/slot/swatch,
materials and equipped source. `CLONE COLOR VERIFIED` confirms cyan readback.
`CALL` identifies the setter/refresh boundary, followed by `CHECKPOINT
after-install` or `CHECKPOINT after-refresh`. Each stage logs live proxy/slot,
part, fragment count/name/class/owner, parameter, slot tags, materials, RGBA,
owning fragment slot, and source fragment/RGBA, then match flags and `passed`.
Read failures include the field and exception; other fields still get logged.
An installation mismatch is not evidence that explicit refresh caused it.
`INSTALLED FRAGMENT TRACKED` logs submitted versus installed names after
successful validation and persistence. The after-install fragment match allows
the verified copy; after-refresh identity must match the recorded installed one.

`CONTEXT UNCHANGED` means the slot-update notification was revalidated and the
preview retained without resetting/extending its timer. `CONTEXT CHANGED/UNVERIFIED`
includes the failed check before cleanup is attempted. Equip, hover, reset,
page-close and all other existing context events remain unconditional restore
triggers; their reason is latched so a later slot notification cannot replace
it in the coalesced queue. UI notifications are read only on the game thread.

The panel is optional. If absent, normal read diagnostics keep working. Its
250 ms file-counter polling starts only when registration succeeds. The helper
is reused on same-Lua-state reloads; actions also pass through the probe's owned
game-thread queue and stale-runtime guard. No additional F-key bindings exist.

## Safety boundary and implementation

The resolver requires one active item page and one live auxiliary context,
Primary Accent's exact torso tag, Clone 8's exact asset ID, and one valid
material-color fragment. It checks owning slot/instance, torso mesh target,
`Color 02`, readable material slots, and finite original RGBA. This first
experiment is restricted to the main-menu humanoid customization instance.

The old data-only action follows these checked steps. The new handoff action
additionally uses the [journaled activation/reset sequence](stock-preview-handoff.md).

1. Resolve the preview via the current character's `GetPreviewCustomizationInstance`;
   require the main-menu `BP_CustomizationPreviewProxyCharacter` and a distinct slot.
2. Require Clone 8 and the same equipped accent part on that proxy.
3. Require a distinct proxy color fragment with matching original color and target;
   refuse a different hovered swatch/armor instead of overwriting it.
4. `CloneFragments(preview_slot)`; require a distinct color fragment owned by
   that preview, with the original material target preserved.
5. Set only the clone to linear `{R=0, G=1, B=1, A=original.A}`.
6. Install clones only into the preview slot; verify the live slot and fragment
   plus the unchanged equipped source. Track and persist that installed fragment
   before refreshing the preview, even if the setter copied the submitted clone.
7. Reacquire and verify the same fields again after refresh.
8. Schedule a 15-second restore. Selection/equip/page-close events also request
   restoration, except events produced synchronously by the test itself and a
   slot-update notification whose complete live context is verified unchanged.

There is no fallback to editing the equipped fragment if any check fails.
`SetDefault...`, `EquipCustomizationPart`, and save APIs are never used by the
tint test. The unrelated Style-slot `Color 02` fragment is not selected.

The native headers define signatures, but their generated CPP bodies are stubs.
Runtime logs confirm proxy reads, cloning, cyan readback and installed-copy
color/target preservation, post-refresh cyan state and original-color restoration
readback. Visible tinting and rendered restoration remain unverified.
A failed check is not a reason to weaken isolation.

Restore reacquires the source instance and linked proxy by recorded names,
then checks the accent fragment identity, swatch ID, target and current color.
Only the tracked installed fragment is set back to its original RGBA and the
proxy refreshed. The current linked slot is reacquired and must contain the
original color/target with the expected owner and swatch before success is
logged. A newly rebuilt fragment that already has that original state requires
no further writes. The restored fragment may remain in the proxy's transient fragment
array; the original equipped fragment was never replaced. If another preview,
fragment, swatch or external color edit has superseded the test, it is left
alone. An unknown fragment in the same swatch is cleared from recovery only
when its original color, target and owner/slot can be verified; otherwise the
record stays pending and another apply is blocked. This prevents silently
discarding an untracked cyan copy after an interrupted/failed install.

`DevPanel/tint_recovery.txt` stores versioned plain data: instance/clone names,
swatch ID, material names and original RGBA, not Lua code or UObject wrappers.
The eight-line `proxy-v2` format adds `prepared`, `installing`, or `owned` phase.
Ten-line `proxy-v3` additionally records container/display identities and allows
a pre-cloning `handoff` phase. Native activation intent is durable before PreviewPart.
Installation intent is recorded before the setter; validated installed identity
is recorded before refresh. Seven-line `proxy-v1` records remain readable, but
no unknown cyan copy is adopted during reload/rollback. If tracking persistence
fails, the validated in-memory identity remains available for immediate rollback.
A new Lua runtime attempts cleanup on the game thread before
another apply. Successful cleanup empties the file. The file and the panel's
generated `state.lua` are ignored by git. Recovery is a best-effort fallback;
rendered restoration still needs testing.

## Local regression checks

```bash
rtk proxy luajit tests/bootstrap_test.lua src/Colors+/Scripts
rtk proxy luajit tests/probe_test.lua src/Colors+Probe/Scripts
rtk proxy luajit tests/tint_test.lua src/Colors+Probe/Scripts
rtk proxy luajit tests/dev_panel_client_test.lua src/Colors+Probe/Scripts
```

Coverage includes isolated clones, source/alpha/target preservation, wrong
context refusal, invalid objects, persistent proxies, hover mismatches,
file/clone/refresh/restore failures, rollback, timeout, context cancellation,
replacement/external-edit protection, recovery, optional panel
absence, counter baselines, default game-thread dispatch, and retired handlers.
Bootstrap coverage includes protected userdata/table/function constructor
candidates, missing constructors, exact disabled-action diagnostics, and no
Unreal constructor calls at startup. Action tests use protected callable
userdata returning protected FName-like userdata, refuse non-callable or
failing constructors and wrong round-trips/lookups before cloning/writing, and
retain recovery if constructor availability is lost during restoration.
Checkpoint tests cover no-op installation, fragment replacement at refresh,
same-fragment color reset, replacement of the live slot, fragment-read errors,
and target changes. They verify stage attribution, continued source diagnostics,
no explicit refresh after failed installation, and existing recovery protection.
The default setter fixture now copies the supplied fragment, matching the live
observations. Coverage includes direct installation, copied-fragment manual/
timeout/reload restoration, identity persistence failure, a setter that throws
after copying, unknown cyan after refresh, live-slot restore verification,
wrong owner/slot/class/target/alpha/source refusal, stock-object reuse refusal,
phase validation and backwards-compatible recovery parsing.
Context tests cover repeated notifications without color/recovery writes or
timer replacement, actual slot/swatch/armor/page/view-model/source/preview changes,
ambiguous or unreadable state, unconditional events in both queue orders, stale
callbacks, and recovered sessions lacking a live UI baseline.
