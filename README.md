# Colors+

[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Colors%2B-d98f40)](https://www.nexusmods.com/starwarszerocompany/mods/314)
[![UE4SS](https://img.shields.io/badge/framework-UE4SS-6f42c1)](https://github.com/UE4SS-RE/RE-UE4SS)
[![License: MIT](https://img.shields.io/badge/license-MIT-2f7d4f)](LICENSE)

Colors+ is a UE4SS Lua mod for **Star Wars: Zero Company** that adds a
**Custom Color** picker to the game's customization screens: any color, not
just the preset swatches, with a live preview.

It writes the chosen color into the same customization data a swatch pick
uses, so the game saves it like any other color. The mod never calls save
functions or edits save files, and colors stay after it is removed.

## Features

- A color box, hue slider and hex input under supported color choices.
- **Main-menu character creator** and the **barracks** character editor:
  clothing and armor, hair, skin (including race-specific skin bundles such
  as Zabrak tones), makeup, tattoos, and horn and scar HSV adjustments.
- **Droids:** head, body and legs colors on astromechs in the creator and
  the barracks, including the story droid BR-1.
- **Armory → Customize Weapon:** the Paint Color of blasters. Drafts only
  touch the armory preview, so Location and Paint Finish can be changed
  while the picker is open.
- **Apply** keeps the color; **Cancel** returns to the previous one.
- Armor wearing a color the palette no longer offers (for example from an
  unlocker mod) can still be changed.
- Works in every game language; the picker's own buttons are English.

Not supported: the base game's eye choices, lightsabers, and ZCUnlocked's
Bolt Color and blade rows (their colors come from ZCUnlocked's own store).
Mouse only.

## Using Colors+

Click **CUSTOM COLOR** under a color choice, pick a color, then **Apply** or
**Cancel**.

| Where | Apply | Leaving |
| --- | --- | --- |
| Main-menu creator | Writes the character's color for this visit | Save the character to keep it; leaving without saving restores the original |
| Barracks editor | Writes the character's color | Kept (the barracks has no save step) and saved with the game |
| Armory | Writes the weapon's paint; the game saves it at once | Nothing to do |

Picking a stock swatch afterwards replaces a custom color as usual. Player
instructions (also the basis of the mod page) are in
[`src/ColorsPlus/README.md`](src/ColorsPlus/README.md).

## Requirements

- **Star Wars: Zero Company**
- **UE4SS** for Zero Company: the recommended build (v3.0.1 Beta,
  `a1e7f571`)

| Steam build | Status |
| --- | --- |
| [25134257](https://steamdb.info/app/2075800/patchnotes/) | Tested |
| 24874058 | Tested |

Steam is the tested launcher. Later builds may work but are unverified until
tested.

## Installation

Download the release ZIP from
[Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/314), not
GitHub's source-code archive. The ZIP keeps `ColorsPlus` as its top-level
folder and includes metadata for both mod managers below.

### With a mod manager

- **[Zero Mod Manager](https://github.com/stellamarislabs/zero-mod-manager)**
  (formerly ZCOM Mod Manager): open **Install**, drop in the ZIP, then
  confirm Colors+ is enabled under **Mods**.
- **[Zero Company Mod Command](https://github.com/EnvianMods/ZeroCompanyModCommand)**:
  drag the ZIP into the **Hangar Bay** and check that it's enabled.

### By hand

1. Install UE4SS for Star Wars: Zero Company.
2. Extract the `ColorsPlus` folder into
   `SWZeroCompany/Binaries/Win64/ue4ss/Mods/`.
3. Check that `ue4ss/Mods/ColorsPlus/Scripts/main.lua` exists. Install the
   whole folder; `main.lua` loads the other modules and `Assets/`.
4. If your UE4SS setup ignores the packaged `enabled.txt`, add
   `ColorsPlus : 1` to `ue4ss/Mods/mods.txt`.

### Updating and uninstalling

Close the game, then install the new ZIP the same way. By hand, copy it over
the old folder so `Recovery/` is kept. Only one copy may be installed: test
builds up to 0.3.0 used a `Colors_Probe` folder, so delete that. Restart the
game after installing or updating; don't use UE4SS's Reload All Mods.

To uninstall, disable or remove it in your mod manager, or delete the
`ColorsPlus` folder. Custom colors stay on your characters and weapons, and
saves load fine without the mod.

## Compatibility

- **[Character Overhaul Suite](https://www.nexusmods.com/starwarszerocompany/mods/291)**
  (MinervaMagicka): compatible.
- **[ZCUnlocked](https://www.nexusmods.com/starwarszerocompany/mods/34)**
  (Smexy): mostly compatible. Its Bolt Color and lightsaber blade rows don't
  get the button; those colors come from ZCUnlocked's own store.
- **[Ship Paint and Hangar Lift](https://www.nexusmods.com/starwarszerocompany/mods/134)**
  (Coppershore): not tested yet.

## Troubleshooting

Colors+ writes two logs beside the installed mod:

- `colors_plus_probe.log`: detailed events (capped at 4 MB).
- `colors_plus_performance.log`: 5-second timing summaries while the picker
  is in use (capped at 1 MB).

At the cap, a log moves to `<name>.previous.log` and a fresh one starts.
`UE4SS.log` remains the startup and crash log.

Sweeping the mouse quickly across the swatches can close the picker; the
previous color is kept, so just open it again.

### Reporting a bug

Open an [issue](https://github.com/chatterchats/ColorsPlus/issues) with:

- the game build and UE4SS version;
- other customization mods installed;
- what you were customizing (character race, slot or weapon) and the steps
  to reproduce it; and
- `colors_plus_probe.log`, `colors_plus_performance.log` and `UE4SS.log`.

## How it works

A color edit is drafted on the game's customization preview (the armory's
preview weapon, or the editor's preview character), so the real character or
weapon is only written on **Apply**. The exception is Zabrak skins with a
material swap, which are drafted on the character itself with the original
kept for Cancel. Apply writes the color into the live customization
fragment, the same object a swatch pick creates, and refreshes it. Every step re-finds its objects by name and
checks them first; anything unexpected is refused instead of guessed.

Unfinished edits are journaled under `Recovery/` and replayed only after a
Lua reload in the same game session; journals from an earlier session are
archived, never replayed.

See [docs/architecture.md](docs/architecture.md) for the character editors.
The armory lives in `armory_ui.lua` (button and picker host) and
`armory_paint.lua` (preview drafts and Apply); their header comments
describe the measured game behaviour they rely on.

## Repository layout

```text
.
├── .github/workflows/release-nexus.yml   # manual Nexus release
├── CHANGELOG.md                          # player-facing notes per release
├── LICENSE
├── README.md
├── Zero_Company_UE4SS_Lua_Guide.md       # general UE4SS lessons
├── docs/
│   ├── architecture.md                   # how a character color edit works
│   ├── development-history.md            # detailed notes through 1.0
│   ├── nexus/                            # mod page summary and BBCode description
│   ├── practical-ue4ss-ui-modding-notes.md
│   └── ...                               # older investigations and reviews
├── src/ColorsPlus/                       # the distributable mod folder
│   ├── Assets/                           # picker gradient textures
│   ├── Recovery/README.txt               # keeps the journal folder in the ZIP
│   ├── Scripts/                          # main.lua and modules
│   ├── README.md                         # player guide
│   ├── enabled.txt
│   ├── modinfo.json                      # Zero Company Mod Command
│   └── zcom-mod.json                     # Zero Mod Manager
├── tests/                                # LuaJIT tests with UE4SS fakes
└── tools/
    ├── bump_version.py                   # version bump + changelog promotion
    ├── generate-picker-gradients.mjs     # regenerates Assets/*.png
    ├── nexus_changelog.py                # a release's notes as Nexus text
    ├── package.py                        # release ZIP (adds LICENSE)
    └── run-tests.sh
```

`src/ColorsPlus` is the distributable folder; `tools/package.py` zips it with
the LICENSE and checks every script is reachable from `main.lua`.

## Development

1. Clone the repository and copy `src/ColorsPlus` into the game's
   `ue4ss/Mods` folder.
2. Run the tests (needs `luajit`):

   ```bash
   tools/run-tests.sh            # every test
   tools/run-tests.sh armory_ui  # selected tests
   ```

3. Restart the game and test in game: the mod works on generated Blueprint
   classes, live widget trees and the game's own customization data, which
   the tests only fake.

Before a release, check at least:

- main-menu creator: Apply, Cancel, save, and leaving without saving;
- barracks editor: Apply, leave, then save and reload the game;
- armory: change Location and Paint Finish with the picker open, then Apply
  and Cancel;
- a Zabrak skin tone, a Default (empty) slot and an unlocker-mod armor color;
  and
- the armory with the game in another language.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat(armory): …`, `fix(hub): …`, `chore(release): v1.0.0`).

## Releasing

The manually run **Release to Nexus Mods** workflow publishes a release; use
`tools/package.py` for a local, package-only build.

1. Add player-facing notes under `## [Unreleased]` in
   [`CHANGELOG.md`](CHANGELOG.md), grouped as Added / Changed / Fixed /
   Removed.
2. Bump the version with `patch`, `minor` or `major`:

   ```bash
   python3 tools/bump_version.py minor
   ```

   It updates `modinfo.json`, `zcom-mod.json`, `Scripts/main.lua` and the
   player README title, and turns `[Unreleased]` into the new version.
3. Run `tools/run-tests.sh` and `python3 tools/package.py`, then check
   `dist/ColorsPlus-#.#.#.zip` with a mod manager and a clean manual install.
   A built version is immutable: the packager refuses to overwrite a ZIP with
   different contents.
4. Commit (`chore(release): v#.#.#`), merge to `main` and push.
5. Run **Release to Nexus Mods** from the **Actions** tab. It needs the
   `NEXUSMODS_API_KEY` repository secret.

The workflow:

- requires `modinfo.json`, `zcom-mod.json`, `main.lua` and the player README
  title to hold the same `#.#.#` version;
- reads that version's notes from `CHANGELOG.md`;
- runs the tests and builds the ZIP with `tools/package.py`; and
- uploads it to Nexus as `ColorsPlus v#.#.#.zip`, finding the mod and its
  single active file through the API (exactly one active file is required).

## Contributing

Bug reports, compatibility findings and focused pull requests are welcome
through [Issues](https://github.com/chatterchats/ColorsPlus/issues) and
[Pull Requests](https://github.com/chatterchats/ColorsPlus/pulls). Keep the
game's own customization data as the only place a color is stored, and
refuse unrecognized layouts rather than guessing.

## Support

- Downloads: [Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/314)
- Changes: [`CHANGELOG.md`](CHANGELOG.md)
- Bugs and requests: [GitHub Issues](https://github.com/chatterchats/ColorsPlus/issues)

## License

[MIT](LICENSE) © 2026 Chatter Chats. The release ZIP includes the license.
