-- Colors+Probe v0.2.117
-- RGB preview; Default temporarily changes the editor swatch and restores it.
local VERSION = "0.2.117"
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local directory = assert(source:match("^(.*[/\\])"), "Scripts directory unavailable")

-- Run each of this mod's scripts once per bootstrap and share its module
-- table. Modules are stateless factories (state lives in new/wrap results);
-- per-zone stacks otherwise recompiled ~68 files each (color_rules 28x).
-- Only this Scripts folder is memoized; this mod has its own Lua state. The
-- original is kept across reloads so a reload never wraps the wrapper, and
-- a fresh table per bootstrap picks up edited files.
local original_loadfile = rawget(_G, "ColorsPlusProbeOriginalLoadfile") or loadfile
rawset(_G, "ColorsPlusProbeOriginalLoadfile", original_loadfile)
local loaded_modules = {}
loadfile = function(path, ...)
    if select("#", ...) > 0 or type(path) ~= "string" or path:sub(1, #directory) ~= directory
        or path:sub(-4) ~= ".lua" or path:find("[/\\]", #directory + 1) then
        return original_loadfile(path, ...)
    end
    local entry = loaded_modules[path]
    if not entry then
        local chunk, err = original_loadfile(path)
        if not chunk then return nil, err end
        entry = { chunk() }
        loaded_modules[path] = entry
    end
    return function() return entry[1] end
end

-- Explicit paths prevent collisions with another mod's generic module names.
local function module(name)
    return assert(loadfile(directory .. name .. ".lua"))()
end

local bootstrap_log = module("logging").new(directory .. "../colors_plus_probe.log",0)
bootstrap_log.write("STARTUP | BOOTSTRAP ENTER | v" .. VERSION)
local started,runtime = pcall(function() return module("hook_registry").start("ColorsPlusProbeRuntime") end)
bootstrap_log.write("STARTUP | RUNTIME START RETURN | ok=" .. tostring(started))
bootstrap_log.close()
assert(started,runtime)
runtime.version = VERSION
runtime.generic_colors = true
local log = module("logging").new(directory .. "../colors_plus_probe.log", runtime.generation)
runtime.log = log.write
local perf_log = module("logging").new(directory .. "../colors_plus_performance.log", runtime.generation,{mirror=false})
runtime.on_close = function() perf_log.close(); log.close() end
runtime.call_trace = module("call_trace").new(runtime)
-- Time every real lookup (cache misses and unheld calls) for tester captures.
runtime.objects = module("object_cache").new(function(path)
    if runtime.perf then return runtime.perf.measure("lookup.static_find", StaticFindObject, path) end
    return StaticFindObject(path)
end)
runtime.trace_picker_initialization = false -- manual colors_picker trace remains available
runtime.perf = module("performance_log").new(runtime,{sink=perf_log.write_batch})
if type(RegisterConsoleCommandHandler)=="function" then runtime.perf.attach() end
local probe = module("customization_probe").new(runtime)
runtime.probe = probe
runtime.log("Loaded v" .. VERSION .. " | detailed snapshots manual only; lifecycle hooks active | generation=" .. runtime.generation)
runtime.log("Default fallback temporarily equips a stock swatch. Apply lasts for the editor visit; exit/Restore restores the original. No save calls.")
runtime.log("Log file: " .. log.path)
runtime.log("Automatic picker performance log: " .. perf_log.path)
runtime.log("STARTUP | PROBE START BEGIN")
probe.start()
runtime.log("STARTUP | PROBE START RETURN")
local tint
local missing = {}
for _, name in ipairs({ "ExecuteInGameThread", "StaticFindObject", "FindAllOf", "MakeActionHandle",
    "ExecuteInGameThreadWithDelay", "CancelDelayedAction" }) do
    if type(_G[name]) ~= "function" then
        missing[#missing + 1] = name .. " (type=" .. type(_G[name]) .. "; expected function)"
    end
end
-- UE4SS hides userdata metatables with __metatable=false. Presence/type is
-- all we check at bootstrap; tint actions prove construction and slot lookup
-- on the game thread before cloning or writing anything.
local name_type = type(FName)
if name_type ~= "function" and name_type ~= "userdata" and name_type ~= "table" then
    missing[#missing + 1] = "FName (type=" .. name_type .. "; expected constructor value)"
end
if #missing == 0 then
    runtime.log("STARTUP | SESSION GATE BEGIN")
    local allowed,session_reason=module("recovery_session").prepare(runtime,directory .. "../DevPanel/")
    runtime.log("STARTUP | SESSION GATE RETURN | allowed=" .. tostring(allowed))
    if allowed then
    tint = module("multi_editor").new(runtime,function(zone_runtime,index)
    local prefix=index==1 and "" or ("zone" .. index .. "_")
    local function journal(leaf) return directory .. "../DevPanel/" .. prefix .. leaf end
    local tint = module("tint_test").new(zone_runtime, probe.access, journal("tint_recovery.txt"))
    local regular = tint
    tint = module("default_tint").wrap(zone_runtime, probe.access, journal("tint_recovery.txt"), tint)
    tint = module("default_selection").wrap(zone_runtime, probe.access, journal("default_selection_recovery.txt"), regular, tint)
    tint = module("editor_session").wrap(zone_runtime, probe.access, journal("editor_recovery.txt"), tint)
    tint = module("zabrak_picker").wrap(zone_runtime, probe.access, journal("zabrak_picker_recovery.txt"), tint)
    return tint
    end,function(index)
        -- Same per-zone journals the session gate preserves/archives. Readers
        -- treat an empty journal as nothing to recover, but any ".previous"
        -- file (interrupted replacement) blocks its zone, so it always counts.
        for _,leaf in ipairs({"tint_recovery.txt","default_selection_recovery.txt","editor_recovery.txt",
            "editor_recovery.txt.previous","zabrak_picker_recovery.txt","zabrak_picker_recovery.txt.previous"}) do
            local f=io.open(directory .. "../DevPanel/zone" .. index .. "_" .. leaf,"r")
            if f then
                local data=f:read(1); f:close()
                if data or leaf:sub(-9)==".previous" then return true end
            end
        end
        return false
    end)
    runtime.tint = tint
    runtime.material_trace = module("material_trace").new(runtime, probe.access, tint.read_context)
    runtime.material_trace.attach()
    runtime.stock_call_trace = module("stock_call_trace").new(runtime, probe.access, tint.read_context)
    runtime.log("STARTUP | RECOVERY LOAD BEGIN")
    tint.start()
    runtime.log("STARTUP | RECOVERY LOAD RETURN")
    runtime.picker = module("live_picker").new(runtime, tint, module("picker_view").new(runtime), module("rgb_input"))
    runtime.picker.start()
    runtime.color_ui = module("color_ui").new(runtime,probe.access,tint)
    runtime.color_ui.start()
    runtime.sv_probe = module("sv_drag_probe").new(runtime)
    runtime.sv_probe.attach()
    runtime.click_probe = module("click_event_probe").new(runtime)
    runtime.click_probe.attach()
    runtime.skin_enable = module("skin_enable_probe").new(runtime, probe.access)
    runtime.skin_enable.attach()
    runtime.skin_target = module("skin_target_probe").new(runtime, probe.access, directory .. "../DevPanel/skin_target_recovery.txt")
    runtime.skin_target.start()
    runtime.skin_target.attach()
    runtime.eye_preview = module("eye_preview").new(runtime, probe.access, directory .. "../DevPanel/eye_recovery.txt")
    runtime.eye_preview.start()
    runtime.eye_preview.attach()
    runtime.log("TINT | API presence checks passed | FName=" .. name_type
        .. " | constructor validation deferred to game-thread action | preview writes remain opt-in")
    else
        runtime.tint_disabled_reason=session_reason
        runtime.log("TINT | Disabled by session gate | " .. tostring(session_reason))
    end
else
    runtime.tint_disabled_reason = "required UE4SS API unavailable: " .. table.concat(missing, ", ")
    runtime.log("TINT | Disabled: " .. runtime.tint_disabled_reason)
end
module("picker_console").attach(runtime)
runtime.screen_trace = module("screen_trace").new(runtime, probe.access)
runtime.screen_trace.attach()
runtime.color_compatibility = module("color_compatibility").new(runtime, probe.access)
runtime.color_compatibility.attach()
-- Reload the helper factory: its old client shuts down before the new client
-- binds this runtime's scheduler. Never reuse a retired runtime adapter.
runtime.log("STARTUP | PANEL CLIENT BEGIN")
local client = module("SWZCDevPanel")
rawset(_G, "ColorsPlusProbeDevPanelClient", client)
module("dev_panel_bridge").attach(runtime, probe, tint, client)
runtime.log("STARTUP | PANEL CLIENT RETURN")
runtime.log("STARTUP | BOOTSTRAP COMPLETE | waiting for deferred game-thread jobs")
return runtime
