# Arbitrary RGB preview — v0.2.13

## Confirmed result

The v0.2.12 run on September 15 at 22:36:44 UTC read sRGB (255, 128, 32),
installed linear RGBA (1, 0.215861, 0.014444, 1), passed both installation
checkpoints and the display check, and restored the equipped red at 22:36:59.
Recovery was empty. The user confirmed visible orange followed by red.
The next test verifies violet and green through in-place updates on that path.

## Input

Edit [rgb.txt](../src/Colors+Probe/DevPanel/rgb.txt) to contain exactly three
comma-separated integer sRGB channels, each from 0 to 255. Whitespace and a
trailing newline are accepted. No alpha, comments, expressions or Lua code.
The file is read again each time **Preview custom RGB (5s/color)** is clicked,
so changing values does not require another mod reload. It supplies only the
first color; the second and third are fixed violet and green for this probe.

The default cycle:

- Orange (initial file): 255, 128, 32
- Violet: 160, 64, 224
- Green: 64, 208, 112

The conversion normalizes each channel to s = value / 255, then uses
s / 12.92 for s <= 0.04045, otherwise ((s + 0.055) / 1.055)^2.4.
Orange becomes approximately linear RGBA (1, 0.215861, 0.014444, 1).
These are color inputs, not predicted screen pixels: the tint mask, base texture,
wear, lighting and material still affect the visible result.

Input must fit in 256 bytes. Missing, malformed, fractional, negative or
out-of-range values are refused before any preview call or recovery write.
Alpha remains 1; the existing blue-handoff opaque-source guard still applies.

## In-game test

1. Reload All Mods to load v0.2.13. Keep Clone 8, Primary Accent, stock red
   selected. Move the pointer off all swatches.
2. F6 → Colors+ Probe → Trace materials (60 seconds).
3. Run **Preview custom RGB (5s/color)** once, close F6 and keep off swatches.
4. Confirm orange → violet → green, each held for five seconds, then original red.
   This runs once, not on repeat. Engine work can add a small delay between steps.
5. Restore original appearance stops the sequence early. Do not click a second
   time during the sequence; concurrent tests are refused.

Do not run the read-only stock-hover trace concurrently: it blocks write tests.
Do not save or accept the character during testing. If restoration fails,
use Restore original appearance; report the failure and restart without saving
if necessary. No save/load persistence claim is being tested yet.

## Verification and recovery

The blue-first path is unchanged: verify stock blue on the data and display
actors, clone the equipped fragment into the data preview, install the custom
linear color, verify the installed copy and refreshed live slot, then check the
display after 750 ms. Equipped source checks remain.

After five seconds, reacquire and validate the owned fragment and source, write
the next color in place, refresh, and revalidate. Check the display again after
750 ms. There is only one blue activation and one installed fragment for all
three colors; intermediate steps do not reset to red or install new clones.
After the third five-second hold, restore the owned fragment to blue and reset
the stock preview back to red. A fixed, independent 20-second safety timeout
also restores if normal sequence completion does not happen. The cycle ends
on context changes, manual restore or a verification failure. Delayed work from
an old step/session cannot advance or restore a newer step/session.

Expected markers include RGB INPUT (both sRGB and linear values),
BLUE BASELINE VERIFIED, CHECKPOINT after-install/after-refresh passed=true,
PREVIEW APPLIED with custom_linear_rgba, RGB CYCLE STEP (1/3, 2/3, 3/3),
DISPLAY SAMPLE VERIFIED with each color's RGBA/revision, RGB CYCLE COMPLETE,
and RESTORED. RGB CYCLE FAILED records an early stop.
The recovery file should be empty after cleanup.

The fourteen-line proxy-v5 recovery record extends v4 with the intended linear
RGBA as its final line. This is persisted before activation and installation;
restoration and reload recovery compare against that recorded target, not cyan
and not the current RGB file. Changing the input file during a test cannot
replace its target or alter cleanup. Records v1–v4 remain readable, and malformed
v5 targets block recovery writes.

An in-place transition temporarily uses proxy-v6: the same fourteen fields
plus a fifteenth field holding the previous linear RGBA. It is valid only in
the owned phase. This record is written before SetColor, so cold recovery can
restore either the previous or next color on the exact owned fragment. After
the refreshed slot passes verification, the record returns to v5. Recovery
always restores; it never resumes an interrupted cycle.

Local tests cover conversion endpoints and the sRGB branch boundary, orange,
violet, green, black, white, invalid input, active-test isolation, copied
fragments, context checks, timeout, reload with changed input, reset failure,
malformed recovery and stale callbacks. Cycle tests also cover in-place
identity, single activation/reset, five-second holds, unchanged watchdog,
manual/context cancellation, missed display updates, transition recovery on
both sides of the setter, and throwing setters before/after mutation.
On September 15 at 22:44:52, 22:44:57 and 22:45:02 UTC, the cycle advanced
through orange, violet and green. All three display samples verified; the cycle
completed at 22:45:07 and restoration verified at 22:45:08, with empty recovery.
The user confirmed every color and return to red. The next checkpoint is the
[interactive picker](live-picker-testing.md), not another timer-only test.
