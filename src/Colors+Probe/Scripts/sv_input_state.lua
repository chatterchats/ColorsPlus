-- Pure state for the isolated SV input experiment. No engine/color writes.
local M={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e7 end
function M.new(rect)
    assert(rect.w>0 and rect.h>0)
    local self={s=.5,v=.5,dragging=false,presses=0,releases=0,moves=0,events=0,fallbacks=0,revision=0}
    local function point(x,y)
        assert(finite(x) and finite(y),"Unreadable SV pointer")
        return (x-rect.x)/rect.w,(y-rect.y)/rect.h
    end
    local function move(x,y)
        local s,t=point(x,y)
        s=math.max(0,math.min(1,s)); local v=1-math.max(0,math.min(1,t))
        if s~=self.s or v~=self.v then self.s,self.v=s,v; self.moves=self.moves+1; self.revision=self.revision+1 end
    end
    function self.press(x,y,event)
        local s,t=point(x,y)
        if s<0 or s>1 or t<0 or t>1 then return false end
        if self.dragging then
            if not event then return false end
            -- A new left-down event proves the preceding press ended, even
            -- if both release and next down occurred between two polls.
            self.releases=self.releases+1
        end
        self.dragging=true; self.presses=self.presses+1; self.revision=self.revision+1
        if event then self.events=self.events+1 else self.fallbacks=self.fallbacks+1 end
        move(x,y); return true
    end
    function self.poll(pressed,x,y)
        if pressed then
            if self.dragging then move(x,y) else self.press(x,y,false) end
        elseif self.dragging then
            -- Retain the event's click position even when press+release both
            -- happened between polls and the cursor has already moved away.
            self.dragging=false; self.releases=self.releases+1; self.revision=self.revision+1
        end
    end
    return self
end
return M
