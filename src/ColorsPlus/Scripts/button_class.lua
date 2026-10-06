-- The game's CommonUI button used for the launcher and the picker's actions:
-- its HandleButtonClicked UFunction is hookable, so clicks need no input poll.
-- The main-menu creator has the class loaded; the hub editor does not, so it
-- is loaded once through UE4SS LoadAsset (game thread only) when missing.
local M={}
M.PATH="/Game/Game/UI/Strategy/Customization/Widgets/CharacterDatabank/WBP_CharacterDataBank_TopNavButton.WBP_CharacterDataBank_TopNavButton_C"
local function live(o) return o~=nil and o:IsValid()==true end
function M.find(log)
    local class=StaticFindObject(M.PATH)
    if live(class) then return class end
    assert(type(LoadAsset)=="function","Button class not loaded and LoadAsset unavailable")
    local ok,err=pcall(LoadAsset,M.PATH)
    class=StaticFindObject(M.PATH)
    if log then pcall(log,"BUTTON CLASS | LoadAsset ok=" .. tostring(ok) .. " | loaded=" .. tostring(live(class))
        .. (ok and "" or (" | " .. tostring(err):gsub("[\r\n]"," ")))) end
    assert(live(class),"Button class could not be loaded")
    return class
end
return M
