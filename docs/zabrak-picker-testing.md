# Zabrak normal-CP integration — v0.2.67

The v0.2.66 console probe passed native rendering on hands, face and horn-base,
manual/timeout restoration, radial navigation and swatch hover/reset. This build
integrates that source path into normal CP. It does not add automatic Save calls.

## Implementation boundaries

- Zabrak skin uses source RGB plus the verified tags/swap/color/scalar order and
  six enable-target tags. Every own order setter verifies returned copies and
  journals their identities before continuing. No face-MID workaround is used.
- Other slots/races retain their existing picker backend. The timed console
  probe remains separate; do not run it while any CP draft or Apply is owned.
- A source draft has a fixed 120-second deadline. Apply closes CP and keeps RGB
  for the creator visit. Reopening and cancelling restores that previous Apply.
- Restore and creator exit return to the visit's original RGB, enable targets
  and array order. A previously saved corrected layout is a valid baseline,
  not something cleanup should incorrectly reset to stock.
- Native stock choices supersede old ownership; replacements are never adopted
  or recolored. Unknown changes during setters retain recovery and block writes.
- Each zone owns an independent process-gated recovery journal. Full restart
  quarantines cold journals without touching potentially reused native IDs.
- Reload All Mods is explicitly held while CP owns a Zabrak source correction.
  Close CP and Restore applied Zabrak edits first. The Dev Panel app is untouched.
- Drafts now change the editor source. Do not Save while a draft is open.
  Native Save/restart persistence has NOT been established by the probe.

## First tests: regular picker only

1. Fully restart, confirm Loaded v0.2.67, select Zabrak Skin Tone 8, and open
   CP through the normal console/keybind or Dev Panel action. Do not run
   colors_zabrak start. Try Orange, Violet, Green and sliders; check hands,
   face and horn-base together. Cancel should restore the original appearance.
2. Reopen, choose Violet and Apply. Back out to the radial selector and return.
   Hover a native swatch then move off; the custom color should return.
3. Reopen that Apply, change to Green, then Cancel. Violet should return.
   Repeat and Apply Green; Restore should return the original visit baseline.
4. Open a fresh draft, change RGB, and wait two minutes. Check restoration.
   Also check leaving the creator without saving after an Apply restores it.
5. Try another Zabrak skin swatch, plus one normal armor color as a regression.
   Later native stock selections must win without overwriting replacements.

If CP refuses, crashes, or fails restoration, stop testing and preserve the logs.
Do not Save or Reload All Mods while the source edit is owned. Restart without
saving if the log reports a held handoff/recovery failure.

## Persistence after lifecycle checks pass

Apply a distinctive color, close CP, and use the game's character Save.
Reopen the creator, then fully restart the game and reopen again. Report
rendering on all three areas, not only a changed swatch or source RGB readback.
Finally edit the saved custom color and Cancel/Restore: its saved RGB should be
the new visit's baseline. This is native verification; mock snapshots only prove
our cleanup does not intentionally mutate a previously serialized copy.
