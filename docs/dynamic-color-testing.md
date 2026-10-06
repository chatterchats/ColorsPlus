# Dynamic single-zone picker — v0.2.27

For the v0.2.28 appearance-palette fix and eye-material survey, use the shorter
[focused test](appearance-palette-testing.md). This document records v0.2.27.

## Scope

This removes the Clone 8, torso, Color 02 and Blue_14 assumptions for new picker
sessions. The selected slot must expose exactly one normalized opaque material
color fragment with exactly one mesh tag and a nonempty material-slot list.
The active palette must contain the equipped VM and a different non-Default
swatch in the same game instance. Its color/target is verified on both preview
data and the displayed character before writing custom RGB.

The current main-menu creator/display identity restrictions remain. Only one
applied zone can be owned at once. Another zone is refused until Restore or
creator exit; there is no automatic loss of a previous Apply to make room.
Eyes (nested slots), skin (multiple fragments/meshes), tattoos (multiple mesh
tags) and unresolved palette ambiguity are not enabled for writes.

## Setup

Restart the game to load v0.2.27 through the existing live source symlink. Keep
SWZC Dev Panel closed; launch via `colors_picker`. Close the console after each
command and move the pointer off native swatches before opening CP. Do not save
the character during these first generalized-target tests. No changes to DP or
to the native character save path are included.

## Pass 1: preview and Cancel

Test one zone at a time, starting on an ordinary stock color:

1. Clone 8 Primary Accent, as a regression check.
2. A different top's Main Color.
3. Arms or legs; include a secondary/tertiary accent if exposed.
4. Hair root and tip separately, then eyebrow color.
5. One makeup color (lipstick, eyeliner or eyeshadow).

For each: run `colors_picker`, select a distinctly different RGB/preset, and
confirm only the intended zone changes. Cancel should return to the starting
stock color. An opening refusal is diagnostic evidence, not a request to bypass
guards: note the zone and run `colors_compat` there while CP is closed. If the
character or another zone changes unexpectedly, stop and report it.

Also try Saturated Blue 1 on an outfit slot: it is no longer a reserved donor
that prevents opening the picker.

## Pass 2: Apply, navigation and restoration

On one newly working armor zone and one newly working hair/makeup zone:

1. Apply a custom RGB. Return to the radial selector, wait, then reopen that
   same zone: the custom color should remain.
2. Reopen CP, change the draft, then Cancel: the last Apply should remain.
3. Hover a stock swatch, then move away: native hover should temporarily win,
   then return to the applied custom color. Clicking a stock swatch should win.
4. Run `colors_picker restore` before testing another zone. It should restore
   the pre-Apply baseline unless a later native stock selection replaced it.
5. In a separate Apply trial, leave the creator for the Databank: the existing
   editor-visit cleanup should restore the baseline without affecting other zones.

On a new outfit zone, repeat opening/Cancel from **Default**. It should select
the first non-Default stock swatch temporarily and return to Default on Cancel.
Then test Apply -> Restore from Default. Finally leave one un-applied draft open
for two minutes and confirm timeout restores its original swatch/Default.

No save/restart-persistence retest is needed in this first pass. Native saving
already retained the previously tested accent; first establish new-target
preview, Apply and cleanup.

## Eyes: diagnostics only

Open Eyes and run `colors_compat` once, even if no secondary color boxes appear.
It now records nested slot tags, part IDs, `visible_in_ui`, and any underlying
material-color parameter/material/mesh tags. It does not equip or recolor eyes.
Traversal is bounded to 32 fragments and depth four, with cycle/owner checks.

## Evidence and recovery

Report which zones visibly worked/refused and whether the correct zone changed.
Logs include `PALETTE DONOR VERIFIED`, `PREVIEW APPLIED`, `EDITOR COLOR`, and
`COLOR COMPAT | NESTED...`. New recovery records carry scalar target descriptions;
legacy records remain readable. A pending donor-activation record authorizes
only resetting the verified preview link, not arbitrary color writes.

Do not Reload All Mods with both CP and DP open. If restoration fails, stop
testing and provide the logs before restarting; do not save. The UI redesign
and multi-zone Apply are separate follow-up work.
