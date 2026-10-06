-- Geometry-free integration of the native-tested desktop-delta drag path.
-- Native cells locate the first press; only that cell is sampled while held.
-- Keep scalar identities/coordinates only; the caller owns layout and lifetime.
local M={}
local function number(n,label)
    assert(type(n)=="number" and n==n and math.abs(n)<1e7,"Unreadable SV " .. label)
    return n
end
local function clamp(n) return math.max(0,math.min(1,n)) end
function M.new(ui,rows,width,height,grid_name)
    local self={held=nil}
    local function timed(label,fn,...)
        if ui.perf then return ui.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function child(parent,index,expected)
        assert(parent:IsValid(),"SV parent retired")
        local value=parent:GetChildAt(index-1)
        assert(value and value:IsValid() and value:GetFullName()==expected,"SV child identity/order changed")
        return value
    end
    local function position()
        local pc=ui.fresh(ui.pc_name,"SV player controller")
        if pc.bShowMouseCursor~=true then return nil,"cursor hidden" end
        local lib=(ui.find or StaticFindObject)("/Script/UMG.Default__WidgetLayoutLibrary")
        assert(lib and lib:IsValid(),"SV layout library unavailable")
        local out={}
        if lib:GetMousePositionScaledByDPI(pc,out,out)~=true then return nil,"viewport mouse unavailable" end
        number(out.LocationX,"viewport X"); number(out.LocationY,"viewport Y")
        local p=lib:GetMousePositionOnPlatform()
        local scale=number(lib:GetViewportScale(pc),"UI scale")
        assert(scale>0 and scale<20,"Invalid SV UI scale")
        return {x=number(p.X,"desktop X"),y=number(p.Y,"desktop Y"),scale=scale}
    end
    local function sample()
        if ui.perf then return ui.perf.measure("sv.pointer",position) end
        return position()
    end
    function self.reset() self.held=nil end
    function self.read()
        -- Reacquire one owned grid, then use direct native child references for
        -- this call only. Never repeatedly search global names for every cell.
        local grid=timed("sv.grid_lookup",ui.fresh,grid_name,"SV grid")
        assert(grid:GetChildrenCount()==#rows,"SV row count changed")
        local function row_at(r)
            local row=timed("sv.child_lookup",child,grid,r,rows[r].name)
            assert(row:GetChildrenCount()==#rows[r].cells,"SV cell count changed")
            return row
        end
        local function pressed(cell)
            return timed("sv.pressed",function() return cell:IsPressed()==true end)
        end
        local held=self.held
        if held then
            local cell=timed("sv.child_lookup",child,row_at(held.row),held.column,held.name)
            if pressed(cell) then
                if held.suspended then return end
                local p,why=sample()
                if not p or p.scale~=held.scale then
                    held.suspended=true
                    ui.log("SV DRAG SUSPENDED | " .. (why or "UI scale changed") .. " | release then click again")
                    return
                end
                -- Viewport position freezes under native capture. Never use it
                -- to advance a drag, nor accumulate deltas after edge clamping.
                return clamp(held.s+(p.x-held.x)/held.scale/width),
                    clamp(held.v-(p.y-held.y)/held.scale/height)
            end
            self.held=nil
        end
        -- The responsive host has no safely marshalled geometry. Preserve its
        -- proven 24x16 native hit-test grid for press seeding, not drag tracking.
        for r,row in ipairs(rows) do
            local native_row=row_at(r)
            if timed("sv.hovered",function() return native_row:IsHovered()==true end) then
                for c,name in ipairs(row.cells) do
                    local cell=timed("sv.child_lookup",child,native_row,c,name)
                    if pressed(cell) then
                        local s,v=(c-1)/(#row.cells-1),1-(r-1)/(#rows-1)
                        local p,why=sample()
                        self.held={name=name,row=r,column=c,s=s,v=v,suspended=not p,
                            x=p and p.x,y=p and p.y,scale=p and p.scale}
                        if not p then ui.log("SV DRAG SUSPENDED | " .. why .. " | release then click again"); return end
                        return s,v
                    end
                end
                break
            end
        end
    end
    return self
end
return M
