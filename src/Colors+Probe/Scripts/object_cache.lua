-- Session-scoped reuse of full-path StaticFindObject results.
-- UE4SS's string lookup costs ~15-20ms per call in this game. v0.2.113 logs
-- showed ~12 lookups per 16ms picker poll (~230ms game-thread stall per idle
-- tick) and ~3x4 per preview update. Follows the guide's retained-reference
-- rule: entries exist only while a color UI/picker owner holds the cache, are
-- dropped synchronously by every native hook callback, any release, and any
-- failed recheck. Every hit is rechecked with IsValid and the exact full name
-- before it is returned; callers keep all of their own ownership checks. An
-- entry not verified within MAX_AGE_MS is looked up again, never touched, so
-- no wrapper is trusted across a long unobserved gap (e.g. a GC pass).
local M={LIMIT=128,MAX_AGE_MS=1000}
function M.new(lookup,clock)
    lookup=lookup or function(path) return StaticFindObject(path) end
    clock=clock or os.clock
    local self={generation=0,hits=0,misses=0}
    local entries,count=nil,0
    local holders={}
    local function current(entry)
        local ok,same=pcall(function()
            return entry.value:IsValid()==true and entry.value:GetFullName()==entry.full
        end)
        return ok and same==true
    end
    function self.find(path)
        if not entries then return lookup(path) end
        local entry=entries[path]
        if entry then
            local now=clock()
            if (now-entry.seen)*1000<=M.MAX_AGE_MS and current(entry) then
                entry.seen=now; self.hits=self.hits+1; return entry.value
            end
            entries[path]=nil; count=count-1
        end
        self.misses=self.misses+1
        local value=lookup(path)
        local ok,full=pcall(function() return value and value:IsValid()==true and value:GetFullName() end)
        -- Only the exact object the path names; never a redirect or default.
        if ok and type(full)=="string" and full:sub(-#path-1)==" " .. path and count<M.LIMIT then
            entries[path]={value=value,full=full,seen=clock()}; count=count+1
        end
        return value
    end
    function self.invalidate()
        if entries then entries={}; count=0 end
        self.generation=self.generation+1
    end
    function self.hold(owner)
        holders[owner]=true
        if not entries then entries={}; count=0 end
    end
    function self.release(owner)
        holders[owner]=nil
        -- Any owner boundary drops every entry; remaining owners start fresh.
        if next(holders)==nil then entries=nil; count=0 else entries={}; count=0 end
        self.generation=self.generation+1
    end
    function self.active() return entries~=nil end
    return self
end
return M
