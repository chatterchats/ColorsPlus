-- Temporarily hide disjoint palette branches while retaining their layout.
-- UE4SS shared strings survive Lua reloads only within this game process.
-- No disk record or native wrapper can replay into a later game session.
local M={KEY="ColorsPlusProbe.PaletteVisibility.v1"}
local ROOT="^UserWidget /[^\r\n]+%.ColorsPlusPicker_Root_%d+$"
local function encode(s)
    local fields={"palette-visibility-v2",s.grid,s.parent,s.overlay,s.root,tostring(#s.targets)}
    for _,target in ipairs(s.targets) do
        fields[#fields+1]=target.widget; fields[#fields+1]=target.parent; fields[#fields+1]=tostring(target.original)
    end
    return table.concat(fields,"\n") .. "\n"
end
function M.parse(data)
    if type(data)~="string" or #data>131072 or data:find("\r",1,true) or data:sub(-1)~="\n" then return nil end
    local fields={}; for field in data:gmatch("([^\n]*)\n") do fields[#fields+1]=field end
    local s={grid=fields[2],parent=fields[3],overlay=fields[4],root=fields[5],targets={}}
    if fields[1]=="palette-visibility-v1" and #fields==6 then
        s.targets[1]={widget=s.grid,parent=s.parent,original=tonumber(fields[6])}
    elseif fields[1]=="palette-visibility-v2" then
        local count=tonumber(fields[6])
        if not count or count%1~=0 or count<1 or count>64 or #fields~=6+3*count then return nil end
        for i=1,count do
            local offset=6+(i-1)*3
            s.targets[i]={widget=fields[offset+1],parent=fields[offset+2],original=tonumber(fields[offset+3])}
        end
    else return nil end
    if not s.grid or not s.grid:match("^BitReactorTileView /[^\r\n]+%.PartsGridList$")
        or not s.overlay or not s.overlay:match("^Overlay /[^\r\n]+$")
        or not s.root or not s.root:match(ROOT) then return nil end
    local tree=s.grid:match("^[^ ]+ (.+)%.PartsGridList$")
    local function inside(full)
        local path=type(full)=="string" and full:match("^[%w_]+ (/[^\r\n]+)$")
        return path and path:sub(1,#tree+1)==tree .. "."
    end
    if not inside(s.parent) or not inside(s.overlay) then return nil end
    local seen,parents={},{}
    for _,target in ipairs(s.targets) do
        local original=target.original
        -- Injected palette children can have an outer outside the native tree.
        -- The recorded native panel parent is verified again before any write.
        if type(target.widget)~="string" or not target.widget:match("^[%w_]+ /[^\r\n]+$")
            or not inside(target.parent) or seen[target.widget]
            or target.widget:match(ROOT) or target.widget==s.overlay
            or not original or original%1~=0 or original<0 or original>4 then return nil end
        seen[target.widget]=true; parents[target.parent]=true
    end
    -- Target branches cannot themselves be hidden ancestors of another target.
    for full in pairs(seen) do if parents[full] then return nil end end
    if s.targets[1].widget~=s.grid or s.targets[1].parent~=s.parent then return nil end
    return s
end
function M.new(a,logger)
    local self={}
    local held,loaded
    local function log(s) if logger then logger("PALETTE VISIBILITY | " .. s) end end
    local function mod() return assert(rawget(_G,"ModRef"),"Palette visibility recovery requires ModRef") end
    local function get()
        if not loaded then
            local data=mod():GetSharedVariable(M.KEY)
            if data~=nil and data~="" then held=assert(M.parse(data),"Invalid palette visibility recovery") end
            loaded=true
        end
        return held
    end
    local function persist(s)
        local data=s and encode(s) or ""
        assert(not s or M.parse(data),"Invalid palette visibility intent")
        mod():SetSharedVariable(M.KEY,data)
        assert(mod():GetSharedVariable(M.KEY)==data,"Palette visibility recovery readback failed")
        held,loaded=s,true
    end
    local function find(full)
        local v=a.unwrap((a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$")))
        if a.live(v) and a.name(v)==full then return v end
    end
    local function parent(v)
        local p=a.unwrap(v:GetParent())
        return a.live(p) and a.name(p) or nil
    end
    function self.validate(b)
        local s=get(); if not s then return true end
        assert(b and b.grid==s.grid and b.overlay==s.overlay,"Hidden palette binding changed")
        local root=assert(find(s.root),"Hidden palette picker unavailable")
        assert(parent(root)==s.overlay,"Hidden palette picker detached")
        for _,target in ipairs(s.targets) do
            local widget=assert(find(target.widget),"Hidden palette control unavailable")
            assert(parent(widget)==target.parent and widget:GetVisibility()==2,"Hidden palette ownership changed")
        end
        return true
    end
    function self.hide(b,root_name,targets)
        assert(not get(),"Restore the previously hidden palette before opening")
        local grid=assert(find(b.grid),"Palette grid unavailable")
        local root=assert(find(root_name),"Palette picker unavailable")
        assert(parent(root)==b.overlay and parent(grid)==b.chain[1],"Palette host changed before hiding")
        local s={grid=b.grid,parent=b.chain[1],overlay=b.overlay,root=root_name,targets={}}
        for _,target in ipairs(targets or {{widget=b.grid,parent=b.chain[1]}}) do
            local widget=assert(find(target.widget),"Palette control unavailable")
            assert(parent(widget)==target.parent,"Palette control reparented before hiding")
            s.targets[#s.targets+1]={widget=target.widget,parent=target.parent,original=widget:GetVisibility()}
        end
        persist(s) -- publish every original value before the first native setter
        for _,target in ipairs(s.targets) do
            local widget=assert(find(target.widget),"Palette control unavailable")
            assert(parent(widget)==target.parent and widget:GetVisibility()==target.original,"Palette control changed before hiding")
            widget:SetVisibility(2) -- Hidden: no drawing/input, desired size retained
            widget=assert(find(target.widget),"Palette control changed while hiding")
            assert(parent(widget)==target.parent and widget:GetVisibility()==2,"Palette hide readback failed")
        end
        self.validate(b) -- reacquire after setters; no wrapper survives the call
        log("HIDDEN | " .. s.grid .. " | controls=" .. #s.targets)
    end
    function self.restore()
        local s=get(); if not s then return true end
        local root=find(s.root)
        assert(not root or not parent(root),"Remove the picker before restoring its palette")
        for _,target in ipairs(s.targets) do
            local widget=find(target.widget)
            if not widget or parent(widget)~=target.parent then
                log("RETIRED | control destroyed/reparented; no visibility write | " .. target.widget)
            elseif widget:GetVisibility()==2 then
                if target.original~=2 then widget:SetVisibility(target.original) end
                widget=assert(find(target.widget),"Palette control changed during restoration")
                assert(parent(widget)==target.parent and widget:GetVisibility()==target.original,"Palette visibility restoration readback failed")
                log("RESTORED | " .. target.widget .. " | visibility=" .. target.original)
            else
                log("RETIRED | native visibility changed; no visibility write | " .. target.widget)
            end
        end
        persist(nil)
        return true
    end
    return self
end
return M
