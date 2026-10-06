# Flattening the editing pipeline

Goal: replace the five-layer wrapper chain per zone with one editing pipeline
whose tests exercise only what players run, without losing the transaction
safety the old tests protect.

## Current chain (per zone, outermost first)

| Layer | Production role | Journal |
|---|---|---|
| `zabrak_picker` (+ `zabrak_picker_source`) | Zabrak skin tones with material swaps edit the source directly | `zabrak_picker_recovery.txt` (`zabrak-picker-source-v1`) |
| `editor_session` | Apply writes the chosen color into the character's source fragment for this creator visit; watch; restore on exit | `editor_recovery.txt` (`editor-v2`..`v7`) |
| `default_selection` | Default/empty slot: temporarily equip a stock swatch, preview, restore Default | `default_selection_recovery.txt` (`selection-v2`) |
| `tint_test` | Preview session: palette donor handoff, clone/install/refresh, live updates, restore | `tint_recovery.txt` (`proxy-v7`..`v12`) |

(`default_tint`, an unreachable Clone 8 "Default" backend, was removed in step 1.)

`multi_editor` builds one chain per zone on demand.

## Dead weight (removed in step 2)

- `runtime.generic_colors` was always true: the Clone 8 accent resolution,
  `ACCENT`/`CLONE8` checks and the non-generic branches never ran.
- Apply modes: production always used the palette donor handoff. The cyan
  (no handoff) and plain handoff modes (owner `PreviewPart`/`ResetPreview`),
  `apply_rgb`/`cycle_rgb`, the RGB file reader and the wrapper gates that
  only blocked those actions were developer leftovers.
- Journal readers for formats only the non-generic path wrote (`proxy-v1`..`v6`,
  `editor-v1`, `selection-v1`). Journals from a previous game process are
  archived by `recovery_session` and never replayed, and the flag has been on
  since before the v0.2.115 baseline, so no supported upgrade can meet one; an
  unreadable journal blocks its zone rather than guessing.

## Milestones (each: suite green, own commit)

1. Delete `default_tint` and its tests. **Done.**
2. **Done.** Port the transaction-safety tests from the legacy (cyan/handoff/RGB) test
   section onto the blue path with generic fixtures: install/adoption rules,
   restore verification, journal-before-write transitions, malformed recovery,
   event ordering, stale callbacks, reload recovery. Then delete the legacy
   modes, `generic_colors`, Clone 8 resolution and old journal readers.
   `tests/tint_test.lua` is now generic-only (605 lines, was 1,368): every
   supported profile, Default integration and editor Apply on the real stack.
3. Merge `default_selection` into the pipeline (temporary stock selection as a
   step of opening/closing), keeping its write-ahead ordering.
4. Merge `editor_session` (Apply/watch/visit restore) into the pipeline.
5. Merge the Zabrak source route as a pipeline backend choice.
6. One journal file per zone with one current format, written in the same
   order the separate journals guarantee today (preview, selection, editor).

Milestones 3-6 change recovery ordering and need in-game verification of
Cancel, Apply, Restore, reload and save across armor, hair, skin (including
Zabrak tones 4/5/10), makeup, tattoos, horns, scars and Default/empty slots.

## Findings while porting

- Blue path, no-op install (fixed): when `SetFragmentInstances` installed
  nothing, rollback logged "Preview changed externally" and left the donor
  swatch previewing with nothing owned. Rollback in the `installing` phase now
  resets the donor when the live fragment is the exact donor object this
  session activated (identity recorded in memory before install; not
  journaled, so reload recovery stays conservative).
