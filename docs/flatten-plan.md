# Flattening the editing pipeline

Goal: replace the five-layer wrapper chain per zone with one editing pipeline
whose tests exercise only what players run, without losing the transaction
safety the old tests protect.

## Result (steps 1-5)

`color_zone.lua` owns one zone. Its regular backend sequences the preview
engine (`tint_test`), the temporary Default selection (`default_selection`)
and applied source edits (`editor_session`); the zone chooses between that
backend and the Zabrak source route (`zabrak_picker` + `zabrak_picker_source`)
at each opening and dispatches drafts by identity. Components own their native
reads/writes and journals; `color_zone` owns the order:

- Open: applied-record check, temporary Default selection, preview, then the
  applied color and skin display on the new draft.
- Apply: journal the record, hold Default, end the preview, write the source,
  verify the display, watch for the rest of the visit.
- Restore: the Zabrak route first, then preview, applied source, Default.
- Any preview end (Cancel, timeout, context change, failed update) returns a
  temporary selection to Default through the preview's `after_restore` hook.

No `wrap()` layers remain: no metatable fall-through, no patched
`regular.restore`, no `hold_selection` reaching through a layer.

## Former chain (per zone, outermost first)

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
3. **Done.** Merge `default_selection` into the pipeline (temporary stock
   selection as a step of opening/closing), keeping its write-ahead ordering.
4. **Done.** Merge `editor_session` (Apply/watch/visit restore) into the pipeline.
5. **Done.** Merge the Zabrak source route as a pipeline backend choice.
6. **Not done (recommended against).** One journal file per zone. The journals
   need different write schemes: the preview journal is a plain overwrite,
   written twice per drag tick (0.5ms average, 7ms max over 1,608 logged
   updates); the Apply journal is replaced atomically (temp file, rename,
   retained `.previous`) because it holds the only copy of the applied
   original. One file would either put that original behind a plain write a
   crash can tear mid-drag, or put every drag tick behind the atomic scheme
   (several file operations per write under Proton). Each component already
   owns its journal; recovery reads them in a fixed order.

Milestones 3-5 change event and recovery sequencing and need in-game verification of
Cancel, Apply, Restore, reload and save across armor, hair, skin (including
Zabrak tones 4/5/10), makeup, tattoos, horns, scars and Default/empty slots.

## Findings while porting

- Blue path, no-op install (fixed): when `SetFragmentInstances` installed
  nothing, rollback logged "Preview changed externally" and left the donor
  swatch previewing with nothing owned. Rollback in the `installing` phase now
  resets the donor when the live fragment is the exact donor object this
  session activated (identity recorded in memory before install; not
  journaled, so reload recovery stays conservative).
