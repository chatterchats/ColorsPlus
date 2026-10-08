-- Run: tools/run-tests.sh droid_target
-- Astromech droids number their mesh slots (".Body.Mesh_0"); humanoids use
-- ".Mesh". Both are color targets; neither is a launcher (color) slot.
local scripts=assert(arg[1])
local target=assert(loadfile(scripts .. "/color_target.lua"))()
local rules=assert(loadfile(scripts .. "/color_rules.lua"))()
local DROID="br.Customization.Slot.Character.Appearance.Astromech."
local CPD="CustomizationPartDefinition:"

assert(rules.mesh_tag(DROID .. "Body.Mesh_0") and rules.mesh_tag(DROID .. "Head.Mesh_2"))
assert(rules.mesh_tag("br.Customization.Slot.Character.Outfit.Torso.Mesh"),"Humanoid meshes unchanged")
assert(not rules.mesh_tag(DROID .. "Body.Mesh_0.MI_DR_AstroMech_R4_01_Body_DAM_0"),"Material sub-tags are not meshes")
assert(not rules.mesh_tag(DROID .. "Body.Mesh_x") and not rules.mesh_tag(DROID .. "Body.Meshes"))
assert(not rules.mesh_tag("br.Customization.Slot.Weapon.PaintColor.Mesh_0"),"Character slots only")

-- A droid color: one mesh, or several numbered meshes recorded exactly.
local single={slot=DROID .. "Body.Color.Secondary",mesh=DROID .. "Body.Mesh_0",parameter="Secondary Color",
    asset=CPD .. "CPD_Astromech_Body_R4_01"}
assert(target.valid(single),"Single droid mesh target")
local multi={slot=DROID .. "Head.Color.Primary",mesh=DROID .. "Head.Mesh_0",parameter="Primary Color",
    asset=CPD .. "CPD_Astromech_Head_R5",targets={
        {mesh=DROID .. "Head.Mesh_0",asset=CPD .. "CPD_Astromech_Head_R5"},
        {mesh=DROID .. "Head.Mesh_1",asset="-"},
        {mesh=DROID .. "Head.Mesh_2",asset=CPD .. "CPD_Astromech_Head_R5_Dome"}}}
assert(target.valid(multi),"Numbered droid meshes, including an absent one")
multi.targets[2].mesh=DROID .. "Head.Mesh_0"
assert(not target.valid(multi),"Duplicate meshes still refused")
multi.targets[2].mesh=DROID .. "Head.Mesh_x"
assert(not target.valid(multi),"Malformed mesh suffix refused")

-- The launcher stays off mesh (shape) selectors, numbered or not.
assert(rules.launcher_color_slot(DROID .. "Body.Color.Secondary"))
assert(not rules.launcher_color_slot(DROID .. "Body.Mesh_0"))
assert(not rules.launcher_color_slot("br.Customization.Slot.Character.Outfit.Torso.Mesh"))
print("Droid targets: numbered astromech meshes accepted; humanoid meshes unchanged; mesh selectors get no launcher")
