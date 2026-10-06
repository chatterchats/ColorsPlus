# Skin material and Dev Panel dispatch capture — v0.2.46

Fully restart; do not Reload All Mods. No Apply or save is needed. Keep clothing
unchanged and restore any earlier custom edit before selecting another swatch.

## Skin comparison

Run the following once on human **Skin Tone 5**, then again on **Skin Tone 16**:

1. Select the swatch and move off the stock palette. Run `colors_materials start`
   in the console. This captures the stock baseline and opens a 60-second window.
2. Run `colors_picker open`, close the console, and move the RGB sliders to a
   conspicuous color. Note whether the face and exposed body actually change.
3. While the preview is still active, run `colors_materials sample`. If CP closed
   before the sample, report that; the log records whether a preview was active.
4. Run `colors_picker restore`, then `colors_materials sample`, then
   `colors_materials stop`. Restore should finish before the following sample.

Finish each sequence within 60 seconds. Start a new window if it expired. The
trace is capped at 20 captures and uses the existing exact linked display actor,
not a global display-actor scan. Skin reads prioritize assigned MI_Head, MI_Body
and MI_Neck materials. Logs include source asset/layout, fragment RGB and scalar
targets, material getters for Skin Coloration/Enable Tinting, and matching vector
and scalar overrides with association/index along a maximum four-node parent
chain. Getter zero/default values do not establish parameter presence. Errors
or missing slot labels are evidence gaps, not a reason to modify materials.

## Dev Panel delivery

On a supported color palette, with CP closed:

1. Run `colors_panel status`.
2. Open DP and click **Open live RGB picker** once. Wait a second.
3. Run `colors_panel status` again. If CP did open, restore it afterward.

The status command is read-only: it does not consume/replay clicks or restart
the client. Compare polls, queued/invoked totals, open_seen/open_disk, pending
jobs, and last_error. The delivery log stages are COUNTER → QUEUED → INVOKE →
PANEL DISPATCH RECEIVED → RUN → PICKER OPEN BEGIN. First-poll and deduplicated
poll-error messages distinguish a stalled callback from state parsing or later
dispatch trouble. The installed SWZC Dev Panel app has not been changed.

## Findings so far

v0.2.45 loaded and console opening succeeded on 5. Its changed RGB was observed
in the linked display fragment, but the user saw no visual change. Those
readbacks do not prove the rendered material received/enabled the tint.

DP logged clicks and its registry points to the live Colors+Probe directory,
but the picker received no open request. The exact dispatch failure is still
unproven. The local client previously suppressed polling errors and could mark
a changed state file consumed even when parsing failed; this now reports the
error and retries without resetting the last valid counters. It is not yet
established that this caused the user's missing clicks.

A separate startup os.date error aborted one callback. Timestamp formatting now
falls back to an explicit unavailable marker rather than aborting its caller;
this is not evidence that the scheduling/dispatch problem has been fixed.

References checked: the local Engine.lua material instance scalar/vector getter
and override definitions; UE4SS delayed-action documentation retrieved with
Context7. The existing explicit-handle game-thread scheduling is retained.
