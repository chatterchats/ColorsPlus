# Current Dev Panel controls (v0.2.94)

## Character Suite iris colors

Shared **Iris Colour**, **Left Iris Colour**, **Right Iris Colour** and **Inner
Iris Colour** support the normal launcher and this panel's **Open live color
picker**. This requires the rebuilt Character Suite eye shader. RGB edits keep
recolour/inner amount and exact eye targeting. Test None as well as a preset.
See the [iris rendering and lifecycle test](appearance-palette-testing.md).

## Vitiligo and scar colors — v0.2.89

Fully restart into v0.2.94 with the 10-01 Character Suite build. Select a visible
vitiligo/scar pattern, then open **Vitiligo Tint** or **Scar Look** and click the
preset to equip it. Hovering does not select it. Use **Custom Color** or
**Colors+ Picker → Open live color picker**. Both slots have automatic launchers,
including from None.

Rebuilt scar Looks and Tint presets use the RGB wheel. Edit only `MM Scar Tint`;
`COS Swatch` and `MM Scar Tint Strength` remain unchanged. Cancel/Restore retain
exact native tint multipliers above 1. Test Fresh Pink, Pale Silvery and a Tint
preset, then the None fallback. See the [vitiligo/scar rendering and lifecycle
test](appearance-palette-testing.md).

The following HSV instructions apply to the earlier 09-30 Character Suite build.

For **Raw Red**, **Fresh Pink**, **Pale Silvery**, **Aged Brown** or **Dark**,
the picker opens three native HSV adjustment sliders with numeric inputs.
The selected Look stays equipped, and the initial values match its current
`Scar HSV Shift`. These are the game's adjustment values, rather than an
absolute HSV color. Change one value a little, then test **Cancel / close
picker**. Reopen, change a value and use **Apply picker color**. Return through
the radial selector, then use **Restore original appearance**. Check that the
Look remains selected and Cancel/Restore recover its exact original values.

Vitiligo and RGB scar tints (**Red, Pink, Silver, Brown, Umber, Bruised, Burn**)
keep the hue/SV/hex color wheel. Scar tint strength must remain unchanged.
Starting from None temporarily borrows an RGB preset; also test None → Open →
Cancel/Apply → Restore. Correct incomplete or out-of-range numeric/hex input
before Apply, including when applying through the Dev Panel.

Test without saving on this first HSV rendering pass. If opening or the visible
color fails, close/restore CP, select the same preset and use **Capture color
compatibility**; report the slot, preset and failed operation. Regression mocks
cover the lifecycle and recovery; they cannot verify the native shader output.

The Colors+ Probe catalog has two groups. The separately installed Dev Panel
application is unchanged; DP can remain open across screen changes. v0.2.34
updates only Colors+'s local client helper to register when a panel reinstall
has removed registry.txt. Creation requires the installed panel entry script;
existing registrations are preserved. No registry is created if DP is absent.

## Colors+ Picker

- **Open live color picker**: equivalent to `colors_picker open` on a supported
  selected color slot, including captured race bundles, Character Suite shared,
  left, right and inner iris colors, vitiligo
  and scar tints/HSV Looks. HSV Looks use native adjustment controls and retain the
  selected preset. Vitiligo/scar slots also have the Custom Color launcher.
  None/Default uses the existing reversible stock-swatch fallback.
- **Apply picker color**: equivalent to `colors_picker apply`; flush the latest
  color/HSV adjustments, retain them in the editor and close CP. Does not invoke the game's Save.
- **Cancel / close picker**: equivalent to `colors_picker close`; discard the
  current un-applied preview, preserving an earlier applied color if present.
- **Restore original appearance**: close CP and undo the tracked preview/applied
  color. This is not an undo operation for a completed game save.

## Colors+ Diagnostics

- **Capture color compatibility**: `colors_compat`, selected slot/palette/material
  evidence, now including companion gameplay tags, scalars and missing meshes.
  Close/restore CP first.
- **Inspect tint target**: read-only targeting/eligibility check.
- **Trace screen transitions / Stop screen trace**: `colors_screens start/stop`;
  bounded page/stack snapshots across navigation. Close DP after starting for
  cleaner capture. Stopping does not alter colors or other diagnostics.
- **Trace materials / Stop material trace**: existing bounded display/fragment/
  material comparison, now including Skin Coloration/Enable Tinting and their
  parent overrides. Console fallback: `colors_materials start/sample/stop`.
  These are diagnostics, not proof of visible color.
- **Trace stock hover calls / Stop stock hover trace**: existing stock-call
  timeline. Restore CP first. Starting cancels queued picker writes; while
  capture is active, picker Open/Apply are refused.

All diagnostics are read-only. Starts retain their existing bounds (screen
trace: 60 one-second samples; material/stock traces: 60-second windows).
Diagnostics still enforce their existing context restrictions.

Old cyan, stock-handoff, blue-swatch and RGB-cycle buttons are removed from the
catalog; the underlying regression-tested helpers remain intact. Character
Suite iris colors use the normal picker; see the [iris test](appearance-palette-testing.md).
Existing `colors_eyes` console experiments
remain opt-in, with `colors_eyes stop` for cleanup, but have no panel buttons.

## In-game check

1. Fully restart the game to load v0.2.94. Do not use Reload All Mods while the
   known post-reload crash is unresolved. F6 > Refresh if needed.
2. Confirm the two groups above and that old cyan/cycle buttons are absent.
3. On a previously working color slot, Open CP, change RGB, then use DP's Apply.
   CP should close and the color remain. Reopen, change RGB, then DP Cancel:
   the earlier applied color should return. DP Restore should undo that applied
   color. Repeat Open/Cancel from Default to check its fallback restores.
4. With CP restored/closed, capture compatibility and inspect the target. Check
   `COLOR COMPAT |` and `TINT |` in `colors_plus_probe.log`.
5. Start screen tracing, close DP, navigate to the radial selector/Databank and
   return. Open DP and stop the trace; check `SCREEN TRACE | START/STOP`.
6. On the color page, start/stop material tracing. Separately start stock-hover
   tracing, hover stock swatches, then stop it. Confirm CP can open afterward.

No character save is needed for this menu check. CP drafts have no timed
expiry in v0.2.94; Cancel, context cancellation and recovery remain active.
Automated tests cover dispatch
and cancellation logic; native UI behavior still needs this in-game check.

The current feature checkpoint is [human skin testing](human-skin-testing.md).

For missing button delivery, run `colors_panel status` before and after one
click. It reports client poll/delivery counters without replaying actions.
Follow the [current diagnostic test](skin-material-dispatch-testing.md); the
installed Dev Panel application is unchanged.

v0.2.39 automatically starts a short, bounded per-call diagnostic window on
picker opening; no extra DP action is needed. See the current
[crash-capture test](picker-crash-tracing.md) before further stress testing.
