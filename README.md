# Colors+

An experimental [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for
**Star Wars: Zero Company** that adds a custom color picker to character
customization. A **Custom Color** button appears under supported color
choices; it opens an HSV picker (color box, hue slider, hex input) with a live
preview on the character.

## Status

The mod lives in `src/ColorsPlus`; developer tools live in `src/Colors+Probe`
(see [Packages](#packages)). It supports clothing
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

## Requirements

- **Star Wars: Zero Company**
- A working [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html)
  installation (developed against build `a1e7f571`)

## Packages

`python3 tools/package-testers.py` builds two verified ZIPs (with SHA-256
files) in `dist/`, both with a `Colors_Probe/` root (the install folder; its
rename to `ColorsPlus` is planned for v0.4):

- **`ColorsPlus-Testers-<version>.zip`**: the player build, exactly
  `src/ColorsPlus`: picker, editing backend, recovery, performance log,
  assets, manifests, the tester guide and `DevPanel/actions.lua` (which also
  keeps the journal folder present). The packager checks that every mod
  script is reachable from `main.lua` and that none needs a developer script.
- **`ColorsPlus-Dev-<version>.zip`**: the mod plus `src/Colors+Probe/Scripts`
  overlaid into the same `Scripts/` folder: traces, the compatibility survey,
  console commands and the SWZC Dev Panel integration. `main.lua` attaches
  them when `dev_tools.lua` is present. They can't be a separate UE4SS mod:
  each mod runs in its own Lua state, and the tools read the picker's runtime.

Both exclude logs, recovery journals and panel state. A released version is
immutable: the packager refuses to overwrite an existing ZIP with different
contents, so bump the version in `src/ColorsPlus` (`Scripts/main.lua`,
`modinfo.json`, `zcom-mod.json`, `DevPanel/actions.lua`, `TESTING.md`) first.

To install, extract `Colors_Probe/` into
`SWZeroCompany/Binaries/Win64/ue4ss/Mods/` and restart the game. Copy over an
existing install rather than deleting it, so recovery files are kept.

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
│   ├── ColorsPlus/          # the mod (Scripts/, Assets/, DevPanel/, manifests)
│   └── Colors+Probe/        # developer tools (Scripts/ only; Dev package)
├── tests/                   # LuaJIT test scripts
└── tools/
    ├── package-testers.py   # player + dev ZIPs
    └── run-tests.sh
```
