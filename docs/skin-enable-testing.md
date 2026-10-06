# v0.2.48: face tint switch and panel delivery

v0.2.47 native result: the skin command refused at face reacquisition, before
any switch write. DP counters advanced on disk but polls remained zero. UE4SS
reported "Ref was not function" near the first poll's expected execution, without
a traceback identifying its owner. Neither result validates the rendering theory.

v0.2.48 reacquires the exact named mesh through the verified actor's bounded
component list, not StaticFindObject on its dotted component path. Replacements
remain excluded. Panel client initialization and its counter baseline now occur
in an owned game-thread startup job after action registration. Logs trace that
job and the first poll's schedule/dispatch/run. This tests a startup registration
context issue; it is not a confirmed engine-level diagnosis.

## Evidence from v0.2.46

The September 17 20:31–20:33 UTC captures show custom Skin Coloration reaching
the actual displayed face MID for both Skin Tone 5 and 16. Skin Tone 5's MID
reports Enable Tinting=0, inherited from MI_HF00_Race0B. Its source scalar targets
Outfit only. Skin Tone 16 reports Enable Tinting=1 on the MID. This motivates a
temporary enable-switch experiment, not a preset rewrite.

Panel status showed open_disk increasing 160→161 while open_seen stayed 160,
polls=0 and pending_jobs=1. Registration/state-file writes worked; the client
poll did not progress. v0.2.47 routes polling and delivery through runtime:after,
the same owned scheduler used by successful console commands. Native verification
is still required; these counters alone do not establish the engine-level cause.

## Test 1: Dev Panel

1. Fully restart the game. Check Loaded v0.2.48. Do not Reload All Mods for these tests.
2. Select a color slot, wait a few seconds, then run `colors_panel status`.
   Expect scheduler=runtime and polls greater than zero.
3. F6 → Colors+ Probe → Open live RGB picker. It should open without a console
   picker command. Cancel it. Run `colors_panel status` again if opening fails.
   Logs should show COUNTER → QUEUED → INVOKE → RECEIVED → RUN.

## Test 2: Skin Tone 5

1. Use the same human face tested previously. Select Skin Tone 5, move off stock
   swatches, open CP (console fallback: `colors_picker open`). Choose Orange and
   leave the sliders alone long enough for its preview update.
2. While CP remains open, run `colors_skin_enable start`, then close the console.
   The displayed face should change if the disabled switch is the remaining cause.
3. Leave it untouched for 10 seconds. The original switch must restore and the
   face should return to its prior appearance. CP remains open; custom RGB data
   may still be pending, but no enable-switch change is saved.
4. Run start again, then `colors_skin_enable stop` before the timeout. Confirm
   the same restoration. Cancel CP when finished.

This experiment deliberately accepts only the captured Skin Tone 5 asset/layout
and MI_HF00_Race0B face parent. Other faces/tones may refuse. Only the assigned
MI_Head dynamic material is written; no body material, parent asset or equipped
fragment is changed. Apply is blocked while the experiment owns the switch.
Changing RGB, closing CP or changing context requests restoration. A replaced
material is retired without writing its replacement. Restoration failure keeps
the experiment owned and blocks reopening/Apply: retry stop or restart the game.
Do not change clothes/race, save or reload mods during this diagnostic test.

Report whether panel opening worked and whether the face changed/restored. Keep
the log so refusal/readback/dispatch details can be inspected before any next fix.
