-- Developer diagnostics: traces, the compatibility survey and console
-- commands. Only the dev package ships this file (and the modules it loads);
-- main.lua attaches it when present. The player package contains the
-- picker, editing backend, recovery and the automatic performance log.
local M={}
function M.attach(runtime,probe,tint,module,directory)
    runtime.lookup_trace = module("lookup_trace").new(runtime, directory)
    runtime.lookup_trace.attach()
    runtime.call_trace = module("call_trace").new(runtime)
    module("picker_console").attach(runtime)
    runtime.screen_trace = module("screen_trace").new(runtime, probe.access)
    runtime.screen_trace.attach()
    runtime.color_compatibility = module("color_compatibility").new(runtime, probe.access)
    runtime.color_compatibility.attach()
end
return M
