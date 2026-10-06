-- Developer diagnostics: probes, traces, console commands and the SWZC Dev
-- Panel integration. Only the dev package ships this file (and the modules it
-- loads); main.lua attaches it when present. The player package contains the
-- picker, editing backend, recovery and the automatic performance log.
local M={}
function M.attach(runtime,probe,tint,module,directory)
    runtime.call_trace = module("call_trace").new(runtime)
    if tint then
        runtime.material_trace = module("material_trace").new(runtime, probe.access, tint.read_context)
        runtime.material_trace.attach()
        runtime.stock_call_trace = module("stock_call_trace").new(runtime, probe.access, tint.read_context)
        runtime.sv_probe = module("sv_drag_probe").new(runtime)
        runtime.sv_probe.attach()
        runtime.click_probe = module("click_event_probe").new(runtime)
        runtime.click_probe.attach()
        runtime.skin_target = module("skin_target_probe").new(runtime, probe.access, directory .. "../DevPanel/skin_target_recovery.txt")
        runtime.skin_target.start()
        runtime.skin_target.attach()
        runtime.eye_preview = module("eye_preview").new(runtime, probe.access, directory .. "../DevPanel/eye_recovery.txt")
        runtime.eye_preview.start()
        runtime.eye_preview.attach()
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
end
return M
