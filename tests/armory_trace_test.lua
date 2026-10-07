-- Run: tools/run-tests.sh armory_trace
local scripts=assert(arg[1])
local factory=assert(loadfile(scripts .. "/armory_trace.lua"))()
local logs,jobs,hooks,commands,lists={},{},{},{},{}
local function obj(full,fields)
    local o=fields or {}; o.full=full
    function o:IsValid() return not self.dead end
    function o:GetFullName() return self.full end
    return o
end
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v[k] end,text=tostring,values=function(v) return v end}
function FName(s) return s end
function FindAllOf(class) return lists[class] end
function RegisterConsoleCommandHandler() end
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,cb) jobs[k]=cb end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(n,cb) commands[n]=cb end
local fail_path
function runtime:hook(path,cb) if path==fail_path then return false end; hooks[path]=cb; return true end
local previous_reasons={}
runtime.dev_context={before=function(r) previous_reasons[#previous_reasons+1]=r end}
local function has(s) for _,l in ipairs(logs) do if l:find(s,1,true) then return true end end end
local function run(k) local cb=assert(jobs[k],k); jobs[k]=nil; cb() end
-- World: one weapon VM with a paint row, a preview render and the screen.
local fragment=obj("CustomizationFragmentInstanceMaterialColor @Rifle.CI.Frag_1",{GetColor=function() return {R=.5,G=.25,B=.125,A=1} end})
local row=obj("BitReactorCustomizationSlotViewModel VM_644",{DisplayName="Paint Color",
    EquippedCustomizationPartViewModel={AssetId={PrimaryAssetName="CPD_Wep_PaintColor_White"}},
    GetFragments=function() return {fragment} end,
    PreviewedCustomizationPartViewModel=function() return {AssetId={PrimaryAssetName="CPD_Wep_PaintColor_Red"}} end})
lists.VM_WeaponCustomization_C={obj("VM_WeaponCustomization_C VM_0",{ColorSlotVMs={row}})}
local preview_fragment=obj("CustomizationFragmentInstanceMaterialColor @Render.CI.Frag_9",{GetColor=function() return {R=1,G=0,B=0,A=1} end})
local preview_slot=obj("CustomizationFragmentInstanceSlot @Render.CI.Slot",{GetFragmentInstances=function() return {preview_fragment} end})
local ci=obj("CustomizationInstance @Render.CI",{GetSlotInstance=function(_,t) assert(t.TagName=="br.Customization.Slot.Weapon.PaintColor"); return preview_slot end})
lists.BP_ArmoryWeaponRender_C={obj("BP_ArmoryWeaponRender_C @Render",{CustomizationInstance=ci})}
lists.WBP_Menu_Armory_CustomizeWeapon_C={obj("WBP_Menu_Armory_CustomizeWeapon_C Screen",{bIsPreviewing=true,IsActivated=function() return true end})}
local trace=factory.new(runtime,a)
trace.attach()
assert(commands.colors_armory and has("Ready: colors_armory"))
-- Inactive: slot events still reach the previous handler, nothing is traced.
runtime.dev_context.before("EquipCustomizationPart")
assert(previous_reasons[1]=="EquipCustomizationPart" and not jobs["armory-trace:snapshot"])
-- Start through the console: hooks registered, a missing one counted.
fail_path=factory.HOOKS[#factory.HOOKS]
commands.colors_armory(nil,{"start"}); run("armory-trace:command")
assert(has("START | hooks installed=" .. (#factory.HOOKS-1) .. " missing=1"))
run("armory-trace:snapshot")
assert(has("SCREEN | WBP_Menu_Armory_CustomizeWeapon_C Screen | previewing=true"))
assert(has("ROW | VM_WeaponCustomization_C VM_0 | 1 | label=Paint Color | swatch=CPD_Wep_PaintColor_White | previewed=CPD_Wep_PaintColor_Red | fragment=CustomizationFragmentInstanceMaterialColor @Rifle.CI.Frag_1 | rgba=0.5000,0.2500,0.1250,1.0000"))
assert(has("PREVIEW | BP_ArmoryWeaponRender_C @Render | instance=CustomizationInstance @Render.CI | paint_fragment=CustomizationFragmentInstanceMaterialColor @Render.CI.Frag_9 | rgba=1.0000,0.0000,0.0000,1.0000"))
-- A hooked function logs and coalesces into one snapshot.
local path=factory.HOOKS[1]
hooks[path](row); hooks[path](row)
assert(has("EVENT | VM_WeaponCustomization_C:StashEquippedParts | BitReactorCustomizationSlotViewModel VM_644"))
logs={}; run("armory-trace:snapshot"); assert(not jobs["armory-trace:snapshot"])
local snapshots=0; for _,l in ipairs(logs) do if l:find("SNAPSHOT BEGIN",1,true) then snapshots=snapshots+1 end end
assert(snapshots==1,"bursts coalesce")
-- A failing read is logged, never raised.
lists.VM_WeaponCustomization_C={obj("VM_WeaponCustomization_C VM_1",{ColorSlotVMs={obj("BitReactorCustomizationSlotViewModel VM_2",{GetFragments=function() error("boom") end})}})}
runtime.dev_context.before("PreviewCustomizationPart"); run("armory-trace:snapshot")
assert(has("ROW | VM_WeaponCustomization_C VM_1 | 1 |") and has("fragment=<none>") and not has("SNAPSHOT FAILED"))
-- Stop: hooks stay registered but are silent.
commands.colors_armory(nil,{"stop"}); run("armory-trace:command")
logs={}; hooks[path](row); assert(#logs==0 and not jobs["armory-trace:snapshot"])
-- Experiment: paint writes the real weapon's row fragment, restore puts it back.
local objects={}
function StaticFindObject(path) return objects[path] end
local refreshes=0
local weapon_ci=obj("CustomizationInstance /Game/Game/Maps/Hub/HUB_Root.HUB_Root:PersistentLevel.BP_Rifle_Relby-v10_C_3.CustomizationInstance",
    {RefreshCustomization=function() refreshes=refreshes+1 end})
local colorclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local current={R=.7,G=.7,B=.7,A=1}
local bolt=obj("CustomizationFragmentInstanceMaterialColor " .. weapon_ci.full:match(" (.+)$") .. ".Slot_19.MaterialColor_262",{
    GetClass=function() return colorclass end,GetOwningCustomizationInstance=function() return weapon_ci end,
    GetColor=function() return {R=current.R,G=current.G,B=current.B,A=current.A} end,
    SetColor=function(_,c) current={R=c.R,G=c.G,B=c.B,A=c.A} end})
objects[bolt.full:match(" (.+)$")]=bolt
local bolt_row=obj("BitReactorCustomizationSlotViewModel VM_637",{DisplayName="Bolt Color",GetFragments=function() return {bolt} end})
local preview_owner=obj("CustomizationInstance /Game/Game/Maps/Hub/Sublevels/Facilities/HUB_Armory_Gameplay.HUB_Armory_Gameplay:PersistentLevel.BP_ArmoryWeaponRender_C_0.CustomizationInstance")
local preview_frag=obj("CustomizationFragmentInstanceMaterialColor X",{GetClass=function() return colorclass end,GetOwningCustomizationInstance=function() return preview_owner end})
local preview_row=obj("BitReactorCustomizationSlotViewModel VM_9",{GetFragments=function() return {preview_frag} end})
lists.VM_WeaponCustomization_C={obj("VM_WeaponCustomization_C VM_WeaponCustomization_C_0",{ColorSlotVMs={row,bolt_row,preview_row}})}
logs={}
assert(not pcall(trace.paint,0,2,"GG0000"),"bad hex refused")
local refused,why=pcall(trace.paint,1,2,"00FF00")
assert(not refused and tostring(why):find("live: 0 (BP_Rifle_Relby-v10_C_3)",1,true),"unknown VM refused with the live list")
assert(has("ROWS | vm 0 | weapon=BP_Rifle_Relby-v10_C_3 | rows: 1=Paint Color, 2=Bolt Color"))
assert(not pcall(trace.paint,0,3,"00FF00"),"preview-owned fragment refused")
trace.paint(0,2,"00FF00")
assert(current.R==0 and current.G==1 and current.B==0 and current.A==1 and refreshes==1)
assert(has("PAINT | " .. bolt.full) and has("from=0.7000,0.7000,0.7000,1.0000") and has("PAINT READBACK | 0.0000,1.0000,0.0000,1.0000"))
trace.paint(0,2,"808080")
assert(math.abs(current.R-0.2158605)<1e-6,"sRGB 0x80 -> linear 0.2159")
trace.restore()
assert(current.R==.7 and current.G==.7 and current.B==.7 and has("RESTORED | " .. bolt.full) and has("restored=1"),"restore keeps the first original")
-- A fragment replaced by a later swatch pick is left alone.
trace.paint(0,2,"FF0000"); objects[bolt.full:match(" (.+)$")]=nil
trace.restore(); assert(current.R==1 and has("RESTORE SKIPPED"),"replaced fragment untouched")
-- Console routes paint and restore.
logs={}
commands.colors_armory(nil,{"paint","0","2","0000FF"}); run("armory-trace:command")
assert(current.B==1 and current.R==0)
commands.colors_armory(nil,{"paint","0","2"}); assert(has("Usage: colors_armory"))
logs={}; commands.colors_armory(nil,{"rows"}); run("armory-trace:command"); assert(has("ROWS | vm 0"))
print("Armory trace: opt-in hooks, chained slot events, coalesced read-only snapshots, failures logged and stop passed")
