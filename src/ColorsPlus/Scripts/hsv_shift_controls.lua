-- Scar material HSV adjustments, in the game's native scale. These are not
-- absolute HSV colors and never pass through sRGB/hex conversion.
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local rules=assert(loadfile(directory .. "color_rules.lua"))()
local M={}
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=1} end
local function text_value(n) return string.format("%.6g",n) end
function M.new(ui)
    local self={channels={},value={R=0,G=0,B=0,A=1}}
    local function native(label,fn) return ui.call("HSV shift " .. label,fn) end
    local function valid(c) return rules.color(c,rules.SCAR,rules.SCAR_HSV_PARAMETER) end
    local function set_slider(ch,n)
        local slider=ui.fresh(ch.slider,ch.label)
        native("SetValue",function() slider:SetValue(n) end)
        -- Retain the exact source value when the native float slider rounds it.
        -- Only subsequent input changes replace that channel's baseline.
        ch.seen=native("GetValue",function() return slider:GetValue() end)
        assert(type(ch.seen)=="number" and ch.seen==ch.seen and ch.seen>=ch.min and ch.seen<=ch.max,"Unreadable HSV adjustment slider")
    end
    local function set_text(ch,n)
        ch.text_seen=text_value(n); ch.invalid=false
        native("SetText",function() ui.fresh(ch.input,ch.label .. " input"):SetText(FText(ch.text_seen)) end)
    end
    function self.build(body)
        ui.label(body,"Adjust the selected scar look. Values use the game's HSV shift scale.",11)
        for _,spec in ipairs(rules.HSV_CHANNELS) do
            local ch={key=spec.key,label=spec.label,min=spec.min,max=spec.max}
            ui.label(body,ch.label,14)
            local row=ui.construct("/Script/UMG.HorizontalBox",body)
            local slider=ui.construct("/Script/UMG.Slider",row)
            slider:SetMinValue(ch.min); slider:SetMaxValue(ch.max); slider:SetStepSize(.1)
            slider:SetIndentHandle(false); slider.IsFocusable=false
            slider:SetSliderBarColor({R=.12,G=.18,B=.2,A=1}); slider:SetSliderHandleColor({R=.95,G=.95,B=.95,A=1})
            local size=ui.construct("/Script/UMG.SizeBox",row); size:SetHeightOverride(36); size:AddChild(slider)
            row:AddChild(size):SetSize({SizeRule=1,Value=1}); ch.slider=slider:GetFullName()
            local input=ui.construct("/Script/UMG.EditableTextBox",row)
            input.SelectAllTextWhenFocused=true; input.RevertTextOnEscape=true; input.ClearKeyboardFocusOnCommit=true
            input:SetIsReadOnly(false); input:SetForegroundColor({R=.015,G=.02,B=.025,A=1})
            local box=ui.construct("/Script/UMG.SizeBox",row)
            box:SetWidthOverride(96); box:SetHeightOverride(36); box:AddChild(input)
            row:AddChild(box):SetPadding({Left=8,Top=0,Right=0,Bottom=0}); ch.input=input:GetFullName()
            body:AddChild(row):SetPadding({Left=0,Top=0,Right=0,Bottom=16})
            self.channels[#self.channels+1]=ch
        end
        self.set_value(self.value)
    end
    function self.set_value(c)
        assert(valid(c),"Invalid scar HSV adjustments")
        self.value=copy(c)
        for _,ch in ipairs(self.channels) do set_slider(ch,c[ch.key]); set_text(ch,c[ch.key]) end
    end
    function self.read()
        local invalid,editing=false,false
        for _,ch in ipairs(self.channels) do
            local slider=ui.fresh(ch.slider,ch.label)
            local n=native("GetValue",function() return slider:GetValue() end)
            assert(type(n)=="number" and n==n and n>=ch.min and n<=ch.max,"Unreadable HSV adjustment slider")
            if n~=ch.seen then editing=true; ch.seen=n; self.value[ch.key]=n; set_text(ch,n) end
            local raw=native("GetText",function() return ui.fresh(ch.input,ch.label .. " input"):GetText() end)
            local value=type(raw)=="string" and raw or raw:ToString()
            assert(type(value)=="string","Unreadable HSV adjustment text")
            if value~=ch.text_seen then
                editing=true
                ch.text_seen=value
                local parsed=#value<=64 and tonumber(value) or nil
                ch.invalid=not (parsed and parsed==parsed and parsed>=ch.min and parsed<=ch.max)
                if not ch.invalid then self.value[ch.key]=parsed; set_slider(ch,parsed) end
            end
            invalid=invalid or ch.invalid
        end
        return copy(self.value),invalid,editing
    end
    return self
end
return M
