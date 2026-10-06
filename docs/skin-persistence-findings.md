# Skin persistence investigation

## Observations (v0.2.51 native test)

The labeled snapshots at 2026-09-18 02:11:59 / 02:12:21 / 02:12:42 UTC show:

| Field | Baseline | Applied before save | Reopened after save |
| --- | --- | --- | --- |
| Source linear RGB | 1,0,0.014444 | 1,0.215861,0.014444 | 1,0.215861,0.014444 |
| Display Skin Coloration | baseline RGB | applied RGB | applied RGB |
| Display Enable Tinting | 0 | 1 | 0 |
| Source scalar Value | 1 | 1 | 1 |
| Source scalar target | Outfit | Outfit | Outfit |
| Colors+ Apply active | no | yes | no |

The RGB change survived save/reopen, including recreation of the source fragment.
The enable override existed on the preview/display MID only and did not survive.
This does not yet establish full process-restart persistence.

The unchanged source scalar value 1 is not proof of its serialization: the stock
preset supplies the same value and could reconstruct it on load. Likewise the
unchanged Outfit target does not demonstrate that edits to MaterialTarget save.

## Reference evidence

Local reference paths are relative to ../ZeroCompany_RE_Reference_v2/reference:

- native_headers/current/BitReactorCore/Public/CustomizationFragmentInstanceMaterialBase.h
  exposes MaterialTarget and SetMaterialTarget(FCustomizationTraitMaterialTarget).
- native_headers/current/BitReactorCore/Public/CustomizationTraitMaterialTarget.h
  contains SlotNameTagsToApply, MaterialSlotNames and MaterialParameterName.
- native_headers/current/BitReactorCore/Public/CustomizationFragmentInstanceMaterialScalar.h
  exposes Value, SetValue and GetValue. The color counterpart exposes Color,
  SetColor and GetColor. Neither dumped field is explicitly SaveGame-marked.
- native_headers/current/BitReactorCore/Public/CustomizationInstance.h marks
  FragmentInstances and PreviewCustomizationInstance Transient.
- The matching Private/*.cpp files contain generated empty/default stubs, not
  evidence of actual setter or serialization behavior. The save statics header
  contains no usable serialization implementation.

Epic's property documentation distinguishes SaveGame and Transient properties:
https://dev.epicgames.com/documentation/unreal-engine/unreal-engine-uproperties
These flags alone cannot explain this game's custom data-copy/save pipeline;
the observed RGB survival is evidence that some character state is preserved.

## Next discriminating experiment

Update (v0.2.53 native test, September 18): leaf tag-array writes successfully
enabled the saved RGB without direct MID writes. Readback, 15-second restoration
and manual restoration passed. The earlier v0.2.52 whole-struct setter attempt
failed parameter validation and rollback; it is not the working write path.

v0.2.54 native result: Save/reopen produced a new source fragment (slot 30 to 58)
with the five-mesh target and unchanged orange RGB. Stop retired the old source
without touching the replacement. After a full restart, the 15:47:43 UTC check
still read target=meshes, RGB=1,0.215860501,0.0144438436,1, armed=false. No target
write/reapplication occurred in the fresh runtime. Together with the user's
visible orange result, this establishes native persistence for this tested
Skin Tone 5 character, not every possible skin/race.

v0.2.55 integrates the correction into Apply; see skin-picker-persistence-testing.md.
The remaining text below records the original experimental rationale.

Test SetMaterialTarget on a verified per-character scalar fragment, leaving Value
at 1 and retaining the parameter/material names. Give it a face-inclusive target
(prefer the already observed five-mesh layout). First prove rendering and exact
restoration without the direct MID workaround. Then compare the changed target
after native Save and reopen, followed by a full-restart check if successful.

Do not perform this inside the current normal picker without further work: its
guards intentionally require the recorded source scalar layout. The experiment
needs its own write-ahead restoration record and validation of both the original
and test target, including partial setter failures. Never edit the stock preset
or parent material, and never relax all target guards merely to accept this test.

If target edits do not persist, the alternative is a mod-owned, character-specific
intent record plus safe load/refresh-time reapplication. Do not infer opt-in from
scalar Value=1 (stock also uses it), or enable tinting on every stock Skin Tone 5.
Stable character identity and save/discard behavior would need verification for
that fallback. No runtime changes were made by this investigation.
