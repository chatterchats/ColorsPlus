-- Routes customization context events to the editing backend. This is
-- production wiring; dev tools may add probe/trace handlers around it through
-- runtime.dev_context {before=fn, after=fn}. A failing dev handler never stops
-- the backend from seeing the event.
local M={}
function M.attach(runtime,probe,tint)
    local function dev(stage,reason,identity)
        local handlers=runtime.dev_context
        local fn=handlers and handlers[stage]
        if not fn then return end
        local ok,err=pcall(fn,reason,identity)
        if not ok then runtime.log("DEV CONTEXT | " .. stage .. " failed | " .. tostring(err)) end
    end
    probe.on_context_event=function(reason,identity)
        dev("before",reason,identity)
        if runtime.skin_enable then runtime.skin_enable.stop(reason) end
        tint.context_changed(reason,identity)
        dev("after",reason,identity)
    end
end
return M
