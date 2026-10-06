local scripts=assert(arg[1])
local objects,classes={},{}
local current_thread=true
local fail_construct,fail_remove
local scans=0
local lookups,scoped=0,0
local lookup_counts={}
local hooks={}
local function runtime_with_clicks(value)
    value=value or {}
    function value:hook(path,fn) hooks[path]=fn; return true end
    return value
end
local function obj(class,path)
    local o={class=class,path=path,children={},Font={},pressed=false,viewport=false}
    function o:IsValid() assert(current_thread,"off-thread UMG"); return not self.invalid end
    function o:GetFullName() return self.class .. " " .. self.path end
    function o:AddChild(c) self.children[#self.children+1]=c; return obj("Slot",self.path .. ".Slot" .. #self.children) end
    function o:SetContent(c) self.content=c end
    function o:SetText(t) self.text=t end
    function o:UpdateText(t) self.text=t end
    function o:SetBrushColor(c) self.brush=c end
    function o:SetVisibility(v) self.visibility=v end
    function o:SetValue(v) self.value=v end
    function o:GetValue() return self.value end
    function o:IsPressed() return self.pressed end
    function o:AddToViewport(z) self.viewport=true; self.z=z end
    function o:IsInViewport() return self.viewport end
    function o:RemoveFromParent() if fail_remove then error("remove failed") end; self.viewport=false; self.removed=true end
    for _,name in ipairs({"SetColorAndOpacity","SetPadding","SetSize","SetHeightOverride","SetBackgroundColor",
        "SetAnchors","SetAlignment","SetOffsets","SetMinValue","SetMaxValue","SetStepSize",
        "SetSliderBarColor","SetSliderHandleColor","SetIsFocusable","SetIsSelectable","SetIsToggleable"}) do
        o[name]=function(self,value) self[name .. "_arg"]=value end
    end
    objects[#objects+1]=o
    return o
end
FName=function(v) return v end
FText=function(v) return v end
StaticFindObject=function(path,...)
    lookups=lookups+1
    if path then lookup_counts[path]=(lookup_counts[path] or 0)+1 end
    if select("#",...)>0 then
        scoped=scoped+1
        error("Root-relative native lookup must not be called, even with a fallback")
    end
    if path=="/Script/UMG.Default__WidgetBlueprintLibrary" then return classes.factory end
    if path:match("^/Script/UMG%.") then
        classes[path]=classes[path] or obj("Class",path); return classes[path]
    end
    if path:find("WBP_CharacterDataBank_TopNavButton",1,true) then
        classes[path]=classes[path] or obj("Class",path); return classes[path]
    end
    for i=#objects,1,-1 do if objects[i].path==path then return objects[i] end end
end
StaticConstructObject=function(class,outer,name)
    assert(current_thread)
    if class.path==fail_construct then error("widget class unavailable") end
    return obj(class.path:match("%.([^%.]+)$"),outer.path .. "." .. name)
end
FindAllOf=function(class)
    scans=scans+1
    local list={}; for _,o in ipairs(objects) do if o.class==class then list[#list+1]=o end end
    return list
end
local pc=obj("PlayerController","/Game/Test.PlayerController_0")
classes.factory=obj("WidgetBlueprintLibrary","/Script/UMG.Default__WidgetBlueprintLibrary")
local native_buttons=0
function classes.factory:Create(context,class,player)
    assert(context==pc and player==pc)
    native_buttons=native_buttons+1
    return obj("WBP_CharacterDataBank_TopNavButton_C",pc.path .. ".Action_" .. native_buttons)
end
pc.bShowMouseCursor=true
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end} end
local stages={}
local construction_perf={event=function() end,measure=function(label,fn,...)
    stages[label]=(stages[label] or 0)+1; return fn(...)
end}
local view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime_with_clicks({perf=construction_perf}))
local function widget(full) assert(type(full)=="string"); return StaticFindObject(full:match("^[^ ]+ (.+)$")) end
local function click(index)
    local o=widget(view.buttons[index].name)
    hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"]({get=function() return o end})
end
local other=obj("UserWidget","/Game/Test.StockCustomization")
other.viewport=true
local factory_path="/Script/UMG.Default__WidgetBlueprintLibrary"
local button_path="/Game/Game/UI/Strategy/Customization/Widgets/CharacterDatabank/WBP_CharacterDataBank_TopNavButton.WBP_CharacterDataBank_TopNavButton_C"
view.frame(function()
    view.open()
    local before=lookups
    view.set_rgb({R=255,G=128,B=32})
    view.show({R=255,G=128,B=32},{R=1,G=.2,B=.01,A=1})
    assert(lookups==before,"Seed controls from owned widgets within construction frame")
end)
for _,b in ipairs(view.buttons) do
    assert(not lookup_counts[b.name:match("^[^ ]+ (.+)$")],"Post-attach captions need no global lookup")
end
assert(lookup_counts[factory_path]==1 and lookup_counts[button_path]==1,
    "All action buttons share one synchronous factory/class lookup")
assert(not lookup_counts[pc.path],"Construction must use its freshly resolved controller")
assert(stages["ui.construct"]>0 and stages["ui.build_resource_lookup"]>0
    and stages["ui.action_button_build"]==5 and stages["ui.attach"]==1
    and stages["ui.post_attach_labels"]==1,"Opening stage timings remain available without verbose tracing")
assert(widget(view.root_name):IsInViewport() and widget(view.root_name).z==30010 and widget(view.root_name).visibility==4)
assert(pc.bShowMouseCursor and other.viewport and not other.removed)
local first=widget(view.root_name)
local seed_lookups=lookups
view.set_rgb({R=255,G=128,B=32})
assert(lookups>seed_lookups,"Construction wrappers must be released before later use")
local values,action=view.read(); assert(values.R==255 and values.G==128 and values.B==32 and not action)
view.show(values,{R=1,G=.2,B=.01,A=1})
assert(widget(view.readout).text:find("#FF8020",1,true) and widget(view.swatch).brush.R==1)
widget(view.sliders.R).value=15.6; values=view.read(); assert(values.R==16)
click(2); values,action=view.read(); assert(action=="violet")
values,action=view.read(); assert(not action,"held buttons cannot repeat")
widget(view.buttons[2].name).pressed=false; view.read()
click(1); click(4)
values,action=view.read(); assert(not values and action=="cancel")
view.close(); assert(first.removed and not view.root_name and other.viewport)
local factories_before=lookup_counts[factory_path]
local classes_before=lookup_counts[button_path]
view.frame(view.open); assert(view.root_name~=first:GetFullName())
assert(lookup_counts[factory_path]==factories_before+1 and lookup_counts[button_path]==classes_before+1,
    "Reopening must reacquire native construction resources")
assert(scans==1,"reopening must not rescan retired widgets")
view.set_rgb({R=1,G=2,B=3})
click(5)
-- Released before the next poll; the event still exists, exactly once.
assert(not widget(view.buttons[5].name).pressed)
values,action=view.read(); assert(action=="apply" and values.B==3)
assert(select(2,view.read())==nil)
widget(view.buttons[5].name).pressed=false; view.read()
local oldSlider=widget(view.sliders.R)
local staleReads=0
oldSlider.IsValid=function() staleReads=staleReads+1; error("retired wrapper") end
local freshSlider=obj(oldSlider.class,oldSlider.path); freshSlider.value=42
widget(view.sliders.G).value=3; widget(view.sliders.B).value=4
values=view.read()
assert(values.R==42 and staleReads==0,"acquire by identity before touching an old wrapper")
-- Every later entry point gates children on the freshly found root attachment.
local root=widget(view.root_name); root.viewport=false
assert(not pcall(view.read))
assert(not pcall(view.set_rgb,{R=1,G=2,B=3}) and freshSlider.value==42)
assert(not pcall(view.show,{R=1,G=2,B=3},{R=1,G=0,B=0,A=1}))
root.viewport=true
-- One callback reuses live wrappers, never the next callback. Only full-path
-- lookups are allowed: native scoped-lookup crashes cannot take a Lua fallback.
local before=lookups
view.frame(function()
    view.read(); local after=lookups
    view.read(); assert(lookups==after,"Duplicate UI reads must share synchronous lookups")
end)
assert(lookups>before and scoped==0)
before=lookups; view.frame(view.read); assert(lookups>before,"No cross-frame native cache")
assert(pcall(view.frame,view.read) and scoped==0)
assert(not pcall(view.frame,function() view.read(); error("frame failed") end))
assert(pcall(view.frame,view.read),"Failed operations must release the frame")
local stale_button=widget(view.buttons[5].name)
click(5); view.close(); view.open(); view.set_rgb({R=1,G=2,B=3})
hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"]({get=function() return stale_button end})
assert(select(2,view.read())==nil,"Pending/stale clicks retire on close")
-- Reuse the live wrapper for the subsequent NaN validation case.
oldSlider.IsValid=function() return false end
widget(view.sliders.R).value=0/0
assert(not pcall(view.read)); view.close()
-- Reload cleanup removes only matching native roots, not similarly named classes.
local owned=obj("UserWidget","/Game/Test.ColorsPlusPicker_Root_90"); owned.viewport=true
local unrelated=obj("OtherWidget","/Game/Test.ColorsPlusPicker_Root_91"); unrelated.viewport=true
view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime_with_clicks()) -- full Lua-state reload
assert(view.cleanup()==91 and owned.removed and unrelated.viewport and other.viewport)
-- Construction failure is closable even before AddToViewport.
fail_construct="/Script/UMG.Slider"; assert(not pcall(view.frame,view.open) and view.root_name)
view.close(); fail_construct=nil
local slider_classes=lookup_counts["/Script/UMG.Slider"]
view.frame(view.open); view.close()
assert(lookup_counts["/Script/UMG.Slider"]==slider_classes+1,"Failed construction releases resource cache")
-- A failed removal preserves identity and blocks duplicate windows until cleanup.
view.open(); fail_remove=true; assert(not pcall(view.close) and view.root_name)
assert(not pcall(view.open)); fail_remove=false; view.close()
-- Destruction between callbacks requires no call on the old native object.
view.open(); root=widget(view.root_name); root.invalid=true
root.RemoveFromParent=function() error("Never remove destroyed widget") end
assert(not pcall(view.read)); view.close(); assert(not view.root_name)
view.open(); view.close()
-- Same-call reuse never bypasses validity/identity validation after attachment.
view.frame(function()
    view.open()
    local slider=widget(view.sliders.R)
    slider.invalid=true
    assert(not pcall(view.set_rgb,{R=1,G=2,B=3}),"Invalid constructed widget must not be reused")
    slider.invalid=false
    local original_path=slider.path; slider.path=original_path .. "_changed"
    assert(not pcall(view.set_rgb,{R=1,G=2,B=3}),"Changed constructed identity must fail closed")
    slider.path=original_path
end)
view.close()
pc.bShowMouseCursor=false; assert(not pcall(view.open) and not view.root_name and not pc.bShowMouseCursor)
-- Normal openings avoid synchronous per-call log flushing. Explicit one-shot
-- tracing still covers the actual UI boundary without changing values.
pc.bShowMouseCursor=true
local traces={}
local runtime=runtime_with_clicks({log=function(s) traces[#traces+1]=s end,after=function() end,cancel=function() end})
runtime.call_trace=assert(loadfile(scripts .. "/call_trace.lua"))().new(runtime)
view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime)
view.open(); assert(not runtime.call_trace.window); view.close()
assert(not table.concat(traces,"\n"):find("CALL TRACE",1,true))
runtime.picker_trace_next=true
view.open(); view.set_rgb({R=10,G=20,B=30})
assert(runtime.call_trace.window and runtime.picker_trace_next==nil)
values=view.read(); assert(values.R==10 and values.G==20 and values.B==30)
view.show(values,{R=.1,G=.2,B=.3,A=1})
widget(view.sliders.R).GetValue=function() error("injected slider failure",0) end
assert(not pcall(view.read))
view.close(); assert(not runtime.call_trace.window)
local joined=table.concat(traces,"\n")
for _,marker in ipairs({"BEGIN | UI R.GetValue","RETURN | UI R.GetValue",
    "RETURN | UI readout.SetText",
    "RETURN | UI swatch.SetBrushColor","ERROR | UI R.GetValue | injected slider failure",
    "RETURN | UI close.RemoveFromParent","picker closed"}) do
    assert(joined:find(marker,1,true),marker)
end
assert(scoped==0,"No picker path may attempt the native scoped overload")
-- A held object cache reuses verified identities across polls; boundaries,
-- invalid wrappers and release all force fresh full-path lookups.
local held=runtime_with_clicks({})
held.objects=assert(loadfile(scripts .. "/object_cache.lua"))().new()
view=assert(loadfile(scripts .. "/picker_view.lua"))().new(held)
held.objects.hold("picker")
before=lookups
view.frame(view.open); view.set_rgb({R=7,G=8,B=9})
view.frame(view.read)
local root_path=view.root_name:match("^[^ ]+ (.+)$")
assert(not lookup_counts[root_path],"Constructed widgets are recorded, never looked up by name")
before=lookups
for _=1,5 do values=view.frame(view.read) end
assert(lookups==before and values.R==7 and values.B==9,"Held polls must not repeat global lookups")
held.objects.invalidate()
view.frame(view.read); assert(lookups==before,"Owned picker widgets survive hook invalidation")
before=lookups
local held_slider=widget(view.sliders.R); held_slider.invalid=true
local held_fresh=obj(held_slider.class,held_slider.path); held_fresh.value=99
values=view.frame(view.read); assert(values.R==99 and lookups>before,"Invalid cached widgets must be reacquired")
root=widget(view.root_name); root.viewport=false
assert(not pcall(view.frame,view.read),"Cached root still requires live attachment")
root.viewport=true
view.close(); held.objects.release("picker")
before=lookups; assert(not held.objects.active())
assert(pcall(view.frame,view.open)); view.set_rgb({R=1,G=2,B=3}); view.frame(view.read); local after=lookups
view.frame(view.read); assert(lookups>after,"Released cache must not reuse objects")
view.close()
print("Picker UMG view: full-path-only lookup, frame reuse, layout, slider readback, button edges, owned cleanup and failure retention passed")
