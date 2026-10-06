-- One color zone: the preview engine and the steps around it, sequenced here
-- rather than through wrapper layers. Opening: temporary Default selection,
-- then the preview. Closing: the preview, then Default.
-- journal(leaf) gives this zone's recovery file paths; parts.preview replaces
-- the preview engine in tests.
local M={}
function M.new(runtime,a,journal,parts)
    parts=parts or {}
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    -- Literal file names: the packager finds player scripts by these references.
    local function load(file) return assert(loadfile(directory .. file))() end
    local preview=parts.preview or load("tint_test.lua").new(runtime,a,journal("tint_recovery.txt"))
    local selection=load("default_selection.lua").new(runtime,a,journal("default_selection_recovery.txt"),preview)
    local busy=false -- an opening is running: its native events and rollbacks are ours
    local self=setmetatable({}, {__index=function(_,k)
        if k=="pending" then return preview.pending or (not selection.held and selection.record()) end
        if k=="blocked" then return selection.blocked or preview.blocked end
        if k=="busy" then return busy or selection.busy or preview.busy end
    end})
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    -- Any preview end (Cancel, timeout, context change, failed update) returns
    -- the slot to Default unless an Apply holds the selection or our own
    -- opening is still running (it restores below once it unwinds).
    preview.after_restore=function(reason)
        if selection.record() and not busy and not selection.busy and not selection.held then
            return selection.restore(reason)
        end
        return true
    end
    function self.restore(reason)
        local ok=preview.restore(reason)
        if ok and selection.record() and not selection.held then return selection.restore(reason) end
        return ok and not selection.blocked
    end
    local function begin_live()
        if self.pending or self.blocked then return nil end
        busy=true
        local session
        local ok,err=pcall(function()
            if not selection.prepare() then session=preview.begin_live(); return end
            session=assert(preview.begin_live(),"Regular RGB preview could not start")
            session.perf_selection="Default"
            selection.opened()
        end)
        busy=false
        if not ok then
            selection.open_failed(err); self.restore("picker opening failed"); selection.open_ended()
            return nil
        end
        return session
    end
    function self.begin_live() return timed("begin.default_selection",begin_live) end
    function self.update_live(...) return preview.update_live(...) end
    function self.update_live_scoped(...) return preview.update_live_scoped(...) end
    function self.check_live(...) return preview.check_live(...) end
    function self.read_context() return preview.read_context() end
    function self.bind_selected_context(c) return preview.bind_selected_context(c) end
    function self.read_selected_context(route) return preview.read_selected_context(route) end
    function self.verify_editor_display() return preview.verify_editor_display() end
    function self.hold_selection(value) selection.hold(value) end
    function self.forget_selection() selection.forget() end
    function self.selected_slot_identity()
        return timed("context.selected_slot",selection.selected_slot_identity)
    end
    function self.inspect()
        if selection.record() or selection.blocked then selection.log("Finish Default selection recovery first"); return false end
        return preview.inspect()
    end
    function self.invalidate_context_lookup(reason)
        selection.invalidate_context_lookup(reason)
        preview.invalidate_context_lookup(reason)
    end
    function self.context_changed(reason)
        self.invalidate_context_lookup(reason)
        if busy or selection.busy then return end -- our own synchronous equip/reset events
        preview.context_changed(reason)
    end
    function self.start()
        local recover=selection.start()
        preview.start()
        if recover then
            runtime:after("selection:recovery",50,function()
                if selection.record() then self.restore("reload recovery") end
            end)
        end
    end
    return self
end
return M
