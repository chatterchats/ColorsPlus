local scripts=assert(arg[1])
local registry=assert(loadfile(scripts .. "/hook_registry.lua"))()
local module=assert(loadfile(scripts .. "/color_compatibility.lua"))()
local objects,lists,commands,jobs,logs={},{},{},{},{}
local serial,registrations,reads=0,0,0
local on_thread=false
local layout="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local vmouter="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local function obj(full,t)
    t=t or {}; t.full=full; objects[full]=t
    function t:IsValid() assert(on_thread); reads=reads+1; return not self.invalid end
    function t:GetFullName() assert(on_thread); return self.full end
    return t
end
local function asset(s) return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=s} end
local class=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local partclass=obj("Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local part=obj("BitReactorCustomizationPartViewModel " .. vmouter .. "BitReactorCustomizationPartViewModel_1",{
    AssetId=asset("CPD_Test_Red"),DisplayName="Red",GetClass=function() return partclass end})
local donor=obj("BitReactorCustomizationPartViewModel " .. vmouter .. "BitReactorCustomizationPartViewModel_2",{
    AssetId=asset("CPD_Test_Blue"),DisplayName="Blue",GetClass=function() return partclass end})
local vm=obj("BitReactorCustomizationSlotViewModel " .. vmouter .. "BitReactorCustomizationSlotViewModel_3",{
    SlotTag={TagName="br.Customization.Slot.Character.Outfit.Torso.Color.Primary"},DisplayName="Main Color",
    EquippedCustomizationPartViewModel=part})
local mesh_tag={TagName="br.Customization.Slot.Character.Outfit.Torso.Mesh"}
local slot=obj("CustomizationFragmentInstanceSlot /Game/Test.SourceSlot",{
    GetSlotNameTag=function() return vm.SlotTag end,GetCustomizationPartPrimaryAssetId=function() return part.AssetId end})
local mesh=obj("CustomizationFragmentInstanceSlot /Game/Test.MeshSlot",{
    GetSlotNameTag=function() return mesh_tag end,GetCustomizationPartPrimaryAssetId=function() return asset("CPD_OtherArmor") end})
local owner=obj("CustomizationInstance /Game/Test.Owner",{GetSlotInstance=function(_,tag)
    return tag.TagName==vm.SlotTag.TagName and slot or mesh end})
local color={R=.1,G=.2,B=.3,A=1}
local fragment=obj("CustomizationFragmentInstanceMaterialColor /Game/Test.Color",{
    GetClass=function() return class end,GetOwningCustomizationInstance=function() return owner end,
    GetOwningCustomizationSlot=function() return slot end,GetColor=function() return color end,
    MaterialTarget={MaterialParameterName="Color 01",MaterialSlotNames={"MI_TORS"},SlotNameTagsToApply={GameplayTags={mesh_tag}}}})
local fragments={fragment}
function vm:GetFragments() return fragments end
local page=obj("WBP_Customization_ItemPage_C " .. layout .. ".WBP_Customization_ItemPage_C_1",{IsActivated=function() return true end})
local master=obj("WBP_CustomCharacter_Master_C " .. layout .. ".WBP_CustomCharacter_Master_C_2")
local parent=obj("CanvasPanel " .. layout .. ".MainOverlay")
local stack=obj("BitReactorActivatableWidgetStack " .. layout .. ".GameLayer_Stack",{
    WidgetList={master,page},GetActiveWidget=function() return page end,GetParent=function() return parent end})
local palette={part,donor}
local grid=obj("BitReactorTileView /Game/Test.Grid",{GetNumItems=function() return #palette end,
    GetItemAt=function(_,i) return palette[i+1] end,
    GetIndexForItem=function(_,item) for i,v in ipairs(palette) do if item==v then return i-1 end end end})
local tiles=obj("WBP_Customization_SelectionTiles_C /Game/Test.Tiles",{
    IsVisible=function() return true end,CurrentSlotTag=vm.SlotTag,PartsGridList=grid})
local aux=obj("CustomizationAuxVM_C /Game/Test.Aux",{CurrentCustomizationSlotVM=vm})
lists.WBP_Customization_ItemPage_C={page}; lists.CustomizationAuxVM_C={aux}; lists.WBP_Customization_SelectionTiles_C={tiles}
-- The active page owns exactly one attached palette for the selected slot.
tiles.GetParent=function() return page end
local active_children={tiles}
local active_list=obj("BitReactorStackBox /Game/Test.ActiveList",{
    IsVisible=function() return true end,GetAllChildren=function() return active_children end})
local active_panel=obj("WBP_CustomizationSlotPanelCombined_C /Game/Test.ActivePanel",{
    IsVisible=function() return true end,CustomizationSlots=active_list})
page.WBP_CustomizationSlotPanelCombined=active_panel
page.SlotWidgetSwitcher=obj("CommonActivatableWidgetSwitcher /Game/Test.Switcher",{GetActiveWidget=function() return active_panel end})
function FindAllOf(c) assert(on_thread); return lists[c] end
function StaticFindObject(path)
    assert(on_thread); for n,o in pairs(objects) do if n:match("^[^ ]+ (.+)$")==path then return o end end
end
function RegisterConsoleCommandHandler(n,cb) assert(not commands[n]); registrations=registrations+1; commands[n]=cb end
function MakeActionHandle() serial=serial+1; return serial end
function ExecuteInGameThreadWithDelay(h,ms,cb) assert(ms==1); jobs[h]=cb end
function CancelDelayedAction() end -- cancelled callbacks can still arrive
local a={unwrap=function(v) return v end,live=function(o) return o and o:IsValid() end,
    name=function(o) return o:GetFullName() end,text=function(v) return v==nil and "<unavailable>" or tostring(v) end,
    prop=function(v,k) return v and v[k] end,values=function(v) assert(type(v)=="table"); return v end}
local function boot()
    local r=registry.start("CompatibilityTestRuntime"); r.log=function(s) logs[#logs+1]=s end
    local compat=module.new(r,a); compat.attach(); return r
end
local output={Log=function() assert(not on_thread,"No retained OutputDevice") end}
local function run()
    local pending=jobs; jobs={}; on_thread=true
    for _,cb in pairs(pending) do cb() end
    on_thread=false
end
local function command(args) commands.colors_compat("colors_compat",args or {},output) end
local function has(s) return table.concat(logs,"\n"):find(s,1,true) end
local r=boot(); assert(reads==0 and not next(jobs),"no startup UObject work")
command({"extra"}); assert(not next(jobs))
command(); assert(reads==0); run()
assert(has("RESULT | CANDIDATE") and has("parameter=Color 01") and has("equipped_part=CustomizationPartDefinition:CPD_OtherArmor"))
-- Generalize discovery without changing gameplay on other zones or asset families.
logs={}; vm.SlotTag.TagName="br.Customization.Slot.Character.Appearance.Hair.Color.Root"
mesh_tag.TagName="br.Customization.Slot.Character.Appearance.Hair.Mesh"
fragment.MaterialTarget.MaterialParameterName="Root Color"; fragment.MaterialTarget.MaterialSlotNames={"MI_Hair"}
part.AssetId=asset("CPD_Hair_Red"); donor.AssetId=asset("CPD_Hair_Blue")
command(); run(); assert(has("RESULT | CANDIDATE") and has("parameter=Root Color"))
logs={}; fragments={}; command(); run(); assert(has("EMPTY/DEFAULT"))
logs={}; fragments={fragment,fragment}; command(); run(); assert(has("RESULT | UNVERIFIED"))
logs={}; fragments={fragment}; color.A=0; command(); run(); assert(has("normalized_opaque=false") and has("RESULT | UNVERIFIED")); color.A=1
logs={}; palette={donor}; command(); run(); assert(has("PALETTE GAP") and has("RESULT | UNVERIFIED")); palette={part,donor}
logs={}; r.tint={applied={}}; local before=reads; command(); run(); assert(reads==before and has("REFUSED")); r.tint=nil
logs={}; lists.CustomizationAuxVM_C={aux,aux}; command(); run(); assert(has("FAILED |") and has("Ambiguous selected slot"))
lists.CustomizationAuxVM_C={aux}
logs={}; stack.WidgetList={page}; command(); run(); assert(has("Creator removed from game stack")); stack.WidgetList={master,page}
logs={}; fragments={}; for i=1,17 do fragments[i]=fragment end
command(); run(); assert(has("Fragment detail limit exceeded")); fragments={fragment}
logs={}; local original_count=grid.GetNumItems; grid.GetNumItems=function() return 1025 end
command(); run(); assert(has("Invalid palette size") and has("RESULT | UNVERIFIED")); grid.GetNumItems=original_count
logs={}; lists.CustomizationAuxVM_C={}; for i=1,129 do lists.CustomizationAuxVM_C[i]=aux end
command(); run(); assert(has("Scan limit: CustomizationAuxVM_C")); lists.CustomizationAuxVM_C={aux}
-- Same-state reload retires queued work, reuses the command, and doesn't retain objects.
-- Bounded nested eye-slot diagnostics never treat a container as a color.
local slotclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceSlot")
local children={fragment}
local nested_slot=obj("CustomizationFragmentInstanceSlot /Game/Test.Eyes",{
    GetClass=function() return slotclass end,GetOwningCustomizationInstance=function() return owner end,
    GetSlotNameTag=function() return {TagName="br.Customization.Slot.Character.Eyes.Iris"} end,
    GetCustomizationPartPrimaryAssetId=function() return asset("CPD_Iris") end,
    GetSlotVisibleInUI=function() return false end,GetFragmentInstances=function() return children end})
fragments={nested_slot}; logs={}; command(); run()
assert(has("NESTED SLOT | tag=br.Customization.Slot.Character.Eyes.Iris") and has("visible_in_ui=false") and has("NESTED COLOR"))
local swapclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialSwap")
local materialclass=obj("Class /Script/Engine.MaterialInstanceConstant")
local eye_material=obj("MaterialInstanceConstant /Game/Test.EyeMaterial",{GetClass=function() return materialclass end})
local swap=obj("CustomizationFragmentInstanceMaterialSwap /Game/Test.EyeSwap",{
    GetClass=function() return swapclass end,GetOwningCustomizationInstance=function() return owner end,
    MaterialTarget=fragment.MaterialTarget,ReplacementMaterial=eye_material})
children={swap}; logs={}; command(); run()
assert(has("NESTED SWAP | material=MaterialInstanceConstant /Game/Test.EyeMaterial") and has("RESULT | UNVERIFIED"))
children={nested_slot}; logs={}; command(); run(); assert(has("Nested slot cycle/alias"))
children={fragment}; fragments={fragment}
-- Active-page palette ownership resolves a stale visible palette, while truly
-- ambiguous attached palettes still refuse. Donors exclude Default/current.
local second=obj("WBP_Customization_SelectionTiles_C /Game/Test.Second",{
    IsVisible=function() return true end,CurrentSlotTag=vm.SlotTag,PartsGridList=obj("BitReactorTileView /Game/Test.Stale")})
lists.WBP_Customization_SelectionTiles_C={second,tiles}
logs={}; command(); run(); assert(has("RESULT | CANDIDATE") and has("active-page discovery"))
second.GetParent=function() return page end
active_children={tiles,second}
logs={}; command(); run(); assert(has("FAILED |") and has("active panel; found 2"))
active_children={tiles}
lists.WBP_Customization_SelectionTiles_C={tiles}
local target_module=assert(loadfile(scripts .. "/color_target.lua"))()
local targets=target_module.new(a)
on_thread=true
local profile=targets.read(fragment,vm.SlotTag.TagName,owner)
assert(target_module.valid(profile) and targets.target(fragment,profile)=="MI_Hair")
assert(targets.donor(vm,page.full)==donor)
donor.AssetId=asset("CPD_Hair_None")
assert(not pcall(targets.donor,vm,page.full)); donor.AssetId=asset("CPD_Hair_Blue")
palette={donor}; assert(not pcall(targets.palette,vm,page.full)); palette={part,donor}
local original_parameter=profile.parameter; profile.parameter="wrong"
assert(not pcall(targets.target,fragment,profile)); profile.parameter=original_parameter
fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag,mesh_tag}
assert(not pcall(targets.read,fragment,vm.SlotTag.TagName,owner))
fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag}
on_thread=false
-- A displayed simple color palette can disagree with Aux's stale Style VM.
local saved_slot_tag,saved_mesh_tag=vm.SlotTag.TagName,mesh_tag.TagName
local style=obj("BitReactorCustomizationSlotViewModel " .. vmouter .. "BitReactorCustomizationSlotViewModel_40",{
    SlotTag={TagName="br.Customization.Slot.Character.Hair.Hair.Mesh"},CustomizationChildSlotViewModels={vm},
    GetFragments=function() error("Never inspect parent Style as color") end})
local root=obj("BitReactorCustomizationSlotViewModel " .. vmouter .. "BitReactorCustomizationSlotViewModel_41",{
    SlotTag={TagName="br.Customization.Slot.Character.Hair"},CustomizationChildSlotViewModels={style,vm}})
local simple=obj("WBP_CustomizationSlotPanel_C /Game/Test.Simple",{
    IsVisible=function() return true end,WBP_Customization_SelectionTiles=tiles})
page.WBP_CustomizationSlotPanel=simple
local saved_switcher=page.SlotWidgetSwitcher.GetActiveWidget
page.SlotWidgetSwitcher.GetActiveWidget=function() return simple end
vm.CustomizationChildSlotViewModels={}
aux.CurrentCustomizationSlotVM=style; aux.RootCustomizationSlotVM=root
for _,case in ipairs({
    {"br.Customization.Slot.Character.Hair.Hair.Color.Primary","br.Customization.Slot.Character.Hair.Hair.Mesh","Root Color"},
    {"br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Lipstick.Color","br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh","Lipstick Color"},
}) do
    vm.SlotTag.TagName=case[1]; mesh_tag.TagName=case[2]; fragment.MaterialTarget.MaterialParameterName=case[3]
    logs={}; command(); run()
    assert(has("RESOLVED DISPLAYED") and has("tag=" .. case[1]) and has("parameter=" .. case[3]) and has("RESULT | CANDIDATE"),table.concat(logs,"\n"))
end
-- Duplicate targets and mixed fragments still cannot become picker candidates.
fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag,mesh_tag}
logs={}; command(); run(); assert(has("RESULT | UNVERIFIED"))
fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag}
fragments={fragment,fragment}; logs={}; command(); run(); assert(has("RESULT | UNVERIFIED")); fragments={fragment}
do
    local saved_get=owner.GetSlotInstance
    local horns="br.Customization.Slot.Character.Horns.Mesh"
    vm.SlotTag.TagName="br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color"
    mesh_tag.TagName="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
    owner.GetSlotInstance=function(self,t) if t.TagName~=horns then return saved_get(self,t) end end
    fragment.MaterialTarget.MaterialParameterName="Tattoo Color"
    fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag,{TagName=horns}}
    logs={}; command(); run()
    assert(has("RESULT | CANDIDATE") and has("tag=" .. horns .. " | state=absent"),table.concat(logs,"\n"))
    vm.SlotTag.TagName="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
    fragment.MaterialTarget.MaterialParameterName="Skin Coloration"
    local tagsclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceGameplayTags")
    local scalarclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialScalar")
    local tags=obj("CustomizationFragmentInstanceGameplayTags /Game/Test.Tags",{
        GetClass=function() return tagsclass end,GetOwningCustomizationInstance=fragment.GetOwningCustomizationInstance,
        GetOwningCustomizationSlot=fragment.GetOwningCustomizationSlot,
        GameplayTags={GameplayTags={{TagName="br.Test.Skin"}}}})
    local scalarfrag=obj("CustomizationFragmentInstanceMaterialScalar /Game/Test.Scalar",{
        GetClass=function() return scalarclass end,GetOwningCustomizationInstance=fragment.GetOwningCustomizationInstance,
        GetOwningCustomizationSlot=fragment.GetOwningCustomizationSlot,Value=.42,
        MaterialTarget={MaterialParameterName="Skin Detail",MaterialSlotNames={"MI_Head"},SlotNameTagsToApply={GameplayTags={mesh_tag}}}})
    fragments={tags,fragment,scalarfrag}; logs={}; command(); run()
    assert(has("GAMEPLAY TAG | index=1 | tag=br.Test.Skin") and has("SCALAR | index=3 | value=0.42")
        and has("parameter=Skin Detail") and has("RESULT | UNVERIFIED"),table.concat(logs,"\n"))
    scalarfrag.Value=0/0; logs={}; command(); run(); assert(has("Unreadable material scalar"))
    tags.GameplayTags=nil; logs={}; command(); run(); assert(has("Unreadable gameplay tags"))
    fragments={fragment}; owner.GetSlotInstance=saved_get
    fragment.MaterialTarget.MaterialParameterName="Root Color"
    fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={mesh_tag}
end
aux.CurrentCustomizationSlotVM=vm; aux.RootCustomizationSlotVM=nil
page.SlotWidgetSwitcher.GetActiveWidget=saved_switcher
vm.SlotTag.TagName=saved_slot_tag; mesh_tag.TagName=saved_mesh_tag
command(); before=reads; r=boot(); run(); assert(reads==before and registrations==1)
command(); run(); assert(reads>before)
command(); r:teardown(); before=reads; run(); assert(reads==before)
assert(color.R==.1 and color.G==.2 and color.B==.3 and vm.EquippedCustomizationPartViewModel==part)
print("Color compatibility: dynamic targets/palettes, no writes, unsupported/default contexts, bounds and reload passed")
