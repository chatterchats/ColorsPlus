# Colors+ v0.5.0 — Custom Color Picker for Star Wars: Zero Company

Tired of picking from the same handful of swatches? Colors+ lets you choose
**any color you like** for your characters and your blasters.

Look for the new **CUSTOM COLOR** button under the color choices in the
main-menu character creator, the barracks, and the armory. It opens a color
picker where you can drag to any shade or type in a color code, and you see
the result on your character or weapon as you go.


## What you need

- Star Wars: Zero Company
- UE4SS for Star Wars Zero Company (from Nexus Mods). Both mod managers below
  can install it for you.

No other mods are needed.


## Installing

### With Zero Company Mod Command

1. Make sure UE4SS is installed: Mod Command shows its status on the
   Settings card. If it isn't, follow the card's offer to install the Nexus
   build.
2. Open the **Hangar Bay** and drag the Colors+ ZIP anywhere into the window.
3. Check that Colors+ is switched on in the Hangar Bay, then start the game
   with **LAUNCH GAME**.

### With Zero Mod Manager

1. Make sure UE4SS is installed: go to **Home → Runtime readiness → UE4SS
   runtime** if it isn't.
2. Download the Colors+ ZIP, open **Install** and drop the ZIP into the app.
   Look over the summary and click **Install**.
3. Check that Colors+ is switched on in **Mods**, then start the game.

### By hand

1. Close the game.
2. Open the ZIP and drag the **ColorsPlus** folder into your game's UE4SS
   mods folder:
   `SWZeroCompany/Binaries/Win64/ue4ss/Mods/`
3. Start the game.

### Updating

Close the game first. With a mod manager, install the new ZIP the same way.
By hand, copy the new **ColorsPlus** folder over your old one (no need to
delete it first).

Only one copy of Colors+ can be installed at a time. If you tried an early
test version, delete its old **Colors_Probe** folder.


## Where you'll find it

**Character creator (main menu) and the barracks:** clothing and armor,
hair, skin (including species skin tones, such as Zabrak), makeup, tattoos,
horns and scars. Eye colors aren't supported (but eye-color options added by
another mod may be).

**Armory → Customize Weapon:** the Paint Color of your blasters.


## How to use it

Click **CUSTOM COLOR** under a color choice. Drag in the color box and along
the rainbow bar, or type a color code. **APPLY COLOR** keeps your new color;
**CANCEL** puts the old one back.

- **Main-menu creator:** save your character as usual to keep your colors.
  If you leave without saving, your old colors come back.
- **Barracks:** your colors are kept as soon as you apply them, and saved
  with your game.
- **Armory:** while the picker is open you're only previewing, so feel free
  to try different Locations and Paint Finishes to see how your color looks
  on each. **APPLY COLOR** paints the weapon for real.

Want one of the game's own colors back? Just click its swatch.

Colors+ works with a mouse only; the buttons can't be reached with a
controller.


## Uninstalling

Switch Colors+ off or remove it in your mod manager, or delete the
**ColorsPlus** folder. Your custom colors stay on your characters and
weapons, and your saves load fine without the mod.


## Works with

- [MinervaMagicka's Character Overhaul Suite](https://www.nexusmods.com/starwarszerocompany/mods/291)
- [Smexy's ZCUnlocked](https://www.nexusmods.com/starwarszerocompany/mods/34):
  mostly compatible. Custom colors don't work for its Blaster Bolt or
  Lightsaber colors.
- [Coppershore's Ship Paint and Hangar Lift](https://www.nexusmods.com/starwarszerocompany/mods/134):
  not tested yet.


## Known issues

- Restart the game after installing or updating Colors+. Don't use UE4SS's
  "Reload All Mods"; it can crash or freeze the game.
- Sweeping the mouse quickly across the color swatches can close the
  picker. Your previous color is kept; just open it again.
- The picker's buttons are in English only for now.


## Found a problem?

Let us know what you were customizing (which character or weapon), what
happened, and which other mods you use. It helps a lot if you attach these
two files from the **ColorsPlus** folder:

- `colors_plus_probe.log`
- `colors_plus_performance.log`

They only contain technical details about what the mod did: no
screenshots, saves or personal files. They may mention folder paths on
your PC, so feel free to look them over before sending. Nothing is ever
uploaded automatically.
