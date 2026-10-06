-- Session provenance is tested without engine calls or real filesystem writes.
local scripts=assert(arg[1])
local guard=assert(loadfile(scripts .. "/recovery_session.lua"))()
local original={open=io.open,rename=os.rename,remove=os.remove,mod=ModRef}
local files,shared,logs,fail={}, {}, {}
local KEY="ColorsPlusProbe.RecoveryProcess.v1"
local DIR="mock/"
local COUNTER,STAMP=DIR .. "process_session_counter.txt",DIR .. "recovery_session.txt"
local TINT,SELECTION=DIR .. "tint_recovery.txt",DIR .. "default_selection_recovery.txt"
local EDITOR=DIR .. "editor_recovery.txt"
local PREVIOUS=EDITOR .. ".previous"
local runtime={log=function(s) logs[#logs+1]=s end}
io.open=function(path,mode)
    if fail=="read" and mode=="r" then return nil,"denied",13 end
    if fail=="write" and mode=="w" then return nil,"denied",13 end
    if mode=="r" and files[path]==nil then return nil,"not found",2 end
    if mode=="w" then files[path]="" end
    return {read=function(_,n) return files[path]:sub(1,n) end,
        write=function(self,s) files[path]=files[path] .. s; return self end,
        flush=function() if fail=="flush" then return nil end; return true end,
        close=function() return true end}
end
os.rename=function(from,to)
    if fail=="archive" and to:find(".archive-",1,true) then return nil,"locked" end
    if fail=="replace" and from==STAMP .. ".tmp" then return nil,"locked" end
    assert(files[from]~=nil,"missing rename source: " .. from)
    assert(files[to]==nil,"Windows rename must not clobber: " .. to)
    files[to],files[from]=files[from],nil; return true
end
os.remove=function(path) assert(files[path]~=nil); files[path]=nil; return true end
local function mod()
    return {GetSharedVariable=function(_,key) return shared[key] end,
        SetSharedVariable=function(_,key,v)
            assert(type(v)=="string","Only scalar strings may be shared")
            if fail~="shared" then shared[key]=v end
        end}
end
local function has(s) for _,line in ipairs(logs) do if line:find(s,1,true) then return true end end end
local function reset()
    files,shared,logs={}, {}, {}; fail=nil; ModRef=mod(); runtime.process_session=nil
end
local function prepare() return guard.prepare(runtime,DIR) end
reset(); local ok,mode=prepare()
assert(ok and mode=="first-attach/new-process")
assert(files[COUNTER]=="1\n" and files[STAMP]=="colors-process-v1:1\n")
assert(shared[KEY]=="colors-process-v1:1" and runtime.process_session==shared[KEY])
-- New Lua state but same UE4SS process: shared marker persists, disk payloads
-- remain unchanged for normal backend validation/recovery.
files[TINT],files[SELECTION]="rgb journal","selection journal"
files[EDITOR]="editor journal"
files[DIR .. "zone2_editor_recovery.txt"]="second zone"
files[DIR .. "zone32_default_selection_recovery.txt"]="last zone Default"
files[DIR .. "eye_recovery.txt"]="eye journal"
files[DIR .. "skin_target_recovery.txt"]="target journal"
files[DIR .. "zabrak_picker_recovery.txt"]="Zabrak CP journal"
files[DIR .. "zone32_zabrak_picker_recovery.txt"]="last Zabrak CP zone"
files[DIR .. "zone32_zabrak_picker_recovery.txt.previous"]=""
files[DIR .. "eye_recovery.txt.previous"]=""
files[PREVIOUS]=""
ModRef=mod(); logs={}; ok,mode=prepare()
assert(ok and mode=="same-process-reload" and has("recovery_authorized=true"))
assert(files[COUNTER]=="1\n" and files[TINT]=="rgb journal" and files[SELECTION]=="selection journal")
assert(files[EDITOR]=="editor journal")
assert(files[DIR .. "zone2_editor_recovery.txt"]=="second zone")
assert(files[DIR .. "zone32_default_selection_recovery.txt"]=="last zone Default")
assert(files[DIR .. "eye_recovery.txt"]=="eye journal")
assert(files[DIR .. "skin_target_recovery.txt"]=="target journal")
assert(files[DIR .. "zabrak_picker_recovery.txt"]=="Zabrak CP journal")
assert(files[DIR .. "zone32_zabrak_picker_recovery.txt"]=="last Zabrak CP zone")
-- Full game restart: sharing resets, even if all transient object names will
-- be identical. Both records are archived before any backend sees them.
shared={}; ModRef=mod(); logs={}; ok,mode=prepare()
assert(ok and mode=="first-attach/new-process" and files[COUNTER]=="2\n")
assert(not files[TINT] and not files[SELECTION])
assert(not files[EDITOR] and files[EDITOR .. ".archive-2-1"]=="editor journal")
assert(not files[DIR .. "zone2_editor_recovery.txt"] and files[DIR .. "zone2_editor_recovery.txt.archive-2-1"]=="second zone")
assert(not files[DIR .. "zone32_default_selection_recovery.txt"] and files[DIR .. "zone32_default_selection_recovery.txt.archive-2-1"]=="last zone Default")
assert(not files[DIR .. "eye_recovery.txt"] and files[DIR .. "eye_recovery.txt.archive-2-1"]=="eye journal")
assert(not files[DIR .. "skin_target_recovery.txt"] and files[DIR .. "skin_target_recovery.txt.archive-2-1"]=="target journal")
assert(not files[DIR .. "zabrak_picker_recovery.txt"] and files[DIR .. "zabrak_picker_recovery.txt.archive-2-1"]=="Zabrak CP journal")
assert(not files[DIR .. "zone32_zabrak_picker_recovery.txt"] and files[DIR .. "zone32_zabrak_picker_recovery.txt.archive-2-1"]=="last Zabrak CP zone")
assert(files[DIR .. "zone32_zabrak_picker_recovery.txt.previous.archive-2-1"]=="")
assert(not files[DIR .. "eye_recovery.txt.previous"] and files[DIR .. "eye_recovery.txt.previous.archive-2-1"]=="")
assert(files[PREVIOUS]==nil and files[PREVIOUS .. ".archive-2-1"]=="","empty interrupted backup must not block a fresh game")
assert(files[TINT .. ".archive-2-1"]=="rgb journal" and files[SELECTION .. ".archive-2-1"]=="selection journal")
assert(files[STAMP]=="colors-process-v1:2\n" and has("no game objects touched"))
-- A deleted counter does not make an old matching disk token authoritative.
files[TINT]="old data"; files[COUNTER]=nil; files[STAMP]="colors-process-v1:1\n"
shared={}; ModRef=mod(); assert(prepare())
assert(not files[TINT] and files[TINT .. ".archive-1-1"]=="old data")
-- Existing archives must never be overwritten.
reset(); files[STAMP]="colors-process-v1:1\n"; files[TINT]="new stale"
files[TINT .. ".archive-1-1"]="earlier evidence"
assert(prepare()); assert(files[TINT .. ".archive-1-1"]=="earlier evidence")
assert(files[TINT .. ".archive-1-2"]=="new stale")
-- Legacy or conflicting same-process provenance is quarantined and held until
-- a real process restart, not bypassed by another Lua reload.
reset(); files[SELECTION]="legacy"
assert(not prepare() and not files[SELECTION] and shared[KEY .. ".Blocked"])
assert(not prepare())
shared={}; ModRef=mod(); assert(prepare())
files[TINT]="unknown in-process"; files[STAMP]="colors-process-v1:999\n"
assert(not prepare() and not files[TINT]); assert(not prepare())
-- Missing/corrupt shared API must not archive or replay anything.
reset(); files[TINT]="pending"; ModRef=nil
assert(not prepare() and files[TINT]=="pending" and files[STAMP]==nil)
reset(); files[TINT]="pending"; shared[KEY]={}
assert(not prepare() and files[TINT]=="pending")
reset(); fail="shared"; files[TINT]="pending"
assert(not prepare() and files[TINT]=="pending" and files[STAMP]==nil)
-- File failures are fail-closed and preserve the old recovery or archive.
for _,reason in ipairs({"read","write","flush","archive"}) do
    reset(); files[STAMP]="colors-process-v1:1\n"; files[TINT]="pending"; fail=reason
    assert(not prepare() and files[TINT]=="pending")
end
reset(); assert(prepare()); local stamp=files[STAMP]; fail="replace"
assert(not prepare() and files[STAMP]==stamp and not files[STAMP .. ".previous"])
reset(); files[COUNTER]="bad\n"; files[TINT]="pending"
assert(not prepare() and files[TINT]=="pending")
reset(); files[COUNTER .. ".previous"]="8\n"; files[TINT]="pending"
assert(not prepare() and files[TINT]=="pending" and files[COUNTER .. ".previous"]=="8\n")
io.open,os.rename,os.remove,ModRef=original.open,original.rename,original.remove,original.mod
print("Recovery session: hot reload authorization, fresh-process quarantine, legacy holds, archive preservation and I/O failure guards passed")
