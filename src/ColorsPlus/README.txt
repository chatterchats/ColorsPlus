Colors+ v0.5.0 — Custom Color Picker for Star Wars: Zero Company
==================================================================

Choose any color you like when customizing your characters and weapons,
instead of only the game's swatches. A CUSTOM COLOR button appears under
supported color choices and opens a picker with a color box, a rainbow
slider and a color-code (hex) box, with a live preview.


REQUIREMENTS
------------

- Star Wars: Zero Company
- UE4SS, the recommended build for Zero Company (v3.0.1 Beta, a1e7f571)

No other mods are needed.


INSTALLING
----------

1. Close the game.
2. Extract the ColorsPlus folder from the ZIP into:
       SWZeroCompany/Binaries/Win64/ue4ss/Mods/
3. Start the game.

Updating: close the game and copy the new files over your ColorsPlus folder.
Keep its Recovery folder. If you used a test build whose folder was called
Colors_Probe (or Colors+Probe), delete that old folder: only one copy of the
mod may be installed.


WHERE IT WORKS
--------------

Character creator (main menu) and the barracks character editor:
  Clothing and armor colors, hair, skin (including race-specific skin tones
  such as Zabrak), makeup, tattoos, and the horn and scar color adjustments.
  The base game's eye choices are not supported (eye-color controls added by
  another mod may be).

Armory > Customize Weapon > COLOR:
  The Paint Color row of blasters.


USING IT
--------

Click CUSTOM COLOR under a color choice. Drag in the color box and the
rainbow slider, or type a color code. APPLY COLOR keeps your choice; CANCEL
puts back the color you had before.

- Main-menu creator: save the character as usual to keep your colors.
  Leaving without saving puts the original colors back.
- Barracks editor: there is no separate save step. Applied colors stay when
  you leave and are saved with your game.
- Armory: while the picker is open only the weapon preview changes, and you
  can change Location and Paint Finish to see your color on each pattern and
  finish. APPLY COLOR paints the weapon and the game saves it straight away.

To go back to one of the game's own colors, just pick its swatch.

The mod is mouse only: the buttons can't be reached with a controller.


UNINSTALLING
------------

Delete the ColorsPlus folder. Your custom colors stay on your characters and
weapons (the game saves them like any other color), and your saves load fine
without the mod.


COMPATIBILITY
-------------

- ZCUnlocked: works alongside it. Its Bolt Color and lightsaber blade rows
  don't get the button: those colors come from ZCUnlocked's own settings, so
  a custom color there would have no effect.
- Color-unlocker mods: armor wearing a color the palette no longer offers
  can still be changed.


KNOWN ISSUES
------------

- Restart the game after installing or updating. Avoid UE4SS's "Reload All
  Mods", which can crash or hang the game.
- Moving the mouse quickly across the swatches can close the picker. Your
  previous color is kept; just open it again.
- Lightsabers have no custom color: without ZCUnlocked they have no color
  rows, and with it their colors belong to ZCUnlocked.
- The picker's own buttons are in English.


REPORTING A PROBLEM
-------------------

Tell us what you were customizing (character race or weapon), what happened,
and which other mods you use. Please include these two files from the
ColorsPlus folder:

    colors_plus_probe.log
    colors_plus_performance.log

They hold timings, which controls you used, the internal names of the color
choices and any errors. No screenshots, save contents or mouse recordings.
Error messages can include file paths on your computer, so feel free to look
them over first. Nothing is uploaded automatically. Each log is capped at a
few megabytes; the older part moves to a .previous.log file beside it.
