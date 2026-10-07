-- Records every StaticFindObject and FindAllOf call this mod makes (lookup
-- cache misses and direct calls alike): path or class, os.clock ms, picker
-- performance window and the calling lines in this mod's scripts. Which
-- lookups miss depends on the code, not the machine, so a capture here names
-- the lookups that cost a slow machine ~38ms each. Read-only; the originals
-- are kept across Lua reloads so a reload never wraps the wrapper.
-- Opt-in (logs a line per lookup): colors_lookups start, use the picker,
-- colors_lookups summary. Console: colors_lookups [start|stop|summary|reset]
local M={}
local MAX_TALLY=256
local unpack=table.unpack or unpack
local function pack(...) return {n=select("#",...),...} end
local function clean(s) return (tostring(s):gsub("[\r\n\t]"," ")) end
-- Instance numbers vary per session; group by shape.
local function shape(s) return (clean(s):gsub("_%d+","_N")) end
function M.new(runtime,directory)
    local self={}
    local originals=rawget(_G,"ColorsPlusLookupTraceOriginals")
    if not originals then
        originals={StaticFindObject=rawget(_G,"StaticFindObject"),FindAllOf=rawget(_G,"FindAllOf")}
        rawset(_G,"ColorsPlusLookupTraceOriginals",originals)
    end
    local tally,order,calls,total=nil,nil,0,0
    local active=false
    local function reset() tally,order,calls,total={},{},0,0 end
    reset()
    local function log(s) runtime.log("LOOKUP TRACE | " .. s) end
    -- Up to three frames inside this mod's scripts, skipping the wrapper,
    -- the shared lookup cache and main.lua's cache hook.
    local function callers()
        local out={}
        for level=3,24 do
            local info=debug.getinfo(level,"Sl")
            if not info then break end
            local src=info.source or ""
            local file=src:sub(1,1)=="@" and src:match("([^/\\]+)%.lua$")
            if file and src:sub(2,#directory+1)==directory and file~="lookup_trace"
                and file~="object_cache" and file~="main" then
                out[#out+1]=file .. ":" .. tostring(info.currentline)
                if #out==3 then break end
            end
        end
        return #out>0 and table.concat(out,"<") or "?"
    end
    local function window()
        -- The performance window is a table; its id matches PERF | window=N.
        local w=runtime.perf and runtime.perf.window
        if type(w)=="table" then w=w.id end
        return w and ("w" .. tostring(w)) or "none"
    end
    local function record(kind,target,ms,result)
        if not active then return end
        local where=callers()
        calls=calls+1; total=total+ms
        log(kind .. " | ms=" .. string.format("%.3f",ms) .. " | window=" .. window() .. " | " .. result
            .. " | path=" .. clean(target) .. " | at=" .. where)
        local key=kind .. " | " .. shape(target) .. " | " .. where
        local entry=tally[key]
        if not entry then
            if #order>=MAX_TALLY then key="(other)"; entry=tally[key] end
            if not entry then entry={n=0,ms=0,max=0}; tally[key]=entry; order[#order+1]=key end
        end
        entry.n=entry.n+1; entry.ms=entry.ms+ms; if ms>entry.max then entry.max=ms end
    end
    local function found(v)
        local ok,live=pcall(function() return v~=nil and v:IsValid()==true end)
        return ok and live and "found" or "missing"
    end
    function self.attach()
        local find,all=originals.StaticFindObject,originals.FindAllOf
        if type(find)=="function" then
            StaticFindObject=function(path,...)
                local start=os.clock()
                local result=pack(find(path,...))
                record("StaticFindObject",path,(os.clock()-start)*1000,found(result[1]))
                return unpack(result,1,result.n)
            end
        end
        if type(all)=="function" then
            FindAllOf=function(class,...)
                local start=os.clock()
                local result=pack(all(class,...))
                local n=0
                if type(result[1])=="table" then for _ in pairs(result[1]) do n=n+1 end end
                record("FindAllOf",class,(os.clock()-start)*1000,"count=" .. n)
                return unpack(result,1,result.n)
            end
        end
        if type(RegisterConsoleCommandHandler)=="function" then
            runtime:console("colors_lookups",function(_,parameters,output)
                local action=string.lower(tostring((parameters or {})[1] or "summary"))
                local message
                if action=="start" then active=true; reset(); message="Lookup trace started (tally reset)."
                elseif action=="stop" then active=false; message="Lookup trace stopped; tally kept."
                elseif action=="reset" then reset(); message="Lookup tally reset."
                elseif action=="summary" then self.summary(); message="Lookup summary written to colors_plus_probe.log."
                else message="Usage: colors_lookups [start|stop|summary|reset]" end
                log(message)
                if output then pcall(function() output:Log(message) end) end
            end)
        end
        log("Ready | off until colors_lookups start | colors_lookups [start|stop|summary|reset]")
    end
    -- Costliest first: total ms, then count.
    function self.summary()
        local rows={}
        for _,key in ipairs(order) do rows[#rows+1]={key=key,e=tally[key]} end
        table.sort(rows,function(x,y)
            if x.e.ms~=y.e.ms then return x.e.ms>y.e.ms end
            return x.e.n>y.e.n
        end)
        log("SUMMARY BEGIN | active=" .. tostring(active) .. " | calls=" .. calls .. " | ms=" .. string.format("%.1f",total) .. " | groups=" .. #rows)
        for i,row in ipairs(rows) do
            log(string.format("SUMMARY %d | n=%d | ms=%.1f | max=%.1f | %s",i,row.e.n,row.e.ms,row.e.max,row.key))
        end
        log("SUMMARY END")
        return rows
    end
    return self
end
return M
