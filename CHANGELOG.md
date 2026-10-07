# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Install steps for Zero Company Mod Command and Zero Mod Manager in the
  README.

### Changed

- The armory's Custom Color button now works in every game language.
- Log files are capped at a few megabytes (older entries move to a
  `.previous.log` file next to them) and no longer fill up `UE4SS.log`.
- One download, `ColorsPlus` plus the version, now including the MIT
  license. The separate Testers and Dev downloads are gone.
- A friendlier README for players.

### Removed

- Developer tools that only test builds used.

## [0.5.0] - 2026-10-07

### Added

- Custom Color for the Paint Color of blasters in Armory > Customize Weapon.
  The picker stays open while you change Location and Paint Finish, so you
  can preview your color on each.

## [0.4.1] - 2026-10-07

### Changed

- Less stutter: far fewer full searches of the game's objects while browsing
  color slots, opening the picker and applying a color.

## [0.4.0] - 2026-10-06

### Added

- Custom Color in the barracks character editor. Applied colors stay when
  you leave and are saved with your game.
- Armor wearing a color the palette no longer offers (for example from an
  unlocker mod) can be changed.

### Changed

- The install folder is now `ColorsPlus` (test builds used `Colors_Probe`).

## [0.3.0] and earlier

Test builds. See [docs/development-history.md](docs/development-history.md)
for the detailed notes.
