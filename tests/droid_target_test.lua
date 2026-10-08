-- Run: tools/run-tests.sh droid_target
-- Astromech droid color targets. The story droid BR-1's parts carry a hyphen
-- (observed in the barracks, 2026-10-08):
--   slot=...Astromech.Legs.Color.Primary | mesh=...Astromech.Legs.Mesh
--   parameter=Color 01 | asset=CustomizationPartDefinition:CPD_AST_Legs_BR-1_Tint
local scripts=assert(arg[1])
local target=assert(loadfile(scripts .. "/color_target.lua"))()
local rules=assert(loadfile(scripts .. "/color_rules.lua"))()
local DROID="br.Customization.Slot.Character.Appearance.Astromech."
local CPD="CustomizationPartDefinition:"

local legs={slot=DROID .. "Legs.Color.Primary",mesh=DROID .. "Legs.Mesh",parameter="Color 01",
    asset=CPD .. "CPD_AST_Legs_BR-1_Tint"}
assert(target.valid(legs),"BR-1's hyphenated part is a valid target")
legs.asset=CPD .. "CPD_AST_Legs_R4_Tint"
assert(target.valid(legs),"Stock droid parts unchanged")

-- Multi-mesh targets round-trip through the journal encoding with hyphens;
-- "-" on its own still means an absent mesh.
local multi={slot=DROID .. "Head.Color.Primary",mesh=DROID .. "Head.Mesh",parameter="Color 01",
    asset=CPD .. "CPD_AST_Head_BR-1_Tint",targets={
        {mesh=DROID .. "Head.Mesh",asset=CPD .. "CPD_AST_Head_BR-1_Tint"},
        {mesh=DROID .. "Body.Mesh",asset="-"}}}
assert(target.valid(multi))
local encoded=target.encode_targets(multi)
local copy={slot=multi.slot,mesh=multi.mesh,parameter=multi.parameter,asset=multi.asset}
assert(target.decode_targets(copy,encoded) and copy.targets[1].asset==CPD .. "CPD_AST_Head_BR-1_Tint"
    and copy.targets[2].asset=="-","Hyphenated names survive the journal")

-- Still refused: other punctuation, empty names, non-character slots.
for _,bad in ipairs({CPD .. "CPD_AST_Legs BR1",CPD .. "CPD_AST_Legs|BR1",CPD .. "CPD_AST_Legs=BR1",CPD .. "",CPD .. "CPD.AST"}) do
    legs.asset=bad; assert(not target.valid(legs),"Refused part name: " .. bad)
end
legs.asset=CPD .. "CPD_AST_Legs_BR-1_Tint"; legs.mesh="br.Customization.Slot.Weapon.PaintColor.Mesh"
assert(not target.valid(legs),"Character slots only")

-- The launcher belongs on droid color selectors, not their mesh selectors.
assert(rules.launcher_color_slot(DROID .. "Legs.Color.Primary"))
assert(not rules.launcher_color_slot(DROID .. "Head.Mesh"))
print("Droid targets: BR-1's hyphenated parts accepted and journaled; other punctuation and non-character slots refused")
