# Stock-preview handoff experiment — v0.2.9

## Evidence and limits

The v0.2.8 run on September 15, 2026 captured three actors. During stock blue
hover (14:25:12 UTC), the matched container's IsPreviewing became true and the
Hawks display actor's ClonedFromCharacter pointed at the data preview. Both
display fragment and torso Color 02 material getter read blue.

During cyan (14:25:26–28), the data preview fragment/material read cyan but
IsPreviewing was false, ClonedFromCharacter pointed at the equipped character,
and the display fragment/material stayed red. Its torso was visible and
recently rendered. The user reported no visible change. Cleanup succeeded at
14:25:41 UTC; the recovery file was empty.

This supports a missing stock-preview activation step, not a tint-mask failure.
It does not prove the exact internal Blueprint execution order.

Local reference sources:

- native_headers/current/BitReactorCore/Public/CustomizationInstance.h declares
  BlueprintCallable PreviewPart(SlotName, PartPrimaryAssetID), ResetPreview(),
  and the pre-preview/update/reset delegates.
- types/all_lua_types/BP_CustomizationPreviewProxyContainer.lua declares the
  container links and preview event handlers.
- types/all_lua_types/BP_CustomizationProxyCharacter.lua declares
  ClonedFromCharacter and its refresh flags.

These paths are relative to the sibling ZeroCompany_RE_Reference_v2/reference.
Generated CPP bodies are stubs, not implementation evidence. Current UE4SS
[UObject documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/classes/uobject.md)
confirms reflected function calls through colon syntax. The experiment adds no
new hooks or direct delegate calls and does not invoke guessed Blueprint graphs.

## New action

Use Preview cyan via stock hover (15 seconds); the original Preview cyan action
is still data-only. The new action:

1. Applies all existing Clone 8/Primary Accent, source/preview/target checks.
2. Requires one main-menu container linked to that exact data actor, the observed
   Hawks display class/level, display instance ownership and stock color/armor.
   Requires IsPreviewing=false and display following the equipped source.
3. Journals scalar container/display identities before native PreviewPart on the
   equipped stock swatch. This is not an equip/save or new custom-swatch action.
4. Requires the same data proxy/container/display and an active link from the
   display to the preview data. Reacquires the stock preview slot after activation.
5. Runs the existing cloned-fragment cyan install/refresh checks, auditing the
   equipped source. No direct material parameter, Blueprint flag or actor-clone
   calls are added.
6. Schedules the unchanged 15-second cleanup. At 750 ms, verifies the same
   context/link and the display's accent fragment color, target, swatch and armor.
   Failure requests immediate cleanup. Material trace gives independent material
   readback; visual confirmation is still required.

Synchronous native side effects are protected by the existing busy guard.
Later hover/equip/page-close events still request cleanup. A redundant slot
notification must also retain the expected display link to prolong the test.

## Cleanup and recovery

Restore recolors only the tracked preview fragment, with existing live-slot
verification. Only an owned handoff is reset through native ResetPreview.
The exact container/display/data links are checked again; the post-reset display
must follow the equipped source and its fragment must match that source.
The experiment expects the persistent data proxy to remain linked. If the native
API behaves differently, verification fails and recovery is retained.

A replaced swatch or externally edited fragment is not forcibly reset. An
unexpected replaced display/container fails closed instead of mutating the
replacement. Reset/verification errors retain recovery and block another apply.
Even a restored link cannot hide a failed post-reset display-color check.

The plain-text proxy-v3 journal adds container and display names to the eight
v2 fields. The handoff phase records activation intent before cyan cloning.
Pre-cyan original fragments may be rebuilt by activation; their original
color/target/ownership must validate before cleanup. v1/v2 remain readable.
Nothing is loaded as Lua, and no UObject handles are retained across callbacks.

Mock regression coverage includes active-hover/ambiguous-link refusal, native
no-op/throw paths, display not consuming cyan, reset errors/no-op/wrong color,
display replacement, displaced user swatches, malformed recovery, full module
recovery, stale settled callbacks and deferred panel actions. Native behavior,
rendering and recovery still need live validation.

## In-game checklist

Follow [the current test steps](dev-panel-tint-test.md#what-to-test-now).
Expected HANDOFF markers are BASELINE VERIFIED, CALL PreviewPart, ACTIVE,
DISPLAY COLOR VERIFIED, CALL ResetPreview, and RESTORED. A color verification is
fragment readback, not proof of pixels. Inspect MATERIAL TRACE for the torso
material and report whether cyan appears and red returns.

Do not save or accept the character during this experiment. Use Restore original
appearance if the timeout does not return red. On failure/crash, stop and report;
restart without saving if cleanup cannot be confirmed.
