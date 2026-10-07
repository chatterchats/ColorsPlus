# Colors+

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for
**Star Wars: Zero Company** that adds a custom color picker to character
customization, in both the main-menu creator and the in-game (barracks)
character editor, and to weapon paint in the armory. A **Custom Color** button appears under supported color
choices; it opens an HSV picker (color box, hue slider, hex input) with a live
preview on the character.

## Status

The mod lives in `src/ColorsPlus`; developer tools live in `src/Colors+Probe`
(see [Packages](#packages)). It supports clothing
and armor colors, hair, skin (including race-specific skin bundles such as
Zabrak tones), makeup, tattoos, horns and scar HSV adjustments, and the
Paint Color of blasters in Armory > Customize Weapon. The base game's eye
choices and lightsabers are not supported; ZCUnlocked's bolt and blade rows
are left to ZCUnlocked. The mod is mouse only. Players' guide:
[`src/ColorsPlus/README.txt`](src/ColorsPlus/README.txt).

- **Apply Color** keeps the choice for the current editor visit. In the
  main-menu creator, save the character normally to keep it; leaving without
  saving restores the original. In the in-game (hub) editor, leaving the
  editor keeps it (the hub has no separate save step). In the armory, Apply
  paints the weapon and the game saves it at once. **Cancel** returns to the
  previous color.
- Unfinished edits are journaled under `Recovery/` and restored after a Lua
  reload; journals from a previous game process are archived, never replayed.
- The picker writes `colors_plus_performance.log` automatically (5-second
  summaries, environment line, lookup timings). Detailed events go to
  `colors_plus_probe.log`. Both are capped (4 MB / 1 MB, one
  `.previous.log` copy each).

Recent work is in [CHANGELOG.md](CHANGELOG.md). How a color edit works is in
[docs/architecture.md](docs/architecture.md); earlier status notes are in
[docs/status-history.md](docs/status-history.md). General UE4SS UI lessons
are in [docs/practical-ue4ss-ui-modding-notes.md](docs/practical-ue4ss-ui-modding-notes.md).

## Requirements

- **Star Wars: Zero Company**
- A working [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html)
  installation: the recommended build for Zero Company, v3.0.1 Beta
  `a1e7f571`

## Packages

`python3 tools/package.py` builds two verified ZIPs (with SHA-256
files) in `dist/`, both with a `ColorsPlus/` root (the install folder; it
was `Colors_Probe/` through v0.3.0):

- **`ColorsPlus-<version>.zip`** (`-Testers-` through 0.5.0): the player
  build, exactly `src/ColorsPlus`: picker, editing backend, recovery,
  performance log, assets, manifests, the player guide `README.txt` and
  `Recovery/README.txt` (which keeps
  the journal folder present after extraction). The packager checks that every mod
  script is reachable from `main.lua` and that none needs a developer script.
- **`ColorsPlus-Dev-<version>.zip`**: the mod plus `src/Colors+Probe/Scripts`
  overlaid into the same `Scripts/` folder: traces, the compatibility survey
  and console commands (`colors_picker`, `colors_compat`, `colors_screens`).
  `main.lua` attaches
  them when `dev_tools.lua` is present. They can't be a separate UE4SS mod:
  each mod runs in its own Lua state, and the tools read the picker's runtime.

Both exclude logs, recovery journals and panel state. A released version is
immutable: the packager refuses to overwrite an existing ZIP with different
contents, so bump the version in `src/ColorsPlus` (`Scripts/main.lua`,
`modinfo.json`, `zcom-mod.json`, `README.txt`) first.

To install, extract `ColorsPlus/` into
`SWZeroCompany/Binaries/Win64/ue4ss/Mods/` and restart the game. Copy over an
existing `ColorsPlus` install rather than deleting it, so recovery files are
kept. When upgrading from v0.3.0 or earlier, delete the old `Colors_Probe`
folder first: there is no automatic migration, and two copies would both
hook the editor.

## Development

```bash
tools/run-tests.sh            # every test
tools/run-tests.sh tint skin  # selected tests
```

Tests are plain LuaJIT scripts with in-memory fakes of the UE4SS API. The
runner lays out the Dev package (mod plus developer scripts) in a temporary
folder and runs each test against it. Runtime behavior
still needs in-game verification: the reference corpus does not contain the
cooked implementation of the customization preview and save lifecycle.

```text
.
├── CHANGELOG.md
├── docs/                    # architecture, status history, UE4SS notes
├── src/
│   ├── ColorsPlus/          # the mod (Scripts/, Assets/, Recovery/, manifests)
│   └── Colors+Probe/        # developer tools (Scripts/ only; Dev package)
├── tests/                   # LuaJIT test scripts
└── tools/
    ├── package.py           # player + dev ZIPs
    └── run-tests.sh
```
