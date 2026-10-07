local scripts=assert(arg[1])
local factory=assert(loadfile(scripts .. "/logging.lua"))()
local old_date,old_open,old_print=os.date,io.open,print
local lines,closed={},0
io.open=function() return {write=function(self,line) lines[#lines+1]=line; return self end,
    flush=function() return true end,close=function() closed=closed+1 end} end
print=function() error("output unavailable") end
os.date=function() error("bad argument #2 to date") end
local log=factory.new("mock",7)
log.write("callback still completes\nnext line")
assert(lines[1]:find("[timestamp unavailable] [Colors+] [generation=7] callback still completes next line",1,true))
os.date=function() return "2026-09-17T00:00:00Z" end
log.write("time recovered"); assert(lines[2]:find("2026-09-17T00:00:00Z",1,true))
log.close(); assert(closed==1)
io.open=function() error("file unavailable") end
factory.new("mock",8).write("both outputs unavailable")
-- A dedicated performance sink batches a summary into one write/flush, with
-- no UE4SS mirroring unless the file is unavailable or fails mid-session.
local writes,flushes,printed=0,0,{}
local fail_write,fail_flush=false,false
io.open=function(_,mode)
    assert(mode=="a","Tester sessions must append, not overwrite earlier reports")
    return {write=function(self,line) writes=writes+1; if fail_write then return nil,"disk full" end; return self end,
        flush=function() flushes=flushes+1; if fail_flush then return nil,"flush failed" end; return true end,
        close=function() closed=closed+1 end}
end
print=function(line) printed[#printed+1]=line end
local dedicated=factory.new("perf",9,{mirror=false})
dedicated.write_batch({"first","second"})
assert(writes==1 and flushes==1 and #printed==0)
fail_flush=true; dedicated.write("flush failure")
assert(#printed==2 and printed[2]:find("flush failure",1,true))
dedicated.write("fallback persists"); assert(writes==2 and #printed==3)
fail_flush=false; fail_write=true
dedicated=factory.new("perf",10,{mirror=false}); dedicated.write("write failure")
assert(printed[#printed]:find("write failure",1,true))
io.open=function() return nil,"permission denied" end
dedicated=factory.new("perf",11,{mirror=false}); dedicated.write("open failure")
assert(printed[#printed]:find("open failure",1,true))
-- Size cap: an oversized log moves to .previous at startup, and a session
-- that crosses the cap rotates too, so the file never grows without bound.
local files,removed,renamed={},{},{}
local old_remove,old_rename=os.remove,os.rename
local function fake(name)
    local f=files[name] or {text=""}; files[name]=f
    return {write=function(self,t) f.text=f.text .. t; return self end,flush=function() return true end,
        seek=function() return #f.text end,close=function() end}
end
io.open=function(name,mode) assert(mode=="a"); return fake(name) end
os.remove=function(name) removed[#removed+1]=name; files[name]=nil; return true end
os.rename=function(a,b) renamed[#renamed+1]=a .. ">" .. b; files[b]=files[a]; files[a]=nil; return true end
files["x/colors_plus_probe.log"]={text=string.rep("z",200)}
local capped=factory.new("x/colors_plus_probe.log",12,{limit=150,mirror=false})
assert(renamed[1]=="x/colors_plus_probe.log>x/colors_plus_probe.previous.log" and removed[1]=="x/colors_plus_probe.previous.log")
assert(#files["x/colors_plus_probe.previous.log"].text==200 and files["x/colors_plus_probe.log"].text=="")
capped.write("small")
assert(files["x/colors_plus_probe.log"].text:find("small",1,true) and #renamed==1)
capped.write(string.rep("y",120))
assert(#renamed==2 and files["x/colors_plus_probe.previous.log"].text:find("small",1,true)
    and files["x/colors_plus_probe.log"].text:find("yyy",1,true) and not files["x/colors_plus_probe.log"].text:find("small",1,true))
os.remove,os.rename=old_remove,old_rename
os.date,io.open,print=old_date,old_open,old_print
print("Logging: timestamp and output failures do not abort callers; timestamp recovery; size cap rotates to .previous")
