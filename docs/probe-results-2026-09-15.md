# Successful read-only armor probe — September 15, 2026

## Capture

Source: `src/Colors+Probe/colors_plus_probe.log`, session marked
`diagnostics=fragment-read-v4`, snapshots 1–31, 12:50:39–12:51:01 UTC.
All 31 snapshots completed with no diagnostic `status=error` and no reported
unreadable fragments. The crash directory still contained only the earlier
08:27 local-time crash. This establishes this run's read-path success, not
general crash freedom or custom-color write support.

Equipped torso: **Clone 8**, asset
`CustomizationPartDefinition:CPD_H_Outfit_Clo001_TORS_TintF`.

## Verified slot targeting

Slot tags below share the prefix `br.Customization.Slot.Character.Outfit.Torso`.

| UI / source | Slot suffix | Color parameter | Material slots |
| --- | --- | --- | --- |
| Main Color | `.Color.Primary` | `Color 01` | `MI_TORS, MI_ARMS, MI_LEGS, MI_BOOT, MI_HELM, MI_PACK` |
| Primary Accent | `.Color.Secondary` | `Color 02` | Same list |
| Clone 8 Style fragment | `.Mesh` | `Color 02` | `MI_TORS` only |

Each target also carries the slot tag
`br.Customization.Slot.Character.Outfit.Torso.Mesh`. The broad material-name
list does not establish that selecting Tops recolors other outfit pieces;
slot-tag targeting must be preserved.

Both color slots return exactly one valid
`/Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor`. Their
object paths are under the preview character's `CustomizationInstance`, not
global customization definition assets. The Lua array entries identify as
`RemoteUnrealParam`; unwrapping produces valid `UObject` values. `GetColor()`
returns a readable Lua table.

## Observed colors

Rounded linear RGBA, not display-space hex:

| Snapshot | Slot / equipped swatch | RGBA |
| --- | --- | --- |
| 3 | Main Color / Red 6 | `(0.071565, 0.014313, 0.014313, 1)` |
| 10 | Main Color / White | `(0.637597, 0.623960, 0.610496, 1)` |
| 12 | Main Color / Red 2 | `(0.085, 0.03145, 0.03145, 1)` |
| 4 | Primary Accent / White | `(0.637597, 0.623960, 0.610496, 1)` |
| 19 | Primary Accent / Blue 5 | `(0.033, 0.058667, 0.11, 1)` |
| 26 | Clone 8 Style / its separate color fragment | `(0.07, 0.07, 0.07, 0)` |

The Style array contains five fragments: Mesh, Foley, MaterialTexture,
MaterialColor, and OverrideSlots. These are not five color zones. Its separate
`Color 02` fragment has alpha zero; alpha semantics and override precedence
are not established. Do not confuse it with the selected accent fragment or
force all fragment alpha values to one.

## Selection and lifetime observations

Snapshots 9–12 distinguish previewed swatches from equipped fragment values:
hovering White while Red 6 is equipped leaves the returned color at Red 6;
clicking White changes it to White. Hovering Red 2 then leaves White's value
until Red 2 is equipped. The same distinction appears for accent swatches.
Treat this API as the equipped-fragment path for these observed events, not
as an established way to retrieve hover-preview fragments.

Fragment identities change on stock swatch equip (Main Color instances
`_192` → `_204` → `_207` in snapshots 9–12). Reacquire and validate the selected
slot's fragment before each operation; do not retain a fragment across swatch
changes and assume it remains current.

## Next milestone

The initial read-only probe is complete for Clone 8's two color slots.
Next is a user-triggered, reversible single-zone custom-tint test: resolve
the selected color slot, preserve the original value/target, apply one test
color through an isolated preview path, verify only the intended zone changes,
and restore it. No custom writes have been performed yet. Preview refresh,
cancel/accept, persistence, reload restoration, and the picker UI remain unproven.

Auxiliary root/selected fields are still invalid and `ActiveTab` reads `None`.
Those gaps did not block native slot-event captures, but should not be used as
trusted context for the write prototype without further validation.
