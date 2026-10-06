-- Real tint/default/editor modules with a three-fragment, five-mesh fixture.
local scripts=assert(arg[1])
local function load(n) return assert(loadfile(scripts .. "/" .. n .. ".lua"))() end
local bundle=load("color_fragments")
local target=load("color_target")
local objects,files,jobs,logs={},{},{},{}
-- Match a clean tester package: no developer rgb.txt is installed.
local serial,writes,source_writes=0,0,0
local on_thread=true
local function obj(class,path,t)
    t=t or {}; t.name=class .. " " .. path; objects[t.name]=t
    function t:IsValid() assert(on_thread); return not self.invalid end
    function t:GetFullName() assert(on_thread and not self.invalid); return self.name end
    return t
end
local function path(o) return o.name:match("^[^ ]+ (.+)$") end
local function class(s) return obj("Class","/Script/BitReactorCore.CustomizationFragmentInstance" .. s) end
local classes={GameplayTags=class("GameplayTags"),MaterialColor=class("MaterialColor"),MaterialScalar=class("MaterialScalar")}
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
local function make(instance,slot,color,skin_race)
    local values={}
    for _,suffix in ipairs({"GameplayTags","MaterialColor","MaterialScalar"}) do
        serial=serial+1
        local f=obj("CustomizationFragmentInstance" .. suffix,path(instance) .. ".Fragment_" .. serial,
            {GetClass=function() return classes[suffix] end,
             GetOwningCustomizationInstance=function() return instance end,GetOwningCustomizationSlot=function() return slot end})
        values[#values+1]=f
    end
    values[1].GameplayTags={GameplayTags={tag(skin_race or race)}}
    values[2].MaterialTarget=material("Skin Coloration")
    values[2].color=copy(color)
    local color_fragment=values[2]
    function color_fragment:GetColor() return copy(self.color) end
    function color_fragment:SetColor(c)
        assert(on_thread)
        writes=writes+1; if instance==owner then source_writes=source_writes+1 end
        self.color=copy(c)
        if self.after_set then self.after_set() end
    end
    values[3].MaterialTarget=material("Enable Tinting"); values[3].Value=1
    return values
end
arrays[owner]=make(owner,source_slot,original)
arrays[preview]=make(preview,preview_slot,original)
local function refresh()
    local src=container.IsPreviewing and preview or owner
    arrays[displayed]=make(displayed,display_slot,arrays[src][2].color,arrays[src][1].GameplayTags.GameplayTags[1].TagName)
    arrays[displayed][3].Value=arrays[src][3].Value
    arrays[displayed][3].MaterialTarget=copy_target(arrays[src][3].MaterialTarget)
    arrays[displayed][2].MaterialTarget=copy_target(arrays[src][2].MaterialTarget)
end
refresh()
function owner:RefreshCustomization() refresh() end
function preview:RefreshCustomization() refresh() end
local meshes={}
for _,instance in ipairs({owner,preview,displayed}) do
    meshes[instance]={}
    for i,s in ipairs(bundle.MESHES) do
        meshes[instance][s]=obj("CustomizationFragmentInstanceSlot",path(instance) .. ".Mesh_" .. i,
            {GetSlotNameTag=function() return tag(s) end,GetCustomizationPartPrimaryAssetId=function() return asset("Mesh" .. i) end})
    end
    local slot=instance==owner and source_slot or instance==preview and preview_slot or display_slot
    function instance:GetSlotInstance(t) return t.TagName==bundle.SKIN and slot or meshes[self][t.TagName] end
    function slot:GetFragmentInstances() return arrays[instance] end
    function slot:GetSlotNameTag() return tag(bundle.SKIN) end
    function slot:GetCustomizationPartPrimaryAssetId()
        return instance==owner and vm.EquippedCustomizationPartViewModel.AssetId
            or instance==preview and proxy_part or container.IsPreviewing and proxy_part or vm.EquippedCustomizationPartViewModel.AssetId
    end
end
function vm:GetFragments() return arrays[owner] end
local clone_mode
function vm:CloneFragments(slot)
    assert(slot==preview_slot)
    if clone_mode=="throw" then error("CloneFragments failed before cloning") end
    local values=make(preview,preview_slot,arrays[owner][2].color,arrays[owner][1].GameplayTags.GameplayTags[1].TagName)
    values[3].MaterialTarget=copy_target(arrays[owner][3].MaterialTarget)
    if clone_mode=="source-alias" then values[1]=arrays[owner][1] end
    if clone_mode=="stock-alias" then values[1]=arrays[preview][1] end
    if clone_mode=="stock-scalar" then parent_scalar(values) end
    if clone_mode=="set-throws" then values[2].after_set=function() error("detached SetColor interrupted") end end
    return values
end
local install_mode
function preview_slot:SetFragmentInstances(values)
    assert(#values==3 and files.recovery:find("\ninstalling\n",1,true))
    -- Reproduce native copying; never assume the submitted clone is installed.
    arrays[preview]=make(preview,preview_slot,values[2].color,values[1].GameplayTags.GameplayTags[1].TagName)
    arrays[preview][3].Value=values[3].Value
    arrays[preview][3].MaterialTarget=copy_target(values[3].MaterialTarget)
    if install_mode=="scalar" then arrays[preview][3].Value=0 end
    if install_mode=="stock-scalar" then parent_scalar(arrays[preview]) end
    if install_mode=="throw" then error("setter threw after copying") end
end
local donor_mode
function vm:PreviewCustomizationPart(p)
    assert(p==shade,"Must skip the other race-tag family in the palette")
    assert(files.recovery:match("^proxy%-v9\n") or files.recovery:match("^proxy%-v10\n"))
    if donor_mode=="before" then error("before donor activation") end
    proxy_part=p.AssetId
    arrays[preview]=make(preview,preview_slot,donor,donor_mode=="wrong-race" and "br.Customization.Part.Character.Race.0A" or race)
    -- Observed 2B1 donor: scalar targets Outfit; its color still targets 5 meshes.
    if donor_mode~="five-mesh" and donor_mode~="empty-scalar" then parent_scalar(arrays[preview]) end
    if donor_mode=="wrong-parent" then arrays[preview][3].MaterialTarget.SlotNameTagsToApply.GameplayTags[1]=tag("br.Customization.Slot.Character") end
    if donor_mode=="color-parent" then arrays[preview][2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag("br.Customization.Slot.Character.Outfit")} end
    if donor_mode=="scalar-zero" then arrays[preview][3].Value=0 end
    if donor_mode=="scalar-material" then arrays[preview][3].MaterialTarget.MaterialSlotNames[2]="MI_Wrong" end
    if donor_mode=="short-color" then arrays[preview][2].MaterialTarget.MaterialSlotNames={"MI_Head"} end
    if donor_mode=="empty-scalar" then arrays[preview][3].MaterialTarget.MaterialSlotNames={} end
    if donor_mode=="extra-mesh" then
        arrays[preview][2].MaterialTarget.SlotNameTagsToApply.GameplayTags[6]=tag("br.Test.Extra.Mesh")
    end
    container.IsPreviewing=true; display.ClonedFromCharacter=data_actor; refresh()
    if donor_mode=="after" then error("after donor activation") end
end
function vm:PreviewedCustomizationPartViewModel() return shade end
local reset_failure
function vm:ResetPreviewedPart()
    if reset_failure then error("reset interrupted") end
    container.IsPreviewing=false; display.ClonedFromCharacter=actor
    proxy_part=vm.EquippedCustomizationPartViewModel.AssetId
    arrays[preview]=make(preview,preview_slot,arrays[owner][2].color,arrays[owner][1].GameplayTags.GameplayTags[1].TagName)
    arrays[preview][3].MaterialTarget=copy_target(arrays[owner][3].MaterialTarget)
    refresh()
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
    local found={}; for n,v in pairs(objects) do if n:match("^([^ ]+) ")==classname then found[#found+1]=v end end
    return found
end
function StaticFindObject(s) for _,v in pairs(objects) do if path(v)==s and not v.invalid then return v end end end
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
local runtime={generic_colors=true,log=function(s) logs[#logs+1]=s end}
function runtime:after(k,delay,fn) jobs[k]={fn=fn,delay=delay} end
function runtime:cancel(k) jobs[k]=nil end
local function run(k) local job=assert(jobs[k],k); jobs[k]=nil; job.fn() end
local access=load("customization_probe").new(runtime).access
local fragments=bundle.new(access)
local tint,editor
local function boot()
    tint=load("tint_test").new(runtime,access,"recovery")
    local defaults=load("default_selection").wrap(runtime,access,"selection",tint,tint)
    editor=load("editor_session").wrap(runtime,access,"editor",defaults)
end
local function assert_ok(ok) assert(ok,table.concat(logs,"\n")) end
local function start()
    logs={}; local session=editor.begin_live(); assert_ok(session)
    assert(not jobs["tint:timeout"],"Live drafts must not arm an expiry")
    assert(session.profile.skin_race==race and #session.profile.targets==5)
    assert(#arrays[preview]==3 and files.recovery:match(session.profile.skin_scalar and "^proxy%-v10\n" or "^proxy%-v9\n"))
    fragments.read(arrays[preview],session.profile)
    return session
end
boot()
-- Opening uses one fresh scalar route for its repeated source checks. A
-- native event during donor activation must invalidate that route immediately.
do
    local before=discovery_scans
    local s=tint.begin_live(); assert_ok(s)
    assert(discovery_scans==before+2,"Opening should discover page/aux once, not at every checkpoint")
    assert_ok(tint.restore("opening route test"))
    -- Hook the actual donor activation, preserving its stock behavior.
    local previous=vm.PreviewCustomizationPart
    vm.PreviewCustomizationPart=function(self,p)
        previous(self,p)
        tint.context_changed("PreviewCustomizationPart")
    end
    before=discovery_scans
    s=tint.begin_live(); assert_ok(s)
    assert(discovery_scans==before+2,"Opening event must force full source rediscovery after reusing the initial hint")
    vm.PreviewCustomizationPart=previous
    assert_ok(tint.restore("opening event test"))
    before=discovery_scans
    s=tint.begin_live(); assert_ok(s)
    assert(discovery_scans==before,"Unchanged creator reopening must reacquire its scalar route")
    assert_ok(tint.restore("opening route retirement"))
end
-- Draft-local scalar routes reacquire every object, never cache read results.
do
    local route=tint.bind_selected_context(tint.read_context())
    local before=discovery_scans
    assert(tint.read_selected_context(route).owner==owner)
    assert(discovery_scans==before,"Bound selection should skip global page/aux scans")
    tint.context_changed("UpdateCurrentCustomizationSlotVM")
    assert(tint.read_selected_context(route).owner==owner)
    assert(discovery_scans==before+2,"Notification must force full rediscovery")
    route=tint.bind_selected_context(tint.read_context())
    local current=aux.CurrentCustomizationSlotVM
    aux.CurrentCustomizationSlotVM=nil
    assert(not pcall(tint.read_selected_context,route)); aux.CurrentCustomizationSlotVM=current
    page.inactive=true; assert(not pcall(tint.read_selected_context,route)); page.inactive=false
    local previous_list=stack.WidgetList; stack.WidgetList={page}
    assert(not pcall(tint.read_selected_context,route)); stack.WidgetList=previous_list
    local part=vm.EquippedCustomizationPartViewModel
    vm.EquippedCustomizationPartViewModel=shade
    assert(not pcall(tint.read_selected_context,route)); vm.EquippedCustomizationPartViewModel=part
    aux.invalid=true; assert(not pcall(tint.read_selected_context,route)); aux.invalid=false
    assert(tint.read_selected_context(route).owner==owner)
end
do
    local p=target.new(access).read(arrays[owner][2],bundle.SKIN,owner,race)
    local q={slot=p.slot,mesh=p.mesh,asset=p.asset,parameter=p.parameter,skin_race=p.skin_race}
    local encoded=target.encode_targets(p)
    assert(target.decode_targets(q,encoded) and target.same(p,q))
    for _,bad in ipairs({encoded .. "|",encoded .. "\n",encoded:gsub("=CustomizationPartDefinition:Mesh5","=-"),
        encoded:gsub("|[^|]+$",""),encoded .. "|extra=CustomizationPartDefinition:Mesh6"}) do
        assert(not target.decode_targets(q,bad),"Malformed skin target record accepted")
    end
    assert(target.decode_targets(q,encoded)); q.skin_race="br.Customization.Part.Character.Race.0A"
    assert(not target.same(p,q))
end
-- Read-only compatibility uses the same bundle gate, with no preview writes.
do
    local before=writes
    assert_ok(load("color_compatibility").new(runtime,access).capture())
    assert(table.concat(logs,"\n"):find("CANDIDATE: human skin bundle",1,true) and writes==before)
end
local s=start()
assert(#arrays[preview][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==5,"Installed custom bundle must retain source scalar targets")
assert(#arrays[displayed][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==5)
assert(source_writes==0 and equal(arrays[owner][2].color,original))
local scans_before=discovery_scans
runtime.perf=load("performance_log").new(runtime)
runtime.perf.start()
local stage_order={}
local measure=runtime.perf.measure
runtime.perf.measure=function(label,fn,...)
    if label:match("^update%.") then stage_order[#stage_order+1]=label end
    return measure(label,fn,...)
end
assert_ok(editor.update_live(s,{R=.1,G=.7,B=.2,A=1}))
assert(discovery_scans==scans_before,"First skin update must reuse the opening lookup, with fresh validation")
assert(table.concat(stage_order,",")==table.concat({"update.skin_stop","update.core","update.validate_before",
    "update.bind_creator","update.journal_intent","update.write_color","update.validate_after_write",
    "update.refresh","update.validate_after_refresh","update.journal_complete","update.skin_enable"},","),
    "Stage instrumentation must preserve mutation/journal/validation order")
for _,label in ipairs(stage_order) do
    local row=assert(runtime.perf.window.rows[label],label)
    assert(row.n==1 and row.errors==0,label)
end
assert(runtime.perf.window.rows["tint.resolve_bound"].n==2)
for _,label in ipairs({"source_fragments","source_profile","source_target","source_meshes",
    "source_companions","preview_fragments","preview_color_target","preview_meshes","display_links"}) do
    local row=assert(runtime.perf.window.rows["validate." .. label],label)
    assert(row.n==3 and row.errors==0,"Each checkpoint needs its own validation substages: " .. label)
end
runtime.perf.stop("test"); runtime.perf=nil
scans_before=discovery_scans
assert_ok(editor.update_live(s,{R=.2,G=.6,B=.3,A=1}))
assert(discovery_scans==scans_before,"Next skin update must reacquire its draft route without global discovery")
scans_before=discovery_scans
local idle_writes=writes
for _=1,4 do assert_ok(tint.check_live(s)) end
run("tint:handoff-check")
assert(discovery_scans==scans_before and writes==idle_writes,"Warm idle/handoff checks must reuse validated route without writes")
local captured_reader
scans_before=discovery_scans
assert_ok(tint.update_live_scoped(s,{R=.3,G=.5,B=.2,A=1},function(read)
    assert(not tint.busy,"Consumer must retain normal event handling")
    captured_reader=read
    assert(read().owner==owner)
    return true
end))
assert(discovery_scans==scans_before,"Warm draft and consumer must not repeat global page/VM discovery")
assert(not pcall(captured_reader),"Reader must expire before update returns")
scans_before=discovery_scans
assert_ok(tint.update_live_scoped(s,{R=.2,G=.5,B=.3,A=1},function(read)
    tint.context_changed("UpdateCurrentCustomizationSlotVM")
    assert(read().owner==owner)
    return true
end))
assert(discovery_scans==scans_before+2,"Native event must force full consumer rediscovery")
for _,failure in ipairs({"throw","false","page"}) do
    assert(not tint.update_live_scoped(s,{R=.2,G=.5,B=.3,A=1},function(read)
        captured_reader=read
        if failure=="throw" then error("consumer failure") end
        if failure=="page" then page.inactive=true; read() end
        return false
    end))
    page.inactive=false
    assert(not pcall(captured_reader),"Failed consumer must also revoke reader")
    scans_before=discovery_scans
    assert_ok(editor.update_live(s,{R=.1,G=.6,B=.2,A=1}))
    assert(discovery_scans==scans_before+2,"Failed consumer must retire the draft lookup route")
end
run("tint:handoff-check")
assert_ok(editor.cancel_live("Cancel"))
assert(not tint.pending and not container.IsPreviewing and equal(arrays[displayed][2].color,original))
s=start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); assert(not tint.pending and files.recovery=="")
-- An untouched picker reuses its opening route on its first idle check, then
-- revalidates without broad discovery; native events retire it immediately.
s=start(); scans_before=discovery_scans; idle_writes=writes
assert_ok(tint.check_live(s))
assert(discovery_scans==scans_before)
scans_before=discovery_scans
assert_ok(tint.check_live(s)); assert(discovery_scans==scans_before and writes==idle_writes)
tint.context_changed("UpdateCurrentCustomizationSlotVM")
assert_ok(tint.check_live(s)); assert(discovery_scans==scans_before+2)
scans_before=discovery_scans
assert_ok(tint.check_live(s)); assert(discovery_scans==scans_before)
page.inactive=true
assert(not tint.check_live(s),"Warm idle route must reject an inactive page")
page.inactive=false
assert_ok(tint.check_live(s)); assert(discovery_scans==scans_before+2,"Failed idle check must discard its route")
do
    local get=arrays[owner][2].GetColor
    arrays[owner][2].GetColor=function(self)
        self.GetColor=get
        tint.context_changed("UpdateCurrentCustomizationSlotVM")
        return get(self)
    end
    assert(not tint.check_live(s),"A reentrant event must prevent idle route promotion")
    scans_before=discovery_scans
    assert_ok(tint.check_live(s)); assert(discovery_scans==scans_before+2)
    assert(writes==idle_writes,"Idle validation must never mutate color")
end
assert_ok(editor.cancel_live("idle regression"))
-- Warm routes cannot conceal changes between updates without notifications,
-- or changes caused by a setter. Neither path may refresh the rejected RGB.
for _,boundary in ipairs({"between","setter","idle"}) do
for _,which in ipairs({"page","aux","slot","source","target","mesh","creator"}) do
    s=start()
    assert_ok(editor.update_live(s,{R=.1,G=.6,B=.2,A=1}))
    local old_current=aux.CurrentCustomizationSlotVM
    local old_source=arrays[owner]
    local old_list=stack.WidgetList
    local original_refresh=preview.RefreshCustomization
    local refresh_count=0
    preview.RefreshCustomization=function(self)
        -- Recovery may refresh the restored baseline; only the rejected new
        -- color must never be presented after ownership has changed.
        if equal(arrays[preview][2].color,{R=.2,G=.4,B=.6,A=1}) then refresh_count=refresh_count+1 end
        original_refresh(self)
    end
    local fragment=arrays[preview][2]
    local function mutate()
        fragment.after_set=nil
        if which=="page" then page.inactive=true
        elseif which=="aux" then aux.invalid=true
        elseif which=="slot" then aux.CurrentCustomizationSlotVM=nil
        elseif which=="source" then arrays[owner]=make(owner,source_slot,original)
        elseif which=="target" then arrays[owner][2].MaterialTarget.MaterialParameterName="Changed"
        elseif which=="mesh" then meshes[owner][bundle.MESHES[1]].invalid=true
        else stack.WidgetList={page} end
    end
    if boundary~="setter" then mutate() else fragment.after_set=mutate end
    runtime.perf=load("performance_log").new(runtime); runtime.perf.start()
    if boundary=="idle" then
        local count=writes
        assert(not tint.check_live(s),"Idle check accepted changed " .. which)
        assert(writes==count,"Idle rejection must not write")
    else
        assert(not editor.update_live(s,{R=.2,G=.4,B=.6,A=1}),"Accepted mutation of " .. which)
        assert(runtime.perf.window.rows[boundary=="between" and "update.validate_before" or "update.validate_after_write"].errors==1)
    end
    assert(not runtime.perf.window.rows["update.refresh"] and not runtime.perf.window.rows["update.journal_complete"],
        "Profiler must propagate guard errors before refresh/commit")
    runtime.perf.stop("failure test"); runtime.perf=nil
    assert(refresh_count==0,"Refreshed after changed " .. which)
    page.inactive=false; aux.invalid=false; aux.CurrentCustomizationSlotVM=old_current
    arrays[owner]=old_source; arrays[owner][2].MaterialTarget.MaterialParameterName="Skin Coloration"
    meshes[owner][bundle.MESHES[1]].invalid=false; stack.WidgetList=old_list
    preview.RefreshCustomization=original_refresh
    assert_ok(editor.restore("guard cleanup")); vm:ResetPreviewedPart()
end
end
-- Post-refresh checks also reacquire ownership; a setter-only guard is not enough.
s=start()
do
    local original_refresh=preview.RefreshCustomization
    preview.RefreshCustomization=function(self)
        preview.RefreshCustomization=original_refresh
        original_refresh(self)
        page.inactive=true
    end
    assert(not editor.update_live(s,{R=.2,G=.4,B=.6,A=1}),"Accepted page change during RefreshCustomization")
    page.inactive=false
    assert_ok(editor.restore("post-refresh guard cleanup")); vm:ResetPreviewedPart()
end
-- A native context event during the setter forces full rediscovery rather
-- than treating the transaction route as valid across that notification.
s=start(); assert_ok(editor.update_live(s,{R=.1,G=.6,B=.2,A=1})); scans_before=discovery_scans
arrays[preview][2].after_set=function() arrays[preview][2].after_set=nil; editor.context_changed("UpdateCurrentCustomizationSlotVM") end
assert_ok(editor.update_live(s,{R=.2,G=.4,B=.6,A=1}))
assert(discovery_scans==scans_before+2,"Context event must rediscover once before reusing fresh follow-up lookup")
scans_before=discovery_scans
assert_ok(editor.update_live(s,{R=.1,G=.6,B=.2,A=1}))
assert(discovery_scans==scans_before,"Next update can reuse discovery performed after the busy event")
scans_before=discovery_scans
assert_ok(editor.update_live(s,{R=.2,G=.4,B=.6,A=1}))
assert(discovery_scans==scans_before,"Stable update may rebind after event rediscovery")
assert_ok(editor.cancel_live("event test"))
-- A reentrant event during bound pre-validation rejects before any new write.
s=start(); assert_ok(editor.update_live(s,{R=.1,G=.6,B=.2,A=1}))
do
    local get=arrays[owner][2].GetColor
    arrays[owner][2].GetColor=function(self)
        self.GetColor=get
        tint.context_changed("UpdateCurrentCustomizationSlotVM")
        return get(self)
    end
    runtime.perf=load("performance_log").new(runtime); runtime.perf.start()
    assert(not editor.update_live(s,{R=.2,G=.4,B=.6,A=1}))
    assert(not runtime.perf.window.rows["update.write_color"] and not runtime.perf.window.rows["update.journal_intent"],
        "Context change during pre-validation must reject before journal/write")
    runtime.perf.stop("pre-validation event"); runtime.perf=nil
    assert_ok(editor.restore("reentrant validation cleanup")); vm:ResetPreviewedPart()
end
s=start(); editor.context_changed("page closed"); assert(not tint.pending and files.recovery=="")
s=start(); local recovery=files.recovery; jobs={}; boot(); editor.start(); run("tint:recovery")
assert(not tint.pending and files.recovery=="" and source_writes==0)
-- Both original five-mesh stock donors and the new parent variant are valid.
donor_mode="five-mesh"; s=start(); assert_ok(editor.cancel_live("five-mesh donor")); donor_mode=nil
-- Stale idle stock data and an active stock hover are not custom installations.
for _,active in ipairs({false,true}) do
    arrays[preview]=make(preview,preview_slot,donor); parent_scalar(arrays[preview]); proxy_part=shade.AssetId
    container.IsPreviewing=active; display.ClonedFromCharacter=active and data_actor or actor; refresh()
    s=start(); assert_ok(editor.cancel_live("stock hover/idle"))
end
-- Apply/source restore also retain all companions; a cancelled second draft
-- preserves the already-applied RGB. Native saves are never called.
s=start(); local custom={R=.2,G=.3,B=.8,A=1}
assert_ok(editor.update_live(s,custom)); assert_ok(editor.apply_live(s))
assert(editor.applied and files.editor:match("^editor%-v4\n"))
assert(equal(arrays[owner][2].color,custom)); fragments.read(arrays[owner],editor.applied.profile)
run("editor:watch")
editor.context_changed("page closed"); assert(editor.applied)
s=start(); assert_ok(editor.cancel_live("second draft")); assert(equal(arrays[owner][2].color,custom))
local editor_record=files.editor
jobs={}; boot(); editor.start(); assert(editor.applied); run("editor:recovery")
assert(not editor.applied and files.editor=="" and equal(arrays[owner][2].color,original))
-- Every target is checked in source, preview and display, not only mesh[1].
for _,instance in ipairs({owner,preview,displayed}) do
    for _,mesh in ipairs(bundle.MESHES) do
        s=start(); local old=meshes[instance][mesh]; meshes[instance][mesh]=nil
        assert(not tint.check_live(s),"Missing skin mesh must invalidate preview")
        meshes[instance][mesh]=old; assert_ok(editor.restore("mesh test"))
    end
end
-- Companion tampering is a refusal, never a repair by writing scalar/tags.
for _,index in ipairs({1,3}) do
    s=start(); local f=arrays[preview][index]
    if index==1 then f.GameplayTags.GameplayTags[1].TagName="br.Customization.Part.Character.Race.0A" else f.Value=0 end
    local before=writes
    assert(not tint.check_live(s) and not editor.restore("companion changed") and writes==before and tint.pending)
    if index==1 then f.GameplayTags.GameplayTags[1].TagName=race else f.Value=1 end
    assert_ok(editor.restore("repair fixture only"))
end
-- Refuse Apply when source companions have changed; do not patch them back.
do
    s=start(); local f=arrays[owner][3]; f.Value=0
    local before=source_writes
    assert(not editor.apply_live(s) and source_writes==before)
    f.Value=1; assert_ok(editor.restore("restore fixture companion"))
end
for _,mode in ipairs({"before","after","wrong-race","wrong-parent","color-parent","scalar-zero","scalar-material"}) do
    donor_mode=mode; local before=writes
    assert(not editor.begin_live() and writes==before and not tint.pending)
    assert(not container.IsPreviewing); donor_mode=nil
end
-- Match the live failure boundary: source passes, stock donor is activated,
-- then its color or scalar target fails. Diagnostics must not reach SetColor.
for _,case in ipairs({
    {"short-color","Skin Coloration","meshes=5 expected=5 | materials=1 expected=3"},
    {"empty-scalar","Enable Tinting","meshes=5 expected=5 | materials=0 expected=3"},
    {"extra-mesh","Skin Coloration","meshes=6 expected=5 | materials=3 expected=3"},
}) do
    donor_mode=case[1]; logs={}; local before=writes
    assert(not editor.begin_live() and not tint.pending and writes==before)
    assert(files.recovery=="" and not container.IsPreviewing and equal(arrays[displayed][2].color,original))
    local output=table.concat(logs,"\n")
    for _,expected in ipairs({"SKIN DONOR | ACTIVATE | source=CustomizationPartDefinition:CPD_H_SkinTone_Human_2B0 | donor=CustomizationPartDefinition:CPD_H_SkinTone_Human_2B1",
        "SKIN PROXY CHECK | phase=stock-preview", "actual=CustomizationPartDefinition:CPD_H_SkinTone_Human_2B1",
        "SKIN TARGET | REFUSED | Unsupported skin target layout | expected_parameter=" .. case[2],
        "SKIN TARGET | COUNTS | " .. case[3], "SKIN TARGET | MESH | index=5 | actual=" .. bundle.MESHES[5]}) do
        assert(output:find(expected,1,true),expected .. "\n" .. output)
    end
    if case[1]=="short-color" then assert(output:find("MATERIAL | index=1 | actual=MI_Head | expected=MI_Head",1,true)) end
    if case[1]=="extra-mesh" then assert(output:find("index=6 | actual=br.Test.Extra.Mesh | expected=<none>",1,true)) end
    donor_mode=nil
end
do
    local output={}
    local diagnostic=bundle.new(access,function(line) output[#output+1]=line end)
    diagnostic.skin_target(arrays[owner][2],"Skin Coloration")
    assert(#output==0,"Healthy targets must not emit detailed diagnostics")
    local malformed=make(owner,source_slot,original)[2]
    local names=malformed.MaterialTarget.MaterialSlotNames
    for i=1,20 do names[i]="bad\n" .. string.rep("x",400) end
    local ok,err=pcall(diagnostic.skin_target,malformed,"Skin Coloration")
    assert(not ok and err=="Unsupported skin target layout")
    assert(#output==24 and output[#output]=="SKIN TARGET | MATERIAL | omitted=4")
    for _,line in ipairs(output) do assert(#line<512 and not line:find("[\r\n\t]")) end
    local broken_logger=bundle.new(access,function() error("logging failed") end)
    ok,err=pcall(broken_logger.skin_target,malformed,"Skin Coloration")
    assert(not ok and err=="Unsupported skin target layout","Logging errors must preserve the original refusal")
    names[1]=setmetatable({},{__index=function() error("unreadable native text") end})
    output={}; ok,err=pcall(diagnostic.skin_target,malformed,"Skin Coloration")
    assert(not ok and err=="Unsupported skin target layout")
    assert(table.concat(output,"\n"):find("actual=<unavailable>",1,true))
end
for _,mode in ipairs({"scalar","throw","stock-scalar"}) do
    install_mode=mode
    assert(not editor.begin_live() and tint.pending and files.recovery~="")
    install_mode=nil
    vm:ResetPreviewedPart(); assert_ok(editor.restore("native reset after ambiguous install"))
end
for _,mode in ipairs({"source-alias","stock-alias","stock-scalar","throw","set-throws"}) do
    clone_mode=mode; local before=source_writes
    assert(not editor.begin_live() and source_writes==before)
    assert(not tint.pending and not container.IsPreviewing)
    clone_mode=nil
end
-- Recovery before installation resets stock without SetColor. Exercise both
-- a verified donor and a prepared detached clone whose setter was interrupted.
for _,mode in ipairs({"throw","set-throws"}) do
    clone_mode=mode; reset_failure=true
    assert(not editor.begin_live() and tint.pending)
    assert(tint.pending.phase==(mode=="throw" and "handoff" or "prepared"))
    clone_mode=nil; reset_failure=nil
    local before=writes; jobs={}; boot(); editor.start(); run("tint:recovery")
    assert(not tint.pending and files.recovery=="" and writes==before and not container.IsPreviewing)
end
-- A different scalar layout cannot replace the layout captured at open.
do
    donor_mode="after"; reset_failure=true; local before=writes
    assert(not editor.begin_live() and tint.pending and tint.pending.blue.pending_baseline)
    donor_mode=nil; reset_failure=nil
    jobs={}; boot(); editor.start(); run("tint:recovery")
    assert(not tint.pending and writes==before and files.recovery=="" and not container.IsPreviewing)
end
do
    s=start()
    local values=arrays[owner]; local saved=copy_target(values[3].MaterialTarget)
    parent_scalar(values); local before=writes
    assert(not tint.check_live(s) and writes==before)
    values[3].MaterialTarget=saved
    assert_ok(editor.restore("source layout repaired"))
end
for _,instance in ipairs({preview,displayed}) do
    s=start(); local saved=copy_target(arrays[instance][3].MaterialTarget)
    parent_scalar(arrays[instance])
    if instance==preview then
        assert(not tint.check_live(s))
        local before=writes; assert(not editor.restore("stock target on installed clone") and writes==before)
    else
        run("tint:handoff-check")
        assert(not tint.pending,"Owned display verification must reject parent scalar layout")
    end
    if tint.pending then arrays[instance][3].MaterialTarget=saved; assert_ok(editor.restore("repair fixture")) end
end
-- Fail before writes for extra/invalid fragments or non-human assets.
do
    local saved=arrays[owner]; local before=writes
    arrays[owner]={saved[1],saved[2],saved[3],saved[2]}
    assert(not editor.begin_live() and writes==before); arrays[owner]=saved
    local old=stock.AssetId; stock.AssetId=asset("CPD_Alien_SkinTone_2B0")
    assert(not editor.begin_live() and writes==before); stock.AssetId=old
end
do
    local baseline=arrays[owner]
    for _,change in ipairs({
        function(v) v[1],v[2]=v[2],v[1] end,
        function(v) v[1].GameplayTags.GameplayTags[2]=tag(race) end,
        function(v) v[3].Value=0 end,
        function(v) v[3].MaterialTarget.MaterialSlotNames[2]="MI_Wrong" end,
        function(v) v[2].MaterialTarget.SlotNameTagsToApply.GameplayTags[5]=tag(bundle.MESHES[1]) end,
        function(v) v[3].invalid=true end,
    }) do
        arrays[owner]=make(owner,source_slot,original); change(arrays[owner])
        local before=writes
        assert(not editor.begin_live() and writes==before and not tint.pending)
    end
    arrays[owner]=baseline
    palette={stock,other_family}; local before=writes
    assert(not editor.begin_live() and writes==before and not tint.pending)
    palette={stock,other_family,shade}
end
-- Skin Tone 5: parent-tag source, same-family donor, full lifecycle and journals.
local parent_recovery,parent_editor
do
    race="br.Customization.Part.Character.Race.0B"
    stock.AssetId=asset("CPD_H_SkinTone_Human_0B1")
    shade.AssetId=asset("CPD_H_SkinTone_Human_0B0")
    arrays[owner]=make(owner,source_slot,original); parent_scalar(arrays[owner])
    vm:ResetPreviewedPart()
    -- Normal picker uses the real face-enable module, not the timed command.
    do
        local scalar=0
        local mc=obj("Class","/Script/Engine.MeshComponent")
        local dc=obj("Class","/Script/Engine.MaterialInstanceDynamic")
        local parent=obj("MaterialInstanceConstant","/Game/Game/Characters/Humanoid/_Heads/Human/HF00/Materials/MI_HF00_Race0B.MI_HF00_Race0B",
            {ScalarParameterValues={{ParameterInfo={Name="Enable Tinting",Association=2,Index=-1},ParameterValue=0}}})
        local mid=obj("MaterialInstanceDynamic",path(display) .. ".Face.MID",{Parent=parent,GetClass=function() return dc end})
        function mid:K2_GetScalarParameterValue() return scalar end
        function mid:SetScalarParameterValue(_,v) scalar=v end
        local face=obj("SkeletalMeshComponent",path(display) .. ".br.Face.Mesh_0",
            {GetOwner=function() return display end,GetMaterialIndex=function() return 0 end,GetMaterial=function() return mid end})
        function display:K2_GetComponentsByClass(c) assert(c==mc); return {face} end
        runtime.tint=editor
        runtime.skin_enable=load("skin_enable_probe").new(runtime,access)
        local draft=start(); assert(scalar==1 and runtime.skin_enable.pending.mode=="preview")
        assert(not jobs["skin-enable:timeout"],"normal preview has no elapsed-time expiry")
        local before_discovery=discovery_scans
        runtime.perf=load("performance_log").new(runtime); runtime.perf.start()
        assert_ok(editor.update_live(draft,custom)); assert(scalar==1)
        assert(discovery_scans==before_discovery,"Human face enabling must reuse opening and synchronous validated routes")
        assert(runtime.perf.window.rows["skin.resolve_bound"].n==1)
        assert(not runtime.perf.window.rows["skin.resolve_context"],"No global face context discovery during RGB update")
        before_discovery=discovery_scans
        assert_ok(editor.update_live(draft,{R=.1,G=.6,B=.2,A=1})); assert(scalar==1)
        assert(discovery_scans==before_discovery,"Warm Human draft and face enable must avoid global discovery")
        assert(runtime.perf.window.rows["skin.resolve_bound"].n==2)
        runtime.perf.stop("human scoped test"); runtime.perf=nil
        assert_ok(editor.cancel_live("auto Cancel")); assert(scalar==0)
        draft=start(); assert(not jobs["tint:timeout"]); assert_ok(tint.restore("external backend restore")); run("skin-enable:watch")
        assert(scalar==0 and not runtime.skin_enable.pending)
        draft=start(); assert_ok(editor.update_live(draft,custom)); assert_ok(editor.apply_live(draft))
        assert(scalar==0 and not runtime.skin_enable.pending)
        assert(#arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==5)
        run("editor:watch"); assert(scalar==0,"applied source must not need direct MID writes")
        editor.context_changed("page closed"); run("editor:watch"); assert(editor.applied)
        -- Radial may remove the hover instance/data while idle source display
        -- stays live. This must neither block enabling nor undo source RGB.
        local get_preview=owner.GetPreviewCustomizationInstance
        owner.GetPreviewCustomizationInstance=function() return nil end
        container.ProxyDataStorage=nil
        assert_ok(runtime.skin_enable.stop("radial boundary"))
        editor.context_changed("page closed"); run("editor:watch")
        assert(scalar==0 and editor.applied and equal(arrays[owner][2].color,custom))
        -- A longer display gap exhausts only rendering retries, not Apply.
        assert_ok(runtime.skin_enable.stop("display gap")); container.ProxyCharacter=nil
        for _=1,10 do run("editor:watch") end
        assert(editor.applied and editor.applied.render_failures==0 and equal(arrays[owner][2].color,custom))
        container.ProxyCharacter=display
        editor.context_changed("UpdateCurrentCustomizationSlotVM"); run("editor:watch")
        assert(scalar==0 and editor.applied.render_failures==0)
        owner.GetPreviewCustomizationInstance=get_preview; container.ProxyDataStorage=data_actor
        -- Stock hover wins, then the owned applied source resumes on hover end.
        container.IsPreviewing=true; display.ClonedFromCharacter=data_actor
        run("editor:watch"); assert(scalar==0 and not runtime.skin_enable.pending)
        vm:ResetPreviewedPart(); run("editor:watch"); assert(scalar==0)
        draft=start(); assert_ok(editor.update_live(draft,{R=.8,G=.1,B=.2,A=1}))
        assert_ok(editor.cancel_live("discard edited draft"))
        assert(scalar==0 and equal(arrays[owner][2].color,custom))
        assert_ok(editor.restore("auto Restore")); assert(scalar==0 and not editor.applied)
        assert(equal(arrays[owner][2].color,original))
        -- Failed enable rolls preview back without touching the source.
        local setter=mid.SetScalarParameterValue
        function mid:SetScalarParameterValue(_,v) scalar=v; if v==1 then error("injected enable failure") end end
        assert(not editor.begin_live() and scalar==0 and not tint.pending)
        mid.SetScalarParameterValue=setter
        draft=start()
        function mid:SetScalarParameterValue(_,v)
            scalar=v
            if v==1 and not container.IsPreviewing then error("injected Apply enable failure") end
        end
        assert_ok(editor.apply_live(draft)); assert(editor.applied and scalar==0)
        assert_ok(editor.restore("source target Restore"))
        assert(equal(arrays[owner][2].color,original))
        mid.SetScalarParameterValue=setter
        runtime.skin_enable=nil; runtime.tint=nil
    end
    local before=writes
    assert_ok(load("color_compatibility").new(runtime,access).capture()); assert(writes==before)
    s=start(); assert(s.profile.skin_scalar=="outfit")
    assert(#arrays[preview][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    assert(#arrays[displayed][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    assert_ok(editor.update_live(s,custom)); run("tint:handoff-check")
    assert_ok(editor.cancel_live("parent Cancel")); assert(equal(arrays[displayed][2].color,original))
    s=start(); assert(not jobs["tint:timeout"]); assert_ok(editor.cancel_live("picker Cancel")); assert(not tint.pending and files.recovery=="")
    s=start(); parent_recovery=files.recovery; jobs={}; boot(); editor.start(); run("tint:recovery")
    assert(not tint.pending and files.recovery=="" and equal(arrays[displayed][2].color,original))
    -- A five-mesh donor must not replace the source's parent-tag scalar layout.
    donor_mode="five-mesh"; s=start(); donor_mode=nil
    assert(s.profile.skin_scalar=="outfit" and #arrays[preview][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    assert_ok(editor.update_live(s,custom)); assert_ok(editor.apply_live(s))
    assert(editor.applied and files.editor:match("^editor%-v6\n")); parent_editor=files.editor
    assert(equal(arrays[owner][2].color,custom)); run("editor:watch")
    s=start(); assert_ok(editor.cancel_live("parent second draft")); assert(equal(arrays[owner][2].color,custom))
    assert_ok(editor.restore("parent Restore")); assert(equal(arrays[owner][2].color,original))
    assert(#arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    -- A leaf write can mutate then throw. Recovery must repair target plus RGB.
    do
        local scalar_fragment=arrays[owner][3]
        local target=scalar_fragment.MaterialTarget
        local tags=target.SlotNameTagsToApply.GameplayTags
        local fail=true
        target.SlotNameTagsToApply=setmetatable({}, {
            __index=function(_,k) assert(k=="GameplayTags"); return tags end,
            __newindex=function(_,k,v)
                assert(k=="GameplayTags"); tags=v
                if fail and #v==5 then
                    target.MaterialParameterName=""; target.MaterialSlotNames={}
                    error("partial source target failure")
                end
            end,
        })
        s=start(); assert_ok(editor.update_live(s,custom))
        assert(not editor.apply_live(s) and not editor.applied and not editor.blocked)
        assert(target.MaterialParameterName=="Enable Tinting" and #target.MaterialSlotNames==3 and #tags==1)
        assert(equal(arrays[owner][2].color,original))
        fail=false
        scalar_fragment.MaterialTarget.SlotNameTagsToApply={GameplayTags=tags}
    end
    -- Already-saved custom skin starts with five targets; Restore must keep them
    -- and restore that saved RGB, not an assumed stock RGB/Outfit target.
    do
        arrays[owner][3].MaterialTarget=material("Enable Tinting")
        arrays[owner][2].color=copy(custom); vm:ResetPreviewedPart()
        s=start(); assert_ok(editor.update_live(s,{R=.8,G=.1,B=.2,A=1}))
        assert_ok(editor.cancel_live("saved custom Cancel"))
        assert(equal(arrays[owner][2].color,custom))
        s=start(); assert_ok(editor.update_live(s,{R=.8,G=.1,B=.2,A=1})); assert_ok(editor.apply_live(s))
        assert(not editor.applied.skin_target and files.editor:match("^editor%-v4"))
        assert_ok(editor.restore("saved custom Restore"))
        assert(equal(arrays[owner][2].color,custom) and #arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==5)
        arrays[owner][2].color=copy(original); parent_scalar(arrays[owner]); vm:ResetPreviewedPart()
    end
    -- A later native selection owns its replacement bundle, even after Apply.
    s=start(); assert_ok(editor.apply_live(s))
    do
        local saved=arrays[owner]
        arrays[owner]=make(owner,source_slot,original); parent_scalar(arrays[owner])
        arrays[owner][2].name=arrays[owner][2].name .. "_Replacement"
        run("editor:watch")
        assert(not editor.applied and not editor.blocked)
        assert(#arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
        arrays[owner]=saved; arrays[owner][2].color=copy(original); parent_scalar(arrays[owner]); vm:ResetPreviewedPart()
    end
    s=start(); assert_ok(editor.update_live(s,custom)); assert_ok(editor.apply_live(s))
    jobs={}; boot(); editor.start(); run("editor:recovery")
    assert(not editor.applied and files.editor=="" and equal(arrays[owner][2].color,original))
    -- Preserve the existing clothing-change cancellation behavior.
    s=start(); assert_ok(editor.apply_live(s))
    local getters={}
    for _,instance in ipairs({owner,preview,displayed}) do
        local arms=meshes[instance][bundle.MESHES[1]]
        getters[instance]=arms.GetCustomizationPartPrimaryAssetId
        arms.GetCustomizationPartPrimaryAssetId=function() return asset("ChangedArms") end
    end
    run("editor:watch")
    assert(not editor.applied and equal(arrays[owner][2].color,original))
    for instance,get in pairs(getters) do meshes[instance][bundle.MESHES[1]].GetCustomizationPartPrimaryAssetId=get end
    -- Layout swaps on owned/source data refuse; no scalar or tag repairs.
    for _,instance in ipairs({owner,preview,displayed}) do
        s=start(); local saved=arrays[instance][3].MaterialTarget
        arrays[instance][3].MaterialTarget=material("Enable Tinting")
        if instance==displayed then
            run("tint:handoff-check"); assert(not tint.pending)
        else
            local count=writes; assert(not tint.check_live(s) and writes==count)
            arrays[instance][3].MaterialTarget=saved; assert_ok(editor.restore("parent layout repaired"))
        end
    end
    local baseline=arrays[owner]
    for _,change in ipairs({
        function(v) v[3].MaterialTarget.SlotNameTagsToApply.GameplayTags[1]=tag("br.Customization.Slot.Character") end,
        function(v) v[3].Value=0 end,
        function(v) v[3].MaterialTarget.MaterialSlotNames[1]="MI_Wrong" end,
        function(v) v[2].MaterialTarget.SlotNameTagsToApply.GameplayTags={tag("br.Customization.Slot.Character.Outfit")} end,
    }) do
        arrays[owner]=make(owner,source_slot,original); parent_scalar(arrays[owner]); change(arrays[owner])
        local count=writes; assert(not editor.begin_live() and writes==count and not tint.pending)
    end
    arrays[owner]=baseline; vm:ResetPreviewedPart()
    -- Independent target experiment: real source fragment, no CP or MID writes.
    do
        runtime.tint=editor
        local tp=load("skin_target_probe").new(runtime,access,"target-journal")
        runtime.skin_target=tp
        local scalar=arrays[owner][3]
        local target_writes=0
        local target=scalar.MaterialTarget
        local stored_tags=target.SlotNameTagsToApply.GameplayTags
        local corrupt_write,fail_restore=false,false
        target.SlotNameTagsToApply=setmetatable({}, {
            __index=function(_,k) assert(k=="GameplayTags"); return stored_tags end,
            __newindex=function(_,k,v)
                assert(k=="GameplayTags")
                if fail_restore then error("restore unavailable") end
                target_writes=target_writes+1; stored_tags=v
                if corrupt_write and #v==5 then
                    target.MaterialParameterName=""
                    target.MaterialSlotNames={}
                    error("partial leaf failure")
                end
            end,
        })
        function scalar:SetMaterialTarget() error("whole-struct setter must not be used") end
        local before_rgb=writes
        assert_ok(tp.begin()); assert(tp.pending and files["target-journal"]:match("^skin%-target%-v1"))
        assert(#scalar.MaterialTarget.SlotNameTagsToApply.GameplayTags==5 and writes==before_rgb)
        assert(not editor.begin_live(),"normal picker must not overlap target ownership")
        run("target:timeout"); assert(not tp.pending and files["target-journal"]=="")
        assert(#scalar.MaterialTarget.SlotNameTagsToApply.GameplayTags==1 and writes==before_rgb)
        assert_ok(tp.begin()); assert_ok(tp.stop("manual")); assert(target_writes==4)
        -- Same-process recovery reacquires exact source and original layout.
        assert_ok(tp.begin()); runtime:cancel("target:timeout")
        local recovered=load("skin_target_probe").new(runtime,access,"target-journal")
        runtime.skin_target=recovered; recovered.start(); assert(recovered.pending)
        run("target:recovery"); assert(not recovered.pending and files["target-journal"]=="")
        tp=recovered
        corrupt_write=true
        assert(not tp.begin() and not tp.pending and not tp.blocked)
        assert(#scalar.MaterialTarget.SlotNameTagsToApply.GameplayTags==1 and writes==before_rgb)
        assert(target.MaterialParameterName=="Enable Tinting" and #target.MaterialSlotNames==3)
        corrupt_write=false
        -- A restore error retains exact recovery ownership until retry succeeds.
        assert_ok(tp.begin())
        fail_restore=true
        assert(not tp.stop("failed restore") and tp.pending and tp.blocked and files["target-journal"]~="")
        fail_restore=false; assert_ok(tp.stop("retry"))
        -- Recover the old whole-struct failure with an empty target parameter.
        assert_ok(tp.begin()); target.MaterialParameterName=""; target.MaterialSlotNames={}
        local damaged=load("skin_target_probe").new(runtime,access,"target-journal")
        damaged.start(); run("target:recovery")
        assert(not damaged.pending and not damaged.blocked and target.MaterialParameterName=="Enable Tinting")
        tp=damaged; runtime.skin_target=tp
        -- Save mode observes page/creator transitions without reapply or restore.
        assert_ok(tp.begin(true))
        local armed_writes=target_writes
        tp.context_changed("page closed"); tp.context_changed("creator closed")
        assert(tp.pending and tp.pending.save_test and target_writes==armed_writes)
        assert_ok(tp.check()); assert(target_writes==armed_writes and writes==before_rgb)
        run("target:timeout"); assert(not tp.pending and #stored_tags==1)
        -- A reopened source may reconstruct the stock target. Check is read-only;
        -- stopping the old experiment must not write to the replacement scalar.
        assert_ok(tp.begin(true))
        local original_bundle=arrays[owner]
        arrays[owner]=make(owner,source_slot,original); parent_scalar(arrays[owner])
        local replacement=arrays[owner][3]
        local replacement_name=replacement.name
        replacement.name=replacement.name .. "_Reopened"
        assert_ok(tp.check())
        assert(#replacement.MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
        assert_ok(tp.stop("after snapshot"))
        assert(#replacement.MaterialTarget.SlotNameTagsToApply.GameplayTags==1 and writes==before_rgb)
        replacement.name=replacement_name
        arrays[owner]=original_bundle
        -- Simulate a fresh editor restoring its original native layout.
        stored_tags={tag("br.Customization.Slot.Character.Outfit")}
        assert_ok(tp.begin()); tp.context_changed("page closed")
        assert(not tp.pending and #stored_tags==1,"normal probe still cancels on transitions")
        files["target-journal"]="skin-target-v1\nforeign\nslot\nscalar\n"
        local invalid=load("skin_target_probe").new(runtime,access,"target-journal"); invalid.start()
        assert(invalid.blocked and not invalid.pending and not invalid.begin())
        files["target-journal"]=""
        runtime.skin_target=nil; runtime.tint=nil
    end
end
-- No human-name/race allowlist: the same verified skin bundle on another race.
do
    local old_race,old_stock,old_shade,old_bundle=race,stock.AssetId,shade.AssetId,arrays[owner]
    race="br.Customization.Part.Character.Race.0C"
    stock.AssetId=asset("CPD_Skin_Alien_Test01"); shade.AssetId=asset("CPD_Skin_Alien_Test02")
    arrays[owner]=make(owner,source_slot,original); parent_scalar(arrays[owner]); vm:ResetPreviewedPart()
    s=start(); assert_ok(editor.update_live(s,custom)); assert_ok(editor.apply_live(s))
    assert(editor.applied.profile.skin_race==race and editor.applied.skin_target)
    assert(#arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==5)
    assert_ok(editor.restore("other race Restore"))
    assert(#arrays[owner][3].MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    race,stock.AssetId,shade.AssetId,arrays[owner]=old_race,old_stock,old_shade,old_bundle
    vm:ResetPreviewedPart()
end
for _,broken in ipairs({parent_recovery:gsub("outfit\n$","bad\n"),parent_recovery:gsub("outfit\n$",""),
    parent_recovery:gsub("^proxy%-v10","proxy-v9"),parent_recovery .. "extra\n"}) do
    files.recovery=broken; boot(); tint.start(); assert(tint.blocked and not tint.pending)
end
files.recovery=""
for _,broken in ipairs({parent_editor:gsub("\noutfit\n","\nbad\n"),parent_editor:gsub("\noutfit\n","\n"),
    parent_editor:gsub("^editor%-v6","editor-v4"),parent_editor .. "extra\n"}) do
    files.editor=broken; boot(); editor.start(); assert(editor.blocked and not editor.applied)
end
files.editor=""
for _,broken in ipairs({recovery:gsub("^proxy%-v9","proxy-v8"),recovery:gsub("br.Customization.Part.Character.Race.2B","bad",1),recovery .. "extra\n"}) do
    files.recovery=broken; boot(); tint.start(); assert(tint.blocked and not tint.pending)
end
files.recovery=""
for _,broken in ipairs({editor_record:gsub("^editor%-v4","editor-v3"),editor_record:gsub("br.Customization.Part.Character.Race.2B","bad",1),editor_record .. "extra\n"}) do
    files.editor=broken; boot(); editor.start(); assert(editor.blocked and not editor.applied)
end
io.open,os.rename,os.remove=old_open,old_rename,old_remove
print("Skin: real preview/Apply/Restore, companions, five meshes, donor isolation, lifetime and recovery passed")
