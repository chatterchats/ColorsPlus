# v0.2.54: does the corrected skin target survive native Save?

The v0.2.53 leaf-write test passed in-game: saved RGB became visible, timeout
restored the original target, and manual stop restored it too. This new test
changes only the verified Skin Tone 5 per-character scalar target, not RGB.

## Commands

- `colors_target start`: original 15-second no-save test; transitions restore.
- `colors_target save`: opt-in 120-second window for native Save/reopen.
- `colors_target check`: read-only source target/RGB/identity snapshot.
- `colors_target stop`: restores only the recorded source, or retires ownership
  if that source was replaced. It does not edit a saved file or replacement.

Save mode logs context changes but performs no writes on those transitions.
It does not poll, refresh or reapply the target after arming. The owned two-minute
deadline remains active. On same-process reload, recovery restores rather than
resuming save mode. Cold-start recovery records are quarantined by the existing
process gate. Do not Reload All Mods during the experiment.

## Test now

1. Fully restart on v0.2.54. Open the same character with the saved custom-orange
   RGB, and enter Skin Tone 5. Keep CP closed, with no other preview/Apply active.
2. Run `colors_target check` for the baseline.
3. Run `colors_target save`. Confirm orange appears and the log says SAVE ARMED.
4. Within two minutes of arming, use the game's normal Save, return to the
   Databank, reopen that same character, and return to Skin Tone 5. Do not select
   another swatch, change race/clothes, open CP, or run the enable probe.
5. Run `colors_target check` immediately. Report whether orange remained and
   whether it disappeared at any point during navigation.
6. Run `colors_target stop` after the snapshot. Do not save again. Report the
   result and let us inspect the log before a further restart test.

If orange never appears or an error/RESTORE FAILED is logged, do not save.
If the deadline expires before the second check, the result is inconclusive:
restoration could have affected it. Do not rush or repeat saves to compensate;
report the timing instead.

The read-only snapshot reports Outfit versus five-mesh target, RGB, full scalar
identity, and whether the source matches the armed source. It can also be used
after a later full restart without arming anything, once that next test is agreed.
Reopening with the same runtime source is weaker evidence than recreation, and
neither is equivalent to a full process-restart persistence check.

Stopping restores the original live source only. If native Save preserved the
modified target, stop is not a disk-level undo. Conversely, a newly reconstructed
stock target will not be overwritten just to make the test appear successful.
