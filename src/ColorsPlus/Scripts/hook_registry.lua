-- Own hooks and delayed work. Reuse a console dispatcher across Lua reloads.
local M = {}

function M.start(key)
    local old = rawget(_G, key)
    if old then old:teardown() end
    local self = {
        alive = true, generation = old and old.generation + 1 or 1,
        hooks = {}, actions = {}, bindings = old and old.bindings or {},
        log = function(message) print("[Colors+Probe] " .. tostring(message) .. "\n") end,
    }

    function self:guard(callback)
        return function(...)
            if not self.alive then return end
            local ok, err = pcall(callback, ...)
            if not ok then self.log("Callback failed: " .. tostring(err)) end
            -- Never forward return values to the hooked UFunction.
        end
    end

    function self:hook(path, callback, before)
        if self.hooks[path] then return true end
        -- Every native callback is a lifetime boundary for reused lookups.
        local function boundary(fn)
            return function(...)
                if self.objects then self.objects.invalidate() end
                return fn(...)
            end
        end
        callback = boundary(callback)
        if before then before = boundary(before) end
        self.log("STARTUP | REGISTER HOOK BEGIN | " .. path)
        local function register()
            if path:sub(1, 8) == "/Script/" then
                return RegisterHook(path, before and self:guard(before) or function() end, self:guard(callback))
            end
            return RegisterHook(path, self:guard(callback))
        end
        local ok, pre, post = pcall(function()
            if self.perf then return self.perf.measure("hook.register", register) end
            return register()
        end)
        if not ok then self.log("STARTUP | REGISTER HOOK FAILED | " .. path .. " | " .. tostring(pre)); return false, tostring(pre) end
        self.log("STARTUP | REGISTER HOOK RETURN | " .. path)
        if pre == nil or post == nil then error("RegisterHook did not return both IDs: " .. path) end
        self.hooks[path] = { pre, post }
        self.log("Hook installed: " .. path)
        return true
    end

    function self:cancel(key_name)
        local entry = self.actions[key_name]
        if not entry then return end
        entry.active = false
        local ok, err = pcall(CancelDelayedAction, entry.handle)
        if not ok then error("Action cancellation failed: " .. tostring(err)) end
        self.actions[key_name] = nil
    end

    function self:cancel_snapshots()
        local keys = {}
        for name in pairs(self.actions) do
            if name:sub(1, 9) == "snapshot:" then keys[#keys + 1] = name end
        end
        for _, name in ipairs(keys) do self:cancel(name) end
    end

    function self:after(key_name, delay, callback)
        assert(self.alive, "runtime retired")
        local traced=key_name:match("^startup:") or key_name:find("recovery",1,true) or key_name=="picker:startup"
            or key_name=="panel-client:startup" or key_name=="panel-client:1"
        if traced then self.log("STARTUP | SCHEDULE BEGIN | " .. key_name) end
        self:cancel(key_name)
        local entry = { handle = MakeActionHandle(), active = true }
        local profile=self.perf and not key_name:match("^perf:") and self.perf
        local ticket=profile and profile.queue(key_name,delay)
        self.actions[key_name] = entry
        if traced then self.log("STARTUP | DISPATCH BEGIN | " .. key_name) end
        ExecuteInGameThreadWithDelay(entry.handle, delay, self:guard(function()
            if not entry.active then return end
            entry.active = false
            self.actions[key_name] = nil
            if profile then profile.dispatch(ticket) end
            if traced then self.log("STARTUP | RUN BEGIN | " .. key_name) end
            local ok,err=pcall(function()
                local function invoke()
                    if profile then return profile.measure("job." .. key_name,callback) end
                    return callback()
                end
                if self.call_trace and key_name~="call-trace:expiry" then
                    return self.call_trace.call("JOB " .. key_name,invoke)
                end
                return invoke()
            end)
            if traced then self.log("STARTUP | RUN " .. (ok and "END" or "FAILED") .. " | " .. key_name) end
            if not ok then error(err) end
        end))
        if traced then self.log("STARTUP | DISPATCH RETURN | " .. key_name) end
    end

    function self:console(name, callback)
        local binding = self.bindings[name]
        if not binding then
            binding = {}
            RegisterConsoleCommandHandler(name, function(...)
                if binding.callback then binding.callback(...) end
                return true
            end)
            self.bindings[name] = binding
        end
        binding.callback = self:guard(callback)
    end

    function self:teardown()
        assert(not (self.tint and self.tint.source_owned),
            "Close CP and Restore applied Zabrak skin before reloading; runtime remains active")
        assert(not (self.skin_enable and self.skin_enable.pending),
            "Close the picker and Restore applied skin (or stop the manual skin test) before reloading; runtime remains active")
        self.log("TEARDOWN | BEGIN")
        if self.color_ui then
            if self.picker then assert(self.picker.close("runtime teardown"),"Picker cleanup failed; reload stopped") end
            self.color_ui.close("runtime teardown")
        end
        if self.perf then self.perf.stop("runtime teardown") end
        self.alive = false
        for _, binding in pairs(self.bindings) do binding.callback = nil end
        local failures, keys = {}, {}
        for name in pairs(self.actions) do keys[#keys + 1] = name end
        for _, name in ipairs(keys) do
            self.log("TEARDOWN | CANCEL BEGIN | " .. name)
            local ok, err = pcall(function() self:cancel(name) end)
            self.log("TEARDOWN | CANCEL RETURN | " .. name .. " | ok=" .. tostring(ok))
            if not ok then failures[#failures + 1] = tostring(err) end
        end
        for path, ids in pairs(self.hooks) do
            self.log("TEARDOWN | UNREGISTER BEGIN | " .. path)
            local ok, err = pcall(UnregisterHook, path, ids[1], ids[2])
            self.log("TEARDOWN | UNREGISTER RETURN | " .. path .. " | ok=" .. tostring(ok))
            if ok then self.hooks[path] = nil else failures[#failures + 1] = tostring(err) end
        end
        if #failures > 0 then error("Cleanup incomplete; reload stopped: " .. table.concat(failures, "; ")) end
        self.log("TEARDOWN | COMPLETE")
        if self.on_close then self.on_close(); self.on_close = nil end
        self.probe = nil
    end
    rawset(_G, key, self)
    return self
end

return M
