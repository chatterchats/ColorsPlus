# Flattening the editing pipeline

Goal: replace the five-layer wrapper chain per zone with one editing pipeline
whose tests exercise only what players run, without losing the transaction
safety the old tests protect.

## Current chain (per zone, outermost first)

| Layer | Production role | Journal |
|---|---|---|
| `zabrak_picker` (+ `zabrak_picker_source`) | Zabrak skin tones with material swaps edit the source directly | `zabrak_picker_recovery.txt` (`zabrak-picker-source-v1`) |
| `editor_session` | Apply writes the chosen color into the character's source fragment for this creator visit; watch; restore on exit | `editor_recovery.txt` (`editor-v1`..`v7`) |
| `default_selection` | Default/empty slot: temporarily equip a stock swatch, preview, restore Default | `default_selection_recovery.txt` (`selection-v1`,`v2`) |
| `default_tint` | **Unreachable**: Clone 8 accent "Default" backend; `default_selection` always intercepts Default first | shares `tint_recovery.txt` (`default-v1`,`v2`) |
| `tint_test` | Preview session: donor handoff, clone/install/refresh, live updates, restore | `tint_recovery.txt` (`proxy-v1`..`v12`) |

`multi_editor` builds one chain per zone on demand.

## Dead weight

- `runtime.generic_colors` is always true: the Clone 8 accent resolution,
  `ACCENT`/`CLONE8` checks and the non-generic branches never run.
- Apply modes: production always uses the blue donor handoff
  (`apply("blue", nil, "selected")`). The cyan (no handoff) and plain handoff
  modes, `apply_rgb`/`cycle_rgb` and the RGB file are developer leftovers.
- Journal readers for old formats. Journals from a previous game process are
  archived by `recovery_session` and never replayed; only same-process Lua
  reloads read them, which testers are told to avoid. Only the current format
  of each journal needs reading; anything else is archived/blocked.

## Milestones (each: suite green, own commit)

1. Delete `default_tint` and its tests.
2. Port the transaction-safety tests from the legacy (cyan/handoff/RGB) test
   section onto the blue path with generic fixtures: install/adoption rules,
   restore verification, journal-before-write transitions, malformed recovery,
   event ordering, stale callbacks, reload recovery. Then delete the legacy
   modes, `generic_colors`, Clone 8 resolution and old journal readers.
3. Merge `default_selection` into the pipeline (temporary stock selection as a
   step of opening/closing), keeping its write-ahead ordering.
4. Merge `editor_session` (Apply/watch/visit restore) into the pipeline.
5. Merge the Zabrak source route as a pipeline backend choice.
6. One journal file per zone with one current format, written in the same
   order the separate journals guarantee today (preview, selection, editor).

Milestones 3-6 change recovery ordering and need in-game verification of
Cancel, Apply, Restore, reload and save across armor, hair, skin (including
Zabrak tones 4/5/10), makeup, tattoos, horns, scars and Default/empty slots.
