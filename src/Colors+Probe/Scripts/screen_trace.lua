-- Opt-in, read-only navigation evidence. No hooks, widget writes or color work.
-- Reacquire on each owned game-thread sample; retain only scalar log text.
local M={}
local CLASSES={
    {"WBP_CustomCharacter_Master_C","page"},
    {"WBP_CustomCharacter_Page_Outfits_C","page"},
    {"WBP_CustomCharacter_Page_Appearance_C","page"},
    {"WBP_Customization_ItemPage_C","page"},
    -- In-game (hub) editor screens.
    {"WBP_CentralUITabs_C","page"},
    {"WBP_Customization_MasterPage_C","page"},
    {"WBP_Customization_Edit_Portrait_C","page"},
    {"BitReactorActivatableWidgetStack","stack"},
    {"BitReactorActivatableWidgetTabStack","stack"},
}
function M.new(runtime,a)
    local self={}
    local generation,active,last,samples=0,false,nil,0
    local function text(v) return tostring(v):gsub("[\r\n\t]"," "):sub(1,1024) end
    local function log(s) runtime.log("SCREEN TRACE | " .. s) end
    local function object(v)
        v=a.unwrap(v); assert(a.live(v),"Object unavailable"); return v
    end
    local function name(v) return a.name(object(v)) end
    local function read(o,fn)
        local ok,value=pcall(function() object(o); return fn() end)
        return ok and text(value) or ("<error: " .. text(value) .. ">")
    end
    local function optional(v)
        v=a.unwrap(v); return a.live(v) and name(v) or "<none/invalid>"
    end
    local function state(o)
        return "activated=" .. read(o,function() return o:IsActivated() end)
            .. " | in_viewport=" .. read(o,function() return o:IsInViewport() end)
            .. " | parent=" .. read(o,function() return optional(o:GetParent()) end)
    end
    local function capture()
        local lines,seen={},{}
        local reads=0
        local function add(s) lines[#lines+1]=s end
        local function inspect(o,kind)
            o=object(o); local full=name(o)
            if seen[full] then return end
            seen[full]=true
            -- Require a runtime instance path; skip CDOs and asset templates.
            if full:find("Default__",1,true) or not full:find("/Engine/Transient.",1,true) then
                add("SKIPPED | " .. text(full)); return
            end
            reads=reads+1; if reads>128 then add("LIMIT | widget state budget=128"); return end
            if kind=="page" then add("PAGE | " .. text(full) .. " | " .. state(o)); return end
            add("STACK | " .. text(full) .. " | parent=" .. read(o,function() return optional(o:GetParent()) end))
            -- Stack-returned screens are discovery evidence, never adopted as owners.
            local current
            add("STACK ACTIVE | " .. text(full) .. " | widget=" .. read(o,function()
                current=a.unwrap(o:GetActiveWidget()); return optional(current)
            end))
            if a.live(current) then inspect(current,"page") end
            local members
            add("STACK MEMBERS | " .. text(full) .. " | count=" .. read(o,function()
                members=a.values(o.WidgetList); return #members
            end))
            if members then
                for i=1,math.min(#members,32) do
                    add("MEMBER | stack=" .. text(full) .. " | index=" .. i .. " | widget=" .. optional(members[i]))
                    if a.live(a.unwrap(members[i])) then inspect(members[i],"page") end
                end
                if #members>32 then add("LIMIT | stack members omitted=" .. (#members-32)) end
            end
        end
        for _,spec in ipairs(CLASSES) do
            local ok,err=pcall(function()
                local values=FindAllOf(spec[1]) or {}
                assert(type(values)=="table","Unsupported widget list")
                local count,shown=0,0
                for _,o in pairs(values) do
                    count=count+1; assert(count<=4096,"Widget scan limit")
                    if shown<32 then
                        shown=shown+1
                        local good,why=pcall(inspect,o,spec[2])
                        if not good then add("READ ERROR | class=" .. spec[1] .. " | " .. text(why)) end
                    end
                end
                add("CLASS | " .. spec[1] .. " | count=" .. count .. " | omitted=" .. (count-shown))
            end)
            if not ok then add("SCAN ERROR | class=" .. spec[1] .. " | " .. text(err)) end
        end
        table.sort(lines)
        return lines,table.concat(lines,"\n")
    end
    function self.stop(reason)
        generation=generation+1; runtime:cancel("screen-trace:sample")
        if active then log("STOP | " .. (reason or "command") .. " | samples=" .. samples) end
        active=false; last=nil
    end
    local function sample(token)
        if not active or generation~=token or not runtime.alive then return end
        samples=samples+1
        local ok,lines,signature=pcall(capture)
        if not ok then log("FAILED | " .. text(lines)); self.stop("capture failed"); return end
        if signature~=last then
            log("CHANGE | sample=" .. samples)
            for _,line in ipairs(lines) do log("sample=" .. samples .. " | " .. line) end
            last=signature
        end
        if samples>=60 then self.stop("60 samples complete"); return end
        runtime:after("screen-trace:sample",1000,function() sample(token) end)
    end
    function self.start()
        self.stop("restarted"); active=true; samples=0
        local token=generation
        log("START | 60 samples at 1s intervals | read-only; navigate with CP/DP closed")
        runtime:after("screen-trace:sample",1000,function() sample(token) end)
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then log("Console unavailable"); return end
        runtime:console("colors_screens",function(_,parameters,output)
            parameters=parameters or {}
            local action=string.lower(tostring(parameters[1] or "start"))
            local message
            if #parameters>1 or (action~="start" and action~="stop") then
                message="Usage: colors_screens [start|stop]"
            else
                runtime:after("screen-trace:command",1,function()
                    if action=="stop" then self.stop("command") else self.start() end
                end)
                message="Queued screen trace " .. action .. "; close the console and navigate."
            end
            log(message)
            if output then pcall(function() output:Log(message) end) end
        end)
        log("Ready: colors_screens [start|stop] (read-only)")
    end
    return self
end
return M
