# Selected color-slot survey — Colors+Probe v0.2.26

Historical survey instructions. v0.2.27 adds dynamic single-zone writes and
nested read-only diagnostics; see [the current test](dynamic-color-testing.md).

This is the first live compatibility test for removing the Clone 8/Primary
Accent restriction. It generalizes **discovery only**, not writes. The existing
picker, recovery formats, Default behavior and write restrictions are unchanged.
The current preview backend assumes Blue_14, Color 02, a torso target, and a
fixed restore slot. We need to verify palette and target structure before
replacing those assumptions. A `CANDIDATE` result does not enable the picker.

## Test

Restart with v0.2.26; keep CP and DP closed. Do not Apply or save during this
survey. On each color page below, select an ordinary stock swatch, move the
cursor off the tiles, run `colors_compat`, and close the console. Give each
capture a second before switching pages.

1. Clone 8 → Primary Accent (known-good reference).
2. Clone 8 → Main Color.
3. A different top/armor piece → one of its color zones.
4. Another outfit category with tint zones, such as gloves or legs.
5. Optional: hair root/tip, skin or eyes, if accessible in this creator.
6. Optional: Default on one of the new zones, to record whether it has zero
   fragments or an actual color value. Do not open the picker on it yet.

Report the zones tested. There should be **no mod-induced color change**. The
manual stock selections themselves are normal editor changes; discard them when
leaving if you don't want to keep them. Nothing is automatically equipped by
the survey.

## Evidence and limits

`COLOR COMPAT` log entries contain:

- exact creator, active item page and selected slot tag;
- equipped swatch name/asset and fragment count/class;
- verified fragment owner/slot, linear RGBA and alpha;
- actual material parameter, material slots, target mesh tags and equipped parts;
- one visible matching palette, ordered samples, equipped-item membership,
  alternative count and whether the legacy Blue_14 is present.

The survey never infers material compatibility from swatch labels alone. Palette
membership is not proof that an alternative provides matching fragments, so
preview activation and writes remain unverified. Single normalized opaque color
fragments with one target mesh and a matching palette are candidates for the next
write test. Default, multiple fragments, non-opaque colors, absent palettes and
unreadable/ambiguous contexts are logged instead of guessed.

The console handler dispatches one owned game-thread job; there are no hooks,
timers or retained UObjects. Repeated commands coalesce and reload cancels queued
captures. Scan limits: 128 item pages/auxiliary VMs, 256 selection widgets, 1024
palette items, 16 fragment details and the existing 64-entry guarded array
reader. An active/applied/blocked picker session refuses the survey to avoid
mixing preview and source evidence.
