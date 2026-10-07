-- CP-owned Zabrak source transaction, derived from the native-verified v0.2.66 probe.
-- No display MID, material reference, preset or save writes. No periodic repaint.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local OUTFIT="br.Customization.Slot.Character.Outfit"
local VERSION="zabrak-picker-source-v1"
local REORDERED="1,4,2,3"
-- Canonical role IDs: tags, color, scalar, swap. Only observed source orders
-- are accepted; preserve the captured baseline verbatim for Cancel/recovery.
local ORDERS={["1,2,3,4"]=true,[REORDERED]=true,["4,1,2,3"]=true}
local function rgba(c) return string.format("%.17g,%.17g,%.17g,%.17g",c.R,c.G,c.B,c.A) end
local function valid_rgb(c)
    if type(c)~="table" or c.A~=1 then return false end
    for _,k in ipairs({"R","G","B","A"}) do
        local n=c[k]; if type(n)~="number" or n~=n or n<0 or n>1 then return false end
    end
    return true
end
local function copy_rgb(c) assert(valid_rgb(c),"Invalid CP RGB"); return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function decode(s)
    local r,g,b,a=s:match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
    local c={R=tonumber(r),G=tonumber(g),B=tonumber(b),A=tonumber(a)}
    assert(valid_rgb(c) and rgba(c)==s,"Invalid journal RGB"); return c
end
function M.new(runtime,a,path)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local codec=assert(loadfile(directory .. "color_bundle.lua"))()
    local worlds=assert(loadfile(directory .. "editor_worlds.lua"))()
    local bundles=codec.new(a)
    local self={pending=nil,blocked=nil,busy=false,hold=false}
    local function log(s) runtime.log("ZABRAK CP SOURCE | " .. s) end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local calls=0
    local quiet=false
    local unpack_values=assert(table.unpack or unpack,"Lua unpack function unavailable")
    local function pack(...) return {n=select("#",...),...} end
    local function call(label,fn)
        calls=calls+1; assert(calls<=4096,"Dispatch trace call bound")
        local prefix="CALL TRACE | call=" .. calls .. " | "
        local result=pack(pcall(fn))
        if not result[1] then
            log(prefix .. "ERROR | " .. label .. " | " .. tostring(result[2]))
            error(result[2],0)
        end
        return unpack_values(result,2,result.n)
    end
    local inspector=assert(loadfile(directory .. "zabrak_rebuild_inspector.lua"))().new(a,log,call,directory)
    local function object(v) v=call("source unwrap",function() return a.unwrap(v) end); assert(call("source IsValid",function() return a.live(v) end),"Source object unavailable"); return v end
    local function name(v) v=object(v); return call("source GetFullName",function() return a.name(v) end) end
    local function fname(s) local v=call("construct gameplay-tag FName",function() return FName(s) end); assert(call("FName ToString",function() return a.text(v) end)==s,"FName mismatch"); return v end
    local function asset(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function find(n)
        local v=a.unwrap(call("source StaticFindObject",function() return (a.find or StaticFindObject)(assert(n:match("^[^ ]+ (.+)$"))) end))
        if a.live(v) then assert(name(v)==n,"Source identity mismatch"); return v end
        local found,count=nil,0
        for _,candidate in pairs(call("source FindAllOf fallback",function() return FindAllOf(n:match("^([^ ]+) ")) end) or {}) do
            count=count+1; assert(count<=4096,"Source lookup bound")
            if a.live(candidate) and name(candidate)==n then assert(not found,"Ambiguous source"); found=candidate end
        end
        return found
    end
    local function same(x,y)
        for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>0.00001 then return false end end
        return true
    end
    local function color(f)
        local v=call("color GetColor",function() return object(f):GetColor() end); local c={}
        for _,k in ipairs({"R","G","B","A"}) do
            local n=a.prop(v,k); assert(type(n)=="number" and n==n and n>=0 and n<=1,"Invalid source RGB"); c[k]=n
        end
        assert(c.A==1,"Expected opaque skin RGB"); return c
    end
    local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
    local function swap_signature(f)
        f=object(f)
        local t=call("swap MaterialTarget",function() return object(f).MaterialTarget end)
        local parameter=call("swap parameter FString",function() return a.text(t.MaterialParameterName) end)
        local tags,materials={},{}
        local tag_values=call("swap target tags ForEach/unwrap",function() return a.values(t.SlotNameTagsToApply.GameplayTags) end)
        local material_values=call("swap target materials ForEach/unwrap",function() return a.values(t.MaterialSlotNames) end)
        assert(#tag_values>=1 and #tag_values<=16 and #material_values<=16,"Swap target bounds")
        for _,v in ipairs(tag_values) do tags[#tags+1]=call("swap tag FName ToString",function() return a.text(v.TagName) end) end
        for _,v in ipairs(material_values) do materials[#materials+1]=call("swap material slot FString",function() return a.text(v) end) end
        -- Deliberately no hard/soft material reference read, stringify or setter.
        local description=table.concat({parameter,table.concat(tags,","),table.concat(materials,",")},"|")
        assert(#description<=4096,"Swap evidence bounds")
        return hex(description),description
    end
    local function validate(s)
        assert(worlds.owner(s.owner),"Untrusted Zabrak owner")
        local root=s.owner:match("^[^ ]+ (.+)$") .. "."
        local function child(n,cls)
            local prefix=cls .. " " .. root
            assert(type(n)=="string" and n:sub(1,#prefix)==prefix and n:sub(#prefix+1):match("^[%w_.]+$"),"Untrusted source child")
        end
        child(s.slot,"CustomizationFragmentInstanceSlot")
        assert(type(s.part)=="string" and s.part:match("^CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_[%w_]+$"),"Unsupported Zabrak part")
        assert(codec.zabrak_face_enable({slot=SKIN,bundle=s.bundle}),"Unsupported Zabrak source layout")
        assert(type(s.swap)=="string" and #s.swap>0 and #s.swap<=8192 and #s.swap%2==0 and s.swap:match("^[0-9a-f]+$"),"Invalid swap recovery evidence")
        local mesh_tags=assert(codec.parse(s.bundle)).signature:match("MaterialColor/Skin Coloration/([^/]+)/")
        local prefix="Skin Coloration|" .. mesh_tags .. "|"
        assert(s.swap==hex(prefix .. "MI_Head")
            or s.part=="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_1B0"
                and s.swap==hex(prefix .. "MI_Head0"),"Unsupported recovery swap target")
        assert(s.phase=="owned" or s.phase=="reorder_pending" or s.phase=="restore_order_pending","Invalid transaction phase")
        assert(ORDERS[s.order],"Invalid recovery order")
        assert(ORDERS[s.original_order],"Invalid baseline order")
        assert(type(s.original_expanded)=="boolean","Invalid baseline targets")
        assert(valid_rgb(s.chosen) and valid_rgb(s.previous),"Invalid owned RGB")
        local seen={}
        for i,cls in ipairs({"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}) do
            child(s.ids[i],"CustomizationFragmentInstance" .. cls)
            assert(not seen[s.ids[i]],"Recovery alias"); seen[s.ids[i]]=true
        end
    end
    local function exists(p)
        local f,err,code=io.open(p,"r")
        if not f then assert(code==2,"Journal read failed: " .. tostring(err)); return false end
        assert(f:close()~=false,"Journal close failed"); return true
    end
    local function persist(s)
        local data=""
        if s then
            validate(s)
            data=table.concat({VERSION,s.owner,s.slot,s.part,s.bundle,s.swap,s.phase,s.order,s.ids[1],s.ids[2],s.ids[3],s.ids[4],s.original_order,tostring(s.original_expanded),rgba(s.chosen),rgba(s.previous)},"\n") .. "\n"
        end
        assert(#data<=16384,"Dispatch journal limit")
        assert(not exists(path .. ".previous"),"Interrupted dispatch journal replacement; restart game")
        local f=assert(io.open(path .. ".tmp","w"))
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Journal close failed")
        local had=exists(path)
        if had then assert(os.rename(path,path .. ".previous"),"Cannot preserve dispatch recovery") end
        if not os.rename(path .. ".tmp",path) then
            if had then os.rename(path .. ".previous",path) end
            error("Cannot install dispatch recovery")
        end
        if had then assert(os.remove(path .. ".previous"),"Cannot retire dispatch recovery") end
    end
    local function source(s,foreign_rgb_readonly)
        validate(s); assert(s.phase=="owned","Unverified order handoff; restart without saving")
        local owner=find(s.owner); if not owner then return nil,"owner retired" end
        local slot=call("owner GetSlotInstance",function() return object(owner):GetSlotInstance({TagName=fname(SKIN)}) end)
        if not a.live(slot) or name(slot)~=s.slot or asset(call("slot GetCustomizationPartPrimaryAssetId",function() return object(slot):GetCustomizationPartPrimaryAssetId() end))~=s.part then return nil,"slot/part replaced" end
        local values=a.values(call("slot GetFragmentInstances",function() return object(slot):GetFragmentInstances() end)); assert(#values==4,"Source bundle count changed")
        local canonical,indices={},{}
        for i,f in ipairs(values) do
            local n=name(f); local found
            for j,id in ipairs(s.ids) do if id==n then found=j; break end end
            if not found then return nil,"fragment set replaced; replacement untouched" end
            assert(not canonical[found],"Source alias"); canonical[found]=object(f); indices[i]=found
            assert(name(call("fragment owning instance",function() return object(f):GetOwningCustomizationInstance() end))==s.owner
                and name(call("fragment owning slot",function() return object(f):GetOwningCustomizationSlot() end))==s.slot,
                "Source fragment ownership changed")
        end
        local order=table.concat(indices,",")
        assert(order==s.order,"Unexpected fragment order")
        local _,_,description=call("bundle read/ownership verification",function() return bundles.read(canonical,{slot=SKIN}) end)
        local target=s.bundle:gsub("MaterialScalar/Enable Tinting/" .. OUTFIT .. "/",
            "MaterialScalar/Enable Tinting/" .. assert(codec.parse(s.bundle)).signature:match("MaterialColor/Skin Coloration/([^/]+)/") .. "/")
        assert(codec.same(description,s.bundle) or codec.same(description,target),"Foreign source target/companion change")
        assert(swap_signature(canonical[4])==s.swap,"Swap target changed")
        assert(foreign_rgb_readonly or same(color(canonical[2]),s.chosen)
            or same(color(canonical[2]),s.previous) or same(color(canonical[2]),codec.parse(s.bundle).originals[2]),"Foreign source RGB")
        return {owner=owner,slot=object(slot),values=canonical,order=order,expanded=codec.same(description,target),description=description}
    end
    local function tags(s,restore)
        local out={}
        local names=restore and OUTFIT or assert(codec.parse(s.bundle)).signature:match("MaterialColor/Skin Coloration/([^/]+)/")
        for tag in names:gmatch("[^,]+") do out[#out+1]={TagName=fname(tag)} end
        return out
    end
    local function copy_state(s)
        return {owner=s.owner,slot=s.slot,part=s.part,bundle=s.bundle,swap=s.swap,
            phase=s.phase,order=s.order,ids={s.ids[1],s.ids[2],s.ids[3],s.ids[4]},original_order=s.original_order,
            original_expanded=s.original_expanded,chosen=copy_rgb(s.chosen),previous=copy_rgb(s.previous)}
    end
    local function commit(s)
        local ok,err=pcall(function() call("durable handoff persist",function() persist(s) end) end)
        if not ok then self.hold=true; self.blocked=tostring(err); error(err,0) end
        self.pending=s
    end
    local function role_order(order)
        local roles={"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}
        local names={}; for i in order:gmatch("%d") do names[#names+1]=roles[tonumber(i)] end
        return table.concat(names,",")
    end
    -- This is the ONLY replacement-adoption boundary: the synchronous return
    -- of our own journaled array setter. UI/Refresh/recovery lookups never adopt.
    local function set_order(desired)
        local s=assert(self.pending)
        assert(desired==REORDERED or desired==s.original_order,"Unowned order destination")
        local c=assert(call("order source readback",function() return source(s) end),"Order source unavailable")
        local view=copy_state(s); view.bundle=c.description
        local before=inspector.inspect(call("before order GetFragmentInstances",function()
            return object(c.slot):GetFragmentInstances()
        end),view,"BEFORE",role_order(s.order))
        assert(before.verified and before.original_ids and before.order_match,"Pre-setter evidence mismatch")
        local intent=copy_state(s)
        intent.phase=desired=="1,4,2,3" and "reorder_pending" or "restore_order_pending"
        commit(intent) -- durable in-flight phase BEFORE native call
        local ok,err=pcall(function()
            local ordered={}
            for i in desired:gmatch("%d") do ordered[#ordered+1]=c.values[tonumber(i)] end
            call(desired=="1,4,2,3" and "test SetFragmentInstances" or "restore SetFragmentInstances",function()
                object(c.slot):SetFragmentInstances(ordered)
            end)
            -- Re-resolve source owner/slot/part, not retired fragment wrappers.
            local owner=assert(find(s.owner),"Owner unavailable after order setter")
            local slot=call("handoff GetSlotInstance",function()
                return object(owner):GetSlotInstance({TagName=fname(SKIN)})
            end)
            assert(name(slot)==s.slot and asset(call("handoff part readback",function()
                return object(slot):GetCustomizationPartPrimaryAssetId()
            end))==s.part,"Handoff source changed")
            local after=inspector.inspect(call("after order GetFragmentInstances",function()
                return object(slot):GetFragmentInstances()
            end),view,"AFTER",role_order(desired))
            assert(after.verified and after.order_match,"Returned fragments failed verified handoff")
            local next_state=copy_state(s); next_state.phase="owned"; next_state.order=desired
            for _,row in ipairs(after.rows) do next_state.ids[row.role]=row.id end
            commit(next_state) -- save NEW identities before RGB/target/refresh
            assert(call("promoted source readback",function() return source(next_state) end),
                "Source changed after verified handoff")
            log("HANDOFF VERIFIED | order=" .. desired .. " | new identities journaled | pointers SKIPPED")
        end)
        if not ok then
            self.hold=true; self.blocked=tostring(err)
            log("HANDOFF HELD | " .. tostring(err) .. " | restart without saving; NO FURTHER WRITES")
            error(err,0)
        end
    end
    function self.stop(reason)
        calls=0
        runtime:cancel("zabrak-cp:command")
        runtime:cancel("zabrak-cp:context")
        runtime:cancel("zabrak-cp:exit")
        runtime:cancel("zabrak-cp:timeout")
        runtime:cancel("zabrak-cp:recovery")
        if self.busy then return false end
        local s=self.pending; if not s then return not self.blocked end
        if self.hold or s.phase~="owned" then
            log("RESTORE REFUSED | unverified/held handoff; recovery retained; restart without saving"); return false
        end
        self.busy=true
        local ok,err=pcall(function()
            local c,why=call("restore source readback",function() return source(s) end)
            assert(c,why or "Source unavailable; recovery retained")
            do
                -- Keep RGB first: SetFragmentInstances may retire wrappers.
                local original=codec.parse(s.bundle).originals[2]
                if not same(color(c.values[2]),original) then
                    log("RESTORE RGB BEGIN | " .. rgba(original))
                    call("restore SetColor",function() object(c.values[2]):SetColor(original) end)
                end
                c=assert(call("source readback",function() return source(s) end),"Source retired after RGB restore")
                assert(same(color(c.values[2]),original),"RGB restore readback failed")
                if c.expanded~=s.original_expanded then
                    log("RESTORE TARGET BEGIN | outfit")
                    call("restore scalar GameplayTags setter",function() object(c.values[3]).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags(s,not s.original_expanded) end)
                end
                c=assert(call("source readback",function() return source(s) end),"Source retired after target restore")
                assert(c.expanded==s.original_expanded,"Target restore readback failed")
                if c.order~=s.original_order then
                    log("RESTORE ORDER BEGIN | " .. role_order(s.original_order))
                    set_order(s.original_order); s=self.pending
                    c=assert(call("source readback",function() return source(s) end),"Source retired after order restore")
                    assert(c.order==s.original_order,"Order restore readback failed")
                end
                call("owner RefreshCustomization",function() object(c.owner):RefreshCustomization() end)
                c=assert(call("source readback",function() return source(s) end),"Source retired after restore refresh")
                assert(c.order==s.original_order and c.expanded==s.original_expanded and same(color(c.values[2]),original),"Restore refresh mismatch")
            end
            commit(nil); self.blocked=nil
        end)
        self.busy=false
        if not ok then self.blocked=tostring(err); log("RESTORE FAILED | " .. self.blocked .. " | recovery retained; DO NOT SAVE")
        else log("RESTORED | " .. tostring(reason) .. " | no MID/asset/save writes") end
        return ok
    end
    local function capture(c,chosen)
        assert(c.profile and c.profile.slot==SKIN,"Not selected Zabrak skin")
        local owner=object(c.owner); local slot=object(c.source_slot)
        local values=a.values(call("CP capture GetFragmentInstances",function() return slot:GetFragmentInstances() end))
        assert(#values==4,"Unsupported Zabrak fragment count")
        local canonical,ids,indices={},{},{}
        local classes={"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}
        for i,f in ipairs(values) do
            local cls=name(call("CP capture GetClass",function() return object(f):GetClass() end))
            local role
            for j,suffix in ipairs(classes) do
                if cls=="Class /Script/BitReactorCore.CustomizationFragmentInstance" .. suffix then role=j end
            end
            assert(role and not canonical[role],"Unsupported/duplicate Zabrak role")
            canonical[role]=object(f); ids[role]=name(f); indices[i]=role
        end
        local order=table.concat(indices,",")
        assert(ORDERS[order],"Unsupported initial Zabrak order: " .. order)
        local _,_,description=call("CP capture canonical bundle",function() return bundles.read(canonical,{slot=SKIN}) end)
        local parsed=assert(codec.parse(description))
        local meshes=assert(parsed.signature:match("MaterialColor/Skin Coloration/([^/]+)/"))
        local normalized,count=description:gsub("MaterialScalar/Enable Tinting/" .. meshes .. "/",
            "MaterialScalar/Enable Tinting/" .. OUTFIT .. "/")
        assert(count<=1 and codec.zabrak_face_enable({slot=SKIN,bundle=normalized}),"Unsupported Zabrak targets")
        local swap,swap_description=swap_signature(canonical[4])
        local s={owner=name(owner),slot=name(slot),part=asset(call("CP capture part",function()
                return slot:GetCustomizationPartPrimaryAssetId()
            end)),bundle=normalized,swap=swap,phase="owned",order=order,ids=ids,
            original_order=order,original_expanded=count==1,chosen=copy_rgb(chosen),previous=copy_rgb(parsed.originals[2])}
        -- One bounded, read-only opening diagnostic, including refused layouts.
        -- Never inspect replacement material pointers, even for troubleshooting.
        log("SWAP TARGET | part=" .. s.part .. " | order=" .. order
            .. " | observed=" .. swap_description:gsub("[%c]","?")
            .. " | expected=Skin Coloration|" .. meshes .. "|MI_Head"
            .. (s.part=="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_1B0" and " (or exact MI_Head0)" or "")
            .. " | material pointers SKIPPED")
        validate(s)
        local current=assert(source(s),"CP source changed before capture")
        assert(same(color(current.values[2]),parsed.originals[2]),"CP capture RGB changed")
        return s
    end
    function self.read(silent)
        local s=assert(self.pending,"No CP source ownership")
        assert(not self.hold,"CP handoff held; restart without saving")
        calls=0; quiet=silent==true
        local result=pack(pcall(function()
            local c,why=source(s)
            if c then
                assert(c.order==REORDERED and c.expanded and same(color(c.values[2]),s.chosen),
                    "Owned CP color/correction changed")
            end
            return c,why
        end)); quiet=false
        if not result[1] then error(result[2],0) end
        return unpack_values(result,2,result.n)
    end
    local update_logged=false
    function self.update(chosen)
        if self.busy or self.blocked or not self.pending then return false end
        calls=0; self.busy=true
        local ok,err=pcall(function()
            chosen=copy_rgb(chosen)
            local s=self.pending
            local c=assert(timed("zupdate.source_before",source,s),"CP source replaced")
            assert(same(color(c.values[2]),s.chosen),"CP color changed before update")
            assert(c.order==REORDERED and c.expanded,"CP source correction changed")
            local next_state=copy_state(s)
            next_state.previous=copy_rgb(color(c.values[2])); next_state.chosen=chosen
            timed("zupdate.journal",commit,next_state) -- both acceptable RGBs BEFORE native setter
            c=assert(timed("zupdate.source_after_journal",source,next_state),"CP source changed before RGB update")
            timed("zupdate.write_color",call,"CP SetColor",function() object(c.values[2]):SetColor(chosen) end)
            c=assert(timed("zupdate.source_after_write",source,next_state),"CP source replaced after RGB update")
            assert(same(color(c.values[2]),chosen),"CP RGB update readback failed")
            timed("zupdate.refresh",call,"owner RefreshCustomization",function() object(c.owner):RefreshCustomization() end)
            c=assert(timed("zupdate.source_after_refresh",source,next_state),"CP refresh replaced source")
            assert(c.expanded and c.order==REORDERED and same(color(c.values[2]),chosen),"CP refresh readback failed")
            -- One line per picker session; failures and Apply still log values.
            if not update_logged then log("RGB VERIFIED | first update | " .. rgba(chosen)); update_logged=true end
        end)
        self.busy=false
        if not ok then self.blocked=tostring(err); log("UPDATE FAILED | " .. self.blocked .. " | recovery retained") end
        return ok
    end
    function self.begin(c,chosen)
        update_logged=false
        calls=0
        if self.pending or self.blocked or self.busy then return false end
        self.busy=true
        local ok,err=pcall(function()
            local s=capture(c,chosen)
            commit(s)
            if s.order~=REORDERED then set_order(REORDERED) end
            s=self.pending
            local current=assert(source(s),"CP source replaced after handoff")
            if not current.expanded then
                call("CP scalar target expansion",function()
                    object(current.values[3]).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags(s,false)
                end)
            end
            current=assert(source(s),"CP scalar setter replaced source")
            assert(current.expanded,"CP target expansion readback failed")
        end)
        self.busy=false
        if ok then ok=self.update(chosen)
        else
            if self.pending or self.hold then self.blocked=tostring(err) end
            log("OPEN FAILED | " .. tostring(err))
        end
        if not ok and self.pending and not self.hold then self.stop("opening rollback") end
        return ok
    end
    -- Clear a retired source only after a live lookup proves it is not our set.
    -- Never recolor/restore/adopt a stock edit or another race's replacement.
    -- Hub editor exit: the applied source (RGB, order, targets) stays for the
    -- game to commit. Only an owned source that still holds the applied RGB.
    function self.keep(reason)
        if self.busy or self.hold or self.blocked or not self.pending or self.pending.phase~="owned" then return false end
        calls=0
        local ok,err=pcall(function()
            local s=self.pending
            local c=assert(call("keep source readback",function() return source(s) end),"Source unavailable")
            assert(same(color(c.values[2]),s.chosen),"Source no longer holds the applied color")
            commit(nil)
            log("KEPT | hub editor; applied source left on the character | " .. tostring(reason))
        end)
        if not ok then log("KEEP REFUSED | " .. tostring(err)) end
        return ok
    end
    function self.release_replaced(reason)
        if self.busy or self.hold or self.blocked or not self.pending or self.pending.phase~="owned" then return false end
        calls=0
        local ok,err=pcall(function()
            local s=self.pending; local owner=assert(find(s.owner),"Cannot prove source retired")
            local slot=call("retirement GetSlotInstance",function()
                return object(owner):GetSlotInstance({TagName=fname(SKIN)})
            end)
            local replaced=not a.live(a.unwrap(slot))
            if not replaced then
                replaced=name(slot)~=s.slot or asset(object(slot):GetCustomizationPartPrimaryAssetId())~=s.part
                if not replaced then
                    local values=a.values(object(slot):GetFragmentInstances())
                    assert(#values<=16,"Retirement fragment count bound")
                    local ids={}; for _,f in ipairs(values) do
                        local id=name(f); assert(not ids[id],"Retirement alias"); ids[id]=true
                    end
                    for _,id in ipairs(s.ids) do if not ids[id] then replaced=true end end
                    if not replaced then
                        -- Read-only exception solely to release a later native
                        -- RGB edit; it never authorizes any setter or adoption.
                        local c=assert(source(s,true),"Cannot verify superseded source")
                        replaced=not same(color(c.values[2]),s.chosen)
                    end
                end
            end
            assert(replaced,"Original source still installed")
            commit(nil); self.blocked=nil
            log("RELEASED | replacement left untouched | " .. tostring(reason))
        end)
        if not ok then log("RELEASE REFUSED | " .. tostring(err)) end
        return ok
    end
    -- Bootstrap process-gates this independent per-zone journal before loading.
    function self.start()
        local handled=false
        local ok,err=pcall(function()
            assert(not exists(path .. ".previous"),"Interrupted CP source journal; restart without saving")
            local f,why,code=io.open(path,"r")
            if not f then assert(code==2,"Journal unreadable: " .. tostring(why)); return end
            local data=f:read(16385) or ""; assert(f:close()~=false,"Journal close failed"); data=data:gsub("\r\n","\n")
            if data=="" then return end
            handled=true
            assert(data:match("^zabrak%-picker%-source%-v1\n"),"Unknown CP source journal retained; restart without saving")
            assert(#data<=16384 and not exists(path .. ".previous"),"Interrupted/oversized dispatch journal")
            local rows={}; for v in data:gmatch("([^\n]*)\n") do rows[#rows+1]=v end
            assert(#rows==16 and rows[1]==VERSION and table.concat(rows,"\n") .. "\n"==data,"Malformed dispatch recovery")
            local s={owner=rows[2],slot=rows[3],part=rows[4],bundle=rows[5],swap=rows[6],phase=rows[7],order=rows[8],ids={rows[9],rows[10],rows[11],rows[12]},original_order=rows[13],original_expanded=rows[14]=="true",chosen=decode(rows[15]),previous=decode(rows[16])}
            assert(rows[14]=="true" or rows[14]=="false","Invalid baseline target flag")
            validate(s); self.pending=s
            assert(s.phase=="owned","Interrupted order handoff retained; restart without saving")
            runtime:after("zabrak-cp:recovery",25,function() self.stop("same-process recovery") end)
        end)
        if not ok then handled=true; self.hold=true; self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
        return handled
    end
    return self
end
return M
