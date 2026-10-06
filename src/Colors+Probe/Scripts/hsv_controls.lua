-- Native cells seed presses; captured desktop deltas provide continuous drag.
-- Retain only scalar widget identities. This module owns no timers or hooks.
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local math_color=assert(loadfile(directory .. "color_math.lua"))()
local rgb_input=assert(loadfile(directory .. "rgb_input.lua"))()
local sv_input=assert(loadfile(directory .. "sv_picker_input.lua"))()
local M={COLUMNS=24,ROWS=16,WIDTH=400,HEIGHT=240}
function M.new(ui)
    local gradients=assert(ui.gradients,"Picker gradient loader unavailable")
    local self={rows={},h=0,s=0,v=1,rgb={R=255,G=255,B=255},invalid=false}
    local construct,fresh=ui.construct,ui.fresh
    local identity=ui.identity or function(o) return o:GetFullName() end
    local function native(label,fn)
        if ui.perf then return ui.perf.measure("hsv." .. label,ui.call,"HSV " .. label,fn) end
        return ui.call("HSV " .. label,fn)
    end
    local function timed(label,fn)
        if ui.perf then return ui.perf.measure(label,fn) end
        return fn()
    end
    local function linear(rgb)
        -- parse also returns an encoded diagnostic. Return exactly one value:
        -- a final-argument helper call otherwise expands both into a UFunction.
        local color=rgb_input.parse(string.format("%d,%d,%d",rgb.R,rgb.G,rgb.B))
        return color
    end
    local function slot_fill(slot) slot:SetSize({SizeRule=1,Value=1}) end
    local function anchors(slot,min,max,offsets)
        slot:SetAnchors({Minimum=min,Maximum=max}); slot:SetAlignment({X=0,Y=0}); slot:SetOffsets(offsets)
    end
    local function add_sized(parent,child,height)
        local size=construct("/Script/UMG.SizeBox",parent)
        size:SetWidthOverride(M.WIDTH); size:SetHeightOverride(height); size:AddChild(child)
        parent:AddChild(size):SetHorizontalAlignment(2); return size
    end
    local function paint()
        if self.painted_h==self.h then return end
        local color=linear(math_color.from_hsv(self.h,1,1))
        native("base.SetBrushColor",function() fresh(self.base_name,"SV hue base"):SetBrushColor(color) end)
        self.painted_h=self.h
    end
    local function marker()
        local slot=fresh(self.marker_slot,"SV marker slot")
        native("marker.SetAnchors",function() slot:SetAnchors({Minimum={X=self.s,Y=1-self.v},Maximum={X=self.s,Y=1-self.v}}) end)
        native("marker.SetAlignment",function() slot:SetAlignment({X=.5,Y=.5}) end)
        native("marker.SetOffsets",function() slot:SetOffsets({Left=0,Top=0,Right=18,Bottom=18}) end)
    end
    local function sync_text()
        self.hex_seen=math_color.hex(self.rgb)
        native("hex.SetText",function() fresh(self.hex_name,"hex input"):SetText(FText(self.hex_seen)) end)
        self.invalid=false
    end
    function self.build(body)
        local area=construct("/Script/UMG.CanvasPanel",body); area:SetVisibility(4)
        -- A known owned size makes desktop deltas independent of host geometry.
        -- Center it in the native fill pane; do not resize the stock selector.
        local size=construct("/Script/UMG.SizeBox",body)
        size:SetWidthOverride(M.WIDTH); size:SetHeightOverride(M.HEIGHT); size:AddChild(area)
        body:AddChild(size):SetHorizontalAlignment(2)
        local function layer(widget)
            widget:SetVisibility(3)
            anchors(area:AddChild(widget),{X=0,Y=0},{X=1,Y=1},{Left=0,Top=0,Right=0,Bottom=0})
        end
        local base=construct("/Script/UMG.Border",area); layer(base)
        self.base_name=identity(base)
        self.gradient_names={}
        for _,key in ipairs({"saturation","value"}) do
            local image=construct("/Script/UMG.Image",area)
            timed("ui.gradient_bind",function() native("gradient " .. key,function() gradients.bind(image,key) end) end)
            layer(image); self.gradient_names[key]=image:GetFullName()
        end
        -- Separate visual siblings: transparent buttons must not tint the
        -- gradient layers. Retain the proven native hit targets above them.
        timed("ui.sv_grid_build",function()
        local grid=construct("/Script/UMG.VerticalBox",area)
        self.grid_name=grid:GetFullName()
        anchors(area:AddChild(grid),{X=0,Y=0},{X=1,Y=1},{Left=0,Top=0,Right=0,Bottom=0})
        for r=1,M.ROWS do
            local row=construct("/Script/UMG.HorizontalBox",grid)
            slot_fill(grid:AddChild(row))
            local record={name=row:GetFullName(),cells={}}; self.rows[r]=record
            for c=1,M.COLUMNS do
                local cell=construct("/Script/UMG.Button",row); cell.IsFocusable=false
                -- v0.2.70 crashed in the very first SetStyle(FButtonStyle).
                -- Never pass/read/copy whole Slate style structs.
                native("cell.SetBackgroundColor",function() cell:SetBackgroundColor({R=0,G=0,B=0,A=0}) end)
                slot_fill(row:AddChild(cell)); record.cells[c]=cell:GetFullName()
            end
        end
        end)
        self.input=sv_input.new(ui,self.rows,M.WIDTH,M.HEIGHT,self.grid_name)
        ui.log("HSV SV READY | renderer=layered-textures | click=24x16 | drag=desktop-delta | size=400x240")
        local mark=ui.text(area,"+",16); mark:SetVisibility(3)
        self.marker_slot=identity(area:AddChild(mark))
        ui.label(body,"HUE",11)
        local hue_area=construct("/Script/UMG.Overlay",body); add_sized(body,hue_area,26)
        local strip=construct("/Script/UMG.Image",hue_area)
        native("gradient hue",function() gradients.bind(strip,"hue") end)
        self.gradient_names.hue=strip:GetFullName()
        local strip_slot=hue_area:AddChild(strip); strip_slot:SetHorizontalAlignment(0); strip_slot:SetVerticalAlignment(0)
        local hue=construct("/Script/UMG.Slider",hue_area)
        hue:SetMinValue(0); hue:SetMaxValue(1); hue:SetStepSize(1/360); hue:SetIndentHandle(false); hue.IsFocusable=false
        hue:SetSliderBarColor({R=0,G=0,B=0,A=0}); hue:SetSliderHandleColor({R=1,G=1,B=1,A=1})
        local hue_slot=hue_area:AddChild(hue); hue_slot:SetHorizontalAlignment(0); hue_slot:SetVerticalAlignment(0)
        self.hue_name=identity(hue)
        ui.log("HSV HUE READY")
        ui.label(body,"HEX COLOR",11)
        local row=construct("/Script/UMG.HorizontalBox",body)
        local hex=construct("/Script/UMG.EditableTextBox",row)
        hex.SelectAllTextWhenFocused=true; hex.RevertTextOnEscape=true; hex.ClearKeyboardFocusOnCommit=true
        hex:SetIsReadOnly(false); hex:SetHintText(FText("#RRGGBB")); hex:SetForegroundColor({R=.015,G=.02,B=.025,A=1})
        local hex_size=construct("/Script/UMG.SizeBox",row); hex_size:SetHeightOverride(36); hex_size:AddChild(hex)
        slot_fill(row:AddChild(hex_size)); self.hex_name=identity(hex)
        local swatch=construct("/Script/UMG.Border",row)
        local swatch_size=construct("/Script/UMG.SizeBox",row); swatch_size:SetWidthOverride(44); swatch_size:SetHeightOverride(36); swatch_size:AddChild(swatch)
        local swatch_slot=row:AddChild(swatch_size); swatch_slot:SetPadding({Left=8,Top=0,Right=0,Bottom=0})
        self.swatch_name=identity(swatch); add_sized(body,row,36)
        ui.log("HSV HEX READY")
        -- live_picker initializes the verified selected RGB after attachment
        -- and before input polling. Avoid a redundant white draft, including
        -- five global widget lookups and writes on the unattached tree.
    end
    function self.set_rgb(rgb)
        if self.input then ui.call("HSV input.reset",self.input.reset) end
        self.h,self.s,self.v=ui.call("HSV initial RGB to HSV",function() return math_color.to_hsv(rgb,self.h) end)
        self.rgb={R=rgb.R,G=rgb.G,B=rgb.B}
        native("hue.SetValue",function() fresh(self.hue_name,"hue"):SetValue(self.h) end)
        self.hue_seen=self.h; sync_text(); paint(); marker()
    end
    function self.read()
        local hue=native("hue.GetValue",function() return fresh(self.hue_name,"hue"):GetValue() end)
        assert(type(hue)=="number" and hue==hue and hue>=0 and hue<=1,"Unreadable hue slider")
        local changed=false
        local text_changed=false
        if hue~=self.hue_seen then self.h=hue; self.hue_seen=hue; changed=true end
        local s,v=timed("sv.input",self.input.read)
        if s and (s~=self.s or v~=self.v) then self.s,self.v=s,v; changed=true end
        if changed then self.rgb=math_color.from_hsv(self.h,self.s,self.v); sync_text(); marker() end
        local raw=native("hex.GetText",function() return fresh(self.hex_name,"hex input"):GetText() end)
        local value=type(raw)=="string" and raw or raw:ToString()
        assert(type(value)=="string","Unreadable hex text")
        if value~=self.hex_seen then
            text_changed=true
            self.hex_seen=value
            local rgb=math_color.parse_hex(value); self.invalid=rgb==nil
            if rgb then
                self.rgb=rgb; self.h,self.s,self.v=math_color.to_hsv(rgb,self.h)
                native("hue.SetValue",function() fresh(self.hue_name,"hue"):SetValue(self.h) end)
                self.hue_seen=self.h; marker()
            end
        end
        -- One native tint update when hue changes; no cell-by-cell repaint.
        paint()
        return {R=self.rgb.R,G=self.rgb.G,B=self.rgb.B},self.invalid,
            changed or text_changed or (self.input.held~=nil and not self.input.held.suspended)
    end
    return self
end
return M
