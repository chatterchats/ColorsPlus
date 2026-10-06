local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/call_trace.lua"))()
local logs,jobs={},{}
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(key,delay,fn) assert(delay==10000); jobs[key]=fn end
function runtime:cancel(key) jobs[key]=nil end
local trace=module.new(runtime,{limit=3})
local function pack(...) return {n=select("#",...),...} end
local function has(s)
    for _,line in ipairs(logs) do if line:find(s,1,true) then return true end end
    return false
end
local opaque=setmetatable({},{__index=function() error("must not inspect native value") end})
local result=pack(trace.call("inactive",function(a) return a,nil,false,nil end,opaque))
assert(result.n==4 and result[1]==opaque and result[3]==false and #logs==0)
local first=trace.start("open\nreason")
local expired=jobs["call-trace:expiry"]
result=pack(trace.call("read",function(a) return a,nil,false,nil end,opaque))
assert(result.n==4 and result[1]==opaque and result[3]==false)
assert(has("call=1 | BEGIN | read") and has("call=1 | RETURN | read"))
local ok,err=pcall(trace.call,"bad",function() error("native test error",0) end)
assert(not ok and err=="native test error" and has("call=2 | ERROR | bad | native test error"))
assert(not has("call=2 | RETURN"))
trace.call("outer",function() trace.call("past cap",function() return 7 end) end)
assert(not trace.window and not jobs["call-trace:expiry"] and has("call limit"))
assert(has("call=3 | RETURN | outer") and not has("BEGIN | past cap"))
local second=trace.start("second")
expired(); trace.stop(first,"stale close"); assert(trace.window==second)
trace.call("replace within call",function() trace.start("third") end)
assert(has("window=2 | call=1 | RETURN | replace within call"))
jobs["call-trace:expiry"](); assert(not trace.window and has("time limit"))

-- Owned jobs must check cancellation and runtime retirement before tracing.
local queue,id={},0
MakeActionHandle=function() id=id+1; return id end
CancelDelayedAction=function() end
ExecuteInGameThreadWithDelay=function(handle,_,fn) queue[handle]=fn end
local owned=assert(loadfile(scripts .. "/hook_registry.lua"))().start("ColorsPlusCallTraceTest")
owned.log=runtime.log
owned.call_trace=module.new(owned)
owned.call_trace.start("owned test")
local ran=0
owned:after("snapshot:test",1,function() ran=ran+1 end)
queue[owned.actions["snapshot:test"].handle]()
assert(ran==1 and has("BEGIN | JOB snapshot:test") and has("RETURN | JOB snapshot:test"))
owned:after("cancelled",1,function() error("cancelled callback ran") end)
local cancelled=queue[owned.actions.cancelled.handle]
owned:cancel("cancelled"); cancelled()
assert(not has("JOB cancelled"))
owned:after("retired",1,function() error("retired callback ran") end)
local retired=queue[owned.actions.retired.handle]
owned:teardown(); retired(); assert(not has("JOB retired"))

-- Exercise both standard-library layouts, regardless of the test interpreter.
-- UE4SS provides table.unpack without the Lua 5.1 global unpack alias.
do
    local global_unpack,table_unpack=unpack,table.unpack
    local native_unpack=assert(table_unpack or global_unpack)
    local passed,failure=pcall(function()
        for _,layout in ipairs({"table-only","global-only"}) do
            _G.unpack=layout=="global-only" and native_unpack or nil
            table.unpack=layout=="table-only" and native_unpack or nil
            local compatible=assert(loadfile(scripts .. "/call_trace.lua"))().new(runtime)
            local window=compatible.start(layout)
            local values=pack(compatible.call("multiple returns",function() return opaque,nil,false,nil end))
            assert(values.n==4 and values[1]==opaque and values[3]==false,layout)
            assert(pack(compatible.call("no returns",function() end)).n==0,layout)
            assert(pack(compatible.call("nil return",function() return nil end)).n==1,layout)
            compatible.stop(window,"complete")
        end
    end)
    _G.unpack,table.unpack=global_unpack,table_unpack
    assert(passed,failure)
end
print("Call tracing: transparent returns/errors, bounded windows, nesting and cancelled/retired jobs passed")
