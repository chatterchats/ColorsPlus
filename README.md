# Colors+

[![UE4SS](https://img.shields.io/badge/framework-UE4SS-6f42c1)](https://github.com/UE4SS-RE/RE-UE4SS)
[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Colors%2B-d98f40)](https://www.nexusmods.com/starwarszerocompany/mods/314)

Colors+ is a UE4SS Lua mod for **Star Wars: Zero Company** that adds a
**Custom Color** picker to the game's customization screens: any color,
not just the preset swatches, with a live preview.

It writes the chosen color into the same customization data a swatch pick
uses, so the game saves it like any other color. The mod never calls save
functions or edits save files, and colors stay after it is removed.

## Features

- A color box, hue slider and hex input under supported color choices.
- **Main-menu character creator** and the **barracks** character editor:
  clothing and armor, hair, skin (including race-specific skin bundles such
  as Zabrak tones), makeup, tattoos, and horn and scar HSV adjustments.
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

## Requirements

- **Star Wars: Zero Company** (Steam). The metadata lists game builds
  `25134257` and `24874058` as tested.
- [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html): the
  recommended build for Zero Company (v3.0.1 Beta, `a1e7f571`).

## Installation

Download the release ZIP from
[Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/314). Its
top-level folder is `ColorsPlus`, and it carries metadata for Zero Company
Mod Command (`modinfo.json`) and Zero Mod Manager (`zcom-mod.json`).

- **Zero Company Mod Command:** drag the ZIP into the Hangar Bay.
- **Zero Mod Manager:** open Install and drop the ZIP in.
- **By hand:** copy the `ColorsPlus` folder into
  `SWZeroCompany/Binaries/Win64/ue4ss/Mods/`.

Restart the game after installing or updating; don't use UE4SS's Reload All
Mods. When updating by hand, copy over the existing folder so `Recovery/` is
kept. Test builds up to 0.3.0 installed as `Colors_Probe`; delete that
folder, since two copies would both hook the editor.

Player instructions (also the basis of the mod page) are in
[`src/ColorsPlus/README.md`](src/ColorsPlus/README.md).

## Using Colors+

| Where | Apply | Leaving |
| --- | --- | --- |
| Main-menu creator | Writes the character's color for this visit | Save the character to keep it; leaving without saving restores the original |
| Barracks editor | Writes the character's color | Kept (the barracks has no save step) and saved with the game |
| Armory | Writes the weapon's paint; the game saves it at once | Nothing to do |

Picking a stock swatch afterwards replaces a custom color as usual.

## Troubleshooting

Colors+ writes two logs beside the installed mod:

- `colors_plus_probe.log`: detailed events (capped at 4 MB).
- `colors_plus_performance.log`: 5-second timing summaries while the picker
  is in use (capped at 1 MB).

At the cap, a log moves to `<name>.previous.log` and a fresh one starts.
`UE4SS.log` remains the startup and crash log. Bug reports should include
both Colors+ logs, the game build, the UE4SS build and other customization
mods in use.

Unfinished edits are journaled under `Recovery/` and replayed only after a
Lua reload in the same game session; journals from an earlier session are
archived, never replayed.

## Repository layout

```text
.
├── .github/workflows/release-nexus.yml   # manual Nexus release
├── CHANGELOG.md                          # player-facing notes per release
├── LICENSE
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
    ├── package.py                        # release ZIP
    └── run-tests.sh
```

The armory support lives in `armory_ui.lua` (button and picker host) and
`armory_paint.lua` (preview drafts and Apply); their header comments
describe the measured game behaviour they rely on.

[`Zero_Company_UE4SS_Lua_Guide.md`](Zero_Company_UE4SS_Lua_Guide.md) and
[`docs/practical-ue4ss-ui-modding-notes.md`](docs/practical-ue4ss-ui-modding-notes.md)
collect general UE4SS lessons shared with the author's other Zero Company
mods.

## Development

```bash
tools/run-tests.sh            # every test (needs luajit)
tools/run-tests.sh armory_ui  # selected tests
```

Tests are plain LuaJIT scripts with in-memory fakes of the UE4SS API; the
runner lays out `src/ColorsPlus` in a temporary folder and runs each test
against it. They don't replace in-game testing: the mod works on generated
Blueprint classes, live widget trees and the game's own customization data.

To try a change, copy `src/ColorsPlus` into the game's `ue4ss/Mods` folder
and restart the game. Before a release, check at least:

- main-menu creator: Apply, Cancel, save, and leaving without saving;
- barracks editor: Apply, leave, then save and reload the game;
- armory: change Location and Paint Finish with the picker open, then Apply
  and Cancel;
- a Zabrak skin tone, a Default (empty) slot and an unlocker-mod armor color;
- the armory with the game in another language.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat(armory): …`, `fix(hub): …`, `chore(release): v1.0.0`).

## Releasing

The manually run **Release to Nexus Mods** workflow checks that every
version declaration agrees, runs the tests, builds the ZIP with
`tools/package.py` and uploads it as `ColorsPlus v#.#.#.zip` with that
release's changelog. Running it publishes a release.

1. Add player-facing notes under `## [Unreleased]` in
   [`CHANGELOG.md`](CHANGELOG.md), grouped as Added / Changed / Fixed /
   Removed.
2. Bump the version (`patch`, `minor` or `major`):

   ```bash
   python3 tools/bump_version.py minor
   ```

   This updates `modinfo.json`, `zcom-mod.json`, `Scripts/main.lua` and the
   player README title, and turns `[Unreleased]` into the new version.
3. Run `tools/run-tests.sh`, then `python3 tools/package.py` to build
   `dist/ColorsPlus-#.#.#.zip`, and try it with a clean manual install and a
   mod manager. A built version is immutable: the packager refuses to
   overwrite a ZIP with different contents.
4. Commit (`chore(release): v#.#.#`), merge to `main` and push.
5. Run **Release to Nexus Mods** from the Actions tab. It needs the
   `NEXUSMODS_API_KEY` repository secret and exactly one active file on the
   [Nexus page](https://www.nexusmods.com/starwarszerocompany/mods/314).

## License

[MIT](LICENSE) © 2026 Chatter Chats. The release ZIP includes the license.
