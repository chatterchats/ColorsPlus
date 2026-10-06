# Human skin test — v0.2.46

## Current test: rendered materials and dispatch

Use [the skin/material comparison and panel delivery test](skin-material-dispatch-testing.md).
Skin Tone 5 opened via console in v0.2.45 and its RGB data updated, but the user
saw no visible skin change. Do not proceed to save/persistence yet. v0.2.46 adds
read-only evidence; it does not change skin tinting or clothing-change guards.

## Previous test: Skin Tone 5 — v0.2.45

1. Fully restart into v0.2.45 (not Reload All Mods). Select human **Skin Tone 5**.
   Leave clothing unchanged throughout this pass.
2. Open CP, change RGB, Cancel, and reopen. Confirm the skin changes during
   preview and returns to its equipped appearance on Cancel.
3. Apply a custom color, back out to the radial selector, then return to Skin
   Tone. The applied color should remain. Restore should return the original.
4. On Skin Tone 16, repeat a short preview/Cancel and Apply/Restore regression.
5. If all of those pass, apply a custom skin color, save through the game's
   normal editor flow, restart, and check persistence. Do not save if cleanup
   refuses or any recovery warning appears.

Skin Tone 5 uses the exact Outfit parent tag for its tint-enable scalar, while
its color still targets five meshes. v0.2.45 records this layout and requires
source, cloned and installed bundles to retain it; the three material names,
race companion and scalar value remain checked. Stock donor layout may differ
without being copied over the source layout. Parent-layout journals add an
explicit marker (proxy-v10/editor-v5); old five-mesh recovery stays supported.
Clothing changes still restore the applied skin color, intentionally unchanged.

## Previous test: click-away and reopen — v0.2.44

1. Fully restart into v0.2.44; do not Reload All Mods or save. Select human
   **Skin Tone 16**, move off stock swatches, and open CP. Move a slider.
2. Click away as before without Apply. Return to Skin Tone, move off stock
   swatches, and reopen CP. Repeat twice; preview should work each time.
3. Cancel a draft, reopen, then test Restore. Both should return to the equipped
   stock appearance (if you selected another stock swatch, that is the baseline).
4. If those pass, back out to the radial selector, return to Skin Tone, and
   repeat preview/Cancel. Report any refusal or unexpected color retention.

Do not Apply/save yet: first isolate reopen and cleanup. v0.2.43 successfully
previewed and updated skin at 15:20:44–51 UTC. After clicking away, the native
auxiliary slot reported Face Shape while the displayed palette was Skin Tone;
our category traversal refused a cycle through Face Shape on each reopen.
v0.2.44 treats these references as a bounded graph, preserving exact displayed
slot, ownership, ambiguity and repeated-tag checks. Logs add `back_edges` to
`COLOR SLOT | RESOLVED DISPLAYED`; this is not a change to skin tint writes.

## Previous donor-layout fix — v0.2.43

At 2026-09-17 13:54:49 UTC the new diagnostics identified donor
`CPD_H_SkinTone_Human_2B1` with `Enable Tinting=1` targeting the single
`br.Customization.Slot.Character.Outfit` tag; its three material names matched.
The donor's color-target check passed. The earlier slot-tree-cycle refusal in
the same session was a separate issue, addressed by the v0.2.44 lookup change.

v0.2.43 allows only this additional stock **scalar** target layout. Stock donor
and stock-hover display checks can accept it; source, submitted clones,
installed custom data, live display verification and editor Apply remain strict.
The full source bundle is cloned, not the donor bundle. Before installation,
cleanup resets the stock hover without SetColor, including unverified donor,
verified donor and prepared-clone recovery. Owned/ambiguous installation phases
do not gain the stock-layout exception. Recovery formats are unchanged.

Tests now model the real parent-tag donor and its displayed copy, and cover
five-mesh donors, stale idle data, stock hover settling, custom preview/Apply,
pre-install recovery, wrong parent/color targets and rejection of the stock
scalar variant on source, clones and installed custom data/display.

## Previous diagnostic test — v0.2.42

The v0.2.41 test at 2026-09-17 12:54:26 UTC verified the equipped Skin Tone 16
and idle display, activated its stock donor, then refused `Unsupported skin
target layout`. No custom SetColor/clone installation occurred. ResetPreviewedPart
restored the equipped appearance. The following compatibility capture again
confirmed the source's five meshes and three material slots; it did not capture
the temporary donor layout.

Fully restart into v0.2.42; do not Reload All Mods. Select the same human
**Skin Tone 16**, move off the swatches, then open CP **once**. It may still
refuse: this patch adds evidence, not a target-layout fix. Stop there and report
the result so the log can be read. No sliders, Apply, save or additional
compatibility capture are needed for this pass.

New log records:

- `TINT | SKIN DONOR | ACTIVATE`: equipped source and requested donor assets.
- `TINT | SKIN PROXY CHECK`: idle/stock-preview stage, source, requested and
  actual preview asset, using identities already read by validation.
- `SKIN TARGET | REFUSED`: expected and actual parameter, distinguishing the
  color fragment from its tint-enable scalar companion.
- `SKIN TARGET | COUNTS`, `MESH`, `MATERIAL`: actual counts and indexed names
  alongside expected values. Lists are capped at 16 entries each, with an
  explicit omitted count; each name is sanitized and capped at 256 characters.

Detailed target records occur only on failed target validation. Diagnostics
reuse the guard's already-read arrays; unreadable names remain diagnostic gaps,
and logger exceptions cannot bypass the original refusal/rollback. Guards,
native write sequence and recovery formats remain unchanged.

## Later functional pass — after preview/restore succeeds

Fully restart; do not Reload All Mods. Restore any pending/applied custom color
before changing zones. Use a human and select an existing **Skin Tone** swatch,
preferably **Skin Tone 16**, the captured `CPD_H_SkinTone_Human_2B0` example.
Move the pointer off the stock swatches before opening CP. Do not save yet.

1. Open CP. Try violet, green and a few RGB slider changes. Check the face,
   neck and any exposed arms/legs for consistent changes. Clothes, hair,
   lipstick and tattoo colors should not be directly recolored by this target;
   skin underneath translucent masks may affect their appearance.
2. Cancel; confirm the original skin tone returns. Reopen and use DP Restore;
   confirm the same. Stop here if opening, rendering or restoration fails.
3. Reopen and leave the preview for two minutes; the original should return.
   Separately reopen and back out to the radial selector: CP should close and
   the un-applied preview should restore.
4. If the above all pass, Apply a distinct color. Back out to the radial
   selector and return. Hover a stock swatch then move away: the applied custom
   color should return. Open a second draft, change RGB and Cancel: the earlier
   applied color should remain. Use Restore to return to the original skin tone.
5. Repeat preview/Cancel on one other human skin swatch. Leave save/restart
   persistence and other races for a later checkpoint.

If opening refuses, keep that palette selected and run Capture color
compatibility. Report the race, swatch and step. Do not repeatedly retry or save
after a restoration error. Original intermittent tattoo crash remains unresolved;
bounded v0.2.40 call tracing is retained and can alter timing.

## What changed

The capture at 2026-09-17 11:43:11 UTC contained exactly:

- GameplayTags: one `br.Customization.Part.Character.Race.2B` tag.
- MaterialColor: `Skin Coloration`, opaque RGBA.
- MaterialScalar: `Enable Tinting=1`.

Both material targets listed `MI_Head,MI_Body,MI_Neck` and, in order, arms,
legs, boots, torso and face mesh slots. The implementation requires this exact
shape, preserving the selected swatch's actual race tag. It snapshots every
equipped mesh asset and validates source/preview/display against those identities.
Missing targets refuse; the tattoo-only optional-horns rule does not apply here.

Stock preview activation is still used to make the display follow the preview
proxy. Human asset names are filtered to a same-family alternate shade, then
its real companion tag/scalar/targets are verified. The naming filter alone
does not authorize a custom write. An unsupported donor or active stock hover
refuses rather than rewriting race tags. No fallback equips a different skin
swatch, and no skin Default handling was added.

The full cloned array is installed; only the color fragment gets SetColor.
Companion ownership, values, ordering and target fields are checked again after
installation/refresh and during live checks. Apply edits the per-character
source color only. No gameplay-tag/scalar setter or save function is called.
Proxy-v9 and editor-v4 recovery records include the race tag and all five mesh
assets; unsupported/malformed records block instead of being guessed.

## Verification and documentation

`tests/skin_test.lua` runs the real tint, Default coordinator, editor-session,
targeting and compatibility modules against a three-fragment native mock. It
covers copying installs, source isolation, companion preservation, all target
meshes, preview/Apply/cancel/timeout/page exit, second-draft cancellation, reload
recovery, malformed records, changed companions and ambiguous native failures.
These tests do not prove native rendering or save persistence.

The documentation lookup confirmed the existing wrapper boundaries in the
[UE4SS TArray documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/classes/tarray.md)
and [RemoteUnrealParam documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/classes/remoteunrealparam.md).
This path reuses those array helpers and the local Lua guide's owned game-thread
jobs and scalar recovery identities. No new UObject API or hook was introduced.
