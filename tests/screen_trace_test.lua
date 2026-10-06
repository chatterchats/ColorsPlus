local scripts=assert(arg[1])
local registry=assert(loadfile(scripts .. "/hook_registry.lua"))()
local module=assert(loadfile(scripts .. "/screen_trace.lua"))()
local commands,jobs,logs,lists={},{},{},{}
local serial,registrations,scans=0,0,0
local on_thread=false
function RegisterConsoleCommandHandler(n,cb) assert(not commands[n]); commands[n]=cb; registrations=registrations+1 end
function MakeActionHandle() serial=serial+1; return serial end
function ExecuteInGameThreadWithDelay(h,ms,cb) assert(ms==1 or ms==1000); jobs[h]=cb end
function CancelDelayedAction() end -- cancelled callbacks deliberately still delivered
function FindAllOf(c) assert(on_thread); scans=scans+1; return lists[c] end
local function widget(class,id)
    local o={full=class .. " /Engine/Transient.Layout.WidgetTree." .. id,active=true}
    function o:IsValid() assert(on_thread); return not self.invalid end
    function o:GetFullName() assert(on_thread and not self.invalid); return self.full end
    function o:IsActivated() assert(on_thread); return self.active end
    function o:IsInViewport() assert(on_thread); return false end
    function o:GetParent() assert(on_thread); return self.parent end
    return o
end
local page=widget("WBP_Customization_ItemPage_C","WBP_Customization_ItemPage_C_1")
local radial=widget("WBP_TestActualRadial_C","Radial_2")
local databank=widget("WBP_TestDatabank_C","Databank_3")
local stack=widget("BitReactorActivatableWidgetTabStack","Menus")
stack.current=page; stack.WidgetList={radial,page}
function stack:GetActiveWidget() assert(on_thread); return self.current end
lists.WBP_Customization_ItemPage_C={page}
lists.BitReactorActivatableWidgetTabStack={stack}
-- A cached master is evidence, not proof of attachment or ownership.
local master=widget("WBP_CustomCharacter_Master_C","WBP_CustomCharacter_Master_C_9"); master.active=false
lists.WBP_CustomCharacter_Master_C={master}
local a={unwrap=function(o) return o end,live=function(o) return o and o:IsValid() end,
    name=function(o) return o:GetFullName() end,values=function(v) assert(type(v)=="table"); return v end}
local function boot()
    local r=registry.start("ScreenTraceTestRuntime")
    r.log=function(s) logs[#logs+1]=s end
    local t=module.new(r,a); t.attach(); return r,t
end
local function run()
    local pending=jobs; jobs={}; on_thread=true
    for _,cb in pairs(pending) do cb() end
    on_thread=false
end
local function has(s) return table.concat(logs,"\n"):find(s,1,true) end
local output={Log=function() assert(not on_thread,"OutputDevice must not be retained") end}
local function command(p) assert(commands.colors_screens("colors_screens",p or {},output)==true) end
local r,t=boot(); assert(scans==0 and not next(jobs),"no automatic polling")
command({"bad"}); assert(not next(jobs)); command({"start","extra"}); assert(not next(jobs))
command(); assert(scans==0); run(); assert(scans==0); run()
assert(has("CHANGE | sample=1") and has("STACK ACTIVE | " .. stack.full .. " | widget=" .. page.full))
assert(has("MEMBER | stack=" .. stack.full .. " | index=1 | widget=" .. radial.full))
assert(has("PAGE | " .. master.full .. " | activated=false"))
local count=#logs; run(); assert(#logs==count,"unchanged state is quiet")
page.active=false; stack.current=radial; run()
assert(has("CHANGE | sample=3") and has("STACK ACTIVE | " .. stack.full .. " | widget=" .. radial.full))
stack.current=databank; stack.WidgetList={databank}; run()
assert(has("PAGE | " .. databank.full),"trace intentionally crosses creator exit")
-- Stale/failed reads are explicit and cannot cause writes or stop other scans.
page.invalid=true
function stack:GetActiveWidget() error("read failed\nline two") end
run(); assert(has("read failed line two") and has("READ ERROR | class=WBP_Customization_ItemPage_C"))
-- Bound to sixty samples and no retained polling afterwards.
for _=6,60 do run() end
assert(has("STOP | 60 samples complete | samples=60") and not next(jobs))
-- Restart/stop invalidate old samples, even when the scheduler delivers them.
command(); run(); command({"stop"}); run(); run(); assert(not next(jobs))
command(); run(); command(); run(); run()
command({"stop"}); run(); run(); assert(not next(jobs))
-- Reload owns both command and sample jobs, and reuses the console dispatcher.
command(); run(); local before=scans
local replacement=boot(); run(); assert(scans==before and registrations==1)
command(); run(); replacement:teardown(); before=scans; run(); assert(scans==before)
-- Oversized candidate sets and default/template identities are bounded/skipped.
page.invalid=false; lists.WBP_CustomCharacter_Master_C={}
for i=1,40 do lists.WBP_CustomCharacter_Master_C[i]=widget("WBP_CustomCharacter_Master_C","Master_" .. i) end
local template=widget("WBP_CustomCharacter_Page_Outfits_C","Default__Template")
function template:IsActivated() error("template must not be read") end
lists.WBP_CustomCharacter_Page_Outfits_C={template}
local final=boot(); command(); run(); run()
assert(has("CLASS | WBP_CustomCharacter_Master_C | count=40 | omitted=8") and has("SKIPPED | " .. template.full))
final:teardown(); run()
RegisterConsoleCommandHandler=nil; module.new(final,a).attach(); assert(has("Console unavailable"))
print("Screen trace: read-only discovery, transitions, bounds, errors, timeout, stop and reload ownership passed")
