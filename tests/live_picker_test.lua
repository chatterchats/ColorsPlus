local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/live_picker.lua"))()
local rgb=assert(loadfile(scripts .. "/rgb_input.lua"))()
local jobs,logs={},{}
local expected_delay=33
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,fn) jobs[k]={delay=ms,cb=fn} end
function runtime:cancel(k) jobs[k]=nil end
local perf_lines={}
runtime.perf=assert(loadfile(scripts .. "/performance_log.lua"))().new(runtime,{sink=function(lines)
    for _,line in ipairs(lines) do perf_lines[#perf_lines+1]=line end
end})
local function run(n)
    for _=1,n or 1 do
        local j=assert(jobs["picker:tick"]); jobs["picker:tick"]=nil
        assert(j.delay==expected_delay); j.cb()
        assert((runtime.perf.window~=nil)==(runtime.picker.active~=nil),"Capture must end on every picker exit, not during an active draft")
    end
end
local calls={open=0,close=0,restore=0,update=0,check=0,cleanup=0}
local values,action={R=255,G=128,B=32},nil
local fail_view, fail_start, fail_update, fail_close, unhealthy
local tint={}
function tint.begin_live()
    calls.open=calls.open+1
    if fail_start then return end
    tint.pending={live=true,test_color=rgb.parse("255,128,32")}
    return tint.pending
end
function tint.restore()
    calls.restore=calls.restore+1
    tint.pending.live=nil; tint.pending=nil
    return true
end
function tint.update_live(s,c)
    assert(s==tint.pending and s.live)
    if fail_update then return false end
    calls.update=calls.update+1; s.test_color=c; return true
end
function tint.check_live() calls.check=calls.check+1; return not unhealthy,"changed" end
local view={
    open=function() if fail_view then error("build failed") end end,
    close=function() calls.close=calls.close+1; if fail_close then error("close failed") end end,
    cleanup=function() calls.cleanup=calls.cleanup+1 end,
    set_rgb=function(v) values={R=v.R,G=v.G,B=v.B} end,
    read=function() if fail_view then error("stale UI") end; local a=action; action=nil; return values,a end,
    show=function(v,c) assert(c.A==1); calls.shown=v end,
}
local picker=module.new(runtime,tint,view,rgb)
runtime.picker=picker
assert(picker.open() and picker.active and calls.open==1)
assert(runtime.perf.window.mode=="picker" and not jobs["perf:expiry"])
assert(runtime.perf.window.rows["ui.open"] and runtime.perf.window.rows["picker.open"],"Opening must be included in automatic capture")
assert(not picker.open() and calls.open==1)
local original=picker.active
values={R=160,G=64,B=224}; run(5); assert(calls.update==0)
assert(runtime.perf.window.rows["picker.sample.editing"].n==5,
    "Input changes and colors waiting for the update gate count as editing")
values={R=64,G=208,B=112}; run(); assert(calls.update==1)
assert(rgb.to_srgb(tint.pending.test_color).G==208)
run(9); assert(calls.check==1 and calls.update==1)
assert(runtime.perf.window.rows["picker.sample.idle"].n==9
    and runtime.perf.window.rows["picker.sample.editing"].n==6,
    "Unchanged polls must not dilute editing metrics")
action="violet"; run(3); assert(calls.update==2 and values.R==160)
local old_tick=jobs["picker:tick"].cb
action="cancel"; run()
assert(not picker.active and not tint.pending and not jobs["picker:tick"] and calls.restore==1)
assert(not runtime.perf.window and table.concat(perf_lines,"\n"):find("reason=picker Cancel",1,true))
assert(picker.open()); local next_active=picker.active; old_tick(); assert(picker.active==next_active)
picker.close("manual"); assert(not tint.pending)
-- Build failure must not start a tint, and failed tint startup closes the UI.
fail_view=true; local before=calls.open; assert(not picker.open() and calls.open==before); fail_view=false
fail_start=true; assert(not picker.open() and not picker.active); fail_start=false
assert(not runtime.perf.window and not jobs["perf:summary"],"Failed opening must close automatic capture")
-- UI lifetime, failed updates, changed context and external restoration stop work.
assert(picker.open()); fail_view=true; run(); fail_view=false
assert(not picker.active and not tint.pending and not jobs["picker:tick"])
assert(picker.open()); values={R=0,G=0,B=0}; fail_update=true; run(6); fail_update=false
assert(not picker.active and not tint.pending)
assert(picker.open()); unhealthy=true; run(15); unhealthy=false
assert(not picker.active and not tint.pending)
assert(picker.open()); tint.pending.live=nil; run()
assert(not picker.active and not tint.pending)
assert(picker.open()); tint.restore(); before=calls.restore; run()
assert(not picker.active and calls.restore==before)
-- Existing recovery refuses opening.
tint.blocked="recovery"; assert(not picker.open()); tint.blocked=nil
-- Startup cleanup is delayed game-thread work and never removes an open picker.
StaticConstructObject=function() end
picker.start(); assert(calls.cleanup==0); jobs["picker:startup"].cb(); assert(calls.cleanup==1)
assert(picker.open()); picker.start(); jobs["picker:startup"].cb(); assert(calls.cleanup==1)
fail_close=true; assert(not picker.close("close failure") and not picker.active and not tint.pending)
fail_close=false; assert(picker.close("retry UI cleanup"))
-- A thrown backend restore must never prevent UI removal or cancel ownership.
assert(picker.open())
local restore=tint.restore
tint.restore=function() error("backend restore failed") end
before=calls.close
assert(not picker.close("restore exception"))
assert(calls.close==before+1 and not picker.active and not jobs["picker:tick"])
tint.restore=restore; tint.restore()
-- Apply flushes the latest (not yet 5Hz-applied) RGB and detaches UI only.
local applied,fail_apply
tint.apply_live=function(s)
    assert(s==tint.pending)
    if fail_apply then return false end
    applied=s.test_color; s.live=nil; tint.pending=nil; return true
end
tint.cancel_live=function(reason) return tint.restore(reason) end
assert(picker.open()); values={R=11,G=22,B=33}; before=calls.restore
action="apply"; run()
assert(not picker.active and not jobs["picker:tick"] and not tint.pending)
assert(not runtime.perf.window and table.concat(perf_lines,"\n"):find("reason=Apply",1,true))
assert(rgb.to_srgb(applied).R==11 and rgb.to_srgb(applied).B==33 and calls.restore==before)
assert(not picker.apply(),"Apply without an open picker is inert")
assert(picker.open()); fail_apply=true; action="apply"; run(); fail_apply=nil
assert(not picker.active and not tint.pending and calls.restore==before+1)
assert(picker.open()); fail_update=true; assert(not picker.apply()); fail_update=nil
assert(not picker.active and not tint.pending)
-- A synchronous native callback may close/replace the picker mid-poll. Old
-- work must not continue writing the UI, cancel the replacement or reschedule.
do
    local read,update=view.read,tint.update_live
    assert(picker.open()); local retired=picker.active
    view.read=function()
        view.read=read; picker.close("reentrant read"); assert(picker.open()); return read()
    end
    run(); assert(picker.active and picker.active~=retired and jobs["picker:tick"])
    picker.close("read test")
    assert(picker.open()); retired=picker.active; values={R=3,G=4,B=5}
    tint.update_live=function(s,c)
        tint.update_live=update; picker.close("reentrant setter"); assert(picker.open()); return false
    end
    run(6); assert(picker.active and picker.active~=retired and jobs["picker:tick"])
    picker.close("setter test")
    assert(picker.open()); tint.pending.force_restore_reason="slot change"
    view.read=function() error("Must not poll UI after a latched context stop") end
    run(); assert(not picker.active and not jobs["picker:tick"])
    view.read=read
end
assert(picker.open())
runtime.skin_enable={pending={},stop=function() runtime.skin_enable.pending=nil; return true end}
action="apply"; before=calls.update; run()
assert(picker.active and calls.update==before and jobs["picker:tick"],"blocked Apply must keep picker polling")
picker.close("skin test"); assert(not runtime.skin_enable.pending)
runtime.skin_enable=nil
-- Faster integrated HSV input does not multiply backend writes/checks.
view.poll_ms=16; expected_delay=16
assert(picker.open())
values={R=0,G=0,B=0}; local updates,checks=calls.update,calls.check
run(12); assert(calls.update==updates and calls.check==checks)
values={R=12,G=34,B=56}; run(); assert(calls.update==updates+1)
run(19); assert(calls.update==updates+1 and calls.check==checks+1)
values={R=56,G=34,B=12}; action="apply"; run()
assert(not picker.active and rgb.to_srgb(applied).R==56,"Apply flushes new input before next coalesced write")
-- All supported preview policies use the same owned readiness timers.
local begin_live,update_live=tint.begin_live,tint.update_live
local function gates_gone()
    assert(not jobs["picker:tick"] and not jobs["picker:preview-ready"] and not jobs["picker:health-ready"])
end
for _,policy in ipairs({"skin","armor","color","hsv"}) do
local receipt=true
tint.begin_live=function() local s=begin_live(); s.preview_policy=policy; return s end
tint.update_live=function(s,c) return update_live(s,c),receipt end
local function fire(k,delay)
    local j=assert(jobs[k],k); assert(j.delay==delay); jobs[k]=nil; j.cb()
end
assert(picker.open()); updates,checks=calls.update,calls.check
local stale_health=jobs["picker:health-ready"].cb
values={R=10,G=20,B=30}; run()
assert(calls.update==updates+1 and calls.check==checks,"First change must not wait for 13 polls: " .. policy)
assert(jobs["picker:preview-ready"].delay==75 and jobs["picker:health-ready"].delay==495)
stale_health(); assert(not picker.active.health_ready,"Validated update invalidates the previous health timer")
-- Arbitrarily many reads cannot end the cooldown; no color queue accumulates.
for i=1,100 do values={R=i,G=22,B=33}; run() end
assert(calls.update==updates+1 and calls.check==checks)
local old_ready=jobs["picker:preview-ready"].cb
fire("picker:preview-ready",75); run()
assert(calls.update==updates+2 and rgb.to_srgb(tint.pending.test_color).R==100)
old_ready(); assert(not picker.active.preview_ready,"Retired cooldown cannot release a new one")
-- A due health check is subsumed only by an explicitly validated update.
fire("picker:health-ready",495); fire("picker:preview-ready",75)
values={R=101,G=22,B=33}; run()
assert(calls.update==updates+3 and calls.check==checks)
receipt=false
fire("picker:health-ready",495); fire("picker:preview-ready",75)
values={R=102,G=22,B=33}; run()
assert(calls.update==updates+4 and calls.check==checks+1,"No receipt must not skip health checks")
receipt=true
-- Idle input gets periodic checks and makes no redundant color writes.
fire("picker:preview-ready",75); fire("picker:health-ready",495); run()
assert(calls.update==updates+4 and calls.check==checks+2)
local stale_preview=old_ready; stale_health=jobs["picker:health-ready"].cb
action="cancel"; run(); gates_gone()
assert(picker.open()); local replacement=picker.active
stale_preview(); stale_health()
assert(picker.active==replacement and not replacement.health_ready)
-- Apply flushes the most recent draft while cooldown is still locked.
values={R=11,G=22,B=33}; run(); assert(not picker.active.preview_ready)
values={R=44,G=55,B=66}; action="apply"; run(); gates_gone()
assert(rgb.to_srgb(applied).R==44 and rgb.to_srgb(applied).B==66)
-- Due preview cannot beat Cancel, a forced stop, or failed context validation.
assert(picker.open()); updates=calls.update
values={R=99,G=22,B=33}; action="cancel"; run(); gates_gone(); assert(calls.update==updates)
assert(picker.open()); values={R=99,G=22,B=33}; tint.pending.force_restore_reason="page exit"
run(); gates_gone(); assert(calls.update==updates)
assert(picker.open()); unhealthy=true; fire("picker:health-ready",495); run(); unhealthy=false
gates_gone(); assert(not picker.active)
assert(picker.open()); values={R=99,G=22,B=33}; fail_update=true; run(); fail_update=false
gates_gone(); assert(not picker.active)
-- Reentrant backend replacement must not arm cooldowns on the new picker.
assert(picker.open()); local retired=picker.active
tint.update_live=function(s,c)
    picker.close("replacement during update"); assert(picker.open()); return true,true
end
values={R=99,G=22,B=33}; run()
assert(picker.active~=retired and picker.active.preview_ready and not jobs["picker:preview-ready"])
tint.update_live=update_live; picker.close("done"); gates_gone()
tint.begin_live=begin_live
end
-- Native HSV mode selects its UI before preview writes and bypasses every
-- RGB byte/gamma conversion. The selected Look is retained by the backend.
local old_begin,old_read_context,old_view_open,old_view_read=tint.begin_live,tint.read_context,view.open,view.read
local rules=assert(loadfile(scripts .. "/color_rules.lua"))()
local hsv_profile={slot=rules.SCAR,parameter=rules.SCAR_HSV_PARAMETER}
local raw={R=-4,G=20,B=-1,A=1}
expected_delay=33; view.poll_ms=33
tint.read_context=function() return {profile=hsv_profile} end
local built_mode
view.open=function(mode) built_mode=mode end
tint.begin_live=function()
    assert(built_mode=="hsv_shift","HSV UI must be ready before native preview starts")
    tint.pending={live=true,test_color=raw,profile=hsv_profile,preview_policy="hsv"}; return tint.pending
end
assert(picker.open() and picker.active.mode=="hsv_shift" and picker.active.smooth)
assert(values.R==-4 and values.G==20 and values.B==-1)
updates=calls.update; run(6); assert(calls.update==updates,"Opening HSV mode must preserve the original values")
values={R=-12.3456789,G=27.5,B=-9.125}; run()
assert(tint.pending.test_color.R==values.R and tint.pending.test_color.G==27.5 and tint.pending.test_color.B==-9.125)
updates=calls.update
values={R=-9.25,G=10.5,B=-2.875}; run(100)
assert(calls.update==updates,"Native HSV must coalesce while the elapsed-time gate is closed")
do local job=assert(jobs["picker:preview-ready"]); jobs["picker:preview-ready"]=nil; job.cb() end
run(); assert(calls.update==updates+1 and tint.pending.test_color.R==-9.25 and tint.pending.test_color.B==-2.875)
values={R=-8,G=-35,B=7}; action="apply"; run(); gates_gone()
assert(applied.R==-8 and applied.G==-35 and applied.B==7)
assert(picker.open()); updates=calls.update
view.read=function() return values,nil,false end
assert(not picker.apply() and picker.active and calls.update==updates,"Invalid Dev Panel Apply must retain the draft")
view.read=old_view_read; action="cancel"; run(); gates_gone()
-- A native selection changing input kind during construction cannot write
-- through the mode that was chosen for the previous source.
tint.begin_live=function() tint.pending={live=true,test_color=rgb.parse("255,128,32")}; return tint.pending end
assert(not picker.open() and not tint.pending and not picker.active)
tint.begin_live,tint.read_context,view.open,view.read=old_begin,old_read_context,old_view_open,old_view_read
-- Seed the controls while the construction frame is live. Native preview
-- setup must run outside that frame and remains authoritative if it differs.
do
    local old_set,old_frame=view.set_rgb,view.frame
    local in_frame=false
    local seeds=0
    view.frame=function(fn)
        assert(not in_frame); in_frame=true
        local ok,err=pcall(fn); in_frame=false; assert(ok,err)
    end
    view.set_rgb=function(value) assert(in_frame); seeds=seeds+1; old_set(value) end
    tint.read_context=function() return {original=rgb.parse("255,128,32")} end
    tint.begin_live=function()
        assert(not in_frame,"No UI wrappers carried through native preview setup")
        assert(seeds==1 and values.R==255 and values.G==128)
        return old_begin()
    end
    assert(picker.open() and seeds==1,"Identical verified start must avoid second UI initialization")
    picker.close("seed test")
    seeds=0
    view.validate_ready=function() assert(in_frame); error("pane detached during preview setup") end
    assert(not picker.open() and not tint.pending and not picker.active,
        "Seeded UI must revalidate attachment after native preview setup and roll back if detached")
    view.validate_ready=nil
    seeds=0
    tint.read_context=function() return {original=rgb.parse("1,2,3")} end
    tint.begin_live=function() assert(not in_frame); return old_begin() end
    assert(picker.open() and seeds==2 and values.R==255 and values.G==128,
        "Changed preview starting color must be initialized from fresh native result")
    picker.close("changed seed")
    seeds=0
    tint.read_context=function() return {original={R=2,G=.2,B=.01,A=1}} end
    assert(picker.open() and seeds==2,"HDR seed must be clipped for RGB UI, not reject a supported source")
    picker.close("HDR seed")
    seeds=0
    tint.read_context=function() return {profile=hsv_profile,original=raw} end
    tint.begin_live=function()
        assert(not in_frame)
        tint.pending={live=true,test_color=raw,profile=hsv_profile}; return tint.pending
    end
    assert(picker.open() and seeds==1 and values.R==-4 and values.G==20,"HSV seeds keep signed native values")
    picker.close("HSV seed")
    view.frame,view.set_rgb=old_frame,old_set
    tint.begin_live,tint.read_context=old_begin,old_read_context
end
-- Automatic opening-only tracing is bounded and does not spill into polling.
runtime.call_trace=assert(loadfile(scripts .. "/call_trace.lua"))().new(runtime)
runtime.trace_picker_initialization=true
logs={}
assert(picker.open() and not runtime.call_trace.window and not jobs["call-trace:expiry"])
local trace_text=table.concat(logs,"\n")
for _,step in ipairs({"tint.begin","performance ready","input mode validation","initial color conversion",
    "initial color keys","UI initialization frame","view.set_rgb","view.show","schedule input polling"}) do
    assert(trace_text:find("BEGIN | OPEN STEP " .. step,1,true),step)
    assert(trace_text:find("RETURN | OPEN STEP " .. step,1,true),step)
end
assert(trace_text:find("opening complete",1,true))
logs={}; run(); assert(not table.concat(logs,"\n"):find("CALL TRACE",1,true))
picker.close("trace test")
-- Lua initialization failures still restore and pair ERROR before stopping.
local set_rgb=view.set_rgb
view.set_rgb=function() error("initialization fault",0) end
logs={}; assert(not picker.open() and not picker.active and not tint.pending)
assert(not runtime.call_trace.window and not jobs["call-trace:expiry"])
assert(table.concat(logs,"\n"):find("ERROR | OPEN STEP view.set_rgb | initialization fault",1,true))
view.set_rgb=set_rgb
-- An explicit user's trace is neither replaced nor stopped by automatic mode.
local explicit=runtime.call_trace.start("explicit diagnostic")
assert(picker.open() and runtime.call_trace.window==explicit)
picker.close("explicit test"); runtime.call_trace.stop(explicit,"test complete")
-- Release defaults: no automatic per-call flushing, but performance capture
-- and explicit diagnostic requests remain available.
runtime.trace_picker_initialization=false
logs={}; assert(picker.open())
assert(not runtime.call_trace.window and not jobs["call-trace:expiry"])
assert(runtime.perf.window and runtime.perf.window.mode=="picker")
assert(not table.concat(logs,"\n"):find("CALL TRACE",1,true))
picker.close("normal logging"); assert(not runtime.perf.window)
explicit=runtime.call_trace.start("manual with automatic tracing off")
assert(picker.open() and runtime.call_trace.window==explicit)
picker.close("manual test"); runtime.call_trace.stop(explicit,"test complete")
print("Live picker: coalescing, skin cooldown/validation receipts, idle health, Apply flush, cancellation and stale/reentrant timers passed")
