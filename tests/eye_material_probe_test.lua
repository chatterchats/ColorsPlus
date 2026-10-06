local scripts=assert(arg[1])
local logs={}
local function obj(full,t)
    t=t or {}; t.full=full
    function t:IsValid() return not self.invalid end
    function t:GetFullName() return self.full end
    return t
end
local function class(s) return obj("Class /Script/" .. s) end
local instance_class=class("Engine.MaterialInstanceConstant")
local base_class=class("Engine.Material")
local texture=obj("Texture2D /Game/Test.IrisTexture")
local base=obj("Material /Game/Test.EyeBase",{GetClass=function() return base_class end})
local function param(n,v) return {ParameterInfo={Name=n,Association=0,Index=-1},ParameterValue=v} end
local parent=obj("MaterialInstanceConstant /Game/Test.EyeParent",{GetClass=function() return instance_class end,Parent=base,
    VectorParameterValues={param("IrisTint",{R=.1,G=.2,B=.3,A=1})},ScalarParameterValues={},TextureParameterValues={}})
local replacement=obj("MaterialInstanceConstant /Game/Test.EyeBlue",{GetClass=function() return instance_class end,Parent=parent,
    VectorParameterValues={},ScalarParameterValues={param("IrisBrightness",.5)},TextureParameterValues={param("Iris",texture)}})
local owner=obj("CustomizationInstance /Game/Test.Owner")
local swap_class=class("BitReactorCore.CustomizationFragmentInstanceMaterialSwap")
local fragment=obj("CustomizationFragmentInstanceMaterialSwap /Game/Test.LeftEye",{
    GetClass=function() return swap_class end,GetOwningCustomizationInstance=function() return owner end,
    ReplacementMaterial=replacement,ReplacementMaterialSoft="/Game/Test.Unloaded",
    MaterialTarget={MaterialSlotNames={"MI_Eye_L"},SlotNameTagsToApply={GameplayTags={{TagName="br.Customization.Slot.Character.Head.Mesh"}}},MaterialParameterName="None"}})
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,text=tostring,
    values=function(v) assert(type(v)=="table"); return v end}
local probe=assert(loadfile(scripts .. "/eye_material_probe.lua"))().new(a,function(s) logs[#logs+1]=s end)
local function has(s) return table.concat(logs,"\n"):find(s,1,true) end
probe.inspect(fragment)
assert(has("MI_Eye_L") and has("name=IrisTint") and has("value=0.1,0.2,0.3,1") and has("IrisBrightness") and has(texture.full))
assert(has("compiled defaults/expressions not inspected"))
logs={}; parent.Parent=replacement; probe.inspect(fragment); assert(has("PARENT CYCLE")); parent.Parent=base
logs={}; fragment.ReplacementMaterial=nil; probe.inspect(fragment); assert(has("REPLACEMENT UNAVAILABLE")); fragment.ReplacementMaterial=replacement
logs={}; replacement.VectorParameterValues={param("Bad",{R=0/0})}; probe.inspect(fragment)
assert(has("PARAMETER GAP") and has("IrisBrightness")); replacement.VectorParameterValues={}
logs={}; replacement.ScalarParameterValues=nil; probe.inspect(fragment); assert(has("PARAMETER GAP") and has("Texture"))
replacement.ScalarParameterValues={param("IrisBrightness",.5)}
logs={}; for i=1,20 do replacement.VectorParameterValues[i]=param("Tint" .. i,{R=0,G=0,B=0,A=1}) end
probe.inspect(fragment); assert(has("TRUNCATED | Vector") and not has("name=Tint17"))
logs={}; replacement.VectorParameterValues={}; replacement.ScalarParameterValues={}
for i=1,43 do replacement.ScalarParameterValues[i]=param("Scalar" .. i,i) end
probe.inspect(fragment); assert(has("name=Scalar43") and not has("TRUNCATED | Scalar"))
replacement.ScalarParameterValues={param("IrisBrightness",.5)}
-- Static records are evidence only. Preserve false, inherited fields, and
-- bOverride=false; do not turn missing data into an empty/disabled result.
local function switch(n,value,override)
    return setmetatable({Value=value},{__index={ParameterInfo={Name=n,Association=2,Index=-1},bOverride=override},
        __newindex=function() error("Static records must not be mutated") end})
end
replacement.StaticParametersRuntime={StaticSwitchParameters={switch("UseGradient",true,true),switch("UseCloudy",false,false)}}
parent.StaticParametersRuntime={StaticSwitchParameters={switch("ParentSwitch",true,false)}}
logs={}; probe.inspect(fragment)
assert(has("STATIC SWITCH | depth=0 | row=1 | name=UseGradient | association=2 | index=-1 | value=true | override=true"))
assert(has("name=UseCloudy | association=2 | index=-1 | value=false | override=false"))
assert(has("STATIC SWITCH | depth=1 | row=1 | name=ParentSwitch"))
assert(replacement.StaticParametersRuntime.StaticSwitchParameters[1].Value==true)
logs={}; replacement.StaticParametersRuntime={StaticSwitchParameters={}}; probe.inspect(fragment)
assert(has("STATIC SWITCHES | depth=0 | count=0") and not has("STATIC GAP | depth=0"))
logs={}; replacement.StaticParametersRuntime=nil; probe.inspect(fragment)
assert(has("STATIC GAP | depth=0") and not has("STATIC SWITCHES | depth=0 | count=0") and has("IrisBrightness"))
logs={}; replacement.StaticParametersRuntime={}; probe.inspect(fragment)
assert(has("StaticSwitchParameters unavailable") and has(texture.full))
logs={}; replacement.StaticParametersRuntime=setmetatable({},{__index=function() error("unreadable switch array") end})
probe.inspect(fragment); assert(has("STATIC GAP") and has("unreadable switch array") and has("ParentSwitch"))
logs={}; replacement.StaticParametersRuntime={StaticSwitchParameters={
    switch("BadValue",1,true),switch("BadOverride",true,1),{Value=true,bOverride=true},
    switch(nil,true,true),switch("GoodAfterBad",false,true)}}
probe.inspect(fragment)
assert(has("STATIC ROW GAP | depth=0 | row=1") and has("STATIC ROW GAP | depth=0 | row=2"))
assert(has("STATIC ROW GAP | depth=0 | row=3") and has("STATIC ROW GAP | depth=0 | row=4") and has("name=GoodAfterBad"))
-- Independent budgets preserve all known Neimoidian scalar/texture evidence.
local many={}; for i=1,40 do many[i]=switch("Switch" .. i,true,true) end
replacement.StaticParametersRuntime={StaticSwitchParameters=many}
for i=1,43 do replacement.ScalarParameterValues[i]=param("Scalar" .. i,i) end
logs={}; probe.inspect(fragment)
assert(has("name=Switch32 ") and not has("name=Switch33 ") and has("STATIC TRUNCATED | depth=0 | shown=32 | count=40"))
assert(has("name=Scalar43") and has(texture.full) and has("ParentSwitch"))
replacement.ScalarParameterValues={param("IrisBrightness",.5)}
logs={}; local current=parent
parent.StaticParametersRuntime={StaticSwitchParameters=many}
for i=1,5 do
    local next_material=obj("MaterialInstanceConstant /Game/Test.Parent" .. i,{GetClass=function() return instance_class end,
        VectorParameterValues={},ScalarParameterValues={},TextureParameterValues={},StaticParametersRuntime={StaticSwitchParameters=many}})
    current.Parent=next_material; current=next_material
end
probe.inspect(fragment); assert(has("PARENT LIMIT"))
assert(has("STATIC TRUNCATED | depth=2 | shown=0 | count=40") and not has("STATIC SWITCH | depth=2"))
local _,count=table.concat(logs,"\n"):gsub("STATIC SWITCH |",""); assert(count==64,"64 static rows per swap across parents")
assert(replacement.TextureParameterValues[1].ParameterValue==texture and fragment.ReplacementMaterial==replacement)
print("Eye material probe: read-only swap/parent overrides, static switch evidence, false/missing/malformed fields, independent budgets and bounds passed")
