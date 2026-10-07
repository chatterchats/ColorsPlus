-- Instances the game handed to our hooks, or that a scan found, kept as full
-- names only (no UObject wrapper survives a call). Measured with the lookup
-- trace (2026-10-07): FindAllOf scans the whole object array on every call
-- (~35ms each, 69% of all lookup time, mostly while just browsing color
-- slots); a by-name StaticFindObject is ~0ms once UE4SS has seen the name, but
-- a name that no longer exists also costs a full scan. Callers try known names
-- first and scan only when no known instance qualifies; dead names are dropped
-- after one miss. Ambiguity checks then apply to the qualifying instances.
-- epoch() changes on every native hook callback (the lookup cache's
-- generation). A known live instance that does not qualify (the aux VM off a
-- color slot) is rescanned at most once per epoch: capture 2 showed polls
-- rescanning it 68 times while the player sat on radial menus.
local M={LIMIT=8}
function M.new(a,epoch)
    epoch=epoch or function() return nil end
    local self={scans=0}
    local unqualified={} -- class -> epoch of the last scan that found none
    local names={} -- class -> full names, most recently noted first
    local controller -- player controller full name
    local function lookup(full)
        local v=a.unwrap((a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$")))
        if a.live(v) and a.name(v)==full then return v end
    end
    -- Record an object already in hand (hook context or scan result).
    function self.note(v)
        local ok,full=pcall(function() v=a.unwrap(v); return a.live(v) and a.name(v) end)
        if not ok or type(full)~="string" or full:find("Default__",1,true) or full:find("[\r\n]") then return end
        local class=full:match("^([^ ]+) /")
        if not class then return end
        local list=names[class] or {}; names[class]=list
        for i,n in ipairs(list) do if n==full then table.remove(list,i); break end end
        table.insert(list,1,full)
        if #list>M.LIMIT then list[#list]=nil end
    end
    -- Live known instances of class; names that no longer resolve are dropped.
    function self.known(class)
        local out,keep={},{}
        for _,full in ipairs(names[class] or {}) do
            local v=lookup(full)
            if v then out[#out+1]=v; keep[#keep+1]=full end
        end
        names[class]=keep
        return out
    end
    -- Instances of class that accept(v): known ones first; a FindAllOf scan,
    -- noting every live result, only when none of them qualifies. Returns the
    -- qualifying list and whether a scan ran.
    function self.select(class,limit,accept)
        local found={}
        local alive=self.known(class)
        for _,v in ipairs(alive) do if accept(v) then found[#found+1]=v end end
        if #found>0 then return found,false end
        -- Known instances exist but none qualifies, and nothing has happened
        -- since a scan last found none: the answer is still none.
        local now=epoch()
        if #alive>0 and now~=nil and unqualified[class]==now then return found,false end
        self.scans=self.scans+1
        local values=FindAllOf(class) or {}
        assert(type(values)=="table","Unsupported object list: " .. class)
        local n=0
        for _,v in pairs(values) do
            n=n+1; assert(n<=limit,"Scan limit: " .. class)
            if a.live(a.unwrap(v)) then
                self.note(v)
                if accept(v) then found[#found+1]=v end
            end
        end
        unqualified[class]=#found==0 and now or nil
        return found,true
    end
    -- UEHelpers.GetPlayerController scans every PlayerController; reuse the
    -- one it returned while that exact object is still live.
    function self.player_controller()
        if controller then
            local v=lookup(controller)
            if v then return v end
            controller=nil
        end
        self.scans=self.scans+1
        local v=a.unwrap(require("UEHelpers").GetPlayerController())
        if a.live(v) then controller=a.name(v) end
        return v
    end
    return self
end
return M
