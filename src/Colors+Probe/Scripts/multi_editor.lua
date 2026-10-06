-- Independent editor/preview/default journals and action namespaces per zone.
-- A single visible draft; multiple applied source edits. No shared native refs.
local M={LIMIT=32}
function M.new(runtime,factory)
    local workers,active={},1
    local self={}
    local function any(field)
        for _,w in ipairs(workers) do if w[field] then return w[field] end end
    end
    setmetatable(self,{__index=function(_,k)
        if k=="blocked" or k=="busy" or k=="pending" or k=="source_owned" then return any(k) end
        if k=="applied" then return workers[active].applied or any(k) end
        return workers[active][k]
    end})
    for i=1,M.LIMIT do
        local proxy=setmetatable({}, {__index=function(_,k)
            if k=="skin_enable" and active~=i then return nil end
            if k=="tint" then return workers[i] end
            return runtime[k]
        end})
        local prefix=i==1 and "" or ("zone" .. i .. ":")
        function proxy:after(key,ms,fn) return runtime:after(prefix .. key,ms,fn) end
        function proxy:cancel(key) return runtime:cancel(prefix .. key) end
        workers[i]=factory(proxy,i)
    end
    function self.begin_live()
        if self.blocked or self.busy or self.pending then return nil end
        local ok,result=pcall(function()
            local key=workers[active].selected_slot_identity()
            local chosen
            for i,w in ipairs(workers) do
                if w.applied and w.applied.vm==key then chosen=i; break end
            end
            if not chosen then
                for i,w in ipairs(workers) do if not w.applied then chosen=i; break end end
            end
            assert(chosen,"Too many simultaneous edited zones; save/exit or Restore first")
            active=chosen
            return workers[active].begin_live()
        end)
        if not ok then runtime.log("MULTI EDITOR | OPEN REFUSED | " .. tostring(result)); return nil end
        return result
    end
    function self.restore(reason)
        local ok=true
        -- Active draft must retire before another zone refreshes the character.
        if not workers[active].restore(reason) then return false end
        for i,w in ipairs(workers) do
            if i~=active and (w.applied or w.pending or w.blocked) then
                if not w.restore(reason) then ok=false end
            end
        end
        return ok
    end
    function self.context_changed(reason,identity)
        -- Inactive zone workers can retain scalar discovery hints. Invalidate
        -- those too, without scheduling native work or restoring their edits.
        for _,w in ipairs(workers) do
            if w.invalidate_context_lookup then w.invalidate_context_lookup() end
        end
        workers[active].context_changed(reason,identity)
        for i,w in ipairs(workers) do
            if i~=active and (w.applied or w.pending or w.blocked) then w.context_changed(reason,identity) end
        end
    end
    function self.start() for _,w in ipairs(workers) do w.start() end end
    for _,k in ipairs({"apply","apply_rgb","cycle_rgb"}) do
        self[k]=function(...)
            if self.applied or self.pending or self.blocked then
                runtime.log("MULTI EDITOR | diagnostic write refused while edits are owned"); return false
            end
            return workers[active][k](...)
        end
    end
    return self
end
return M
