-- Probe-owned stock UMG window. All methods run on the game thread.
-- No input-mode, focus or cursor writes: customization already supplies them.
local M = {}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local hsv_controls=assert(loadfile(directory .. "hsv_controls.lua"))()
local hsv_shift_controls=assert(loadfile(directory .. "hsv_shift_controls.lua"))()
local button_clicks=assert(loadfile(directory .. "button_clicks.lua"))()
local buttons=assert(loadfile(directory .. "button_class.lua"))()
local BUTTON_CLASS=buttons.PATH
local ROOT = "^UserWidget .+%.ColorsPlusPicker_Root_(%d+)$"
local HEADING_CLASS="/Game/Game/UI/Strategy/Customization/Widgets/New/WBP_Customization_SlotSubItemName.WBP_Customization_SlotSubItemName_C"
function M.new(runtime)
    local self = {root_name=nil, sliders={}, buttons={}}
    runtime.gradient_assets=runtime.gradient_assets or assert(loadfile(directory .. "gradient_assets.lua"))()
    local count = 0
    local next_root_id
    local trace_window
    local frame
    local function log(s)
        if runtime.log then runtime.log("PICKER VIEW | " .. s) end
        if runtime.perf then runtime.perf.event("PICKER VIEW | " .. s) end
    end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function call(label,fn)
        if runtime.call_trace then return runtime.call_trace.call("UI " .. label,fn) end
        return fn()
    end
    -- Session-held reuse (object_cache); identity is still verified below.
    local function find(path)
        if runtime.objects then return runtime.objects.find(path) end
        return StaticFindObject(path)
    end
    local function valid(o,label)
        if not o then return false end
        local ok, yes = pcall(function() return call((label or "object") .. ".IsValid",function() return o:IsValid() end) end)
        return ok and yes == true
    end
    local function required(o, label)
        assert(valid(o,label), "Picker widget unavailable: " .. (label or "object")); return o
    end
    local function identity(o)
        local name=required(o,"owned widget"):GetFullName()
        -- Only construction-time, same-call reuse. frame() releases this table
        -- before preview mutation and before any delayed input callback.
        if frame then frame.objects[name]=o end
        -- Owned widgets are new each opening; record them so later polls never
        -- pay a first-lookup object scan. Pinned for this picker session only.
        if runtime.objects then runtime.objects.remember(o,true) end
        return name
    end
    -- Class/factory reuse lasts only for this synchronous opening operation.
    -- Do not retain widgets or resources across callbacks or reopenings.
    local function resource(path)
        local value=frame and frame.classes[path]
        if value then return required(value,path) end
        value=timed("ui.build_resource_lookup",function()
            return required(call("class.StaticFindObject " .. path,function()
                -- The button class may need loading (hub editor).
                if path==BUTTON_CLASS then return buttons.find(runtime.log) end
                return StaticFindObject(path)
            end),path)
        end)
        if frame then frame.classes[path]=value end
        return value
    end
    local function construct_impl(path, outer, name)
        count = count + 1
        local class=resource(path)
        required(outer,"outer")
        local fname=call("construct.FName",function() return FName(name or ("ColorsPlusPicker_Widget_" .. count)) end)
        local o=required(call("StaticConstructObject " .. path,function() return StaticConstructObject(class,outer,fname) end),path)
        return o
    end
    local function construct(path,outer,name) return timed("ui.construct",construct_impl,path,outer,name) end
    local function fresh_impl(name,label)
        assert(type(name)=="string","Picker identity missing: " .. label)
        local cached=frame and frame.objects[name]
        if cached then
            required(cached,label .. " cached")
            assert(cached:GetFullName()==name,"Picker identity changed: " .. label)
            return cached
        end
        local path=assert(name:match("^[^ ]+ (.+)$"),"Malformed picker identity: " .. label)
        -- The v0.2.102 native trace stopped inside the root-relative lookup.
        -- Use only the proven one-argument full path; pcall cannot recover a
        -- native access violation. Keep same-frame reuse and identity checks.
        local found=required(call(label .. ".StaticFindObject",function()
            return call(label .. ".full.StaticFindObject " .. path,function() return find(path) end)
        end),label)
        assert(call(label .. ".GetFullName",function() return found:GetFullName() end)==name,"Picker identity changed: " .. label)
        if frame then frame.objects[name]=found end
        return found
    end
    local function fresh(name,label) return timed("ui.object_lookup",fresh_impl,name,label) end
    local function attached()
        if self.pane_binding then call("attachment.binding",function()
            assert(runtime.color_ui.binding==self.pane_binding,"Color pane ownership ended")
        end) end
        if frame and frame.attached==self.root_name then return required(frame.root,"root") end
        local root=fresh(self.root_name,"root")
        if self.pane_binding then
            call("attachment.validate_picker",function() runtime.color_ui.validate_picker(self.pane_binding) end)
            local parent=required(call("root.GetParent",function() return root:GetParent() end),"picker parent")
            assert(call("parent.GetFullName",function() return parent:GetFullName() end)==self.pane_binding.overlay,"Picker pane was detached")
        else
            assert(call("root.IsInViewport",function() return root:IsInViewport() end),"Picker was removed from viewport")
        end
        if frame then frame.root=root; frame.attached=self.root_name end
        return root
    end
    -- Scoped to one synchronous UI operation, never a delayed callback boundary.
    -- Even a failed read releases all wrappers. Re-entry/close invalidates it.
    function self.frame(fn,...)
        assert(not frame,"Nested picker UI frame")
        frame={objects={},classes={}}
        local function pack(...) return {n=select("#",...),...} end
        local results=pack(pcall(fn,...))
        frame=nil
        if not results[1] then error(results[2],0) end
        return (table.unpack or unpack)(results,2,results.n)
    end
    local function padding(slot, n) slot:SetPadding({Left=n,Top=n,Right=n,Bottom=n}) end
    local function fill(slot) slot:SetSize({SizeRule=1,Value=1}) end
    local function text(parent, value, size)
        local t = construct("/Script/UMG.TextBlock", parent)
        t:SetText(FText(value))
        t:SetColorAndOpacity({SpecifiedColor={R=.86,G=.9,B=.93,A=1},ColorUseRule=0})
        pcall(function() t.Font.Size=size or 12 end)
        return t
    end
    local function label(parent, value, size)
        local t=text(parent,value,size); padding(parent:AddChild(t),4); return t
    end
    local function native_heading(parent,pc,caption)
        -- CreateWidget initializes the game's Blueprint WidgetTree and styles;
        -- a bare StaticConstructObject does not initialize a UserWidget BP.
        local library=resource("/Script/UMG.Default__WidgetBlueprintLibrary")
        local class=resource(HEADING_CLASS)
        local heading=required(call("heading.Create",function() return library:Create(pc,class,pc) end),"native heading")
        local full=identity(heading)
        assert(full:match("^WBP_Customization_SlotSubItemName_C /"),"Unexpected native heading class")
        required(heading.WidgetTree,"native heading tree")
        required(heading.BitReactorRichTextBlock_107,"native heading text")
        heading.Caption=FText(caption) -- Construct uses Caption when attached
        heading:SetVisibility(3); heading.bIsFocusable=false
        padding(parent:AddChild(heading),4)
        self.heading_name,self.heading_caption=full,caption
    end
    local function build_button(parent, caption, action, pc)
        local library=resource("/Script/UMG.Default__WidgetBlueprintLibrary")
        local class=resource(BUTTON_CLASS)
        -- The controller was resolved in this opening call. Validate locally;
        -- no global name search or retained wrapper is needed to create a child.
        required(pc,"button player controller")
        local b=required(call("button.Create",function() return library:Create(pc,class,pc) end),"native action button")
        local full=identity(b)
        assert(full:match("^WBP_CharacterDataBank_TopNavButton_C /"),"Unexpected action button class")
        b:SetIsFocusable(false)
        b:SetIsSelectable(false)
        b:SetIsToggleable(false)
        local box=construct("/Script/UMG.SizeBox",parent)
        box:SetHeightOverride(34); box:AddChild(b)
        local slot=parent:AddChild(box); padding(slot,3); fill(slot)
        b:UpdateText(FText(caption))
        self.buttons[#self.buttons+1]={name=full,action=action,caption=caption}
        local owner=self.root_name
        button_clicks.get(runtime).bind(full,owner,action,function(received)
            if self.root_name~=owner then return end
            -- One pending action per view, Cancel takes precedence. No tint,
            -- widget removal, or scheduler call inside the native click stack.
            if not self.pending_action or received=="cancel" then
                self.pending_action=received
                self.received_at=os.clock()
                log("CLICK RECEIVED | action=" .. received .. " | root=" .. owner)
            end
        end)
    end
    local function button(parent,caption,action,pc)
        return timed("ui.action_button_build",build_button,parent,caption,action,pc)
    end
    local function remove(root)
        -- RemoveFromParent covers viewport and native-panel children alike.
        call("close.RemoveFromParent",function() root:RemoveFromParent() end)
        assert(call("close.IsInViewport readback",function() return root:IsInViewport() end) == false, "Picker viewport removal did not complete")
        if runtime.color_ui then
            assert(not valid(call("close.GetParent",function() return root:GetParent() end)),"Picker panel removal did not complete")
        end
    end
    function self.close()
        frame=nil
        if runtime.button_clicks then runtime.button_clicks.retire(self.root_name) end
        self.pending_action=nil; self.received_at=nil
        log("REMOVE BEGIN | root=" .. tostring(self.root_name))
        -- Drop child wrappers even when native root removal fails. The scalar
        -- identity is retained for a later cleanup attempt, never for polling.
        self.sliders,self.buttons={},{}
        self.hsv=nil
        self.hsv_shift=nil; self.input_mode=nil
        self.poll_ms=nil
        self.readout,self.swatch,self.status=nil,nil,nil
        self.heading_name,self.heading_caption=nil,nil
        self.status_text=nil
        if self.root_name then
            local root=call("close.StaticFindObject",function() return StaticFindObject(self.root_name:match("^[^ ]+ (.+)$")) end)
            -- An already-destroyed root needs no native removal. Do not keep a
            -- dead identity blocking future opens, or fall back to a wrapper.
            if valid(root) then
                assert(call("close.GetFullName",function() return root:GetFullName() end) == self.root_name, "Picker root identity changed")
                remove(root)
            end
        end
        self.root_name=nil
        if runtime.color_ui and runtime.color_ui.release_picker then runtime.color_ui.release_picker(self.pane_binding) end
        self.pane_binding=nil
        log("REMOVED | picker detached; palette restored")
        if runtime.call_trace then runtime.call_trace.stop(trace_window,"picker closed") end
        trace_window=nil
    end
    function self.cleanup()
        -- A Lua reload can leave a viewport alive. Remove only our exact native
        -- root class/name prefix; never touch stock or another mod's widgets.
        assert(not self.root_name, "Close the current picker before cleanup")
        if next_root_id then
            if runtime.color_ui then runtime.color_ui.release_picker(nil) end
            return next_root_id
        end
        log("CLEANUP BEGIN")
        local max_id, seen=0,0
        for _,root in pairs(FindAllOf("UserWidget") or {}) do
            seen=seen+1; assert(seen <= 8192,"Picker root scan exceeded limit")
            if valid(root) then
                local suffix=root:GetFullName():match(ROOT)
                if suffix then
                    max_id=math.max(max_id,tonumber(suffix))
                    remove(root)
                end
            end
        end
        if runtime.color_ui then runtime.color_ui.release_picker(nil) end
        next_root_id=max_id+1
        log("CLEANUP COMPLETE")
        return next_root_id
    end
    function self.open(input_mode)
        assert(not self.root_name,"Picker is already open or requires cleanup")
        assert(type(StaticConstructObject) == "function","StaticConstructObject unavailable")
        assert(input_mode==nil or input_mode=="hsv_shift","Unsupported picker input mode")
        self.input_mode=input_mode
        local trace=runtime.picker_trace_next
        runtime.picker_trace_next=nil
        if trace and runtime.call_trace then trace_window=runtime.call_trace.start("picker opening (opt-in)") end
        local next_id=timed("ui.cleanup",self.cleanup)
        next_root_id=next_id+1
        log("OPEN CONTROLLER | root=" .. next_id)
        local pc=required(call("GetPlayerController",function() return require("UEHelpers").GetPlayerController() end),"player controller")
        if runtime.objects then runtime.objects.remember(pc) end -- SV drag reacquires it by name
        assert(pc.bShowMouseCursor == true, "Open cursor-driven character customization first")
        local pane
        if runtime.color_ui then pane=timed("ui.prepare_pane",runtime.color_ui.prepare_picker) end
        local root=construct("/Script/UMG.UserWidget",pc,"ColorsPlusPicker_Root_" .. next_id)
        self.root_name=identity(root)
        assert(self.root_name:match(ROOT),"Unexpected picker root identity")
        log("BUILD BEGIN | " .. self.root_name)
        root:SetVisibility(4) -- self hit-test invisible, children interactive
        root.bIsFocusable=false
        local tree=construct("/Script/UMG.WidgetTree",root)
        root.WidgetTree=tree
        local canvas=construct("/Script/UMG.CanvasPanel",tree)
        canvas:SetVisibility(4)
        if pane then
            -- Canvas has no content-driven desired size. A fixed owned SizeBox
            -- reserves enough space for short palettes; the Overlay slot fills
            -- the actual host height when a taller grid needs more space.
            local bounds=construct("/Script/UMG.SizeBox",tree)
            bounds:SetHeightOverride(560); bounds:AddChild(canvas); tree.RootWidget=bounds
        else tree.RootWidget=canvas end
        if pane then
            -- Consume pointer input throughout the swatch host, including empty
            -- space below the controls. This owned child is removed with the
            -- picker. The native grid is also Hidden while this pane is open.
            local shield=construct("/Script/UMG.Button",canvas)
            shield:SetVisibility(0); shield.IsFocusable=false
            shield:SetBackgroundColor({R=0,G=0,B=0,A=0})
            local shield_slot=canvas:AddChild(shield)
            shield_slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
            shield_slot:SetAlignment({X=0,Y=0})
            shield_slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        end
        local panel=construct("/Script/UMG.Border",canvas)
        panel:SetVisibility(pane and 4 or 0) -- pane controls/shield handle input
        panel:SetBrushColor(pane and {R=0,G=0,B=0,A=0} or {R=.013,G=.019,B=.026,A=.98})
        panel:SetPadding({Left=14,Top=10,Right=14,Bottom=10})
        local slot=canvas:AddChild(panel)
        slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=pane and 1 or 0,Y=pane and 1 or 0}})
        slot:SetAlignment({X=0,Y=0})
        slot:SetOffsets(pane and {Left=0,Top=0,Right=0,Bottom=0} or {Left=16,Top=90,Right=390,Bottom=390})
        local body=construct("/Script/UMG.VerticalBox",panel); panel:SetContent(body)
        if pane then timed("ui.heading_build",native_heading,body,pc,input_mode=="hsv_shift" and "SCAR / HSV ADJUSTMENTS" or "CUSTOM COLOR")
        else label(body,input_mode=="hsv_shift" and "SCAR / HSV ADJUSTMENTS" or "COLORS+  /  LIVE RGB PREVIEW",16) end
        if not pane then label(body,"Selected color zone - experimental",11) end
        self.readout=identity(label(body,pane and "SATURATION / VALUE" or "R 255   G 128   B 32   /   #FF8020",14))
        if input_mode=="hsv_shift" then
            self.hsv_shift=hsv_shift_controls.new({construct=construct,fresh=fresh,call=call,label=label})
            self.hsv_shift.build(body)
            self.poll_ms=33
            log("HSV SHIFT READY | native adjustment sliders/text; selected preset retained")
        elseif pane then
            self.hsv=hsv_controls.new({construct=construct,fresh=fresh,find=find,identity=identity,call=call,text=text,label=label,log=log,
                gradients=runtime.gradient_assets,pc_name=pc:GetFullName(),perf=runtime.perf})
            timed("ui.hsv_build",self.hsv.build,body); self.swatch=self.hsv.swatch_name
            self.poll_ms=16
            log("HSV READY | click=24x16 | drag=continuous | hue=continuous | hex=RRGGBB | pane_height=host-fill | desired_height=560")
        else
        local swatch=construct("/Script/UMG.Border",body)
        self.swatch=identity(swatch)
        local swatch_size=construct("/Script/UMG.SizeBox",body)
        swatch_size:SetHeightOverride(34); swatch_size:AddChild(swatch)
        padding(body:AddChild(swatch_size),4)
        for _,key in ipairs({"R","G","B"}) do
            local row=construct("/Script/UMG.HorizontalBox",body)
            local name=label(row,key,14)
            local slider=construct("/Script/UMG.Slider",row)
            slider:SetMinValue(0); slider:SetMaxValue(255); slider:SetStepSize(1)
            slider.IsFocusable=false
            local hue={R=.05,G=.05,B=.05,A=1}; hue[key]=.85
            slider:SetSliderBarColor(hue); slider:SetSliderHandleColor({R=.95,G=.95,B=.95,A=1})
            local size=construct("/Script/UMG.SizeBox",row)
            size:SetHeightOverride(32); size:AddChild(slider)
            fill(row:AddChild(size)); padding(body:AddChild(row),3)
            self.sliders[key]=identity(slider)
        end
        local presets=construct("/Script/UMG.HorizontalBox",body)
        button(presets,"Orange","orange",pc); button(presets,"Violet","violet",pc); button(presets,"Green","green",pc)
        body:AddChild(presets)
        end
        -- Validation appears only when needed, above the action row. No footer.
        local status=text(body,"",11); body:AddChild(status); status:SetVisibility(1)
        self.status=identity(status); self.status_text=""
        local cancel=construct("/Script/UMG.HorizontalBox",body)
        button(cancel,"Cancel","cancel",pc); button(cancel,"Apply Color","apply",pc)
        body:AddChild(cancel):SetPadding({Left=0,Top=12,Right=0,Bottom=0})
        timed("ui.attach",function()
            if pane then
                local host=fresh(pane.overlay,"swatch overlay")
                local host_slot=call("overlay.AddChild",function() return host:AddChild(root) end)
                host_slot:SetHorizontalAlignment(0); host_slot:SetVerticalAlignment(0)
                self.pane_binding=pane
                attached()
                runtime.color_ui.hide_palette(pane,self.root_name)
                attached()
            else
                call("root.AddToViewport",function() root:AddToViewport(30010) end)
                assert(call("open.IsInViewport",function() return root:IsInViewport() end),"Picker was not added to viewport")
            end
        end)
        timed("ui.post_attach_labels",function()
            if self.heading_name then
                -- Reacquire after native attachment/Construct before setting text.
                call("heading.SetText",function() fresh(self.heading_name,"native heading"):SetText(FText(self.heading_caption)) end)
            end
            for _,b in ipairs(self.buttons) do fresh(b.name,"action button"):UpdateText(FText(b.caption)) end
        end)
        log("ATTACHED | " .. self.root_name)
    end
    function self.set_rgb(rgb)
        call("set_rgb.attached",attached)
        if self.hsv_shift then self.hsv_shift.set_value(rgb); return end
        if self.hsv then self.hsv.set_rgb(rgb); return end
        for _,key in ipairs({"R","G","B"}) do
            local slider=fresh(self.sliders[key],key)
            call(key .. ".SetValue",function() slider:SetValue(rgb[key]) end)
        end
    end
    function self.validate_ready()
        -- Native preview setup may notify/rebuild the surrounding page. Check
        -- the attachment afresh even if construction already seeded the color.
        attached()
    end
    function self.read()
        attached()
        local action=self.pending_action
        self.pending_action=nil
        if action then
            log(string.format("CLICK CONSUMED | action=%s | queue_cpu_ms=%.1f",action,(os.clock()-(self.received_at or os.clock()))*1000))
            self.received_at=nil
        end
        if action == "cancel" then return nil,action end
        if self.hsv_shift then
            local value,invalid,editing=self.hsv_shift.read()
            local message=invalid and "Enter H/S/V values within the slider ranges. Apply is unavailable."
                or ""
            if message~=self.status_text then
                local status=fresh(self.status,"status")
                call("status.SetText",function() status:SetText(FText(message)) end)
                call("status.SetVisibility",function() status:SetVisibility(invalid and 0 or 1) end); self.status_text=message
            end
            if invalid and action=="apply" then log("APPLY REFUSED | invalid HSV input"); action=nil end
            return value,action,not invalid,editing
        end
        if self.hsv then
            local rgb,invalid,editing=timed("ui.hsv_read",self.hsv.read)
            local message=invalid and "Enter six hex digits (#RRGGBB). Apply is unavailable."
                or ""
            if message~=self.status_text then
                local status=fresh(self.status,"status")
                call("status.SetText",function() status:SetText(FText(message)) end)
                call("status.SetVisibility",function() status:SetVisibility(invalid and 0 or 1) end); self.status_text=message
            end
            if invalid and action=="apply" then log("APPLY REFUSED | invalid hex input"); action=nil end
            return rgb,action,not invalid,editing
        end
        local rgb={}
        for _,key in ipairs({"R","G","B"}) do
            local slider=fresh(self.sliders[key],key)
            local v=call(key .. ".GetValue",function() return slider:GetValue() end)
            assert(type(v) == "number" and v == v and v >= 0 and v <= 255,"Unreadable slider " .. key)
            rgb[key]=math.floor(v+.5)
        end
        return rgb,action
    end
    function self.show(rgb,linear)
        attached()
        if self.hsv_shift then
            call("readout.SetText",function() fresh(self.readout,"readout"):SetText(FText(string.format("H %.6g   S %.6g   V %.6g",rgb.R,rgb.G,rgb.B))) end)
            return
        end
        if not self.hsv then
            local readout=fresh(self.readout,"readout")
            local value=call("readout.FText",function() return FText(string.format("R %d   G %d   B %d   /   #%02X%02X%02X",
                rgb.R,rgb.G,rgb.B,rgb.R,rgb.G,rgb.B)) end)
            call("readout.SetText",function() readout:SetText(value) end)
        end
        local swatch=fresh(self.swatch,"swatch")
        call("swatch.SetBrushColor",function() swatch:SetBrushColor(linear) end)
    end
    return self
end
return M
