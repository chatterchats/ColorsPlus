local scripts=assert(arg[1])
local events=assert(loadfile(scripts .. "/context_events.lua"))()
local order,logs={},{}
local runtime={log=function(s) logs[#logs+1]=s end}
local probe={}
local tint={context_changed=function(reason,identity) order[#order+1]="tint:" .. reason .. ":" .. tostring(identity) end}
events.attach(runtime,probe,tint)

-- Player build: no skin-enable, no dev tools; the backend still sees every event.
probe.on_context_event("page closed","master")
assert(#order==1 and order[1]=="tint:page closed:master")

-- Skin preview stops before the backend; dev handlers wrap both, in order.
order={}
runtime.skin_enable={}; runtime.skin_enable.stop=function(reason) order[#order+1]="skin:" .. reason end
runtime.dev_context={before=function(reason) order[#order+1]="before:" .. reason end,
    after=function(reason) order[#order+1]="after:" .. reason end}
probe.on_context_event("UpdateCurrentCustomizationSlotVM")
assert(table.concat(order,",")=="before:UpdateCurrentCustomizationSlotVM,skin:UpdateCurrentCustomizationSlotVM,"
    .. "tint:UpdateCurrentCustomizationSlotVM:nil,after:UpdateCurrentCustomizationSlotVM")

-- A failing dev handler is logged and never hides the event from the backend.
order={}
runtime.dev_context={before=function() error("probe broke") end,after=function() error("trace broke") end}
probe.on_context_event("creator closed")
assert(table.concat(order,",")=="skin:creator closed,tint:creator closed:nil")
assert(#logs==2 and logs[1]:find("before failed",1,true) and logs[2]:find("after failed",1,true))
print("Context events: production routing, skin stop order, dev wrapping and dev failure isolation passed")
