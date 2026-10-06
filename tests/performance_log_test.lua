local scripts=assert(arg[1])
local jobs,commands,logs={},{},{}
local now,clock_calls=0,0
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,fn) jobs[k]={ms=ms,fn=fn} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(k,fn) commands[k]=fn end
local module=assert(loadfile(scripts .. "/performance_log.lua"))()
local perf=module.new(runtime,{limit=4,clock=function() clock_calls=clock_calls+1; return now end})
local function run(k) local j=assert(jobs[k]); jobs[k]=nil; j.fn() end
local function results(...) assert(select("#",...)==3); local a,b,c=...; assert(a==1 and b==nil and c==3) end
results(perf.measure("disabled",function() return 1,nil,3 end))
results(perf.picker_sample(function() return 1,nil,3 end))
assert(clock_calls==0 and #logs==0 and not perf.queue("disabled",16),"Disabled profiler must not sample clock/log")
perf.attach(); commands.colors_perf(nil,{"bad"}); assert(not jobs["perf:command"])
commands.colors_perf(nil,{"start"}); run("perf:command")
assert(jobs["perf:expiry"].ms==120000 and jobs["perf:summary"].ms==5000)
assert(table.concat(logs,"\n"):find("update-stages-v3",1,true),"Capture must identify the stage instrumentation")
local old_summary=jobs["perf:summary"].fn
local w=perf.window
results(perf.measure("outer",function()
    now=now+.01
    perf.measure("inner",function() now=now+.02 end)
    return 1,nil,3
end))
assert(w.rows.outer.n==1 and math.abs(w.rows.outer.total-30)<1e-8 and w.rows.inner.slow==1)
local ok,why=pcall(perf.measure,"failure",function() now=now+.002; error("original failure",0) end)
assert(not ok and why=="original failure" and w.rows.failure.errors==1)
local ticket=perf.queue("zone12:editor:watch",100); now=now+.15; perf.dispatch(ticket)
assert(w.rows["queue_clock_late.zone:editor:watch"].max>49)
perf.measure("overflow",function() end); assert(w.dropped==1 and w.labels==4)
run("perf:summary"); assert(perf.window==w and w.labels==0 and jobs["perf:summary"])
for i=1,10 do perf.measure("job.panel-client:" .. i,function() end) end
assert(w.labels==1 and w.rows["job.panel-client:poll"].n==10,"Polling serials must share one bounded label")
perf.measure("job.snapshot:aux:PrivateObjectName",function() end)
assert(w.rows["job.snapshot:aux"],"Do not retain diagnostic object identities in timing labels")
assert(table.concat(logs,"\n"):find("avg_ms=",1,true))
perf.start(); local replacement=perf.window; old_summary(); assert(perf.window==replacement)
perf.dispatch(ticket); assert(replacement.labels==0,"Retired queue tickets must not enter a new capture")
perf.measure("ends_inside",function() perf.stop("nested stop"); return true end)
assert(not perf.window and not jobs["perf:expiry"] and not jobs["perf:summary"])
perf.start(); run("perf:expiry"); assert(not perf.window)
-- Actual owned scheduler, including the always-present (usually idle) tracer.
MakeActionHandle=function() return {} end
CancelDelayedAction=function(h) h.cancelled=true end
ExecuteInGameThreadWithDelay=function(h,ms,fn) h.fn=fn end
local owned=assert(loadfile(scripts .. "/hook_registry.lua"))().start("ColorsPerfTestRuntime")
owned.log=runtime.log
owned.perf=module.new(owned,{clock=function() return now end})
owned.call_trace={call=function(_,fn) return fn() end}
owned.perf.begin_picker("runtime teardown test")
owned:after("picker:tick",16,function() now=now+.025 end)
local job=owned.actions["picker:tick"]; now=now+.020; job.handle.fn()
assert(owned.perf.window.rows["job.picker:tick"].max>24)
assert(owned.perf.window.rows["queue_clock_late.picker:tick"].max>3)
owned:teardown(); assert(not owned.perf.window and next(owned.actions)==nil)
local expanded=module.new(runtime)
expanded.start()
for i=1,193 do expanded.measure("bounded-stage-" .. i,function() end) end
assert(expanded.window.labels==192 and expanded.window.dropped==1,"Expanded stage budget (opening sub-stages) must remain bounded")
expanded.stop("budget test")
-- Automatic picker captures own their lifetime; manual commands cannot cut
-- them short. Summaries go to an independent, batched sink, not runtime.log.
local batches={}
local automatic=module.new(runtime,{clock=function() return now end,
    sink=function(lines) batches[#batches+1]=table.concat(lines,"\n") end})
automatic.attach()
automatic.start(); local manual_expiry=jobs["perf:expiry"].fn
local capture=automatic.begin_picker("Custom Color button","test.Color.Primary")
assert(capture.mode=="picker" and capture.phase=="queued" and not jobs["perf:expiry"])
assert(automatic.begin_picker("repeat press","test.Color.Primary")==capture,"Repeat presses must not restart an existing capture")
local stale_auto_summary=jobs["perf:summary"].fn
manual_expiry(); assert(automatic.window==capture)
automatic.picker_opening(); automatic.picker_ready({profile={slot="test.Color.Primary"},preview_policy="armor"})
local writes_before=#batches
for _=1,300 do automatic.measure("ui.read",function() now=now+.001 end) end
assert(#batches==writes_before,"Inputs must aggregate in memory, without per-input IO")
now=now+181; run("perf:summary")
assert(automatic.window==capture and not jobs["perf:expiry"],"Automatic capture must survive beyond two minutes")
for _,action in ipairs({"stop","start"}) do commands.colors_perf(nil,{action}); run("perf:command"); assert(automatic.window==capture) end
automatic.cancel_launch("must not stop active picker"); assert(automatic.window==capture)
automatic.end_picker("Cancel",capture)
assert(not automatic.window and not jobs["perf:summary"])
automatic.begin_picker("Custom Color button","second.Color")
local replacement=automatic.window
automatic.end_picker("stale close",capture); stale_auto_summary()
assert(automatic.window==replacement)
automatic.cancel_launch("left before opening"); assert(not automatic.window and not jobs["perf:summary"])
assert(table.concat(batches,"\n"):find("reason=Cancel",1,true) and table.concat(batches,"\n"):find("ui.read",1,true))
local broken=module.new(runtime,{sink=function() error("bad sink") end})
broken.begin_picker("button"); broken.end_picker("failed file sink")
assert(not broken.window,"A failing sink must not disrupt picker lifetime")
-- Inclusive hitch counters and post-read activity classification have bounded
-- storage and do not write until a summary. Idle cannot dilute editing rows.
local ms=0
local diagnostic_batches={}
local diagnostic=module.new(runtime,{clock=function() return ms/1000 end,
    sink=function(lines) diagnostic_batches[#diagnostic_batches+1]=table.concat(lines,"\n") end})
diagnostic.begin_picker("test")
local writes=#diagnostic_batches
for _,duration in ipairs({25,50,100,250,300}) do
    ms=0; diagnostic.measure("hitches",function() ms=duration end)
end
local row=diagnostic.window.rows.hitches
assert(row.n==5 and row.slow==5 and row.ge50==4 and row.ge100==3 and row.ge250==2)
ms=0
results(diagnostic.picker_sample(function()
    ms=10; diagnostic.picker_activity(true); ms=100; return 1,nil,3
end))
for _=1,20 do
    ms=0; diagnostic.picker_sample(function() diagnostic.picker_activity(false); ms=1 end)
end
assert(diagnostic.window.rows["picker.sample.editing"].total==100
    and diagnostic.window.rows["picker.sample.editing"].n==1
    and diagnostic.window.rows["picker.sample.idle"].n==20)
assert(#diagnostic_batches==writes,"Activity/threshold metrics must not flush per tick")
local ok,why=pcall(diagnostic.picker_sample,function() error("input failed",0) end)
assert(not ok and why=="input failed" and diagnostic.window.rows["picker.sample.unclassified"].errors==1)
diagnostic.picker_activity(true) -- outside a sample cannot poison a later one
diagnostic.picker_sample(function() diagnostic.picker_activity(false) end)
assert(diagnostic.window.rows["picker.sample.idle"].n==21,"Failed sample releases activity scope")
diagnostic.report("test")
assert(diagnostic.window.labels==0 and diagnostic_batches[#diagnostic_batches]:find("ge50ms=4 ge100ms=3 ge250ms=2",1,true))
diagnostic.picker_ready({part="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_0A0",
    blue={part="donor"},profile={slot="SkinTone"}})
local ready=diagnostic_batches[#diagnostic_batches]
assert(ready:find("part=CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_0A0 | backend=regular",1,true)
    and ready:find("preview_part=donor",1,true))
diagnostic.picker_ready({perf_target={part="swap-preset",backend="source-swap"}})
assert(diagnostic_batches[#diagnostic_batches]:find("part=swap-preset | backend=source-swap",1,true))
diagnostic.picker_ready({part="temporary-preset",perf_selection="Default"})
assert(diagnostic_batches[#diagnostic_batches]:find("selection=Default",1,true))
diagnostic.picker_ready({part=setmetatable({},{__tostring=function() error("Native metadata must not be inspected") end})})
assert(diagnostic_batches[#diagnostic_batches]:find("part=unknown",1,true))
diagnostic.picker_ready({part="preset\nforged|field\t" .. string.rep("x",1000)})
ready=diagnostic_batches[#diagnostic_batches]
assert(not ready:find("\n",1,true) and not ready:find("forged|field",1,true) and #ready<=1050)
diagnostic.picker_sample(function()
    diagnostic.picker_activity(true); diagnostic.end_picker("exit")
    diagnostic.begin_picker("replacement")
end)
assert(diagnostic.window.labels==0,"An old sample must not enter a replacement window")
diagnostic.end_picker("done")
-- Object cache counters are reported per summary interval, not cumulatively.
local counted={log=function(s) logs[#logs+1]=s end,objects={hits=40,misses=7,active=function() return true end}}
function counted:after(k,ms,fn) jobs[k]={ms=ms,fn=fn} end
function counted:cancel(k) jobs[k]=nil end
local counter=module.new(counted,{clock=function() return now end})
counter.begin_picker("counter test")
counted.objects.hits,counted.objects.misses=52,9
logs={}; counter.report("interval")
assert(table.concat(logs,"\n"):find("object_cache | hits=12 misses=2 active=true",1,true),"Cache counters must be interval deltas")
logs={}; counter.report("interval")
assert(table.concat(logs,"\n"):find("object_cache | hits=0 misses=0",1,true))
counter.end_picker("done")
-- Each capture names its host environment once, from scalar host APIs only.
UE4SS={GetVersion=function() return 3,0,1 end}
UnrealVersion={GetMajor=function() return 5 end,GetMinor=function() return 3 end}
local env_runtime={log=function(s) logs[#logs+1]=s end}
function env_runtime:after(k,ms,fn) jobs[k]={ms=ms,fn=fn} end
function env_runtime:cancel(k) jobs[k]=nil end
local env=module.new(env_runtime,{clock=function() return now end})
logs={}; env.begin_picker("env test")
local joined=table.concat(logs,"\n")
assert(joined:find("| ENV | ue4ss=3.0.1 | unreal=5.3 | lua=",1,true),"Capture must record the UE4SS/engine versions")
env.end_picker("done")
UE4SS={GetVersion=function() error("unavailable") end}; UnrealVersion=nil
local missing=module.new(env_runtime,{clock=function() return now end})
logs={}; missing.begin_picker("env missing")
assert(table.concat(logs,"\n"):find("| ENV | ue4ss=unknown | unreal=unknown",1,true),"Missing host APIs must not stop capture")
missing.end_picker("done"); UE4SS=nil
print("Performance logging: off-path, timing/nil/error preservation, bounded summaries, expiry, stale windows, scheduler and teardown passed")
