-- Read-only test of actual CommonUI press/click handlers, NOT delegate
-- signatures or plain UserWidget preview events. No widgets/input/tint writes.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local clicks=assert(loadfile(directory .. "button_clicks.lua"))()
local HOOKS={
    {"/Script/CommonUI.CommonButtonBase:HandleButtonPressed","common.press"},
    {"/Script/CommonUI.CommonButtonBase:HandleButtonReleased","common.release"},
    {"/Script/CommonUI.CommonButtonBase:HandleButtonClicked","common.click"},
    {"/Script/BitReactorGame.BitReactorButtonBase:HandleInternalButtonPressed","game.press"},
    {"/Script/BitReactorGame.BitReactorButtonBase:HandleInternalButtonReleased","game.release"},
}
function M.new(runtime)
    local self={window=nil}
    local function log(s) runtime.log("CLICK EVENTS | " .. s) end
    local function report(w,reason)
        log("REPORT | " .. reason .. " | handlers_observed=" .. w.total .. " | page_scoped=" .. w.scoped)
        for _,spec in ipairs(HOOKS) do
            local row=w.counts[spec[2]]
            if row then log(spec[2] .. " | observed=" .. row.total .. " | page_scoped=" .. row.scoped) end
        end
        for i,name in ipairs(w.samples) do log("sample[" .. i .. "] | " .. name) end
    end
    function self.stop(reason)
        local w=self.window; self.window=nil
        runtime:cancel("click-events:watch"); runtime:cancel("click-events:expiry")
        if w then report(w,reason or "stop"); log("STOP | no game state modified") end
        return true
    end
    local function observe(label,context)
        local w=self.window; if not w or w.done then return end
        -- Only the documented callback parameter is unwrapped. Do not retain
        -- it or traverse/mutate a tree while Slate is dispatching this event.
        local o=context:get()
        if not o or not o:IsValid() then return end
        local full=o:GetFullName()
        local path=full:match("^[^ ]+ (.+)$")
        if not path then return end
        local scoped=path:sub(1,#w.prefix)==w.prefix
        local row=w.counts[label] or {total=0,scoped=0}; w.counts[label]=row
        row.total=row.total+1; w.total=w.total+1
        if scoped then row.scoped=row.scoped+1; w.scoped=w.scoped+1 end
        -- Pooled buttons may not have a page-prefixed outer. Count those as
        -- unscoped evidence only; never mistake it for a verified picker event.
        if #w.samples<4 and not w.seen[full] then
            w.seen[full]=true; w.samples[#w.samples+1]=(scoped and "page | " or "unscoped | ") .. full:sub(1,400)
        end
        if w.total>=500 then w.done=true end
        -- No return override, FEventReply, pointer event or delegate binding.
    end
    local function watch(w)
        runtime:after("click-events:watch",1000,function()
            if self.window~=w then return end
            local ok=pcall(runtime.color_ui.validate_picker,w.binding)
            if not ok or w.done then self.stop(w.done and "500-event limit" or "color page changed"); return end
            watch(w)
        end)
    end
    function self.start()
        self.stop("replaced")
        local ok,err=pcall(function()
            assert(runtime.color_ui and runtime.picker and not runtime.picker.active,"Close Custom Color and open stock color swatches first")
            local b=runtime.color_ui.prepare_picker()
            local installed=0
            for _,spec in ipairs(HOOKS) do
                local label=spec[2]
                local good
                if label=="common.click" then
                    clicks.get(runtime).observe("click-probe",function(context) observe(label,context) end)
                    good=true
                else good=runtime:hook(spec[1],function(context) observe(label,context) end) end
                if good then installed=installed+1 end
            end
            assert(installed>0,"No native click-handler hook available")
            local w={binding=b,prefix=assert(b.page:match("^[^ ]+ (.+)$")) .. ".",
                counts={},samples={},seen={},total=0,scoped=0}
            self.window=w; watch(w)
            runtime:after("click-events:expiry",60000,function() if self.window==w then self.stop("60s timeout") end end)
            log("START | handlers=" .. installed .. " | click stock swatches; probe only observes | colors_click stop for counts")
        end)
        if not ok then self.stop("start failure"); log("REFUSED | " .. tostring(err)) end
        return ok
    end
    function self.attach()
        runtime:console("colors_click",function(_,params)
            params=params or {}; local action=tostring(params[1] or "start"):lower()
            if #params>1 or (action~="start" and action~="stop") then log("Usage: colors_click start|stop"); return end
            runtime:after("click-events:command",1,function()
                if action=="start" then self.start() else self.stop("console stop") end
            end)
            log("QUEUED | " .. action .. " | close the console")
        end)
    end
    return self
end
return M
