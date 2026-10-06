# Color-picker research

## Current conclusion

The read-only Clone 8 probe now verifies both color slots, live material-color
fragments, linear RGBA values, and material targets. See
[the successful September 15 capture](probe-results-2026-09-15.md). Custom
color writes and persistence have not yet been tested.

The customization runtime supports arbitrary colors for tint-backed categories.
The first prototype should target one currently selected color zone on one
humanoid armor torso.

The armor material's existing tint mask determines which pixels belong to the
zone. Colors+ should preserve that targeting and replace only the selected
zone's runtime color value.

## Reference evidence

- `UCustomizationFragmentInstanceMaterialColor` stores an `FLinearColor` and
  exposes Blueprint-callable `GetColor` and `SetColor` functions.
- `FCustomizationTraitMaterialTarget` identifies applicable slot tags, material
  slots, and the material parameter name.
- `UCustomizationFragmentInstanceSlot` carries instanced fragment arrays and
  exposes APIs for applying a part together with fragments.
- `UBitReactorCustomizationSlotViewModel` exposes the active fragments and
  part-equipping operations used by the customization UI.
- The humanoid outfit hierarchy and individual piece categories contain five
  child-slot subobjects in the dump. Their indices do not prove five visible
  color zones: the supplied Clone 8 screenshots show two color nodes, with the
  red one selected as PRIMARY ACCENT. The successful runtime capture now maps
  Main Color to `Color 01` and Primary Accent to `Color 02` for Clone 8.
- `BP_CPD_H_Outfit_Color_Base_C` is accepted by
  `br.Customization.Accepts.Outfit.Color` slots and supplies one
  `CustomizationFragmentMaterialColor`.
- Engine Lua types expose a two-dimensional slider, HSV/RGB conversions, and
  linear-color-to-hex formatting suitable for a picker UI.

The local evidence comes from the sibling
`ZeroCompany_RE_Reference_v2/reference` corpus, principally:

- `native_headers/current/BitReactorCore/Public/CustomizationFragmentInstanceMaterialColor.h`
- `native_headers/current/BitReactorCore/Public/CustomizationTraitMaterialTarget.h`
- `native_headers/current/BitReactorCore/Public/CustomizationFragmentInstanceSlot.h`
- `native_headers/current/BitReactorGame/Public/BitReactorCustomizationSlotViewModel.h`
- `indexes/all_content_paths.tsv`
- `mappings/jmap/game_specific_cdo_values.jsonl`
- `types/all_lua_types/Synthesis.lua`
- `types/all_lua_types/Engine.lua`

## Prototype boundary

1. Activate only while the current customization slot accepts outfit colors.
2. Initially allowlist one armor torso for predictable visual testing.
3. Preserve the selected stock swatch as the part and material-target baseline.
4. Clone its runtime fragment array before preview mutation.
5. Change only the `UCustomizationFragmentInstanceMaterialColor` belonging to
   the currently selected zone.
6. Restore the original fragments on cancel and commit the modified fragments
   only on acceptance.

## Questions requiring runtime inspection

- The exact gameplay tag, display name, and role of each child slot.
- Whether calling `SetColor` immediately refreshes the preview or requires a
  slot ViewModel re-equip/refresh operation.
- Whether the UI edits a disposable preview character or the persisted
  character data directly.
- Whether modified fragment instances survive save/load, presets, recruitment,
  portraits, and later customization sessions.
- How extreme linear RGB values behave after the armor material's tint,
  weathering, and lighting operations.

Saved user swatches are separate from character customization persistence and
will require mod-owned configuration storage.

## First probe

The initial `src/Colors+Probe` read probe observes auxiliary ViewModel
selection methods, item-page lifecycle methods, and native slot equip/preview
methods. Its automatic observations do not clone fragments, call setters,
save characters, create UI, or inspect material textures. The v0.2.0 optional
Dev Panel action now adds an isolated cloned-fragment preview experiment;
see `dev-panel-tint-test.md`. In-game write validation remains pending.

Hook registration uses the documented UE4SS distinction: native UFunctions
receive the observer as the third (post) callback; Blueprint UFunctions receive
it as the second argument. Both returned IDs are retained for removal. See the
[UE4SS RegisterHook documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/registerhook.md).
