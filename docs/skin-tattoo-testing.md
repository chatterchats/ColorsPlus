# Tattoo test and skin capture (v0.2.37)

Historical checkpoint: tattoo passed the user's visual tests. v0.2.41 adds
guarded human skin preview/Apply; follow [the current test](human-skin-testing.md).
The read-only skin restrictions below describe v0.2.37, not the current build.

## Scope and evidence

The September 17 11:11:18 UTC capture selected Tattoo Color / Ashen,
`CPD_H_Tattoo_Color_01`: one opaque material-color fragment, `Tattoo Color`,
`MI_Head`, targeting face and horns. Face resolved to `CPD_H_Head_HF00`; the
following horns lookup was unavailable. That missing optional target must not
prevent the face tint, but it must not silently disappear from validation.

The picker now supports this exact ordered pair:

- `br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh`
- `br.Customization.Slot.Character.Horns.Mesh`

Face must resolve to an equipped part; horns must resolve to an equipped part
or remain absent. Any different/missing/added target or changed equipped asset
invalidates the preview. Existing ownership checks still protect cleanup of
our original color fragment. No whole material, texture or mesh is modified.
Malformed journals refuse; multi-mesh records use proxy-v8/editor-v3, while
existing single-mesh formats remain readable. Only scalar descriptions, never
UObjects, are retained between scheduled actions.

Skin has three observed fragments: gameplay tags, material color, and material
scalar. Its color targets arms, legs, boots, torso and face using `Skin Coloration`.
This build captures the companion values and target availability; it does not
remove the single-fragment write guard. The reflected fields come from the
local native headers `CustomizationFragmentInstanceGameplayTags.h` (`GameplayTags`)
and `CustomizationFragmentInstanceMaterialScalar.h` (`Value`), alongside the
existing `MaterialTarget` inspection. Missing fields produce gaps, not invented
defaults. No new hooks or native mutation methods are introduced.

## In-game check

Fully restart into v0.2.37; **do not Reload All Mods**. Do not save during this
checkpoint. The source is still linked directly to the live probe mod folder.

1. On a human, choose a clearly visible tattoo and an existing tattoo color
   such as Ashen. Open its **color palette**, not the tattoo Style selector.
   With no applied/preview color pending, use **Capture color compatibility**.
2. Open CP and preview cyan, then magenta. Check that the tattoo changes while
   skin, hair and makeup stay unchanged. Cancel; the original tattoo color
   should return. A muted result can reflect the underlying tattoo texture/mask.
3. Reopen, Apply a distinct color, back out to the radial selector, then return.
   It should remain. Hover stock swatches and move away; the applied custom
   color should return. Reopen CP, change color and Cancel; the applied color
   should remain. Use **Restore original appearance** to undo it.
4. Open an un-applied preview and switch slots: CP should close and restore.
   Separately open a preview and leave it for two minutes: it should restore.
5. Restore/close CP **before** changing race. If a horned character exposes the
   same tattoo-color palette, capture compatibility there and repeat Open,
   preview, Cancel and Apply/Restore. Do not expect every horn texture to expose
   a visible tattoo mask; report which surfaces actually change. A live but
   empty/unrecognized horn slot safely refuses rather than guessing an asset.
6. With CP restored and closed, open **Skin Color**, select one existing swatch,
   and run **Capture color compatibility**. Select a different skin swatch and
   capture again. If convenient, capture one non-human skin tone too. There is
   no skin picker test yet; it should still refuse mixed-fragment writes.

If opening fails, leave that palette selected, capture compatibility, and report
the race, swatch and step. Do not keep trying Apply or save after a restore error.

Expected skin evidence: `GAMEPLAY TAGS`, individual `GAMEPLAY TAG`, `SCALAR`,
the scalar's `TARGET`, and each `TARGET SLOT` with equipped asset or `state=absent`.
Skin's overall result remains `UNVERIFIED`; that is expected at this stage.

Automated tests cover the targeting and ownership logic, not native rendering,
cross-race behavior or save persistence. Establish visible tattoo behavior before
repeating save/restart tests. Eyes remain deferred to the separate texture mod.
