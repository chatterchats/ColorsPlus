# SV drag-input probe — v0.2.77

**Result:** User verified dragging, fast clicks and focus return. Desktop counts
rose steadily while viewport counts did not; capture remained yes. This confirms
the frozen-viewport / working desktop-delta path. v0.2.78 integrates it into CP;
see [integrated tests](picker-drag-performance-testing.md). Event-hook delivery
is still not demonstrated. The instructions below document the isolated probe.

v0.2.76 opened and rapid clicking worked. Drag status changed but coordinates
usually froze; one drag worked after switching focus. The captured session
reported **events=0, fallbacks=65**, then closed on unavailable mouse position.
Thus the event bridge has not been demonstrated. v0.2.77 tests desktop cursor
deltas during a held press and compares both coordinate sources. It does not
claim that viewport-coordinate freezing is already confirmed as the cause.

The v0.2.75 attempt reached the pointer read but refused `Ambiguous mouse X`.
v0.2.76 passes a shared output table and explicitly reads `LocationX` and
`LocationY`, rather than counting numeric entries. This addresses the parser
failure; press-event delivery, dragging and native DPI alignment remain unverified.

This is a separate input test, not the production picker. It never calls the
tint backend, changes a character color, writes recovery journals or invokes
Save. The existing 24-by-16 production SV input is unchanged pending this test.

## Test

1. Fully restart. Open a normal customization color selector, leaving CP closed.
2. Run `colors_sv start` and close the console. Expect a small overlay titled
   **SV INPUT TEST - NO CHARACTER COLOR WRITES**, with a cyan SV area and counters.
3. Quickly click near each corner and several middle positions. The marker
   should land there, even for a short click. Note whether **event** increments
   for each press or **fallback** is doing all the work. A fallback-only result
   means the event bridge has not been proved; do not treat it as a quick-click fix.
4. Hold left mouse and drag horizontally, vertically and diagonally. The marker
   and S/V numbers should follow continuously; moving outside the box while
   held should clamp to its edges. Release outside, then move back in without
   pressing: the marker must stay still. Also try releasing inside.
   Watch **Desktop**, **viewport** and **capture**: if Desktop increases while
   viewport stays fixed and the marker follows, that supports the frozen-
   viewport hypothesis. If both stay fixed, or capture says no during the hold,
   report that instead. The counters count changed samples, not pixel distance.
5. Hover without clicking and right-click: neither should change the marker.
   Character appearance must remain unchanged throughout.
6. Click **Close input test**, reopen and use `colors_sv stop`. Reopen once more
   and back out of the color page; it should close. Optional: let its 90-second
   timeout expire. Normal Custom Color should still work after the probe closes.
7. Switch focus away and back during a drag. If mouse position becomes
   unavailable, the probe should stay open, end the drag and wait for release.
   Release and make a fresh click before dragging again; it must not resume
   from the previous press. Context/page changes still close the whole probe.

Report marker lag/missed clicks, whether capture continues outside the box,
the event/fallback counts, and any screenshot or `SV INPUT PROBE | FAILED` line.
If it refuses to open, the log should identify hook, position or host validation
failure. No color-persistence retest is needed for this input-only build.

## Implementation boundaries

- A fixed 400-by-240 SV rectangle at viewport-layout (52,235) avoids passing
  FGeometry or inferring native selector bounds. Mouse coordinates come from
  WidgetLayoutLibrary.GetMousePositionScaledByDPI via one shared scalar-out table.
  Its named LocationX/LocationY values must be finite numbers; unrelated entries
  are ignored and missing axes refuse input. This coordinate bridge still
  requires native testing.
- UserWidget.OnPreviewMouseButtonDown is observed only for the exact owned
  root identity. Only callback RemoteUnrealParams are unwrapped. Mouse events
  and UObject wrappers are never retained; hooks never return FEventReply.
- The native button, not Lua, captures and releases the mouse. Its IsPressed
  state and HasMouseCapture are sampled at 16 ms with no character updates.
  GetMousePositionOnPlatform supplies desktop coordinates; each drag starts
  from a validated viewport position and applies desktop deltas divided by
  GetViewportScale. No native geometry conversion or input-mode write is used.
  A scale change invalidates the anchor and ends the current drag.
  The press event records a quick click even if the button is released before
  the next sample. The pointer marker is updated by the next sample, not in
  the event callback. Release/capture loss freezes the last sampled position.
  The previous sentence describes the intended event path, covered by mocks;
  native v0.2.76 received no such events and used polling only. Coordinate loss
  now suspends the current drag without destroying the probe. Capture state
  is diagnostic; IsPressed release or coordinate loss ends input.
- Scope checks, owned delayed jobs, exact-root cleanup and failed-removal
  retention prevent stale callbacks/duplicate roots. CP refuses to open until
  the probe closes; the probe refuses an active CP/preview. Hooks are registered
  lazily on probe opening and unregistered by normal runtime teardown.
- Existing tint, Apply/Cancel, persistence and production input cadence are
  unchanged. Passing this test is evidence for a future integrated control,
  not proof that all production UI/backend lag has been eliminated.

Documentation lookup confirmed the hook API's callback wrappers, ownership
IDs, and nil-return behavior; it also forbids hooking delegate signatures.
The probe observes the ordinary UFunction rather than a delegate:
[UE4SS RegisterHook](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/registerhook.md).

Named scalar outputs and first-table reuse were checked against
[UE4SS LuaUObject.cpp](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/UE4SS/src/LuaType/LuaUObject.cpp).
