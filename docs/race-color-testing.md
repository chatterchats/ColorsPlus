# Togruta markings and Ovissian skin tests — v0.2.58

Use a fresh game launch after installing this build. Confirm `Loaded v0.2.58`
in the probe log. The installed SWZC Dev Panel app itself is unchanged. Close
both DP and CP before any Reload All Mods; the known both-open reload crash is
not part of this fix. No game saves are invoked by the picker.

## Focused v0.2.58 checks (do not save yet)

1. Togruta face marking color: select a stock swatch, open CP, preview an
   obvious RGB, Cancel and reopen. Apply, return to radial and reenter, then
   Restore. Only the face markings should change, not skin or lekku markings.
2. Repeat on Togruta lekku marking color. Apply distinct face and lekku RGBs
   together, then Restore both to their individual baselines. Keep the lekku
   style unchanged; changing mesh style still triggers the existing reset guard.
3. Ovissian Skin Tone 1, then Skin Tone 2: on each, preview, Cancel/reopen,
   Apply, radial round-trip and Restore. Face/bare skin should visibly change;
   horns and eyes should retain their original appearance. The extra iris
   scalar in Skin Tone 1 must remain untouched.
4. Let a draft expire after two minutes on either target; it should restore
   and allow reopening. If anything fails, note race/slot/swatch and capture
   compatibility plus Inspect tint target after cancelling/restoring.

The new captures contain one marking RGB plus a matching enable scalar per
Togruta marking slot. Ovissian Skin Tone 1 has an `IrisUVRadius=10` scalar on
`MI_EyeRight` that Skin Tone 2 lacks. It is carried unchanged in the complete
source clone, not written or exposed as eye RGB support. Unknown companions,
changed targets/scalars and replaced objects remain refused. Automated tests
cover both directions of the differing Ovissian donor layouts.

Zabrak's no-visible-skin-tint issue is not changed by this build.

## Earlier v0.2.57 coverage

## First checks (do not save yet)

1. Weequay: open Skin Tone, preview an obvious RGB, Apply, return to the radial
   selector and reenter, then Restore. Check face and any visible bare skin.
   Hair and tattoo should still work.
2. Twi'lek: preview an obvious RGB on Skin Tone. Check head, body and lekku.
   Cancel should recover their individual original shades. Repeat with Apply,
   radial round-trip and Restore; their original shades must not be flattened
   into the head's original color. Marking-color behavior should be unchanged.
3. Ovissian and Devaronian: test skin and horn colors independently. Apply both,
   Cancel another draft, then Restore all. Each slot should return to its own
   baseline; a skin edit must not overwrite the horn edit.
4. Apply on a race with horns, back out and change to a hornless race. Open its
   skin picker. Removed old slots should retire, not cause `Restore pending`
   failures. Do not expect a custom RGB to transfer across races automatically.

## Broader coverage

Check skin on Togruta, Rodian, Neimoidian, Mirialan and Zabrak as well. Test at
least two stock swatches per race, including a different material/special shade
where available. Preview, Cancel, Apply, Restore, stock swatch hover/selection,
radial navigation and the two-minute draft timeout should remain reversible.
Existing human skin and ordinary armor/hair/tattoo slots are regression checks.

After rendering/restoration passes, save a character with an applied race skin
color and a separate horn/other color. Reopen and restart to test the game's
native persistence. Restore does not undo a completed game save.

If opening or rendering fails, note race, slot, stock swatch, whether the picker
opened, and which visible regions changed. After Cancel/Restore, capture
`colors_compat` and Inspect tint target on that exact slot. Readback-only success
does not establish a visible tint; scalar enable values, swaps, scar adjustments
and hue shifts are preserved rather than overridden.

## Captured layouts used

The Sep 29 captures cover Weequay, Twi'lek, Togruta, Rodian, Ovissian,
Neimoidian (asset spelling `Niemoidian`), Mirialan and Devaronian skin, plus
Ovissian/Devaronian horns. Earlier Zabrak capture includes a six-mesh color,
enable scalar and trailing race tag. Generic bundles are bounded at 16 fragments
and 16 mesh/material targets; recorded class/order/target/scalar/scar state is
verified before writes. All fragments must share their owner/slot, and cloning
must not alias source or stock companions. Every original RGB is journaled
before mutation; source companion identities are recorded for safe retirement.

Only `Skin Coloration` fragments receive custom RGB. Native `CloneFragments`
and `SetFragmentInstances` carry the complete array; material swaps, gameplay
tags, `Enable Tinting`, `Hue Shift` and `Scar HSV Shift` are not Lua-edited.
The separately verified human source-scalar correction remains in use where
its existing layout requires it.
