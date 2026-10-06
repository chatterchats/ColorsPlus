-- Catalog and bridge behavior without Unreal or the Dev Panel UI.
local scripts=assert(arg[1])
local bridge=assert(loadfile(scripts .. "/dev_panel_bridge.lua"))()
local manifest=assert(loadfile(scripts .. "/../DevPanel/actions.lua"))()
local jobs,handlers,logs,calls={},{},{},{}
local game_thread=false
local runtime={alive=true}
runtime.log=function(s) logs[#logs+1]=s end
function runtime:guard(fn) return function(...) if self.alive then return fn(...) end end end
function runtime:after(key,ms,fn) assert(ms==1); jobs[key]=self:guard(fn) end
function runtime:cancel(key) jobs[key]=nil end
local function hit(key)
    return function() assert(game_thread,"must dispatch on game thread"); calls[key]=(calls[key] or 0)+1 end
end
local function run(key)
    local fn=assert(jobs["panel:" .. key],key .. " not scheduled")
    jobs["panel:" .. key]=nil
    game_thread=true; fn(); game_thread=false
end
local function invoke(key) handlers[key](); run(key) end
local client={OnAction=function(key,fn) handlers[key]=fn end,IsAvailable=function() return true end}
local tint={inspect=hit("inspect"),restore=hit("restore"),context_changed=hit("context")}
runtime.picker={open=hit("open"),close=hit("close"),apply=hit("apply")}
runtime.color_compatibility={capture=hit("compat")}
runtime.screen_trace={start=hit("screens"),stop=hit("screens_stop")}
runtime.material_trace={arm=hit("materials"),stop=hit("materials_stop"),event=hit("material_event")}
runtime.stock_call_trace={arm=hit("stock"),stop=hit("stock_stop"),slot_event=hit("stock_event")}
local probe={}
bridge.attach(runtime,probe,tint,client)
local expected={open_picker=true,apply_picker=true,close_picker=true,restore_tint=true,
    inspect_tint=true,capture_compat=true,trace_screens=true,stop_screen_trace=true,
    trace_materials=true,stop_material_trace=true,trace_stock_calls=true,stop_stock_calls=true}
local seen={}
local main_file=assert(io.open(scripts .. "/main.lua","r"))
local build=assert(main_file:read("*a"):match('local VERSION = "([%d.]+)"'))
main_file:close()
assert(manifest.version==build and #manifest.actions==12)
assert(manifest.actions[1].desc:find("colors_plus_performance.log",1,true)
    and not manifest.actions[1].desc:find("2-minute timeout",1,true))
for _,action in ipairs(manifest.actions) do
    assert(expected[action.key] and not seen[action.key] and handlers[action.key],action.key)
    seen[action.key]=true
    assert(action.category=="Colors+ Picker" or action.category=="Colors+ Diagnostics")
    assert(not action.desc:find("Clone 8",1,true))
end
assert(not seen.apply_cyan and not seen.apply_blue and not seen.apply_handoff and not seen.apply_rgb)

handlers.open_picker(); assert(not calls.open); run("open_picker"); assert(calls.open==1)
invoke("apply_picker"); assert(calls.apply==1)
handlers.open_picker(); handlers.apply_picker(); invoke("close_picker")
assert(not jobs["panel:open_picker"] and not jobs["panel:apply_picker"])
assert(calls.close==1 and not calls.restore,"Cancel must not undo an earlier Apply")
tint.applied={}
handlers.open_picker(); handlers.apply_picker(); invoke("restore_tint")
assert(calls.close==2 and calls.restore==1)
assert(not jobs["panel:open_picker"] and not jobs["panel:apply_picker"])
handlers.trace_stock_calls(); assert(not jobs["panel:trace_stock_calls"],"restore applied color before stock capture")
tint.applied=nil
invoke("capture_compat"); invoke("inspect_tint"); assert(calls.compat==1 and calls.inspect==1)
for stop,start in pairs({stop_screen_trace="trace_screens",stop_material_trace="trace_materials",stop_stock_calls="trace_stock_calls"}) do
    handlers[start](); assert(jobs["panel:" .. start])
    invoke(stop); assert(not jobs["panel:" .. start],"Stop must supersede pending Start")
    invoke(start)
end
assert(calls.screens==1 and calls.materials==1 and calls.stock==1)
jobs["screen-trace:command"]=function() error("stale console start") end
invoke("stop_screen_trace"); assert(not jobs["screen-trace:command"])

-- Recheck exclusions after dispatch, not only at the click boundary.
handlers.open_picker(); handlers.apply_picker()
runtime.stock_call_trace.window={}
run("open_picker"); run("apply_picker")
assert(calls.open==1 and calls.apply==1)
handlers.open_picker(); assert(not jobs["panel:open_picker"])
invoke("close_picker"); invoke("stop_stock_calls")
runtime.stock_call_trace.window=nil
handlers.open_picker(); handlers.apply_picker(); invoke("trace_stock_calls")
assert(not jobs["panel:open_picker"] and not jobs["panel:apply_picker"])
handlers.apply_picker(); runtime.eye_preview={pending={}}
run("apply_picker"); assert(calls.apply==1)
invoke("stop_screen_trace"); invoke("stop_material_trace"); invoke("stop_stock_calls")
handlers.capture_compat(); assert(not jobs["panel:capture_compat"])
runtime.eye_preview=nil

-- Page exit cancels queued context-sensitive work, not screen tracing.
for _,key in ipairs({"open_picker","apply_picker","capture_compat","inspect_tint","trace_materials","trace_stock_calls","trace_screens"}) do handlers[key]() end
game_thread=true; probe.on_context_event("page closed"); game_thread=false
for _,key in ipairs({"open_picker","apply_picker","capture_compat","inspect_tint","trace_materials","trace_stock_calls"}) do
    assert(not jobs["panel:" .. key],key .. " survives page exit")
end
assert(jobs["panel:trace_screens"]); run("trace_screens")
game_thread=true; probe.on_stock_call("test"); game_thread=false
assert(calls.stock_event==1)
runtime.alive=false; handlers.open_picker(); assert(not jobs["panel:open_picker"])
runtime.alive=true

-- Independent read-only features must not be disabled with the tint backend.
runtime.picker=nil; runtime.tint_disabled_reason="session gate blocked"
bridge.attach(runtime,probe,nil,client)
handlers.open_picker(); assert(not jobs["panel:open_picker"])
invoke("capture_compat"); invoke("trace_screens"); invoke("stop_screen_trace")
assert(calls.compat==2)
runtime.color_compatibility=nil
invoke("capture_compat"); assert(logs[#logs]:find("Unavailable: color_compatibility",1,true))
-- Read-only dispatch status works even when tint is disabled.
RegisterConsoleCommandHandler=function() end
local status_command,status_reads=nil,0
function runtime:console(name,fn) assert(name=="colors_panel"); status_command=fn end
client.Status=function() assert(game_thread); status_reads=status_reads+1; return "polls=3" end
client.SetDiagnosticSink=function(fn) assert(fn==runtime.log) end
bridge.attach(runtime,probe,nil,client)
status_command(nil,{"status"}); assert(status_reads==0); run("status"); assert(status_reads==1)
assert(logs[#logs]:find("STATUS | polls=3",1,true))
status_command(nil,{"reset"}); assert(not jobs["panel:status"])
assert(logs[#logs]:find("Usage:",1,true))
print("Dev Panel bridge: catalog, dispatch, Apply/Cancel/Restore, exclusions, queued cancellation and independent diagnostics passed")
