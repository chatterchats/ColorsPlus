-- Temporary bounded diagnostics. No UObject inspection, extra engine calls,
-- or retained callback/return values. Uses the existing flushed runtime logger.
local M={}
-- UE4SS uses table.unpack; LuaJIT/5.1 test runners may only expose unpack.
local unpack_values=assert(table.unpack or unpack,"Lua unpack function unavailable")
local function pack(...) return {n=select("#",...),...} end
function M.new(runtime,options)
    options=options or {}
    local limit=options.limit or 6000
    local duration=options.duration or 10000
    local self={window=nil}
    local serial=0
    local function clean(s) return tostring(s):gsub("[\r\n\t]"," "):sub(1,384) end
    local function log(w,s) runtime.log("CALL TRACE | window=" .. w.id .. " | " .. s) end
    function self.stop(w,reason)
        if not w or self.window~=w then return end
        self.window=nil
        runtime:cancel("call-trace:expiry")
        log(w,"STOP | calls=" .. w.calls .. " | " .. clean(reason))
    end
    function self.start(reason)
        self.stop(self.window,"replaced")
        serial=serial+1
        local w={id=serial,calls=0}; self.window=w
        log(w,"START | max_calls=" .. limit .. " | duration_ms=" .. duration .. " | " .. clean(reason))
        runtime:after("call-trace:expiry",duration,function() self.stop(w,"time limit") end)
        return w
    end
    function self.call(label,fn,...)
        local w=self.window
        if not w then return fn(...) end
        if w.calls>=limit then self.stop(w,"call limit"); return fn(...) end
        w.calls=w.calls+1
        local prefix="call=" .. w.calls .. " | "
        label=clean(label)
        log(w,prefix .. "BEGIN | " .. label)
        local result=pack(pcall(fn,...))
        -- Pair this call with its original window, even if a nested callback
        -- closes/replaces it. A Lua error is distinct from a missing RETURN.
        if not result[1] then
            log(w,prefix .. "ERROR | " .. label .. " | " .. clean(result[2]))
            error(result[2],0)
        end
        log(w,prefix .. "RETURN | " .. label)
        return unpack_values(result,2,result.n)
    end
    return self
end
return M
