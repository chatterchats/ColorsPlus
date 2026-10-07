-- Run: tools/run-tests.sh armory_paint
local scripts=assert(arg[1])
local factory=assert(loadfile(scripts .. "/armory_paint.lua"))()
local objects,lists,logs={},{},{}
local function obj(full,fields)
    local o=fields or {}; o.full=full
    function o:IsValid() return not self.dead end
    function o:GetFullName() return self.full end
    objects[full:match("^[^ ]+ (.+)$")]=o
    return o
end
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v[k] end,text=tostring,values=function(v) return v end}
function StaticFindObject(path) return objects[path] end
function FindAllOf(class) return lists[class] end
function FName(s) return s end
local TAG="br.Customization.Slot.Weapon.PaintColor"
local HUB="/Game/Game/Maps/Hub/HUB_Root.HUB_Root:PersistentLevel."
local ARM="/Game/Game/Maps/Hub/Sublevels/Facilities/HUB_Armory_Gameplay.HUB_Armory_Gameplay:PersistentLevel."
local colorclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local function id(n) return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=n} end
local refreshes={real=0,preview=0}
local function fragment(full,owner,slot,rgba)
    local f=obj(full,{color={R=rgba[1],G=rgba[2],B=rgba[3],A=rgba[4]},
        MaterialTarget={MaterialParameterName="Paint Color"}})
    function f:GetClass() return colorclass end
    function f:GetColor() local c=self.color; return {R=c.R,G=c.G,B=c.B,A=c.A} end
    function f:SetColor(c) self.color={R=c.R,G=c.G,B=c.B,A=c.A} end
    function f:GetOwningCustomizationInstance() return owner end
    function f:GetOwningCustomizationSlot() return slot end
    return f
end
-- The real rifle: customization instance, paint slot, fragment, colour row.
local real_ci=obj("CustomizationInstance " .. HUB .. "BP_Rifle_Relby-v10_C_3.CustomizationInstance",
    {RefreshCustomization=function() refreshes.real=refreshes.real+1 end})
local real_slot=obj("CustomizationFragmentInstanceSlot " .. HUB .. "BP_Rifle_Relby-v10_C_3.CustomizationInstance.Slot_26",
    {GetSlotNameTag=function() return {TagName=TAG} end,GetCustomizationPartPrimaryAssetId=function() return id("CPD_Wep_PaintColor_White") end})
local real=fragment("CustomizationFragmentInstanceMaterialColor " .. HUB .. "BP_Rifle_Relby-v10_C_3.CustomizationInstance.Slot_26.Color_0",real_ci,real_slot,{.71,.72,.70,1})
local row=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.VM_644",
    {DisplayName="Paint Color",SlotTag={TagName=TAG},GetFragments=function() return {real} end})
-- The armory preview copy.
local preview_ci=obj("CustomizationInstance " .. ARM .. "BP_ArmoryWeaponRender_C_0.CustomizationInstance",
    {RefreshCustomization=function() refreshes.preview=refreshes.preview+1 end})
local preview_part="CPD_Wep_PaintColor_White"
local preview_slot=obj("CustomizationFragmentInstanceSlot " .. ARM .. "BP_ArmoryWeaponRender_C_0.CustomizationInstance.Slot_3",
    {GetCustomizationPartPrimaryAssetId=function() return id(preview_part) end})
local preview=fragment("CustomizationFragmentInstanceMaterialColor " .. ARM .. "BP_ArmoryWeaponRender_C_0.CustomizationInstance.Slot_3.Color_0",preview_ci,preview_slot,{.71,.72,.70,1})
local preview_list={preview}
function preview_slot:GetFragmentInstances() return preview_list end
function preview_ci:GetSlotInstance(t) assert(t.TagName==TAG); return preview_slot end
local render=obj("BP_ArmoryWeaponRender_C " .. ARM .. "BP_ArmoryWeaponRender_C_0",{isShowingWeapon=true,CustomizationInstance=preview_ci})
lists.BP_ArmoryWeaponRender_C={render}
local runtime={log=function(s) logs[#logs+1]=s end}
local bound=row.full
runtime.armory_ui={bound_row=function() return bound end}
local paint=factory.new(runtime,a)
runtime.armory_paint=paint
local function has(s) for _,l in ipairs(logs) do if l:find(s,1,true) then return true end end end
local function near(c,r,g,b,al) return math.abs(c.R-r)<1e-6 and math.abs(c.G-g)<1e-6 and math.abs(c.B-b)<1e-6 and math.abs(c.A-al)<1e-6 end

-- Only the vanilla Paint Color row of a hub blaster qualifies.
assert(paint.qualifies(row))
local bolt=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.X.VM_637",{DisplayName="Bolt Color",SlotTag={TagName=TAG},GetFragments=function() return {real} end})
assert(not paint.qualifies(bolt),"ZCUnlocked rows are left alone")
local saber_ci=obj("CustomizationInstance " .. HUB .. "BP_LightSaber_Tel_Padawan_C_2.CustomizationInstance")
local saber_frag=fragment("CustomizationFragmentInstanceMaterialColor " .. HUB .. "BP_LightSaber_Tel_Padawan_C_2.CustomizationInstance.Slot_0.Color_0",saber_ci,real_slot,{1,1,1,1})
local saber=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.X.VM_652",{DisplayName="Paint Color",SlotTag={TagName=TAG},GetFragments=function() return {saber_frag} end})
assert(not paint.qualifies(saber),"Lightsabers are left alone")
local preview_row=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.X.VM_9",{DisplayName="Paint Color",SlotTag={TagName=TAG},GetFragments=function() return {preview} end})
assert(not paint.qualifies(preview_row),"The preview copy is not a weapon")

-- Context and a draft: only the preview is written.
local c=paint.read_context()
assert(near(c.original,.71,.72,.70,1) and c.profile.slot==TAG and c.profile.parameter=="Paint Color")
local s=assert(paint.begin_live())
assert(paint.pending==s and s.preview_policy=="armor" and s.perf_target.backend=="armory-paint")
assert(paint.update_live(s,{R=1,G=0,B=0,A=1}))
assert(near(preview.color,1,0,0,1) and near(real.color,.71,.72,.70,1) and refreshes.preview==1 and refreshes.real==0)
assert(paint.check_live(s))
assert(not paint.begin_live(),"One draft at a time")
-- Cancel puts the preview back and never touched the weapon.
assert(paint.cancel_live("Cancel"))
assert(near(preview.color,.71,.72,.70,1) and near(real.color,.71,.72,.70,1) and not paint.pending and has("CANCELLED | Cancel | preview restored"))

-- Apply writes the real weapon, keeps alpha, and the preview shows it too.
real.color.A=.5
s=assert(paint.begin_live())
assert(paint.update_live(s,{R=0,G=1,B=0,A=1}))
assert(paint.apply_live(s))
assert(near(real.color,0,1,0,.5) and near(preview.color,0,1,0,.5) and refreshes.real==1 and not paint.pending and has("APPLIED | weapon="))

-- The weapon changed under the draft (a swatch pick): Apply refuses.
s=assert(paint.begin_live()); assert(paint.update_live(s,{R=0,G=0,B=1,A=1}))
real.color={R=.2,G=.2,B=.2,A=1}
assert(not paint.apply_live(s) and has("APPLY FAILED | ") and near(real.color,.2,.2,.2,1))
assert(paint.cancel_live("cleanup"))

-- The game rebuilt the preview: health fails, Cancel leaves it to the game.
s=assert(paint.begin_live())
local rebuilt=fragment("CustomizationFragmentInstanceMaterialColor " .. ARM .. "BP_ArmoryWeaponRender_C_0.CustomizationInstance.Slot_3.Color_9",preview_ci,preview_slot,{.2,.2,.2,1})
preview_list={rebuilt}
local healthy,why=paint.check_live(s)
assert(not healthy and tostring(why):find("rebuilt",1,true))
assert(not paint.update_live(s,{R=1,G=1,B=1,A=1}) and near(rebuilt.color,.2,.2,.2,1))
assert(paint.cancel_live("rebuilt") and has("preview left to the game"))
preview_list={preview}

-- Refusals at opening: a preview of another swatch, two previews, no row.
preview_part="CPD_Wep_PaintColor_Red"; assert(not paint.begin_live() and has("different paint swatch")); preview_part="CPD_Wep_PaintColor_White"
lists.BP_ArmoryWeaponRender_C={render,obj("BP_ArmoryWeaponRender_C " .. ARM .. "BP_ArmoryWeaponRender_C_1",{isShowingWeapon=true,CustomizationInstance=preview_ci})}
assert(not paint.begin_live() and has("Expected one armory preview")); lists.BP_ArmoryWeaponRender_C={render}
bound=nil; assert(not paint.begin_live() and has("No armory paint row bound")); bound=row.full
row.DisplayName="Bolt Color"; assert(not paint.begin_live() and has("no longer the vanilla Paint Color row")); row.DisplayName="Paint Color"
assert(paint.begin_live() and paint.cancel_live("done"))
print("Armory paint: vanilla row only, preview-only drafts, Apply to the weapon (alpha kept), Cancel restores, refusals on change")
