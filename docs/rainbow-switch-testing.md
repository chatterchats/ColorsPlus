# Rainbow launcher and HSV pane — v0.2.94

## Current focused check — native heading / aligned hex row

Fully restart into v0.2.94. Open **Iris Colour** or **Skin Tone**. The custom
picker's **CUSTOM COLOR** heading should use the same branch marker and native
font as the normal **SKIN TONE** label. The combined hex textbox, eight-unit
gap and color preview should span the same centered width as SV and hue.

Test hex typing/correction, SV dragging, hue, Cancel, Apply and reopening.
Cancel restores the opening color; Apply retains the edit. Both reveal the
normal labels, slider, swatches and launcher. The title should remain correct
on repeated openings and on vitiligo/scars, with no duplicate native headings.

Cancel remains the only return button. The footer and draft timeout are still
removed; input errors appear above the buttons only when needed. Leaving a
color page or ending the creator visit still cancels an open draft.

All 42 regression programs pass, including native factory call arity,
initialized heading children/caption, aligned combined hex row and cleanup
before/after heading failures. Native font/marker rendering needs this check.

## Scope

Test the first native saturation/value area, hue strip and editable hex input,
keeping the tested RGB preview/Apply/Cancel/source persistence. Smooth gradient
images cover the area, with 24-by-16 clickable targets, not a free-drag surface; the continuous hue
slider and exact hex input are not restricted to those cell colors. A saved
palette and controller navigation are not implemented. Keyboard focus is left
to the native text box; the mod does not change input modes or cursor state.

## Load

Fully restart the game. Do not Reload All Mods with DP/CP open or an applied
skin override owned. The installed mod is `ue4ss/Mods/Colors_Probe` in this setup.
Its changed scripts/metadata are deployed separately from logs and journals.

## Opening crash smoke test first

v0.2.72 opened and handled input, timeout and cancellation successfully. Its
SV field was invisible, hue strip visibly tiled, hex text low-contrast and
opening slow. v0.2.73 draws separate texture layers rather than button children,
uses dark text and removes automatic heavy call tracing. Restart, open once,
and check that the SV field is visible (white top-left, chosen hue top-right,
black bottom), the hue strip is smooth and the hex text is readable. Compare
first and second opening delays. Native import/rendering still needs this test.

v0.2.70 crashed in the first cell's `SetStyle` call. v0.2.71 removes whole
button-style arguments and paints owned child Borders instead. This is a native
workaround to verify, not a crash fix established by mocks. Native v0.2.71
constructed the SV area without crashing, then refused the first hue-strip
setter with `UFunction expected 1 parameters, received 2` and removed the UI.
v0.2.72 fixes the helper's extra diagnostic return; the strict setter mock
reproduces that exact construction-stage failure before the fix.

Open Custom Color once on the same slot, wait five seconds without editing,
then Cancel. Confirm normal swatches return and capture a screenshot of the
opened pane. Only continue the input tests below after this succeeds. If it
crashes, do not keep repeating it; the build-stage checkpoints will narrow it.

## Test

1. Open Tops > a color zone. Without opening DP, look for the rainbow
   **Custom Color** button below the native list. Confirm normal swatch
   scrolling, clicking and the selected-slot header still work. Compare long
   Tops and short Horns lists: the footer now uses spare vertical selector space.
2. Click Custom Color. Expect the HSV controls inside the lower
   swatch area, with the slot/zone header still visible. No floating panel
   should cover the header or character, and the native swatches must be hidden behind
   the transparent picker even on Horns. Click near top-left (white), top-right
   (full saturation), bottom (black), and the middle. Drag the hue strip after
   selecting a saturated cell; verify preview, marker and hex follow. Hovering
   without clicking must not change the color. The area is click-only this pass.
3. Click **Cancel**. Expect the opening color restored and the original native
   list, labels, slider and launcher revealed. Reopen and repeat.
4. Reopen, type `#FF8020`, `#00FFFF`, `#A040E0`, and `#5C5C5C` into HEX COLOR.
   Each complete six-digit value should preview; lowercase and no `#` also work.
   Type an incomplete or invalid value: keep the last valid draft, show guidance
   and refuse Apply without closing. Cancel must still work. Check typing,
   selecting and replacing text, and that the game remains responsive.
5. Enter a complete hex value and immediately click **Apply Color**. Expect the picker to close,
   native swatches to return, and the applied color to remain. Reopen and
   cancel a different draft; it should return to the applied color.
6. Test opening from Default, then Cancel. Default must be restored.
7. With a draft open, switch color zones or back out to radial/Databank.
   The draft must close. Re-enter a color zone and confirm exactly one
   launcher appears and can reopen. No launcher on a mesh/style selector
   or on the excluded Eyes selector.
8. Leave a draft open for at least three minutes: it must stay open. Edit again,
   then Cancel and confirm the normal palette returns. Repeat on hair and skin.

Please report placement/clipping, whether the button appears automatically,
and which slot/race failed. A screenshot is especially useful for layout.
If attachment fails, try `colors_picker open` on the same color selector;
it uses the same path and logs a more direct failure. Do not save an abnormal
session. Use the existing Restore command after testing applied edits.

## Evidence and safety

`color_ui.lua` follows the existing active-page/selected-slot resolver and
creator-stack binding. Only ancestor panels inside the exact SelectionTiles
WidgetTree are eligible: an Overlay to host our picker and a VerticalBox to
append our launcher. The grid, native sibling branches along its ancestry
and our launcher are temporarily Hidden while the picker is attached. This
includes lower labels and injected slider rows, using their verified native
panel parents rather than assuming they share a WidgetTree object path. Host
ancestors stay visible; native desired size, items, child order, focus and
switchers are unchanged. Every target's original visibility is restored after
removing the picker root. The pane brush and input
shield are transparent; the shield has no picker action and sits below controls.
The picker root fills the verified host in both dimensions and reserves a
560-unit desired height for short selectors. SV, hue and the combined hex/preview
row use centered 400-unit SizeBoxes. The heading is a newly created instance of
the game's SlotSubItemName Blueprint, initialized through the reflected
WidgetBlueprintLibrary.Create function. Its Caption is set before attachment,
then SetText runs after native Construct. It ignores pointer input and remains
a child of the owned picker; stock heading widgets are not changed.

Visibility intent is recorded as bounded plain strings through UE4SS ModRef
shared variables before the first native setter, including every control's
original visibility. Cleanup reacquires exact objects and restores only
still-Hidden targets with their recorded parents; native visibility changes,
destroyed widgets and reparenting retire those targets without a write.
The shared record survives a Lua reload but cannot persist into another game
process. Failed restoration retains the record for retry.

No cached geometry or coordinate-conversion calls are needed. Lower list
headings are hidden; the slot/zone header outside SelectionTiles stays visible.

Native v0.2.68 logs confirmed attachment and click dispatch on Skin Tone/Horns,
but opening failed at `Unreadable geometry: host point` after `AbsoluteToLocal`,
before preview writes. v0.2.69 removes that dependency and makes the rainbow
decoration visible without hit testing. The user verified opening and Back/Cancel
restoration, but Horns screenshots showed the Canvas background ending above
its overflowing controls. The v0.2.70 SizeBox fixes desired-height propagation;
new native layout, input behavior and cost still require this test.

The September 30 v0.2.70 probe/UE4SS logs end at `UI HSV cell.SetStyle` BEGIN
(call 123), with no RETURN and before tint preview begins. Crash reports
`CE0CE3AC4CDD0917A8679CA6B4F50682` and `86001F944C83BD785385A79D6D944B14`
share stack hash `831460A0CF16325B3DA8E1546C11DB1D72CC6F7B` and native write
access violations. The exact C++ fault is not symbolized. No native `pcall`
fallback is attempted: v0.2.71 does not call `SetStyle` at all. Stock buttons
remain interactive. v0.2.73 removes their child Borders and instead layers an
opaque hue base, white-to-transparent saturation image and transparent-to-black
value image as siblings beneath the transparent input grid. Only scalar texture
and widget identities survive callbacks; brushes hold native texture references.
The 1024-pixel hue image replaces tiled chips. Regenerate/check assets with
`node tools/generate-picker-gradients.mjs` / `--check`; include `Assets/` when
deploying. No whole Slate style marshalling is introduced.

Readiness is event-started, deferred, coalesced and limited to four attempts.
Only an attached launcher has a 33 ms button/lifetime poll. Press edges defer
opening by 100 ms; page/slot identity and generation are checked at dispatch.
No UObject wrapper is retained across callbacks. Exact owned roots are cleaned
up on context exit/reload; failed native removal retains the identity and blocks
duplicate installation. Existing skin/source reload restrictions remain.

Logs: `COLOR UI | ATTACHED`, `LAUNCH`, `SWITCH`, `NOT ATTACHED`, `RETIRED`,
and `PICKER VIEW | ATTACHED` / `PICKER | OPEN FAILED`. Expect
`COLOR UI | SWITCH | layout=fill` when the picker passes host validation.
`PICKER VIEW | HSV SV READY`, `HSV HUE READY`, `HSV HEX READY` and `HSV READY`
mark construction stages independently of the bounded call-trace window.
Detailed call tracing is off for normal openings. Use `colors_picker trace`
only when capturing a failure: it opens one traced picker and can cause hitches.

Automated tests exercise launcher scoping, real picker-view integration,
geometry-free fill anchors, visible rainbow decoration, deferred/held presses,
fixed-height ownership, forbidden whole-style calls, separate gradient/input
layer ownership, asset alpha endpoints, single-argument native color setters, HSV/hex synchronization,
grey hue retention, invalid
hex/Apply refusal, single-update hue redraw, actual coordinator Apply flush and Cancel,
replaced wrappers, stale callbacks,
slot/page changes, bounded readiness, cleanup failure and exact reload cleanup.
They do not establish native marshalling or visual layout; this test does.
