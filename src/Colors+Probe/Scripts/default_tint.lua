-- Default is absence of an accent fragment, not an RGB value. This isolated
-- live-picker backend never equips a part or invents a source/default color.
local M={}
local ACCENT="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"
local MESH="br.Customization.Slot.Character.Outfit.Torso.Mesh"
local NONE="CustomizationPartDefinition:CPD_H_Outfit_Color_None"
local BLUE="CustomizationPartDefinition:CPD_H_Outfit_Color_Blue_14"
local ARMOR="CustomizationPartDefinition:CPD_H_Outfit_Clo001_TORS_TintF"
local BLUE_COLOR={R=0,G=1/15,B=.2,A=1}
local OWNER="^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"
local PREVIEW="^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.BP_CustomizationPreviewProxyCharacter_C_%d+%.CustomizationInstance$"
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
local source=debug.getinfo(1,"S").source:gsub("^@","")
local directory=assert(source:match("^(.*[/\\])"))
local handoff_module=assert(loadfile(directory .. "display_handoff.lua"))()
local owner_module=assert(loadfile(directory .. "default_owner.lua"))()
function M.new(runtime,a,path)
    local self={}
    local ownership=owner_module.new(a)
    local function log(s) runtime.log("DEFAULT TINT | " .. s) end
    local function candidates(class,limit)
        local values=FindAllOf(class) or {}; assert(type(values)=="table","Unsupported candidate list")
        local count=0; for _ in pairs(values) do count=count+1; assert(count<=limit,"Too many " .. class) end
        return values
    end
    local function obj(v)
        v=a.unwrap(v); assert(a.live(v),"Default preview object unavailable"); return v
    end
    local function name(v) return a.name(obj(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function tag(t) return {TagName=FName(t)} end
    local function slot(o,t) return obj(obj(o):GetSlotInstance(tag(t))) end
    local function same(x,y)
        if not x or not y then return false end
        for _,k in ipairs({"R","G","B","A"}) do
            if type(x[k])~="number" or x[k]~=x[k] or math.abs(x[k]-y[k])>1e-5 then return false end
        end
        return true
    end
    local function color(v)
        local c=obj(v):GetColor(); local out={}
        for _,k in ipairs({"R","G","B","A"}) do
            local n=c[k]; assert(type(n)=="number" and n==n and n>=0 and n<=1,"Invalid RGB")
            out[k]=n
        end
        assert(out.A==1,"Default preview must be opaque"); return out
    end
    local function encoded(c) return string.format("%.17g,%.17g,%.17g,%.17g",c.R,c.G,c.B,c.A) end
    local function parse(s)
        local r,g,b,alpha=s:match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
        local c={R=tonumber(r),G=tonumber(g),B=tonumber(b),A=tonumber(alpha)}
        for _,k in ipairs({"R","G","B","A"}) do
            assert(c[k] and c[k]==c[k] and c[k]>=0 and c[k]<=1,"Invalid recovery color")
        end
        assert(c.A==1,"Invalid recovery alpha"); return c
    end
    local function find(full)
        local o=(a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$"))
        if a.live(o) and name(o)==full then return o end
        -- Transient path lookup differs across UE4SS builds. Only an exact
        -- full-name match within the expected class may replace it.
        local class=full:match("^([^ ]+) ")
        assert(class=="CustomizationInstance" or class=="BitReactorCustomizationSlotViewModel","Unsupported recovery class")
        for _,candidate in pairs(candidates(class,4096)) do
            if a.live(candidate) and name(candidate)==full then return candidate end
        end
        error("Exact Default recovery identity unavailable: " .. full)
    end
    local function empty(instance,expected_slot)
        local s=slot(instance,ACCENT)
        if expected_slot then assert(name(s)==expected_slot,"Default source slot changed") end
        assert(id(s:GetCustomizationPartPrimaryAssetId())==NONE,"Source is no longer Default")
        assert(#a.values(s:GetFragmentInstances())==0,"Default has an unexpected override")
        assert(id(slot(instance,MESH):GetCustomizationPartPrimaryAssetId())==ARMOR,"Default requires Clone 8")
        return s
    end
    local function target(f)
        assert(name(obj(f):GetClass())=="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor","Not a color fragment")
        local t=f.MaterialTarget
        assert(a.text(t.MaterialParameterName)=="Color 02","Not Primary Accent")
        local tags=a.values(t.SlotNameTagsToApply.GameplayTags)
        assert(#tags==1 and a.text(tags[1].TagName)==MESH,"Unexpected target tag")
        local names,torso={},false
        for _,v in ipairs(a.values(t.MaterialSlotNames)) do
            local n=a.text(v); assert(n:match("^[%w_]+$"),"Invalid material slot")
            names[#names+1]=n; torso=torso or n=="MI_TORS"
        end
        assert(torso,"No torso material target"); return table.concat(names,",")
    end
    local function fragment(instance,expected_part)
        local s=slot(instance,ACCENT)
        assert(id(s:GetCustomizationPartPrimaryAssetId())==expected_part,"Preview swatch changed")
        local values=a.values(s:GetFragmentInstances()); assert(#values==1,"Expected one preview color")
        local f=obj(values[1]); local materials=target(f)
        assert(name(f:GetOwningCustomizationInstance())==name(instance)
            and name(f:GetOwningCustomizationSlot())==name(s),"Preview fragment ownership changed")
        assert(id(slot(instance,MESH):GetCustomizationPartPrimaryAssetId())==ARMOR,"Preview armor changed")
        return f,s,materials
    end
    local function inspect(instance,expected,materials,part)
        if id(part)==NONE then empty(instance); return end
        local f,_,m=fragment(instance,id(part))
        assert(m==materials and same(color(f),expected),"Default display color/target mismatch")
    end
    local handoff=handoff_module.new(runtime,a,inspect)
    local function selected()
        local choices={}
        for _,aux in pairs(candidates("CustomizationAuxVM_C",128)) do
            if a.live(aux) and a.live(a.prop(aux,"CurrentCustomizationSlotVM")) then choices[#choices+1]=aux end
        end
        assert(#choices==1,"Default selection ambiguous")
        local aux=choices[1]; local vm=obj(aux.CurrentCustomizationSlotVM)
        return aux,vm,obj(vm.EquippedCustomizationPartViewModel)
    end
    function self.selected()
        local ok,yes=pcall(function() local _,_,part=selected(); return id(part.AssetId)==NONE end)
        return ok and yes
    end
    local function resolve()
        local page
        for _,p in pairs(candidates("WBP_Customization_ItemPage_C",128)) do
            if a.live(p) and p:IsActivated() then assert(not page,"Ambiguous active page"); page=name(p) end
        end
        assert(page,"Open customization first")
        local aux,vm,part=selected()
        assert(a.text(vm.SlotTag.TagName)==ACCENT and name(vm):match(VM),"Select Clone 8 Primary Accent")
        assert(id(part.AssetId)==NONE and #a.values(vm:GetFragments())==0,"Default selection changed")
        local owner,anchor_vm,tree_root=ownership.resolve(aux,vm)
        assert(name(owner):match(OWNER),"Unsupported Style fragment owner")
        local source_slot=empty(owner)
        local preview=obj(owner:GetPreviewCustomizationInstance())
        assert(name(preview):match(PREVIEW),"Unsupported Default preview")
        return {page=page,slot=vm,part=part,owner=owner,source_slot=source_slot,preview=preview,
            root_vm=anchor_vm,tree_root=tree_root}
    end
    function self.read_context() return resolve() end
    local function persist(s)
        local data=""
        if s then
            data=table.concat({s.tree_root and "default-v2" or "default-v1",s.owner,s.preview,s.source_slot,s.slot_vm,s.handoff.container,
                s.handoff.display,s.phase,s.fragment,s.materials,encoded(s.test_color),encoded(s.previous_color),s.root_vm},"\n") .. "\n"
            if s.tree_root then data=data .. s.tree_root .. "\n" end
        end
        local f=assert(io.open(path,"w"),"Cannot write Default recovery")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        f:close(); assert(ok,err)
    end
    local function source_unchanged(s)
        local owner=find(s.owner); empty(owner,s.source_slot)
        local vm=find(s.slot_vm)
        if s.tree_root then
            ownership.verify(find(s.tree_root),vm,s.root_vm,s.owner)
        else
            -- v0.2.16 recovery remains read-compatible; never reinterpret a
            -- legacy root identity as a Style identity.
            local roots=a.values(find(s.root_vm):GetFragments())
            assert(#roots>0,"Default root no longer has fragments")
            for _,f in ipairs(roots) do
                assert(name(obj(f):GetOwningCustomizationInstance())==s.owner,"Default root owner changed")
            end
        end
        assert(a.text(vm.SlotTag.TagName)==ACCENT and id(obj(vm.EquippedCustomizationPartViewModel).AssetId)==NONE
            and #a.values(vm:GetFragments())==0,"Default slot VM changed")
        local preview=obj(owner:GetPreviewCustomizationInstance())
        assert(name(preview)==s.preview,"Default preview replaced")
        return owner,preview,vm
    end
    local function check(s)
        assert(self.pending==s and s.live and not s.stop,"Default preview ended")
        local c=resolve()
        assert(c.page==s.page and name(c.slot)==s.slot_vm and name(c.owner)==s.owner
            and c.root_vm==s.root_vm and c.tree_root==s.tree_root,"Default UI context changed")
        source_unchanged(s)
        local f,_,materials=fragment(c.preview,BLUE)
        assert(name(f)==s.fragment and materials==s.materials and same(color(f),s.test_color),"Default owned tint changed")
        handoff.verify(s,c.owner,c.preview,s.test_color,s.materials,{PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_H_Outfit_Color_Blue_14"})
        return f,c.preview
    end
    function self.restore(reason)
        local s=self.pending; if not s then return true end
        s.live=false; self.busy=true
        local ok,err=pcall(function()
            runtime:cancel("default:timeout"); runtime:cancel("default:check"); runtime:cancel("default:context")
            local owner=find(s.owner)
            local preview=obj(owner:GetPreviewCustomizationInstance())
            if name(preview)~=s.preview then
                persist(nil); self.pending=nil; log("RELEASED | linked preview replaced; no writes"); return
            end
            local ps=slot(preview,ACCENT); local part=id(ps:GetCustomizationPartPrimaryAssetId())
            if part~=BLUE then
                -- Stock equip/hover can displace the preview before our callback.
                -- Do not require the old equipped Default or reset the new choice.
                handoff.restore(s,owner,preview,false,function() end,function() error("Unexpected reset") end)
                persist(nil); self.pending=nil; log("RELEASED | stock selection replaced preview; no writes"); return
            end
            local _,_,vm=source_unchanged(s)
            local may_reset=false
            if part==BLUE then
                local f,_,materials=fragment(preview,BLUE); local current=color(f)
                if s.materials~="none" then assert(materials==s.materials,"Default cleanup target changed") end
                if s.phase=="activating" or s.phase=="copying" then
                    assert(same(current,BLUE_COLOR),"Unverified color after Default activation/copy")
                    may_reset=true -- no custom write was possible in these phases
                elseif name(f)==s.fragment then
                    assert(same(current,s.test_color) or same(current,s.previous_color) or same(current,BLUE_COLOR),"Owned Default tint edited externally")
                    f:SetColor(BLUE_COLOR); preview:RefreshCustomization()
                    local restored,_,m=fragment(preview,BLUE)
                    assert(m==materials and same(color(restored),BLUE_COLOR),"Default rollback readback failed")
                    may_reset=true
                else
                    assert(same(current,BLUE_COLOR),"Untracked Default preview fragment; recovery retained")
                    log("Stock hover replaced our fragment; no reset")
                end
            end
            handoff.restore(s,owner,preview,may_reset,function(instance)
                empty(owner,s.source_slot); empty(instance)
            end,function()
                source_unchanged(s); vm:ResetPreviewedPart()
            end)
            persist(nil); self.pending=nil
            log("RESTORED | Default has no override | " .. (reason or "Cancel"))
        end)
        self.busy=false
        if not ok then log("RESTORE FAILED | " .. tostring(err) .. " | recovery retained; do not save") end
        return ok
    end
    function self.begin_live()
        if self.pending or self.blocked then return end
        self.busy=true
        local ok,err=pcall(function()
            -- Default has no RGB override. Begin from the verified temporary
            -- stock donor; cancellation still restores the absence of color.
            local chosen={R=BLUE_COLOR.R,G=BLUE_COLOR.G,B=BLUE_COLOR.B,A=1}
            local c=resolve(); empty(c.preview)
            log("OWNERSHIP | character tree=" .. c.tree_root .. " | Style=" .. c.root_vm .. " | owner=" .. name(c.owner))
            local vm_outer=name(c.slot):match("^[^ ]+ (.+)%.BitReactorCustomizationSlotViewModel_%d+$")
            local blue_vm
            for _,vm in pairs(candidates("BitReactorCustomizationPartViewModel",2048)) do
                if a.live(vm) and id(obj(vm).AssetId)==BLUE
                    and name(vm):match("^BitReactorCustomizationPartViewModel (.+)%.BitReactorCustomizationPartViewModel_%d+$")==vm_outer then
                    assert(not blue_vm,"Ambiguous Blue_14")
                    assert(name(vm:GetClass())=="Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel","Unexpected Blue_14 class")
                    blue_vm=vm
                end
            end
            assert(blue_vm,"No cached Blue_14 swatch")
            local s={owner=name(c.owner),preview=name(c.preview),source_slot=name(c.source_slot),slot_vm=name(c.slot),
                page=c.page,root_vm=c.root_vm,tree_root=c.tree_root,phase="activating",fragment="none",materials="none",test_color=chosen,previous_color=BLUE_COLOR,
                handoff=handoff.prepare(c,c.preview),blue={part=BLUE,slot_vm=name(c.slot)},
                perf_selection="Default",perf_target={backend="default-preview",part=NONE}}
            persist(s); self.pending=s
            handoff.activate(s,c,c.preview,blue_vm)
            source_unchanged(s)
            local donor,ps,materials=fragment(c.preview,BLUE)
            assert(same(color(donor),BLUE_COLOR),"Stock donor is not measured Blue_14")
            handoff.verify(s,c.owner,c.preview,BLUE_COLOR,materials,blue_vm.AssetId)
            s.materials=materials; s.fragment=name(donor); s.phase="copying"; persist(s)
            -- The observed native setter copies fragment instances. Require a
            -- distinct owned result; never tint the stock donor if it aliases.
            ps:SetFragmentInstances({donor})
            local installed,_,m=fragment(c.preview,BLUE)
            assert(name(installed)~=name(donor) and m==materials and same(color(installed),BLUE_COLOR),"Default setter did not make a separate verified copy")
            s.fragment=name(installed); s.phase="writing"; persist(s)
            installed:SetColor(chosen); c.preview:RefreshCustomization()
            s.live=true; check(s)
            s.phase="owned"; persist(s)
            runtime:after("default:check",750,function()
                if self.pending~=s then return end
                local healthy,why=self.check_live(s)
                if not healthy then log(tostring(why)); self.restore("settled check failed") end
            end)
            log("LIVE START | equipped Default remains empty | RGB=" .. encoded(chosen))
        end)
        self.busy=false
        if not ok then log("OPEN FAILED | " .. tostring(err)); self.restore("open failed"); return nil end
        return self.pending
    end
    function self.check_live(s) return pcall(check,s) end
    function self.update_live(s,chosen)
        self.busy=true
        local ok,err=pcall(function()
            chosen=parse(encoded(chosen))
            local f,preview=check(s)
            s.previous_color=s.test_color; s.test_color=chosen; s.phase="writing"; persist(s)
            f:SetColor(chosen); preview:RefreshCustomization(); check(s)
            s.phase="owned"; persist(s)
        end)
        self.busy=false
        if not ok then log("UPDATE FAILED | " .. tostring(err)); self.restore("update failed") end
        return ok
    end
    function self.context_changed(reason)
        local s=self.pending; if not s or self.busy then return end
        if reason~="UpdateCurrentCustomizationSlotVM" then s.stop=true end
        runtime:after("default:context",1,function()
            if self.pending~=s then return end
            if not self.check_live(s) then self.restore("context: " .. reason) end
        end)
    end
    function self.start(data)
        local ok,err=pcall(function()
            assert(#data<=16384 and data:sub(-1)=="\n","Malformed Default journal")
            local f={}; for line in data:gmatch("([^\n]*)\n") do f[#f+1]=line end
            assert((#f==13 and f[1]=="default-v1" or #f==14 and f[1]=="default-v2" and f[14]:match(VM))
                and f[2]:match(OWNER) and f[3]:match(PREVIEW)
                and f[4]:match("^CustomizationFragmentInstanceSlot .+") and f[5]:match(VM)
                and f[13]:match(VM)
                and handoff_module.valid_record(f[6],f[7]),"Untrusted Default recovery identities")
            local phase=f[8]
            assert(phase=="activating" or phase=="copying" or phase=="writing" or phase=="owned","Invalid Default phase")
            local prefix="CustomizationFragmentInstanceMaterialColor " .. f[3]:match("^[^ ]+ (.+)$") .. "."
            assert(phase=="activating" and f[9]=="none" and f[10]=="none"
                or f[9]:sub(1,#prefix)==prefix and f[10]:match("^[%w_,]+$"),"Untrusted Default fragment")
            self.pending={owner=f[2],preview=f[3],source_slot=f[4],slot_vm=f[5],handoff={container=f[6],display=f[7]},
                phase=phase,fragment=f[9],materials=f[10],test_color=parse(f[11]),previous_color=parse(f[12]),root_vm=f[13],tree_root=f[14],blue={part=BLUE,slot_vm=f[5]}}
            runtime:after("default:recovery",1,function() self.restore("reload recovery") end)
        end)
        if not ok then self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
    end
    return self
end
function M.wrap(runtime,a,path,base)
    local default=M.new(runtime,a,path)
    local wrapper=setmetatable({}, {__index=function(_,key)
        if key=="pending" then return default.pending or base.pending end
        if key=="blocked" then return default.blocked or base.blocked end
        if key=="busy" then return default.busy or base.busy end
        return base[key]
    end})
    function wrapper.start()
        local f=io.open(path,"r"); local data
        if f then data=f:read(16385); f:close() end
        if data then data=data:gsub("\r\n","\n") end
        if data and data:match("^default%-") then default.start(data) else base.start() end
    end
    function wrapper.begin_live()
        if wrapper.pending or wrapper.blocked then return nil end
        if default.selected() then return default.begin_live() end
        return base.begin_live()
    end
    function wrapper.restore(reason)
        if default.pending then return default.restore(reason) end
        return base.restore(reason)
    end
    function wrapper.check_live(s)
        if default.pending==s and s then return default.check_live(s) end
        return base.check_live(s)
    end
    function wrapper.update_live(s,c)
        if default.pending==s and s then return default.update_live(s,c) end
        return base.update_live(s,c)
    end
    function wrapper.context_changed(reason)
        if default.pending then default.context_changed(reason) else base.context_changed(reason) end
    end
    function wrapper.read_context()
        if default.selected() then return default.read_context() end
        return base.read_context()
    end
    for _,key in ipairs({"apply","apply_rgb","cycle_rgb","inspect"}) do
        wrapper[key]=function(...)
            if default.pending or default.blocked then
                runtime.log("DEFAULT TINT | Finish Default preview/recovery first"); return false
            end
            return base[key](...)
        end
    end
    -- Inclusive per-layer opening time for the performance log; no behavior change.
    local timed_begin_live=wrapper.begin_live
    function wrapper.begin_live(...)
        if runtime.perf then return runtime.perf.measure("begin.default_tint",timed_begin_live,...) end
        return timed_begin_live(...)
    end
    return wrapper
end
return M
