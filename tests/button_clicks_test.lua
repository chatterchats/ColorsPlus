local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/button_clicks.lua"))()
local hook,installs
installs=0
local runtime={hook=function(_,path,callback)
    assert(path=="/Script/CommonUI.CommonButtonBase:HandleButtonClicked")
    installs=installs+1; hook=callback; return true
end}
local clicks=module.get(runtime)
assert(module.get(runtime)==clicks)
local seen={}
local function receive(action) seen[#seen+1]=action end
clicks.bind("Button /Test.Apply","view1","apply",receive)
clicks.bind("Button /Test.Cancel","view1","cancel",receive)
local observations=0
clicks.observe("probe",function() observations=observations+1 end)
local function event(identity,valid)
    local object={IsValid=function() return valid~=false end,GetFullName=function() return identity end}
    assert(hook({get=function() return object end})==nil,"No native return override")
end
event("Button /Test.Apply"); event("Button /Test.Cancel")
assert(table.concat(seen,",")=="apply,cancel","Clicks survive without IsPressed polling")
event("Button /Other.Apply"); event("Button /Test.Apply",false)
assert(#seen==2 and observations==4 and installs==1)
assert(not pcall(clicks.bind,"Button /Test.Apply","view1","apply",receive))
clicks.retire("view1"); event("Button /Test.Apply"); assert(#seen==2)
clicks.bind("Button /Test.NewApply","view2","apply",receive)
event("Button /Test.Apply"); assert(#seen==2,"Old view never drives a new picker")
event("Button /Test.NewApply"); assert(#seen==3 and installs==1)
clicks.retire("view2"); clicks.observe("probe",nil)
hook({get=function() error("Inactive router must not touch objects") end})
local failed=module.get({hook=function() return false end})
assert(not pcall(failed.bind,"Button /Test.Fail","view3","apply",receive))
assert(not next(failed.routes) and not failed.installed)
print("Button clicks: native routing, fast events, foreign/stale rejection, shared observer and hook failure passed")
