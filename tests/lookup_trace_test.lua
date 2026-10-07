-- Run: tools/run-tests.sh lookup_trace
local scripts=assert(arg[1])
local here=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])") or "./"
local factory=assert(loadfile(scripts .. "/lookup_trace.lua"))()
local logs,commands,finds,scans={},{},0,0
local live={IsValid=function() return true end}
local dead={IsValid=function() return false end}
function StaticFindObject(path,extra)
    finds=finds+1; assert(extra==nil)
    if path=="/Game/Test.Missing" then return dead end
    return live,"second"
end
function FindAllOf(class)
    scans=scans+1
    if class=="Empty" then return nil end
    return {live,live}
end
function RegisterConsoleCommandHandler() end
local runtime={log=function(s) logs[#logs+1]=s end,perf={window=nil}}
function runtime:console(name,cb) commands[name]=cb end
-- Frames are attributed to scripts under the given directory: here, the tests.
local trace=factory.new(runtime,here)
trace.attach()
assert(commands.colors_lookups and logs[#logs]:find("Ready",1,true))
local function last() return logs[#logs] end
-- Off until started: calls pass through without logging.
local quiet=#logs; assert(StaticFindObject("/Game/Test.Obj_9")==live and #logs==quiet)
local replies={}
local output={Log=function(_,s) replies[#replies+1]=s end}
commands.colors_lookups(nil,{"start"},output); assert(replies[1]:find("started",1,true))
finds=0
-- Results pass through unchanged, including extra returns and nil.
local value,second=StaticFindObject("/Game/Test.Obj_12")
assert(value==live and second=="second" and finds==1)
assert(last():find("StaticFindObject | ms=",1,true) and last():find("window=none | found | path=/Game/Test.Obj_12",1,true))
assert(last():find("at=lookup_trace_test:",1,true),"caller line recorded")
runtime.perf.window=3
assert(StaticFindObject("/Game/Test.Missing")==dead and last():find("window=w3 | missing",1,true))
local all=FindAllOf("Thing"); assert(#all==2 and last():find("FindAllOf | ms=",1,true) and last():find("count=2",1,true))
assert(FindAllOf("Empty")==nil and last():find("count=0",1,true))
-- Instance numbers group into one shape; the summary orders by cost.
for i=1,5 do StaticFindObject("/Game/Test.Obj_" .. i) end
logs={}; local rows=trace.summary()
assert(logs[1]:find("SUMMARY BEGIN | active=true | calls=9",1,true) and logs[#logs]=="LOOKUP TRACE | SUMMARY END")
local grouped=false
for _,row in ipairs(rows) do if row.key:find("/Game/Test.Obj_N",1,true) and row.e.n==5 then grouped=true end end
assert(grouped,"Obj_1..5 share a shape and call site; Obj_12's call site is separate")
for i=2,#rows do assert(rows[i-1].e.ms>=rows[i].e.ms) end
-- Console: summary and reset.
commands.colors_lookups(nil,{"reset"},output); assert(replies[2]=="Lookup tally reset.")
logs={}; trace.summary(); assert(logs[1]:find("calls=0",1,true))
commands.colors_lookups(nil,{"stop"},output); assert(replies[3]:find("stopped",1,true))
quiet=#logs; StaticFindObject("/Game/Test.Obj_1"); assert(#logs==quiet,"stopped trace is silent")
commands.colors_lookups(nil,{"bogus"},output); assert(replies[4]:find("Usage",1,true))
-- A Lua reload wraps the stored originals, never the previous wrapper.
local before=finds
local again=factory.new(runtime,here); again.attach()
StaticFindObject("/Game/Test.Obj_1"); assert(finds==before+1,"one native call per lookup after reload")
print("Lookup trace: pass-through results, timing/window/caller lines, shape grouping, summary, console and reload passed")
