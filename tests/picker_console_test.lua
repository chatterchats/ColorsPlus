-- luajit tests/picker_console_test.lua src/Colors+Probe/Scripts
local scripts=assert(arg[1])
local registry=assert(loadfile(scripts .. "/hook_registry.lua"))()
local console=assert(loadfile(scripts .. "/picker_console.lua"))()
local commands,jobs,logs,replies={},{},{},{}
local serial,registrations,opens,closes,applies,restores=0,0,0,0,0,0
local game_thread=false
function RegisterConsoleCommandHandler(name,cb)
    assert(not commands[name]); commands[name]=cb; registrations=registrations+1
end
function MakeActionHandle() serial=serial+1; return serial end
function ExecuteInGameThreadWithDelay(handle,ms,cb) assert(ms==1); jobs[handle]=cb end
function CancelDelayedAction() return true end -- deliberately deliver cancelled jobs
local output={Log=function(_,s) assert(not game_thread); replies[#replies+1]=s end}
local function boot()
    local runtime=registry.start("PickerConsoleTestRuntime")
    runtime.log=function(s) logs[#logs+1]=s end
    runtime.picker={open=function() assert(game_thread); opens=opens+1 end,
        apply=function() assert(game_thread); applies=applies+1 end,
        close=function(reason) assert(game_thread and reason=="console close"); closes=closes+1 end}
    runtime.tint={restore=function() assert(game_thread); restores=restores+1 end}
    console.attach(runtime)
    return runtime
end
local function run()
    local pending=jobs; jobs={}; game_thread=true
    for _,cb in pairs(pending) do cb() end
    game_thread=false
end
local function command(parameters)
    assert(commands.colors_picker("colors_picker",parameters,output)==true)
end
local first=boot()
command({}); assert(opens==0); run(); assert(opens==1)
command({"OPEN"}); command({"open"}); run(); assert(opens==2,"coalesce repeated opens")
command({}); command({"close"}); run(); assert(opens==2 and closes==1,"close supersedes open")
command({"invalid"}); command({"open","extra"}); run(); assert(opens==2 and closes==1)
assert(replies[#replies]:find("Usage:",1,true))
command({}); first:cancel("panel:open_picker"); run(); assert(opens==2,"navigation cancellation")
local picker=first.picker; first.picker=nil; first.tint_disabled_reason="session held"
command({}); run(); assert(replies[#replies]=="Disabled: session held")
first.picker=picker
command({})
local second=boot(); run(); assert(opens==2,"retired callbacks must not open")
assert(registrations==1,"same-state reload must reuse console registration")
command({}); run(); assert(opens==3,"command routes to replacement runtime")
command({"apply"}); run(); assert(applies==1)
second.picker.close=function(reason) assert(game_thread and reason=="console restore"); closes=closes+1 end
command({"restore"}); run(); assert(restores==1)
second.picker.open=function() assert(game_thread and second.picker_trace_next==true); opens=opens+1 end
command({"trace"}); run(); assert(opens==4 and second.picker_trace_next==nil,"Tracing is explicit and one-shot")
second:teardown(); command({}); run(); assert(opens==4)
RegisterConsoleCommandHandler=nil
console.attach(second)
assert(logs[#logs]:find("Unavailable:",1,true))
print("Colors+Probe standalone picker console tests passed")
