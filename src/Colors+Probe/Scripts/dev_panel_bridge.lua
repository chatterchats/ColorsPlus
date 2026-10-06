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
    local writes={apply_cyan=true,apply_handoff=true,apply_blue=true,apply_rgb=true,open_picker=true,apply_picker=true}
    local stops={stop_material_trace="trace_materials",stop_stock_calls="trace_stock_calls",stop_screen_trace="trace_screens"}
    local function cancel_writes()
        for key in pairs(writes) do runtime:cancel("panel:" .. key) end
    end
    local function register(key, callback, independent)
        local function allowed()
            if runtime.skin_target and (runtime.skin_target.pending or runtime.skin_target.blocked)
                and key~="restore_tint" and key~="close_picker" and not stops[key] then
                runtime.log("SKIN TARGET PROBE | Stop/recover colors_target first"); return false
            end
            if not stops[key] and runtime.eye_preview and (runtime.eye_preview.pending or runtime.eye_preview.blocked) then
                runtime.log("EYE PREVIEW | Dev Panel action refused; use colors_eyes stop first")
                return false
            end
            if not tint and not independent then
                runtime.log("TINT | Disabled: " .. (runtime.tint_disabled_reason or "tint module unavailable"))
                return false
            end
            if writes[key]
                and runtime.stock_call_trace and runtime.stock_call_trace.window then
                runtime.log("STOCK CALL TRACE | Tint action refused during read-only stock capture; stop the trace first")
                return false
            end
            if key == "trace_stock_calls" and ((runtime.picker and runtime.picker.active)
                or (tint and (tint.pending or tint.applied or tint.blocked))) then
                runtime.log("STOCK CALL TRACE | Restore the picker color before stock capture")
                return false
            end
            return true
        end
        client.OnAction(key, runtime:guard(function()
            runtime.log("PANEL DISPATCH | RECEIVED | " .. key)
            if not allowed() then return end
            if key == "restore_tint" or key == "close_picker" or key == "trace_stock_calls" then cancel_writes() end
            if stops[key] then runtime:cancel("panel:" .. stops[key]) end
            if key == "stop_screen_trace" then runtime:cancel("screen-trace:command") end
            if key == "restore_tint" then
                runtime:cancel("tint:rgb-cycle")
                runtime:cancel("tint:timeout")
            end
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
    -- Historical handlers remain for development regression fixtures/old state
    -- files, but are no longer advertised as current tests in the panel menu.
    register("apply_cyan", function() tint.apply() end)
    register("apply_handoff", function() tint.apply(true) end)
    register("apply_blue", function() tint.apply("blue") end)
    register("apply_rgb", function() tint.cycle_rgb() end)
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
        if runtime.skin_target and not runtime.skin_target.stop("Dev Panel Restore") then return end
        if runtime.picker then runtime.picker.close("Dev Panel Restore") end
        if tint.pending or tint.applied or not runtime.picker then tint.restore("Dev Panel Restore") end
    end)
    register("trace_materials", function()
        if runtime.material_trace then runtime.material_trace.arm() end
    end)
    register("stop_material_trace", function()
        if runtime.material_trace then runtime.material_trace.stop("panel") end
    end)
    register("trace_stock_calls", function()
        if runtime.stock_call_trace then
            cancel_writes()
            runtime.stock_call_trace.arm()
        end
    end)
    register("stop_stock_calls", function()
        if runtime.stock_call_trace then runtime.stock_call_trace.stop("panel") end
    end)
    if tint then
        probe.on_stock_call = function(...)
            if runtime.stock_call_trace then runtime.stock_call_trace.slot_event(...) end
        end
        probe.on_context_event = function(reason,identity)
            if runtime.skin_target then runtime.skin_target.context_changed(reason) end
            if runtime.skin_enable then runtime.skin_enable.stop(reason) end
            if runtime.eye_preview then runtime.eye_preview.context_changed(reason) end
            local closed=reason=="page closed" or reason=="creator closed"
            if closed then
                runtime:cancel("eyes:command")
                -- A panel action may already have been handed to this runtime
                -- but not executed. Do not open/apply it on the next screen.
                cancel_writes()
                for _,key in ipairs({"inspect_tint","capture_compat","trace_materials","trace_stock_calls"}) do
                    runtime:cancel("panel:" .. key)
                end
            end
            tint.context_changed(reason,identity)
            if runtime.stock_call_trace and closed then runtime.stock_call_trace.stop(reason) end
            if runtime.material_trace then
                if closed then runtime.material_trace.stop(reason)
                else runtime.material_trace.event("stock/UI: " .. reason) end
            end
        end
    end
    runtime.log("Dev Panel integration | available=" .. tostring(client.IsAvailable()) .. " | F6 > Colors+ Probe")
end
return M
