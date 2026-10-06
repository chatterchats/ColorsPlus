--[[
    SWZCDevPanel.lua - optional client helper
    ------------------------------------------
    Colors+ local copy: owned scheduling and missing-registry recovery.
    The separately installed Dev Panel application is not modified.
    Place this helper in the mod's Scripts folder alongside:

        <YourMod>/DevPanel/actions.lua

    Usage:

        local DevPanel = require("SWZCDevPanel")

        DevPanel.OnAction("refresh", function()
            refresh_databank()
        end)

    Actions run on the game thread by default. Pass { game_thread = false } for
    pure file/logging work.

    If SWZC Dev Panel is not installed, registration simply fails quietly and
    your mod continues to work normally.
]]

local SEP = package.config:sub(1, 1)
local FRAMEWORK_FOLDER = "SWZCDevPanel"
local POLL_MS = 250

local Client = {}

local function ThisFileDir()
    local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
    return src:match("^(.*)[/\\][^/\\]+$")
end

local SCRIPT_DIR = ThisFileDir()
local MOD_DIR = SCRIPT_DIR and SCRIPT_DIR:match("^(.*)[/\\][^/\\]+$") or nil
local MODS_DIR = MOD_DIR and MOD_DIR:match("^(.*)[/\\][^/\\]+$") or nil
local DEV_DIR = MOD_DIR and (MOD_DIR .. SEP .. "DevPanel") or nil

local schema = nil
local handlers = {}
local lastCounts = {}
local started = false
local registered = false
local lastRaw = nil
local alive = true
local jobs = {}
local scheduler, cancel_scheduled
local deferred_init=false
local serial = 0
local diagnostic_sink
local health={polls=0,queued=0,invoked=0,last_error="none"}
local clients = rawget(_G, "SWZCDevPanelClients") or {}
rawset(_G, "SWZCDevPanelClients", clients)
local clientKey = MOD_DIR or SCRIPT_DIR or "default"
if clients[clientKey] then clients[clientKey].Shutdown() end
clients[clientKey] = Client

local function ReadFile(path)
    if not path then return nil end
    local f, err, code = io.open(path, "r")
    if not f then return nil, err, code end
    local s, read_err = f:read("*a")
    local closed, close_err = f:close()
    if not closed then return nil, close_err end
    if not s then return nil, read_err end
    return s
end

local function LoadTable(path)
    if not path then return nil end
    local chunk,err = loadfile(path)
    if not chunk then return nil,err end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return nil,ok and "expected table" or tostring(result) end
    return result
end

local function Id()
    return schema and schema.id or (MOD_DIR and MOD_DIR:match("([^/\\]+)$")) or "?"
end

local function Note(message)
    message=tostring(message):gsub("[\r\n]"," "):sub(1,1400)
    if diagnostic_sink then
        local ok=pcall(diagnostic_sink,"PANEL CLIENT | " .. message)
        if ok then return end
    end
    pcall(print,string.format("[SWZCDevPanel:%s] %s\n", tostring(Id()),message))
end

function Client.SetDiagnosticSink(fn) diagnostic_sink=fn end
function Client.UseScheduler(schedule, cancel)
    assert(not started, "Set client scheduler before registering actions")
    assert(type(schedule)=="function" and type(cancel)=="function", "Invalid client scheduler")
    scheduler, cancel_scheduled = schedule, cancel
    deferred_init=true -- integration explicitly calls Init on the game thread
end

local function RegistryPath()
    return MODS_DIR and (MODS_DIR .. SEP .. FRAMEWORK_FOLDER .. SEP .. "registry.txt") or nil
end

local function StatePath()
    return DEV_DIR and (DEV_DIR .. SEP .. "state.lua") or nil
end

local function Register()
    if not (MODS_DIR and DEV_DIR and schema and schema.id) then return false end
    local path = RegistryPath()
    local existing, err, code = ReadFile(path)
    local missing = existing == nil
    if missing then
        -- A fresh/reinstalled panel can legitimately have no registry yet.
        -- Only ENOENT authorizes creation; unreadable files must not be treated
        -- as empty. Check the installed entry script without executing it.
        if code ~= 2 then return false, "cannot read registry: " .. tostring(err) end
        local marker = MODS_DIR .. SEP .. FRAMEWORK_FOLDER .. SEP .. "Scripts" .. SEP .. "main.lua"
        local installed = io.open(marker, "r")
        if not installed then return false, "SWZC Dev Panel entry script unavailable" end
        local closed, close_err = installed:close()
        if not closed then return false, "cannot close install check: " .. tostring(close_err) end
        existing = ""
    end

    local line = tostring(schema.id) .. "|" .. DEV_DIR
    for l in existing:gmatch("[^\r\n]+") do
        if l == line then return true end
    end

    -- Append preserves every other mod's registration, including if another
    -- client created the file between our read and this open.
    local f, open_err = io.open(path, "a")
    if not f then return false, "cannot append registry: " .. tostring(open_err) end
    local ok, write_err = pcall(function()
        local prefix = #existing > 0 and existing:sub(-1) ~= "\n" and "\n" or ""
        assert(f:write(prefix .. line .. "\n"))
        assert(f:flush())
    end)
    local closed, close_err = f:close()
    if not ok then return false, "cannot write registry: " .. tostring(write_err) end
    if not closed then return false, "cannot close registry: " .. tostring(close_err) end
    if missing then Note("created missing registry for installed SWZC Dev Panel") end
    return true
end

local function Schedule(delay, fn)
    if not alive then return end
    serial = serial + 1
    local handle = scheduler and ("panel-client:" .. serial) or MakeActionHandle()
    local job = { active = true, cancel = cancel_scheduled or CancelDelayedAction }
    jobs[handle] = job
    local function callback()
        if not alive or not job.active or jobs[handle] ~= job then return end
        job.active = false
        jobs[handle] = nil
        local ok, err = pcall(fn)
        if not ok then Note("scheduled callback error: " .. tostring(err)) end
    end
    if scheduler then scheduler(handle, delay, callback)
    else ExecuteInGameThreadWithDelay(handle, delay, callback) end
end

local function Dispatch(key, handler)
    health.queued=health.queued+1
    Note("QUEUED | action=" .. key .. " | total=" .. health.queued)
    local function invoke()
        if alive and handlers[key] == handler then
            health.invoked=health.invoked+1
            Note("INVOKE | action=" .. key .. " | total=" .. health.invoked)
            local ok, err = pcall(handler.fn)
            if not ok then Note("action handler error: " .. tostring(err)) end
        end
    end
    if handler.game_thread ~= false then
        -- Never fall back to running an engine callback on a worker thread.
        Schedule(0, invoke)
    else
        invoke()
    end
end

local function ApplyState(loaded, announce)
    if not schema or type(schema.actions) ~= "table" then return end
    for i = 1, #schema.actions do
        local action = schema.actions[i]
        if type(action) == "table" and action.key then
            local key = tostring(action.key)
            local current = tonumber(loaded and loaded[key]) or 0
            local previous = tonumber(lastCounts[key]) or current

            if announce and current > previous and handlers[key] then
                Note("COUNTER | action=" .. key .. " | previous=" .. previous .. " | current=" .. current)
                local delta = current - previous
                if delta > 20 then
                    Note(string.format("action '%s' jumped by %d; clamping to 20 invocations", key, delta))
                    delta = 20
                end
                for _ = 1, delta do Dispatch(key, handlers[key]) end
            end
            lastCounts[key] = current
        end
    end
end

function Client.Reload(announce)
    if not alive then return end
    local raw,err,code = ReadFile(StatePath())
    if raw==nil and not (not announce and code==2) then error("state read failed: " .. tostring(err)) end
    if raw == lastRaw and announce then return end
    local loaded,why=LoadTable(StatePath())
    if not loaded and raw~=nil then error("state parse failed: " .. tostring(why)) end
    ApplyState(loaded, announce == true)
    -- A transient failed read/parse must not mark the new file as consumed.
    lastRaw = raw
end

function Client.Status()
    -- Read-only: never advances counters, restarts polling or replays clicks.
    local disk,err=LoadTable(StatePath())
    local pending=0; for _,job in pairs(jobs) do if job.active then pending=pending+1 end end
    return "alive=" .. tostring(alive) .. " | registered=" .. tostring(registered)
        .. " | polls=" .. health.polls .. " | queued=" .. health.queued .. " | invoked=" .. health.invoked
        .. " | pending_jobs=" .. pending .. " | open_seen=" .. tostring(lastCounts.open_picker)
        .. " | scheduler=" .. (scheduler and "runtime" or "native")
        .. " | open_disk=" .. tostring(disk and disk.open_picker) .. " | last_error=" .. health.last_error
        .. " | state=" .. tostring(StatePath()) .. " | read_error=" .. tostring(err)
end

function Client.Init()
    if not alive then return Client end
    if started then return Client end
    started = true
    Note("INIT BEGIN | scheduler=" .. (scheduler and "runtime" or "native"))
    for _, name in ipairs({"MakeActionHandle", "ExecuteInGameThreadWithDelay", "CancelDelayedAction"}) do
        if not scheduler and type(_G[name]) ~= "function" then
            Note("integration disabled: owned game-thread API missing: " .. name)
            return Client
        end
    end

    schema = LoadTable(DEV_DIR and (DEV_DIR .. SEP .. "actions.lua") or nil)
    if type(schema) ~= "table" or type(schema.id) ~= "string" or type(schema.actions) ~= "table" then
        Note("no valid DevPanel/actions.lua found; integration disabled")
        return Client
    end

    local baseline_ok,baseline_err=pcall(Client.Reload,false)
    if not baseline_ok then
        health.last_error=tostring(baseline_err); Note("BASELINE FAILED | " .. health.last_error)
        return Client -- do not replay stale disk clicks without a baseline
    end
    local ok, result, reason = pcall(Register)
    registered = ok and result == true
    if not ok then reason = result end

    if registered then
        Note(string.format("registered %d dev action%s", #schema.actions, #schema.actions == 1 and "" or "s"))
        local function poll()
            Schedule(POLL_MS, function()
                health.polls=health.polls+1
                if health.polls==1 then Note("POLL STARTED | state=" .. tostring(StatePath())) end
                local loaded,err=pcall(Client.Reload,true)
                if not loaded then
                    local why=tostring(err):sub(1,1000)
                    if why~=health.last_error then Note("POLL FAILED | " .. why) end
                    health.last_error=why
                elseif health.last_error~="none" then
                    Note("POLL RECOVERED"); health.last_error="none"
                end
                if alive then poll() end
            end)
        end
        poll()
    else
        Note("registration unavailable; dev actions remain inactive: " .. tostring(reason or "invalid registration paths/schema"))
    end

    return Client
end

function Client.OnAction(key, fn, options)
    if not alive then return Client end
    if type(key) ~= "string" or type(fn) ~= "function" then return Client end
    options = type(options) == "table" and options or {}
    handlers[key] = {
        fn = fn,
        game_thread = options.game_thread ~= false,
    }
    if not started and not deferred_init then Client.Init() end
    if lastCounts[key] == nil then
        local loaded = LoadTable(StatePath())
        lastCounts[key] = tonumber(loaded and loaded[key]) or 0
    end
    return Client
end

function Client.IsAvailable()
    if not started and not deferred_init then Client.Init() end
    return alive and registered == true
end

function Client.Shutdown()
    alive = false
    registered = false
    handlers = {}
    local failures = {}
    for handle, job in pairs(jobs) do
        job.active = false
        local ok, err = pcall(job.cancel, handle)
        if ok then jobs[handle] = nil else failures[#failures+1] = tostring(err) end
    end
    assert(#failures == 0, "Dev Panel client cleanup incomplete: " .. table.concat(failures, "; "))
    diagnostic_sink=nil
end

return Client
