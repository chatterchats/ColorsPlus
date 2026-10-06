# Read-only material trace — v0.2.8

Follow the [current in-game checklist](dev-panel-tint-test.md#what-to-test-now).
This build adds diagnostics, not a new material mutation path.

## Question

The September 15 v0.2.6 cyan experiment changed the linked data preview's accent
fragment for the full 15 seconds without a visible armor change. Does the
container-linked display actor receive that fragment, and do its material
parameters follow stock swatches versus our temporary cyan fragment?

The local reference type BP_CustomizationPreviewProxyContainer.lua declares
separate ProxyDataStorage and ProxyCharacter properties.
BP_CustomizationProxyCharacter.lua declares CustomizationInstance,
ClonedFromCharacter and refresh-delay/listener flags. These declarations justify
tracing the relationship; they do not establish which actor is actually onscreen
or what the Blueprint refresh graph does.

## Captures

The opt-in trace resolves the existing strict Clone 8 Primary Accent context
anew on the game thread. It follows only main-menu containers whose
ProxyDataStorage matches the linked main-menu preview actor. Only that matched
container's exact live ProxyCharacter reference may cross levels. It is
reacquired on each capture, never found through a global display-actor scan.
Its customization instance must report that actor as its owner; a mismatch
leaves the instance unreadable but does not suppress the actor's owned meshes.
Linked display candidates are processed first within the existing capture limits.
It logs:

- Equipped character, linked data preview and matched display-candidate identities.
- Each actor's current accent fragment/RGBA and refresh flags when readable.
- Mesh component ownership, skinned asset, visibility/recent-render hints.
- Material slot names mapped through GetMaterialIndex, then zero-based GetMaterial.
- Dynamic/constant material instance Color 01 and Color 02 K2 getter values.
- Relevant vector overrides, including parameter association/index, through
  bounded parent chains.

Engine.lua's reflected K2_GetComponentsByClass, mesh/material accessors and
K2_GetVectorParameterValue signatures are used. No non-reflected native C++
GetVectorParameterValue overload is assumed callable from Lua.

Captures occur at arming, before/after the existing cyan refresh, and at
150/750 ms after UI events, successful cyan application and restore attempts.
Event snapshots coalesce. Missing properties/getters produce explicit errors;
one missing field is not treated as a zero value or a successful measurement.

## Limits and interpretation

The v0.2.7 in-game run on September 15 at 14:17:17 UTC read cyan from the hidden
data actor's torso material, not only its fragment. The matched container pointed
to BP_HawksCustomizationProxyCharacter_C_0 in the HawksCustomization level, but
the old main-menu-only actor filter omitted its details. This is the filter
corrected in v0.2.8. IsPreviewing was true during stock hovering and false during
cyan; DelayProxyRefreshing was true in both. Neither flag is modified by this
trace, and their causal role in the missing visible update is not established.

This module never creates dynamic material instances, sets parameters or
materials, clones actors, or triggers refreshes. The separate cyan action keeps
its existing validation, ownership, recovery and 15-second restoration behavior.
A trace failure cannot prevent cyan cleanup.

The window expires after 60 seconds or at most 20 captures and stops on page close.
Each capture follows at most 8 containers, 4 distinct actors, 24 meshes per actor,
16 slots per mesh, 48 unique material details and 4 parent-chain levels.
The shared array reader refuses more than 64 entries; limits/errors are logged.
Only scalar/window bookkeeping survives between captures, never UObject handles.

Look for MATERIAL TRACE markers alongside TINT in colors_plus_probe.log or
UE4SS.log. Match material object names back to the actor/mesh/slot records.

Visibility and recent-render flags are hints, not proof of screen ownership.
A K2 getter returning zero/default does not establish that a parameter exists.
Overrides may have material-layer associations: identical names need not target
the same parameter. A stock color change provides the control observation for
interpreting these records. Only runtime captures can establish which path
tracks the user's visible armor.

## Local validation

material_trace_test.lua exercises linkage (including unrelated-container exclusion),
real slot-index mapping, fragment/material differences, parent overrides/cycles,
unavailable getters, bounded enumeration, game-thread reads, mutation traps,
inactive behavior, timeout/capture limits and stale-window cancellation.
Cross-level tests cover the linked actor, replaced/invalid links, instance-owner
mismatches, unrelated/foreign containers and unchanged source/data scope.
tint_test.lua covers trace callbacks around apply/restore, error isolation and
deferred Dev Panel actions. These mocks do not validate native engine safety
or visible behavior; the in-game capture is still required.
