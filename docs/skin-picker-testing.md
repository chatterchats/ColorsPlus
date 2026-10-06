# v0.2.50: automatic Skin Tone 5 face tint

v0.2.49 native testing passed the other picker lifecycle checks but radial
navigation lost Apply: the display helper hit Object unavailable after page
close, and the editor watcher restored the source RGB. v0.2.50 removes the
idle applied display's dependency on hover-instance/data objects. It also
separates display failure from source/visit validation: eight rendering attempts
are allowed before pausing until another context event. Source/visit checks keep
running while display retries are paused. Initial Apply failures still roll back.
Regression tests remove hover data and simulate a longer display gap.

v0.2.48 native testing confirmed DP dispatch, orange rendering with face
Enable Tinting=1, ten-second restoration, and manual restoration.

v0.2.49 uses that exact MID operation automatically for Skin Tone 5
(CPD_H_SkinTone_Human_0B1 / MI_HF00_Race0B). Existing five-mesh skin support,
other colors, clothing guards and the working DP startup are unchanged.
The manual probe command remains diagnostic; do not use it in these tests.

## Test sequence

Fully restart and verify Loaded v0.2.50. Use the same human face as the successful
test. Do not Reload All Mods while a skin preview or Apply is active.

1. Select Skin Tone 5 and open CP through DP. Orange should appear without
   running colors_skin_enable. Move RGB sliders and try the preset buttons.
2. Cancel: original skin appearance should return. Reopen and let the normal
   two-minute CP deadline expire; it should restore again.
3. Reopen, select a distinct color and Apply. CP should close and color remain.
   Back out to the radial selector and re-enter; color should remain.
4. Hover stock swatches, then move off. Stock hover should show temporarily;
   the custom applied color should resume. Selecting a stock swatch must win.
5. Apply a custom color again if necessary. Reopen CP, change the color, then
   Cancel. The previous applied color should return, not the unsaved draft.
6. Use Restore original appearance (or colors_picker restore): original skin
   should return. Separately, Apply then leave customization to Databank without
   saving: existing editor-exit cleanup should restore the original.
7. Smoke-test Skin Tone 16 and one armor accent; their existing behavior should
   be unchanged.

Report which step differs, and keep the log. SKIN ENABLE ACTIVE now identifies
preview or applied ownership; the normal path does not use the ten-second timer.

## Limits

This is editor-lifecycle integration, not persisted tint-enable storage. RGB
still uses the existing source-fragment Apply/journal machinery; the enable
switch exists only on the transient displayed face material. Stock presets,
parent materials and source scalar targets are untouched. Restart persistence
is not expected to be solved by this step. Do not save for this verification.

Applied rendering is maintained only after the existing editor watcher verifies
source color, source identity, creator visit and clothing targets. It yields to
native hover and later stock selection. No actor or material UObject is retained
across ticks. Failed restoration retains ownership and blocks safe handoff.
Close CP and Restore applied skin before reloading mods; a full restart remains
the development test procedure.
