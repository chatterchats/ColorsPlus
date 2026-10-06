# Stock-hover call trace — v0.2.10

## Why this run is read-only

The v0.2.9 attempts on September 15 at 14:39:56 and 14:44:35 UTC called native
PreviewPart with the equipped stock swatch. Immediate verification failed before
cyan was installed. Rollback completed and emptied recovery. Later samples were
post-rollback, so they cannot distinguish a same-swatch no-op from delayed work.

This trace watches natural hover behavior instead. It never calls PreviewPart,
ResetPreview, CloneFrom, setters or refresh functions. It does not change the
handoff experiment or its rollback timing. Cyan panel actions are blocked while
this read-only trace is armed; arming refuses an active tint session.

## What is captured

Nine additional UFunction hooks are installed on demand:

- CustomizationInstance PreviewPart: native pre/post, caller, slot tag and asset ID.
- CustomizationInstance ResetPreview: native pre/post and caller.
- SetPreviewCustomizationInstance: native pre/post and new instance.
- Container CustomizationPrePreviewUpdated: Blueprint post, slot tag and asset ID.
- Container CustomizationPreviewSet: Blueprint post, old/new instance.
- Container CustomizationPreviewReset and OnPreviewRefreshed: Blueprint post.
- Display CloneFrom: Blueprint post, source actor, weapon/injury/pose arguments.
- Display RefreshCharacterCustomization: Blueprint post.

The existing slot-view-model hook also forwards PreviewCustomizationPart's part
view-model identity and asset ID. It remains a post callback, not a new duplicate
hook. Other existing slot events are named in the timeline.

Current UE4SS [RegisterHook documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/registerhook.md)
specifies native pre/post and Blueprint post-only behavior. The trace labels
those phases explicitly and always returns nil through the owned runtime guard.
It hooks reflected event handlers, never delegate signatures or an ubergraph.
Game-specific signatures and paths were checked against the local reference
Lua types, native headers and object-symbol index.

Borrowed RemoteUnrealParam values are converted to scalar strings inside the
callback. Only the armed identities, counters and correlation sequence survive
between callbacks. Contexts are filtered to the exact selected slot, source/data
instances, matched main-menu container and its linked cross-level display.
Other actors' arguments are not captured. The trace does not claim callback
ordering is the full internal Blueprint execution order.

After post callbacks, 50/250/1000 ms jobs reacquire the current context. They
record equipped asset, IsPreviewing, delay flags, ClonedFromCharacter, and the
source/data/display accent fragments' asset IDs and RGBA. Jobs coalesce around
the latest callback; after_sequence identifies it. These are requested delays,
not precise latency measurements. A new event can supersede earlier samples.

## Bounds and gaps

The window lasts 60 seconds, with at most 160 logged callbacks and 60 samples.
Page close, explicit stop, or invalid/replaced context stops delayed sampling.
Stopped callbacks are inert; the owned hook registry removes hooks and cancels
work at reload. Re-arming retries missing hooks without duplicate registrations.
Hook coverage and failures are logged. Missing callbacks are not proof that the
game skipped a path, especially when coverage is incomplete.

This run can show which arguments natural hovering passes and whether its link
changes between callbacks and settled checks. If the UI short-circuits hovering
an equipped swatch before calling PreviewPart, it will not by itself prove how
the direct native call behaves asynchronously; a later controlled test may still
be needed. No diagnosis of native same-swatch behavior is assumed in advance.

## Test

Reload mods, open Clone 8 Primary Accent with red selected, and move off swatches.
F6 → Colors+ Probe → Trace stock hover calls (60 seconds). Close F6.
Hover selected red for two seconds, move off for two, hover blue for two,
move off for two, then hover selected red again and move off. Do not click
swatches, run cyan, or save. Report blue-hover visibility and return to red.

Look for STOCK CALL TRACE in colors_plus_probe.log or UE4SS.log. Expect ARMED,
native-pre/native-post, blueprint-post, argument lines, coalesced samples and STOP.
Local tests cover hook phases/IDs, scoped argument capture, expired wrappers,
read-only enforcement, missing-hook retry, coalescing, cancellation, limits,
stale callbacks, page-close routing and cyan-action refusal.
