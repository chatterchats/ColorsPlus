local M = {}
function M.attach(runtime, probe, tint, client)
    if client.UseScheduler and type(MakeActionHandle)=="function"
        and type(ExecuteInGameThreadWithDelay)=="function" and type(CancelDelayedAction)=="function" then
        client.UseScheduler(function(key,ms,fn) runtime:after(key,ms,fn) end,
            function(key) runtime:cancel(key) end)
        runtime:after("panel-client:startup",1,function()
            client.Init()
            runtime.log("PANEL CLIENT | STARTUP RETURN | " .. client.Status())
        end)
    end
    if client.SetDiagnosticSink then client.SetDiagnosticSink(runtime.log) end
    if type(RegisterConsoleCommandHandler)=="function" and client.Status then
        runtime:console("colors_panel",function(_,args)
            args=args or {}
            if #args>1 or (args[1]~=nil and args[1]~="status") then
                runtime.log("PANEL CLIENT | Usage: colors_panel status"); return
            end
            runtime:after("panel:status",1,function() runtime.log("PANEL CLIENT | STATUS | " .. client.Status()) end)
        end)
    end
    local writes={open_picker=true,apply_picker=true}
    local stops={stop_screen_trace="trace_screens"}
    local function cancel_writes()
        for key in pairs(writes) do runtime:cancel("panel:" .. key) end
    end
    local function register(key, callback, independent)
        local function allowed()
            if not tint and not independent then
                runtime.log("TINT | Disabled: " .. (runtime.tint_disabled_reason or "tint module unavailable"))
                return false
            end
            return true
        end
        client.OnAction(key, runtime:guard(function()
            runtime.log("PANEL DISPATCH | RECEIVED | " .. key)
            if not allowed() then return end
            if key == "restore_tint" or key == "close_picker" then cancel_writes() end
            if stops[key] then runtime:cancel("panel:" .. stops[key]) end
            if key == "stop_screen_trace" then runtime:cancel("screen-trace:command") end
            if key == "restore_tint" then runtime:cancel("tint:timeout") end
            -- Keep the owned delayed-action boundary even if a helper ever
            -- dispatches without ExecuteInGameThread. Never mutate in LoopAsync.
            runtime:after("panel:" .. key, 1, function()
                runtime.log("PANEL DISPATCH | RUN | " .. key)
                -- State may change after the panel dispatch but before this job.
                if allowed() then callback() end
            end)
        end))
    end
    register("inspect_tint", function() tint.inspect() end)
    register("open_picker", function()
        if runtime.picker then runtime.picker.open() end
    end)
    register("apply_picker", function()
        if runtime.picker then runtime.picker.apply() end
    end)
    register("close_picker", function()
        if runtime.picker then runtime.picker.close("Dev Panel Cancel") end
    end)
    local function diagnostic(module, method)
        if runtime[module] then runtime[module][method]()
        else runtime.log("DEV PANEL | Unavailable: " .. module) end
    end
    register("capture_compat", function() diagnostic("color_compatibility","capture") end, true)
    register("trace_screens", function() diagnostic("screen_trace","start") end, true)
    register("stop_screen_trace", function() diagnostic("screen_trace","stop") end, true)
    register("restore_tint", function()
        if runtime.picker then runtime.picker.close("Dev Panel Restore") end
        if tint.pending or tint.applied or not runtime.picker then tint.restore("Dev Panel Restore") end
    end)
    if tint then
        -- context_events owns the production route (skin stop, backend); this
        -- runs first so queued panel work never lands on the next screen.
        runtime.dev_context = {
            before=function(reason)
                if reason=="page closed" or reason=="creator closed" then
                    -- A panel action may already have been handed to this runtime
                    -- but not executed. Do not open/apply it on the next screen.
                    cancel_writes()
                    for _,key in ipairs({"inspect_tint","capture_compat"}) do
                        runtime:cancel("panel:" .. key)
                    end
                end
            end,
        }
    end
    runtime.log("Dev Panel integration | available=" .. tostring(client.IsAvailable()) .. " | F6 > Colors+ Probe")
end
return M
