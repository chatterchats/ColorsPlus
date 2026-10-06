# Appearance palettes and eye materials

## Character Suite vitiligo/scar retest — v0.2.89

Fully restart with the 10-01 Character Suite update. Select a visible vitiligo
or scar pattern, then enter **Vitiligo Tint** or **Scar Look**. Both should show
**Custom Color**, including when the color selection is None. The Dev Panel's
**Open live color picker** also works.

- Vitiligo: equip a color preset, preview a contrasting RGB color and Cancel.
- Scars: test Fresh Pink and Pale Silvery, then one Tint preset such as Red.
  Preview should affect the scar tint while retaining its pattern and strength.
  Cancel/Restore must recover the original preset appearance exactly, including
  the above-1 native tint values in Fresh Pink/Pale Silvery.
- For both: reopen → Apply → radial round trip → Restore. Repeat from None:
  Open → Cancel, then Open → Apply → Restore should restore the empty selection.

The separate scar display swatch and tint strength stay as supplied by the
selected preset. Earlier HSV Looks use their native adjustment controls.
All 41 regression programs cover lifecycle and recovery; native shader output
still needs this test. If opening or color fails, Restore, equip the same preset
and use **Capture color compatibility**; report the failed operation.


## Character Suite iris retest — v0.2.88

Fully restart with the 10-01 Character Suite update. Use a normal recolorable eye
mode and a visible iris pattern. Select an iris preset before opening **Custom
Color**, or use **F6 → Colors+ Picker → Open live color picker**.

- **Matching eyes / Iris Colour:** change outer RGB and confirm both eyes respond.
- **Heterochromia / Left Iris Colour:** change outer RGB; the right outer iris
  should retain its own selection.
- **Heterochromia / Right Iris Colour:** change outer RGB; the left outer iris
  should retain its own selection.
- **Inner Iris Colour:** change inner RGB and confirm the inner region of both
  eyes responds while their outer colors remain as selected.

For each slot: preview → Cancel, reopen → Apply, radial round trip → Restore.
Restore before changing eye mode for this test. Repeat from None to check the
launcher, temporary fallback and restoration of the original empty selection.
Recolour strength/inner amount, iris pattern and other shader settings should
retain their original values. Native shader output is still unverified; the 41
regression programs cover lifecycle, targeting and recovery. If an operation
fails, Restore before using **Capture color compatibility** on the same slot.

## Character Suite retest — v0.2.83

Fully restart the game to load the updated scripts, with Character Suite enabled.
Test each slot with Custom Color, change RGB, Cancel, then reopen and Apply.
Return through the radial selector and run `colors_picker restore` before moving
to another slot. Test without saving during this first rendering pass.

- **Sclera:** an ordinary swatch and None. Confirm both eyes change when using
  the shared sclera palette and that Cancel/Restore returns the original state.
- **Lashes:** an ordinary swatch and None. Confirm the intended lash materials
  respond and Cancel/Restore returns the original state.
- **Freckles:** Natural (game-default alpha 0.99). Confirm RGB responds without
  changing its original alpha; Cancel/Restore should recover Natural exactly.
- **Blush:** test both blend-mode families exposed by Character Suite. The color
  should change while each preset retains its original blending appearance.
- **Lipstick/eyeliner:** one preview/Cancel as a regression check.

If opening or rendering fails, close/restore the picker, select the same slot,
and run `colors_compat`. Report the preset and whether the failure was opening,
visible color, Apply or restoration. v0.2.85 also supports vitiligo/scar RGB
colors and native scar HSV adjustments manually; see the [Dev Panel test](dev-panel-controls.md).

The 40 Lua regression programs cover the lifecycle and recovery changes. They
cannot verify the native shader output. These four slots need no new palette
encoding from Maddie if the captured layouts remain the same.

## Historical test — v0.2.28

## Changes and limits

v0.2.27's `found 2 (attached=0)` failures came from global palette discovery:
two locally visible widgets matched the slot, but neither UWidget parent chain
reached the active page. Restore succeeded and all recovery journals were empty.

The new resolver starts at the exact active item page, reads the active child
of `SlotWidgetSwitcher`, verifies it against the page's known panel reference,
then follows only that panel's documented lists. It supports the single panel,
combined `CustomizationSlots`, and `WBP_Customization_SlotList.SlotStack` paths.
There is no fallback to arbitrary global selection widgets. Existing checks
for slot tag, VM game instance/class, equipped membership, ordering, preview
ownership and restore identity remain. Missing references or ambiguous matches
are logged and refused, not guessed. Bounds: 128 page candidates, 128 traversed
widgets, depth eight, 64 children per container, 1024 palette entries.

The one-applied-zone limit remains. Skin/tattoo multi-mesh writes and eye RGB
editing are not enabled. No Save/Discard hooks, DP changes or recovery-format
changes are included.

## Focused live test

Restart the game, keep DP closed, and do not save during this pass.

1. On **Eye Shadow Color**, run `colors_picker`. Change RGB, Apply, then run
   `colors_picker restore`. Immediately reopen the picker on the same color.
   It should open again; Cancel should restore the pre-preview baseline.
2. Repeat preview/Cancel on hair root, hair tip and eyebrow color. Test one
   other makeup **Color** subslot (not its Style/Pattern selector).
3. On one of those newly working zones, Apply -> radial selector -> return,
   then Restore -> reopen. Run `colors_picker restore` before changing zones.
4. One outfit color preview/Cancel is sufficient as a regression check. No need
   to repeat the full armor matrix.

If opening fails, run `colors_compat` on the same selected color and report the
zone. `ACTIVE PALETTE` logs now show the active panel, traversal routes and
matching tile tags, so a failed path should be diagnosable from this capture.
Stop if the wrong zone changes or Restore fails; do not save.

## Eyes: two read-only comparisons

With CP closed and any Apply restored:

1. Open Eyes, select one ordinary eye preset, move off the tiles, and run
   `colors_compat`. Close the console and wait a second.
2. Select a visibly different eye preset and repeat. Report the two preset names.

The probe still never equips or previews anything itself. Your native preset
selections are ordinary editor changes; discard them on exit if unwanted.

The existing probe found hidden `.Left` and `.Right` slots, each holding a
`CustomizationFragmentInstanceMaterialSwap`. The expanded `EYE MATERIAL` output
records target slots/tags and the already-loaded replacement material. It walks
up to four material-instance levels and reads vector, scalar and texture
override entries (16 per type/level, 64 rows per swap; existing array reader
limit 64). Parameters include association/index as well as name. Missing data,
cycles, truncation and unsupported material classes are explicit gaps.

No synchronous asset loads, material creation, setters or guessed parameter
getters are used. Empty override arrays do **not** prove that a shader lacks
color parameters: compiled base-material defaults/expressions are not inspected.
This test looks for evidence of tint parameters versus texture/material swaps;
it does not establish arbitrary RGB eye support or persistence.
