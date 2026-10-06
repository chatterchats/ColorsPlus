-- Independent editor/preview/default journals and action namespaces per zone.
-- A single visible draft; multiple applied source edits. No shared native refs.
-- Zones are created on demand: each is a full backend stack, so building all
-- 32 at startup cost ~2,200 module loads. Zones with journals on disk (and all
-- lower zones, keeping the list contiguous) are created before start().
local M={LIMIT=32}
function M.new(runtime,factory,has_journal)
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
    local function create(i)
        local proxy=setmetatable({}, {__index=function(_,k)
            if k=="skin_enable" and active~=i then return nil end
            if k=="tint" then return workers[i] end
            return runtime[k]
        end})
        local prefix=i==1 and "" or ("zone" .. i .. ":")
        function proxy:after(key,ms,fn) return runtime:after(prefix .. key,ms,fn) end
        function proxy:cancel(key) return runtime:cancel(prefix .. key) end
        workers[i]=factory(proxy,i)
        return workers[i]
    end
    local needed=1
    for i=2,M.LIMIT do
        if has_journal and has_journal(i) then needed=i end
    end
    for i=1,needed do create(i) end
    local started=false
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
            if not chosen and #workers<M.LIMIT then
                chosen=#workers+1
                local w=create(chosen)
                if started then w.start() end
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
    function self.start() started=true; for _,w in ipairs(workers) do w.start() end end
    function self.zone_count() return #workers end
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
