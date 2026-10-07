-- Opt-in, read-only trace of Armory > Customize Weapon: which of the screen's
-- own functions run when a colour swatch is hovered, picked, saved or
-- cancelled, and what the real weapon's and the armory preview's colour rows
-- hold afterwards. Hooks only log and schedule one coalesced snapshot; no
-- setters, equips or saves. Register only while the armory is open (the
-- classes must be loaded): colors_armory [start|stop].
-- Experiment (writes!): colors_armory paint <vm#> <row#> <RRGGBB> writes a
-- colour straight into that colour row's fragment on the REAL weapon (as a
-- swatch pick would) and refreshes it; colors_armory restore puts every
-- recorded original back. Dev-only, to learn whether ZCUnlocked's bolt
-- colour follows the fragment and whether a custom weapon colour persists.
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
    -- Experiment writes ------------------------------------------------------
    local WEAPON="^CustomizationInstance /Game/Game/Maps/Hub/HUB_Root%.HUB_Root:PersistentLevel%.BP_[%w_%-]+_C_%d+%.CustomizationInstance$"
    local written={} -- fragment full name -> {owner=, original=}
    local function linear(byte)
        local c=byte/255
        return c<=0.04045 and c/12.92 or ((c+0.055)/1.055)^2.4
    end
    local function find(full)
        local v=live(StaticFindObject(full:match("^[^ ]+ (.+)$")))
        if v and a.name(v)==full then return v end
    end
    -- The VM numbers change every session: list what is live.
    function self.rows()
        local vms=list("VM_WeaponCustomization_C",8)
        if #vms==0 then log("ROWS | no weapon customization VM (open Customize Weapon)"); return "none" end
        local summary={}
        for _,v in ipairs(vms) do
            local labels,weapon={},"?"
            for i,row in ipairs(try(function() return a.values(a.prop(v,"ColorSlotVMs")) end) or {}) do
                local r=live(row)
                if r then
                    labels[#labels+1]=i .. "=" .. scalar(try(function() return a.text(r.DisplayName) end) or "?")
                    local f=live((try(function() return a.values(r:GetFragments()) end) or {})[1])
                    local o=f and try(function() return name(f:GetOwningCustomizationInstance()) end)
                    if o and weapon=="?" then weapon=o:match("PersistentLevel%.([%w_%-]+)%.") or o end
                end
            end
            local number=name(v):match("_(%d+)$") or "?"
            log("ROWS | vm " .. number .. " | weapon=" .. scalar(weapon) .. " | rows: " .. table.concat(labels,", "))
            summary[#summary+1]=number .. " (" .. weapon .. ")"
        end
        return table.concat(summary,"; ")
    end
    function self.paint(vm_index,row_index,hex)
        local r8,g8,b8=hex:match("^#?(%x%x)(%x%x)(%x%x)$")
        assert(r8,"Colour must be RRGGBB")
        local wvm
        for _,v in ipairs(list("VM_WeaponCustomization_C",8)) do
            if name(v):match("_(%d+)$")==tostring(vm_index) then wvm=v end
        end
        if not wvm then error("No VM_WeaponCustomization_C_" .. tostring(vm_index) .. "; live: " .. self.rows(),0) end
        local rows=a.values(a.prop(wvm,"ColorSlotVMs"))
        local row=assert(live(rows[row_index]),"No colour row " .. tostring(row_index))
        local frags=a.values(row:GetFragments())
        assert(#frags==1,"Row must have exactly one fragment (has " .. #frags .. ")")
        local f=assert(live(frags[1]),"Fragment unavailable")
        assert(name(f:GetClass())=="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor","Not a colour fragment")
        local owner=assert(live(f:GetOwningCustomizationInstance()),"No owner")
        assert(name(owner):match(WEAPON),"Owner is not a hub weapon: " .. name(owner))
        local now=f:GetColor()
        local record=written[name(f)] or {owner=name(owner),original={R=now.R,G=now.G,B=now.B,A=now.A}}
        written[name(f)]=record
        local c={R=linear(tonumber(r8,16)),G=linear(tonumber(g8,16)),B=linear(tonumber(b8,16)),A=record.original.A}
        log("PAINT | " .. name(f) .. " | label=" .. scalar(try(function() return a.text(row.DisplayName) end) or "?")
            .. " | from=" .. color(f) .. " | to=" .. string.format("%.4f,%.4f,%.4f,%.4f",c.R,c.G,c.B,c.A))
        f:SetColor(c)
        owner:RefreshCustomization()
        log("PAINT READBACK | " .. color(f) .. " | owner=" .. name(owner) .. " | restore with colors_armory restore")
    end
    function self.restore()
        local n=0
        for full,record in pairs(written) do
            local f=find(full)
            if f and name(f:GetOwningCustomizationInstance())==record.owner then
                f:SetColor(record.original)
                live(f:GetOwningCustomizationInstance()):RefreshCustomization()
                log("RESTORED | " .. full .. " | rgba=" .. color(f)); n=n+1
            else
                log("RESTORE SKIPPED | " .. full .. " | fragment replaced (a swatch was picked since) or gone")
            end
            written[full]=nil
        end
        log("RESTORE DONE | restored=" .. n)
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
            parameters=parameters or {}
            local action=string.lower(tostring(parameters[1] or "start"))
            local message
            if action=="start" or action=="stop" then
                runtime:after("armory-trace:command",1,function() if action=="stop" then self.stop() else self.start() end end)
                message="Queued armory trace " .. action .. "."
            elseif action=="paint" and #parameters==4 then
                local vm_index,row_index,hex=tonumber(parameters[2]),tonumber(parameters[3]),tostring(parameters[4])
                runtime:after("armory-trace:command",1,function()
                    local ok,err=pcall(self.paint,vm_index,row_index,hex)
                    if not ok then log("PAINT REFUSED | " .. scalar(err)) end
                end)
                message="Queued paint of VM " .. tostring(vm_index) .. " row " .. tostring(row_index) .. " -> " .. hex .. "."
            elseif action=="rows" then
                runtime:after("armory-trace:command",1,function()
                    local ok,err=pcall(self.rows)
                    if not ok then log("ROWS FAILED | " .. scalar(err)) end
                end)
                message="Queued weapon row listing (see the log/console)."
            elseif action=="restore" then
                runtime:after("armory-trace:command",1,function()
                    local ok,err=pcall(self.restore)
                    if not ok then log("RESTORE FAILED | " .. scalar(err)) end
                end)
                message="Queued restore of painted rows."
            else message="Usage: colors_armory [start|stop|rows|paint <vm#> <row#> <RRGGBB>|restore]" end
            log(message)
            if output then pcall(function() output:Log(message) end) end
        end)
        log("Ready: colors_armory [start|stop] (read-only; open Customize Weapon first)")
    end
    return self
end
return M
