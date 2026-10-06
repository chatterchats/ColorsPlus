# v0.2.56: multiple edited slots and data-driven color compatibility

## Changes

The visible picker still owns one draft at a time, but applied edits now have
independent editor, Default-selection and preview recovery state per slot.
Opening another compatible color slot no longer requires restoring the first.
Reopening an already-edited slot selects its existing edit record.

Cancel/timeout discard the current draft, retaining earlier Applies. Restore is
now Restore-all: it restores every owned edited slot to its captured baseline.
Native stock replacement is preserved for the affected slot, without discarding
other slots. Native Save remains responsible for committing the character.

Each slot has a separate cancellable action namespace and recovery journals.
Existing unprefixed journals remain zone 1; zones 2–32 use zoneN_ prefixes.
All are subject to the existing same-process recovery / cold-start quarantine
gate. The 32-record cap bounds memory, scans and pending work; it is not a slot
allowlist. Only one draft may be active, and incomplete recovery blocks new edits.

Compatibility now follows material/color data rather than the prior swatch/race
allowlists. Ordinary colors may have 1–16 distinct mesh targets; optional missing
targets are recorded explicitly and must remain absent. Skin still requires its
verified three-fragment bundle, race tag, color/scalar parameters and target shape.
Source tint-enable correction applies to compatible Outfit-targeted skin scalars,
not just Human_0B1. The preview captures its actual face material's parent identity
instead of requiring the Skin Tone 5 material. No shared parent material is edited.

Non-outfit palettes with an explicit None entry can use the same temporary native
selection handoff, provided the chosen swatch resolves to compatible color data.
Style-only/non-color data, eyes, ambiguous owners, and stale/replaced targets still
refuse. There must still be a usable alternative preview swatch in the palette;
no arbitrary assets are synthesized. These are data/lifetime requirements, not
promises that every race's shader exposes the same controls.

## In-game test

Fully restart on v0.2.56. Do not Reload All Mods or use the old skin/eye probes.

1. On one character, Apply distinct colors to armor Main Color, armor Accent,
   hair root, and tattoo (or other available color slots), without restoring
   between them. All earlier edits should remain visible when returning.
2. Reopen an edited slot, preview a new color, and Cancel. Repeat with timeout.
   That slot's previous Apply and all other edited slots should remain.
3. Select a stock swatch on just one edited slot. Only that slot should change.
   Use Restore: the remaining edits should return to their original baselines,
   while the intentional stock choice is preserved.
4. Repeat with two slots that start on Default/None. Apply both, navigate back
   and forth, then Restore. Both should return to Default/None independently.
5. Test skin tones other than 5 and 16, including another race. Check preview,
   Apply, Cancel, timeout, Restore and native stock selection. Report race, slot
   and swatch for a refusal/no visible change; unfamiliar layouts remain guarded.
6. Once those pass, Apply multiple slots, save normally, reopen, and restart.
   Confirm all saved edits persist. Edit one saved custom slot again and Cancel;
   the saved baseline on every other slot should remain unchanged.

Stop before saving on any Apply/Restore failure. Keep the logs. This build's
broader compatibility and multi-slot native behavior still need this validation.
