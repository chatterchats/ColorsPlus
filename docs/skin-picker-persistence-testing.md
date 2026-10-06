# v0.2.55: normal picker with persistent Skin Tone 5 Apply

The source-target experiment passed full restart persistence. This build moves
the same leaf tag-array correction into the normal picker Apply flow.

## Behavior

- Preview of an uncorrected Skin Tone 5 retains the temporary face MID workaround.
  Cancel/timeout do not correct its source target.
- Apply journals RGB plus the exact scalar identity, then changes that source's
  Outfit target to five meshes and refreshes natively. No applied MID loop needed.
- Restore returns both original RGB and Outfit targeting if this edit corrected
  them. Source replacement by native selection is left untouched.
- Editing an already-saved five-mesh custom skin does not assume an original
  Outfit target. Cancel/Restore preserve the saved baseline layout and RGB.
- Native Save remains the only game-save action; this mod does not invoke Save.
- Only the verified Skin Tone 5 / Human_0B1 / Race.0B correction is enabled.
  Existing behavior on other supported color slots is unchanged.

## Test

Fully restart for v0.2.55. Do not use colors_target save/start or colors_skin_enable.
Use the normal CP launch from the console or DP. Avoid Reload All Mods.

1. On the already-saved orange Skin Tone 5, open CP, preview another color, and
   Cancel. Orange should return. Repeat and allow the normal two-minute timeout.
2. Apply a different color, return to the radial selector and back. It should
   remain. Hover stock swatches, then move off: hover should preview stock, then
   the applied custom color should return. Restore should return saved orange.
3. Select a stock skin tone, then Skin Tone 5 to obtain its native stock baseline.
   Open CP and preview/Cancel: stock appearance should return. Repeat with timeout.
4. Apply a distinct custom color. Check the radial round trip and hover behavior.
   Restore must return the stock baseline, including the original target layout.
5. Apply again, then select a different stock swatch. That later selection must
   win; the custom color must not be reapplied to it.
6. Return to stock Skin Tone 5, Apply a new custom color, and save normally.
   Reopen the character; verify the color. Then fully restart and verify again.
7. Edit that saved custom color once more, Apply, and save. Reopen to verify the
   newer color. Cancel/Restore before saving should instead preserve its previous
   saved baseline, as in steps 1–2.

If Apply/Restore fails, do not save. Keep the logs and report the step. No separate
target command is required for these tests. A brief rendering refresh during
navigation is separate from source ownership/persistence and should be reported.

## Recovery

editor-v6 stores the original Outfit layout and exact source scalar alongside
the existing RGB record; it is written before mutation. Repair validates owner,
slot, race, color target and scalar value independently of damaged scalar target
fields. It does not repair foreign/replacement fragments or stock definitions.
Legacy editor-v1 through v5 journals still use their prior recovery behavior.
Cold-start journal handling remains process-gated; do not replay runtime paths
from a previous process against a newly loaded character.
