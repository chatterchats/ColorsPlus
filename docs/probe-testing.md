# Testing Colors+Probe

> Historical discovery checklist. Since v0.2.107 detailed snapshots are manual
> only: use `colors_probe` or an explicit Dev Panel capture. Stock swatch and
> page events still drive lifecycle guards, but no longer collect snapshots.
> Current tester installs are copies under `Mods/Colors_Probe`; use the packaged
> `TESTING.md` for installation and fully restart the game for updates.

The v4 read-only capture succeeded. See
[results and the next milestone](probe-results-2026-09-15.md). No further
repetition of the discovery checklist is needed. The next test is the
[SWZC Dev Panel accent preview](dev-panel-tint-test.md).

## Install and reload

The development mod lives in `src/Colors+Probe`, separately from `src/Colors+`.
The local game installation is linked directly to that directory:

```text
/run/media/chats/e0057d4a-fe46-43eb-a837-db51979c500f/Games/STAR WARS Zero Company (2026)/Star Wars Zero Company/SWZeroCompany/Binaries/Win64/ue4ss/Mods/Colors+Probe
  -> /run/media/chats/e0057d4a-fe46-43eb-a837-db51979c500f/ZComMods/Colors+/src/Colors+Probe
```

The source folder includes `enabled.txt`. Restart the game for the first load
if Reload All Mods does not discover the new folder. Subsequent source edits
are visible through this link; use UE4SS Reload All Mods or restart the game.
No ZIP build or mod-manager reinstall is needed.

## Completed capture: fragment-read diagnostics

The September 15 first successful run recorded 53 snapshots and identified
Clone 8 (`CPD_H_Outfit_Clo001_TORS_TintF`), but every fragment read was
unavailable. That run did not establish the tint values or material targets.
The second capture (12:43 UTC) recorded 26 snapshots: `GetFragments()` succeeded
with `return_type=table`, but every `ForEach` call failed because the returned
table had no such method. No new crash report was present. The v3 reader now
handles numeric-key Lua tables, but its third capture (12:46–12:47 UTC, 33
snapshots) marked every entry invalid: one entry per color slot, five for
Clone 8 Style. No new crash report was present. Those counts are array entries,
not verified material-color fragments or visible tint-zone counts.

The installed UE4SS revision `a1e7f571` explains the remaining mismatch:
[`push_arrayproperty`](https://github.com/UE4SS-RE/RE-UE4SS/blob/a1e7f571/UE4SS/src/LuaType/LuaUObject.cpp#L792)
builds a one-based Lua table using `Operation::GetParam` for each entry;
[`push_objectproperty`](https://github.com/UE4SS-RE/RE-UE4SS/blob/a1e7f571/UE4SS/src/LuaType/LuaUObject.cpp#L397)
turns that operation into `RemoteUnrealParam`. The v4 reader unwraps only values
whose binding `:type()` identifies them as `RemoteUnrealParam` or
`LocalUnrealParam`. Direct UObjects are never blindly unwrapped. The subsequent
v4 capture verified fragment values; this checklist is retained as history.

1. Reload All Mods (or restart), preferably before opening customization.
   The new startup marker is `diagnostics=fragment-read-v4`.
2. Open **Tops**, equip **Clone 8**, then open **Primary Accent**.
3. Hover a stock swatch briefly, then click it. Click a second swatch, pausing
   about a second between actions.
4. Open **Main Color** and click one stock swatch.
5. Leave the customization page, reopen it, and return to **Primary Accent**.
6. Report that the capture is done, or stop and report any crash/error.

No console command, mod-manager reinstall, or custom color entry is needed.
These automatic captures remain read-only; stock swatch clicks still change the character
through the game's normal behavior. This capture does not test save persistence.

New log fields distinguish `fragments.get.status` (call success/error and
return type) from `fragments.iteration.status` (iteration success/error and
visited count). Errors are preserved as bounded single-line messages. Material
color instances also log `get_color.status`. An unreadable fragment array now
reports `material_color_instances=<unavailable>`, not zero; a successfully read
empty array still reports zero. The iterator logs `format=lua-table` for returned
table entries or `format=tarray` for UE4SS's documented `TArray:ForEach` with
`elem:get()`. Numeric table keys are sorted and preserved, including zero-based
and sparse keys. Record-shaped tables are reported as errors, not empty arrays.
Both paths inspect at most 64 entries and explicitly mark truncation.
Each fragment logs its source/value binding types, whether it was unwrapped,
and the result or error of its validity check. An invalid/unreadable entry or
class (or truncation) makes the total material-color count unavailable;
`material_color_instances_observed` is only the successfully identified subset.

## First capture

1. Confirm the UE4SS log contains `[Colors+Probe]` and `Probe ready`.
2. Open the character creator and select **Tops**, then the **Clone 8** torso
   shown in the reference screenshots.
3. Select the red **PRIMARY ACCENT** node.
4. Pause briefly, select two different stock swatches, then visit the other
   color node. Distinguish actual clicks from hover previews when reporting.
5. Leave the customization page and reopen it.
6. Reload all mods with the page open, select another swatch, and confirm the
   log continues without duplicate hook or callback errors.

Automatic snapshots only read game data. Changes caused by selecting the game's stock
swatches still follow the game's normal customization behavior.

## Manual snapshot

With the color-selection page open, enter this in the **game's Unreal console**
(not a Lua REPL or terminal):

```text
colors_probe
```

The command retries any pending hooks and takes a snapshot on the game thread.
Stock swatch clicks no longer collect snapshots automatically. Native
equip/preview events still retry missing Blueprint hooks.

## Log location and interpretation

The log is appended and flushed to `src/Colors+Probe/colors_plus_probe.log`,
also accessible as `Mods/Colors+Probe/colors_plus_probe.log` through the link.
Every message is mirrored to `UE4SS.log`. If the dedicated log cannot be opened,
the startup message says so.

Each `SNAPSHOT … BEGIN/END` block contains:

- Runtime generation, event name, and UObject identities.
- Root/current slot display names, tags, and equipped-part identifiers.
- Root child-slot summaries when available.
- Selected/hovered part separately from equipped or previewed parts.
- The selected/event slot's fragment identities and classes.
- Material-color instance values as **linear RGBA**, not display-space hex.
- The material parameter, material slot names, and target slot tags.

`<unavailable>` marks an unreadable field; it must not be interpreted as zero or
an empty target. An empty default/no-color slot may have no color fragment.
Manual/page-activation discovery lists auxiliary ViewModel **candidates**, not
a proven association with one page. The exact auxiliary-object event captures
and native slot events provide additional evidence for identifying the active
objects.

Explicit non-forced snapshots are deduplicated. A manual command forces output.
Pending hooks are reported once per runtime; four finite startup attempts plus
native events/manual commands handle classes that load later. There is no
continuous UObject poll or object-construction observer. The optional Dev Panel
helper separately polls its action-counter file while registered.

Local mocked tests validate hook routing, delayed snapshots, stale-object
handling, screen cancellation, and reload cleanup. Actual field accessibility,
game behavior, and compatibility still require this in-game capture.
