# Displayed color-slot test (v0.2.36)

Result: the user confirmed all tests below passed. The next checkpoint is
[tattoo multi-mesh testing and skin capture](skin-tattoo-testing.md).
The scope restrictions below describe v0.2.36, not the newer tattoo build.

## Evidence and scope

The September 17 10:59–11:00 UTC captures showed color grids for skin, hair,
tattoo and lipstick while CurrentCustomizationSlotVM still named Face Shape,
Hair Style, Tattoo Style and Lipstick Style. The earlier picker attempts also
refused Style fragments. This is a selection-resolution bug, not evidence the
user opened the wrong selector.

The v0.2.35 retest confirmed lipstick working. Hair root's compatibility capture
at 11:10:08 UTC and picker open at 11:10:12 both refused `cycle/alias` before
color writes. Those logs do not distinguish a real loop from a shared reference.
v0.2.36 allows completed nodes to be referenced again, checks their tag is stable,
and still rejects nodes encountered again on the active recursion path. Distinct
VMs claiming the displayed tag remain ambiguous. Bounds and write guards remain.
The live snapshot confirms hair root uses `.Color.Secondary` and tips use
`.Color.Primary`; these labels are never used to guess which tag to select.

Use the active simple panel's CurrentSlotTag and resolve the exact matching
slot under RootCustomizationSlotVM.CustomizationChildSlotViewModels. Require
the original auxiliary slot to belong to that tree too. Validate equipped
palette membership and reacquire the same grid/tag before returning. This is
read-only selection discovery; never update the game's auxiliary selection.
The reference declarations are in WBP_Customization_SelectionTiles.lua,
CustomizationAuxVM.lua and BitReactorCustomizationSlotViewModel.h in the local
ZeroCompany_RE_Reference_v2 dump. No new engine API or hook is introduced.

Only simple panels permit this override. Combined/list layouts still require
an exact current-slot palette match because a visible list alone cannot prove
which of several palettes is selected. Missing/foreign/ambiguous/cyclic graphs,
missing equipped swatches and changing grids/tags refuse rather than guess.

Skin and tattoo mutations are deliberately still unsupported: their multi-mesh
targets (and skin's accompanying non-color fragments) need separate work.
Eye customization remains deferred to a texture mod. The panel application and
the v0.2.34 missing-registry fix are unchanged.

## In-game verification

1. Fully restart into v0.2.36; do not Reload All Mods. Open the same hairstyle
   that failed in the previous run. Do not save the character.
2. Open **Hair → Root Color**. With CP closed and no applied color pending, run
   **Capture color compatibility**, then **Open live RGB picker**. Check that
   RGB changes affect roots rather than tips. Cancel and confirm restoration.
3. Reopen CP, Apply a distinct root color, back out to the radial selector and
   return. Reopen CP and Cancel an edit; the applied color should remain.
   Use **Restore original appearance** before moving to lipstick.
4. Briefly open CP on hair-tip color and lipstick color, then Cancel, to check
   that existing working slots remain functional. No repeat of the full
   lipstick test is needed. Optionally switch away while CP is previewing to
   confirm its existing cancellation.

Success evidence: `COLOR SLOT | RESOLVED DISPLAYED` records the auxiliary and
displayed tags and `shared_references` count when they differ. If a real loop
exists, its error now names the node. `COLOR COMPAT | SELECTED` should name the color
slot rather than Style. If opening fails, capture compatibility on that screen
and report which selector/step failed. No extra skin/tattoo testing is needed
for this checkpoint. Automated tests cannot establish the rendered result.
