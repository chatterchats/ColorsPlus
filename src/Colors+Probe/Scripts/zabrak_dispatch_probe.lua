-- Traced, reversible source-dispatch experiment. No MID/asset/save writes
-- or reapplication. Recovery uses identities and targets, NEVER swap pointers.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local OUTFIT="br.Customization.Slot.Character.Outfit"
local VERSION="zabrak-dispatch-v3"
local ORDER={1,4,2,3}
local ORANGE={R=1,G=0.21586050011389926,B=0.014443843596092545,A=1}
function M.new(runtime,a,path)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local codec=assert(loadfile(directory .. "color_bundle.lua"))()
    local bundles=codec.new(a)
    local diagnostics=assert(loadfile(directory .. "zabrak_capture.lua"))().new(runtime,a)
    local self={pending=nil,blocked=nil,busy=false,hold=false}
    local function log(s) runtime.log("ZABRAK DISPATCH | " .. s) end
    local calls=0
    local unpack_values=assert(table.unpack or unpack,"Lua unpack function unavailable")
    local function pack(...) return {n=select("#",...),...} end
    local function call(label,fn)
        calls=calls+1; assert(calls<=4096,"Dispatch trace call bound")
        local prefix="CALL TRACE | call=" .. calls .. " | "
        log(prefix .. "BEGIN | " .. label)
        local result=pack(pcall(fn))
        if not result[1] then
            log(prefix .. "ERROR | " .. label .. " | " .. tostring(result[2]))
            error(result[2],0)
        end
        log(prefix .. "RETURN | " .. label)
        return unpack_values(result,2,result.n)
    end
    local inspector=assert(loadfile(directory .. "zabrak_rebuild_inspector.lua"))().new(a,log,call,directory)
    local function object(v) v=call("source unwrap",function() return a.unwrap(v) end); assert(call("source IsValid",function() return a.live(v) end),"Source object unavailable"); return v end
    local function name(v) v=object(v); return call("source GetFullName",function() return a.name(v) end) end
    local function fname(s) local v=call("construct gameplay-tag FName",function() return FName(s) end); assert(call("FName ToString",function() return a.text(v) end)==s,"FName mismatch"); return v end
    local function asset(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function find(n)
        local v=a.unwrap(call("source StaticFindObject",function() return StaticFindObject(assert(n:match("^[^ ]+ (.+)$"))) end))
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
    local function rgba(c) return string.format("%.6f,%.6f,%.6f,%.6f",c.R,c.G,c.B,c.A) end
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
        return hex(description)
    end
    local function validate(s)
        assert(type(s.owner)=="string" and s.owner:match("^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"),"Untrusted Zabrak owner")
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
        assert(s.swap==hex("Skin Coloration|" .. mesh_tags .. "|MI_Head"),"Unsupported recovery swap target")
        assert(s.phase=="owned" or s.phase=="reorder_pending" or s.phase=="restore_order_pending","Invalid transaction phase")
        assert(s.order=="1,2,3,4" or s.order=="1,4,2,3","Invalid recovery order")
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
            data=table.concat({VERSION,s.owner,s.slot,s.part,s.bundle,s.swap,s.phase,s.order,s.ids[1],s.ids[2],s.ids[3],s.ids[4]},"\n") .. "\n"
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
    local function source(s)
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
        end
        local order=table.concat(indices,",")
        assert(order==s.order,"Unexpected fragment order")
        local _,_,description=call("bundle read/ownership verification",function() return bundles.read(canonical,{slot=SKIN}) end)
        local target=s.bundle:gsub("MaterialScalar/Enable Tinting/" .. OUTFIT .. "/",
            "MaterialScalar/Enable Tinting/" .. assert(codec.parse(s.bundle)).signature:match("MaterialColor/Skin Coloration/([^/]+)/") .. "/")
        assert(codec.same(description,s.bundle) or codec.same(description,target),"Foreign source target/companion change")
        assert(swap_signature(canonical[4])==s.swap,"Swap target changed")
        assert(same(color(canonical[2]),ORANGE) or same(color(canonical[2]),codec.parse(s.bundle).originals[2]),"Foreign source RGB")
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
            phase=s.phase,order=s.order,ids={s.ids[1],s.ids[2],s.ids[3],s.ids[4]}}
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
        runtime:cancel("zabrak:command")
        runtime:cancel("zabrak:context")
        runtime:cancel("zabrak:exit")
        runtime:cancel("zabrak:timeout")
        runtime:cancel("zabrak:recovery")
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
                if c.expanded then
                    log("RESTORE TARGET BEGIN | outfit")
                    call("restore scalar GameplayTags setter",function() object(c.values[3]).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags(s,true) end)
                end
                c=assert(call("source readback",function() return source(s) end),"Source retired after target restore")
                assert(not c.expanded,"Target restore readback failed")
                if c.order~="1,2,3,4" then
                    log("RESTORE ORDER BEGIN | tags,color,scalar,swap")
                    set_order("1,2,3,4"); s=self.pending
                    c=assert(call("source readback",function() return source(s) end),"Source retired after order restore")
                    assert(c.order=="1,2,3,4","Order restore readback failed")
                end
                call("owner RefreshCustomization",function() object(c.owner):RefreshCustomization() end)
                c=assert(call("source readback",function() return source(s) end),"Source retired after restore refresh")
                assert(c.order=="1,2,3,4" and not c.expanded and same(color(c.values[2]),original),"Restore refresh mismatch")
            end
            commit(nil); self.blocked=nil
        end)
        self.busy=false
        if not ok then self.blocked=tostring(err); log("RESTORE FAILED | " .. self.blocked .. " | recovery retained; DO NOT SAVE")
        else log("RESTORED | " .. tostring(reason) .. " | no MID/asset/save writes") end
        return ok
    end
    function self.context_changed(reason)
        if self.busy or not self.pending then return end
        local s=self.pending
        -- No source refresh or array setter inside a native UI transition hook.
        -- A later ordinary event cannot overwrite an already queued exit.
        local key=reason=="creator closed" and "zabrak:exit" or "zabrak:context"
        runtime:after(key,1,function()
            if self.pending~=s or self.busy then return end
            if reason=="creator closed" then self.stop(reason); return end
            calls=0
            local ok,c=pcall(function() return call("context source readback",function() return source(s) end) end)
            if not ok or not c then self.stop("source/context changed") end
        end)
        -- Radial navigation retains source-only test until the fixed deadline.
    end
    function self.capture() return diagnostics.capture() end
    local function capture()
        local s=assert(diagnostics.capture(),"Read-only capture failed; no writes attempted")
        s.phase="owned"; s.order="1,2,3,4"; validate(s)
        -- Only the swap target actually captured in the successful native test.
        local mesh_tags=assert(codec.parse(s.bundle)).signature:match("MaterialColor/Skin Coloration/([^/]+)/")
        assert(s.swap==hex("Skin Coloration|" .. mesh_tags .. "|MI_Head"),"Unsupported captured swap target")
        return s
    end
    function self.begin()
        calls=0
        if self.pending or self.blocked or self.busy then log("REFUSED | stop/recover first"); return false end
        local ok,err=pcall(function()
            assert(not runtime.skin_target or not (runtime.skin_target.pending or runtime.skin_target.blocked),"Stop other source test")
            assert(runtime.tint and not (runtime.tint.pending or runtime.tint.applied or runtime.tint.blocked),"Restore all CP colors first")
            assert(not (runtime.picker and runtime.picker.active),"Close CP first")
            for _,key in ipairs({"skin_enable","eye_preview"}) do
                local other=runtime[key]; assert(not other or not (other.pending or other.blocked),"Restore other display preview first")
            end
            assert(not (runtime.stock_call_trace and runtime.stock_call_trace.window),"Stop stock trace first")
            local s=capture(); local c=assert(call("source readback",function() return source(s) end),"Source changed before test")
            assert(c.order=="1,2,3,4" and not c.expanded,"Source must start in stock order/target layout")
            commit(s) -- before any native mutation
            self.busy=true
            log("ORDER SET BEGIN | tags,swap,color,scalar")
            set_order("1,4,2,3"); s=self.pending
            c=assert(call("source readback",function() return source(s) end),"Source changed after handoff")
            log("TARGET SET BEGIN | six captured mesh tags")
            call("test scalar GameplayTags setter",function() object(c.values[3]).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags(s,false) end)
            c=assert(call("source readback",function() return source(s) end),"Source changed during target setter"); assert(c.expanded,"Expanded target readback failed")
            log("RGB SET BEGIN | orange")
            call("test SetColor orange",function() object(c.values[2]):SetColor(ORANGE) end)
            c=assert(call("source readback",function() return source(s) end),"Source changed during RGB setter"); assert(same(color(c.values[2]),ORANGE),"RGB readback failed")
            log("REFRESH BEGIN | normal source RefreshCustomization; no post-refresh setters")
            call("owner RefreshCustomization",function() object(c.owner):RefreshCustomization() end)
            c=assert(call("source readback",function() return source(s) end),"Source retired after test refresh")
            assert(c.expanded and c.order=="1,4,2,3" and same(color(c.values[2]),ORANGE),"Test refresh changed source")
            runtime:after("zabrak:timeout",60000,function() if self.pending==s then self.stop("60-second timeout") end end)
            self.busy=false
            log("ACTIVE | orange | 60 seconds | source RGB/order/enable targets | NO MID WRITES / NO REAPPLY / DO NOT SAVE")
        end)
        self.busy=false
        if not ok then log("START FAILED | " .. tostring(err)); if self.pending then self.stop("start rollback") end end
        return ok
    end
    -- Returns false only when the shared journal belongs to the legacy human
    -- probe. Session classification/quarantine is performed by main first.
    function self.start()
        local handled=false
        local ok,err=pcall(function()
            local f,why,code=io.open(path,"r")
            if not f then assert(code==2,"Journal unreadable: " .. tostring(why)); return end
            local data=f:read(16385) or ""; assert(f:close()~=false,"Journal close failed"); data=data:gsub("\r\n","\n")
            if data=="" or data:match("^skin%-target%-v1\n") then return end
            handled=true
            assert(data:match("^zabrak%-dispatch%-v3\n"),"Legacy/unverified order inspection retained; restart without saving")
            assert(#data<=16384 and not exists(path .. ".previous"),"Interrupted/oversized dispatch journal")
            local rows={}; for v in data:gmatch("([^\n]*)\n") do rows[#rows+1]=v end
            assert(#rows==12 and rows[1]==VERSION and table.concat(rows,"\n") .. "\n"==data,"Malformed dispatch recovery")
            local s={owner=rows[2],slot=rows[3],part=rows[4],bundle=rows[5],swap=rows[6],phase=rows[7],order=rows[8],ids={rows[9],rows[10],rows[11],rows[12]}}
            validate(s); self.pending=s
            assert(s.phase=="owned","Interrupted order handoff retained; restart without saving")
            runtime:after("zabrak:recovery",25,function() self.stop("same-process recovery") end)
        end)
        if not ok then handled=true; self.hold=true; self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
        return handled
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then return end
        runtime:console("colors_zabrak",function(_,args)
            args=args or {}; local action=args[1]
            if #args~=1 or (action~="start" and action~="stop" and action~="capture") then log("Usage: colors_zabrak [start|stop|capture]"); return end
            runtime:after("zabrak:command",1,function()
                if action=="start" then self.begin()
                elseif action=="stop" then self.stop("console")
                else self.capture() end
            end)
        end)
        log("CONSOLE READY | colors_zabrak start/stop/capture | traced 60s source test; pointers skipped; DO NOT SAVE")
    end
    return self
end
return M
