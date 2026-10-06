-- Pure layout math for the Custom Color launcher. color_ui reads the values
-- from the live widget tree; nothing here touches native objects.
local M={}

-- records: one per widget, from the swatch grid upward. Each record is
-- {desired=, h=, pad_l=, pad_r=, parent_kind=, parent_size_rule=,
-- width_override=, root=}, where h/pad/size describe the widget's slot in its
-- parent (a widget-tree root continues to its owning UserWidget with h=0 and
-- no padding). Slate cannot be asked for laid-out geometry from Lua, so the
-- width is derived: find the nearest widget whose width does not depend on
-- its parent, then apply each slot's alignment and padding back down.
-- Returns the grid's width, or nil when no record gives a trusted width.
function M.column_width(records)
    local top
    for i,r in ipairs(records) do
        if r.width_override and r.width_override>0 then r.width=r.width_override; top=i; break end
        -- Auto-sized in a horizontal box, on a canvas, or an unowned root:
        -- the widget is laid out at its desired width.
        if (r.parent_kind=="HorizontalBox" and r.parent_size_rule==0) or r.parent_kind=="CanvasPanel" or r.root then
            if not r.desired then return nil end
            r.width=r.desired; top=i; break
        end
        -- Any other horizontal box slot shares space with siblings: unknown.
        if r.parent_kind=="HorizontalBox" then return nil end
    end
    if not top then return nil end
    for i=top-1,1,-1 do
        local r=records[i]
        local inner=records[i+1].width-(r.pad_l or 0)-(r.pad_r or 0)
        if r.h==nil or r.h==0 then r.width=inner
        else r.width=math.min(r.desired or inner,inner) end
    end
    return records[1].width
end

-- Tile view row geometry inside `width`: the first and last visible swatch
-- edges of a full row. Spacing not included in the entry size is padding
-- split around each entry (observed: 64-wide tiles with 10 spacing start 5
-- in). alignment: EListItemAlignment numbering.
local ALIGN={[0]="evenly",[1]="fill",[2]="fill",[3]="left",[4]="right",[5]="center",[6]="fill"}
function M.swatch_row(width,entry,spacing,includes,alignment,count)
    assert(width and width>0 and entry and entry>0 and count and count>0,"Unreadable swatch metrics")
    spacing=spacing or 0
    local align=ALIGN[alignment or 0] or "evenly"
    local pitch=includes and entry or entry+spacing
    local per_line=math.max(1,math.floor(width/pitch))
    local n=math.min(per_line,count)
    local used=n*pitch
    local start,span=0,used
    if align=="right" then start=width-used
    elseif align=="center" then start=(width-used)/2
    elseif align=="evenly" then
        local extra=(width-per_line*pitch)/per_line
        start=extra/2; span=n*(pitch+extra)-extra
    elseif align=="fill" then span=width end
    -- Visible swatches exclude the spacing padding around each entry.
    start=start+spacing/2; span=span-spacing
    assert(span>0,"Swatch row does not fit")
    return {left=start,width=span,per_line=per_line,align=align}
end
return M
