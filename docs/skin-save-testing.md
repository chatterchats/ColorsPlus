# v0.2.51: read-only skin save comparison

Skin Tone 5's preview/editor lifecycle passed native testing, with a brief
transition flash. The user saved the character and reported that the color was
not retained. We have not established whether RGB, face enable state, or both
were lost.

The new commands append labeled snapshots to colors_plus_probe.log and UE4SS.log.
They do not save, restore, equip, refresh, clone or write any game property.
They observe runtime character data, not the serialized save file directly.
Any failed read is unavailable evidence, not zero/default. Strict context refusal
must be investigated rather than interpreted as proof of serialization loss.

## Procedure

1. Fully restart for v0.2.51. Use the same character and Skin Tone 5. Enter its
   skin color selector and move the pointer off swatches. Do not open CP yet.
   Run: colors_save baseline
2. Open CP normally, choose a distinctive color and Apply. Keep the skin page
   open, move off stock swatches and run: colors_save before
3. Save the character normally. Do not use CP Restore or manually revert the
   swatch before saving. Leave to Databank, then reopen the same character.
4. Return to its skin color selector without choosing a different swatch or
   opening CP. Move off swatches and run: colors_save after
5. Tell us the test is done before restarting again so the logs can be reviewed.
   Report whether the color is visible and whether the selected skin tone changed.

Use a test character if you do not want its saved appearance altered by the
native Save operation. The diagnostic itself is read-only, but you are testing
the game's real save workflow.

## What the captures show

- Source skin asset, owner/fragment identities and linear RGBA.
- Equipped, preview-data and linked displayed fragment RGB and scalar targets.
- Skin Coloration and Enable Tinting getters on selected skin materials, plus
  bounded parent override data.
- Before-save Apply original/chosen RGB and current enable ownership mode.

Baseline and after refuse active Colors+ Apply or face-enable ownership.
All stages refuse a live draft or blocked recovery. Before requires an applied
color belonging to the current source. Commands are coalesced, execute on the
game thread, and are cancelled by page exit; wait for the capture before leaving.
They do not require or start the 60-second materials trace window.

Compare source RGB first, separately from display Enable Tinting. The resulting
evidence can localize the loss across the save/reopen workflow, but cannot alone
prove precisely where inside native serialization the value was discarded.
