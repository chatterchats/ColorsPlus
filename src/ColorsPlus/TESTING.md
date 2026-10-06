# Welcome to Colors+ — tester build v0.4.0

Colors+ lets you choose your own colors when customizing a character, instead
of being limited to the game's existing choices. Thanks for trying it out!
This is an early test version, so please back up your saves first.

## What's new in this update

- **Custom colors in the in-game character editor.** The Custom Color button
  now also appears in the character customization you reach in the base
  (the barracks), not just the main-menu creator. Skin, tattoo and armor
  colors on Hawks and recruits were tested there; other color options
  should work too, so tell us if one doesn't.
- **In the base, leaving the editor keeps your colors.** The base editor has
  no separate save step, so an applied color stays on the character when
  you leave, and it is saved with your game as usual. In the main-menu
  creator, save the character as before.
- **Armor colors from other mods.** Armor wearing a color the palette no
  longer offers (for example, one picked with a color-unlocker mod) can now
  be changed too.
- **New install folder.** The mod's folder is now called `ColorsPlus`
  (it used to be `Colors_Probe`). See below: delete the old folder.

Please try the base editor on a few different characters and color slots,
then leave the barracks, walk around, and save and reload your game. Tell us
if a color ever changes back or shows on the wrong character.

## Getting started

You need a working UE4SS installation for Zero Company. You do not need any
other mods or console commands to use the color picker.

1. Close the game.
2. **Updating from an earlier version?** Delete the old `Colors_Probe`
   folder (or `Colors+Probe`) from your game's
   `SWZeroCompany/Binaries/Win64/ue4ss/Mods/` folder. Only one copy of the
   mod may be installed; two copies will fight over the same colors.
3. Extract the ZIP's `ColorsPlus` folder into that same `Mods` folder.
4. Start the game and open character customization.

When updating to a later version, copy the new files over your existing
`ColorsPlus` folder. Keep its `Recovery` folder: it lets the mod recover
unfinished edits.

For this test version, restart the game when updating the mod. Please avoid
**Reload All Mods**, which has caused crashes during testing.

## Try it out

Customize a character as you normally would. When choosing a color, click
**Custom Color** to try something beyond the existing choices.

- Experiment with the color box and rainbow slider, or enter a color code.
- **Apply Color** keeps your choice. **Cancel** goes back to the color you had
  before opening the picker.
- Try different clothing, hair, skin, and other available colors. Feel free
  to switch between custom colors and the game's existing choices.
- In the main-menu creator, save your character normally to keep your
  changes. In the base editor, leaving the editor keeps them. We'd love to
  hear whether they still look right the next time you play.

There's no timed checklist to follow: use it at your own pace. The button
belongs on color choices, not the lists where you choose a helmet or outfit.
The base game's eye choices aren't supported; extra eye-color controls added
by another mod may be available.

## Tell us how it went

Did anything feel slow, confusing, or fail to work? Did a color disappear or
change unexpectedly? Tell us what you were customizing and what happened.
Mention your character's race and any other character-customization mods you
use. Screenshots or a short video are welcome. If everything worked, that's
useful feedback too!

Performance logging runs automatically while you use the picker. There's
nothing to turn on, and it stops when you finish or leave the picker.

When you're done, close the game and send **`colors_plus_performance.log`**
along with your feedback. You'll find it inside the installed `ColorsPlus`
folder, beside this guide:

`SWZeroCompany/Binaries/Win64/ue4ss/Mods/ColorsPlus/colors_plus_performance.log`

Don't worry about reading or interpreting it. The same file keeps results
from earlier sessions, so there's no need to clear it between tests.

If the game crashes or a color won't change back, also send
`colors_plus_probe.log` from that folder and a game crash report if available.
If you can't find the performance log after using the picker, let us know;
`UE4SS.log` in the `ue4ss` folder can help us work out why.

## A note about the logs

The report contains timing information, the selected color preset's internal
identifier, which customization controls you used, and any picker errors. It
also distinguishes detected editing from idle checks and counts slower operations.
It does not contain screenshots, save contents, or a
recording of your mouse movements. Error messages can include file paths on
your computer, so you're welcome to review it before sharing. Nothing is
uploaded automatically.

This tester build leaves out the developer diagnostic tools. If we need a
specific capture, we'll send a separate diagnostic build.
