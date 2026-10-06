local scripts=assert(arg[1])
local jobs,hooks,commands,logs={},{},{},{}
local healthy=true
local binding={page="WBP_Customization_ItemPage_C /Game/Test.Page"}
local runtime={picker={},log=function(s) logs[#logs+1]=s end,color_ui={
    prepare_picker=function() assert(healthy); return binding end,
    validate_picker=function(b) assert(healthy and b==binding) end}}
function runtime:after(k,ms,fn) jobs[k]={ms=ms,fn=fn} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(k,fn) commands[k]=fn end
local hook_count=0
function runtime:hook(path,fn)
    assert(not path:find("__DelegateSignature",1,true) and not path:find("UserWidget",1,true))
    if not hooks[path] then hook_count=hook_count+1; hooks[path]=fn end
    return true
end
local function run(k) local j=assert(jobs[k]); jobs[k]=nil; j.fn() end
local probe=assert(loadfile(scripts .. "/click_event_probe.lua"))().new(runtime)
probe.attach(); commands.colors_click(nil,{"invalid"}); assert(not jobs["click-events:command"])
commands.colors_click(nil,{"start"}); assert(not probe.window); run("click-events:command")
assert(probe.window and hook_count==5 and jobs["click-events:expiry"].ms==60000)
local function event(path,full)
    local object={IsValid=function() return true end,GetFullName=function() return full end}
    assert(hooks[path]({get=function() return object end})==nil,"Native return must never be overridden")
end
local press="/Script/CommonUI.CommonButtonBase:HandleButtonPressed"
local release="/Script/CommonUI.CommonButtonBase:HandleButtonReleased"
-- A press/release pair entirely between polls is retained as scalar evidence.
event(press,"WBP_Button_C /Game/Test.Page.WidgetTree.Button_1")
event(release,"WBP_Button_C /Game/Test.Page.WidgetTree.Button_1")
assert(probe.window.total==2 and probe.window.scoped==2)
event(press,"WBP_Button_C /Game/Other.Button")
assert(probe.window.total==3 and probe.window.scoped==2)
assert(probe.window.counts["common.press"].total==2)
for i=1,10 do event(press,"WBP_Button_C /Game/Test.Page.WidgetTree.Button_" .. i) end
assert(#probe.window.samples==4,"Sample identities are bounded")
local stale=jobs["click-events:watch"].fn
probe.stop("test"); assert(not probe.window and not jobs["click-events:watch"] and not jobs["click-events:expiry"])
assert(probe.start() and hook_count==5,"Hooks reused within runtime, not duplicated")
stale(); assert(probe.window)
for _=1,510 do event(press,"WBP_Button_C /Game/Test.Page.WidgetTree.Button") end
assert(probe.window.total==500 and probe.window.done)
run("click-events:watch"); assert(not probe.window)
assert(probe.start()); healthy=false; run("click-events:watch"); assert(not probe.window)
healthy=true; runtime.picker.active={}; assert(not probe.start()); runtime.picker.active=nil
assert(probe.start()); run("click-events:expiry"); assert(not probe.window)
hooks[press]({get=function() error("Inactive callbacks must not touch native data") end})
assert(table.concat(logs,"\n"):find("page_scoped=",1,true))
print("Click-event probe: ordinary-handler hooks, between-poll clicks, scoping, bounds, stale jobs, expiry and read-only callbacks passed")
