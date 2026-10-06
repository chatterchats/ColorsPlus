# Architecture

How Colors+Probe edits a color, and why it is shaped this way. Source lives
in `src/Colors+Probe/Scripts`; tests in `tests/` (`tools/run-tests.sh`).

## Overview

- `main.lua` starts the runtime, passes the recovery session gate
  (`recovery_session`) and builds `multi_editor`.
- `multi_editor` keeps one **zone** per color slot being edited (up to 32,
  created on demand; zones with journals on disk are created at startup). It
  shows one draft at a time; several zones may hold applied colors.
- The picker UI (`color_ui` launcher, `live_picker`, `picker_view`) talks to
  the active zone only through its public surface: `begin_live`,
  `update_live`, `check_live`, `apply_live`, `cancel_live`, `restore`,
  `context_changed`, plus `pending`/`applied`/`blocked`/`busy`.
- `dev_tools.lua` (Dev package only) attaches probes, traces and the SWZC Dev
  Panel; the Testers package is the scripts reachable from `main.lua` without it.

## A zone (`color_zone.lua`)

A zone chooses a backend at each opening and dispatches drafts by identity:

- **Zabrak source route** (`zabrak_picker` + `zabrak_picker_source`): Zabrak
  skins whose bundle has a material swap. The preview cannot clone swap
  bundles, so drafts edit the character's source fragments directly.
- **Regular backend** for everything else, sequenced in `color_zone`:
  - Open: applied-record check, temporary Default selection, preview, then
    the applied color and skin display on the new draft.
  - Apply: journal the record, hold Default, end the preview, write the
    source, verify the display, watch for the rest of the creator visit.
  - Restore: preview, applied source, then Default. (The Zabrak route, when
    active, is always ended first.)
  - Any preview end (Cancel, timeout, context change, failed update) returns
    a temporary selection to Default through the preview's `after_restore` hook.

Components own their native reads/writes and their journal; `color_zone`
owns the order. Tests can replace the preview engine (`parts.preview`) or the
whole regular backend (`parts.regular`).

| Component | Role | Journal (current formats) |
|---|---|---|
| `tint_test` | Preview engine: palette donor handoff on the preview proxy, clone/install/refresh, live updates, restore | `tint_recovery.txt` (`proxy-v7`..`v12`), plain overwrite |
| `default_selection` | Default/empty slots: temporarily equip a stock swatch so the preview has a fragment to clone | `default_selection_recovery.txt` (`selection-v2`) |
| `editor_session` | Apply: write the chosen color into the character's source fragment for this creator visit; restore on exit | `editor_recovery.txt` (`editor-v2`..`v7`), atomic replace with `.previous` |
| `zabrak_picker` / `zabrak_picker_source` | Zabrak swap skins: source-owned drafts and Apply | `zabrak_picker_recovery.txt` (`zabrak-picker-source-v1`) |

Zone *n* > 1 prefixes its journals with `zone<n>_`. All journals live in
`DevPanel/`. Journals left by a previous game process are archived by
`recovery_session`, never replayed; only a same-process Lua reload replays
them, and an unreadable journal blocks its zone instead of guessing.

### Why the journals stay separate

They need different write schemes. The preview journal is written twice per
drag tick (0.5ms average, 7ms max over 1,608 logged updates) and is a plain
overwrite. The Apply journal holds the only copy of the applied original, so
it is replaced atomically (temp file, rename, retained `.previous`). One file
per zone would either put that original behind a write a crash can tear
mid-drag, or put every drag tick behind the atomic scheme.

## History: flattening (October 2026, v0.3.0)

Until v0.2.120 each zone was a chain of five wrappers (`zabrak_picker` →
`editor_session` → `default_selection` → `default_tint` → `tint_test`), each
re-implementing begin/restore/context/start, delegating through metatables,
and reaching across layers (a patched `regular.restore`, `hold_selection`).

1. Removed `default_tint`/`default_owner`, an unreachable Clone 8 "Default"
   backend.
2. Removed the `generic_colors` flag (always on) and the Clone 8 path behind
   it: accent resolution, cyan and owner-level handoff modes,
   `apply_rgb`/`cycle_rgb`, the RGB file reader and journal readers for
   `proxy-v1`..`v6`, `editor-v1`, `selection-v1`. Their transaction-safety
   tests were ported to the donor path first; `tests/tint_test.lua` went from
   1,368 to 605 lines.
3. Default selection became a component sequenced by the new `color_zone`.
4. Apply (`editor_session`) became a component.
5. The Zabrak route became the zone's backend choice.

Found while porting: a preview install that changed nothing left the palette
donor hovered on rollback. Rollback in the `installing` phase now resets the
donor when the live fragment is the exact donor object this session activated
(identity kept in memory only, so reload recovery stays conservative).
