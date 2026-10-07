-- Weapon Paint Color in Armory > Customize Weapon: the picker backend.
-- Measured in game (2026-10-07): a swatch pick replaces the real weapon's
-- paint fragment and saves at once (no stash or cancel step); hovering only
-- rebuilds the armory preview (BP_ArmoryWeaponRender's own copy). A colour
-- written into the real fragment shows in the hub and survives save/load.
-- So drafts write only the preview copy, which the game rebuilds anyway, and
-- Apply writes the real fragment, the game's own save point. Nothing persists
-- before Apply, so no recovery journal is needed. Only the vanilla Paint
-- Color row qualifies: ZCUnlocked's bolt/blade rows reuse the same tags and
-- colour their effects from their own store, so a write there would only
-- repaint the weapon body. Lightsabers are left alone for the same reason.
local M={}
M.LABEL="Paint Color"
M.TAG="br.Customization.Slot.Weapon.PaintColor"
M.PARAMETER="Paint Color"
local COLOR="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"
local WEAPON="^CustomizationInstance /Game/Game/Maps/Hub/HUB_Root%.HUB_Root:PersistentLevel%.(BP_[%w_%-]+_C)_%d+%.CustomizationInstance$"
local PREVIEW="^CustomizationInstance /Game/Game/Maps/Hub/Sublevels/Facilities/HUB_Armory_Gameplay%.HUB_Armory_Gameplay:PersistentLevel%.BP_ArmoryWeaponRender_C_%d+%.CustomizationInstance$"
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function same(x,y)
    for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>0.00001 then return false end end
    return true
end
function M.new(runtime,a)
    local self={pending=nil,blocked=nil,busy=false,applied=nil}
    local function log(s) runtime.log("ARMORY PAINT | " .. tostring(s):gsub("[\r\n]"," ")) end
    self.log=log
    local function object(v,label) v=a.unwrap(v); assert(a.live(v),"Unavailable: " .. (label or "armory object")); return v end
    local function name(v) return a.name(object(v)) end
    local function find(full,label)
        local v=a.unwrap((a.find or StaticFindObject)(assert(full:match("^[^ ]+ (.+)$"),"Invalid identity")))
        assert(a.live(v) and a.name(v)==full,(label or "Armory object") .. " changed")
        return v
    end
    local function color(f)
        local c=f:GetColor(); local out={}
        for _,k in ipairs({"R","G","B","A"}) do out[k]=a.prop(c,k); assert(finite(out[k]),"Unreadable colour") end
        return out
    end
    local function rgba(c) return string.format("%.6f,%.6f,%.6f,%.6f",c.R,c.G,c.B,c.A) end
    local function part(slot) local id=slot:GetCustomizationPartPrimaryAssetId(); return a.text(id.PrimaryAssetType.Name) .. ":" .. a.text(id.PrimaryAssetName) end
    -- The single MaterialColor fragment of a slot, targeting Paint Color.
    local function paint_fragment(values,label)
        values=a.values(values)
        assert(#values==1,label .. " must hold exactly one fragment (has " .. #values .. ")")
        local f=object(values[1],label .. " fragment")
        assert(name(f:GetClass())==COLOR,label .. " fragment is not a colour")
        assert(a.text(f.MaterialTarget.MaterialParameterName)==M.PARAMETER,label .. " fragment does not target " .. M.PARAMETER)
        return f
    end
    -- Is this colour row the vanilla Paint Color row of a hub blaster?
    local function qualifies(row)
        local ok=pcall(function()
            row=object(row,"row")
            assert(a.text(row.DisplayName)==M.LABEL and a.text(row.SlotTag.TagName)==M.TAG)
            local f=paint_fragment(row:GetFragments(),"Row")
            local weapon=name(f:GetOwningCustomizationInstance()):match(WEAPON)
            assert(weapon and not weapon:find("LightSaber",1,true))
        end)
        return ok
    end
    self.qualifies=qualifies
    -- The armory preview showing the weapon: its customization and paint
    -- fragment, which must show the given swatch.
    local function preview_paint(expected)
        local renders={}
        local function shown(r) return a.live(r) and a.prop(r,"isShowingWeapon")==true end
        if runtime.known then renders=runtime.known.select("BP_ArmoryWeaponRender_C",8,shown)
        else for _,r in pairs(FindAllOf("BP_ArmoryWeaponRender_C") or {}) do if shown(a.unwrap(r)) then renders[#renders+1]=r end end end
        assert(#renders==1,"Expected one armory preview showing a weapon (found " .. #renders .. ")")
        local preview=object(a.prop(object(renders[1]),"CustomizationInstance"),"armory preview customization")
        assert(name(preview):match(PREVIEW),"Unsupported armory preview")
        local pslot=object(preview:GetSlotInstance({TagName=FName(M.TAG)}),"armory preview paint slot")
        local pf=paint_fragment(pslot:GetFragmentInstances(),"Preview")
        assert(part(pslot)==expected,"Armory preview shows a different paint swatch")
        return preview,pf
    end
    -- The weapon's paint slot and fragment, found from the weapon itself.
    local function weapon_paint(owner)
        local slot=object(owner:GetSlotInstance({TagName=FName(M.TAG)}),"weapon paint slot")
        assert(a.text(slot:GetSlotNameTag().TagName)==M.TAG,"Weapon paint slot tag changed")
        return slot,paint_fragment(slot:GetFragmentInstances(),"Weapon")
    end
    -- Resolve everything from the bound row (scalar identity) afresh.
    local function resolve(row_name)
        assert(type(row_name)=="string","No armory paint row bound")
        local row=find(row_name,"Paint row")
        assert(qualifies(row),"Row is no longer the vanilla Paint Color row")
        local f=paint_fragment(row:GetFragments(),"Row")
        local owner=object(f:GetOwningCustomizationInstance(),"weapon customization")
        local slot,wf=weapon_paint(owner)
        assert(name(wf)==name(f),"Weapon paint slot does not hold the row's fragment")
        local preview,pf=preview_paint(part(slot))
        return {row=row,fragment=f,owner=owner,slot=slot,preview=preview,preview_fragment=pf}
    end
    local function write_preview(c,value)
        c.preview_fragment:SetColor(value)
        c.preview:RefreshCustomization()
        assert(a.live(c.preview_fragment) and same(color(c.preview_fragment),value),"Armory preview readback failed")
    end
    -- Changing Location or Finish rebuilds the armory preview (and can
    -- recreate the row VMs): the session follows the weapon itself. The
    -- preview may be missing for a moment while it rebuilds; a new copy gets
    -- the draft again. Only a weapon-side paint change ends the draft.
    local MISSING_LIMIT=20
    local function check(s)
        local owner=find(s.owner,"Weapon customization")
        local slot,f=weapon_paint(owner)
        assert(part(slot)==s.perf_target.part,"Weapon paint swatch changed")
        if name(f)~=s.fragment then
            assert(same(color(f),s.original),"Weapon paint fragment replaced")
            log("WEAPON FRAGMENT RENEWED | " .. s.fragment .. " -> " .. name(f))
            s.fragment=name(f)
        end
        local c={owner=owner,slot=slot,fragment=f}
        local ok,preview,pf=pcall(preview_paint,s.perf_target.part)
        if not ok then
            s.missing=(s.missing or 0)+1
            if s.missing==1 then log("PREVIEW UNAVAILABLE | waiting for the armory to rebuild it (" .. tostring(preview) .. ")") end
            assert(s.missing<MISSING_LIMIT,"Armory preview unavailable: " .. tostring(preview))
            return c
        end
        s.missing=nil
        c.preview,c.preview_fragment=preview,pf
        if name(pf)~=s.preview_fragment or name(preview)~=s.preview then
            -- A fresh copy of the weapon: its colour is the weapon's own.
            s.preview,s.preview_fragment=name(preview),name(pf)
            s.preview_original=color(pf)
            if not same(s.preview_original,s.test_color) then write_preview(c,s.test_color) end
            log("PREVIEW REBUILT | preview=" .. s.preview_fragment .. " | draft reapplied")
        end
        return c
    end
    -- The row the armory launcher is bound to (scalar), or nil.
    local function bound_row() return runtime.armory_ui and runtime.armory_ui.bound_row and runtime.armory_ui.bound_row() end
    function self.read_context()
        local c=resolve(bound_row())
        return {original=color(c.fragment),profile={slot=M.TAG,parameter=M.PARAMETER},part=part(c.slot)}
    end
    function self.begin_live()
        if self.pending or self.busy then return nil end
        local ok,result=pcall(function()
            local row=bound_row()
            local c=resolve(row)
            local original=color(c.fragment)
            assert(original.R>=0 and original.G>=0 and original.B>=0,"Unsupported paint value")
            local s={live=true,row=row,fragment=name(c.fragment),owner=name(c.owner),preview=name(c.preview),
                preview_fragment=name(c.preview_fragment),original=copy(original),preview_original=color(c.preview_fragment),
                test_color=copy(original),profile={slot=M.TAG,parameter=M.PARAMETER},preview_policy="armor",
                perf_target={part=part(c.slot),backend="armory-paint"}}
            self.pending=s
            log("OPEN | weapon=" .. s.owner .. " | part=" .. s.perf_target.part .. " | original=" .. rgba(original)
                .. " | preview=" .. s.preview_fragment .. " | drafts write the armory preview only")
            return s
        end)
        if not ok then log("OPEN REFUSED | " .. tostring(result)); return nil end
        return result
    end
    function self.update_live(s,chosen)
        if s~=self.pending or not s.live or self.busy then return false end
        self.busy=true
        local ok,err=pcall(function()
            local value={R=chosen.R,G=chosen.G,B=chosen.B,A=s.original.A}
            local c=check(s)
            s.test_color=value
            -- Without a preview the draft waits for the next copy.
            if c.preview then write_preview(c,value); return true end
            return false
        end)
        self.busy=false
        if not ok then log("UPDATE REFUSED | " .. tostring(err)); return false end
        return true,err
    end
    function self.check_live(s)
        if s~=self.pending or not s.live then return false,"Armory paint draft ended" end
        local ok,err=pcall(check,s)
        return ok,err
    end
    function self.apply_live(s)
        if s~=self.pending or not s.live or self.busy then return false end
        self.busy=true
        local ok,err=pcall(function()
            local c=check(s)
            assert(same(color(c.fragment),s.original),"Weapon paint changed since the picker opened")
            local value=copy(s.test_color)
            c.fragment:SetColor(value)
            c.owner:RefreshCustomization()
            assert(a.live(c.fragment) and same(color(c.fragment),value),"Weapon paint readback failed")
            -- Keep the preview showing the applied colour too.
            if c.preview and not same(color(c.preview_fragment),value) then write_preview(c,value) end
            log("APPLIED | weapon=" .. s.owner .. " | " .. rgba(s.original) .. " -> " .. rgba(value)
                .. " | the game saves it like a swatch pick")
        end)
        self.busy=false
        if ok then s.live=false; self.pending=nil; return true end
        log("APPLY FAILED | " .. tostring(err))
        return false
    end
    -- Cancel/close: the weapon was never written; put the preview back.
    function self.cancel_live(reason)
        local s=self.pending
        if not s then return true end
        if self.busy then return false end
        self.busy=true
        local ok,err=pcall(function()
            local c=check(s)
            assert(c.preview,"Armory preview unavailable")
            write_preview(c,s.preview_original)
        end)
        self.busy=false
        s.live=false; self.pending=nil
        if ok then log("CANCELLED | " .. tostring(reason) .. " | preview restored")
        else log("CANCELLED | " .. tostring(reason) .. " | preview left to the game (" .. tostring(err) .. ")") end
        return true
    end
    self.restore=self.cancel_live
    function self.context_changed() end
    return self
end
return M
