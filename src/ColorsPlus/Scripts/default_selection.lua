-- Default and empty slots have no fragment for the preview to clone. The zone
-- temporarily equips a stock swatch for the visit, previews that, and returns
-- the slot to Default after the preview ends (color_zone sequences this).
-- No save APIs; the journal records intent before every editor mutation.
local M={}
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
local PART="^BitReactorCustomizationPartViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationPartViewModel_%d+$"
local EMPTY_PART="^BitReactorNoneCustomizationPartViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorNoneCustomizationPartViewModel_%d+$"
local function outer(full) return full:match("^[^ ]+ (.+)%.BitReactorCustomization%w+ViewModel_%d+$")
    or full:match("^[^ ]+ (.+)%.BitReactorNoneCustomizationPartViewModel_%d+$") end
function M.new(runtime,a,path,preview)
    -- record: the journaled temporary selection. held: an Apply keeps it for
    -- the creator visit. busy: our own equip is running (ignore its events).
    local self={busy=false,held=false}
    local selection
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local targets=assert(loadfile(directory .. "color_target.lua"))().new(a,runtime.log)
    local rules=assert(loadfile(directory .. "color_rules.lua"))()
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local worlds=assert(loadfile(directory .. "editor_worlds.lua"))()
    local function valid_tag(s) return type(s)=="string" and s:match("^br%.Customization%.Slot%.Character%.[%w_.]+$") end
    local function is_default(s) return s=="None:None" or s:match("_None$")~=nil end
    local function log(s) runtime.log("DEFAULT SELECTION | " .. s) end
    self.log=log
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
            or class=="BitReactorNoneCustomizationPartViewModel"
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
        if lookup_route then
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
        local function current(aux) return a.live(aux) and a.live(a.unwrap(a.prop(aux,"CurrentCustomizationSlotVM"))) end
        local auxes
        if runtime.known then auxes=runtime.known.select("CustomizationAuxVM_C",128,current)
        else auxes={}; for _,aux in pairs(candidates("CustomizationAuxVM_C",128)) do if current(aux) then auxes[#auxes+1]=aux end end end
        for _,aux in ipairs(auxes) do
            assert(not found,"Ambiguous current customization slot")
            found=a.unwrap(a.prop(aux,"CurrentCustomizationSlotVM"))
            root=a.prop(aux,"RootCustomizationSlotVM")
            aux_name=name(aux)
        end
        found=object(found,"current customization slot")
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
        local function active(p) return a.live(p) and p:IsActivated()==true end
        local pages
        if runtime.known then pages=runtime.known.select("WBP_Customization_ItemPage_C",128,active)
        else pages={}; for _,p in pairs(candidates("WBP_Customization_ItemPage_C",128)) do if active(p) then pages[#pages+1]=p end end end
        for _,p in ipairs(pages) do assert(not found,"Ambiguous active page"); found=name(p) end
        return assert(found,"Open customization first")
    end
    local function part(v,vm)
        v=object(v,"palette swatch")
        local empty=name(v):match(EMPTY_PART) and id(v.AssetId)=="None:None"
            and name(v:GetClass())=="Class /Script/BitReactorGame.BitReactorNoneCustomizationPartViewModel"
        assert((name(v):match(PART) or empty) and outer(name(v))==outer(name(vm)),"Swatch game-instance mismatch")
        assert(empty or name(v:GetClass())=="Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel","Unexpected swatch class")
        return v
    end
    local function first_swatch(vm)
        local items,grid=targets.palette(vm,page(),true)
        for _,item in ipairs(items) do
            if not is_default(item.asset) and rules.preview_asset(a.text(vm.SlotTag.TagName),item.asset) then
                return item.object,grid,item.index
            end
        end
        error("No non-Default fallback swatch")
    end
    local function persist(s)
        local data=""
        if s then
            assert(valid_tag(s.tag),"Invalid Default recovery tag")
            local fields={"selection-v2",s.slot_vm,s.default_vm,s.temp_vm,s.temp_part,
                s.owner or "unbound",s.source_slot or "unbound",s.owner and "selected" or "selecting",s.tag}
            data=table.concat(fields,"\n") .. "\n"
        end
        local f=assert(io.open(path,"w"),"Cannot write Default selection recovery")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Cannot close Default selection recovery")
    end
    local function source_slot(owner,s)
        return object(owner:GetSlotInstance({TagName=FName(s.tag)}),"source color slot")
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
            local primary=bundle.read(fragments,{slot=s.tag})
            f=object(primary)
        end
        assert(name(f:GetOwningCustomizationInstance())==s.owner and name(f:GetOwningCustomizationSlot())==s.source_slot,
            "Default selection owner changed")
        return owner,slot
    end
    -- Only after the preview ended: the hover must never outlive its baseline.
    function self.restore(reason)
        if not selection then return not self.blocked end
        local s=selection; self.busy=true
        local ok,err=pcall(function()
            assert(not self.blocked and not preview.blocked and not preview.pending,"Finish RGB/legacy recovery before restoring Default")
            local vm=find(s.slot_vm)
            assert(a.text(vm.SlotTag.TagName)==s.tag,"Recorded Default slot changed")
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
        self.busy=false
        if not ok then log("RESTORE FAILED | " .. tostring(err) .. " | recovery retained; do not save") end
        return ok
    end
    function self.record() return selection end
    -- Apply retains the temporary stock selection for the creator visit, not
    -- its hover preview; the zone releases this hold on exit/recovery.
    function self.hold(value) self.held=value==true end
    function self.forget()
        -- Only after the zone proves the live source was replaced by a later
        -- stock edit. Never re-equip Default over that user's new choice.
        persist(nil); selection=nil; self.held=false
    end
    function self.selected_slot_identity() return name(selected()) end
    -- The object itself, for same-call use only: a by-name reacquisition of a
    -- slot VM UE4SS has not seen yet costs a full object scan.
    function self.selected_slot() return object(selected(),"selected slot") end
    -- Opening step: when the selected slot shows Default, journal the intent,
    -- equip the first previewable stock swatch and bind its owner. Returns
    -- true when a temporary selection now needs the preview; the zone calls
    -- opened() once the preview started, or restores on any failure.
    function self.prepare()
        local vm=selected()
        if self.held and selection then
            assert(name(vm)==selection.slot_vm,"Applied Default selection context changed")
            selection.page=page() -- item page may be recreated within the same creator
            verify_bound(selection,vm)
        end
        if not is_default(equipped(vm)) then return false end
        local active_page=page()
        local slot_tag=a.text(vm.SlotTag.TagName)
        assert(name(vm):match(VM) and valid_tag(slot_tag),"Select a color slot")
        assert(equipped(vm)~="None:None" or rules.empty_editable_slot(slot_tag),"Empty slot is not a supported color zone")
        lifetime.bind(active_page)
        assert(#a.values(vm:GetFragments())==0,"Default has unexpected fragments")
        local original=part(vm.EquippedCustomizationPartViewModel,vm)
        local chosen,grid,index=first_swatch(vm)
        local s={slot_vm=name(vm),default_vm=name(original),temp_vm=name(chosen),temp_part=id(chosen.AssetId),
            page=active_page,opening=true,tag=slot_tag}
        persist(s); selection=s -- durable intent BEFORE any editor mutation
        log("CALL | EquipCustomizationPart | temporary=" .. s.temp_part .. " | index=" .. index .. " | list=" .. grid)
        vm:EquipCustomizationPart(chosen)
        assert(name(selected())==s.slot_vm and page()==active_page and equipped(vm)==s.temp_part,
            "Temporary selection did not settle on the same slot")
        -- Reuse the already-proven fragment/owner/armor/target verification.
        local context=preview.read_context()
        assert(name(context.slot)==s.slot_vm and id(context.part.AssetId)==s.temp_part,"Temporary selection context changed")
        s.owner=name(context.owner); s.source_slot=name(context.source_slot)
        assert(worlds.owner(s.owner),"Unsupported temporary selection owner")
        persist(s)
        return true
    end
    function self.opened()
        selection.opening=nil
        log("LIVE START | temporarily equipped stock swatch; closing restores Default; no save")
    end
    function self.open_failed(err)
        log("OPEN FAILED | " .. tostring(err))
    end
    function self.open_ended()
        -- Only the synchronous opening attempt may undo an unbound equip.
        if selection then selection.opening=nil end
    end
    function self.invalidate_context_lookup(reason)
        lookup_revision=lookup_revision+1 -- refuses lookups in flight
        -- Stored hints survive non-structural events: selected() revalidates
        -- page, auxiliary VM, slot VM identity and tag before every use.
        if rules.structural_context(reason) then lookup_route=nil end
    end
    -- Reads the journal; the zone schedules the restore when one was found.
    function self.start()
        local f=io.open(path,"r")
        if f then
            local data=f:read(16385); f:close(); data=(data or ""):gsub("\r\n","\n")
            if data~="" then
                local ok,err=pcall(function()
                    local v={}; for line in data:gmatch("([^\n]*)\n") do v[#v+1]=line end
                    assert(#data<=16384 and data:sub(-1)=="\n" and #v==9 and v[1]=="selection-v2" and valid_tag(v[9])
                        and v[2]:match(VM) and (v[3]:match(PART) or v[3]:match(EMPTY_PART)
                            and rules.empty_editable_slot(v[9])) and v[4]:match(PART)
                        and outer(v[2])==outer(v[3]) and outer(v[2])==outer(v[4]) and v[3]~=v[4]
                        and v[5]:match("^CustomizationPartDefinition:[%w_%-]+$")
                        and rules.preview_asset(v[9],v[5]) and not is_default(v[5]),
                        "Malformed Default selection recovery")
                    local bound=v[8]=="selected" and worlds.owner(v[6])
                        and v[7]:sub(1,#("CustomizationFragmentInstanceSlot " .. v[6]:match("^[^ ]+ (.+)$") .. "."))
                            =="CustomizationFragmentInstanceSlot " .. v[6]:match("^[^ ]+ (.+)$") .. "."
                    assert(bound or v[8]=="selecting" and v[6]=="unbound" and v[7]=="unbound","Invalid selection recovery phase/owner")
                    selection={slot_vm=v[2],default_vm=v[3],temp_vm=v[4],temp_part=v[5],
                        owner=bound and v[6] or nil,source_slot=bound and v[7] or nil,tag=v[9]}
                end)
                if not ok then self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
            end
        end
        return selection~=nil
    end
    return self
end
return M
