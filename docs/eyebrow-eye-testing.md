# v0.2.32: temporary textured-eye scalar test

## Current focused test

Fully restart to load v0.2.32; **do not use Reload All Mods** while the earlier
navigation crash remains unresolved. Keep CP and DP closed, restore any CP
application first, and do not save during testing.

1. On standard/human eyes, select **Light Brown**, then move off the tiles.
2. Run `colors_eyes texture`, close the console, and watch the full 20 seconds
   without hovering other presets. Expected *if these controls affect the iris*:

   | Stage | Time | Temporary change |
   | --- | --- | --- |
   | 1 | 0–5s | IrisSaturation=0: less color / grayscale iris |
   | 2 | 5–10s | Original values |
   | 3 | 10–15s | IrisBrightness=25% of its original value: darker iris |
   | 4 | 15–20s | Original values; safety timeout ends test |

3. Repeat on **Rodian Star Blue** after the previous test has restored.
4. On one preset with a visible effect, run it again and use `colors_eyes stop`
   during the first pulse. Confirm the original appearance returns.
5. Start once more and leave the Eyes page during a pulse. Confirm restoration
   and no later pulse after returning. If either restoration fails, stop testing
   and report it before trying other navigation.

Report separately whether desaturation and darkening worked for each preset,
whether the iris pattern remained intact, and whether both restoration tests
worked. If there is no visible effect, do not repeat the same cycle; report it.
No new compatibility capture is needed for these four already-captured presets.

This tests controls on the texture-based path; it is **not arbitrary RGB** yet.
No texture pixel edits or swaps, mask changes, static-switch changes, asset
loads, shader recompilation, source edits or save calls. The existing
`colors_eyes start` vector/Albino test remains unchanged.

Implementation: only existing, verified display-owned MIDs are touched via
`K2_GetScalarParameterValue` / `SetScalarParameterValue`, checked against the
local Engine.lua declarations and the [official material-instance API](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/UMaterialInstanceDynamic).
Only the two captured asset/parent pairs qualify. Both scalar overrides must be
explicit, global, unambiguous and readable; live baselines must be positive and
bounded. Original/previous/chosen scalar values are journaled before writes.
`eye-scalar-v1` is strictly separate from the existing `eye-v1` vector records;
kind mismatches and unknown parameters are rejected before recovery writes.
Native replacement materials and externally changed values remain authoritative.
Same-process recovery restores, never resumes; fresh-process records are
quarantined by the existing process gate. Do not downgrade/reload while active.

## v0.2.31 capture results

The September 17 02:21–02:22 UTC captures completed for all four presets:

- Light Brown: Color TEX/GEN = false, override=true.
- Dark Brass: Color TEX/GEN = true, override=true.
- Albino and Rodian Star Blue: zero recorded runtime switches. That is not an
  effective false value; the base material defaults are still unknown.
- Full special-race scalar lists were captured (43 Neimoidian / 31 Rodian).

Together with the prior visible tests, the switch values support different
texture/generated color paths. The scalar test above checks whether the
recorded IrisSaturation and IrisBrightness controls affect the textured iris.

## Previous v0.2.31 read-only capture (completed)

Fully restart the game to load v0.2.31. **Do not use Reload All Mods for this
capture**: the earlier post-reload navigation crash remains unresolved. Keep
CP and SWZC Dev Panel closed, and do not run the eye preview or save changes.

Select each preset below, move the pointer off the preset tiles, then run
`colors_compat` once and close the console before navigating to the next one:

1. Standard/human eyes: **Light Brown**.
2. Standard/human eyes: **Albino**.
3. Rodian eyes: **Rodian Star Blue**.
4. Neimoidian eyes: **Dark Brass**.

No visible change is expected. The existing command now also records each
loaded replacement/parent instance's runtime static switch names, association,
index, boolean value and override flag. `STATIC BEGIN`, `STATIC SWITCHES` and
`STATIC SWITCH` identify the evidence; `STATIC GAP` / `STATIC ROW GAP` explicitly
mean unavailable or malformed data, not a disabled switch. Count zero means an
empty recorded array, not absence of inherited/default shader behavior.

Static capture has an independent 32-row-per-material / 64-row-per-swap limit.
The existing 64 vector/scalar/texture-row budget remains unchanged, including
up to 64 scalars so the known 43-scalar Neimoidian overrides are no longer cut
off at 16. Parent traversal remains four materials maximum. No setters, shader
recompilation, asset loads, editor-only data or new hooks are used.

The local Engine.lua / JMAP declarations expose
`UMaterialInstance.StaticParametersRuntime` ->
`FStaticParameterSetRuntimeData.StaticSwitchParameters` ->
`FStaticSwitchParameter.Value` plus inherited `ParameterInfo` / `bOverride`.
These are recorded runtime entries, **not proof of the effective compiled
shader branch**. Unreal also distinguishes switch retrieval from override-only
retrieval in its [material interface reference](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UMaterialInterface).

## Confirmed live results and remaining uncertainty

- v0.2.30 confirmed the case-only `MI_EyeLeft` -> `MI_Eyeleft` round trip.
- Dark Brass: both IrisColor1 and IrisColor2 changed visibly, with timed and
  manual restoration. Albino: CloudyIrisColor changed visibly; manual stop and
  native context-event restoration were logged.
- Light Brown and Rodian Star Blue: setters/readback and timeout restoration
  succeeded, but neither iris-color pulse visibly changed the eyes.
- All four use M_EyeRefractive, with different textures and explicit overrides.
  Different Color TEX/GEN overrides now support the color-path hypothesis;
  the exact compiled graph has not been inspected. Eye Apply/save/persistence
  is not implemented.
- Navigation crashed after a mod reload despite a completed eye restore.
  Subsequent fresh-launch testing reached multiple races. Reload is a suspect,
  not a confirmed cause or a fixed issue.

## Previous v0.2.30 test (historical)

Eyebrow Apply/Restore/reopen succeeded in the v0.2.29 log; no need to repeat
those for this patch. Eyes refused before writes at the FName round-trip guard.
The new helper follows [FName's case-insensitive semantics](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Core/FName)
only for whitelisted ASCII eye slots/parameters. It still rejects wrong names,
None, suffix changes and unreadable returns, and keeps object paths exact.
Case-only conversions log `EYE FNAME | CASE NORMALIZED` once per name/helper;
failures now include requested and returned values. The case-only mismatch was
subsequently confirmed in the live log.

With CP and DP closed, fully restart, select Neimoidian > Dark
Brass, move off the swatches, then run `colors_eyes start` and close the console.
Watch the 20-second sequence below. If it changes and restores correctly, run it
again and use `colors_eyes stop` during a pulse. If it refuses or shows no change,
stop and report that result before repeating the broader preset matrix.

## Full test sequence

Restart the game to load the linked probe. Keep SWZC Dev Panel closed. No mod
manager deployment is needed. Restore any applied CP color before changing zones.

## Eyebrows

1. Equip an eyebrow color, then hover a different swatch without selecting it.
2. Run `colors_picker`. Change RGB, Apply, then `colors_picker restore`.
3. Immediately reopen and Cancel. Repeat after hovering and moving off a swatch.
4. Back out to the radial selector, re-enter Eyebrow Color, open and Cancel again.
5. Do one armor color preview/Cancel as a regression check.

Expected: the selected slot's verified stock hover is reset to the equipped
baseline before the normal donor preview starts. A stale *inactive* data proxy
is allowed only after verifying that the displayed character follows the source.
The new donor still has to pass the existing material/mesh/color/ownership tests.
An unrelated, ambiguous or unverified preview remains a refusal, not a reset.
Restore should return the equipped eyebrow color, not the swatch only hovered.

## Eye probe (separate from CP)

Begin with **Neimoidian > Dark Brass**. Select it, move off the preset tiles,
then run `colors_eyes start` and close the console. Do not hover tiles during
the first complete cycle.

| Elapsed time | Parameter test |
| --- | --- |
| 0–5 seconds | `IrisColor1` cyan; `IrisColor2` unchanged |
| 5–10 seconds | Original values |
| 10–15 seconds | `IrisColor2` magenta; `IrisColor1` unchanged |
| 15–20 seconds | Original values; session ends at 20 seconds |

Look for a visible change, which region changes, and complete restoration.
Textures, lighting, gradients and brightness can prevent a pure cyan/magenta
appearance. Successful setter readback alone is **not** proof of visible effect.

If the first cycle opens and restores correctly, repeat on:

- Light Brown (standard eye material).
- Rodian Black and Rodian Star Blue (separate vs shared eye material slots).
- Albino: the two pulses both target `CloudyIrisColor`, cyan then magenta.

Then run separate cancellation checks on one working preset:

1. `colors_eyes start`, then `colors_eyes stop` during a pulse.
2. Start again and select a different stock eye preset; the stock choice wins.
3. Start again and leave the Eyes page; the test ends.
4. Reload cancellation testing is paused pending investigation of the
   post-reload navigation crash. Use a full restart between code changes.

If the first preset refuses or never changes visibly, report that and stop;
the log contains the reason/stage, so there is no need to repeat every preset.

This is **display-only**: no eye Apply/save/persistence support. CP and the eye
probe block each other while active or awaiting recovery. Do not save during
testing. Unsupported presets (including Blue without explicit iris overrides)
refuse rather than guessing a parameter's existence. `colors_compat` stays
read-only; special-race scalar capture now includes up to 64 entries while the
total per-swap parameter budget remains 64.

## Implementation and recovery boundaries

- Bind the active creator/page, selected eye root, nested swap ownership,
  source/display preset agreement and exact linked display actor.
- Only existing `MaterialInstanceDynamic` objects belonging to the display's
  face mesh can be edited. Verify their parent preset and that the material is
  not shared across display slots. No stock MIC or source/data actor writes.
- Journal original/previous/chosen RGBA and exact material/component identities
  before setters. Restore only our unchanged target and expected colors;
  native material replacements or other parameter edits win.
- Use owned delayed game-thread work with a 20-second cycle, 250ms context
  checks, native context-event cancellation and scalar identities across jobs.
- `eye_recovery.txt` uses the existing process-session gate. Same-process reload
  restores; a fresh game archives old records without replaying stale identities.
- Reference declarations: `Engine.lua` MaterialInstanceDynamic vector getter /
  setter, MeshComponent slot APIs; `BitReactorCore.lua` nested slots/material
  swaps. Ownership checks use the documented
  [UE4SS UObject.GetOuter](https://docs.ue4ss.com/lua-api/classes/uobject.html#getouter).

All engine behavior in this new probe still requires the live tests above.
