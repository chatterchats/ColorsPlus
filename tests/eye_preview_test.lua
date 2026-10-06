local scripts=assert(arg[1])
local saved={open=io.open,rename=os.rename,remove=os.remove}
local files,objects,jobs,logs={},{},{},{}
local writes=0
local fail_write,fail_set,external_signature
local function obj(full,t)
    t=t or {}; t.full=full; objects[full]=t
    function t:IsValid() return not self.invalid end
    function t:GetFullName() assert(not self.invalid); return self.full end
    return t
end
local function cls(s) return obj("Class /Script/" .. s) end
local function asset(s) return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=s} end
local function tag(s) return {TagName=s} end
local function copy(v) return {R=v.R,G=v.G,B=v.B,A=v.A} end
local function name_text(v) return type(v)=="table" and v.ToString and v:ToString() or tostring(v) end
local function parameter_key(v)
    for _,key in ipairs({"IrisColor1","IrisColor2","CloudyIrisColor","IrisSaturation","IrisBrightness"}) do
        if key:lower()==name_text(v):lower() then return key end
    end
    error("Unexpected native parameter")
end
local function same(x,y) return x.R==y.R and x.G==y.G and x.B==y.B and x.A==y.A end
local runtime={alive=true,process_session="test",log=function(s) logs[#logs+1]=s end}
function runtime:after(k,d,cb) jobs[k]={delay=d,cb=cb} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(k,cb) self.commands=self.commands or {}; self.commands[k]=cb end
local function run(k) local job=assert(jobs[k],k); jobs[k]=nil; job.cb() end
local function has(s) return table.concat(logs,"\n"):find(s,1,true) end
io.open=function(p,mode)
    if mode=="r" and files[p]==nil then return nil,"missing",2 end
    if mode=="w" then if fail_write then return nil end; files[p]="" end
    return {read=function(_,n) return type(n)=="number" and files[p]:sub(1,n) or files[p] end,
        write=function(_,v) files[p]=files[p] .. v; return true end,flush=function() return true end,close=function() return true end}
end
os.rename=function(from,to) if files[from]==nil then return false end; files[to]=files[from]; files[from]=nil; return true end
os.remove=function(p) files[p]=nil; return true end
FName=function(s) return s end
RegisterConsoleCommandHandler=function() end
StaticFindObject=function(path)
    for full,o in pairs(objects) do if full:match("^[^ ]+ (.+)$")==path then return o end end
end
local a={live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,unwrap=function(v) return v end,
    prop=function(v,k) return v and v[k] end,text=name_text,values=function(v) assert(type(v)=="table"); return v end}
local EYES="br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Color"
local FACE="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
local world="/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local dp="/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel.BP_HawksCustomizationProxyCharacter_C_0"
local source_actor=obj("Char_Hero_Humanoid_C " .. world .. "Char_Hero_Humanoid_C_0")
local data_actor=obj("BP_CustomizationPreviewProxyCharacter_C " .. world .. "BP_CustomizationPreviewProxyCharacter_C_0")
local display=obj("BP_CustomCharacter_CustomizationProxy_C " .. dp,{ClonedFromCharacter=source_actor})
local container=obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "BP_CustomizationPreviewProxyContainer_C_0",
    {ProxyDataStorage=data_actor,ProxyCharacter=display,IsPreviewing=false})
local owner=obj("CustomizationInstance " .. world .. "Char_Hero_Humanoid_C_0.CustomizationInstance",{GetOwner=function() return source_actor end})
local preview=obj("CustomizationInstance " .. world .. "BP_CustomizationPreviewProxyCharacter_C_0.CustomizationInstance",{GetOwner=function() return data_actor end})
owner.GetPreviewCustomizationInstance=function() return preview end
local instance=obj("CustomizationInstance " .. dp .. ".CustomizationInstance",{GetOwner=function() return display end})
display.CustomizationInstance=instance
local mic_class,mid_class,slot_class,swap_class=cls("Engine.MaterialInstanceConstant"),cls("Engine.MaterialInstanceDynamic"),
    cls("BitReactorCore.CustomizationFragmentInstanceSlot"),cls("BitReactorCore.CustomizationFragmentInstanceMaterialSwap")
local base=obj("Material /Game/Game/Characters/Materials/M_EyeRefractive.M_EyeRefractive")
local baseline={IrisColor1={R=.5,G=.1,B=.03,A=1},IrisColor2={R=.6,G=.2,B=.04,A=1},CloudyIrisColor={R=.2,G=.04,B=.05,A=1}}
local parent=obj("MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/Neimoidian/Nei_N01/Materials/MI_Nei_N01_Eyes.MI_Nei_N01_Eyes",
    {Parent=base,GetClass=function() return mic_class end,VectorParameterValues={}})
local function params(names)
    parent.VectorParameterValues={}
    for _,n in ipairs(names) do parent.VectorParameterValues[#parent.VectorParameterValues+1]={ParameterInfo={Name=n,Association=2,Index=-1},ParameterValue=copy(baseline[n])} end
end
params({"IrisColor1","IrisColor2"})
local part=obj("BitReactorCustomizationPartViewModel /Engine/Transient.Part",{AssetId=asset("CPD_H_Eyes_Neimoidian_01")})
local roots,children,swaps={},{},{}
for n,own in ipairs({owner,instance}) do
    local root=obj("CustomizationFragmentInstanceSlot " .. own.full:match("^[^ ]+ (.+)$") .. ".Eyes",{
        GetSlotNameTag=function() return tag(EYES) end,GetCustomizationPartPrimaryAssetId=function() return part.AssetId end,
        GetOwningCustomizationInstance=function() return own end})
    roots[n]=root; children[n]={}; swaps[n]={}
    own.GetSlotInstance=function(_,t) assert(t.TagName==EYES); return root end
    for i,side in ipairs({"Left","Right"}) do
        local child=obj("CustomizationFragmentInstanceSlot " .. own.full:match("^[^ ]+ (.+)$") .. ".Eyes." .. side,{
            GetClass=function() return slot_class end,GetSlotNameTag=function() return tag(EYES .. "." .. side) end,
            GetOwningCustomizationInstance=function() return own end})
        children[n][i]=child
        local swap=obj("CustomizationFragmentInstanceMaterialSwap " .. own.full:match("^[^ ]+ (.+)$") .. ".Eyes." .. side .. ".Swap",{
            GetClass=function() return swap_class end,GetOwningCustomizationInstance=function() return own end,
            GetOwningCustomizationSlot=function() return child end,ReplacementMaterial=parent,
            MaterialTarget={MaterialSlotNames={"MI_Eye" .. side},SlotNameTagsToApply={GameplayTags={tag(FACE)}}}})
        swaps[n][i]=swap; child.GetFragmentInstances=function() return {swap} end
    end
    root.GetFragmentInstances=function() return children[n] end
end
local vm=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.VM",{SlotTag=tag(EYES),EquippedCustomizationPartViewModel=part,
    GetFragments=function() return children[1] end})
local aux=obj("CustomizationAuxVM_C /Engine/Transient.Aux",{CurrentCustomizationSlotVM=vm})
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local page=obj("WBP_Customization_ItemPage_C " .. host .. ".WBP_Customization_ItemPage_C_19",{IsActivated=function() return true end})
local master=obj("WBP_CustomCharacter_Master_C " .. host .. ".WBP_CustomCharacter_Master_C_18")
local canvas=obj("CanvasPanel /Engine/Transient.Canvas")
obj("BitReactorActivatableWidgetStack " .. host .. ".GameLayer_Stack",{
    WidgetList={master,page},GetActiveWidget=function() return page end,GetParent=function() return canvas end})
obj("Class /Script/Engine.MeshComponent")
local component=obj("SkeletalMeshComponent " .. dp .. "." .. FACE .. "_18",{GetOwner=function() return display end})
local mids={}
for i=1,2 do
    local mid=obj("MaterialInstanceDynamic " .. component.full:match("^[^ ]+ (.+)$") .. ".MI_Eyes_Test_" .. i,{
        GetClass=function() return mid_class end,GetOuter=function() return component end,Parent=parent,values={}})
    for k,v in pairs(baseline) do mid.values[k]=copy(v) end
    mid.K2_GetVectorParameterValue=function(self,n) return copy(assert(self.values[parameter_key(n)])) end
    mid.SetVectorParameterValue=function(self,n,v)
        n=parameter_key(n)
        writes=writes+1
        if fail_set=="before" then fail_set=nil; error("setter failed before") end
        if fail_set=="restore" and same(v,baseline[n]) then error("restore failed") end
        self.values[n]=copy(v)
        if fail_set=="after" then fail_set=nil; error("setter failed after") end
    end
    mids[i]=mid
end
local assigned={mids[1],mids[2]}; local star=false
component.GetMaterialIndex=function(_,n)
    n=name_text(n):lower()
    if star then return n=="mi_eyes" and 0 or -1 end
    return n=="mi_eyeleft" and 0 or n=="mi_eyeright" and 1 or -1
end
component.GetNumMaterials=function() return star and 1 or 2 end
component.GetMaterial=function(_,i) return assigned[i+1] end
display.K2_GetComponentsByClass=function() return {component} end
FindAllOf=function(c)
    if c=="WBP_Customization_ItemPage_C" then return {page} end
    if c=="CustomizationAuxVM_C" then return {aux} end
    if c=="BP_CustomizationPreviewProxyContainer_C" then return {container} end
    if c=="SkeletalMeshComponent" then return {component} end
    error("Unexpected scan: " .. c)
end
local module=assert(loadfile(scripts .. "/eye_preview.lua"))()
local function new() local e=module.new(runtime,a,"eyes"); runtime.eye_preview=e; e.start(); return e end
local eye=new(); eye.attach(); assert(runtime.commands.colors_eyes)
local function restored()
    assert(not eye.pending and not eye.blocked and files.eyes=="")
    for _,mid in ipairs(mids) do for n,v in pairs(baseline) do assert(same(mid.values[n],v),n) end end
end
assert(eye.begin(),table.concat(logs,"\n")); assert(#eye.pending.rows==4)
assert(mids[1].values.IrisColor1.G==1 and same(mids[1].values.IrisColor2,baseline.IrisColor2))
assert(jobs["eyes:stage"].delay==5000); local stale=jobs["eyes:stage"].cb
run("eyes:watch"); run("eyes:stage"); assert(same(mids[1].values.IrisColor1,baseline.IrisColor1))
run("eyes:stage"); assert(mids[1].values.IrisColor2.B==1 and same(mids[1].values.IrisColor1,baseline.IrisColor1))
run("eyes:stage"); run("eyes:stage"); restored()
assert(eye.begin()); local current=eye.pending; stale(); assert(eye.pending==current); assert(eye.stop("manual")); restored()
assert(eye.begin()); assert(jobs["eyes:timeout"].delay==20000); run("eyes:timeout"); restored()
-- Failures after partial writes restore all touched rows, without shared asset setters.
for _,mode in ipairs({"before","after"}) do fail_set=mode; assert(not eye.begin()); restored() end
assert(eye.begin()); fail_set="restore"; assert(not eye.stop("failure") and eye.pending and files.eyes~="")
fail_set=nil; assert(eye.stop("retry")); restored()
-- A retained record is recoverable without an active editor and never resumes.
assert(eye.begin()); eye=new(); assert(eye.pending and not eye.pending.signature)
aux.CurrentCustomizationSlotVM=nil; run("eyes:recovery"); aux.CurrentCustomizationSlotVM=vm; restored()
assert(eye.begin()); eye=new(); local old_recovery=jobs["eyes:recovery"].cb
assert(eye.stop("before queued recovery")); assert(eye.begin()); current=eye.pending
old_recovery(); assert(eye.pending==current); assert(eye.stop()); restored()
assert(eye.begin()); eye.context_changed("page closed"); run("eyes:event"); restored()
assert(eye.begin()); local lookup=StaticFindObject
StaticFindObject=function(path) if path==component.full:match("^[^ ]+ (.+)$") then return nil end; return lookup(path) end
assert(eye.stop("component lookup fallback")); StaticFindObject=lookup; restored()
assert(eye.begin()); container.IsPreviewing=true; run("eyes:watch"); container.IsPreviewing=false; restored()
-- A game's material replacement/parameter edit wins over the test.
assert(eye.begin()); assigned[1]=parent; assert(eye.stop("native replacement")); assigned[1]=mids[1]
mids[1].values.IrisColor1=copy(baseline.IrisColor1); restored()
assert(eye.begin()); mids[1].values.IrisColor1={R=.123,G=.234,B=.345,A=1}; assert(eye.stop("external edit"))
assert(mids[1].values.IrisColor1.R==.123); mids[1].values.IrisColor1=copy(baseline.IrisColor1); restored()
-- Guards: missing override, shared asset, hover, foreign MID outer, alias, file failure.
local function refused(setup,cleanup)
    setup(); local before=writes; logs={}; assert(not eye.begin(),table.concat(logs,"\n")); assert(writes==before and not eye.pending); cleanup()
end
refused(function() params({}) end,function() params({"IrisColor1","IrisColor2"}) end)
refused(function() assigned[1]=parent end,function() assigned[1]=mids[1] end)
refused(function() container.IsPreviewing=true end,function() container.IsPreviewing=false end)
refused(function() mids[1].GetOuter=function() return source_actor end end,function() mids[1].GetOuter=function() return component end end)
refused(function() assigned[2]=mids[1] end,function() assigned[2]=mids[2] end)
refused(function() fail_write=true end,function() fail_write=false end)
refused(function() runtime.tint={applied={}} end,function() runtime.tint=nil end)
-- Albino cycles only the explicitly recorded CloudyIrisColor.
params({"CloudyIrisColor"}); assert(eye.begin()); assert(#eye.pending.rows==2)
run("eyes:stage"); run("eyes:stage"); assert(mids[1].values.CloudyIrisColor.R==1)
assert(eye.stop()); restored(); params({"IrisColor1","IrisColor2"})
-- Rodian Star uses a shared material SLOT, not two separately edited targets.
star=true
for _,set in ipairs(swaps) do for _,s in ipairs(set) do s.MaterialTarget.MaterialSlotNames={"MI_Eyes"} end end
assert(eye.begin(),table.concat(logs,"\n")); assert(#eye.pending.rows==2); assert(eye.stop()); restored()
star=false; for _,set in ipairs(swaps) do for i,s in ipairs(set) do s.MaterialTarget.MaterialSlotNames={i==1 and "MI_EyeLeft" or "MI_EyeRight"} end end
-- Constructor and reflected names can have different display capitalization.
local constructor=FName
FName=function(s) return {ToString=function() return s:lower() end} end
for _,set in ipairs(swaps) do for _,s in ipairs(set) do s.MaterialTarget.MaterialSlotNames[1]=s.MaterialTarget.MaterialSlotNames[1]:upper() end end
for _,p in ipairs(parent.VectorParameterValues) do p.ParameterInfo.Name=p.ParameterInfo.Name:upper() end
assert(eye.begin(),table.concat(logs,"\n")); assert(has("EYE FNAME | CASE NORMALIZED"))
run("eyes:stage"); run("eyes:stage"); assert(mids[1].values.IrisColor2.B==1)
eye=new(); run("eyes:recovery"); restored()
FName=constructor
-- Genuine slot/parameter lookup mismatches still refuse before setters.
for _,bad in ipairs({"None","MI_EyeLeft_0","MI_EyeRight"}) do
    refused(function() FName=function() return bad end end,function() FName=constructor end)
end
refused(function() FName=function(s) return s=="IrisColor1" and "None" or s end end,function() FName=constructor end)
-- Texture-path scalar test uses the same ownership, journal and cancellation
-- lifecycle, without any texture/vector/static-switch setters.
local original_parent,original_asset=parent.full,part.AssetId
local brown="MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/_Eyes/MI_Eyes_Brown_02.MI_Eyes_Brown_02"
local rodian="MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/Rodian/Rod_R01/Materials/MI_Rod_R01_Eyes_Star02.MI_Rod_R01_Eyes_Star02"
local scalar_baseline={IrisSaturation=1.308,IrisBrightness=1.3}
local scalar_writes,scalar_failure,fail_scalar_at=0,nil,nil
parent.ScalarParameterValues={}
for n,v in pairs(scalar_baseline) do
    parent.ScalarParameterValues[#parent.ScalarParameterValues+1]={ParameterInfo={Name=n,Association=2,Index=-1},ParameterValue=v}
end
for _,mid in ipairs(mids) do
    mid.scalars={IrisSaturation=scalar_baseline.IrisSaturation,IrisBrightness=scalar_baseline.IrisBrightness}
    mid.K2_GetScalarParameterValue=function(self,n) return assert(self.scalars[parameter_key(n)]) end
    mid.SetScalarParameterValue=function(self,n,v)
        n=parameter_key(n); assert(type(v)=="number" and files.eyes:match("^eye%-scalar%-v1\n"),"Journal precedes scalar write")
        scalar_writes=scalar_writes+1
        if scalar_failure=="before" then scalar_failure=nil; error("scalar setter failed before") end
        if scalar_failure=="restore" and v==scalar_baseline[n] then error("scalar restore failed") end
        if scalar_failure=="noop" then scalar_failure=nil; return end
        self.scalars[n]=v
        if scalar_failure=="after" or scalar_writes==fail_scalar_at then scalar_failure=nil; fail_scalar_at=nil; error("scalar setter failed after") end
    end
end
local vector_writes=writes
local function scalar_restored()
    restored(); assert(writes==vector_writes,"Texture test must not write vectors")
    for _,mid in ipairs(mids) do for n,v in pairs(scalar_baseline) do assert(math.abs(mid.scalars[n]-v)<0.00001,n) end end
end
local function texture_refused(setup,cleanup)
    setup(); local before=scalar_writes; assert(not eye.begin("texture")); assert(scalar_writes==before and not eye.pending); cleanup()
end
texture_refused(function() end,function() end) -- Neimoidian is not this test's target
parent.full=brown; part.AssetId=asset("CPD_H_Eyes_Brown_02")
eye.attach(); runtime.commands.colors_eyes("colors_eyes",{"texture"}); assert(not eye.pending); run("eyes:command")
assert(eye.pending and #eye.pending.rows==4 and mids[1].scalars.IrisSaturation==0 and mids[2].scalars.IrisSaturation==0)
local scalar_stale=jobs["eyes:stage"].cb
run("eyes:watch"); run("eyes:stage"); assert(mids[1].scalars.IrisSaturation==scalar_baseline.IrisSaturation)
run("eyes:stage"); assert(mids[1].scalars.IrisBrightness==scalar_baseline.IrisBrightness*.25)
assert(mids[1].scalars.IrisSaturation==scalar_baseline.IrisSaturation)
run("eyes:stage"); run("eyes:timeout"); scalar_restored()
assert(eye.begin("texture")); current=eye.pending; scalar_stale(); assert(eye.pending==current)
assert(eye.stop("manual scalar stop")); scalar_restored()
assert(eye.begin("texture")); eye.context_changed("page closed"); run("eyes:event"); scalar_restored()
assert(eye.begin("texture")); container.IsPreviewing=true; run("eyes:watch"); container.IsPreviewing=false; scalar_restored()
for _,mode in ipairs({"before","after","noop"}) do scalar_failure=mode; assert(not eye.begin("texture")); scalar_restored() end
fail_scalar_at=scalar_writes+3; assert(not eye.begin("texture")); scalar_restored() -- second eye partial write
assert(eye.begin("texture")); scalar_failure="restore"; assert(not eye.stop() and eye.blocked and files.eyes~="")
scalar_failure=nil; assert(eye.stop()); scalar_restored()
assert(eye.begin("texture")); eye=new(); aux.CurrentCustomizationSlotVM=nil
run("eyes:recovery"); aux.CurrentCustomizationSlotVM=vm; scalar_restored()
assert(eye.begin("texture")); mids[1].scalars.IrisSaturation=.456; run("eyes:watch")
assert(mids[1].scalars.IrisSaturation==.456); mids[1].scalars.IrisSaturation=scalar_baseline.IrisSaturation; scalar_restored()
assert(eye.begin("texture")); assigned[1]=parent; assert(eye.stop()); assigned[1]=mids[1]
mids[1].scalars.IrisSaturation=scalar_baseline.IrisSaturation; scalar_restored()
local scalar_params=parent.ScalarParameterValues
texture_refused(function() parent.ScalarParameterValues={} end,function() parent.ScalarParameterValues=scalar_params end)
texture_refused(function() scalar_params[1].ParameterInfo.Association=0 end,function() scalar_params[1].ParameterInfo.Association=2 end)
texture_refused(function() scalar_params[3]=scalar_params[1] end,function() scalar_params[3]=nil end)
texture_refused(function() parent.full=original_parent end,function() parent.full=brown end)
texture_refused(function() FName=function(s) return s=="IrisSaturation" and "None" or s end end,function() FName=constructor end)
texture_refused(function() fail_write=true end,function() fail_write=false end)
texture_refused(function() runtime.picker={active=true} end,function() runtime.picker=nil end)
texture_refused(function() runtime.tint={applied={}} end,function() runtime.tint=nil end)
for _,bad in ipairs({0,-1,0/0,math.huge,65}) do
    texture_refused(function() mids[1].scalars.IrisSaturation=bad end,function() mids[1].scalars.IrisSaturation=scalar_baseline.IrisSaturation end)
end
-- Shared Rodian slot is edited once per parameter, with case-preserving names.
parent.full=rodian; part.AssetId=asset("CPD_H_Eyes_Rodian_03"); star=true
for _,set in ipairs(swaps) do for _,s in ipairs(set) do s.MaterialTarget.MaterialSlotNames={"MI_Eyes"} end end
FName=function(s) return {ToString=function() return s:lower() end} end
for _,p in ipairs(scalar_params) do p.ParameterInfo.Name=p.ParameterInfo.Name:upper() end
assert(eye.begin("texture")); assert(#eye.pending.rows==2); assert(eye.stop()); scalar_restored()
FName=constructor
assert(eye.begin("texture")); local scalar_record=files.eyes; assert(eye.stop()); scalar_restored()
for _,bad in ipairs({scalar_record:gsub("eye%-scalar%-v1","eye-v1"),scalar_record:gsub("IrisSaturation","IrisColor1"),
    scalar_record:gsub("IrisSaturation","UnknownScalar"),scalar_record:gsub("eye%-scalar%-v1","eye-scalar-v2")}) do
    files.eyes=bad; local before=scalar_writes; eye=new(); assert(eye.blocked and not eye.pending and scalar_writes==before)
end
files.eyes=""; eye=new(); parent.full=original_parent; part.AssetId=original_asset; star=false
for _,set in ipairs(swaps) do for i,s in ipairs(set) do s.MaterialTarget.MaterialSlotNames={i==1 and "MI_EyeLeft" or "MI_EyeRight"} end end
assert(eye.begin()); local record=files.eyes; assert(eye.stop()); restored()
for _,bad in ipairs({record .. "extra\n",record:gsub("IrisColor1","UnknownParameter"),record:gsub("eye%-v1","eye-v2")}) do
    files.eyes=bad; local before=writes; eye=new(); assert(eye.blocked and not eye.pending and writes==before)
end
files.eyes=""; eye=new(); files["eyes.previous"]=""; eye=new(); assert(eye.blocked)
io.open,os.rename,os.remove=saved.open,saved.rename,saved.remove
print("Eye preview: vector/scalar modes, real targets, two eyes/Star/Albino, timed stages, partial failures, native changes, typed recovery and guards passed")
