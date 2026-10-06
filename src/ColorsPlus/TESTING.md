# Welcome to Colors+ — tester build v0.3.0

Colors+ lets you choose your own colors when customizing a character, instead
of being limited to the game's existing choices. Thanks for trying it out!
This is an early test version, so please back up your saves first.

## What's new in this update

This update is all about speed and smoothness:

- **No more slowdown while the picker is open.** Leaving the picker (or a
  color palette with the Custom Color button) on screen should no longer lag
  the game, and dragging around the color box and rainbow slider should feel
  much smoother.
- **Faster opening.** The picker should open noticeably quicker, especially
  when you reopen it on a color you've already used, with no hitch right
  after it appears.
- **Smoother after Apply.** Browsing the creator after applying colors to
  several parts should stay smooth, and loading into the game is quicker.
- **No more picker closing by itself** if your mouse passes over the color
  swatches while it opens.
- **The Custom Color button now uses the game's own button style.** Tell us
  if it looks out of place or doesn't respond to a click.
- **Tidier editing code behind the scenes.** The part of the mod that
  previews, applies and undoes colors was reorganized. Nothing should look
  different, so tell us if Cancel, Apply, leaving the creator or restarting
  ever leaves a color other than the one you expected.

Please try leaving the picker open untouched, dragging colors on skin,
clothing and other appearance options, switching color slots, and reopening
the picker. If you sent us a log for an earlier build, we'd especially like
to compare: this build records a little extra timing detail.

Cancel should still return your previous color; Apply should keep your latest
choice. Performance logging still runs automatically while you use the
picker. No console commands or extra setup are needed.

## Getting started

You need a working UE4SS installation for Zero Company. You do not need SWZC
Dev Panel or any console commands to use the color picker.

1. Close the game.
2. Extract the ZIP's `Colors_Probe` folder into your game's
   `SWZeroCompany/Binaries/Win64/ue4ss/Mods/` folder.
3. Start the game and open character customization.

If you are updating, copy the new files over your existing `Colors_Probe`
folder rather than deleting it first. Leave any extra files already there
alone; they help the mod recover unfinished edits. Only keep one copy of this
mod enabled. An older copy may be called `Colors+Probe`.

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
- Save your character normally if you want to keep your changes. We'd love
  to hear whether they still look right the next time you play.

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
along with your feedback. You'll find it inside the installed `Colors_Probe`
folder, beside this guide:

`SWZeroCompany/Binaries/Win64/ue4ss/Mods/Colors_Probe/colors_plus_performance.log`

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
