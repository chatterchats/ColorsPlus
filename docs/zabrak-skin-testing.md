# Zabrak post-refresh face RGB test — v0.2.61

Fully restart and confirm `Loaded v0.2.61`. Use normal CP from the console or
DP. Do not run `colors_target` or `colors_skin_enable`, save the character, or
Reload All Mods during this test.

The capture shows six-mesh `Skin Coloration` (face, outfit pieces, horns) but
`Enable Tinting=1` targets only the Outfit parent. v0.2.60's native trace showed
the arm taking Violet (linear RGBA `0.351533,0.051269,0.745404,1`) while face and
horn-base skin stayed stock (`0.417885,0.184475,0.093059,1`). The face's enable
switch did reach 1, and Cancel restored it to 0. MaterialSwap is a possible
explanation, not an established cause.

This build writes both temporary face MID enable and `Skin Coloration` RGB
after the verified refresh on that exact four-fragment Zabrak layout. It records
both original values before setters and verifies readback after reacquisition.
Cancel/timeout/Restore independently recover both owned values. Foreign RGB is
not overwritten; a retired MID cannot transfer its restoration to a replacement.
Only the face MID gets this new RGB write: please report horn-base and bare-arm
skin separately. The parent must declare the captured global RGB parameter.
It does not correct the source scalar target or claim saved rendering support.

v0.2.59 passed the RGB/clone/refresh checks, then refused because its actor-wide
MI_Head lookup did not find exactly one target. v0.2.60 binds Zabrak to the
uniquely visible face-tagged component (observed dotted or underscore naming),
not unrelated actor materials or hidden old faces. Exact MID/parent/index
ownership still applies. Missing/ambiguous faces fail closed with bounded
`DISCOVERY FAILED`, `DISCOVERY MESH` and `DISCOVERY SLOTS` evidence.

1. Select Zabrak Skin Tone 8 (captured asset `Hum_Zabrak_1A1`). Open CP and
   preview obvious cyan/orange. Check face and visible bare skin. Cancel, then
   reopen. The original skin must return on Cancel.
2. Apply a distinct RGB, return to radial and reenter. Hover stock swatches,
   then move off: stock hover should win, followed by the custom color. Open
   another draft and Cancel; the previous applied color should return. Restore
   should recover the original RGB and transient face enable state.
3. Let an un-applied draft expire after two minutes, then reopen. Also leave
   customization with a draft open; the draft should close and restore.
4. Repeat preview/Cancel/Apply/Restore on a second Zabrak skin swatch. Existing
   horn-color editing should remain unchanged. Report which visible regions
   changed or did not change; the direct RGB/enable operation itself is face-only.

If the picker refuses or RGB remains invisible, note the stock swatch and
capture `colors_compat` and Inspect tint target after Cancel/Restore. Keep the
logs, especially `SKIN ENABLE | RGB SET BEGIN`, `RGB VERIFIED`, `RGB RESTORE BEGIN`
and any refusal/restore failure. A getter readback is not proof of visible color.
After visible rendering is confirmed, the next step is a journaled source-target correction
and native Save/restart testing, not an automatic saved-color reapply loop.

The [engine component API](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/USceneComponent)
defines `IsVisible` as component visibility; it is an additional selection
condition, not proof of character ownership. The
[primitive component API](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UPrimitiveComponent)
provides slot names for refusal diagnostics. Actor/component/MID/parent identity
checks remain the ownership gates.

The [dynamic material API](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UMaterialInstanceDynamic)
defines `SetVectorParameterValue(FName, FLinearColor)` and
`K2_GetVectorParameterValue(FName)` for an MID. This test uses the assigned MID,
not a component-wide parameter setter or a stock material asset.
