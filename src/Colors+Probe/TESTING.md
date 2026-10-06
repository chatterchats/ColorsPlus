# Welcome to Colors+ — tester build v0.2.120

Colors+ lets you choose your own colors when customizing a character, instead
of being limited to the game's existing choices. Thanks for trying it out!
This is an early test version, so please back up your saves first.

## What's new in this update

This update targets the lag while the picker is open. The game should no
longer slow down just because the picker (or a color palette with the Custom
Color button) is on screen, and dragging should update much more smoothly.
Try leaving the picker open untouched, then drag around the color box and
along the rainbow slider on skin, clothing and other appearance colors. Also
switch color slots, return to the selection menu and reopen the picker.
After applying colors to several zones, browse the creator for a while:
it should stay smooth. Loading into the game should also be quicker.
Opening the picker should be faster too, without a hitch right after it appears.
The picker should no longer close by itself if your mouse passes over the
color swatches while it opens.

Cancel should still return your previous color; Apply should keep your latest
choice. The Zabrak Skin Tone 4, 5 and 10 fixes are included and have passed
Cancel, Restore, menu navigation and save/restart testing.

Normal performance logging still runs automatically while you use the picker.
No console commands or extra setup are needed. The skin-color fixes and native
Apply/Cancel buttons remain included, and extra troubleshooting tracing stays off.

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
