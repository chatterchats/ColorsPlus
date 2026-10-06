-- Route Zabrak skins with material swaps through source-owned transactions.
-- Other slots retain the existing editor backend. No native refs across jobs.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
function M.wrap(runtime,a,path,base)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local engine=assert(loadfile(directory .. "zabrak_picker_source.lua"))().new(runtime,a,path)
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a,runtime.log)
    local targets=assert(loadfile(directory .. "color_target.lua"))().new(a)
    local bundles=assert(loadfile(directory .. "color_bundle.lua"))()
    local draft,applied,binding,busy
    local context_epoch=0
    local self=setmetatable({}, {__index=function(_,k)
        if k=="pending" then return draft or engine.blocked and engine.pending or base.pending end
        if k=="applied" then return applied or base.applied end
        if k=="blocked" then return engine.blocked or base.blocked end
        if k=="busy" then return busy or engine.busy or base.busy end
        if k=="source_owned" then return engine.pending or engine.blocked end
        return base[k]
    end})
    local function log(s) runtime.log("ZABRAK CP | " .. s) end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Zabrak CP object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function asset(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
    local function same(x,y)
        for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>.00001 then return false end end
        return true
    end
    local function find(id)
        local v=(a.find or StaticFindObject)(assert(id:match("^[^ ]+ (.+)$")))
        assert(a.live(a.unwrap(v)) and name(v)==id,"Recorded CP object retired"); return object(v)
    end
    local function selected_zabrak(c)
        return c.profile and c.profile.slot==SKIN
            and asset(c.part.AssetId):match("^CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_[%w_]+$")~=nil
    end
    local function check_source()
        local c=assert(engine.read(true),"Zabrak source replaced")
        assert(binding,"Missing creator binding")
        targets.mesh(c.owner,binding.profile)
        local vm=find(binding.vm)
        assert(a.text(vm.SlotTag.TagName)==SKIN
            and asset(object(vm.EquippedCustomizationPartViewModel).AssetId)==engine.pending.part,"Recorded skin VM changed")
        local values=a.values(vm:GetFragments()); assert(#values==4,"Skin VM fragment count changed")
        local actual={}; for _,f in ipairs(values) do actual[name(f)]=true end
        for _,id in ipairs(engine.pending.ids) do assert(actual[id],"Skin VM no longer follows current source") end
        return c
    end
    local function clear_visit()
        runtime:cancel("zabrak-cp:watch"); runtime:cancel("zabrak-cp:context")
        runtime:cancel("zabrak-cp:exit"); runtime:cancel("zabrak-cp:draft-timeout")
        if draft then draft.live=false end
        draft=nil; applied=nil; binding=nil
    end
    local function watch()
        runtime:after("zabrak-cp:watch",250,function()
            if not engine.pending or busy or engine.blocked then return end
            local ok,err=pcall(function()
                check_source()
                if lifetime.active(binding.creator) then binding.gaps=0
                else binding.gaps=(binding.gaps or 0)+1; assert(binding.gaps<=2,"Creator visit ended") end
            end)
            if not ok then
                if engine.release_replaced("watch: " .. tostring(err)) then clear_visit()
                else self.restore("creator/source changed: " .. tostring(err)) end
                return
            end
            watch()
        end)
    end
    function self.begin_live()
        if self.blocked or self.pending or self.busy then return nil end
        local read,c=pcall(base.read_context)
        if not read or not selected_zabrak(c) then return base.begin_live() end
        -- read_context has already checked the live source, roles, companions
        -- and targets. The asset name alone does not imply a MaterialSwap:
        -- tester Skin Tone 1 (Hum_Zabrak_0A0) contains only tags/color/scalar.
        -- Use the regular validated bundle path when no swap needs ordering.
        -- Swap bundles still pass the engine's exact four-role/order/target
        -- checks below; never retry another backend after a failed mutation.
        local description=bundles.parse(c.profile.bundle)
        if not description then log("OPEN REFUSED | missing verified Zabrak bundle"); return nil end
        local count,swaps=0,0
        for row in description.signature:gmatch("[^;]+") do
            count=count+1
            if row=="MaterialSwap" then swaps=swaps+1 end
        end
        log("ROUTE | backend=" .. (swaps==0 and "regular" or "source-swap")
            .. " | fragments=" .. count .. " | swaps=" .. swaps .. " | part=" .. asset(c.part.AssetId)
            .. " | layout=" .. description.signature)
        if swaps==0 then return base.begin_live() end
        if base.applied then log("OPEN REFUSED | another zone owns this worker"); return nil end
        busy=true
        local session
        local ok,err=pcall(function()
            if runtime.skin_enable then assert(runtime.skin_enable.stop("Zabrak source picker"),"Restore display probe first") end
            local creator=lifetime.bind(c.page)
            if applied then
                check_source()
                assert(name(c.owner)==applied.owner and name(c.slot)==applied.vm
                    and lifetime.belongs(binding.creator,c.page),"Applied Zabrak context changed")
                assert(lifetime.active(binding.creator),"Creator visit ended")
            else
                binding={creator=creator,vm=name(c.slot),profile=c.profile,gaps=0}
            end
            local chosen=applied and applied.chosen or c.original
            session={live=true,test_color=copy(chosen),previous=copy(chosen),vm=name(c.slot),
                page=c.page,owner=name(c.owner),creator=creator,preview_policy="skin"}
            draft=session -- own cleanup if opening fails after native mutation
            if applied then assert(engine.update(chosen),"Applied source draft failed")
            else assert(engine.begin(c,chosen),"Source picker opening failed") end
            check_source()
            session.perf_target={backend="source-swap",part=engine.pending.part}
            watch()
            log("OPEN | verified source RGB; no MID writes; no draft timeout")
        end)
        busy=false
        if not ok then
            log("OPEN FAILED | " .. tostring(err))
            self.restore("failed opening rollback")
            return nil
        end
        return session
    end
    local function check_selected(s)
        assert(s==draft and s.live and not self.blocked,"Draft ended/blocked")
        local epoch=context_epoch
        assert(lifetime.page_active(binding.creator,s.page),"Selected creator page changed")
        local c
        if s.selected_context and type(base.read_selected_context)=="function" then
            c=timed("zupdate.context_bound",base.read_selected_context,s.selected_context)
        else c=timed("zupdate.context_discover",base.read_context) end
        assert(c.page==s.page and name(c.slot)==s.vm and name(c.owner)==s.owner
            and selected_zabrak(c),"Selected skin page changed")
        local route=s.selected_context
        if not route and type(base.bind_selected_context)=="function" then route=base.bind_selected_context(c) end
        assert(epoch==context_epoch,"Context changed during selected validation")
        s.selected_context=route -- scalar identities only; scoped to this draft
    end
    function self.check_live(s)
        if s~=draft then return base.check_live(s) end
        return pcall(function()
            timed("zupdate.source_guard",check_source)
            check_selected(s)
        end)
    end
    function self.update_live(s,chosen)
        if s~=draft then return base.update_live(s,chosen) end
        local healthy,why=timed("zupdate.validate",self.check_live,s)
        if not healthy then log("UPDATE REFUSED | " .. tostring(why)); self.cancel_live("draft context changed"); return false end
        busy=true
        local ok=timed("zupdate.core",engine.update,chosen)
        if ok then s.test_color=copy(chosen) end
        busy=false
        if not ok then self.restore("RGB failure rollback") end
        return ok,ok -- successful updates include full live-context validation
    end
    function self.apply_live(s)
        if s~=draft then return base.apply_live(s) end
        local healthy,why=self.check_live(s)
        if not healthy then log("APPLY REFUSED | " .. tostring(why)); return false end
        check_source()
        if not same(engine.pending.chosen,s.test_color) then return false end
        applied={owner=s.owner,vm=s.vm,chosen=copy(s.test_color)}
        s.live=false; draft=nil
        runtime:cancel("zabrak-cp:draft-timeout")
        watch()
        log("APPLIED | source RGB/order/enable targets retained for creator visit; no save calls")
        return true
    end
    function self.cancel_live(reason)
        if not draft then return base.cancel_live and base.cancel_live(reason) or base.restore(reason) end
        if busy then return false end
        local s=draft
        runtime:cancel("zabrak-cp:draft-timeout")
        busy=true
        local ok
        if applied then ok=engine.update(applied.chosen)
        else ok=engine.stop(reason or "picker Cancel") end
        busy=false
        if ok then
            s.live=false; draft=nil
            if applied then watch() else clear_visit() end
            log("CANCELLED | " .. tostring(reason) .. " | prior applied RGB or original source restored")
        end
        return ok
    end
    function self.restore(reason)
        if busy then return false end
        if engine.pending or engine.blocked then
            busy=true
            local ok=engine.stop(reason or "Restore")
            busy=false
            if not ok then return false end
            clear_visit()
        end
        if not engine.pending and not engine.blocked and (draft or binding) then clear_visit() end
        return base.restore(reason)
    end
    function self.context_changed(reason,identity)
        -- Invalidate even when synchronous source writes suppress restoration.
        -- The next check rediscovers; no cached route crosses a native event.
        context_epoch=context_epoch+1
        if draft then draft.selected_context=nil end
        if busy then return end
        base.context_changed(reason,identity)
        if not engine.pending or engine.blocked then return end
        if reason=="creator closed" then
            if identity and binding and identity~=binding.creator.master then return end
            local expected=binding
            runtime:after("zabrak-cp:exit",1,function()
                if binding==expected then self.restore(reason) end
            end)
            return
        end
        local s,expected=draft,binding
        runtime:after("zabrak-cp:context",1,function()
            -- A dispatched callback may outlive Cancel/reopen or Apply. Never
            -- let an event from that draft operate on its replacement.
            if binding~=expected or draft~=s or not engine.pending or busy then return end
            local ok,err=pcall(check_source)
            if not ok then
                if engine.release_replaced("native context: " .. tostring(err)) then clear_visit()
                else self.restore("context verification failed") end
                return
            end
            -- Covering a hovered stock tile with CP emits ResetPreviewedPart.
            -- A reset alone is not a slot change: retain the draft only after
            -- fresh source AND selected-context validation, without a grace
            -- period or repaint. Applied RGB already remains in source.
            if s and draft==s then
                if reason=="UpdateCurrentCustomizationSlotVM" or reason=="ResetPreviewedPart" then
                    -- check_source above already ran in this callback; do not
                    -- repeat it through check_live or cache it across ticks.
                    local healthy,why=pcall(check_selected,s)
                    if not healthy then self.cancel_live(reason .. ": " .. tostring(why))
                    elseif reason=="ResetPreviewedPart" then log("HOVER RESET | kept verified draft") end
                else self.cancel_live(reason) end
            end
        end)
    end
    function self.start() base.start(); engine.start() end
    for _,key in ipairs({"apply","apply_rgb","cycle_rgb"}) do
        self[key]=function(...)
            if engine.pending or engine.blocked then log("DIAGNOSTIC REFUSED | Restore source CP first"); return false end
            return base[key](...)
        end
    end
    return self
end
return M
