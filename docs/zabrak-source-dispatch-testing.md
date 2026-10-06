# Zabrak source-dispatch handoff test — v0.2.66

This is a reversible source-RGB/order/enable-target experiment, not normal
picker integration or a persistence test.

## Evidence and scope

The v0.2.65 native test returned four fresh instances immediately after
SetFragmentInstances. Their classes, owning instance/slot, supported payloads
and swap targets matched; tags/swap/color/scalar order was honored.

v0.2.66 may accept fresh identities ONLY in the synchronous return window of
its own array setter. Before/after inspection verifies the same owner, slot and
part, four unique supported roles, race tags, material targets, RGB/scalar values
and requested order. Newly verified identities are durably recorded before any
subsequent RGB/target/refresh write. Restoration uses the same handoff, since its
stock-order setter may rebuild the fragments again.

Hard/soft replacement references remain opaque: neither is read, stringified,
written or compared. Their involvement in the earlier crash remains suspected,
not proven. Supported metadata does not prove reference-only state or rendering.

## Safety and recovery

- Start journals stock RGB/layout/order, requests tags/swap/color/scalar order,
  expands the enable scalar's target tags to the captured six mesh tags, sets
  orange RGB, and calls normal source RefreshCustomization once.
- No MID/preset/asset/save writes or periodic reapplication. Normal CP unchanged.
- Plain bounded v3 journals track exact current IDs, expected order and owned or
  in-flight phase. Partial order calls, failed evidence or failed journal commits
  hold the record and require a restart without saving. No later inferred adoption.
- Exact owned records may restore in-process. Stop restores RGB, scalar targets
  and stock order, performs one refresh, and clears recovery only after readback.
  Missing/foreign/replaced sources retain evidence rather than claim success.
- A successful Start schedules a fixed 60-second Stop. Creator exit queues Stop;
  radial navigation only checks ownership and does not repaint.
- Older dispatch/inspection journals block native recovery unchanged. Normal
  bootstrap handles cold-process classification/quarantine after full restart.
- Native faults can bypass Lua protection; flushed call boundaries remain enabled.

## First test: preview and manual restoration

1. Fully restart without saving to retire the held v0.2.65 inspection. Confirm
   Loaded v0.2.66. Select Zabrak Skin Tone 8
   (CPD_H_SkinTone_Hum_Zabrak_1A1), with the native swatch grid open.
   Restore existing CP edits and leave CP closed.
2. Run colors_zabrak start once. Keep the selected swatch and race unchanged.
   Report separately whether hands, face and horn-base skin turn orange.
3. Before 60 seconds, run colors_zabrak stop. Report whether all changed areas
   return to their original colors and the game stays responsive.

Do not save, reload mods, change race or use CP during this test. If it refuses,
crashes, or fails restoration, do not retry; preserve the log and restart without
saving. HANDOFF VERIFIED should appear for both the test and restoration order.
A failure should instead retain the journal and include HANDOFF HELD or RESTORE
FAILED/REFUSED, never an unverified RESTORED ending.

## Follow-up after successful manual restoration

Repeat Start without touching the screen and wait 60 seconds for timeout
restoration. Once that passes, repeat with one radial round trip before Stop.
These remain rendering/lifetime tests, not persistence tests.

colors_zabrak capture remains read-only when no source/picker ownership is active.
