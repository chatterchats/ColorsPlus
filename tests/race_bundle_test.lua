-- Real preview/Default/editor modules exercised against captured race bundles.
-- No native save/equip writes. Engine copies fragment arrays at install/refresh.
local scripts=assert(arg[1])
local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
helpers.share_modules(scripts)
local function load(n) return assert(loadfile(scripts .. "/" .. n .. ".lua"))() end
local bundle=load("color_fragments")
local target=load("color_target")
local iris_rules=load("color_rules")
local objects,files,jobs,logs={},{},{},{}
-- The shipped picker must work without any developer RGB input file.
local serial,writes,source_writes=0,0,0
local on_thread=true
-- Indexed fakes: full scans of every object ever created made this test
-- quadratic (~50s). Indexes mirror objects; removals are honoured below.
local by_path,by_class={},{}
local function obj(class,path,t)
    t=t or {}; t.name=class .. " " .. path; objects[t.name]=t
    by_path[path]=t
    by_class[class]=by_class[class] or {}; by_class[class][t.name]=t
    function t:IsValid() assert(on_thread); return not self.invalid end
    function t:GetFullName() assert(on_thread and not self.invalid); return self.name end
    return t
end
local function path(o) return o.name:match("^[^ ]+ (.+)$") end
local function class(s) return obj("Class","/Script/BitReactorCore.CustomizationFragmentInstance" .. s) end
local classes={GameplayTags=class("GameplayTags"),MaterialColor=class("MaterialColor"),MaterialScalar=class("MaterialScalar"),MaterialSwap=class("MaterialSwap")}
local selected_tag=bundle.SKIN
local layout
local absent_slot,clone_alias,set_failure,donor_layout,cross_target
local orange={R=1,G=.2,B=.01,A=1}
local violet={R=.3,G=.05,B=.8,A=1}
local function asset(s) return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=s} end
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function equal(a,b) return a.R==b.R and a.G==b.G and a.B==b.B and a.A==b.A end
local function tag(s) return {TagName=s} end
local function material(parameter)
    local names,tags={},{}
    for i,s in ipairs(bundle.MATERIALS) do names[i]=s end
    for i,s in ipairs(bundle.MESHES) do tags[i]=tag(s) end
    return {MaterialParameterName=parameter,MaterialSlotNames=names,SlotNameTagsToApply={GameplayTags=tags}}
end
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local world="/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local owner=obj("CustomizationInstance",world .. "Char_Hero_Humanoid_C_0.CustomizationInstance")
local preview=obj("CustomizationInstance",world .. "BP_CustomizationPreviewProxyCharacter_C_4.CustomizationInstance")
local display=obj("BP_CustomCharacter_CustomizationProxy_C",
    "/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel.BP_HawksCustomizationProxyCharacter_C_1")
local displayed=obj("CustomizationInstance",path(display) .. ".CustomizationInstance")
display.CustomizationInstance=displayed
local actor=obj("Char_Hero_Humanoid_C",world .. "Char_Hero_Humanoid_C_0")
local data_actor=obj("BP_CustomizationPreviewProxyCharacter_C",world .. "BP_CustomizationPreviewProxyCharacter_C_4")
function owner:GetOwner() return actor end
function preview:GetOwner() return data_actor end
function displayed:GetOwner() return display end
function owner:GetPreviewCustomizationInstance() return preview end
local container=obj("BP_CustomizationPreviewProxyContainer_C",world .. "BP_CustomizationPreviewProxyContainer_C_1",
    {ProxyCharacter=display,ProxyDataStorage=data_actor,IsPreviewing=false})
display.ClonedFromCharacter=actor
local original={R=.074214,G=.043735,B=.030713,A=1}
local donor={R=.15,G=.12,B=.09,A=1}
local race="br.Customization.Part.Character.Race.2B"
local source_slot=obj("CustomizationFragmentInstanceSlot",path(owner) .. ".Slot_1")
local preview_slot=obj("CustomizationFragmentInstanceSlot",path(preview) .. ".Slot_1")
local display_slot=obj("CustomizationFragmentInstanceSlot",path(displayed) .. ".Slot_1")
local fragment_class=obj("Class","/Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local function part(i,s)
    return obj("BitReactorCustomizationPartViewModel",host .. "BitReactorCustomizationPartViewModel_" .. i,
        {AssetId=asset(s),GetClass=function() return fragment_class end})
end
local stock=part(1,"CPD_H_SkinTone_Human_2B0")
local other_family=part(2,"CPD_H_SkinTone_Human_0A0")
local shade=part(3,"CPD_H_SkinTone_Human_2B1")
local vm=obj("BitReactorCustomizationSlotViewModel",host .. "BitReactorCustomizationSlotViewModel_1",
    {SlotTag=tag(bundle.SKIN),EquippedCustomizationPartViewModel=stock,CustomizationChildSlotViewModels={}})
local arrays={}; local proxy_part=stock.AssetId
local function parent_scalar(values)
    values[3].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag("br.Customization.Slot.Character.Outfit")}
end
local function copy_target(t)
    local v={MaterialParameterName=t.MaterialParameterName,MaterialSlotNames={},SlotNameTagsToApply={GameplayTags={}}}
    for i,s in ipairs(t.MaterialSlotNames) do v.MaterialSlotNames[i]=s end
    for i,s in ipairs(t.SlotNameTagsToApply.GameplayTags) do v.SlotNameTagsToApply.GameplayTags[i]=tag(s.TagName) end
    return v
end
local function make(instance,slot,c,specifications)
    local values={}
    for _,spec in ipairs(specifications or layout) do
        serial=serial+1
        local suffix=spec.class
        local f=obj("CustomizationFragmentInstance" .. suffix,path(instance) .. ".Fragment_" .. serial,
            {GetClass=function() return classes[suffix] end,
             GetOwningCustomizationInstance=function() return instance end,GetOwningCustomizationSlot=function() return slot end})
        values[#values+1]=f
        if suffix=="MaterialColor" or suffix=="MaterialScalar" then
            f.MaterialTarget=material(spec.parameter)
            f.MaterialTarget.MaterialSlotNames=spec.materials
            if spec.meshes then
                f.MaterialTarget.SlotNameTagsToApply.GameplayTags={}
                for i,mesh in ipairs(spec.meshes) do f.MaterialTarget.SlotNameTagsToApply.GameplayTags[i]=tag(mesh) end
            end
            if suffix=="MaterialColor" then
                local factor=spec.factor or 1
                f.color=spec.constant and copy(spec.constant) or {R=c.R*factor,G=c.G*factor,B=c.B*factor,A=c.A}
                function f:GetColor() return copy(self.color) end
                function f:SetColor(value)
                    assert(on_thread and not self.invalid)
                    writes=writes+1
                    if instance==owner then
                        source_writes=source_writes+1
                        assert(files.editor:match("^editor%-v%d+\n"),"Journal before source writes")
                    end
                    self.color=copy(value)
                    if self.after_set then self.after_set() end
                end
            else f.Value=spec.value end
        elseif suffix=="GameplayTags" then f.GameplayTags={GameplayTags={tag("br.Customization.Part.Character.Race.Zabrak")}}
        else f.ReplacementMaterial="original material"; f.ReplacementMaterialSoft="original soft material" end
    end
    return values
end
local function copy_bundle(values,instance,slot)
    -- The temporary donor can have a different companion count/layout from
    -- the source. Copy the actual array, not the currently equipped template.
    local specifications={}
    for i,f in ipairs(values) do
        local spec={class=f:GetClass().name:match("CustomizationFragmentInstance([%w]+)$"),value=f.Value}
        if f.MaterialTarget then
            spec.parameter=f.MaterialTarget.MaterialParameterName
            spec.materials=f.MaterialTarget.MaterialSlotNames; spec.meshes={}
            for j,v in ipairs(f.MaterialTarget.SlotNameTagsToApply.GameplayTags) do spec.meshes[j]=v.TagName end
        end
        specifications[i]=spec
    end
    local result=make(instance,slot,original,specifications)
    for i,f in ipairs(values) do
        if f.color then result[i].color=copy(f.color) end
        if f.Value then result[i].Value=f.Value end
        if f.MaterialTarget then result[i].MaterialTarget=copy_target(f.MaterialTarget) end
        if f.GameplayTags then result[i].GameplayTags=f.GameplayTags end
        if f.ReplacementMaterial then
            result[i].ReplacementMaterial=f.ReplacementMaterial
            result[i].ReplacementMaterialSoft=f.ReplacementMaterialSoft
        end
    end
    return result
end
layout={{class="MaterialColor",parameter="Skin Coloration",materials={"MI_Head","MI_Body"}}}
arrays[owner]=make(owner,source_slot,original)
arrays[preview]=make(preview,preview_slot,original)
local function refresh()
    local src=container.IsPreviewing and preview or owner
    arrays[displayed]=copy_bundle(arrays[src],displayed,display_slot)
end
refresh()
function owner:RefreshCustomization() refresh() end
function preview:RefreshCustomization() refresh() end
local meshes={}
for _,instance in ipairs({owner,preview,displayed}) do
    meshes[instance]={}
    local all={}
    for _,mesh in ipairs(bundle.MESHES) do all[#all+1]=mesh end
    all[#all+1]="br.Customization.Slot.Character.Lekku.Mesh"
    all[#all+1]="br.Customization.Slot.Character.Outfit.Helmet.Mesh"
    all[#all+1]="br.Customization.Slot.Character.Horns.Mesh"
    all[#all+1]="br.Customization.Slot.Character.Antennae.Mesh"
    all[#all+1]="br.Customization.Slot.Character.Hair.Hair.Mesh"
    for i,s in ipairs(all) do
        meshes[instance][s]=obj("CustomizationFragmentInstanceSlot",path(instance) .. ".Mesh_" .. i,
            {GetSlotNameTag=function() return tag(s) end,GetCustomizationPartPrimaryAssetId=function() return asset("Mesh" .. i) end})
    end
    local slot=instance==owner and source_slot or instance==preview and preview_slot or display_slot
    function instance:GetSlotInstance(t)
        if t.TagName==selected_tag then return not (self==owner and absent_slot) and slot or nil end
        return meshes[self][t.TagName]
    end
    function slot:GetFragmentInstances() return arrays[instance] end
    function slot:GetSlotNameTag() return tag(selected_tag) end
    function slot:GetCustomizationPartPrimaryAssetId()
        return instance==owner and vm.EquippedCustomizationPartViewModel.AssetId
            or instance==preview and proxy_part or container.IsPreviewing and proxy_part or vm.EquippedCustomizationPartViewModel.AssetId
    end
end
function vm:GetFragments() return arrays[owner] end
function vm:CloneFragments(slot)
    assert(slot==preview_slot)
    local result=copy_bundle(arrays[owner],preview,preview_slot)
    if clone_alias then result[#result]=arrays[owner][#result] end
    return result
end
function preview_slot:SetFragmentInstances(values)
    assert(files.recovery:find("\ninstalling\n",1,true))
    arrays[preview]=copy_bundle(values,preview,preview_slot)
end
function vm:PreviewCustomizationPart(p)
    assert(p==shade)
    assert(files.recovery:match("^proxy%-v%d+\n"))
    proxy_part=p.AssetId; arrays[preview]=make(preview,preview_slot,donor,donor_layout)
    container.IsPreviewing=true; display.ClonedFromCharacter=data_actor; refresh()
end
function vm:PreviewedCustomizationPartViewModel() return shade end
function vm:ResetPreviewedPart()
    container.IsPreviewing=false; display.ClonedFromCharacter=actor
    proxy_part=vm.EquippedCustomizationPartViewModel.AssetId
    arrays[preview]=copy_bundle(arrays[owner],preview,preview_slot); refresh()
end
local pagepath=host .. "WBP_OverallUILayout_C_15.WidgetTree_16."
local page=obj("WBP_Customization_ItemPage_C",pagepath .. "WBP_Customization_ItemPage_C_19",{IsActivated=function(self) return not self.inactive end})
local master=obj("WBP_CustomCharacter_Master_C",pagepath .. "WBP_CustomCharacter_Master_C_18")
local parent=obj("Panel","/Game/Test.Parent")
local stack=obj("BitReactorActivatableWidgetStack",pagepath .. "GameLayer_Stack",
    {WidgetList={master,page},GetActiveWidget=function() return page end,GetParent=function() return parent end})
local aux=obj("CustomizationAuxVM_C",host .. "CustomizationAuxVM_C_1",{CurrentCustomizationSlotVM=vm})
local palette={stock,other_family,shade}
local grid=obj("BitReactorTileView",path(page) .. ".Grid",{GetNumItems=function() return #palette end,
    GetItemAt=function(_,i) return palette[i+1] end,GetIndexForItem=function(_,p) for i,v in ipairs(palette) do if v==p then return i-1 end end end})
local tiles=obj("WBP_Customization_SelectionTiles_C",path(page) .. ".Tiles",
    {CurrentSlotTag=tag(bundle.SKIN),PartsGridList=grid,IsVisible=function() return true end,GetParent=function() return page end})
local panel=obj("WBP_CustomizationSlotPanel_C",path(page) .. ".Panel",{WBP_Customization_SelectionTiles=tiles,IsVisible=function() return true end})
page.WBP_CustomizationSlotPanel=panel
page.SlotWidgetSwitcher=obj("CommonActivatableWidgetSwitcher",path(page) .. ".Switcher",{GetActiveWidget=function() return panel end})
local discovery_scans=0
function FindAllOf(classname)
    if classname=="WBP_Customization_ItemPage_C" or classname=="CustomizationAuxVM_C" then discovery_scans=discovery_scans+1 end
    local found={}; for n,v in pairs(by_class[classname] or {}) do if objects[n]==v then found[#found+1]=v end end
    return found
end
function StaticFindObject(s)
    local v=by_path[s]
    if v and objects[v.name]==v and not v.invalid then return v end
    for _,o in pairs(objects) do if path(o)==s and not o.invalid then return o end end
end
function FName(s) assert(on_thread); return s end
local old_open,old_rename,old_remove=io.open,os.rename,os.remove
io.open=function(p,mode)
    if mode=="r" and not files[p] then return nil,"missing",2 end
    if mode=="w" then files[p]="" end
    return {read=function() return files[p] end,write=function(self,s) files[p]=files[p] .. s; return self end,
        flush=function() return true end,close=function() return true end}
end
os.rename=function(from,to) assert(files[from] and not files[to]); files[to],files[from]=files[from],nil; return true end
os.remove=function(p) assert(files[p]); files[p]=nil; return true end
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,delay,fn) jobs[k]={fn=fn,delay=delay} end
function runtime:cancel(k) jobs[k]=nil end
local function run(k) local job=assert(jobs[k],k); jobs[k]=nil; job.fn() end
local access=load("customization_probe").new(runtime).access
local fragments=bundle.new(access)
local tint,editor,route_zabrak
local journal=helpers.journal()
local function boot()
    tint=load("tint_test").new(runtime,access,"recovery")
    editor=load("color_zone").new(runtime,access,journal,{preview=tint})
end
local function assert_ok(ok) assert(ok,table.concat(logs,"\n")) end
local function start()
    logs={}; local session=editor.begin_live(); assert_ok(session)
    assert(not jobs["tint:timeout"],"Live drafts must not arm an expiry")
    assert(session.profile and files.recovery:match("^proxy%-v%d+\n"))
    fragments.read(arrays[preview],session.profile)
    return session
end

local function skin(materials,factor,meshes)
    return {class="MaterialColor",parameter="Skin Coloration",materials=materials,factor=factor,meshes=meshes}
end
local function scalar(materials,meshes)
    return {class="MaterialScalar",parameter="Enable Tinting",materials=materials,value=1,meshes=meshes}
end
local swap={class="MaterialSwap"}
local core=bundle.MESHES
local six={unpack(core)}; six[6]="br.Customization.Slot.Character.Horns.Mesh"
local lekku_six={unpack(core)}; lekku_six[6]="br.Customization.Slot.Character.Lekku.Mesh"
local seven={unpack(core)}; seven[6]="br.Customization.Slot.Character.Lekku.Mesh"; seven[7]="br.Customization.Slot.Character.Outfit.Helmet.Mesh"
local rodian_seven={unpack(core)}; rodian_seven[6]="br.Customization.Slot.Character.Antennae.Mesh"; rodian_seven[7]="br.Customization.Slot.Character.Hair.Hair.Mesh"
local horns={"br.Customization.Slot.Character.Horns.Mesh"}
local function scar(materials,meshes,r,g)
    return {class="MaterialColor",parameter="Scar HSV Shift",materials=materials,meshes=meshes,constant={R=r,G=g,B=-2,A=1}}
end
local hue={class="MaterialScalar",parameter="Hue Shift",materials={"MI_Head","MI_Body"},value=.20000000298,meshes=lekku_six}
local iris={class="MaterialScalar",parameter="IrisUVRadius",materials={"MI_EyeRight"},value=10,meshes=lekku_six}
local ovissian_01={swap,swap,skin({"MI_Head","MI_Body"},1,lekku_six),scalar({"MI_Body"},lekku_six),
    {class="MaterialScalar",parameter="Hue Shift",materials={"MI_Head","MI_Body"},value=0,meshes=lekku_six},iris}
local ovissian_02={swap,swap,skin({"MI_Head","MI_Body"},1,lekku_six),scalar({"MI_Head","MI_Body"},lekku_six),hue}
local face={core[5]}
local lekku={"br.Customization.Slot.Character.Lekku.Mesh"}
local function marking(material,meshes)
    return {{class="MaterialColor",parameter="Tattoo Color",materials={material},meshes=meshes},scalar({material},meshes)}
end
local blush_tag="br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Blush.Color"
local function blush(mode)
    return {{class="MaterialColor",parameter="Cheek / Blush Color",materials={"MI_Head"},meshes=face},
        {class="MaterialScalar",parameter="MM Blush Blend Mode",materials={"MI_Head"},meshes=face,value=mode}}
end
local scar_tag=load("color_rules").SCAR
local function scar_tint(strength)
    return {{class="MaterialColor",parameter="MM Scar Tint",materials={"MI_Head"},meshes={face[1],horns[1]}},
        {class="MaterialScalar",parameter="MM Scar Tint Strength",materials={"MI_Head"},meshes={face[1],horns[1]},value=strength}}
end
-- Exact 10-01 capture: COS Swatch is UI-only; MM Scar Tint is an HDR multiplier.
local fresh_swatch={R=.42868998646736,G=.13013599812984,B=.19120199978352,A=1}
local fresh_tint={R=.67344999313354,G=.60796999931335,B=1.3968499898911,A=1}
local silver_swatch={R=.4396570026874542,G=.32777801156044006,B=.27049800753593445,A=1}
local silver_tint={R=.6892099976539612,G=1.5178099870681763,B=1.9695500135421753,A=1}
local function scar_palette(swatch,tint,strength)
    return {{class="MaterialColor",parameter="COS Swatch",materials={"COS_SwatchOnly"},meshes={face[1],horns[1]},constant=swatch},
        {class="MaterialColor",parameter="MM Scar Tint",materials={"MI_Head"},meshes={face[1],horns[1]},constant=tint},
        {class="MaterialScalar",parameter="MM Scar Tint Strength",materials={"MI_Head"},meshes={face[1],horns[1]},value=strength}}
end
local function iris_tint(side,amount)
    local inner=side=="Inner"
    local materials=(inner or side=="Both") and {"MI_EyeLeft","MI_EyeRight"} or {"MI_Eye" .. side}
    return {{class="MaterialColor",parameter=inner and "MM Iris Color Inner" or "MM Iris Color Outer",materials=materials,meshes=face},
        {class="MaterialScalar",parameter=inner and "MM Iris Inner Amount" or "MM Iris Recolour",materials=materials,meshes=face,value=amount}}
end
local cases={
    {"Weequay",{swap,skin({"MI_Head","MI_Body"}),scalar({"MI_Body",""})}},
    {"Twilek",{skin({"MI_Lekku"},.7,seven),skin({"MI_Body"},.7,seven),skin({"MI_Head"},1,seven),
        scalar({"MI_Head","MI_Body","MI_Lekku","MI_Neck"},seven),scar({"MI_Head","MI_Body","MI_Lekku","MI_Neck"},seven,3,3)}},
    {"Togruta",{skin({"MI_Head","MI_Body"},1,lekku_six),scalar({"MI_Head","MI_Body"},lekku_six),scar({"MI_Head","MI_Body"},lekku_six,4,4)}},
    {"Rodian",{swap,skin({"MI_Head","MI_Body"},1,rodian_seven),scalar({"MI_Head","MI_Body"},rodian_seven)}},
    {"Ovissian",{swap,swap,skin({"MI_Head","MI_Body"},1,lekku_six),scalar({"MI_Head","MI_Body"},lekku_six),hue}},
    {"Niemoidian",{swap,skin({"MI_Head","MI_Body"}),scalar({"MI_Head","MI_Body"})}},
    {"Mirialan",{skin({"MI_Head","MI_Body","MI_Neck"}),scalar({"MI_Head","MI_Body","MI_Neck"}),scar({"MI_Head","MI_Body","MI_Neck"},core,-4,1)}},
    {"Devaronian",{skin({"MI_Head","MI_Body","MI_Neck"})}},
    {"Zabrak",{skin({"MI_Head","MI_Body"},1,six),scalar({"MI_Head"},six),{class="GameplayTags"}}},
    {"OvissianHorns",{skin({"MI_Horns"},1,horns),scalar({},horns)},true},
    {"DevaronianHorns",{skin({"MI_Horns"},1,horns),scalar({},horns)},true},
    {"Ovissian01",ovissian_01,false,nil,ovissian_02},
    {"Ovissian02",ovissian_02,false,nil,ovissian_01},
    {"TogrutaFaceMarkings",marking("MI_Head",face),false,"br.Customization.Slot.Character.Appearance.Humanoid.Head.Markings.Color"},
    {"TogrutaLekkuMarkings",marking("MI_Lekku",lekku),false,"br.Customization.Slot.Character.Lekku.Markings.Color"},
    -- Zabrak skins with a material swap (the face-MID layout) always take the
    -- zone's source route: zabrak_picker_test and skin_enable_probe_test.
    {"BlushMode1",blush(1),false,blush_tag,blush(0)},
    {"BlushMode0",blush(0),false,blush_tag,blush(1)},
    {"ScarTint1",scar_tint(1),false,scar_tag,scar_tint(.25)},
    {"ScarTint025",scar_tint(.25),false,scar_tag,scar_tint(1)},
    {"IrisLeft",iris_tint("Left",1),false,"br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintLeft",iris_tint("Left",.25)},
    {"IrisRight",iris_tint("Right",.6),false,"br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintRight",iris_tint("Right",1)},
    {"IrisInner",iris_tint("Inner",.75),false,"br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisInner",iris_tint("Inner",.2)},
    {"IrisShared",iris_tint("Both",1),false,"br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisTint",iris_tint("Both",.4)},
    {"ScarPaletteFresh",scar_palette(fresh_swatch,fresh_tint,1),false,scar_tag,scar_palette(silver_swatch,silver_tint,.25)},
    {"ScarPaletteSilver",scar_palette(silver_swatch,silver_tint,.25),false,scar_tag,scar_palette(fresh_swatch,fresh_tint,1)},
    -- Tester 0A0 shape: the zone's Zabrak route declines it (no swap), so it
    -- runs through preview/editor/recovery. Scalar targets stay untouched by this route.
    {"Hum_Zabrak_0A",{{class="GameplayTags"},skin({"MI_Head","MI_Body"},1,six),
        scalar({"MI_Head","MI_Body"},six)},false,nil,nil,true},
    {"ZabrakTone4",{{class="GameplayTags"},skin({"MI_Head","MI_Body"},1,six),
        scalar({"MI_Head","MI_Body"},six)},false,nil,nil,true,"0B0","0B2"},
    {"ZabrakTone5",{{class="GameplayTags"},scalar({"MI_Head"},six),
        skin({"MI_Head"},1,six)},false,nil,{{class="GameplayTags"},skin({"MI_Head","MI_Body"},1,six),
            scalar({"MI_Head","MI_Body"},six)},true,"0B1","0B0"},
}
local all_meshes={}
for instance,values in pairs(meshes) do
    all_meshes[instance]={}; for mesh,value in pairs(values) do all_meshes[instance][mesh]=value end
end
local function reset(case)
    files={}; jobs={}; logs={}; absent_slot=nil; clone_alias=nil
    layout=case[2]; donor_layout=case[5]
    route_zabrak=case[6]
    cross_target=case[7]=="0B1"
    for instance,values in pairs(all_meshes) do
        for mesh,value in pairs(values) do meshes[instance][mesh]=value end
        if case[1]:match("^Ovissian%d*$") then meshes[instance]["br.Customization.Slot.Character.Lekku.Mesh"]=nil end
    end
    selected_tag=case[4] or (case[3] and "br.Customization.Slot.Character.Horns.Color" or bundle.SKIN)
    vm.SlotTag.TagName=selected_tag; tiles.CurrentSlotTag.TagName=selected_tag
    stock.AssetId=asset("CPD_H_SkinTone_" .. case[1] .. "_01")
    shade.AssetId=asset("CPD_H_SkinTone_" .. case[1] .. "_02")
    if route_zabrak then
        stock.AssetId=asset("CPD_H_SkinTone_Hum_Zabrak_" .. (case[7] or "0A0"))
        shade.AssetId=asset("CPD_H_SkinTone_Hum_Zabrak_" .. (case[8] or "0A1"))
    end
    if selected_tag==scar_tag then
        stock.AssetId=asset("CPD_COS_ScarTint_Red"); shade.AssetId=asset("CPD_COS_ScarTint_Pink")
        if #layout==3 then
            stock.AssetId=asset("CPD_COS_ScarLook_FreshPink"); shade.AssetId=asset("CPD_COS_ScarLook_PaleSilvery")
        end
    end
    local iris=iris_rules.iris(selected_tag)
    if iris then stock.AssetId=asset(iris.prefix .. "Gold"); shade.AssetId=asset(iris.prefix .. "Blue") end
    vm.EquippedCustomizationPartViewModel=stock; proxy_part=stock.AssetId
    palette={stock,shade}
    if case[7]=="0B0" then
        other_family.AssetId=asset("CPD_H_SkinTone_Hum_Zabrak_0B1")
        palette={stock,other_family,shade} -- Incompatible sibling comes first.
    end
    arrays[owner]=make(owner,source_slot,original); arrays[preview]=make(preview,preview_slot,original)
    container.IsPreviewing=false; display.ClonedFromCharacter=actor; refresh(); boot()
end
local function check_source(c,restore)
    local f=fragments.read(arrays[owner],editor.applied and editor.applied.profile or {slot=selected_tag})
    local p=editor.applied and editor.applied.profile
    if p then assert(fragments.matches(f,p,c,restore)) else assert(equal(f.color,c)) end
end
local function originals()
    local result={}
    for i,f in ipairs(arrays[owner]) do if f.color then result[i]=copy(f.color) end end
    return result
end
local function original_matches(expected)
    for i,c in pairs(expected) do assert(equal(arrays[owner][i].color,c),"Original group not restored at " .. i) end
    for i,f in ipairs(arrays[owner]) do
        if f.ReplacementMaterial then assert(f.ReplacementMaterial=="original material" and f.ReplacementMaterialSoft=="original soft material") end
        if f.Value~=nil then assert(f.Value==layout[i].value,"Scalar companion was modified") end
    end
end
-- Selected-slot callers reuse scalar hints, but must rediscover after an event
-- and still reject ambiguous or dead native contexts without writing anything.
reset(cases[1])
local identity=editor.selected_slot_identity()
local scans=discovery_scans
assert(editor.selected_slot_identity()==identity and discovery_scans==scans)
editor.context_changed("UpdateCurrentCustomizationSlotVM")
assert(editor.selected_slot_identity()==identity and discovery_scans==scans,"Non-structural events keep the revalidated hint")
editor.invalidate_context_lookup("page closed")
assert(editor.selected_slot_identity()==identity and discovery_scans==scans+2,"Structural events force rediscovery")
local extra_aux=obj("CustomizationAuxVM_C",host .. "CustomizationAuxVM_C_99",{CurrentCustomizationSlotVM=vm})
editor.invalidate_context_lookup()
assert(not pcall(editor.selected_slot_identity),"Rediscovery accepted ambiguous auxiliary VMs")
objects[extra_aux.name]=nil
assert(editor.selected_slot_identity()==identity)
page.inactive=true
assert(not pcall(editor.selected_slot_identity),"Cached selected-slot route ignored page deactivation")
page.inactive=false
assert(editor.selected_slot_identity()==identity)
local activated=page.IsActivated
page.IsActivated=function(self)
    editor.invalidate_context_lookup()
    return activated(self)
end
assert(not pcall(editor.selected_slot_identity),"Reentrant event promoted stale selected-slot lookup")
page.IsActivated=function(self)
    editor.invalidate_context_lookup("PreviewCustomizationPart")
    return activated(self)
end
assert(not pcall(editor.selected_slot_identity),"Any reentrant event, structural or not, refuses the lookup in flight")
page.IsActivated=activated
assert(editor.selected_slot_identity()==identity)
tint.read_context(); scans=discovery_scans
tint.read_context()
assert(discovery_scans==scans,"Repeated source reads must reuse scalar lookup")
tint.context_changed("UpdateCurrentCustomizationSlotVM")
tint.read_context()
assert(discovery_scans==scans,"Non-structural notification keeps the revalidated source lookup")
tint.invalidate_context_lookup("creator closed")
tint.read_context()
assert(discovery_scans==scans+2,"Structural notification must force source rediscovery")
page.IsActivated=function(self)
    tint.invalidate_context_lookup()
    return activated(self)
end
assert(not pcall(tint.read_context),"Reentrant event promoted stale source lookup")
page.IsActivated=function(self)
    tint.invalidate_context_lookup("UpdateCurrentCustomizationSlotVM")
    return activated(self)
end
assert(not pcall(tint.read_context),"Any reentrant event refuses the source lookup in flight")
page.IsActivated=activated
for _,case in ipairs(cases) do
    reset(case); local before=originals(); local writes_before=writes
    assert_ok(load("color_compatibility").new(runtime,access).capture())
    assert(writes==writes_before and table.concat(logs,"\n"):find(selected_tag==blush_tag
        and "CANDIDATE: blush color/blend-mode pair" or selected_tag==scar_tag
        and "CANDIDATE: scar tint/strength pair" or iris_rules.iris(selected_tag)
        and "CANDIDATE: iris color/amount pair" or "CANDIDATE: race tint bundle",1,true))
    local s=start()
    local p=s.profile
    if cross_target then
        assert(s.blue.part~=s.part and equal(s.blue.original,donor),"Donor baseline was replaced by source color")
        assert(s.blue.materials=="MI_Head,MI_Body" and s.materials=="MI_Head")
        assert(files.recovery:match("^proxy%-v12\n"))
        assert(target.self_preview(p,s.part))
        assert(not target.self_preview(p,"CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_0B0"))
        local bad={}; for k,v in pairs(p) do bad[k]=v end
        bad.bundle=p.bundle:gsub("/MI_Head","/MI_Head,MI_Body")
        assert(not target.self_preview(bad,s.part),"Same-swatch recovery accepted different material targets")
    end
    if p.bundle then
        -- Each companion class/color is gathered once per matched read, not
        -- reread by the comparison. Every later call must read native data anew.
        local counters,saved={},{ }
        for i,f in ipairs(arrays[preview]) do
            counters[i]={class=0,color=0}; saved[i]={class=f.GetClass,color=f.GetColor}
            local count,methods=counters[i],saved[i]
            f.GetClass=function(self) count.class=count.class+1; return methods.class(self) end
            if methods.color then f.GetColor=function(self) count.color=count.color+1; return methods.color(self) end end
        end
        local primary=fragments.read_matched(arrays[preview],p,s.test_color)
        for i,count in ipairs(counters) do
            assert(count.class==1 and count.color==(saved[i].color and 1 or 0),"Matched read duplicated native data: " .. case[1])
        end
        assert(fragments.matches(primary,p,s.test_color))
        for i,count in ipairs(counters) do
            assert(count.class==2 and count.color==(saved[i].color and 2 or 0),"Separate comparison must freshly read exactly once")
        end
        for i,f in ipairs(arrays[preview]) do f.GetClass,f.GetColor=saved[i].class,saved[i].color end
        local recorded=assert(load("color_bundle").parse(p.bundle))
        for i in pairs(recorded.originals) do
            local f=arrays[preview][i]; local before=f.color
            f.color={R=.123,G=.456,B=.789,A=1}
            assert(not pcall(fragments.read_matched,arrays[preview],p,s.test_color),"Changed editable companion accepted")
            f.color=before
        end
        assert(fragments.read_matched(arrays[owner],p,s.original,true),"Distinct source companion baselines must survive")
    end
    local scans_before=discovery_scans
    assert_ok(editor.update_live(s,violet))
    assert(discovery_scans==scans_before,
        "First update must reuse the verified opening lookup route: " .. case[1])
    assert(fragments.matches(fragments.read(arrays[preview],p),p,violet))
    scans_before=discovery_scans
    assert_ok(editor.update_live(s,orange))
    assert(discovery_scans==scans_before,
        "Every warm draft must reuse its lookup route: " .. case[1])
    assert(fragments.matches(fragments.read(arrays[preview],p),p,orange))
    scans_before=discovery_scans
    assert_ok(tint.check_live(s)); assert_ok(tint.check_live(s))
    run("tint:handoff-check")
    assert(discovery_scans==scans_before,"Every supported layout must avoid full idle rediscovery: " .. case[1])
    tint.context_changed("UpdateCurrentCustomizationSlotVM")
    scans_before=discovery_scans
    assert_ok(editor.update_live(s,violet))
    assert(discovery_scans==scans_before,"Non-structural events keep the revalidated route: " .. case[1])
    tint.invalidate_context_lookup("page closed")
    scans_before=discovery_scans
    assert_ok(editor.update_live(s,orange))
    assert(discovery_scans==scans_before+2,"Every layout must rediscover after a structural event: " .. case[1])
    run("tint:handoff-check"); original_matches(before)
    assert_ok(editor.cancel_live("Cancel")); original_matches(before)
    s=start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); assert(not tint.pending); original_matches(before)
    -- Hot Lua recovery preserves per-fragment originals, including Twilek's
    -- different head vs body/lekku baseline; no Lua code in either journal.
    s=start(); jobs={}; boot(); editor.start(); run("tint:recovery")
    assert(not tint.pending and not editor.blocked); original_matches(before)
    s=start(); assert_ok(editor.update_live(s,orange)); assert_ok(editor.apply_live(s))
    assert(files.editor:match("^editor%-v7\n")); check_source(orange)
    run("editor:watch")
    s=start(); assert_ok(editor.update_live(s,violet)); assert_ok(editor.cancel_live("second draft"))
    check_source(orange)
    s=start(); assert_ok(editor.update_live(s,violet)); assert_ok(editor.apply_live(s)); check_source(violet)
    assert_ok(editor.restore("Restore")); original_matches(before)
    s=start(); assert_ok(editor.apply_live(s)); jobs={}; boot(); editor.start()
    assert(editor.applied); run("editor:recovery"); original_matches(before)
    -- An old race slot disappears. Retire without writes or blocking other edits.
    s=start(); assert_ok(editor.apply_live(s)); local n=source_writes
    absent_slot=true; run("editor:watch")
    assert(not editor.applied and not editor.blocked and files.editor=="" and source_writes==n)
    reset(case); s=start(); assert_ok(editor.cancel_live("new race available"))
    -- Same owner/slot/asset, but a replaced companion is not ours to undo.
    if #layout>1 then
        s=start(); assert_ok(editor.apply_live(s)); n=source_writes
        local replacement=copy_bundle(arrays[owner],owner,source_slot)
        local index=load("color_bundle").parse(editor.applied.profile.bundle).primary==1 and 2 or 1
        arrays[owner][index]=replacement[index]; run("editor:watch")
    assert(not editor.applied and not editor.blocked and source_writes==n)
    end
    reset(case); clone_alias=true; local n=writes
    assert(not editor.begin_live() and writes==n and not tint.pending)
    clone_alias=nil
end
-- Ordinary cosmetic colors use the same preview/Apply/recovery path, including
-- native None list entries, material selectors and the game's freckles alpha.
do
    local none_class=obj("Class","/Script/BitReactorGame.BitReactorNoneCustomizationPartViewModel")
    local none=obj("BitReactorNoneCustomizationPartViewModel",host .. "BitReactorNoneCustomizationPartViewModel_0",
        {AssetId={PrimaryAssetType={Name="None"},PrimaryAssetName="None"},GetClass=function() return none_class end})
    local hsv_look=part(5,"CPD_COS_ScarLook_FreshPink")
    function vm:EquipCustomizationPart(p)
        assert(files.selection:match("^selection%-v2\n"),"Empty-selection journal before equip")
        vm.EquippedCustomizationPartViewModel=p; proxy_part=p.AssetId
        arrays[owner]=p==none and {} or make(owner,source_slot,original)
        arrays[preview]=copy_bundle(arrays[owner],preview,preview_slot); refresh()
    end
    local function empty_start()
        if selected_tag==scar_tag and #layout==3 then stock.AssetId=asset("CPD_COS_ScarTint_Red") end
        palette=selected_tag==scar_tag and #layout==2 and {none,hsv_look,stock,shade} or {none,stock,shade}
        vm.EquippedCustomizationPartViewModel=none
        proxy_part=none.AssetId; arrays[owner]={}; arrays[preview]={}; refresh()
        return start()
    end
    local function empty_restored()
        assert(vm.EquippedCustomizationPartViewModel==none and #arrays[owner]==0
            and files.selection=="" and files.recovery=="",table.concat(logs,"\n"))
    end
    local simple={
        {"Sclera",{{class="MaterialColor",parameter="ScleraTint",materials={"MI_EyeLeft","MI_EyeRight"},meshes=face}},false,
            "br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Sclera"},
        {"Lashes",{{class="MaterialColor",parameter="Root Color",
            materials={"Eyelash","^MI_HF(00|09|10)_Eyebrows$","^MI_Eyebrows$"},meshes=face}},false,
            "br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyelash.Color"},
        {"Freckles",{{class="MaterialColor",parameter="Freckle Color",materials={"MI_Head"},meshes={face[1],horns[1]}}},false,
            load("color_rules").FRECKLES},
        {"Vitiligo",{{class="MaterialColor",parameter="Vitilago Color Override",materials={"MI_Head","MI_Lekku"},
            meshes={face[1],horns[1],lekku[1]}}},false,load("color_rules").VITILIGO},
        {"ScarTint",scar_tint(1),false,scar_tag,scar_tint(.25)},
        cases[20],cases[21],cases[22],cases[23],cases[24],cases[25],
    }
    for _,case in ipairs(simple) do
        original.A=case[1]=="Freckles" and .9900000095367432 or 1
        reset(case); local before=originals()
        palette={none,stock,shade}
        if case[1]=="ScarTint" then palette={none,hsv_look,stock,shade} end
        if case[1]=="Freckles" or case[1]=="Vitiligo" or selected_tag==scar_tag then
            for _,values in pairs(meshes) do
                values[horns[1]]=nil
                if case[1]=="Vitiligo" then values[lekku[1]]=nil end
            end
        end
        local n=writes; assert_ok(load("color_compatibility").new(runtime,access).capture())
        assert(writes==n and table.concat(logs,"\n"):find("RESULT | CANDIDATE",1,true))
        local s=start(); assert(s.test_color.A==original.A and s.blue.part~="None:None")
        if case[1]=="ScarTint" then assert(s.blue.part=="CustomizationPartDefinition:CPD_COS_ScarTint_Pink") end
        assert_ok(editor.update_live(s,violet)); assert(s.test_color.A==original.A)
        local chosen=copy(violet); chosen.A=original.A
        local primary=fragments.read(arrays[preview],s.profile)
        assert(equal(primary.color,chosen)); original_matches(before)
        if case[1]=="ScarTint" then assert(arrays[preview][2].Value==1,"Donor strength replaced source strength") end
        if selected_tag==scar_tag and #layout==3 then
            assert(equal(arrays[preview][1].color,before[1]) and arrays[preview][3].Value==layout[3].value,
                "Scar donor swatch/strength replaced source companions")
            assert(s.blue.original.B>1 and load("color_bundle").parse(s.profile.bundle).primary==2)
        end
        assert_ok(editor.cancel_live("cosmetic Cancel")); original_matches(before)
        s=start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); assert(not tint.pending); original_matches(before)
        s=start(); jobs={}; boot(); editor.start(); run("tint:recovery")
        assert(not tint.pending and not editor.blocked); original_matches(before)
        s=start(); assert_ok(editor.update_live(s,violet)); assert_ok(editor.apply_live(s)); check_source(chosen)
        s=start(); assert_ok(editor.update_live(s,orange)); assert_ok(editor.cancel_live("applied cosmetic draft")); check_source(chosen)
        assert_ok(editor.restore("cosmetic Restore")); original_matches(before)
        s=start(); assert_ok(editor.update_live(s,violet)); assert_ok(editor.apply_live(s))
        jobs={}; boot(); editor.start(); assert(editor.applied and not editor.blocked)
        run("editor:recovery"); original_matches(before)
        -- A Natural donor has .99 too; restoration must recognize its exact
        -- baseline even when the selected colored preset is opaque.
        if case[1]=="Freckles" then
            original.A=1; donor.A=.9900000095367432; reset(case)
            s=start(); assert(s.blue.original.A==donor.A and s.test_color.A==1)
            assert_ok(editor.cancel_live("Natural donor")); donor.A=1
            original.A=.5; reset(case); n=writes
            assert(not editor.begin_live() and writes==n,"Unobserved freckle alpha must refuse")
            original.A=1
        else
            reset(case); s=empty_start(); assert_ok(editor.cancel_live("empty cosmetic Cancel")); empty_restored()
            s=empty_start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); empty_restored()
            s=empty_start(); jobs={}; boot(); editor.start(); run("tint:recovery"); empty_restored()
            s=empty_start(); assert_ok(editor.apply_live(s)); assert(editor.applied)
            assert_ok(editor.restore("empty cosmetic Restore")); empty_restored()
            s=empty_start(); assert_ok(editor.apply_live(s)); jobs={}; boot(); editor.start()
            run("editor:recovery"); empty_restored()
        end
    end
    original.A=1
end
-- Native scar Look presets retain their asset and raw HSV adjustment values.
-- RGB presets in this mixed palette must never become HSV preview donors.
do
    local looks={
        {name="RawRed",R=-4,G=20,B=-1,A=1},
        {name="FreshPink",R=-8,G=-4,B=6,A=1},
        {name="PaleSilvery",R=1,G=-35,B=7,A=1},
        {name="AgedBrown",R=1,G=10,B=-1,A=1},
        {name="Dark",R=-1,G=18,B=-7,A=1},
    }
    local function hsv_layout(c)
        return {{class="MaterialColor",parameter="Scar HSV Shift",materials={"MI_Head"},meshes={face[1],horns[1]},constant=c}}
    end
    local chosen={R=-12.3456789,G=27.5,B=-9.125,A=1}
    for i,value in ipairs(looks) do
        local other=looks[i%#looks+1]
        local case={"ScarHSV",hsv_layout(value),false,scar_tag,hsv_layout(other)}
        reset(case)
        stock.AssetId=asset("CPD_COS_ScarLook_" .. value.name); shade.AssetId=asset("CPD_COS_ScarLook_" .. other.name)
        local rgb_part=part(6,"CPD_COS_ScarTint_Silver")
        palette={rgb_part,stock,shade}; proxy_part=stock.AssetId
        for _,m in pairs(meshes) do m[horns[1]]=nil end
        local before=originals(); local n=writes
        assert_ok(load("color_compatibility").new(runtime,access).capture())
        assert(writes==n and table.concat(logs,"\n"):find("CANDIDATE: scar HSV adjustments",1,true))
        local s=start()
        assert(load("color_rules").hsv(s.profile) and equal(s.test_color,value) and equal(s.blue.original,other))
        assert(vm.EquippedCustomizationPartViewModel==stock and vm.EquippedCustomizationPartViewModel.AssetId.PrimaryAssetName=="CPD_COS_ScarLook_" .. value.name)
        assert(s.preview_policy=="hsv")
        local scans=discovery_scans
        assert_ok(editor.update_live(s,chosen)); assert(equal(arrays[preview][1].color,chosen)); original_matches(before)
        assert(discovery_scans==scans,"First HSV update must reuse opening lookup")
        scans=discovery_scans
        assert_ok(editor.update_live(s,value)); assert(equal(arrays[preview][1].color,value)); original_matches(before)
        assert(discovery_scans==scans,"Warm native HSV must reuse route without RGB conversion")
        assert_ok(editor.cancel_live("HSV Cancel")); original_matches(before)
        s=start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); assert(not tint.pending); original_matches(before)
        s=start(); assert_ok(editor.update_live(s,chosen))
        if i==1 then
            local journal=files.recovery; local written=writes
            files.recovery=journal:gsub("\nScar HSV Shift\n","\nMM Scar Tint\n",1)
            jobs={}; boot(); editor.start()
            assert(editor.blocked and not tint.pending and writes==written,"Raw HSV recovery accepted an RGB parameter")
            files.recovery=journal
        end
        jobs={}; boot(); editor.start(); run("tint:recovery")
        assert(not tint.pending and not editor.blocked); original_matches(before)
        s=start(); assert_ok(editor.update_live(s,chosen)); assert_ok(editor.apply_live(s)); check_source(chosen)
        s=start(); assert_ok(editor.update_live(s,value)); assert_ok(editor.cancel_live("HSV applied draft")); check_source(chosen)
        assert_ok(editor.restore("HSV Restore")); original_matches(before)
        s=start(); assert_ok(editor.update_live(s,chosen)); assert_ok(editor.apply_live(s))
        if i==1 then
            local journal=files.editor; local written=source_writes; local fields={}
            for line in journal:gmatch("([^\n]*)\n") do fields[#fields+1]=line end
            fields[8]="181,27.5,-9.125,1"; files.editor=table.concat(fields,"\n") .. "\n"
            jobs={}; boot(); editor.start()
            assert(editor.blocked and not editor.applied and source_writes==written,"Out-of-range HSV editor recovery was accepted")
            files.editor=journal
        end
        jobs={}; boot(); editor.start(); assert(editor.applied and not editor.blocked)
        run("editor:recovery"); original_matches(before)
        assert(vm.EquippedCustomizationPartViewModel==stock and files.selection==nil,"HSV opening must never equip another preset")
        s=start(); arrays[owner][1].after_set=function() arrays[owner][1].after_set=nil; error("HSV Apply interrupted") end
        assert(not editor.apply_live(s)); original_matches(before); assert(not editor.applied and not editor.blocked)
        s=start(); local bad={R=181,G=0,B=0,A=1}; n=source_writes
        assert(not editor.update_live(s,bad) and source_writes==n and not tint.pending); original_matches(before)
    end
end
-- Marking pairs and the read-only iris companion must remain the captured
-- shape. Reject unknown or changed companions without attempting setters.
local function refuses(case,mutate)
    reset(case); mutate(arrays[owner]); local n=writes
    assert(not pcall(fragments.read,arrays[owner],{slot=selected_tag}),"Unsupported companion accepted")
    assert(writes==n,"Validation wrote a fragment")
end
for _,case in ipairs({cases[14],cases[15]}) do
    refuses(case,function(a) a[2].Value=0 end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialParameterName="Hue Shift" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialSlotNames={"MI_Other"} end)
    refuses(case,function(a) a[2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[1])} end)
    refuses(case,function(a) a[3]=a[2] end)
end
refuses(cases[12],function(a) a[6].MaterialTarget.MaterialParameterName="Unknown Scalar" end)
refuses(cases[12],function(a) a[6].MaterialTarget.MaterialSlotNames={"MI_Head"} end)
refuses(cases[12],function(a) a[6].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[5])} end)
refuses(cases[12],function(a) a[6].Value=math.huge end)
for _,case in ipairs({cases[16],cases[17]}) do
    refuses(case,function(a) a[2].MaterialTarget.MaterialParameterName="Unknown Blend Mode" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialSlotNames={"MI_Other"} end)
    refuses(case,function(a) a[2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[1])} end)
    refuses(case,function(a) a[2].Value=math.huge end)
    refuses(case,function(a) a[3]=a[2] end)
end
reset(cases[16]); local blush_session=start(); assert_ok(editor.update_live(blush_session,orange)); local blend_writes=writes
arrays[preview][2].Value=.5
assert(not editor.update_live(blush_session,violet) and writes==blend_writes,"Changed blush blend mode was overwritten")
arrays[preview][2].Value=1
assert_ok(editor.cancel_live("repaired blush blend mode"))
for _,case in ipairs({cases[18],cases[19]}) do
    refuses(case,function(a) a[1].MaterialTarget.MaterialParameterName="Scar HSV Shift" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialParameterName="Scar Strength" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialSlotNames={"MI_Other"} end)
    refuses(case,function(a) a[2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[1])} end)
    refuses(case,function(a) a[2].Value=-1 end)
    refuses(case,function(a) a[2].Value=math.huge end)
    refuses(case,function(a) a[3]=a[2] end)
end
reset(cases[18]); local invalid_profile={slot=scar_tag,parameter="Scar HSV Shift",mesh=face[1],asset="CustomizationPartDefinition:CPD_H_Head"}
-- The new scar helper is an immutable companion, never the editable color.
for _,case in ipairs({cases[24],cases[25]}) do
    refuses(case,function(a) a[3]=nil end)
    refuses(case,function(a) a[1],a[2]=a[2],a[1] end)
    refuses(case,function(a) a[1].MaterialTarget.MaterialParameterName="MM Scar Tint" end)
    refuses(case,function(a) a[1].MaterialTarget.MaterialSlotNames={"MI_Head"} end)
    refuses(case,function(a) a[1].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(face[1])} end)
    refuses(case,function(a) a[1].color.B=1.4 end)
    refuses(case,function(a) a[2].color.R=-.1 end)
    refuses(case,function(a) a[2].color.B=math.huge end)
    refuses(case,function(a) a[2].color.A=.99 end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialSlotNames={"COS_SwatchOnly"} end)
    refuses(case,function(a) a[2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[1]),tag(horns[1])} end)
    refuses(case,function(a) a[3].MaterialTarget.MaterialParameterName="Enable Tinting" end)
    refuses(case,function(a) a[3].Value=1.1 end)
    refuses(case,function(a) a[3].MaterialTarget.MaterialSlotNames={"MI_Other"} end)
    reset(case); local before=originals(); local s=start(); local count=source_writes
    assert(not editor.update_live(s,fresh_tint) and source_writes==count and not tint.pending,
        "HDR native baselines must not loosen picker inputs")
    original_matches(before); s=start()
    assert_ok(editor.update_live(s,violet))
    assert(equal(arrays[preview][1].color,before[1]),"Preview recolored the display swatch")
    count=writes; arrays[preview][1].color.R=.9
    assert(not editor.update_live(s,orange) and writes==count,"Changed scar display swatch was overwritten")
    arrays[preview][1].color=copy(before[1]); assert_ok(editor.cancel_live("scar swatch repaired"))
    s=start(); assert_ok(editor.update_live(s,orange)); count=writes; arrays[preview][3].Value=.5
    assert(not editor.update_live(s,violet) and writes==count,"Changed scar strength was overwritten")
    arrays[preview][3].Value=layout[3].value; assert_ok(editor.cancel_live("scar strength repaired"))
    s=start(); assert_ok(editor.update_live(s,violet)); assert_ok(editor.apply_live(s))
    assert(equal(arrays[owner][1].color,before[1]),"Apply recolored the display swatch")
    count=source_writes; arrays[owner][2].MaterialTarget.MaterialSlotNames={"MI_Other"}
    run("editor:watch")
    assert(editor.applied and editor.blocked and source_writes==count,"Changed scar target lost recovery or accepted writes")
    arrays[owner][2].MaterialTarget.MaterialSlotNames=layout[2].materials
    assert_ok(editor.restore("scar target repaired")); original_matches(before)
end
-- The rebuilt eye shader exposes these four captured color/amount pairs.
-- Amounts and side-specific material targets must survive every ownership check.
for i=20,23 do
    local case=cases[i]
    refuses(case,function(a) a[2]=nil end)
    refuses(case,function(a) a[3]=a[2] end)
    refuses(case,function(a) a[1],a[2]=a[2],a[1] end)
    refuses(case,function(a) a[1].MaterialTarget.MaterialParameterName="MM Unknown Iris" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialParameterName="Enable Tinting" end)
    refuses(case,function(a) a[2].MaterialTarget.MaterialSlotNames={"MI_Head"} end)
    refuses(case,function(a) a[1].MaterialTarget.MaterialSlotNames={i==20 and "MI_EyeRight" or "MI_EyeLeft"} end)
    refuses(case,function(a) a[1].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag(core[1])} end)
    refuses(case,function(a) a[2].Value=-.1 end)
    refuses(case,function(a) a[2].Value=1.1 end)
    refuses(case,function(a) a[2].Value=math.huge end)
    reset(case); local source_value=layout[2].value
    local wrong=part(20,"CPD_COS_" .. (i==22 and "IrisTint_" or "IrisInner_") .. "Blue")
    palette={wrong,stock,shade}
    local s=start(); assert(s.blue.part=="CustomizationPartDefinition:" .. iris_rules.iris(selected_tag).prefix .. "Blue")
    assert(arrays[preview][2].Value==source_value,"Iris donor amount replaced the selected amount")
    assert_ok(editor.update_live(s,orange))
    local count=writes
    arrays[preview][2].Value=source_value==1 and .5 or 1
    assert(not editor.update_live(s,violet) and writes==count,"Changed iris amount was overwritten")
    arrays[preview][2].Value=source_value; assert_ok(editor.cancel_live("iris amount repaired"))
    local before=originals()
    s=start(); assert_ok(editor.apply_live(s)); local applied_before=source_writes
    arrays[owner][1].MaterialTarget.MaterialSlotNames={"MI_Head"}
    run("editor:watch")
    assert(editor.applied and editor.blocked and source_writes==applied_before,"Changed iris eye target must retain recovery without writes")
    arrays[owner][1].MaterialTarget.MaterialSlotNames=layout[1].materials
    assert_ok(editor.restore("iris eye target repaired")); original_matches(before)
end
reset(cases[18])
local color_rules=load("color_rules")
assert(color_rules.color(silver_tint,scar_tag,"MM Scar Tint"))
assert(not color_rules.input_color(silver_tint,scar_tag,"MM Scar Tint"))
assert(not color_rules.color(silver_tint,blush_tag,"MM Scar Tint"),"HDR scar values escaped the exact slot")
assert(not color_rules.color(silver_tint,scar_tag,"COS Swatch"),"HDR scar values escaped the tint parameter")
assert(color_rules.hsv(invalid_profile) and target.valid(invalid_profile))
assert(not color_rules.color({R=-4,G=20,B=-1,A=1},blush_tag,"Scar HSV Shift"),"Raw HSV values escaped the exact scar slot")
assert(not color_rules.color({R=-4,G=20,B=-1,A=1},scar_tag,"MM Scar Tint"),"Raw HSV values escaped into RGB scar tint")
assert(not color_rules.color({R=math.huge,G=0,B=0,A=1},scar_tag,"Scar HSV Shift"))
assert(not color_rules.color({R=0,G=0,B=0,A=.99},scar_tag,"Scar HSV Shift"))
local rgb_guard=start(); invalid_profile.bundle=rgb_guard.profile.bundle
assert(not color_rules.hsv(invalid_profile) and not target.valid(invalid_profile),"HSV profile accepted an RGB companion bundle")
assert_ok(editor.cancel_live("scar mode guard"))
reset(cases[18]); local scar_session=start(); assert_ok(editor.update_live(scar_session,orange)); local strength_writes=writes
arrays[preview][2].Value=.5
assert(not editor.update_live(scar_session,violet) and writes==strength_writes,"Changed scar tint strength was overwritten")
arrays[preview][2].Value=1
assert_ok(editor.cancel_live("repaired scar tint strength"))
reset(cases[12]); local guarded=start(); local n=writes
arrays[preview][6].Value=11
assert(not editor.update_live(guarded,violet) and writes==n,"Changed iris companion was overwritten")
arrays[preview][6].Value=10
assert_ok(editor.cancel_live("repaired iris companion"))
reset(cases[14]); guarded=start()
local mismatched={}; for k,v in pairs(guarded.profile) do mismatched[k]=v end
mismatched.parameter="Skin Coloration"
assert(not target.valid(mismatched),"Marking descriptor accepted a skin parameter")
assert_ok(editor.cancel_live("profile parameter guard"))
-- Interrupted multi-color Apply: restore both the written prefix and the
-- untouched suffix, even when the selected primary hasn't been written yet.
reset(cases[2]); local before=originals(); local s=start()
arrays[owner][1].after_set=function() arrays[owner][1].after_set=nil; error("setter interrupted after first color") end
assert(not editor.apply_live(s)); original_matches(before)
assert(not editor.applied and not editor.blocked)
-- Retire a newly rebuilt bundle rather than undoing its native selection.
reset(cases[2]); s=start(); assert_ok(editor.apply_live(s)); local n=source_writes
arrays[owner]=make(owner,source_slot,donor); run("editor:watch")
assert(not editor.applied and not editor.blocked and source_writes==n)
-- Native callbacks rebuild a source bundle during the first setter. Stop
-- before the next native call and never restore into the new identities.
reset(cases[2]); s=start(); n=source_writes
arrays[owner][1].after_set=function() arrays[owner]=make(owner,source_slot,donor) end
assert(not editor.apply_live(s) and source_writes==n+1)
assert(not editor.applied and not editor.blocked)
-- Recovery descriptions are bounded plain data, with one original per RGB
-- fragment; omissions, duplicate indices, nonfinite colors and code refuse.
reset(cases[2]); s=start()
local codec=load("color_bundle"); local encoded=s.profile.bundle
for _,bad in ipairs({encoded .. "\n",encoded .. ";1=0,0,0,1",encoded:gsub("@[^@]+$","@3=0,0,0,1"),
    encoded:gsub("@[^@]+$","@1=nan,0,0,1"),"return os.execute('anything')",string.rep("x",8193)}) do
    assert(not codec.parse(bad),"Malformed bundle description accepted")
end
assert_ok(editor.cancel_live("codec test"))
-- A refresh failure after the group setter must remain retryable, including
-- the donor primary baseline (which differs from the equipped source).
reset(cases[2]); s=start()
local refresh_preview=preview.RefreshCustomization
preview.RefreshCustomization=function() error("refresh interrupted after restore setters") end
assert(not editor.cancel_live("interrupted restore") and tint.pending)
preview.RefreshCustomization=refresh_preview
assert_ok(editor.cancel_live("retry restored donor baseline"))
assert(not tint.pending and not container.IsPreviewing)
reset(cases[2]); s=start()
arrays[preview][1].after_set=function() arrays[preview][1].after_set=nil; error("partial group restore") end
assert(not editor.cancel_live("partial restore") and tint.pending)
assert_ok(editor.cancel_live("retry partial restore"))
assert(not tint.pending and not container.IsPreviewing)
-- Wrong donor targets refuse before any clone write, then reset stock preview.
-- Failure after donor measurement must restore the donor using its own target,
-- not attempt a source-layout read or write on that stock bundle.
reset(cases[#cases])
local clone_before=vm.CloneFragments
local before_writes=writes
vm.CloneFragments=function() error("test stopped before cloning") end
assert(not editor.begin_live() and writes==before_writes and not container.IsPreviewing)
assert(not tint.pending and not editor.blocked)
vm.CloneFragments=clone_before
-- A prepared clone was never installed: hot recovery validates the recorded
-- donor target/RGB and resets it without touching either fragment array.
reset(cases[#cases]); start()
arrays[preview]=make(preview,preview_slot,donor,donor_layout); refresh()
files.recovery=files.recovery:gsub("\nowned\n","\nprepared\n")
before_writes=writes; boot(); editor.start(); run("tint:recovery")
assert(writes==before_writes and not tint.pending and not container.IsPreviewing)
-- Cross-target evidence must survive reload exactly; malformed target strings
-- cannot grant broader native write permissions.
for _,bad_materials in ipairs({"MI_Head","MI_Body","MI_Head,MI_Body,MI_Horns"}) do
    reset(cases[#cases]); start()
    files.recovery=files.recovery:gsub("\nMI_Head,MI_Body\n$","\n" .. bad_materials .. "\n")
    before_writes=writes; boot(); editor.start()
    assert(tint.blocked and not jobs["tint:recovery"] and writes==before_writes)
end
reset(cases[#cases]); donor_layout=layout
before_writes=writes
assert(not editor.begin_live() and writes==before_writes and not container.IsPreviewing)
assert(not tint.pending and not editor.blocked)
assert(table.concat(logs,"\n"):find("Proxy color/target differs",1,true))
-- Missing compatible donor must fail before preview activation.
reset(cases[#cases-1]); palette={stock,other_family}
before_writes=writes
assert(not editor.begin_live() and writes==before_writes and not container.IsPreviewing)
assert(table.concat(logs,"\n"):find("Compatible Zabrak preview swatch absent",1,true))
io.open,os.rename,os.remove=old_open,old_rename,old_remove
print("Race bundles: captured layouts, RGB groups, preserved companions, independent originals, hot recovery, partial Apply rollback and race retirement passed")
