-- Default fallback: temporarily equip a stock swatch in the editor, then use
-- the regular RGB preview. Restore the preview BEFORE re-equipping Default.
-- No save APIs; two independent journals preserve the two cleanup obligations.
local M={}
local ACCENT="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"
local NONE="CustomizationPartDefinition:CPD_H_Outfit_Color_None"
local BLUE="CustomizationPartDefinition:CPD_H_Outfit_Color_Blue_14"
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
local PART="^BitReactorCustomizationPartViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationPartViewModel_%d+$"
local EMPTY_PART="^BitReactorNoneCustomizationPartViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorNoneCustomizationPartViewModel_%d+$"
local OWNER="^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"
local function outer(full) return full:match("^[^ ]+ (.+)%.BitReactorCustomization%w+ViewModel_%d+$")
    or full:match("^[^ ]+ (.+)%.BitReactorNoneCustomizationPartViewModel_%d+$") end
function M.wrap(runtime,a,path,regular,base)
    local selection,blocked,busy,held
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local targets=assert(loadfile(directory .. "color_target.lua"))().new(a,runtime.log)
    local rules=assert(loadfile(directory .. "color_rules.lua"))()
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local function valid_tag(s) return type(s)=="string" and s:match("^br%.Customization%.Slot%.Character%.[%w_.]+$") end
    local function is_default(s) return s==NONE or runtime.generic_colors and (s=="None:None" or s:match("_None$")~=nil) end
    local self=setmetatable({}, {__index=function(_,key)
        if key=="pending" then return base.pending or (not held and selection) end
        if key=="blocked" then return blocked or base.blocked end
        if key=="busy" then return busy or base.busy end
        return base[key]
    end})
    local function log(s) runtime.log("DEFAULT SELECTION | " .. s) end
    local function object(v,label)
        v=a.unwrap(v); assert(a.live(v),"Unavailable " .. (label or "Default selection object")); return v
    end
    local function name(v) return a.name(object(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function equipped(vm) return id(object(vm.EquippedCustomizationPartViewModel,"equipped swatch").AssetId) end
    local function candidates(class,limit)
        local items=FindAllOf(class) or {}; assert(type(items)=="table","Unsupported object list")
        local n=0; for _ in pairs(items) do n=n+1; assert(n<=limit,"Too many " .. class) end
        return items
    end
    local function find(full)
        local value=(a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$"))
        if a.live(value) and name(value)==full then return value end
        local class=full:match("^([^ ]+) ")
        assert(class=="BitReactorCustomizationSlotViewModel" or class=="BitReactorCustomizationPartViewModel"
            or runtime.generic_colors and class=="BitReactorNoneCustomizationPartViewModel"
            or class=="CustomizationInstance","Unsupported recovery class")
        for _,v in pairs(candidates(class,4096)) do
            if a.live(v) and name(v)==full then return v end
        end
        error("Exact Default selection identity unavailable: " .. full)
    end
    local page,lookup_route
    local lookup_revision=0
    local function selected()
        local revision=lookup_revision
        if runtime.generic_colors and lookup_route then
            local route=lookup_route
            local ok,value=pcall(function()
                assert(lifetime.page_active(route.creator,route.page),"Selected page changed")
                local aux=object((a.find or StaticFindObject)(assert(route.aux:match("^[^ ]+ (.+)$"))))
                assert(name(aux)==route.aux,"Selected auxiliary VM changed")
                local vm=object(a.prop(aux,"CurrentCustomizationSlotVM"))
                assert(name(vm)==route.vm and a.text(vm.SlotTag.TagName)==route.tag,"Selected slot changed")
                return targets.selected(vm,route.page,a.prop(aux,"RootCustomizationSlotVM"))
            end)
            assert(revision==lookup_revision,"Selection changed during lookup")
            if ok then return value end
            lookup_route=nil -- failed hint gets full ambiguity-checked discovery
        end
        local found,root,aux_name
        for _,aux in pairs(candidates("CustomizationAuxVM_C",128)) do
            if a.live(aux) then
                local vm=a.unwrap(a.prop(aux,"CurrentCustomizationSlotVM"))
                if a.live(vm) then
                    assert(not found,"Ambiguous current customization slot"); found=vm
                    root=a.prop(aux,"RootCustomizationSlotVM")
                    aux_name=name(aux)
                end
            end
        end
        found=object(found,"current customization slot")
        if not runtime.generic_colors then return found end
        local active_page=page()
        local selected=targets.selected(found,active_page,root)
        local route={page=active_page,aux=aux_name,vm=name(found),tag=a.text(found.SlotTag.TagName),
            creator=lifetime.bind(active_page)} -- scalar identities only
        assert(revision==lookup_revision,"Selection changed during discovery")
        lookup_route=route
        return selected
    end
    page=function()
        local found
        for _,p in pairs(candidates("WBP_Customization_ItemPage_C",128)) do
            if a.live(p) and p:IsActivated() then assert(not found,"Ambiguous active page"); found=name(p) end
        end
        return assert(found,"Open customization first")
    end
    local function part(v,vm)
        v=object(v,"palette swatch")
        local empty=runtime.generic_colors and name(v):match(EMPTY_PART) and id(v.AssetId)=="None:None"
            and name(v:GetClass())=="Class /Script/BitReactorGame.BitReactorNoneCustomizationPartViewModel"
        assert((name(v):match(PART) or empty) and outer(name(v))==outer(name(vm)),"Swatch game-instance mismatch")
        assert(empty or name(v:GetClass())=="Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel","Unexpected swatch class")
        return v
    end
    local function first_swatch(vm)
        if runtime.generic_colors then
            local items,grid=targets.palette(vm,page())
            for _,item in ipairs(items) do
                if not is_default(item.asset) and rules.preview_asset(a.text(vm.SlotTag.TagName),item.asset) then
                    return item.object,grid,item.index
                end
            end
            error("No non-Default fallback swatch")
        end
        local found,grid_name,index
        for _,widget in pairs(candidates("WBP_Customization_SelectionTiles_C",256)) do
            if a.live(widget) and widget:IsVisible()
                and a.text(a.prop(a.prop(widget,"CurrentSlotTag"),"TagName"))==ACCENT then
                local grid=object(widget.PartsGridList,"stock swatch list")
                local count=grid:GetNumItems()
                assert(type(count)=="number" and count%1==0 and count>=0 and count<=1024,"Invalid swatch-list size")
                local first,at,has_default
                for i=0,count-1 do
                    local item=part(grid:GetItemAt(i),vm)
                    assert(grid:GetIndexForItem(item)==i,"Swatch-list ordering changed")
                    local asset=id(item.AssetId)
                    assert(asset:match("^CustomizationPartDefinition:CPD_H_Outfit_Color_[%w_]+$"),"Not an outfit-color palette")
                    if asset==NONE then
                        has_default=has_default or name(item)==name(vm.EquippedCustomizationPartViewModel)
                    elseif not first then first,at=item,i end
                end
                if first and has_default then
                    assert(not found,"Ambiguous active accent palette")
                    found,grid_name,index=first,name(grid),at
                end
            end
        end
        assert(found,"No verified Primary Accent swatch list with Default")
        -- The regular path needs a different equipped swatch for its Blue_14
        -- handoff. Refuse this unusual order rather than silently skip a color.
        assert(id(found.AssetId)~=BLUE,"First stock swatch is the reserved Blue_14 preview donor")
        return found,grid_name,index
    end
    local function persist(s)
        local data=""
        if s then
            local fields={s.tag and "selection-v2" or "selection-v1",s.slot_vm,s.default_vm,s.temp_vm,s.temp_part,
                s.owner or "unbound",s.source_slot or "unbound",s.owner and "selected" or "selecting"}
            if s.tag then assert(valid_tag(s.tag),"Invalid Default recovery tag"); fields[9]=s.tag end
            data=table.concat(fields,"\n") .. "\n"
        end
        local f=assert(io.open(path,"w"),"Cannot write Default selection recovery")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Cannot close Default selection recovery")
    end
    local function source_slot(owner,s)
        return object(owner:GetSlotInstance({TagName=FName(s.tag or ACCENT)}),"source color slot")
    end
    local function verify_bound(s,vm)
        local owner=find(s.owner); local slot=source_slot(owner,s)
        assert(name(slot)==s.source_slot,"Default selection source slot replaced")
        assert(id(slot:GetCustomizationPartPrimaryAssetId())==s.temp_part,"Source swatch changed")
        local fragments=a.values(vm:GetFragments())
        local f
        if #fragments==1 then f=object(fragments[1])
        else
            local bundle=assert(loadfile(directory .. "color_fragments.lua"))().new(a)
            local primary=bundle.read(fragments,s.tag and {slot=s.tag} or nil)
            f=object(primary)
        end
        assert(name(f:GetOwningCustomizationInstance())==s.owner and name(f:GetOwningCustomizationSlot())==s.source_slot,
            "Default selection owner changed")
        return owner,slot
    end
    local function restore_selection(reason)
        if not selection then return not blocked end
        local s=selection; busy=true
        local ok,err=pcall(function()
            assert(not blocked and not base.blocked and not base.pending,"Finish RGB/legacy recovery before restoring Default")
            local vm=find(s.slot_vm)
            assert(a.text(vm.SlotTag.TagName)==(s.tag or ACCENT),"Recorded Default slot changed")
            local current=equipped(vm)
            local original=part(find(s.default_vm),vm)
            local default_asset=id(original.AssetId)
            assert(is_default(default_asset),"Recorded original is not Default")
            if current~=s.temp_part and current~=default_asset then
                persist(nil); selection=nil
                log("RELEASED | another stock swatch was selected; left it unchanged"); return
            end
            if current==s.temp_part then
                if s.owner then verify_bound(s,vm)
                else
                    -- Only the still-running synchronous opening attempt may
                    -- undo an equip before owner discovery finished. On reload
                    -- an unbound record must never guess a character.
                    assert(s.opening and name(selected())==s.slot_vm and page()==s.page,
                        "Unbound selection recovery; manually return the original slot to Default")
                end
                log("CALL | EquipCustomizationPart | restore Default | " .. tostring(reason))
                vm:EquipCustomizationPart(original)
            end
            assert(equipped(vm)==default_asset and #a.values(vm:GetFragments())==0,"Default restoration readback failed")
            if s.owner then
                local source=source_slot(find(s.owner),s)
                assert(name(source)==s.source_slot and id(source:GetCustomizationPartPrimaryAssetId())==default_asset
                    and #a.values(source:GetFragmentInstances())==0,"Source Default restoration readback failed")
            end
            persist(nil); selection=nil
            log("RESTORED | equipped Default; no accent override | " .. tostring(reason))
        end)
        busy=false
        if not ok then log("RESTORE FAILED | " .. tostring(err) .. " | recovery retained; do not save") end
        return ok
    end
    -- Regular tint timeout/context/error callbacks call regular.restore directly.
    -- Intercept that one boundary so Default restoration cannot be skipped when
    -- the RGB session ends before the picker notices it.
    local regular_restore=regular.restore
    regular.restore=function(reason)
        local ok=regular_restore(reason)
        if ok and selection and not busy and not held then return restore_selection(reason) end
        return ok
    end
    function self.restore(reason)
        local ok=base.restore(reason)
        if ok and selection and not held then return restore_selection(reason) end
        return ok and not blocked
    end
    -- Session Apply retains the temporary stock selection, not its hover preview.
    -- The outer editor-session owner must release this hold on exit/recovery.
    function self.hold_selection(value) held=value==true end
    function self.forget_selection()
        -- Only after the outer owner proves the live source was replaced by a
        -- later stock edit. Never re-equip Default over that user's new choice.
        persist(nil); selection=nil; held=false
    end
    function self.selected_slot_identity()
        if runtime.perf then return runtime.perf.measure("context.selected_slot",function() return name(selected()) end) end
        return name(selected())
    end
    function self.begin_live()
        if self.pending or self.blocked then return nil end
        busy=true
        local session
        local ok,err=pcall(function()
            local vm=selected()
            if held and selection then
                assert(name(vm)==selection.slot_vm,"Applied Default selection context changed")
                selection.page=page() -- item page may be recreated within the same creator
                verify_bound(selection,vm)
            end
            if not is_default(equipped(vm)) then session=base.begin_live(); return end
            local active_page=page()
            local slot_tag=a.text(vm.SlotTag.TagName)
            assert(name(vm):match(VM) and (runtime.generic_colors and valid_tag(slot_tag) or slot_tag==ACCENT),"Select a color slot")
            assert(equipped(vm)~="None:None" or rules.empty_editable_slot(slot_tag),"Empty slot is not a supported color zone")
            if runtime.generic_colors then lifetime.bind(active_page) end
            assert(#a.values(vm:GetFragments())==0,"Default has unexpected fragments")
            local original=part(vm.EquippedCustomizationPartViewModel,vm)
            local chosen,grid,index=first_swatch(vm)
            local s={slot_vm=name(vm),default_vm=name(original),temp_vm=name(chosen),temp_part=id(chosen.AssetId),
                page=active_page,opening=true,tag=runtime.generic_colors and slot_tag or nil}
            persist(s); selection=s -- durable intent BEFORE any editor mutation
            log("CALL | EquipCustomizationPart | temporary=" .. s.temp_part .. " | index=" .. index .. " | list=" .. grid)
            vm:EquipCustomizationPart(chosen)
            assert(name(selected())==s.slot_vm and page()==active_page and equipped(vm)==s.temp_part,
                "Temporary selection did not settle on the same slot")
            -- Reuse the already-proven fragment/owner/armor/target verification.
            local context=regular.read_context()
            assert(name(context.slot)==s.slot_vm and id(context.part.AssetId)==s.temp_part,"Temporary selection context changed")
            s.owner=name(context.owner); s.source_slot=name(context.source_slot)
            assert(s.owner:match(OWNER),"Unsupported temporary selection owner")
            persist(s)
            session=assert(base.begin_live(),"Regular RGB preview could not start")
            session.perf_selection="Default"
            s.opening=nil
            log("LIVE START | temporarily equipped stock swatch; closing restores Default; no save")
        end)
        busy=false
        if not ok then
            log("OPEN FAILED | " .. tostring(err)); self.restore("picker opening failed")
            if selection then selection.opening=nil end
            return nil
        end
        return session
    end
    function self.invalidate_context_lookup(reason)
        lookup_revision=lookup_revision+1 -- refuses lookups in flight
        -- Stored hints survive non-structural events: selected() revalidates
        -- page, auxiliary VM, slot VM identity and tag before every use.
        if rules.structural_context(reason) then lookup_route=nil end
        if base.invalidate_context_lookup then base.invalidate_context_lookup(reason) end
    end
    function self.context_changed(reason)
        self.invalidate_context_lookup(reason)
        if busy then return end -- ignore only our synchronous equip/reset events
        base.context_changed(reason)
    end
    function self.start()
        local f=io.open(path,"r")
        if f then
            local data=f:read(16385); f:close(); data=(data or ""):gsub("\r\n","\n")
            if data~="" then
                local ok,err=pcall(function()
                    local v={}; for line in data:gmatch("([^\n]*)\n") do v[#v+1]=line end
                    local generic=#v==9 and v[1]=="selection-v2" and valid_tag(v[9])
                    assert(#data<=16384 and data:sub(-1)=="\n" and (#v==8 and v[1]=="selection-v1" or generic)
                        and v[2]:match(VM) and (v[3]:match(PART) or generic and v[3]:match(EMPTY_PART)
                            and rules.empty_editable_slot(v[9])) and v[4]:match(PART)
                        and outer(v[2])==outer(v[3]) and outer(v[2])==outer(v[4]) and v[3]~=v[4]
                        and v[5]:match(generic and "^CustomizationPartDefinition:[%w_]+$" or "^CustomizationPartDefinition:CPD_H_Outfit_Color_[%w_]+$")
                        and (not generic or rules.preview_asset(v[9],v[5]))
                        and not is_default(v[5]) and (generic or v[5]~=BLUE),
                        "Malformed Default selection recovery")
                    local bound=v[8]=="selected" and v[6]:match(OWNER)
                        and v[7]:sub(1,#("CustomizationFragmentInstanceSlot " .. v[6]:match("^[^ ]+ (.+)$") .. "."))
                            =="CustomizationFragmentInstanceSlot " .. v[6]:match("^[^ ]+ (.+)$") .. "."
                    assert(bound or v[8]=="selecting" and v[6]=="unbound" and v[7]=="unbound","Invalid selection recovery phase/owner")
                    selection={slot_vm=v[2],default_vm=v[3],temp_vm=v[4],temp_part=v[5],
                        owner=bound and v[6] or nil,source_slot=bound and v[7] or nil,tag=generic and v[9] or nil}
                end)
                if not ok then blocked=tostring(err); log("RECOVERY BLOCKED | " .. blocked) end
            end
        end
        base.start()
        if selection then
            runtime:after("selection:recovery",50,function()
                if selection then self.restore("reload recovery") end
            end)
        end
    end
    for _,key in ipairs({"apply","apply_rgb","cycle_rgb","inspect"}) do
        self[key]=function(...)
            if selection or blocked then log("Finish Default selection recovery first"); return false end
            return base[key](...)
        end
    end
    -- Inclusive per-layer opening time for the performance log; no behavior change.
    local timed_begin_live=self.begin_live
    function self.begin_live(...)
        if runtime.perf then return runtime.perf.measure("begin.default_selection",timed_begin_live,...) end
        return timed_begin_live(...)
    end
    return self
end
return M
