local scripts=assert(arg[1])
local worlds=assert(loadfile(scripts .. "/editor_worlds.lua"))()
local main="/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local hub="/Game/Game/Maps/Hub/HUB_Root.HUB_Root:PersistentLevel."
local function owner(level,actor) return "CustomizationInstance " .. level .. actor .. ".CustomizationInstance" end
-- Owners: the creator's recruit; the hub's live squad members (as observed).
assert(worlds.owner(owner(main,"Char_Hero_Humanoid_C_0"))=="creator")
-- The creator's new droid (observed 2026-10-08: Char_Hero_Astromech_C_0 in MainMenu).
assert(worlds.owner(owner(main,"Char_Hero_Astromech_C_0"))=="creator")
assert(not worlds.owner(owner(main,"Char_HQ_M-EVO_C_1")),"Creator edits only its recruit")
assert(not worlds.owner(owner(main,"BP_AstromechWeapon_C_2")),"A droid's weapon is not an owner")
assert(worlds.owner(owner(hub,"Char_Hero_HAWKS_Control_C_0"))=="hub")
assert(worlds.owner(owner(hub,"Char_Hero_Humanoid_C_0"))=="hub")
assert(worlds.owner(owner(hub,"Char_Hero_Astromech_BR-1_C_0"))=="hub")
assert(not worlds.owner(owner(main,"Char_Hero_HAWKS_Control_C_0")),"Creator edits only its recruit")
assert(not worlds.owner(owner(hub,"BP_CustomizationProxyCharacter_C_0")),"Display proxy is not an owner")
assert(not worlds.owner(owner(hub,"BP_CustomizationPreviewProxyCharacter_C_1")),"Preview proxy is not an owner")
assert(not worlds.owner("CustomizationInstance /Game/Game/GameData/Narrative/Conversations/con/SEQ.SEQ:MovieScene_0.Char_Hero_HAWKS_Control_0.CustomizationInstance"))
assert(not worlds.owner(owner(hub,"Char_Hero_Humanoid_C_0") .. ".Child"))
assert(not worlds.owner(owner(hub,"Char_Hero_Humanoid_C_0") .. "\n"))
assert(not worlds.owner("CustomizationInstance " .. hub .. "Default__Char_Hero_Humanoid_C_0.CustomizationInstance"))
assert(not worlds.owner(nil) and not worlds.owner(7))
-- Previews, containers and displays.
local preview=owner(hub,"BP_CustomizationPreviewProxyCharacter_C_2")
assert(worlds.preview(owner(main,"BP_CustomizationPreviewProxyCharacter_C_0"))=="creator" and worlds.preview(preview)=="hub")
assert(worlds.container("BP_CustomizationPreviewProxyContainer_C " .. hub .. "BP_CustomizationPreviewProxyContainer_C_2")=="hub")
assert(worlds.display("BP_CustomizationProxyCharacter_C " .. hub .. "BP_CustomizationProxyCharacter_C_0")=="hub")
assert(worlds.display("BP_CustomCharacter_CustomizationProxy_C /Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel.BP_HawksCustomizationProxyCharacter_C_0")=="creator")
assert(not worlds.display("BP_CustomizationProxyCharacter_C " .. main .. "BP_CustomizationProxyCharacter_C_0"))
-- One edit never mixes editors.
assert(worlds.same("owner",owner(hub,"Char_Hero_HAWKS_Control_C_0"),"preview",preview)=="hub")
assert(not worlds.same("owner",owner(main,"Char_Hero_Humanoid_C_0"),"preview",preview))
assert(not worlds.same("owner","bogus","preview","bogus"))
print("Editor worlds: creator/hub owners, previews, displays and cross-editor refusal passed")
