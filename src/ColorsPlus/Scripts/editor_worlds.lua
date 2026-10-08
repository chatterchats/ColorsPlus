-- The character editors Colors+ edits in, and the exact objects each may
-- touch: the main-menu creator and the in-game (hub) editor. Every check
-- returns the editor's key or nil; callers compare keys so one edit never
-- mixes objects from both. Names are full UE names ("Class /Path").
local M={}
local LEVELS={
    creator="/Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.",
    hub="/Game/Game/Maps/Hub/HUB_Root%.HUB_Root:PersistentLevel%.",
}
-- Editable characters. The creator edits its new recruit (a humanoid or an
-- astromech droid); the hub edits the selected squad member's live actor
-- (Hawks, recruits and droids observed).
local OWNERS={creator={"Char_Hero_Humanoid_C_%d+","Char_Hero_Astromech_C_%d+"},hub={"Char_Hero_[%w_%-]+_C_%d+"}}
local HAWKS_LEVEL="/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization%.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel%."
local DISPLAYS={
    creator="^BP_CustomCharacter_CustomizationProxy_C " .. HAWKS_LEVEL .. "BP_HawksCustomizationProxyCharacter_C_%d+$",
    hub="^BP_CustomizationProxyCharacter_C " .. LEVELS.hub .. "BP_CustomizationProxyCharacter_C_%d+$",
}
local function check(name,pattern_for)
    if type(name)~="string" or name:find("[\r\n]") or name:find("Default__",1,true) then return nil end
    for key,level in pairs(LEVELS) do
        if name:match(pattern_for(key,level)) then return key end
    end
end
function M.owner(name)
    for i=1,2 do
        local key=check(name,function(key,level)
            local actor=OWNERS[key][i]
            return actor and "^CustomizationInstance " .. level .. actor .. "%.CustomizationInstance$" or "^$"
        end)
        if key then return key end
    end
end
function M.preview(name)
    return check(name,function(_,level)
        return "^CustomizationInstance " .. level .. "BP_CustomizationPreviewProxyCharacter_C_%d+%.CustomizationInstance$"
    end)
end
function M.container(name)
    return check(name,function(_,level)
        return "^BP_CustomizationPreviewProxyContainer_C " .. level .. "BP_CustomizationPreviewProxyContainer_C_%d+$"
    end)
end
function M.display(name)
    return check(name,function(key) return DISPLAYS[key] end)
end
-- The editor both names belong to, or nil when either is unsupported or
-- they belong to different editors.
function M.same(kind_a,name_a,kind_b,name_b)
    local key=M[kind_a](name_a)
    return key and key==M[kind_b](name_b) and key or nil
end
return M
