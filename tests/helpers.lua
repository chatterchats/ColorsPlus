-- Shared test support. Load from a test with:
--   local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
local M={}

-- main.lua loads each script once per bootstrap and hands every caller the
-- same module table. Tests do the same, so they exercise that sharing and do
-- not recompile a script on every factory call. Call once, before loading.
function M.share_modules(scripts)
    local original=loadfile
    local loaded={}
    local prefix=scripts .. "/"
    loadfile=function(path,...)
        if select("#",...)>0 or type(path)~="string" or path:sub(1,#prefix)~=prefix then
            return original(path,...)
        end
        local entry=loaded[path]
        if not entry then
            local chunk,err=original(path)
            if not chunk then return nil,err end
            entry={chunk()}
            loaded[path]=entry
        end
        return function() return entry[1] end
    end
end

-- Game 1.2: SelectionTiles expose their slot only through the MDViewModel
-- library (active_palette.tiles_slot_tag). Wraps a test's StaticFindObject
-- with the library and slot view model class; a tiles fixture stands in for
-- its own "Default" slot view model, so it carries SlotTag={TagName=...}.
function M.view_models(find)
    local class={IsValid=function() return true end,
        GetFullName=function() return "Class /Script/BitReactorGame.BitReactorCustomizationSlotViewModel" end,
        path="/Script/BitReactorGame.BitReactorCustomizationSlotViewModel"}
    local library={IsValid=function() return true end,
        GetViewModel=function(_,widget,c,name)
            if type(name)~="string" then name=name:ToString() end
            assert(c==class and name=="Default","Unexpected view model lookup")
            assert(widget:GetFullName():match("^WBP_Customization_SelectionTiles_C "),"View model lookup off a tiles widget")
            return widget.SlotTag and widget or nil
        end}
    FName=FName or function(v) return v end
    return function(path,...)
        if path=="/Script/MDViewModel.Default__MDViewModelFunctionLibrary" then return library end
        if path==class.path then return class end
        return find(path,...)
    end
end

-- color_zone journal(leaf) for tests that keep journals in a files table
-- under short names. overrides: {[leaf]=name}.
function M.journal(overrides)
    local names={["tint_recovery.txt"]="recovery",["default_selection_recovery.txt"]="selection",
        ["editor_recovery.txt"]="editor",["zabrak_picker_recovery.txt"]="zabrak"}
    for leaf,name in pairs(overrides or {}) do names[leaf]=name end
    return function(leaf) return assert(names[leaf],leaf) end
end
return M
