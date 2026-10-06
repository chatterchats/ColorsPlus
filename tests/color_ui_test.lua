local scripts=assert(arg[1])
local objects,classes,jobs,logs={},{},{},{}
local shared={}
ModRef={GetSharedVariable=function(_,key) return shared[key] end,
    SetSharedVariable=function(_,key,value) assert(type(value)=="string"); shared[key]=value end}
local global_scans=0
local fail_remove,fail_construct=false,nil
local brush_writes=0
local hooks={}
local function object(kind,path)
    local o={kind=kind,path=path,children={},Font={},visibility=0,active=true}
    function o:IsValid() return not self.invalid end
    function o:GetFullName() return self.kind .. " " .. self.path end
    function o:IsVisible() return not self.invalid and self.visibility~=1 and self.visibility~=2 end
    function o:GetVisibility() return self.visibility end
    function o:IsActivated() return self.active end
    function o:GetParent() return self.parent end
    function o:GetCachedGeometry() error("Opaque native geometry must not be used") end
    function o:GetAllChildren() return self.children end
    function o:GetChildAt(i) return self.children[i+1] end
    function o:GetChildrenCount() return #self.children end
    function o:AddChild(child)
        self.children[#self.children+1]=child; child.parent=self
        local slot=object(self.kind .. "Slot",self.path .. ".Slot" .. #self.children)
        child.Slot=slot
        return slot
    end
    function o:SetContent(child) self:AddChild(child) end
    function o:RemoveFromParent()
        if fail_remove and self.kind=="UserWidget" then error("remove failed") end
        if self.parent then
            for i,v in ipairs(self.parent.children) do if v==self then table.remove(self.parent.children,i); break end end
        end
        self.parent=nil; self.viewport=false
    end
    function o:IsInViewport() return self.viewport==true end
    function o:AddToViewport() error("Integrated picker must not use viewport") end
    function o:SetVisibility(v) self.visibility=v end
    function o:SetText(v) self.text=v end
    function o:UpdateText(v) self.text=v end
    function o:GetText() return self.text end
    function o:IsHovered() return self.hovered==true end
    function o:SetBrushColor(v,...)
        assert(select("#",...)==0,"SetBrushColor expects exactly one argument, matching native UFunction arity")
        brush_writes=brush_writes+1; self.brush=v
    end
    function o:SetStyle() error("Whole Slate style marshalling is forbidden after the native crash") end
    function o:SetBrushFromTexture(texture,match,...)
        assert(select("#",...)==0 and match==false and texture:IsValid())
        self.texture=texture
    end
    function o:SetValue(v) self.value=v; self.value_writes=(self.value_writes or 0)+1 end
    function o:GetValue() return self.value end
    function o:IsPressed() return self.pressed==true end
    function o:SetPadding(v) self.SetPadding_arg=v; self.Padding=v end
    for _,fn in ipairs({"SetHeightOverride","SetWidthOverride","SetSize","SetVerticalAlignment",
        "SetHorizontalAlignment","SetBackgroundColor","SetColorAndOpacity","SetAnchors","SetAlignment","SetOffsets",
        "SetMinValue","SetMaxValue","SetStepSize","SetSliderBarColor","SetSliderHandleColor",
        "SetIndentHandle","SetIsReadOnly","SetHintText","SetForegroundColor",
        "SetIsFocusable","SetIsSelectable","SetIsToggleable"}) do
        o[fn]=function(self,v) self[fn .. "_arg"]=v end
    end
    objects[o:GetFullName()]=o; return o
end
local a={unwrap=function(v) return v end,live=function(v) return v and v.IsValid and v:IsValid() and not v.path:find("Default__",1,true) end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,
    text=tostring,values=function(v) assert(type(v)=="table"); return v end}
function StaticFindObject(path,outer,relative)
    if outer then path=outer.path .. "." .. relative end
    if path:match("^/Script/UMG%.[A-Z]") and not path:find("Default__",1,true) then
        classes[path]=classes[path] or object("Class",path); return classes[path]
    end
    for _,o in pairs(objects) do if o.path==path then return o end end
end
function StaticConstructObject(class,outer,n)
    if class.path==fail_construct then error("construction failed") end
    return object(class.path:match("%.([^%.]+)$"),outer.path .. "." .. n)
end
function FindAllOf(kind)
    global_scans=global_scans+1
    local list={}; for _,o in pairs(objects) do if o.kind==kind then list[#list+1]=o end end; return list
end
FName=function(v) return v end
FText=function(v) return v end
local imports=0
local importer=object("KismetRenderingLibrary","/Script/Engine.Default__KismetRenderingLibrary")
function importer:ImportFileAsTexture2D(context,path)
    assert(context:IsValid()); local file=assert(io.open(path,"rb")); file:close()
    imports=imports+1; return object("Texture2D","/Engine/Transient.Gradient_" .. imports)
end
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local master=object("WBP_CustomCharacter_Master_C",host .. ".WBP_CustomCharacter_Master_C_2")
local page=object("WBP_Customization_ItemPage_C",host .. ".WBP_Customization_ItemPage_C_3")
local game_stack=object("BitReactorActivatableWidgetStack",host .. ".GameLayer_Stack")
game_stack.parent=object("CanvasPanel",host .. ".MainOverlay")
game_stack.WidgetList={master,page}; game_stack.GetActiveWidget=function() return page end
local panel=object("WBP_CustomizationSlotPanel_C",page.path .. ".WidgetTree_4.WBP_CustomizationSlotPanel")
page.WBP_CustomizationSlotPanel=panel
local switcher=object("CommonActivatableWidgetSwitcher",page.path .. ".WidgetTree_4.SlotWidgetSwitcher")
switcher.GetActiveWidget=function() return panel end; page.SlotWidgetSwitcher=switcher
local tiles=object("WBP_Customization_SelectionTiles_C",panel.path .. ".WidgetTree_5.WBP_Customization_SelectionTiles")
panel.WBP_Customization_SelectionTiles=tiles
local tree=tiles.path .. ".WidgetTree_6"
local stack=object("VerticalBox",tree .. ".VerticalBox_0")
local overlay=object("Overlay",tree .. ".Overlay_0")
local grid=object("BitReactorTileView",tree .. ".PartsGridList")
-- In-game shape (logged on v0.3.0): Overlay_0 holds the selector stack; the
-- stack holds SizeBox_0, whose MaxDesiredHeight caps the swatch area so the
-- palette fits its background box. A fixed width stands in for the derived
-- column width here (the real column derives it from the panel above).
local grid_box=object("SizeBox",tree .. ".SizeBox_0")
grid_box.bOverride_WidthOverride=true; grid_box.WidthOverride=480
grid_box.bOverride_MaxDesiredHeight=true; grid_box.MaxDesiredHeight=550
function grid_box:SetMaxDesiredHeight(v) self.MaxDesiredHeight=v end
overlay:AddChild(stack); stack:AddChild(grid_box); grid_box:AddChild(grid); tiles.PartsGridList=grid
-- Labels and a mod-added slider can sit above the nearest picker host/stack.
-- Preserve that ancestry but hide its sibling branches, including nested UI.
local palette_root=object("VerticalBox",tree .. ".PaletteRoot")
local zone_label=object("WBP_Customization_SlotSubItemName_C",tree .. ".SlotName")
local recolour_label=object("WBP_Customization_SlotSubItemName_C","/Engine/Transient.InjectedLabel_1"); recolour_label.visibility=3
local slider_box=object("WBP_COS_SliderRow_C","/Engine/Transient.InjectedSlider_1"); slider_box.visibility=4
local recolour_slider=object("Slider",slider_box.path .. ".WidgetTree.Slider"); recolour_slider.value=1
slider_box:AddChild(recolour_slider)
palette_root:AddChild(zone_label); palette_root:AddChild(recolour_label)
palette_root:AddChild(slider_box)
palette_root:AddChild(overlay)
-- Tiles are 75 wide, left aligned, 7 items: one full row of 6 in 480. The
-- swatch SizeBox sits 10px in from the stack's left edge.
grid_box.Slot.Padding={Left=10,Top=10,Right=0,Bottom=0}
function grid:GetEntryWidth() return 75 end
function grid:GetNumItems() return 7 end
grid.HorizontalEntrySpacing=0; grid.bEntrySizeIncludesEntrySpacing=false; grid.TileAlignment=3
local header=object("TextBlock",page.path .. ".WidgetTree_4.SlotHeader")
local tag="br.Customization.Slot.Character.Hair.Hair.Color.Primary"
local vm=object("BitReactorCustomizationSlotViewModel","/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.BitReactorCustomizationSlotViewModel_7")
vm.SlotTag={TagName=tag}; vm.GetFragments=function() return {} end
tiles.CurrentSlotTag={TagName=tag}
local pc=object("PlayerController","/Game/Test.PlayerController_0"); pc.bShowMouseCursor=true
local heading_class_path="/Game/Game/UI/Strategy/Customization/Widgets/New/WBP_Customization_SlotSubItemName.WBP_Customization_SlotSubItemName_C"
local heading_class=object("WidgetBlueprintGeneratedClass",heading_class_path)
local button_class=object("WidgetBlueprintGeneratedClass","/Game/Game/UI/Strategy/Customization/Widgets/CharacterDatabank/WBP_CharacterDataBank_TopNavButton.WBP_CharacterDataBank_TopNavButton_C")
local widget_factory=object("WidgetBlueprintLibrary","/Script/UMG.Default__WidgetBlueprintLibrary")
local heading_creates=0
local fail_heading_create,fail_heading_text
local button_creates=0
function widget_factory:Create(context,class,player,...)
    if class==button_class then
        assert(context==pc and player==pc and select("#",...)==0)
        button_creates=button_creates+1
        return object("WBP_CharacterDataBank_TopNavButton_C",pc.path .. ".Action_" .. button_creates)
    end
    assert(select("#",...)==0 and context==pc and player==pc and class==heading_class,
        "CreateWidget requires exactly world context, Blueprint class and owning player")
    if fail_heading_create then error("heading creation failed") end
    heading_creates=heading_creates+1
    local h=object("WBP_Customization_SlotSubItemName_C",pc.path .. ".NativeHeading_" .. heading_creates)
    h.WidgetTree=object("WidgetTree",h.path .. ".WidgetTree")
    h.BitReactorRichTextBlock_107=object("BitReactorRichTextBlock",h.WidgetTree.path .. ".Caption")
    h.WidgetTree.RootWidget=object("HorizontalBox",h.WidgetTree.path .. ".NativeRow")
    h.WidgetTree.RootWidget:AddChild(object("Image",h.WidgetTree.path .. ".NativeBranchMarker"))
    h.WidgetTree.RootWidget:AddChild(h.BitReactorRichTextBlock_107)
    h.Caption="STOCK CAPTION"
    function h:SetText(value,...)
        assert(select("#",...)==0 and self.Caption==value,"Caption must survive native Construct")
        if fail_heading_text then error("heading text failed after attachment") end
        self.BitReactorRichTextBlock_107:SetText(value)
    end
    return h
end
local mouse_x,mouse_y=1000,500
local layout=object("WidgetLayoutLibrary","/Script/UMG.Default__WidgetLayoutLibrary")
function layout:GetMousePositionScaledByDPI(controller,x,y)
    assert(controller==pc and x==y); x.LocationX=100; x.LocationY=100; return true
end
function layout:GetMousePositionOnPlatform() return {X=mouse_x,Y=mouse_y} end
function layout:GetViewportScale() return 1 end
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end} end
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:hook(path,fn) hooks[path]=fn; return true end
function runtime:after(k,delay,fn) jobs[k]={delay=delay,fn=fn} end
function runtime:cancel(k) jobs[k]=nil end
local function run(k) local job=assert(jobs[k],k); jobs[k]=nil; job.fn() end
local opens,closes=0,0
runtime.picker={open=function() opens=opens+1; runtime.picker.active={} end,
    close=function() closes=closes+1; runtime.picker.active=nil; return true end}
local tint={selected_slot_identity=function() return vm:GetFullName() end}
local ui=assert(loadfile(scripts .. "/color_ui.lua"))().new(runtime,a,tint); runtime.color_ui=ui
local function find(full) return assert(StaticFindObject(full:match("^[^ ]+ (.+)$"))) end
local function click(view,index)
    local o=find(view.buttons[index].name)
    hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"]({get=function() return o end})
end
-- The launcher is the game's CommonUI button; a click latches, the 1ms
-- launch job pauses swatch input and queues the deferred opening.
local function launch_click()
    local o=find(ui.button_name)
    hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"]({get=function() return o end})
end
ui.start(); run("color-ui:startup"); run("color-ui:install")
local binding=assert(ui.binding)
assert(#stack.children==1 and #overlay.children==2 and grid.visibility==0,"The launcher sits in the column's overlay")
assert(ui.reconcile()==binding and #overlay.children==2,"No duplicate launcher")
local scans_before=global_scans
assert(ui.reconcile()==binding and global_scans==scans_before,"Verified launcher must not rediscover global pages")
local root_name=ui.root_name
local button=find(ui.button_name)
assert(button.kind=="WBP_CharacterDataBank_TopNavButton_C" and button.text=="CUSTOM COLOR",
    "Launcher uses the game's native button with its caption set after attachment")
local launcher_root=find(root_name)
local rainbow
for _,o in pairs(objects) do
    if o.kind=="Image" and o.path:sub(1,#launcher_root.path+1)==launcher_root.path .. "." then
        assert(not rainbow,"Launcher must have one gradient image")
        assert(o.visibility==3,"Rainbow decoration must be visible and hit-test invisible")
        rainbow=o
    end
end
assert(rainbow and rainbow.texture and imports==1)
assert(rainbow.parent.SetWidthOverride_arg==42 and rainbow.parent.SetHeightOverride_arg==24)
local launcher=find(root_name)
assert(launcher.parent==overlay and launcher.Slot.SetVerticalAlignment_arg==3 and launcher.Slot.SetHorizontalAlignment_arg==0,
    "Launcher sits at the bottom of the column overlay, adding no height")
assert(grid.Slot.Padding.Bottom==52 and grid_box.MaxDesiredHeight==550,
    "A band inside the capped swatch area holds the launcher; the cap itself is untouched")
local launcher_size=launcher.WidgetTree.RootWidget.children[1]
assert(launcher_size.SetWidthOverride_arg==450 and launcher_size.Slot.SetHorizontalAlignment_arg==1
    and launcher_size.Slot.SetPadding_arg.Left==10,"Launcher spans exactly the six-swatch row")
local layout_logged=false
for _,line in ipairs(logs) do
    if line:find("LAUNCHER LAYOUT | height=band bottom 0->52 | width=450.0 left=10.0 column=480.0 per_line=6 align=left",1,true) then layout_logged=true end
end
assert(layout_logged,"Launcher layout records the values it used")
local footer=launcher.WidgetTree.RootWidget
assert(footer.kind=="Overlay" and footer.visibility==4)
assert(footer.children[1].SetHeightOverride_arg==44 and footer.children[1].Slot.SetVerticalAlignment_arg==2)
assert(jobs["color-ui:poll"].delay==100,"The first layout check runs soon after the page builds")
-- Another widget re-applies the grid padding after ours: adopt it as stock
-- and reserve the band again; a cap changed by others is never touched.
grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=8}); grid_box.MaxDesiredHeight=455; run("color-ui:poll")
assert(grid.Slot.Padding.Bottom==60 and grid_box.MaxDesiredHeight==455,"Padding reset by another widget is adopted and the band reserved again")
assert(jobs["color-ui:poll"].delay==500,"Launcher validation is a slow backstop, not an input poll")
run("color-ui:poll"); assert(grid.Slot.Padding.Bottom==60,"Our own band is not reserved twice")
grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0}); grid_box.MaxDesiredHeight=550; run("color-ui:poll")
assert(grid.Slot.Padding.Bottom==52)
launch_click(); assert(grid.visibility==0 and not jobs["color-ui:open"],"No widget work inside the native click stack")
run("color-ui:launch"); assert(opens==0 and jobs["color-ui:open"].delay==100)
assert(grid.visibility==3,"Swatches stop taking the mouse from the launch click")
run("color-ui:open"); assert(opens==1)
assert(grid.visibility==0,"Launch completion restores input the picker never took over")
launch_click(); assert(not jobs["color-ui:launch"],"Clicks while the picker is open are ignored")
runtime.picker.close()
-- A refused launch restores the stock swatch input.
launch_click(); run("color-ui:launch")
assert(grid.visibility==3 and jobs["color-ui:open"])
local validate_launch=ui.validate_picker
ui.validate_picker=function() error("launch refused for test") end
run("color-ui:open"); ui.validate_picker=validate_launch
assert(grid.visibility==0 and opens==1,"A refused launch restores swatch input")
-- The real picker below opens while input is paused; hiding must record the
-- stock value (checked when the view closes), not the temporary pause.
launch_click(); run("color-ui:launch")
assert(grid.visibility==3); runtime:cancel("color-ui:open")
assert(ui.prepare_picker()==binding,"Opening must not depend on geometry marshalling")
-- Real view fills only the verified lower selector host, without geometry calls.
local view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime)
view.open(); assert(find(view.root_name).parent==overlay and view.pane_binding==binding)
assert(grid.Slot.Padding.Bottom==0,"The picker keeps the stock swatch layout")
assert(not find(view.hsv.hue_name).value_writes and not find(view.hsv.hex_name).text
    and not view.hsv.painted_h,"Build must not initialize an unused white draft")
local native_heading=find(view.heading_name)
assert(heading_creates==1 and native_heading.kind=="WBP_Customization_SlotSubItemName_C"
    and native_heading.BitReactorRichTextBlock_107.text=="CUSTOM COLOR" and native_heading.Caption=="CUSTOM COLOR",
    "Use the game's native heading, including its caption/style, rather than a glyph in a TextBlock")
assert(native_heading.visibility==3 and native_heading.bIsFocusable==false
    and native_heading.WidgetTree.RootWidget.children[1].kind=="Image",
    "Keep the native marker and make the decorative heading ignore input")
assert(#overlay.children==3 and grid.visibility==2 and grid.parent==grid_box,
    "Native swatches must be Hidden without removing their layout space")
assert(zone_label.visibility==2 and recolour_label.visibility==2 and slider_box.visibility==2
    and launcher.visibility==2,"Both labels, the slider branch and our launcher must disappear")
assert(palette_root.visibility==0 and stack.visibility==0 and overlay.visibility==0
    and header.visibility==0 and recolour_slider.value==1,"Keep the host/header visible and slider value intact")
assert(ui.reconcile()==binding,"Palette discovery must retain the active grid while it is Hidden")
local validator=ui.validate_picker
ui.validate_picker=function() error("Hidden launcher must not duplicate picker validation") end
run("color-ui:poll")
assert(jobs["color-ui:poll"].delay==500,"Hidden launcher keeps only the slow backstop")
ui.validate_picker=validator
local bounds=find(view.root_name).WidgetTree.RootWidget
assert(bounds.kind=="SizeBox" and bounds.SetHeightOverride_arg==560,"Short selectors must reserve the full pane height")
local canvas=bounds.children[1]
local shield=canvas.children[1]
assert(shield.kind=="Button" and shield.visibility==0 and shield.IsFocusable==false,
    "A non-focusable owned input shield must precede the controls")
assert(shield.SetBackgroundColor_arg.A==0 and #shield.children==0)
assert(shield.Slot.SetAnchors_arg.Minimum.X==0 and shield.Slot.SetAnchors_arg.Minimum.Y==0
    and shield.Slot.SetAnchors_arg.Maximum.X==1 and shield.Slot.SetAnchors_arg.Maximum.Y==1)
local shield_offsets=shield.Slot.SetOffsets_arg
assert(shield_offsets.Left==0 and shield_offsets.Top==0 and shield_offsets.Right==0 and shield_offsets.Bottom==0,
    "The input shield must include the area beneath picker controls")
local pane_slot=canvas.children[2].Slot
assert(pane_slot.SetAnchors_arg.Minimum.X==0 and pane_slot.SetAnchors_arg.Minimum.Y==0)
assert(pane_slot.SetAnchors_arg.Maximum.X==1 and pane_slot.SetAnchors_arg.Maximum.Y==1)
local offsets=pane_slot.SetOffsets_arg
assert(offsets.Left==0 and offsets.Top==0 and offsets.Right==0 and offsets.Bottom==0)
assert(canvas.children[2].brush.A==0 and canvas.children[2].visibility==4,
    "The integrated picker must have no background while its native palette is Hidden")
assert(find(view.root_name).Slot.SetHorizontalAlignment_arg==0
    and find(view.root_name).Slot.SetVerticalAlignment_arg==0,"Picker must cover taller palettes across the full host")
view.set_rgb({R=12,G=34,B=56}); local rgb=view.read(); assert(rgb.R==12 and rgb.B==56)
assert(select(4,view.read())==false,"Unchanged HSV input is idle")
find(view.hsv.hex_name).text="invalid"
assert(select(4,view.read())==true,"Invalid text changes still count as editing")
assert(select(4,view.read())==false,"Unchanged invalid text is not perpetual editing")
view.set_rgb({R=12,G=34,B=56})
shield.pressed=true
local unchanged,shield_action=view.read()
assert(not shield_action and unchanged.B==56,"Clicking empty picker space must not trigger a picker action")
shield.pressed=false
view.show(rgb,{R=.1,G=.2,B=.3,A=1})
local hsv=view.hsv
assert(#hsv.rows==16 and #hsv.rows[1].cells==24)
for _,row in ipairs(hsv.rows) do
    for _,name in ipairs(row.cells) do
        local cell=find(name)
        assert(cell.SetBackgroundColor_arg.A==0 and #cell.children==0,"Input buttons must not own gradient visuals")
    end
end
local area=find(hsv.base_name).parent
assert(area.parent.SetWidthOverride_arg==400 and area.parent.SetHeightOverride_arg==240)
assert(area.parent.Slot.SetHorizontalAlignment_arg==2,"Owned fixed SV dimensions must be centered")
local hue_size=find(hsv.hue_name).parent.parent
assert(hue_size.kind=="SizeBox" and hue_size.SetWidthOverride_arg==area.parent.SetWidthOverride_arg
    and hue_size.Slot.SetHorizontalAlignment_arg==area.parent.Slot.SetHorizontalAlignment_arg,
    "Hue and SV must share the same centered width")
assert(#view.buttons==2 and view.buttons[1].action=="cancel" and view.buttons[2].action=="apply",
    "Cancel is the only return-to-swatches button")
local actions=find(view.buttons[1].name).parent.parent
assert(actions.Slot.SetPadding_arg.Top==12,"Leave space between hex row and actions")
assert(find(view.status).visibility==1 and find(view.status).text=="",
    "A valid draft has no footer or reserved validation row")
assert(actions.parent.children[#actions.parent.children]==actions,"Nothing should be drawn below Cancel/Apply")
assert(area.children[1]==find(hsv.base_name))
assert(area.children[2]==find(hsv.gradient_names.saturation) and area.children[3]==find(hsv.gradient_names.value))
assert(area.children[4]==find(hsv.rows[1].name).parent,"Input grid is above the visual layers")
for _,name in pairs(hsv.gradient_names) do
    local image=find(name)
    assert(image.kind=="Image" and image.visibility==3 and image.texture:IsValid())
end
assert(imports==3,"Import only three gradient assets, not per-cell textures")
assert(find(hsv.gradient_names.hue).texture==rainbow.texture,"Launcher and picker share one native hue texture")
assert(find(hsv.swatch_name).brush.R==.1)
local hex=find(hsv.hex_name)
local hex_row=hex.parent.parent
local hex_row_size=hex_row.parent
assert(hex_row_size.kind=="SizeBox" and hex_row_size.SetWidthOverride_arg==area.parent.SetWidthOverride_arg
    and hex_row_size.Slot.SetHorizontalAlignment_arg==area.parent.Slot.SetHorizontalAlignment_arg,
    "Combined hex input/preview must share the centered SV/hue width")
assert(hex_row.children[1].Slot.SetSize_arg.SizeRule==1 and hex_row.children[2].SetWidthOverride_arg==44
    and hex_row.children[2].Slot.SetPadding_arg.Left==8,"Preview and gap stay within the row's width")
assert(hex.SetForegroundColor_arg.R<.03 and hex.SetForegroundColor_arg.A==1,"Dark input text on native light background")
assert(hex.text=="#0C2238")
hex.text="ff8020"; rgb=view.read(); assert(rgb.R==255 and rgb.G==128 and rgb.B==32)
assert(hsv.invalid==false)
-- Partially typed/invalid text holds the last valid draft and blocks Apply.
hex.text="#12"; click(view,2)
rgb,action=view.read(); assert(rgb.R==255 and not action and hsv.invalid)
assert(find(view.status).text:find("six hex digits",1,true))
assert(find(view.status).visibility==0,"Invalid input shows guidance above the actions")
find(view.buttons[2].name).pressed=false
hex.text="#00FFFF"; rgb=view.read(); assert(rgb.R==0 and rgb.G==255 and rgb.B==255)
assert(find(view.status).visibility==1 and find(view.status).text=="","Valid input removes guidance again")
-- A hue-only adjustment on grey preserves the intended hue for later SV edits.
view.set_rgb({R=128,G=128,B=128})
local paint_before=brush_writes
find(hsv.hue_name).value=.25; rgb=view.read(); assert(rgb.R==128 and rgb.B==128)
assert(brush_writes-paint_before==1,"Hue redraw must require exactly one background tint update")
for _=1,7 do view.read() end
assert(brush_writes-paint_before==1 and hsv.painted_h==.25,"Idle polling must not repaint gradients")
find(hsv.hue_name).value=.5
find(hsv.rows[1].name).hovered=true; find(hsv.rows[1].cells[24]).pressed=true
rgb=view.read(); assert(rgb.R==0 and rgb.G==255 and rgb.B==255 and hex.text=="#00FFFF")
find(hsv.rows[1].name).hovered=false; find(hsv.rows[1].cells[24]).pressed=false
view.read() -- release the captured seed before the next input
-- Integrated input follows captured desktop deltas even outside the seed row,
-- while viewport mouse coordinates stay frozen. The marker/hex update together.
local row=hsv.rows[8]; local cell=find(row.cells[12])
find(row.name).hovered=true; cell.pressed=true; view.read()
local start_s,start_v=hsv.s,hsv.v
find(row.name).hovered=false; mouse_x=mouse_x+100; mouse_y=mouse_y+60
rgb=view.read()
assert(math.abs(hsv.s-start_s-.25)<1e-9 and math.abs(hsv.v-start_v+.25)<1e-9)
assert(hex.text==string.format("#%02X%02X%02X",rgb.R,rgb.G,rgb.B))
local marker_slot=find(hsv.marker_slot)
assert(marker_slot.SetAnchors_arg.Minimum.X==hsv.s and marker_slot.SetAnchors_arg.Minimum.Y==1-hsv.v)
assert(select(4,view.read())==true,"Held stationary SV capture is still editing")
cell.pressed=false; assert(select(4,view.read())==false,"Released unchanged SV input is idle")
view.set_rgb({R=0,G=255,B=255})
-- Hovering alone must never change a draft.
find(hsv.rows[16].name).hovered=true; rgb=view.read(); assert(rgb.G==255)
find(hsv.rows[16].name).hovered=false
-- Use actual FText conversion, not arbitrary wrapper probing.
hex.GetText=function() return {ToString=function() return "#123456" end} end
rgb=view.read(); assert(rgb.R==18 and rgb.G==52 and rgb.B==86)
hex.GetText=function(self) return self.text end; hex.text="#123456"
-- New wrappers are acquired by identity; a stale hue wrapper is never reused.
local old_hue=find(hsv.hue_name)
local next_hue=object("Slider",old_hue.path); next_hue.value=hsv.hue_seen
old_hue.IsValid=function() error("retired HSV hue wrapper touched") end
rgb=view.read(); assert(rgb.B==86)
old_hue.IsValid=function() return false end
assert(find(view.buttons[1].name).text=="Cancel")
click(view,1)
local value,action=view.read(); assert(value==nil and action=="cancel")
view.close(); assert(#overlay.children==2 and ui.root_name==root_name and grid.visibility==0)
assert(grid.Slot.Padding.Bottom==52,"Closing the picker re-reserves the launcher band")
assert(zone_label.visibility==0 and recolour_label.visibility==3 and slider_box.visibility==4
    and launcher.visibility==4 and recolour_slider.value==1,"Close restores every original visibility exactly")
assert(not view.hsv,"HSV child identities retire with the owned view")
assert(not view.heading_name and not view.heading_caption,"Native heading identity retires with the owned root")
-- A fresh Lua view restores visibility after removing a stranded owned root.
view.open(); local abandoned=find(view.root_name)
local recovered_ui=assert(loadfile(scripts .. "/color_ui.lua"))().new(runtime,a,tint)
runtime.color_ui=recovered_ui
local recovered_view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime)
recovered_view.cleanup()
assert(grid.visibility==0 and not abandoned.parent and #overlay.children==2,
    "Lua recovery must reveal the exact palette after retiring its picker")
assert(zone_label.visibility==0 and recolour_label.visibility==3 and slider_box.visibility==4
    and launcher.visibility==4,"Lua recovery restores labels, slider and launcher as well as the grid")
runtime.color_ui=ui; view.close()
-- Native heading failures must be closable before and after palette hiding.
fail_heading_create=true
assert(not pcall(view.open) and view.root_name and grid.visibility==0)
fail_heading_create=nil; view.close(); assert(launcher.visibility==4 and #overlay.children==2)
fail_heading_text=true
assert(not pcall(view.open) and view.root_name and grid.visibility==2)
fail_heading_text=nil; view.close()
assert(grid.visibility==0 and zone_label.visibility==0 and slider_box.visibility==4
    and launcher.visibility==4 and #overlay.children==2,"Late heading failure restores the complete palette")
-- Actual coordinator plus native HSV view: Apply flushes current hex even
-- between 5Hz backend updates; Cancel remains first even with broken inputs.
local old_picker=runtime.picker
local live_view=assert(loadfile(scripts .. "/picker_view.lua"))().new(runtime)
local applied,updated,cancelled
local fake_tint={}
function fake_tint.begin_live()
    local session={live=true,test_color={R=1,G=0,B=0,A=1}}
    fake_tint.pending=session; return session
end
function fake_tint.update_live(session,color) assert(fake_tint.pending==session); updated=color; return true end
function fake_tint.apply_live(session) applied=updated; fake_tint.pending=nil; session.live=false; return true end
function fake_tint.cancel_live() cancelled=true; fake_tint.pending=nil; return true end
function fake_tint.check_live() return true end
local input=assert(loadfile(scripts .. "/rgb_input.lua"))()
runtime.call_trace=assert(loadfile(scripts .. "/call_trace.lua"))().new(runtime)
runtime.trace_picker_initialization=true
runtime.picker=assert(loadfile(scripts .. "/live_picker.lua"))().new(runtime,fake_tint,live_view,input)
assert(runtime.picker.open())
assert(find(live_view.hsv.hue_name).value_writes==1
    and find(live_view.hsv.hex_name).text=="#FF0000",
    "Coordinator initializes the selected RGB exactly once before polling")
assert(not runtime.call_trace.window and not jobs["call-trace:expiry"])
local opening_logs=table.concat(logs,"\n")
for _,boundary in ipairs({"OPEN STEP view.set_rgb","UI set_rgb.attached","UI attachment.validate_picker",
    "UI HSV initial RGB to HSV","UI HSV hue.SetValue","UI HSV hex.SetText",
    "UI HSV marker.SetAnchors","UI HSV marker.SetAlignment","UI HSV marker.SetOffsets","OPEN STEP view.show"}) do
    assert(opening_logs:find("BEGIN | " .. boundary,1,true),boundary)
    assert(opening_logs:find("RETURN | " .. boundary,1,true),boundary)
end
find(live_view.hsv.hex_name).text="#FF8020"
click(live_view,2)
run("picker:tick")
assert(applied.R==1 and math.abs(applied.G-input.parse("255,128,32").G)<1e-9)
assert(not runtime.picker.active and not live_view.root_name and #overlay.children==2 and grid.visibility==0,
    "Apply must reveal the original palette")
assert(zone_label.visibility==0 and recolour_label.visibility==3 and slider_box.visibility==4
    and launcher.visibility==4,"Apply restores the complete native selector")
assert(runtime.picker.open())
find(live_view.hsv.hex_name).text="bad input"
find(live_view.hsv.hue_name).GetValue=function() error("Cancel must bypass child input reads") end
click(live_view,1)
run("picker:tick"); assert(cancelled and not runtime.picker.active and not jobs["picker:tick"] and grid.visibility==0)
assert(zone_label.visibility==0 and recolour_label.visibility==3 and slider_box.visibility==4
    and launcher.visibility==4,"Cancel restores the complete native selector")
runtime.picker=old_picker
runtime.call_trace=nil; runtime.trace_picker_initialization=nil
-- Retired native wrappers are never retained. The path is reacquired each use.
local retired_grid=grid
grid=object("BitReactorTileView",retired_grid.path)
grid.parent=grid_box; grid.Slot=object("SizeBoxSlot",grid_box.path .. ".Slot1"); tiles.PartsGridList=grid
function grid:GetEntryWidth() return 75 end
function grid:GetNumItems() return 7 end
grid.HorizontalEntrySpacing=0; grid.bEntrySizeIncludesEntrySpacing=false; grid.TileAlignment=3
grid_box.children[1]=grid -- a fresh native GetAllChildren call returns fresh wrappers too
retired_grid.IsValid=function() error("old grid wrapper touched") end
assert(ui.validate_picker(binding)); retired_grid.IsValid=function() return false end
local before=opens
launch_click(); run("color-ui:launch")
local queued=jobs["color-ui:open"].fn
-- Slot change retires a launcher before bounded installation runs: installation
-- request generation must remain independent of the retired poll generation.
tag="br.Customization.Slot.Character.Hair.Hair.Color.Secondary"
vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
ui.context_changed("UpdateCurrentCustomizationSlotVM")
run("color-ui:poll"); assert(not ui.binding and not ui.root_name)
queued(); assert(opens==before)
run("color-ui:install"); assert(ui.binding and ui.binding.tag==tag and #overlay.children==2)
local stale_poll=jobs["color-ui:poll"].fn
local retired_button=find(ui.button_name)
assert(runtime.button_clicks.routes[ui.button_name],"Launcher click route is bound while attached")
ui.context_changed("page closed"); assert(not ui.binding and not jobs["color-ui:poll"])
stale_poll(); run("color-ui:retire"); assert(#overlay.children==1 and not ui.root_name)
assert(grid.Slot.Padding.Bottom==0,"Retiring the launcher restores the stock grid padding")
assert(not runtime.button_clicks.routes[retired_button:GetFullName()],"Retiring the launcher unbinds its click route")
hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"]({get=function() return retired_button end})
assert(not jobs["color-ui:launch"] and not jobs["color-ui:open"],"A click on a retired launcher does nothing")
-- No indefinite readiness work when the screen is unavailable.
page.active=false; ui.context_changed("BP_OnActivated")
for _=1,4 do run("color-ui:install") end
assert(not jobs["color-ui:install"] and not ui.binding)
page.active=true
-- No borrowing a page-level parent or touching unsupported/missing ancestry.
grid.parent=object("Overlay",page.path .. ".WidgetTree_4.PageWideOverlay")
assert(not pcall(ui.reconcile) and #overlay.children==1)
grid.parent=grid_box
-- Failed attachment still refuses preview; removal failures retain identity.
fail_construct="/Script/UMG.HorizontalBox"; assert(not pcall(ui.reconcile) and not ui.root_name)
fail_construct=nil; ui.reconcile()
grid.parent=nil; assert(not pcall(ui.prepare_picker)); grid.parent=grid_box
fail_remove=true; assert(not pcall(ui.close,"injected failure") and ui.root_name)
assert(not pcall(ui.reconcile),"Cannot install over failed cleanup")
fail_remove=false; ui.close("retry"); assert(not ui.root_name)
-- Preset/style assets may carry material colors without being color palettes.
do
    local fragment_class=object("Class","/Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
    local fragment=object("CustomizationFragmentInstanceMaterialColor",vm.path .. ".StyleColor")
    fragment.GetClass=function() return fragment_class end
    local rejected={"br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Color"}
    for _,part in ipairs({"Helmet","Torso","Arms","Legs","Boots"}) do
        rejected[#rejected+1]="br.Customization.Slot.Character.Outfit." .. part .. ".Mesh"
    end
    for _,has_fragment in ipairs({false,true}) do
        vm.GetFragments=function() return has_fragment and {fragment} or {} end
        for _,slot in ipairs(rejected) do
            tag=slot; vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
            assert(not pcall(ui.prepare_picker),"Preset/style grids must never offer Custom Color: " .. slot)
            assert(not ui.root_name and not ui.binding and #overlay.children==1 and grid.visibility==0)
        end
    end
    vm.GetFragments=function() return {} end
    for _,part in ipairs({"Helmet","Torso","Arms","Legs","Boots"}) do
        for _,zone in ipairs({"Primary","Secondary","Tertiary"}) do
            tag="br.Customization.Slot.Character.Outfit." .. part .. ".Color." .. zone
            vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
            assert(ui.reconcile().tag==tag,"Actual armor color palettes must remain available, including Default")
            ui.close("next armor palette")
        end
    end
    runtime.perf=assert(loadfile(scripts .. "/performance_log.lua"))().new(runtime)
    for _,slot in ipairs(rejected) do
        tag="br.Customization.Slot.Character.Outfit.Torso.Color.Primary"
        vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
        ui.reconcile()
        launch_click(); run("color-ui:launch")
        assert(jobs["color-ui:open"])
        assert(runtime.perf.window and runtime.perf.window.phase=="queued" and not jobs["perf:expiry"],
            "Button press must start capture before the deferred opening")
        local opens_before=opens
        tag=slot; vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
        run("color-ui:open")
        assert(not runtime.perf.window and not jobs["perf:summary"],"Rejected queued launch must end capture")
        assert(opens==opens_before,"Queued palette clicks must not open after switching to a preset/style grid")
        run("color-ui:poll")
        assert(not ui.root_name and not ui.binding and not jobs["color-ui:poll"])
        ui.context_changed("DisplayCustomizationList")
        for _=1,4 do run("color-ui:install") end
        assert(not ui.root_name and not jobs["color-ui:install"] and #overlay.children==1)
    end
    runtime.perf=nil
end
for _,slot in ipairs({"br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Sclera",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.ScleraLeft",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.ScleraRight",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintLeft",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintRight",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisInner",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisTint",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyelash.Color"}) do
    tag=slot; vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
    assert(ui.reconcile().tag==tag,"Supported eye/lash colors must get the launcher even while empty")
    ui.close("next cosmetic")
end
for _,slot in ipairs({"br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Vitiligo.Tint",
    "br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Scar.Look"}) do
    tag=slot; vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
    local binding=ui.reconcile()
    assert(not binding.manual and ui.root_name and ui.button_name and jobs["color-ui:poll"])
    assert(#overlay.children==2 and ui.validate_picker(binding),"Vitiligo/scar launchers must keep verified native ancestry")
    view.open(); assert(view.pane_binding==binding and #overlay.children==3 and ui.root_name)
    view.set_rgb({R=255,G=128,B=32}); local rgb=view.read(); assert(rgb.R==255)
    view.close(); assert(ui.binding==binding and #overlay.children==2)
    grid.parent=nil
    assert(not pcall(ui.validate_picker,binding),"Vitiligo/scar pane must reject changed native ancestry")
    grid.parent=grid_box; ui.close("next cosmetic"); assert(not ui.binding)
end
-- Raw scar HSV controls preserve native values instead of converting them to
-- sRGB, rendering an impossible hex swatch, or rounding untouched channels.
tag="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Scar.Look"
vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
view.open("hsv_shift")
assert(view.hsv_shift and not view.hsv and not view.swatch and #view.hsv_shift.channels==3)
assert(#view.buttons==2 and find(view.status).visibility==1 and find(view.status).text=="")
local adjustment={R=-4.123456789,G=20,B=-1,A=1}
local channels=view.hsv_shift.channels
local hue_slider=find(channels[1].slider)
hue_slider.GetValue=function(self) return math.floor(self.value*1e6)/1e6 end
view.set_rgb(adjustment)
local native,local_action,valid,editing=view.read(); assert(valid and native.R==adjustment.R and native.G==20 and native.B==-1 and not editing)
local brush_before=brush_writes
view.show(native,native); assert(brush_writes==brush_before,"HSV adjustments must not be sent to a UMG color swatch")
find(channels[2].input).text="27.5"; native,_,valid,editing=view.read()
assert(valid and native.R==adjustment.R and native.G==27.5 and editing)
find(channels[1].input).text="-12.3456789"; native,_,valid=view.read()
assert(valid and native.R==-12.3456789,"Exact native text input must survive slider float rounding")
find(channels[3].slider).value=-9.125; native,_,valid=view.read()
assert(valid and native.B==-9.125 and native.G==27.5)
for _,bad in ipairs({"nan","inf","181",string.rep("1",65)}) do
    find(channels[1].input).text=bad; click(view,2)
    native,local_action,valid=view.read(); assert(not valid and not local_action and native.R==-12.3456789)
    assert(find(view.status).visibility==0 and find(view.status).text:find("slider ranges",1,true))
    find(view.buttons[2].name).pressed=false; view.read()
end
find(channels[1].input).text="-12.3456789"; native,_,valid=view.read()
assert(valid and find(view.status).visibility==1 and find(view.status).text=="")
local retired_shift_slider=find(channels[2].slider)
local shift_slider=object("Slider",retired_shift_slider.path); shift_slider.value=30
retired_shift_slider.IsValid=function() error("Retired HSV adjustment wrapper touched") end
native,_,valid=view.read(); assert(native.G==30)
retired_shift_slider.IsValid=function() return false end
click(view,1)
find(channels[1].slider).GetValue=function() error("Cancel must bypass invalid HSV inputs") end
native,local_action=view.read(); assert(native==nil and local_action=="cancel")
view.close(); assert(not view.hsv_shift and not view.input_mode and ui.binding and #overlay.children==2)
ui.close("HSV test ended")
tag="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Scar.Strength"
vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
assert(not pcall(ui.prepare_picker),"Manual override must refuse unrelated scalar slots")
-- The launcher band: reserved while a launcher shows, restored on
-- retirement, but grid padding another mod changed after us is theirs. The
-- swatch cap (which creator overhauls keep re-applying) is never written.
tag="br.Customization.Slot.Character.Hair.Hair.Color.Primary"; vm.SlotTag.TagName=tag; tiles.CurrentSlotTag.TagName=tag
ui.close("band baseline"); grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
local cap_writes=0; local cap_set=grid_box.SetMaxDesiredHeight
grid_box.SetMaxDesiredHeight=function(self,v) cap_writes=cap_writes+1; cap_set(self,v) end
assert(pcall(ui.reconcile) and ui.binding and grid.Slot.Padding.Bottom==52)
ui.close("band restore"); assert(grid.Slot.Padding.Bottom==0)
assert(pcall(ui.reconcile) and grid.Slot.Padding.Bottom==52)
-- A widget that keeps resetting the padding wins after three corrections.
for i=1,4 do grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=i}); run("color-ui:poll") end
assert(grid.Slot.Padding.Bottom==4,"Back off instead of fighting a widget that keeps resetting the padding")
grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=9}); ui.close("padding changed by another mod")
assert(grid.Slot.Padding.Bottom==9,"Never overwrite grid padding another mod changed")
assert(cap_writes==0,"The swatch cap is never written")
grid_box.SetMaxDesiredHeight=cap_set; grid.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
-- If the nearest overlay is not the column's parent, the launcher stays
-- below the swatches and no band is reserved (it never covers swatches).
local inner=object("Overlay",tree .. ".InnerOverlay")
overlay.children={}; stack.parent=palette_root; palette_root.children[#palette_root.children+1]=stack
stack.children={}; grid_box.parent=nil; stack:AddChild(inner); inner:AddChild(grid_box)
assert(pcall(ui.reconcile) and ui.binding and ui.binding.overlay==inner:GetFullName() and grid.Slot.Padding.Bottom==0)
assert(find(ui.root_name).parent==stack,"No band without the column's overlay: the launcher stays below the swatches")
ui.close("no column overlay")
-- Reload cleanup targets only exact launcher roots; no stock/mimic removal.
local stale=object("UserWidget",page.path .. ".ColorsPlusLauncher_Root_90"); stack:AddChild(stale)
local other=object("OtherWidget",page.path .. ".ColorsPlusLauncher_Root_91"); stack:AddChild(other)
ui.cleanup(); assert(not stale.parent and other.parent==stack and grid.parent==grid_box)
assert(grid.visibility==0 and grid.parent==grid_box,"Native grid remains visible and owned by its original host")
assert(zone_label.visibility==0 and recolour_label.visibility==3 and slider_box.visibility==4
    and header.visibility==0 and recolour_slider.value==1)
print("Color UI: native heading factory/cleanup, aligned color controls, layered gradients, rainbow footer, exact/invalid hex, real Apply/Cancel, constant-cost redraw and scalar lifetimes passed")
