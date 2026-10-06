-- Isolated target tests: 15-second preview or opt-in 120-second native-save window.
-- No RGB, MID, preset, automatic reapplication, or save API writes.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local PART="CustomizationPartDefinition:CPD_H_SkinTone_Human_0B1"
local RACE="br.Customization.Part.Character.Race.0B"
local PREFIX="Class /Script/BitReactorCore.CustomizationFragmentInstance"
function M.new(runtime,a,path)
    local self={pending=nil,blocked=nil,busy=false}
    local dispatch
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local bundle=assert(loadfile(directory .. "color_fragments.lua"))()
    local function log(s) runtime.log("SKIN TARGET PROBE | " .. s) end
    local fragments=bundle.new(a,log)
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Target probe object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function fname(v) local f=FName(v); assert(a.text(f)==v,"FName mismatch"); return f end
    local function find(full)
        local found=a.unwrap(StaticFindObject(assert(full:match("^[^ ]+ (.+)$"))))
        if a.live(found) then assert(name(found)==full,"Lookup identity mismatch"); return found end
        local n=0
        for _,v in pairs(FindAllOf(full:match("^([^ ]+) ")) or {}) do
            n=n+1; assert(n<=4096,"Source lookup bound")
            if a.live(v) and name(v)==full then assert(not found or not a.live(found),"Ambiguous source"); found=v end
        end
        return a.live(found) and found or nil
    end
    local function validate(s)
        assert(s.owner:match("^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"),"Untrusted source owner")
        local p=s.owner:match("^[^ ]+ (.+)$") .. "."
        for key,cls in pairs({slot="CustomizationFragmentInstanceSlot",scalar="CustomizationFragmentInstanceMaterialScalar"}) do
            local prefix=cls .. " " .. p
            assert(s[key]:sub(1,#prefix)==prefix and s[key]:sub(#prefix+1):match("^[%w_.]+$"),"Untrusted source child")
        end
    end
    local function exists(p)
        local f,err,code=io.open(p,"r")
        if not f then assert(code==2,"Journal read failed: " .. tostring(err)); return false end
        assert(f:close()~=false,"Journal close failed"); return true
    end
    local function persist(s)
        local data=""
        if s then validate(s); data=table.concat({"skin-target-v1",s.owner,s.slot,s.scalar},"\n") .. "\n" end
        assert(not exists(path .. ".previous"),"Interrupted target journal replacement; restart game")
        local f=assert(io.open(path .. ".tmp","w"))
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Journal close failed")
        local had=exists(path)
        if had then assert(os.rename(path,path .. ".previous"),"Cannot preserve target journal") end
        if not os.rename(path .. ".tmp",path) then
            if had then os.rename(path .. ".previous",path) end
            error("Cannot install target journal")
        end
        if had then assert(os.remove(path .. ".previous"),"Cannot retire previous target journal") end
    end
    local function write_target(f,layout,repair)
        local tags={}
        for _,v in ipairs(layout=="outfit" and {"br.Customization.Slot.Character.Outfit"} or bundle.MESHES) do
            tags[#tags+1]={TagName=fname(v)}
        end
        -- Avoid the whole inherited-struct UFunction argument. In normal use
        -- only change its tag array; parameter/material fields stay native.
        -- Recovery repairs each known original leaf, even after a partial write.
        if repair then
            log("WRITE BEGIN | parameter")
            object(f).MaterialTarget.MaterialParameterName="Enable Tinting"
            assert(a.text(object(f).MaterialTarget.MaterialParameterName)=="Enable Tinting","Parameter repair readback failed")
            log("WRITE RETURN | parameter")
            log("WRITE BEGIN | materials")
            object(f).MaterialTarget.MaterialSlotNames={"MI_Head","MI_Body","MI_Neck"}
            local values=a.values(object(f).MaterialTarget.MaterialSlotNames)
            assert(#values==3,"Material repair count mismatch")
            for i,v in ipairs(bundle.MATERIALS) do assert(a.text(values[i])==v,"Material repair readback failed") end
            log("WRITE RETURN | materials")
        end
        log("WRITE BEGIN | tags=" .. layout)
        object(f).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags
        assert(fragments.skin_target(f,"Enable Tinting",true)==layout,"Target leaf readback failed")
        log("WRITE RETURN | tags=" .. layout)
    end
    local function source(s,recovery)
        validate(s)
        local owner=object(find(s.owner))
        local slot=object(owner:GetSlotInstance({TagName=fname(SKIN)}))
        if name(slot)~=s.slot or id(slot:GetCustomizationPartPrimaryAssetId())~=PART then return nil,owner,"source replaced" end
        local values=a.values(slot:GetFragmentInstances())
        assert(#values==3,"Source bundle changed")
        for i,cls in ipairs({"GameplayTags","MaterialColor","MaterialScalar"}) do
            local v=object(values[i])
            assert(name(v:GetClass())==PREFIX .. cls
                and name(v:GetOwningCustomizationInstance())==s.owner
                and name(v:GetOwningCustomizationSlot())==s.slot,"Source companion ownership changed")
        end
        local tags=a.values(object(values[1]).GameplayTags.GameplayTags)
        assert(#tags==1,"Source race bundle changed")
        local race=a.text(tags[1].TagName)
        assert(race==RACE,"Source race changed")
        if name(values[3])~=s.scalar then return nil,owner,"scalar replaced" end
        assert(name(values[3]:GetClass())==PREFIX .. "MaterialScalar"
            and name(values[3]:GetOwningCustomizationInstance())==s.owner
            and name(values[3]:GetOwningCustomizationSlot())==s.slot,"Scalar ownership changed")
        assert(object(values[3]).Value==1,"Source scalar value changed")
        fragments.skin_target(values[2],"Skin Coloration")
        -- Recovery validates identity and untouched companions, but cannot
        -- require the scalar target fields it is about to repair to be healthy.
        local layout=recovery and "repair" or fragments.skin_target(values[3],"Enable Tinting",true)
        return object(values[3]),owner,layout,object(values[2])
    end
    local function rgb(f)
        local c=object(f):GetColor(); local out={}
        for _,k in ipairs({"R","G","B","A"}) do
            local n=a.prop(c,k); assert(type(n)=="number" and n==n and n>=0 and n<=1,"Invalid source RGB")
            out[#out+1]=string.format("%.9g",n)
        end
        return table.concat(out,",")
    end
    function self.stop(reason)
        if self.busy then return false end
        for _,k in ipairs({"target:command","target:timeout","target:recovery"}) do runtime:cancel(k) end
        local s=self.pending; if not s then return not self.blocked end
        self.busy=true
        local ok,err=pcall(function()
            local f,owner,layout,color=source(s,true)
            if f then
                local original_rgb=rgb(color)
                log("RESTORE SET BEGIN | target=outfit")
                write_target(f,"outfit",true)
                local checked,_,actual=source(s); assert(checked and actual=="outfit","Target restore readback failed")
                object(owner):RefreshCustomization()
                local checked,_,actual,after=source(s)
                assert(checked and actual=="outfit" and rgb(after)==original_rgb,"Target refresh restore failed")
            else log("RETIRED | " .. layout .. " | replacement untouched") end
            persist(nil); self.pending=nil; self.blocked=nil
        end)
        self.busy=false
        if not ok then self.blocked=tostring(err); log("RESTORE FAILED | " .. self.blocked .. " | recovery retained; do not save")
        else log("RESTORED | " .. tostring(reason) .. " | source RGB untouched") end
        return ok
    end
    function self.context_changed(reason)
        if self.busy then return end
        if self.pending and self.pending.save_test then
            -- Observe only: no refresh, reapply, or restoration inside native Save.
            log("SAVE CONTEXT | " .. tostring(reason) .. " | no writes; deadline remains active")
            return
        end
        self.stop(reason)
    end
    function self.check()
        local ok,err=pcall(function()
            assert(not self.busy and not self.blocked,"Target recovery incomplete")
            local tint=assert(runtime.tint,"Tint unavailable")
            assert(not tint.pending and not tint.applied and not tint.blocked
                and not (runtime.picker and runtime.picker.active),"Close CP and restore Apply before checking")
            local c=tint.read_context()
            assert(c.profile and c.profile.slot==SKIN and id(c.part.AssetId)==PART,"Select the tested Skin Tone 5 character")
            local _,values=fragments.read(c.source_slot:GetFragmentInstances(),{slot=SKIN})
            local s={owner=name(c.owner),slot=name(c.source_slot),scalar=name(values[3])}
            local f,_,layout,color=source(s); assert(f,"Check source replaced")
            local previous=self.pending
            local same=previous and previous.owner==s.owner and previous.slot==s.slot and previous.scalar==s.scalar
            log("SAVE CHECK | target=" .. layout .. " | rgb=" .. rgb(color)
                .. " | source=" .. s.scalar .. " | same_as_armed=" .. tostring(same==true)
                .. " | armed=" .. tostring(previous~=nil) .. " | read-only; not proof of disk serialization")
        end)
        if not ok then log("SAVE CHECK FAILED | " .. tostring(err)) end
        return ok
    end
    function self.begin(save_test)
        if dispatch and (dispatch.pending or dispatch.blocked) then log("Start refused; stop colors_zabrak first"); return false end
        if self.pending or self.blocked or self.busy then log("Start refused; stop/recover first"); return false end
        local ok,err=pcall(function()
            local tint=assert(runtime.tint,"Tint unavailable")
            assert(not tint.pending and not tint.applied and not tint.blocked and not (runtime.picker and runtime.picker.active),"Close CP and Restore any Apply first")
            for _,key in ipairs({"skin_enable","eye_preview"}) do
                local other=runtime[key]; assert(not other or not (other.pending or other.blocked),"Stop other preview first")
            end
            assert(not (runtime.stock_call_trace and runtime.stock_call_trace.window),"Stop stock capture first")
            local c=tint.read_context()
            assert(c.profile and c.profile.slot==SKIN and c.profile.skin_scalar=="outfit" and id(c.part.AssetId)==PART,"Select Skin Tone 5 with original Outfit target")
            local _,values=fragments.read(c.source_slot:GetFragmentInstances(),c.profile)
            local s={owner=name(c.owner),slot=name(c.source_slot),scalar=name(values[3]),save_test=save_test==true}
            local f,owner,layout,color=source(s); assert(f and layout=="outfit","Source target changed")
            local original_rgb=rgb(color)
            self.pending=s
            persist(s) -- exact original/test layouts are fixed by this versioned record
            runtime:after("target:timeout",s.save_test and 120000 or 15000,function()
                if self.pending==s then self.stop(s.save_test and "save-test 120-second deadline" or "15-second timeout") end
            end)
            self.busy=true
            log("SET BEGIN | target=meshes | source=" .. s.scalar .. " | rgb=" .. original_rgb)
            write_target(f,"meshes",false)
            local checked,_,actual=source(s); assert(checked and actual=="meshes","Test target readback failed")
            object(owner):RefreshCustomization()
            local confirmed,_,installed,after=source(s)
            assert(confirmed and installed=="meshes" and rgb(after)==original_rgb,"Refresh changed target/source RGB")
            self.busy=false
            if s.save_test then
                log("SAVE ARMED | 120 seconds | target=meshes | rgb=" .. original_rgb
                    .. " | native Save/reopen now, then colors_target check; no reapplication")
            else
                log("ACTIVE | 15 seconds | target=meshes | scalar=1 | RGB unchanged | no direct MID writes; DO NOT SAVE")
            end
        end)
        self.busy=false
        if not ok then log("START FAILED | " .. tostring(err)); if self.pending then self.stop("start rollback") end end
        return ok
    end
    function self.start()
        local ok,err=pcall(function()
            assert(not exists(path .. ".previous"),"Interrupted target journal replacement")
            local f,why,code=io.open(path,"r")
            if not f then assert(code==2,"Journal unreadable: " .. tostring(why)); return end
            local data=f:read(8193) or ""; f:close(); data=data:gsub("\r\n","\n")
            if data=="" then return end
            assert(#data<=8192,"Target journal oversized")
            local owner,slot,scalar=data:match("^skin%-target%-v1\n([^\n]+)\n([^\n]+)\n([^\n]+)\n$")
            local s={owner=owner,slot=slot,scalar=scalar}; validate(s); self.pending=s
            runtime:after("target:recovery",25,function() self.stop("same-process recovery") end)
        end)
        if not ok then self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then return end
        runtime:console("colors_target",function(_,args)
            args=args or {}; local action=args[1]
            if #args~=1 or (action~="start" and action~="stop" and action~="save" and action~="check") then
                log("Usage: colors_target [start|stop|save|check]"); return
            end
            runtime:after("target:command",1,function()
                if action=="check" then self.check()
                elseif action=="stop" then
                    if dispatch and (dispatch.pending or dispatch.blocked) then dispatch.stop("console")
                    else self.stop("console") end
                else self.begin(action=="save") end
            end)
        end)
        log("CONSOLE READY | colors_target start/stop/save/check | isolated target and save probes")
    end
    -- Share the already process-gated source journal and exclusion boundary.
    -- Keep human console semantics; dispatch recovery routes by record version.
    dispatch=assert(loadfile(directory .. "zabrak_dispatch_probe.lua"))().new(runtime,a,path)
    local router={dispatch=dispatch}
    setmetatable(router,{__index=function(_,k)
        if k=="pending" or k=="blocked" or k=="busy" then return self[k] or dispatch[k] end
        return self[k]
    end})
    function router.start() if not dispatch.start() then self.start() end end
    function router.stop(reason) return self.stop(reason) and dispatch.stop(reason) end
    function router.context_changed(reason)
        self.context_changed(reason); dispatch.context_changed(reason)
    end
    function router.attach() self.attach(); dispatch.attach() end
    return router
end
return M
