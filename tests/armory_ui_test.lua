-- Run: tools/run-tests.sh armory_ui
local scripts=assert(arg[1])
local factory=assert(loadfile(scripts .. "/armory_ui.lua"))()
local objects,lists,logs,jobs,hooks,scans={},{},{},{},{},{}
local function register(o) objects[o.full:match("^[^ ]+ (.+)$")]=o; local c=o.full:match("^([^ ]+) "); lists[c]=lists[c] or {}; table.insert(lists[c],o); return o end
local function widget(class,path,fields)
    local o=fields or {}; o.full=class .. " " .. path; o.visibility=o.visibility or 0; o.children=o.children or {}
    function o:IsValid() return not self.dead end
    function o:GetFullName() return self.full end
    function o:GetParent() return self.parent end
    function o:IsVisible() return self.visibility~=1 and self.visibility~=2 end
    function o:GetVisibility() return self.visibility end
    function o:SetVisibility(v) self.visibility=v end
    function o:RemoveFromParent() if self.parent then for i,c in ipairs(self.parent.children) do if c==self then table.remove(self.parent.children,i) end end end; self.parent=nil end
    function o:AddChild(child)
        child.parent=self; table.insert(self.children,child)
        return {SetPadding=function() end,SetVerticalAlignment=function() end,SetHorizontalAlignment=function() end,SetSize=function() end}
    end
    function o:SetHeightOverride() end; function o:SetWidthOverride() end
    function o:SetBrushFromTexture() end; function o:SetColorAndOpacity() end
    return register(o)
end
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v[k] end,text=tostring,values=function(v) return v end}
function StaticFindObject(path)
    if path:match("^/Script/") then
        if path=="/Script/UMG.Default__WidgetBlueprintLibrary" or path=="/Script/Engine.Default__KismetRenderingLibrary" then return objects[path] end
        return {IsValid=function() return true end,GetFullName=function() return "Class " .. path end,short=path:match("%.(%w+)$")}
    end
    return objects[path]
end
function FindAllOf(class) scans[#scans+1]=class; return lists[class] end
function FName(s) return s end
function FText(s) return s end
local serial=0
function StaticConstructObject(class,outer,fname)
    serial=serial+1
    local short=class.short or "Widget"
    return widget(short,outer.full:match("^[^ ]+ (.+)$") .. "." .. tostring(fname))
end
-- Libraries: widget creation (the Custom Color button) and texture import.
objects["/Script/UMG.Default__WidgetBlueprintLibrary"]={IsValid=function() return true end,
    Create=function(_,pc,class,owner)
        local b=widget("WBP_CharacterDataBank_TopNavButton_C","/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.Button_" .. (serial+1))
        function b:SetIsFocusable() end; function b:SetIsSelectable() end; function b:SetIsToggleable() end
        function b:UpdateText(t) self.caption=t end
        return b
    end}
objects["/Script/Engine.Default__KismetRenderingLibrary"]={IsValid=function() return true end,
    ImportFileAsTexture2D=function() return {IsValid=function() return true end} end}
objects["/Game/Game/UI/Strategy/Customization/Widgets/CharacterDatabank/WBP_CharacterDataBank_TopNavButton.WBP_CharacterDataBank_TopNavButton_C"]={IsValid=function() return true end,GetFullName=function() return "WidgetBlueprintGeneratedClass X" end}
package.loaded.UEHelpers={GetPlayerController=function() return widget("BP_BrunoPlayerController_C","/Game/Maps/Hub.Hub:PersistentLevel.PC_0") end}
-- The armory screen, its COLOR section and the Paint Color row widget.
local L="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_1.WidgetTree_2.WBP_CentralUITabs_C_3.WidgetTree_4.WBP_TabbedMenu_Armory_C_5.WidgetTree_6"
local screen=widget("WBP_Menu_Armory_CustomizeWeapon_C",L .. ".WBP_Menu_Armory_CustomizeWeapon_C_7",{active=true})
function screen:IsActivated() return self.active end
local S=L .. ".WBP_Menu_Armory_CustomizeWeapon_C_7.WidgetTree_8"
local section=widget("WBP_CustomizationSection_Tiles_C",S .. ".WBP_CustomizationSection_Tiles_C_9")
local entries={}
section.TileEntries=widget("MDVMDynamicEntryBox",S .. ".WBP_CustomizationSection_Tiles_C_9.WidgetTree_10.TileEntries")
function section.TileEntries:GetAllEntries() return entries end
local function row_widget(n)
    local E=S .. ".WBP_CustomizationSection_Tiles_C_9.WidgetTree_10.WBP_Customization_PartTiles_C_" .. n
    local entry=widget("WBP_Customization_PartTiles_C",E)
    local overlay=widget("Overlay",E .. ".WidgetTree_11.Overlay_0")
    local column=widget("VerticalBox",E .. ".WidgetTree_11.VerticalBox_0"); column.parent=overlay
    local size=widget("SizeBox",E .. ".WidgetTree_11.SizeBox_0"); size.parent=column
    local grid=widget("BitReactorTileView",E .. ".WidgetTree_11.PartsGrid"); grid.parent=size
    grid.items={}
    function grid:GetIndexForItem(item) for i,v in ipairs(self.items) do if v==item then return i-1 end end; return -1 end
    overlay.parent=entry -- the row widget itself (outside its tree)
    entry.PartsGrid=grid
    return entry,grid,column,overlay
end
local white={}
local paint_row=register({full="BitReactorCustomizationSlotViewModel /Engine/Transient.X.VM_644",IsValid=function() return true end,GetFullName=function(self) return self.full end,
    EquippedCustomizationPartViewModel=white,GetFragments=function() return {{IsValid=function() return true end,GetFullName=function() return "CustomizationFragmentInstanceMaterialColor @Rifle.Frag" end}} end})
local bolt_row=register({full="BitReactorCustomizationSlotViewModel /Engine/Transient.X.VM_637",IsValid=function() return true end,GetFullName=function(self) return self.full end,
    EquippedCustomizationPartViewModel=white})
local vm=register({full="VM_WeaponCustomization_C /Engine/Transient.X.VM_WeaponCustomization_C_0",IsValid=function() return true end,GetFullName=function(self) return self.full end,
    ColorSlotVMs={paint_row,bolt_row}})
local paint_entry,paint_grid,paint_column,paint_overlay=row_widget(12)
local bolt_entry,bolt_grid=row_widget(13)
-- Both grids hold the shared White swatch: entry order picks the paint row.
paint_grid.items={white}; bolt_grid.items={white}
entries={paint_entry,bolt_entry}
-- Runtime fakes.
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,cb) jobs[k]=cb end
function runtime:cancel(k) jobs[k]=nil end
function runtime:hook(path,cb) hooks[path]=cb; return true end
local opened=0
runtime.picker={active=false,open=function() opened=opened+1; runtime.picker.active=true; return true end,
    close=function(reason) runtime.picker.active=false; runtime.picker.closed=reason end}
runtime.armory_paint={TAG="br.Customization.Slot.Weapon.PaintColor",qualifies=function(row) return row==paint_row end}
local function run(k) local cb=assert(jobs[k],k); jobs[k]=nil; cb() end
local function has(s) for _,l in ipairs(logs) do if l:find(s,1,true) then return true end end end
local ui=factory.new(runtime,a)
runtime.armory_ui=ui

-- Outside the armory: slot events never look for armory widgets.
local before=#scans
ui.context_changed("EquipCustomizationPart")
assert(not jobs["armory-ui:install"] and #scans==before,"No discovery outside Customize Weapon")
-- The screen activates: discover, attach under the paint row's swatches.
ui.context_changed("armory activated",screen.full)
run("armory-ui:install")
assert(ui.binding and ui.binding.row==paint_row.full and ui.binding.entry==paint_entry.full,"Entry order resolves the shared swatch")
assert(ui.binding.overlay==paint_overlay.full and ui.binding.stack==paint_column.full)
assert(ui.root_name and objects[ui.root_name:match("^[^ ]+ (.+)$")].parent==paint_column,"Launcher sits in the row's column")
assert(has("FOUND | row=") and has("ATTACHED | row="))
assert(ui.bound_row()==paint_row.full)
-- A click launches the picker on the armory backend and host.
local click=assert(hooks["/Script/CommonUI.CommonButtonBase:HandleButtonClicked"])
local button=objects[ui.button_name:match("^[^ ]+ (.+)$")]
click({get=function() return button end})
run("armory-ui:launch"); run("armory-ui:open")
assert(opened==1 and runtime.color_host==ui and runtime.color_backend==runtime.armory_paint)
-- Host calls: prepare, hide (grid and launcher collapsed), release restores.
local b=ui.prepare_picker()
assert(b==ui.binding and ui.validate_picker(b))
ui.hide_palette(b,"UserWidget picker")
assert(paint_grid.visibility==1 and objects[ui.root_name:match("^[^ ]+ (.+)$")].visibility==1 and ui.picker_owner)
ui.context_changed("armory section",screen.full)
assert(not jobs["armory-ui:install"],"Never rebind under an open picker")
ui.release_picker(b)
assert(paint_grid.visibility==0 and objects[ui.root_name:match("^[^ ]+ (.+)$")].visibility==4 and not ui.picker_owner)
assert(runtime.color_host==nil and runtime.color_backend==nil)
-- The poll retires the launcher when the row is no longer the paint row.
runtime.picker.active=false
paint_grid.dead=true
run("armory-ui:poll")
assert(not ui.binding and has("RETIRED |"),"A replaced grid retires the launcher")
paint_grid.dead=nil
-- Leaving the screen closes an armory picker and forgets the screen.
ui.context_changed("armory activated",screen.full); run("armory-ui:install")
assert(ui.binding)
runtime.picker.active=true; ui.picker_owner="UserWidget picker"
ui.context_changed("armory deactivated")
assert(runtime.picker.closed=="armory closed" and not ui.binding and not ui.root_name)
before=#scans; ui.context_changed("ResetPreviewedPart")
assert(not jobs["armory-ui:install"] and #scans==before,"Forgotten screen: quiet again")
-- No paint row (a saber, or ZCUnlocked rows only): never attaches.
runtime.picker.active=false; ui.picker_owner=nil
runtime.armory_paint.qualifies=function() return false end
ui.context_changed("armory activated",screen.full)
for _=1,3 do run("armory-ui:install") end
assert(not ui.binding and has("NOT ATTACHED |") and has("No vanilla Paint Color row"))
print("Armory UI: quiet outside the armory, row discovery and placement, launch on the armory backend, host hide/release, retire and leave")
