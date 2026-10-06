-- One CommonUI handler per runtime. Retain scalar identities, never widgets.
-- Receivers may only latch intent; callers consume it after native dispatch.
local M={}
local HOOK="/Script/CommonUI.CommonButtonBase:HandleButtonClicked"
function M.get(runtime)
    if runtime.button_clicks then return runtime.button_clicks end
    local self={routes={},observers={}}
    local function install()
        if self.installed then return end
        assert(runtime:hook(HOOK,function(context)
            if next(self.routes) then
                local object=context:get()
                if object and object:IsValid() then
                    local route=self.routes[object:GetFullName()]
                    if route then route.receive(route.action) end
                end
            end
            for _,callback in pairs(self.observers) do callback(context) end
            -- No return override or UI writes while CommonUI is dispatching.
        end),"Native button click handler unavailable")
        self.installed=true
    end
    function self.bind(identity,owner,action,receive)
        install()
        assert(not self.routes[identity],"Duplicate button click route")
        self.routes[identity]={owner=owner,action=action,receive=receive}
    end
    function self.retire(owner)
        for identity,route in pairs(self.routes) do
            if route.owner==owner then self.routes[identity]=nil end
        end
    end
    function self.observe(key,callback)
        install(); self.observers[key]=callback
    end
    runtime.button_clicks=self
    return self
end
return M
