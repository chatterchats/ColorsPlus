-- Exercise the supplied helper against an in-memory file protocol.
-- luajit tests/dev_panel_client_test.lua src/Colors+Probe/Scripts
local scripts=assert(arg[1])
local original_open,original_loadfile,original_print=io.open,loadfile,print
local manifest=assert(original_loadfile(scripts .. "/../DevPanel/actions.lua"))()
local registry,state_raw,state,queue,notes="","initial",{open_picker=4},{},{}
local id,gameThread=0,false
local mode="present"
local appends, marker_checks=0,0
io.open=function(path,access)
    if path:match("registry%.txt$") then
        if access=="r" then
            if mode=="read_denied" then return nil,"permission denied",13 end
            if mode=="absent" or registry==nil then return nil,"no such file",2 end
        else
            assert(access=="a","registry must never be truncated")
            appends=appends+1
            if mode=="append_denied" then return nil,"permission denied",13 end
            registry=registry or ""
        end
        return {read=function() return registry end,
            close=function() if mode=="close_failed" then return nil,"close failed" end; return true end,
            flush=function() if mode=="flush_failed" then return nil,"flush failed" end; return true end,
            write=function(self,s)
                if mode=="write_failed" then return nil,"disk full" end
                registry=registry .. s; return self
            end}
    end
    if path:match("SWZCDevPanel[/\\]Scripts[/\\]main%.lua$") then
        assert(access=="r"); marker_checks=marker_checks+1
        if mode=="absent" then return nil,"no such file",2 end
        return {close=function() return true end}
    end
    if path:match("state%.lua$") then
        return {read=function() return state_raw end,close=function() return true end}
    end
    error("unexpected IO " .. path)
end
loadfile=function(path)
    if path:match("actions%.lua$") then return function() return manifest end end
    if path:match("state%.lua$") then return function() return state end end
    return original_loadfile(path)
end
print=function(s) notes[#notes+1]=s end
function LoopAsync() error("unowned worker poll forbidden") end
function ExecuteInGameThread() error("unowned action dispatch forbidden") end
function MakeActionHandle() id=id+1; return id end
function ExecuteInGameThreadWithDelay(h,ms,cb) queue[h]={ms=ms,cb=cb} end
function CancelDelayedAction(h) if queue[h] then queue[h].cancelled=true end end
local function pending(ms)
    local list={}
    for h,j in pairs(queue) do if j.ms==ms and not j.cancelled then list[#list+1]=h end end
    return list
end
local function run(ms)
    local batch=pending(ms)
    for _,h in ipairs(batch) do
        local job=queue[h]; queue[h]=nil
        gameThread=true; job.cb(); gameThread=false
    end
end
local function boot() return assert(original_loadfile(scripts .. "/SWZCDevPanel.lua"))() end
local client=boot()
local called=0
client.OnAction("open_picker",function() assert(gameThread); called=called+1 end)
assert(client.IsAvailable() and #pending(250)==1 and called==0,"old clicks must not replay")
assert(registry:find("ColorsPlusProbe|",1,true))
state.open_picker=5; state_raw="click 5"; run(250)
assert(called==0 and #pending(0)==1,"dispatch must be an owned game-thread action")
run(0); assert(called==1)
assert(client.Status():find("open_seen=5",1,true) and client.Status():find("invoked=1",1,true))
-- A torn state file must not silently reset counters or consume changed bytes.
local saved_state=state; state=false; state_raw="torn file"; run(250)
assert(client.Status():find("state parse failed",1,true) and called==1)
state=saved_state; state.open_picker=6
local before_status=called; local status=client.Status()
assert(status:find("open_seen=5",1,true) and status:find("open_disk=6",1,true) and called==before_status)
run(250); run(0); assert(called==2,"same raw file must retry after failed parsing")
-- Restore the original sequence without generating an action on a reset.
state.open_picker=5; state_raw="counter reset"; run(250); assert(called==2)
called=1
run(250); assert(#pending(0)==0,"unchanged counters must not redispatch")
state.open_picker=6; state_raw="click 6"; run(250)
client.OnAction("open_picker",function() assert(gameThread); called=called+10 end)
run(0); assert(called==1,"replacing a handler invalidates its queued invocations")
assert(#pending(250)==1)
state.open_picker=7; state_raw="click 7"; run(250); run(0); assert(called==11)
state.open_picker=8; state_raw="click 8"; run(250)
local oldCallbacks={}
for _,j in pairs(queue) do oldCallbacks[#oldCallbacks+1]=j.cb end
local reloaded=boot()
reloaded.OnAction("open_picker",function() assert(gameThread); called=called+100 end)
assert(not client.IsAvailable() and #pending(250)==1 and #pending(0)==0)
gameThread=true; for _,cb in ipairs(oldCallbacks) do cb() end; gameThread=false
assert(called==11,"retired callbacks must remain inert")
state.open_picker=9; state_raw="click 9"; run(250); run(0); assert(called==111)
reloaded.Shutdown()
assert(#pending(250)==0 and not reloaded.IsAvailable())
mode="absent"
local before=appends
local absent=boot()
absent.OnAction("open_picker",function() error("absent panel dispatched") end)
assert(not absent.IsAvailable() and #pending(250)==0)
assert(appends==before,"absent panel must not create a registry")
-- Reinstall removed the registry but retained the panel's entry script.
mode="present"; registry=nil
local fresh=boot()
fresh.OnAction("open_picker",function() assert(gameThread); called=called+1 end)
assert(fresh.IsAvailable() and #pending(250)==1 and appends==before+1)
assert(registry:find("ColorsPlusProbe|",1,true) and called==111,"old counters must not replay after recreation")
state.open_picker=10; state_raw="click 10"; run(250); run(0); assert(called==112)
fresh.Shutdown()
local registered_line=registry
local again=boot(); again.Init()
assert(again.IsAvailable() and registry==registered_line and appends==before+1,"no duplicate registrations")
again.Shutdown()
registry="OtherMod|other/DevPanel" -- existing content without trailing newline
local alongside=boot(); alongside.Init()
assert(alongside.IsAvailable() and registry=="OtherMod|other/DevPanel\n" .. registered_line)
alongside.Shutdown()
for _,failure in ipairs({"read_denied","append_denied","write_failed","flush_failed","close_failed"}) do
    mode=failure; registry=nil
    local previous_checks,previous_appends=marker_checks,appends
    local failed=boot(); failed.Init()
    assert(not failed.IsAvailable() and #pending(250)==0,failure .. " must not start polling")
    assert(notes[#notes]:find("registration unavailable",1,true))
    if failure=="read_denied" then
        assert(marker_checks==previous_checks and appends==previous_appends,"unreadable is not missing")
    end
    failed.Shutdown()
end
mode="present"
local delayed=ExecuteInGameThreadWithDelay
ExecuteInGameThreadWithDelay=nil
local unsupported=boot()
unsupported.OnAction("open_picker",function() error("unsafe fallback") end)
assert(not unsupported.IsAvailable() and #pending(250)==0)
ExecuteInGameThreadWithDelay=delayed
-- The integration uses the runtime's scheduler, not a second native queue.
local adapted=boot()
local owned,retired={},{}
local native=MakeActionHandle
MakeActionHandle=function() error("adapter bypassed") end
adapted.UseScheduler(function(key,ms,cb) owned[key]={ms=ms,cb=cb} end,
    function(key) owned[key]=nil end)
adapted.OnAction("open_picker",function() assert(gameThread); called=called+1 end)
assert(next(owned)==nil and not adapted.IsAvailable(),"adapter must not poll from bootstrap")
-- Establish baseline only at explicit game-thread activation, not registration.
state.open_picker=10; state_raw="before activation"
gameThread=true; adapted.Init(); gameThread=false
assert(adapted.Status():find("scheduler=runtime",1,true))
local function tick_owned(ms)
    local batch={}; for key,j in pairs(owned) do if j.ms==ms then batch[key]=j end end
    for key,j in pairs(batch) do owned[key]=nil; gameThread=true; j.cb(); gameThread=false end
end
before=called; state.open_picker=11; state_raw="adapter click"
tick_owned(250); tick_owned(0)
assert(called==before+1 and adapted.Status():find("polls=1",1,true))
for _,j in pairs(owned) do retired[#retired+1]=j.cb end
adapted.Shutdown(); assert(next(owned)==nil)
for _,cb in ipairs(retired) do cb() end
assert(next(owned)==nil and called==before+1)
MakeActionHandle=native
io.open,loadfile,print=original_open,original_loadfile,original_print
print("Dev Panel client: registry recreation, absent panel, preserved entries, I/O failures, owned dispatch, counter baselines and reload safety passed")
