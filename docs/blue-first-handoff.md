# Blue-first display handoff — probe v0.2.11

## Evidence and hypothesis

The September 15 v0.2.10 stock-hover capture at 15:08:38–15:09:38 UTC recorded
34 callback events and 25 state snapshots. Hovering Blue_14 produced a slot-VM
PreviewCustomizationPart callback with that part VM; the container was previewing,
the display followed the data actor, and both carried blue. Moving off reset
the preview to the equipped red source. Hovering equipped Red_14 did not activate
that handoff through the sampled 1000 ms window.

No native CustomizationInstance preview/reset callbacks were captured. That
does not establish that native functions were never called internally.

The v0.2.11 run at 22:15:55 UTC on September 15 confirmed this path: the blue
baseline and both installation checkpoints passed, cyan reached the display
fragment, and the user confirmed visible cyan. At 22:16:10 the 15-second timer
restored the fragment, called SlotVM.ResetPreviewedPart, verified the display
following the equipped source, and cleared recovery. Equipped red was unchanged.
The user also confirmed the visible return. This proves temporary preview on
the tested armor/slot, not saving, other slots, or a completed color picker.

## Implementation

The game reference headers declare the selected slot VM's callable
PreviewCustomizationPart(partVM) and ResetPreviewedPart() methods in
reference/native_headers/current/BitReactorGame/Public/BitReactorCustomizationSlotViewModel.h
in the sibling ZeroCompany_RE_Reference_v2 corpus. The part VM header exposes its
AssetId. Current [UE4SS UObject documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/classes/uobject.md)
confirms reflected member calls use colon syntax. These signatures alone do
not prove game behavior; the runtime trace supplies the entry-point evidence.

The test finds exactly one live cached native Blue_14 part VM in the same
GameInstance outer as the selected Primary Accent slot. It does not create a
part VM, invent an object suffix, or equip the asset. The scan is capped at
2048 cached VMs and refuses ambiguous results.

The existing Clone 8, source, preview, ownership and material-target guards
remain. An opaque source different from Blue_14 and an inactive stock hover are
required. Blue_14 must read back as linear RGBA (0, 1/15, 0.2, 1) on both data
and display before the existing cloned-fragment cyan installation. Source
identity, part and color are rechecked after activation. The display's cyan
fragment is checked after 750 ms; visual confirmation is still necessary.

Cleanup restores the owned cyan fragment to the verified blue baseline, then
uses the recorded slot VM's ResetPreviewedPart to return the display to the
equipped source. There is no fallback to a native owner reset, direct flag edit,
actor cloning, material write, equip, or save call. Changed external previews
are not forcibly reset. Missing identities or failed cleanup retain recovery.

## Recovery and testing

The plain-data proxy-v4 journal contains 13 lines: version, source instance,
data instance, owned fragment, equipped asset, target materials, equipped RGBA,
phase, container, display, blue asset, blue RGBA, and exact slot VM identity.
It is persisted before activation, then before installation and after copied
fragment verification. Source and transient blue baselines are never conflated.
Older v1/v2/v3 records remain supported. Invalid blue asset/color/slot/field
counts block recovery writes. Runtime objects are reacquired, not serialized.

Mock coverage includes blue/cyan/red restoration, copied installations,
no-op/throwing activation, wrong display blue, missing/duplicate cached VMs,
nonopaque source refusal, reload recovery, malformed v4 journals, failed resets,
and externally replaced hovers. These tests do not validate engine behavior.

Use the [current in-game checklist](dev-panel-tint-test.md#what-to-test-now).
Expected log markers: BLUE BASELINE VERIFIED, CHECKPOINT after-install,
CHECKPOINT after-refresh, DISPLAY COLOR VERIFIED, SlotVM.ResetPreviewedPart,
and RESTORED. The recovery file should be empty after successful cleanup.
