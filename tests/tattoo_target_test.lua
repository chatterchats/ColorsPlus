local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/color_target.lua"))()
local FACE="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
local HORNS="br.Customization.Slot.Character.Horns.Mesh"
local SLOT="br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color"
local function mesh(tag,asset)
    return {IsValid=function(self) return not self.invalid end,GetSlotNameTag=function() return {TagName=tag} end,
        GetCustomizationPartPrimaryAssetId=function() return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=asset} end}
end
local slots={[FACE]=mesh(FACE,"FaceA")}
local owner={GetSlotInstance=function(_,t) return slots[t.TagName] end}
local a={unwrap=function(v) return v end,live=function(v) return v and v:IsValid() end,
    values=function(v) return v end,text=tostring}
function FName(s) return s end
local targets=module.new(a)
local f={MaterialTarget={MaterialParameterName="Tattoo Color",MaterialSlotNames={"MI_Head"},
    SlotNameTagsToApply={GameplayTags={{TagName=FACE},{TagName=HORNS}}}}}
local function refused(fn,...) assert(not pcall(fn,...),"Expected a fail-closed target check") end
local p=targets.read(f,SLOT,owner)
assert(module.valid(p) and p.targets[2].asset=="-")
assert(targets.target(f,p)=="MI_Head"); targets.mesh(owner,p)
FName=function(s) return s==HORNS and "None" or s end
refused(targets.mesh,owner,p) -- even an absent target must round-trip correctly
FName=function(s) return s end
local encoded=module.encode_targets(p)
local q={slot=SLOT,mesh=FACE,asset=p.asset,parameter=p.parameter}
assert(module.decode_targets(q,encoded) and module.same(p,q))
for _,bad in ipairs({"",encoded .. "|extra=x",encoded .. "\n",encoded:gsub("|.*$","|"..FACE.."=-"),
    encoded:gsub("FaceA","-"),encoded:gsub("|.*$","|"..HORNS.."=None:None")}) do
    assert(not module.decode_targets(q,bad),bad)
end
assert(module.decode_targets(q,encoded))
slots[HORNS]=mesh(HORNS,"HornsA")
refused(targets.mesh,owner,p)
q=targets.read(f,SLOT,owner); assert(not module.same(p,q)); targets.mesh(owner,q)
assert(q.targets[2].asset=="CustomizationPartDefinition:HornsA")
slots[HORNS]=mesh(HORNS,"HornsB"); refused(targets.mesh,owner,q)
slots[HORNS]=nil; refused(targets.mesh,owner,q)
slots[HORNS]=mesh(FACE,"HornsA"); refused(targets.read,f,SLOT,owner)
slots[HORNS]=nil; slots[FACE]=nil; refused(targets.read,f,SLOT,owner)
slots[FACE]=mesh(FACE,"FaceA"); slots[FACE].invalid=true; refused(targets.read,f,SLOT,owner)
slots[FACE].invalid=nil
f.MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=FACE},{TagName=FACE}}
refused(targets.read,f,SLOT,owner); refused(targets.target,f,p)
f.MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=HORNS},{TagName=FACE}}
refused(targets.read,f,SLOT,owner); refused(targets.target,f,p)
f.MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=FACE}}
assert(module.valid(targets.read(f,SLOT,owner))); refused(targets.target,f,p)
f.MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=FACE},{TagName=HORNS}}
refused(targets.read,f,"br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone",owner)
f.MaterialTarget.MaterialParameterName="Skin Coloration"; assert(module.valid(targets.read(f,SLOT,owner)))
f.MaterialTarget.MaterialParameterName="Tattoo Color"
slots[FACE]=mesh(FACE,"FaceB"); refused(targets.mesh,owner,p)
assert(not module.same(p,targets.read(f,SLOT,owner)))
print("Tattoo targets: exact pair, present/absent horns, mesh changes, target mismatch and strict journal encoding passed")
