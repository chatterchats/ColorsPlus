# Editor-session Apply — Colors+Probe v0.2.25

Status: v0.2.21 Apply, stock hover returning to custom RGB, and stock selection
replacement passed in-game. The 07:21:36 transition to the radial slot selector
ran our `EDITOR COLOR | RESTORED | page closed` path and reverted violet to White.
v0.2.22 attempted to widen Apply's lifetime to the full creator, but all three
Apply attempts at 11:40–11:41 UTC failed with `No attached creator for item page`
before writing the source color. v0.2.23's 11:51:18 UTC capture found exactly one
master with a matching layout, but `in_viewport=false`, `parent=<none/invalid>`
and `activated=false`. The failed Apply restored Default successfully. v0.2.24's
12:01:16–12:01:56 UTC trace proved that the same master stays in `GameLayer_Stack`
under the active item page, becomes active at the radial selector, and is removed
at Databank exit. v0.2.25 now uses those verified stack relationships. Live Apply
and navigation confirmation is pending. Color experiments remain
restricted to **Clone 8 → Primary Accent**.
SWZC Dev Panel is optional and unchanged. Restart the game for this build.

## Next test: Apply and navigate

1. Restart with v0.2.25 and leave DP closed. Select Clone 8 → Primary Accent with
   a stock red selected. Move off stock swatches, run `colors_picker`, and close
   the console.
2. Choose a distinctive RGB and press **Apply (session)**. CP should close and
   the color should remain. Stop and report if it reverts or fails.
3. Back out to the radial selector, pause five seconds, then reenter Primary
   Accent. RGB should remain. Reopen CP, preview a different color, then Cancel;
   the applied RGB should return.
4. Exit fully to Databank without saving, then reenter: the original red should
   be restored, not the custom RGB.
5. Repeat from Default: RGB should survive the radial round trip, and full exit
   should restore Default. Do not press the game's Save/Confirm button.

Successful Apply logs `CREATOR BIND | BOUND` with the exact master and stack,
then `EDITOR COLOR | APPLIED`. Failures log `CREATOR BIND | REFUSED` or an editor
watcher restore reason. `colors_screens` remains available but isn't needed for
this test. No picker/Dev Panel reload stress test is requested.

## Previous test: v0.2.24 screen navigation (no Apply)

1. Restart with v0.2.24; leave CP and DP closed. Open Clone 8 → Primary Accent.
2. Run `colors_screens` in the game console and close the console. Remain on the
   color page for about five seconds.
3. Back out to the radial outfit selector and remain there for about five seconds.
4. Leave customization for Databank without saving; remain there for five seconds.
5. Reenter customization, pause on the radial selector, then open Tops → Primary
   Accent again. Pause about five seconds on each screen.
6. Run `colors_screens stop`, or let its 60 one-second samples finish. Report done.

No custom color needs to be selected, and Apply is still expected to refuse.
The trace intentionally survives these screen transitions; it is read-only and
does not expand color ownership. No new hooks or startup polling are installed.
Restart/stop/reload cancel owned work. Logs contain `SCREEN TRACE | CHANGE`,
`PAGE`, `STACK ACTIVE`, `MEMBER` and `STOP`; unchanged samples stay quiet.
Missing classes, read errors, skipped templates and limits are explicit. Up to
32 candidates per class and 32 members per stack are described, with a shared
128-widget state-read budget per sample. Oversized arrays use the existing
64-entry guarded reader. Only scalar text survives a sample.

The trace uses existing native declarations in `CommonUI.lua` and
`BitReactorGame.lua` for `GetActiveWidget` and `WidgetList`, plus the documented
UE4SS `FindAllOf` interface. Stack membership is evidence to inspect, not assumed
proof of creator ownership. A cached master or shared layout alone is insufficient.

## Previous test: v0.2.23 Apply diagnostics

1. Restart the game with v0.2.23; leave DP closed.
2. Open Clone 8 → Primary Accent with an ordinary stock color selected. Move off
   the swatches, run `colors_picker`, then close the console.
3. Choose a distinctive RGB and press **Apply (session)** once.
4. Stop and report the result. Apply may still revert; this build collects the
   evidence needed to correct the guard. Do not continue the navigation checklist
   below or save the character yet.

Look for `CREATOR BIND | BEGIN`, `REFUSED`, candidate lines and `SUMMARY` in
`colors_plus_probe.log`. Each refusal records up to 32 candidate details, with
the full count and omitted count. `host_match`, `in_viewport`, `parent` and
`activated` distinguish layout mismatch from attachment failure; individual
read errors are reported separately. If the scan itself fails, `REFUSED` records
that error. Successful bindings emit `BOUND`. No diagnostic polling is added.

## Meaning of each action

- `colors_picker` / `colors_picker open`: open the picker. On reopening after
  Apply, start with the applied RGB, not the orange file preset.
- **Apply (session)** / `colors_picker apply`: flush the latest sliders, end the
  temporary hover, keep RGB in the verified per-character source tint fragment,
  and close CP. No two-minute expiry for an applied color.
- **Cancel** / `colors_picker close`: discard only the current picker edit.
  With no prior Apply, return to stock/Default. With a prior Apply, return to
  that applied color. The picker-edit timeout does the same after two minutes.
- `colors_picker restore`: close CP and undo the whole session Apply, returning
  to the original stock color/Default. DP's Restore action also does this.
- Leaving the item page closes CP and discards an open draft, but retains Apply
  in the radial selector. Reentering the item page should retain it too. Leaving
  the **full creator** restores the original. Picking another stock color or
  replacing the armor takes precedence.

**Do not press the game's Save/Confirm button during this experiment.** Apply
now changes the editor's character-owned fragment, unlike the old hover-only
preview. This mod makes no save calls, but that does not prove the game's own
save path cannot serialize the temporary state. Exit/discard, then verify the
original appearance. Save persistence is explicitly not implemented.

## Full regression test — after the short test above passes

1. Restart; leave DP closed. Select Clone 8 → Primary Accent with red equipped.
   Move off the stock swatches, run `colors_picker`, then close the console.
2. Choose Orange (or another distinctive RGB) and press **Apply (session)**.
   CP should close and the color should remain, with no return to red.
3. Back out to the **radial outfit slot selector**: custom RGB should remain.
   Reenter Tops → Primary Accent and confirm it still remains. Repeat three
   times. Also switch directly to another slot and back to Primary Accent.
   Move off stock tiles before reopening CP. The controls should show the applied
   RGB. Preview Violet, then Cancel: Orange should return, not red.
4. Reopen, choose Green and Apply. Reopen once more and confirm Green is loaded.
   Change the sliders, let the two-minute edit timeout expire, and confirm Green
   returns. Applied color alone should not time out with CP closed.
5. Run `colors_picker restore`: red should return. Apply another color, back out
   through the radial selector (RGB remains), then leave the **whole creator**
   for Databank without saving and re-enter: red should be restored.
6. Repeat from **Default**. Apply should leave the temporary stock swatch selected
   while showing the custom RGB. Cancel after reopening retains custom RGB;
   `restore` or full creator exit must return selection AND appearance to Default.
   Backing out to the radial selector alone must not restore Default.
7. Optional: Apply, then choose a different stock color. It should win; Colors+
   must not reapply RGB or later force the earlier red/Default over that new choice.

If step 2 reverts or appears unchanged, stop there and report it. Inspect
`EDITOR COLOR | APPLY FAILED` / `RESTORE FAILED` and nearby `HANDOFF` lines in
`colors_plus_probe.log`. Do not keep stacking tests on failed/blocked recovery.
Use `colors_picker restore` to retry cleanup; restart if cleanup is refused.
Do not test active-window Reload All Mods: the development-only CP+DP crash
remains deferred. Restore the session and close both windows before reloading.

## Implementation and recovery notes

Only the exact main-menu character, VM, Clone 8 torso slot, Color 02 material
target and source fragment are eligible. Source writes occur on owned game-thread
actions and are checked again after refresh. Apply additionally verifies the
existing display handoff is back on the source and shows the applied color.
No asset definitions, material templates or save APIs are modified.

The live session binds to the exact `GameLayer_Stack` under the active item's
runtime OverallUILayout. Its parent must be live (the trace observed MainOverlay),
but screens do not need UMG parents or viewport membership. Initial Apply requires
one same-layout master in the stack, immediately followed by the exact active item
page at the top. The watcher requires the same master to remain in that stack and
the active top to be either that master or its immediate same-layout item page.
Recreated item pages can reopen the same source target; cached widgets outside
the stack and replacement creators cannot inherit an Apply.

Two 250ms watcher polls tolerate a temporarily inactive/unrecognized top during
navigation; the third restores. Creator removal/replacement, missing/detached
stack, duplicate/ambiguous members or unreadable membership trigger cleanup
immediately. Master `CloseMenu` and `ClearCustomizationAuxData` still request
cleanup; item `BP_OnDeactivated` only ends the draft. Existing source/character/
armor checks and later-stock-edit handling remain intact. Stack/master binding
stays in memory; old/new recovery journals still only restore, never resume.

`DevPanel/editor_recovery.txt` is a plain-data `editor-v1` journal with original,
previous and requested colors plus exact scalar identities. A temporary/previous
file swap preserves the older journal if writing fails. Interrupted swaps block
new writes. The process provenance gate archives prior-process records and
backups without resolving potentially reused UObject names.

Reload recovery ends any hover first, restores the source color next, and
re-equips Default last if the session began there. It never resumes an Apply.
The Default adapter holds its existing selection journal while an Apply is
active. Later stock replacements are not recolored or overwritten. Failed or
ambiguous cleanup retains recovery and blocks additional Apply operations.

Automated coverage includes the real tint/handoff/Default stack with simulated
native refresh propagation, failure injection, reload ordering, creator binding,
radial navigation and recreated item pages. Native Apply propagation passed in
v0.2.21; the wider creator-bound lifetime is the next live checkpoint.
