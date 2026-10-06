# v0.2.53: independent scalar-target probe

## Scope

Test whether the character's existing Enable Tinting scalar can affect its face
without a direct MID override. Only CPD_H_SkinTone_Human_0B1, Race.0B, the verified
three-fragment source and original Outfit scalar layout are accepted.

colors_target start changes only that per-character scalar's MaterialTarget
SlotNameTagsToApply.GameplayTags field to the observed five-mesh layout. Parameter name,
material names, scalar value 1, RGB and all stock assets are unchanged. It calls
RefreshCustomization, checks source target/RGB again and restores after 15 seconds.
This validates struct marshalling, rendering and rollback before any save test.

## Test

1. Fully restart for v0.2.53 without saving the failed v0.2.52 test session.
2. Reopen the character that already has the saved custom RGB from the previous
   test. Enter its Skin Tone 5 color page; do not select another stock swatch,
   open CP, or Apply anything. Move the mouse off swatches.
3. Run colors_target start and close the console. If targeting works, the saved
   orange RGB should become visible without CP or colors_skin_enable.
4. Wait 15 seconds. The usual skin appearance should return.
5. Repeat start, then run colors_target stop before the timeout. Confirm the
   same restoration.
6. Report rendering, automatic restoration and manual restoration results.

Do not save, change clothes/race or reload mods while this test is active.
The target's ability to survive Save/reopen is explicitly a later test after
this one succeeds. If needed, colors_target stop or DP Restore attempts cleanup.
If recovery fails, do not save; retain logs/recovery files and report it.

## Safety and limitations

- v0.2.52 failed target validation after SetMaterialTarget returned and could not
  restore. v0.2.53 avoids that whole-struct call. Native tag-array field assignment
  still requires validation in-game; passing mocked tests is not proof.
- Dedicated DevPanel/skin_target_recovery.txt is written before mutation.
  It identifies the exact source owner/slot/scalar; version v1 fixes original
  Outfit and test five-mesh layouts rather than accepting arbitrary saved targets.
- Restoration reacquires the original source through the owner/slot, validates
  its companion ownership, race, color target and scalar value, and never writes
  to a later replacement. It does not require the damaged scalar target to pass
  normal validation before repairing its known original parameter/material/tag
  fields. Each repair is read back; source RGB is checked after refresh.
- Partial setter/restore errors retain recovery and block normal CP/other write
  probes. Same-process recovery replays only under the existing process gate;
  new-process records are archived rather than applied to reused object names.
- Context events cancel/restore unless emitted reentrantly within the probe's
  synchronous setter/refresh. A fixed owned deadline remains the backstop.
- The regular picker and its scalar-layout guards are not relaxed. No new
  automatic saved-color detection or global material patch is introduced.
