-- Opt-in, read-only trace of Armory > Customize Weapon: which of the screen's
-- own functions run when a colour swatch is hovered, picked, saved or
-- cancelled, and what the real weapon's and the armory preview's colour rows
-- hold afterwards. Hooks only log and schedule one coalesced snapshot; no
-- setters, equips or saves. Register only while the armory is open (the
-- classes must be loaded): colors_armory [start|stop].
local M={}
local BASE="/Game/Game/UI/Strategy/Armory/"
local VM=BASE .. "BP/VM_WeaponCustomization.VM_WeaponCustomization_C:"
local SCREEN=BASE .. "WBP_Menu_Armory_CustomizeWeapon.WBP_Menu_Armory_CustomizeWeapon_C:"
local RENDER=BASE .. "Actor/BP_ArmoryWeaponRender.BP_ArmoryWeaponRender_C:"
local TILES=BASE .. "Widgets/WBP_Customization_PartTiles.WBP_Customization_PartTiles_C:"
M.HOOKS={
    VM .. "StashEquippedParts", VM .. "EquipStashedParts", VM .. "ResetPreviews", VM .. "UpdateSlots",
    VM .. "StashModParts", VM .. "EquipStashedMods",
    SCREEN .. "CopyWeaponCustomizationToPreview", SCREEN .. "HandleOnStylePreviewUpdated",
    SCREEN .. "HandleOnWeaponTypePreviewReset", SCREEN .. "HandleOnWeaponTypePrePreviewUpdated",
    SCREEN .. "UpdateStyleSection", SCREEN .. "UpdateContent", SCREEN .. "BP_OnActivated", SCREEN .. "BP_OnDeactivated",
    RENDER .. "UpdateWeaponPreview", RENDER .. "ResetWeapons",
    TILES .. "BP_OnItemSelectionChanged",
}
function M.new(runtime,a)
    local self={active=false}
    local function scalar(v) return tostring(v):gsub("[\r\n\t]"," "):sub(1,512) end
    local function log(s) runtime.log("ARMORY TRACE | " .. s) end
    local function live(v) v=a.unwrap(v); return a.live(v) and v or nil end
    local function name(v) v=live(v); return v and a.name(v) or "<none>" end
    local function try(fn) local ok,v=pcall(fn); if ok then return v end end
    local function color(f)
        local c=try(function() return f:GetColor() end)
        return c and string.format("%.4f,%.4f,%.4f,%.4f",c.R,c.G,c.B,c.A) or "?"
    end
    local function list(class,limit)
        local values=FindAllOf(class) or {}
        local out={}
        for _,v in pairs(values) do if live(v) then out[#out+1]=v; if #out>=limit then break end end end
        return out
    end
    local function snapshot(reason)
        log("SNAPSHOT BEGIN | after=" .. scalar(reason))
        for _,screen in ipairs(list("WBP_Menu_Armory_CustomizeWeapon_C",4)) do
            log("SCREEN | " .. name(screen) .. " | previewing=" .. scalar(try(function() return a.prop(screen,"bIsPreviewing") end))
                .. " | activated=" .. scalar(try(function() return screen:IsActivated() end)))
        end
        for _,wvm in ipairs(list("VM_WeaponCustomization_C",8)) do
            local rows=try(function() return a.values(a.prop(wvm,"ColorSlotVMs")) end) or {}
            for i,row in ipairs(rows) do
                local r=live(row)
                if r and i<=8 then
                    local frags=try(function() return a.values(r:GetFragments()) end) or {}
                    local f=live(frags[1])
                    log(string.format("ROW | %s | %d | label=%s | swatch=%s | previewed=%s | fragment=%s | rgba=%s",
                        name(wvm),i,scalar(try(function() return a.text(r.DisplayName) end) or "?"),
                        scalar(try(function() return a.text(r.EquippedCustomizationPartViewModel.AssetId.PrimaryAssetName) end) or "?"),
                        scalar(try(function() return a.text(r:PreviewedCustomizationPartViewModel().AssetId.PrimaryAssetName) end) or "?"),
                        f and name(f) or "<none>",f and color(f) or "-"))
                end
            end
        end
        for _,render in ipairs(list("BP_ArmoryWeaponRender_C",4)) do
            local ci=live(try(function() return a.prop(render,"CustomizationInstance") end))
            local slot=ci and live(try(function() return ci:GetSlotInstance({TagName=FName("br.Customization.Slot.Weapon.PaintColor")}) end))
            local frags=slot and (try(function() return a.values(slot:GetFragmentInstances()) end) or {}) or {}
            local f=live(frags[1])
            log("PREVIEW | " .. name(render) .. " | instance=" .. name(ci) .. " | paint_fragment=" .. (f and name(f) or "<none>")
                .. " | rgba=" .. (f and color(f) or "-"))
        end
        log("SNAPSHOT END")
    end
    local function event(label)
        if not self.active then return end
        log("EVENT | " .. label)
        runtime:after("armory-trace:snapshot",50,function()
            if self.active then
                local ok,err=pcall(snapshot,label)
                if not ok then log("SNAPSHOT FAILED | " .. scalar(err)) end
            end
        end)
    end
    function self.start()
        self.active=true
        local installed,missing=0,0
        for _,path in ipairs(M.HOOKS) do
            local short=path:match("([%w_]+_C:[%w_]+)$") or path
            local ok=runtime:hook(path,function(context) event(short .. " | " .. name(context)) end)
            if ok then installed=installed+1 else missing=missing+1 end
        end
        log("START | hooks installed=" .. installed .. " missing=" .. missing .. " | slot events logged too")
        event("start")
    end
    function self.stop()
        self.active=false; runtime:cancel("armory-trace:snapshot"); log("STOP")
    end
    function self.attach()
        -- Chain onto the existing dev context handler (picker console).
        local previous=runtime.dev_context
        runtime.dev_context={
            before=function(reason,identity)
                if previous and previous.before then previous.before(reason,identity) end
                event("slot event " .. scalar(reason))
            end,
            after=previous and previous.after,
        }
        if type(RegisterConsoleCommandHandler)~="function" then log("Console unavailable"); return end
        runtime:console("colors_armory",function(_,parameters,output)
            local action=string.lower(tostring((parameters or {})[1] or "start"))
            local message
            if action=="start" or action=="stop" then
                runtime:after("armory-trace:command",1,function() if action=="stop" then self.stop() else self.start() end end)
                message="Queued armory trace " .. action .. "."
            else message="Usage: colors_armory [start|stop]" end
            log(message)
            if output then pcall(function() output:Log(message) end) end
        end)
        log("Ready: colors_armory [start|stop] (read-only; open Customize Weapon first)")
    end
    return self
end
return M
