# Live RGB picker — probe v0.2.25 / optional Dev Panel v0.2.3

The v0.2.20 standalone stock/Default, editor-exit and timeout tests passed.
For the new **Apply (session)** button, use [editor-session-testing.md](editor-session-testing.md).
The preview-only checks below remain useful when you do not press Apply.

## Standalone console test (current)

1. Restart the game to load v0.2.25. Leave DP closed, or disable it before
   starting the game for a fully standalone test.
2. Open Clone 8 → Primary Accent with red equipped. Move off the stock swatches.
3. In the **in-game console**, enter `colors_picker`, then close the console.
   `colors_picker open` is equivalent. There is no new keybind.
4. Test sliders and Orange/Violet/Green. Enter `colors_picker close` to restore
   red, or use the picker's Cancel button. Reopening must produce only one picker.
5. Repeat from Default; cancellation must select Default again. Test changing
   slots, leaving/re-entering customization, and the two-minute timeout.
6. Close CP and DP before Reload All Mods. CP-only reload previously passed,
   but both-open reload crashed after bootstrap and before deferred recovery.
   Troubleshooting that development-only combination is deferred, not fixed.

The command uses the existing guarded picker and owned game-thread action;
it does not change save behavior. Invalid arguments print usage. Disabled tint
recovery reports its reason instead of opening the picker. DP is optional.

**Reload warning:** v0.2.18 passed Default opening, hover/page exit and timeout,
but Reload All Mods with CP open hung the game. Follow the staged procedure in
`reload-hang-testing.md` first. Active-preview reload steps below are deferred
until the closed-window baseline is verified. v0.2.19 adds recovery provenance
and startup logging, not a proven fix for the native hang.

## Current scope

A probe-owned stock UMG window, launched through F6 → Colors+ Probe →
Open live RGB picker. It uses a temporary editor selection for Default;
SWZC Dev Panel v0.2.3 adds startup diagnostics to the verified menu persistence.
The window sits on the left so the character remains visible on the right.
It contains three 0–255 sRGB sliders, numeric RGB and hex readout, a color swatch,
orange/violet/green presets, and Cancel / Restore original.

This is a first interaction prototype, not the final wheel/HSV design.
The hex field is a readout, not editable input. Alpha is fixed at 1. There is
now a session-only Apply button, but no Save button, custom swatch persistence,
or character-save integration. Cancel restores the last applied color, if any;
otherwise it restores the opening stock color/Default.
The initial preview comes from DevPanel/rgb.txt (orange by default).

## Test

1. Cancel any active preview, then **restart the game** for a clean test. Open
   Clone 8 → Primary Accent with red equipped,
   and move off the stock swatches. Ensure previous tint recovery is clear.
2. In F6, run Open live RGB picker. Close F6 to uncover the character; the
   Colors+ picker remains open independently.
3. Drag each RGB slider. Check the numeric/hex readout and swatch update, and
   the armor follows after a short delay (updates are capped at roughly 5 Hz).
4. Click Violet, Green and Orange; confirm the corresponding armor colors.
5. Click Cancel / Restore original. Confirm the window disappears and red returns.
6. Reopen once and confirm there is only one window. Optionally leave it open:
   its fixed two-minute safety timer should restore red and close the picker.
7. With both windows open, switch customization slots. The picker should still
   cancel. Then return to Databank: the shared panel should remain visible,
   briefly pause action polling and resume without changing the new menu's input.
8. Re-enter Clone 8 → Primary Accent, equip red, move off stock swatches, press
   open the picker from the still-visible panel. Try Orange and Cancel. Repeat this Databank round trip
   three times, including once while a picker preview is still active.
9. Close both windows before Reload All Mods; active-window reload testing is
   deferred following the confirmed both-open crash.

## Default/no-override test

Cancel any preview, then Reload All Mods (or restart). Confirm Colors+ Probe
v0.2.19 is loaded (fully restart for this upgrade). The installed mod is linked directly to this source tree.

1. Select **Default** on Clone 8 → Primary Accent, move off stock swatches,
   and run **Open live RGB picker** (not the old RGB-cycle action).
2. The first non-Default stock swatch should become equipped temporarily, then
   orange should appear. Try Violet/Green and the sliders.
3. Cancel. The original untinted/default appearance should return, and Default
   must be selected again. Repeat with the two-minute timeout, switching slots,
   and leaving/re-entering the page. Check both appearance and selected tile.
4. Test one regular red-swatch preview again to check the existing path.
5. Close the picker before Reload All Mods. Do not save this experiment.

The user clarified that swatch clicks change the editor's working state; they
persist to the character only when the editor is saved. This fallback therefore
uses `EquipCustomizationPart` twice: select a stock swatch, then restore the
recorded Default part. It is NOT strictly preview-only, but never calls save APIs.
`ResetPreviewedPart` alone would only return to the temporary stock color.

The first non-Default item comes from the ordered `PartsGridList` of one visible
`WBP_Customization_SelectionTiles_C` with the exact Primary Accent tag and the
equipped Default item. List size, order, asset type and game-instance identities
are checked before equip. Missing/ambiguous lists refuse without mutation.
If the first item is the reserved Blue_14 handoff donor, refuse rather than
silently choose a different item. The normal tint engine verifies Clone 8 and
fragment ownership after selection; failures roll back the editor selection.
Neither unavailable auxiliary root field is needed by this path.

`DevPanel/default_selection_recovery.txt` stores `selection-v1` intent before
equip, then records the verified source owner/slot. RGB recovery remains in
`tint_recovery.txt` (`proxy-v1`–`proxy-v6`). Internal RGB timeout, context and
failure cleanup also triggers Default restoration, not just the Cancel button.
On reload, restore RGB first, then Default; never resume an RGB session. A later
stock selection is left alone. If the exact old slot/owner cannot be verified,
keep recovery and block another preview rather than equip on a different character.
A reload during the narrow pre-owner-binding phase cannot guess an owner: manually
return the original slot to Default, then use Restore original appearance.
v0.2.19 requires matching process provenance before loading either journal.
Old-process records are archived rather than applied in a fresh game. See the
reload-hang notes for the fail-closed behavior of unrecognized records.

The previous `default-v1/v2` backend is retained for existing recovery records,
not new picker openings. Its v0.2.16/v0.2.17 ownership attempts failed on missing
`RootCustomizationSlotVM` and `CharacterCustomizationVM` respectively.

Markers: `DEFAULT SELECTION | CALL | EquipCustomizationPart | temporary=...`,
`LIVE START`, and `RESTORED | equipped Default; no accent override`. Successful
cleanup leaves both recovery files empty. `RELEASED` means a later stock choice
was preserved. `RESTORE FAILED` retains recovery: do not save the editor.

The panel stays open only while its owning controller and attached tree remain
valid. Actual world travel, controller replacement or lost widgets still close
it; reopen with F6. A held transition click must be released before an action fires.

Do not accept/save the character during this probe. If the UI is unresponsive,
F6 → Restore original appearance is the fallback. On a restore failure, do not
save; report the log and discard the editor changes if recovery cannot complete.

The picker needs the customization screen's existing visible cursor. It does
not change input mode, capture focus, hide/show the cursor, or bind new keys.
F6 controls only the shared Dev Panel; Cancel closes the picker. Moving over a
stock swatch, selecting another slot, or leaving the customization page can end
the test through the existing context safeguards.

## Implementation and checks

The view follows the local Dev Panel's demonstrated UserWidget/WidgetTree/
CanvasPanel construction pattern. The find-docs lookup verified the UE4SS
[StaticConstructObject signature](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/staticconstructobject.md)
and [game-thread dispatch](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/executeingamethread.md).
Slider calls are documented on Epic's
[USlider API](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/UMG/Components/USlider?application_version=5.5).
That public page is 5.5; the installed game is 5.6.1, so these calls and layout
still require the first live UI validation. Widget failures close/restore rather
than bypass the tint guards.

UI polling uses owned, game-thread-only 33 ms jobs. Latest RGB wins, with at
most one armor update per six polls. Numeric/readout changes need not wait for
the armor write. A full source/context check also runs every fifteen polls.
Cancel is checked before pending color input. Button press edges are polled;
very brief clicks can be missed, so retry or use the Dev Panel restore fallback
if necessary. The fixed 120-second timeout is not extended by slider changes.

The tint engine uses the proven blue-first handoff once, then updates the same
owned installed fragment. Each write validates context, journals previous/next
colors in v6, writes/refreshes/verifies, returns to v5, and schedules a display
check 750 ms after the last change. Older settled checks cannot affect a newer
color. RGB writes still target only the owned preview fragment, never stock
fragment colors or material assets. The Default adapter additionally changes
the editor's equipped part temporarily; it does not modify default definitions.

Restore invalidates live state even if cleanup fails, so a pending journal
cannot keep driving UI writes. Reload recovery restores instead of resuming.
Startup removes only native UserWidget roots with the ColorsPlusPicker_Root
prefix and numeric suffix; failed removal preserves identity and blocks duplicate
creation. Widget wrappers are validated before use; unresolved UI closes safely.

Expected markers: PICKER | OPEN BEGIN, PICKER VIEW | BUILD BEGIN,
PICKER VIEW | ATTACHED, PICKER | VIEW READY, PICKER | OPEN, LIVE PICKER START, LIVE PICKER UPDATE,
DISPLAY SAMPLE VERIFIED, HANDOFF | RESTORED, and PICKER | CLOSED.
Recovery should be empty after Cancel or timeout. Local controller, mock-UMG
and tint tests pass; visual layout, slider dragging and click reliability
cannot be certified by those mocks. Sliders/presets and slot cancellation were
confirmed by the user. Menu persistence, picker page-exit cancellation and
reopening after re-entry passed the v0.2.16/v0.2.2 live test. The v0.2.18 stock
palette lookup, Default restore, hover/page-exit cancellation and timeout passed
in-game. Active-preview reload failed with a hang; retest in stages, not as part
of routine picker testing.

For v0.2.17, find-docs confirmed the existing typed-wrapper array helper against
the current UE4SS [TArray API](https://github.com/ue4ss-re/re-ue4ss/blob/main/docs/lua-api/classes/tarray.md).
No raw UObject `get()` probing or new scheduling hooks were added.
For v0.2.18, find-docs confirmed the UListView family; exact `GetNumItems`,
`GetItemAt` and `GetIndexForItem` signatures are in the game's local UMG dump.
The adapter cross-checks the returned index instead of trusting scan order.
