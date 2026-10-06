local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/skin_enable_probe.lua"))()
local objects,jobs,logs={},{},{}
local function obj(n,fields)
    local v=fields or {}; v.n=n; v.valid=true
    objects[n:match("^[^ ]+ (.+)$")]=v; return v
end
local a={unwrap=function(v) return v end,live=function(v) return v and v.valid end,
    name=function(v) return v.n end,text=tostring,prop=function(v,k) return v[k] end,values=function(v) return v end}
function FName(s) return s end
function StaticFindObject(p) return objects[p] end
function RegisterConsoleCommandHandler() end
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,cb) jobs[k]={ms=ms,cb=cb} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(n,cb) self.command=cb end
local function run(k) local j=assert(jobs[k]); jobs[k]=nil; j.cb() end
local midclass=obj("Class /Script/Engine.MaterialInstanceDynamic")
obj("Class /Script/Engine.MeshComponent")
local parent=obj("MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/Human/HF00/Materials/MI_HF00_Race0B.MI_HF00_Race0B",
    {ScalarParameterValues={{ParameterInfo={Name="Enable Tinting",Association=2,Index=-1},ParameterValue=0}}})
local value,writes,fail_set,fail_restore=0,0,false,false
local mid=obj("MaterialInstanceDynamic /display.face.mid",{Parent=parent})
function mid:GetClass() return midclass end
function mid:K2_GetScalarParameterValue(p) assert(p=="Enable Tinting"); return value end
function mid:SetScalarParameterValue(p,v)
    assert(p=="Enable Tinting")
    if v==0 and fail_restore then error("restore failed") end
    value=v; writes=writes+1
    if v==1 and fail_set then error("failed after write") end
end
local actor=obj("Actor /display")
local mesh=obj("Mesh /display.face")
-- Mirrors native dotted-component lookup failure; actor enumeration still works.
objects["/display.face"]=nil
local material=mid
function mesh:GetOwner() return actor end
function mesh:GetMaterialIndex(p) assert(p=="MI_Head"); return 0 end
function mesh:GetMaterial(i) assert(i==0); return material end
local components={mesh}
function mid:GetOuter() return mesh end
local stock_rgb={R=0.417885,G=0.184475,B=0.093059,A=1}
local rgb=stock_rgb
local rgb_writes,fail_rgb,fail_rgb_restore=0,false,false
local after_rgb,after_scalar
local function same_rgb(x,y) return x.R==y.R and x.G==y.G and x.B==y.B and x.A==y.A end
function mid:K2_GetVectorParameterValue(p) assert(p=="Skin Coloration"); return rgb end
function mid:SetVectorParameterValue(p,v)
    assert(p=="Skin Coloration")
    if same_rgb(v,stock_rgb) and fail_rgb_restore then error("RGB restore failed") end
    rgb={R=v.R,G=v.G,B=v.B,A=v.A}; rgb_writes=rgb_writes+1
    if after_rgb then after_rgb() end
    if not same_rgb(v,stock_rgb) and fail_rgb then error("RGB failed after write") end
end
local scalar_setter=mid.SetScalarParameterValue
function mid:SetScalarParameterValue(p,v) scalar_setter(self,p,v); if after_scalar then after_scalar(v) end end
function actor:K2_GetComponentsByClass() return components end
local data=obj("Actor /data"); actor.ClonedFromCharacter=data
local container=obj("Container /container",{IsPreviewing=true,ProxyDataStorage=data,ProxyCharacter=actor})
local preview=obj("Instance /data.instance",{GetOwner=function() return data end})
local owner=obj("Instance /owner",{GetPreviewCustomizationInstance=function() return preview end})
local s={live=true,phase="owned",part="CustomizationPartDefinition:CPD_H_SkinTone_Human_0B1",fragment="fragment",
    profile={slot="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone",skin_scalar="outfit"},
    handoff={container=container.n,display=actor.n}}
runtime.tint={pending=s,read_context=function() return {owner=owner} end,check_live=function() return true end}
runtime.picker={active={session=s}}
local probe=module.new(runtime,a); runtime.skin_enable=probe; probe.attach()
runtime.command(nil,{"start"}); probe.stop("page closed")
assert(not jobs["skin-enable:command"] and writes==0)
runtime.command(nil,{"start"}); assert(writes==0); run("skin-enable:command")
assert(value==1 and probe.pending and jobs["skin-enable:timeout"].ms==10000)
local old=jobs["skin-enable:watch"].cb
run("skin-enable:timeout"); assert(value==0 and not probe.pending and next(jobs)==nil)
old(); assert(next(jobs)==nil)
runtime.perf=assert(loadfile(scripts .. "/performance_log.lua"))().new(runtime)
runtime.perf.start()
assert(probe.start()); assert(probe.stop("manual") and value==0)
assert(runtime.perf.window.rows["skin.resolve_context"].n==1)
assert(runtime.perf.window.rows["skin.assigned"].n>=3)
runtime.perf.stop("test"); runtime.perf=nil
-- An unrelated material replacement must never receive the restore write.
assert(probe.start()); material=obj("MaterialInstanceDynamic /replacement"); local before=writes
run("skin-enable:watch"); assert(not probe.pending and writes==before)
material=mid; value=0
-- Partial native failure must roll back; failed recovery stays owned/blocked.
fail_set=true; assert(not probe.start() and value==0 and not probe.pending)
fail_restore=true; assert(not probe.start() and value==1 and probe.pending)
fail_set=false; fail_restore=false; assert(probe.stop("retry") and value==0)
-- Retired UObject is never dereferenced for a write.
assert(probe.start()); mesh.valid=false; before=writes
assert(probe.stop("mesh destroyed") and writes==before); mesh.valid=true; value=0
-- Do not overwrite an external scalar change.
assert(probe.start()); value=0.5; before=writes
assert(probe.stop("external") and writes==before and value==0.5); value=0
-- Wrong source, layout, parent definition and stock preview links fail closed.
local original=s.part; s.part="CustomizationPartDefinition:Other"
assert(not probe.start()); s.part=original
s.profile.skin_scalar=nil; assert(not probe.start()); s.profile.skin_scalar="outfit"
parent.ScalarParameterValues[1].ParameterValue=1; assert(not probe.start())
parent.ScalarParameterValues[1].ParameterValue=0
container.IsPreviewing=false; assert(not probe.start()); container.IsPreviewing=true
runtime.picker.active=nil; assert(not probe.start())
assert(value==0 and not probe.pending)
-- Captured four-fragment Zabrak descriptor opts into automatic preview/Apply
-- only. Ordinary races/slots and structurally different companions do not.
local codec=assert(loadfile(scripts .. "/color_bundle.lua"))()
local core=assert(loadfile(scripts .. "/color_fragments.lua"))().MESHES
local meshes={}; for i,v in ipairs(core) do meshes[i]=v end
meshes[6]="br.Customization.Slot.Character.Horns.Mesh"
local encoded="b1@2@GameplayTags/br.Customization.Part.Character.Race.1A;MaterialColor/Skin Coloration/"
    .. table.concat(meshes,",") .. "/MI_Head,MI_Body;MaterialScalar/Enable Tinting/br.Customization.Slot.Character.Outfit/MI_Head,MI_Body/1;MaterialSwap@2=0,0,0,1"
local human_profile,human_part=s.profile,s.part
assert(rgb_writes==0,"Human scalar probe wrote face RGB")
s.profile={slot=human_profile.slot,bundle=encoded}; s.part="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_1A1"
s.test_color={R=0.35,G=0.05,B=0.75,A=1}
parent.VectorParameterValues={{ParameterInfo={Name="Skin Coloration",Association=2,Index=-1},ParameterValue=stock_rgb}}
local human_mesh_name=mesh.n
mesh.n="Mesh /display.br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh_6"
local primary_visible=true
function mesh:IsVisible() return primary_visible end
function mesh:GetMaterialSlotNames() return {"MI_Head"} end
assert(codec.zabrak_face_enable(s.profile) and probe.supports(s))
assert(not probe.start(),"Manual Skin Tone 5 command broadened to Zabrak")
assert(probe.start("preview",s) and value==1 and same_rgb(rgb,s.test_color))
local saved_rgb_writes=rgb_writes
assert(probe.start("preview",s) and rgb_writes==saved_rgb_writes,"Repeated check rewrote RGB")
assert(probe.stop("Zabrak Cancel") and value==0 and same_rgb(rgb,stock_rgb))
-- Failure after either setter restores each owned value; failed restoration
-- remains retryable without leaving the enable switch on.
fail_rgb=true
assert(not probe.start("preview",s) and value==0 and same_rgb(rgb,stock_rgb) and not probe.pending)
fail_rgb_restore=true
assert(not probe.start("preview",s) and value==0 and probe.pending and same_rgb(rgb,s.test_color))
fail_rgb=false; fail_rgb_restore=false
assert(probe.stop("RGB restore retry") and same_rgb(rgb,stock_rgb) and not probe.pending)
assert(probe.start("preview",s)); fail_restore=true
assert(not probe.stop("scalar restore failure") and same_rgb(rgb,stock_rgb) and value==1 and probe.pending)
fail_restore=false; assert(probe.stop("scalar retry") and value==0)
-- Foreign RGB is not re-applied or restored over.
assert(probe.start("preview",s)); rgb={R=0.1,G=0.2,B=0.3,A=1}; saved_rgb_writes=rgb_writes
assert(not probe.start("preview",s) and rgb_writes==saved_rgb_writes)
assert(probe.stop("foreign RGB") and rgb_writes==saved_rgb_writes and value==0 and rgb.R==0.1)
rgb=stock_rgb
-- A native callback retiring the face stops the next setter/readback. Neither
-- RGB nor scalar recovery may write into its replacement.
after_scalar=function(v) if v==1 then material=obj("MaterialInstanceDynamic /replacement") end end
saved_rgb_writes=rgb_writes
assert(not probe.start("preview",s) and not probe.pending and rgb_writes==saved_rgb_writes)
after_scalar=nil; material=mid; value=0
after_rgb=function() material=obj("MaterialInstanceDynamic /replacement2") end
local saved_scalar_writes=writes
assert(not probe.start("preview",s) and not probe.pending and writes==saved_scalar_writes+1)
after_rgb=nil; material=mid; value=0; rgb=stock_rgb
-- Undeclared/default getter values, foreign outers and invalid colors refuse
-- before granting any setter intent.
parent.VectorParameterValues={}; local count=writes
assert(not probe.start("preview",s) and writes==count); parent.VectorParameterValues={{ParameterInfo={Name="Skin Coloration",Association=2,Index=-1},ParameterValue=stock_rgb}}
local outer=mid.GetOuter; mid.GetOuter=function() return actor end
assert(not probe.start("preview",s) and writes==count); mid.GetOuter=outer
s.test_color.R=math.huge; assert(not probe.start("preview",s) and writes==count); s.test_color.R=0.35
-- Body/horn materials and stale hidden faces can also expose MI_Head. Only
-- the uniquely visible exact face-tag component grants the transient setter.
local decoy=obj("Mesh /display.br.Customization.Slot.Character.Horns.Mesh_6")
function decoy:GetOwner() return actor end
function decoy:GetMaterialIndex() return 0 end
function decoy:IsVisible() return true end
function decoy:GetMaterial() error("Non-face material must not be acquired") end
function decoy:GetMaterialSlotNames() return {"MI_Head"} end
local hidden=obj("Mesh /display.br_Customization_Slot_Character_Appearance_Humanoid_Head_Face_Mesh_5")
local hidden_visible=false
function hidden:GetOwner() return actor end
function hidden:GetMaterialIndex() return 0 end
function hidden:IsVisible() return hidden_visible end
function hidden:GetMaterial() return material end
function hidden:GetMaterialSlotNames() return {"MI_Head"} end
components={decoy,hidden,mesh}
assert(probe.start("preview",s) and value==1 and probe.pending.mesh==mesh.n)
assert(probe.stop("ambiguous actor slot names") and value==0)
assert(probe.start("preview",s) and value==1)
primary_visible=false; runtime.picker.active={session=s}; run("skin-enable:watch")
assert(value==0 and not probe.pending,"Hidden owned face was not restored")
primary_visible=true; runtime.picker.active=nil
hidden_visible=true; local n=writes
assert(not probe.start("preview",s) and writes==n and not probe.pending)
hidden_visible=false; components={decoy,hidden}; n=writes
assert(not probe.start("preview",s) and writes==n and table.concat(logs,"\n"):find("candidates=0",1,true))
components={mesh}
for _,bad in ipairs({encoded:gsub("MI_Head,MI_Body","MI_Head"),encoded:gsub("/1;MaterialSwap","/0;MaterialSwap"),
    encoded:gsub(";MaterialSwap",""),encoded:gsub("GameplayTags/[^;]+","MaterialSwap"),encoded .. "\n"}) do
    s.profile.bundle=bad; assert(not codec.zabrak_face_enable(s.profile) and not probe.supports(s))
    local n=writes; assert(probe.start("preview",s) and writes==n)
end
s.profile.bundle=encoded; s.profile.slot="br.Customization.Slot.Character.Horns.Color"
assert(not probe.supports(s)); s.profile.slot=human_profile.slot
s.part="CustomizationPartDefinition:CPD_H_SkinTone_Ovissian_01"; assert(not probe.supports(s))
s.profile,s.part=human_profile,human_part
mesh.n=human_mesh_name
-- Teardown cannot abandon a transient switch by cancelling its restore timer.
local registry=assert(loadfile(scripts .. "/hook_registry.lua"))()
local owner_runtime=registry.start("SkinEnableTestRuntime")
owner_runtime.skin_enable={pending={}}
assert(not pcall(owner_runtime.teardown,owner_runtime) and owner_runtime.alive)
owner_runtime.skin_enable.pending=nil; owner_runtime:teardown()
_G.SkinEnableTestRuntime=nil
print("Skin enable probe: narrow ownership, deferred start, timeout, stop, stale callbacks, replacement and failed-write recovery passed")
