# Colors+

An experimental [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for
**Star Wars: Zero Company** that adds a custom color picker to character
customization. A **Custom Color** button appears under supported color
choices; it opens an HSV picker (color box, hue slider, hex input) with a live
preview on the character.

## Status

The active mod is **Colors+Probe** (`src/Colors+Probe`). It supports clothing
and armor colors, hair, skin (including race-specific skin bundles such as
Zabrak tones), makeup, tattoos, horns and scar HSV adjustments. The base
game's eye choices are not supported.

- **Apply Color** keeps the choice for the current editor visit; save the
  character normally to keep it. **Cancel** returns to the previous color.
- Unfinished edits are journaled under `DevPanel/` and restored after a Lua
  reload; journals from a previous game process are archived, never replayed.
- The picker writes `colors_plus_performance.log` automatically (5-second
  summaries, environment line, lookup timings). Detailed events go to
  `colors_plus_probe.log`.

Recent work is in [CHANGELOG.md](CHANGELOG.md). How a color edit works is in
[docs/architecture.md](docs/architecture.md); earlier status notes are in
[docs/status-history.md](docs/status-history.md). General UE4SS UI lessons
are in [docs/practical-ue4ss-ui-modding-notes.md](docs/practical-ue4ss-ui-modding-notes.md).

`src/Colors+` is the original bootstrap placeholder for the eventual release
mod.

## Requirements

- **Star Wars: Zero Company**
- A working [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html)
  installation (developed against build `a1e7f571`)

## Packages

`python3 tools/package-testers.py` builds two verified ZIPs (with SHA-256
files) in `dist/`, both with a `Colors_Probe/` root:

- **`ColorsPlus-Testers-<version>.zip`**: the player build. Only scripts
  reachable from `main.lua` without `dev_tools.lua` (picker, editing backend,
  recovery, performance log), plus assets, manifests, the tester guide and
  `DevPanel/actions.lua` (which also keeps the journal folder present).
- **`ColorsPlus-Dev-<version>.zip`**: everything, including probes, traces,
  console commands and the SWZC Dev Panel integration (`dev_tools.lua`).

Both exclude logs, recovery journals and panel state. A released version is
immutable: the packager refuses to overwrite an existing ZIP with different
contents, so bump the version in `Scripts/main.lua`, `modinfo.json`,
`zcom-mod.json`, `DevPanel/actions.lua` and `TESTING.md` first.

To install, extract `Colors_Probe/` into
`SWZeroCompany/Binaries/Win64/ue4ss/Mods/` and restart the game. Copy over an
existing install rather than deleting it, so recovery files are kept.

## Development

```bash
tools/run-tests.sh   # every test, each against the folder it targets
```

Tests are plain LuaJIT scripts with in-memory fakes of the UE4SS API
(`luajit tests/<name>_test.lua src/Colors+Probe/Scripts`). Runtime behavior
still needs in-game verification: the reference corpus does not contain the
cooked implementation of the customization preview and save lifecycle.

```text
.
├── CHANGELOG.md
├── docs/                    # research, testing notes, status history
├── src/
│   ├── Colors+Probe/        # active mod (Scripts/, Assets/, DevPanel/)
│   └── Colors+/             # original bootstrap placeholder
├── tests/                   # LuaJIT test scripts
└── tools/
    ├── package-testers.py   # player + dev ZIPs
    └── run-tests.sh
```
