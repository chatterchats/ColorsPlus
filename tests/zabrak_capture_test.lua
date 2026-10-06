local scripts=assert(arg[1])
local function load(n) return assert(loadfile(scripts .. "/" .. n .. ".lua"))() end
local logs,jobs,commands={}, {}, {}
local native_reads,forbidden_reads,fs_writes,fs_reads=0,0,0,0
local file_data=nil
local original_open=io.open
io.open=function(_,mode)
    if mode~="r" then fs_writes=fs_writes+1; error("Read-only probe wrote journal") end
    fs_reads=fs_reads+1
    if file_data==nil then return nil,"missing",2 end
    return {read=function() return file_data end,close=function() return true end}
end
function RegisterConsoleCommandHandler() end
local a={unwrap=function(v) return v end,live=function(v) native_reads=native_reads+1; return v and v.valid end,
    name=function(v) native_reads=native_reads+1; return v.n end,
    prop=function(v,k) return v[k] end,
    values=function(v) native_reads=native_reads+1; assert(type(v)=="table"); return v end,
    text=function(v) assert(type(v)=="string","Do not stringify reflected pointer userdata"); return v end}
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,cb) jobs[k]={ms=ms,cb=cb} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(n,cb) commands[n]=cb end
local function run(k) local j=assert(jobs[k],k); jobs[k]=nil; j.cb() end
local function contains(s)
    for _,line in ipairs(logs) do if line:find(s,1,true) then return true end end
    return false
end
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local OUTFIT="br.Customization.Slot.Character.Outfit"
local meshes={"br.Customization.Slot.Character.Outfit.Arms.Mesh","br.Customization.Slot.Character.Outfit.Legs.Mesh",
    "br.Customization.Slot.Character.Outfit.Boots.Mesh","br.Customization.Slot.Character.Outfit.Torso.Mesh",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh","br.Customization.Slot.Character.Horns.Mesh"}
local owner={valid=true,n="CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance"}
local slot={valid=true,n="CustomizationFragmentInstanceSlot " .. owner.n:match("^[^ ]+ (.+)$") .. ".Slot_1"}
local part={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_H_SkinTone_Hum_Zabrak_1A1"}
local values={}
local codec=load("color_bundle")
local function target(parameter,tags)
    local array={}; for i,s in ipairs(tags) do array[i]={TagName=s} end
    return {MaterialParameterName=parameter,MaterialSlotNames={"MI_Head","MI_Body"},SlotNameTagsToApply={GameplayTags=array}}
end
for i,suffix in ipairs({"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}) do
    local class={valid=true,n="Class /Script/BitReactorCore.CustomizationFragmentInstance" .. suffix}
    values[i]={valid=true,n="CustomizationFragmentInstance" .. suffix .. " " .. owner.n:match("^[^ ]+ (.+)$") .. ".Fragment_" .. i,
        GetClass=function() return class end,GetOwningCustomizationInstance=function() return owner end,
        GetOwningCustomizationSlot=function() return slot end}
end
values[1].GameplayTags={GameplayTags={{TagName="br.Customization.Part.Character.Race.1A"}}}
values[2].MaterialTarget=target("Skin Coloration",meshes)
values[2].GetColor=function() return {R=.417885,G=.184475,B=.093059,A=1} end
values[3].MaterialTarget=target("Enable Tinting",{OUTFIT}); values[3].Value=1
values[4].MaterialTarget=target("",{meshes[5],meshes[6]})
setmetatable(values[4],{__index=function(_,k)
    if k=="ReplacementMaterial" or k=="ReplacementMaterialSoft" then
        forbidden_reads=forbidden_reads+1; error("Unsafe material reference read")
    end
    error("Unexpected swap member: " .. k)
end})
local _,_,description=codec.new(a).read(values,{slot=SKIN})
local profile={slot=SKIN,bundle=description}
function slot:GetFragmentInstances() native_reads=native_reads+1; return values end
function slot:SetFragmentInstances() error("Read-only capture reordered fragments") end
function owner:RefreshCustomization() error("Read-only capture refreshed source") end
values[2].SetColor=function() error("Read-only capture changed RGB") end
local context={owner=owner,source_slot=slot,part={AssetId=part},profile=profile}
runtime.tint={read_context=function() native_reads=native_reads+1; return context end}
local function boot()
    local probe=load("zabrak_capture").new(runtime,a)
    runtime.skin_target=nil
    return {},probe
end
local router,probe=boot()
local before=native_reads
assert(probe.capture())
assert(native_reads>before and contains("CAPTURE COMPLETE") and contains("hard/soft material references SKIPPED"))
assert(not probe.pending and not probe.blocked and not probe.busy)
assert(fs_writes==0 and fs_reads==0 and forbidden_reads==0)
assert(not next(jobs))
-- Every trace boundary pairs BEGIN with RETURN. Userdata itself is never logged.
local active={}
for _,line in ipairs(logs) do
    local run_id,call,phase,label=line:match("CAPTURE TRACE | run=(%d+) | call=(%d+) | (%u+) | (.+)")
    if run_id then
        local key=run_id .. ":" .. call
        if phase=="BEGIN" then assert(not active[key]); active[key]=label
        else assert(phase=="RETURN" and active[key]==label); active[key]=nil end
    end
end
assert(not next(active))
assert(probe.capture() and contains("CAPTURE BEGIN | run=2"))
local reads=native_reads
assert(native_reads==reads and fs_writes==0 and not next(jobs))
-- Lua failures identify the last native/helper boundary, reset busy, and permit
-- another read-only capture. A native fault would leave BEGIN without RETURN.
local read_context=runtime.tint.read_context
runtime.tint.read_context=function() error("context failure") end
assert(not probe.capture() and not probe.busy and contains("ERROR | tint.read_context"))
runtime.tint.read_context=read_context
local target_before=values[4].MaterialTarget
values[4].MaterialTarget=nil
assert(not probe.capture() and not probe.busy and contains("ERROR | swap MaterialTarget"))
values[4].MaterialTarget=target_before
assert(probe.capture())
local function refusal(key,value)
    local previous=runtime[key]; runtime[key]=value
    local n=native_reads
    assert(not probe.capture() and native_reads==n and not probe.busy)
    runtime[key]=previous
end
refusal("picker",{active={}}); refusal("skin_enable",{pending={}}); refusal("eye_preview",{blocked="pending"})
refusal("stock_call_trace",{window={}})
runtime.tint.applied={}; reads=native_reads; assert(not probe.capture() and native_reads==reads); runtime.tint.applied=nil
profile.bundle="unsupported"; assert(not probe.capture() and not probe.busy); profile.bundle=description
slot.valid=false; assert(not probe.capture() and not probe.busy); slot.valid=true
assert(probe.capture() and forbidden_reads==0 and fs_writes==0)
assert(fs_reads==0 and fs_writes==0 and forbidden_reads==0)
io.open=original_open
print("Zabrak capture: read-only snapshot, paired trace boundaries, pointer-read traps, errors/retries, invalid source and exclusions passed")
