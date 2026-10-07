local scripts=assert(arg[1])
local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
helpers.share_modules(scripts)
local function load(n) return assert(loadfile(scripts .. "/" .. n .. ".lua"))() end
local objects,files,jobs,commands,logs={},{},{},{},{}
local function obj(n,t)
    t=t or {}; t.n=n; t.valid=true; objects[n:match("^[^ ]+ (.+)$")]=t; return t
end
local a={unwrap=function(v) return v end,live=function(v) return v and v.valid end,name=function(v) return v.n end,
    prop=function(v,k) return v[k] end,text=tostring,values=function(v) assert(type(v)=="table"); return v end}
function StaticFindObject(p) return objects[p] end
function FindAllOf() return {} end
function FName(s) return s end
function RegisterConsoleCommandHandler() end
local original={open=io.open,rename=os.rename,remove=os.remove}
local fail_journal=false
local disk_writes,fail_at=0,nil
io.open=function(p,mode)
    if mode=="r" and not files[p] then return nil,"missing",2 end
    if mode=="w" then disk_writes=disk_writes+1; if fail_journal or disk_writes==fail_at then return nil,"write refused" end; files[p]="" end
    return {read=function() return files[p] end,write=function(self,s) files[p]=files[p] .. s; return self end,
        flush=function() return true end,close=function() return true end}
end
os.rename=function(from,to) assert(files[from] and not files[to]); files[to],files[from]=files[from],nil; return true end
os.remove=function(p) assert(files[p]); files[p]=nil; return true end
local runtime={log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,cb) jobs[k]={ms=ms,cb=cb} end
function runtime:cancel(k) jobs[k]=nil end
function runtime:console(n,cb) commands[n]=cb end
local function run(k) local j=assert(jobs[k],k); jobs[k]=nil; j.cb() end
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local OUTFIT="br.Customization.Slot.Character.Outfit"
local meshes={"br.Customization.Slot.Character.Outfit.Arms.Mesh","br.Customization.Slot.Character.Outfit.Legs.Mesh",
    "br.Customization.Slot.Character.Outfit.Boots.Mesh","br.Customization.Slot.Character.Outfit.Torso.Mesh",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh","br.Customization.Slot.Character.Horns.Mesh"}
local stock={R=.417885,G=.184475,B=.093059,A=1}
local orange={R=1,G=.21586050011389926,B=.014443843596092545,A=1}
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function equal(x,y) return x.R==y.R and x.G==y.G and x.B==y.B and x.A==y.A end
local owner=obj("CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance")
local slot=obj("CustomizationFragmentInstanceSlot " .. owner.n:match("^[^ ]+ (.+)$") .. ".Slot_1")
local part={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_H_SkinTone_Hum_Zabrak_1A1"}
local forbidden_reads=0
local function contains(text)
    for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end
    return false
end
local values,baseline,profile
local writes,refreshes,rgb_writes=0,0,0
local on_install,on_rgb,on_refresh,fail_refresh,fail_restore
local clone_setter=true
local generation=0
local source_part=part
local mesh_slots={}
local function target(parameter,tags)
    local array={}; for i,s in ipairs(tags) do array[i]={TagName=s} end
    return {MaterialParameterName=parameter,MaterialSlotNames={"MI_Head","MI_Body"},SlotNameTagsToApply={GameplayTags=array}}
end
local codec=load("color_bundle")
local function reset()
    files={}; jobs={}; commands={}; logs={}; writes=0; refreshes=0; rgb_writes=0
    disk_writes=0; fail_at=nil; clone_setter=true; generation=0; on_refresh=nil
    on_install=nil; on_rgb=nil; fail_refresh=false; fail_restore=false; fail_journal=false
    source_part=part; slot.valid=true; owner.valid=true; forbidden_reads=0
    values={}
    for i,suffix in ipairs({"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}) do
        local class=obj("Class /Script/BitReactorCore.CustomizationFragmentInstance" .. suffix)
        values[i]=obj("CustomizationFragmentInstance" .. suffix .. " " .. owner.n:match("^[^ ]+ (.+)$") .. ".Fragment_" .. i,
            {GetClass=function() return class end,GetOwningCustomizationInstance=function() return owner end,GetOwningCustomizationSlot=function() return slot end})
    end
    values[1].GameplayTags={GameplayTags={{TagName="br.Customization.Part.Character.Race.1A"}}}
    values[2].MaterialTarget=target("Skin Coloration",meshes); values[2].color=copy(stock)
    local color_fragment=values[2]
    function color_fragment:GetColor() return copy(self.color) end
    function color_fragment:SetColor(c)
        assert(files.journal and files.journal:match("^zabrak%-picker%-source%-v1"),"Setter before durable intent")
        assert(files.journal:find("\nowned\n",1,true) and files.journal:find(self.n,1,true),"RGB before promoted IDs")
        if fail_restore and equal(c,stock) then error("RGB restore unavailable") end
        self.color=copy(c); writes=writes+1; rgb_writes=rgb_writes+1
        if on_rgb then on_rgb(c) end
    end
    values[3].MaterialTarget=target("Enable Tinting",{OUTFIT}); values[3].Value=1
    values[4].MaterialTarget=target("Skin Coloration",meshes)
    values[4].MaterialTarget.MaterialSlotNames={"MI_Head"}
    setmetatable(values[4],{__index=function(_,k)
        if k=="ReplacementMaterial" or k=="ReplacementMaterialSoft" then
            forbidden_reads=forbidden_reads+1; error("Forbidden material pointer read")
        end
        error("Unexpected swap member: " .. k)
    end})
    baseline={values[1],values[2],values[3],values[4]}
    local _,_,description=codec.new(a).read(values,{slot=SKIN})
    profile={slot=SKIN,bundle=description}
    runtime.picker=nil; runtime.skin_enable=nil
    runtime.tint={read_context=function() return {owner=owner,source_slot=slot,part={AssetId=part},profile=profile} end}
end
function owner:GetSlotInstance(t) if t.TagName==SKIN then return slot end; return mesh_slots[t.TagName] end
function owner:RefreshCustomization()
    refreshes=refreshes+1
    if fail_refresh then error("refresh failed") end
    if on_refresh then on_refresh() end
end
function slot:GetCustomizationPartPrimaryAssetId() return source_part end
function slot:GetFragmentInstances() return values end
local function deep(t)
    if type(t)~="table" then return t end
    local out={}; for k,v in pairs(t) do out[k]=deep(v) end
    return setmetatable(out,getmetatable(t))
end
local function clone_all(v)
    generation=generation+1
    local out={}
    for i,f in ipairs(v) do
        local n=deep(f); n.n=f.n:gsub("_Copy_%d+$","") .. "_Copy_" .. generation
        obj(n.n,n); f.valid=false; out[i]=n
    end
    return out
end
function slot:SetFragmentInstances(v)
    assert(files.journal and files.journal:match("^zabrak%-picker%-source%-v1"),"Order setter before durable intent")
    assert(files.journal:find("_pending\n"),"Order setter without durable in-flight phase")
    values={}; for i,f in ipairs(v) do values[i]=f end
    if clone_setter then values=clone_all(values) end
    writes=writes+1
    if on_install then on_install() end
end

local function current(role)
    for _,f in ipairs(values) do
        if f:GetClass().n=="Class /Script/BitReactorCore.CustomizationFragmentInstance" .. role then return f end
    end
end
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local page=obj("WBP_Customization_ItemPage_C " .. host .. ".WBP_Customization_ItemPage_C_1828",
    {IsActivated=function(self) return not self.inactive end})
local parent=obj("Panel /Game/Test.CreatorParent")
local master=obj("WBP_CustomCharacter_Master_C " .. host .. ".WBP_CustomCharacter_Master_C_1800",
    {IsActivated=function(self) return not self.inactive end})
local stack=obj("BitReactorActivatableWidgetStack " .. host .. ".GameLayer_Stack",
    {GetParent=function() return parent end,GetActiveWidget=function(self) return self.top end})
local vm_reads=0
local vm=obj("BitReactorCustomizationSlotViewModel /Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.BitReactorCustomizationSlotViewModel_1",
    {SlotTag={TagName=SKIN},EquippedCustomizationPartViewModel={AssetId=part},
        GetFragments=function() vm_reads=vm_reads+1; return values end})
for i,tag in ipairs(meshes) do
    mesh_slots[tag]=obj("CustomizationFragmentInstanceSlot " .. owner.n:match("^[^ ]+ (.+)$") .. ".Mesh_" .. i,
        {GetSlotNameTag=function() return {TagName=tag} end,
            GetCustomizationPartPrimaryAssetId=function() return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="Mesh_" .. i} end})
end
local base,worker,delegated,selected,context_reads,bound_reads
local function boot()
    stack.WidgetList={master,page}; stack.top=page; page.inactive=false; selected=true
    delegated=0; context_reads=0; bound_reads=0
    vm.EquippedCustomizationPartViewModel={valid=true,AssetId=source_part}
    base={}
    local function context()
        assert(not page.inactive)
        local p={slot=selected and SKIN or "br.Customization.Slot.Character.Outfit.Torso.Color.Secondary",
            parameter="Skin Coloration",mesh=meshes[1],asset="CustomizationPartDefinition:Mesh_1",targets={}}
        local f,_,_,_,desc=load("color_fragments").new(a).read(values,{slot=SKIN})
        p.bundle=desc
        for i,tag in ipairs(meshes) do p.targets[i]={mesh=tag,asset="CustomizationPartDefinition:Mesh_" .. i} end
        return {owner=owner,source_slot=slot,slot=vm,part=vm.EquippedCustomizationPartViewModel,
            fragment=f,page=page.n,materials="MI_Head,MI_Body",original=copy(f:GetColor()),profile=p}
    end
    function base.read_context() context_reads=context_reads+1; return context() end
    function base.bind_selected_context(c) return {page=c.page,vm=c.slot.n,owner=c.owner.n} end
    function base.read_selected_context(route)
        bound_reads=bound_reads+1
        local c=context()
        assert(c.page==route.page and c.slot.n==route.vm and c.owner.n==route.owner)
        return c
    end
    function base.begin_live() delegated=delegated+1; return {normal=true} end
    function base.update_live() delegated=delegated+1; return true end
    function base.check_live() delegated=delegated+1; return true end
    function base.apply_live() delegated=delegated+1; return true end
    function base.cancel_live() return true end
    function base.restore() return true end
    function base.context_changed() end
    function base.start() end
    function base.invalidate_context_lookup() end
    function base.pending() end; function base.applied() end
    function base.blocked() end; function base.busy() end
    -- The zone's regular backend is faked: these tests cover the route and
    -- the zone's choice between the two.
    worker=load("color_zone").new(runtime,a,function(leaf)
        assert(leaf=="zabrak_picker_recovery.txt",leaf); return "journal"
    end,{regular=base})
    runtime.tint=worker
    runtime.skin_enable={stop=function() return true end,start=function() error("No MID workaround permitted") end}
    return worker
end
local violet={R=.351,G=.052,B=.745,A=1}
local green={R=.052,G=.630,B=.163,A=1}
local function original_source()
    assert(equal(current("MaterialColor").color,stock))
    assert(#current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    assert(values[2]==current("MaterialColor") and values[4]==current("MaterialSwap") and files.journal=="")
    assert(not worker.pending and not worker.applied and not worker.source_owned and not worker.blocked)
    assert(forbidden_reads==0)
end
local function errors()
    local out={}; for _,line in ipairs(logs) do
        if line:find("FAILED",1,true) or line:find("REFUSED",1,true) or line:find("ERROR",1,true) then out[#out+1]=line end
    end
    return table.concat(out,"\n")
end
reset(); boot(); selected=false
assert(worker.begin_live().normal and delegated==1 and writes==0)
-- Same Zabrak asset family, but no swap: route the verified three-fragment
-- source to the regular backend, without starting a source transaction.
reset(); values[4]=nil; boot()
local regular=worker.begin_live()
assert(regular.normal and delegated==1 and writes==0 and not files.journal)
assert(contains("backend=regular | fragments=3 | swaps=0"))
assert(worker.update_live(regular,orange) and worker.check_live(regular)
    and worker.apply_live(regular) and delegated==4)
assert(worker.cancel_live("regular Cancel") and worker.restore("regular Restore"))
-- Do not silently hand unsupported swap layouts to the generic backend.
reset(); values[3],values[4]=values[4],values[3]; boot()
assert(not worker.begin_live() and writes==0 and delegated==0)
-- Invalid/missing bundle evidence must refuse before any source mutation.
reset(); boot()
local read_context=base.read_context
base.read_context=function() local c=read_context(); c.profile.bundle=nil; return c end
assert(not worker.begin_live() and writes==0 and delegated==0)
reset(); boot()
local opened=worker.begin_live()
local draft=assert(opened,errors()); assert(draft.live and worker.pending==draft and draft.preview_policy=="skin")
assert(draft.perf_target.backend=="source-swap"
    and draft.perf_target.part=="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_1A1")
assert(not contains("CALL TRACE |"),"Normal opening must not emit per-call diagnostics")
assert(worker.update_live(draft,orange)); assert(equal(current("MaterialColor").color,orange))
logs={}
runtime.perf=load("performance_log").new(runtime); runtime.perf.start()
local before_context,before_bound=context_reads,bound_reads
local updated,validated=worker.update_live(draft,violet)
assert(context_reads==before_context and bound_reads==before_bound+1,"Repeated Zabrak update must use the bound selected route")
assert(updated and validated==true); assert(equal(current("MaterialColor").color,violet))
for _,label in ipairs({"validate","core","source_before","journal","source_after_journal",
    "write_color","source_after_write","refresh","source_after_refresh"}) do
    local row=assert(runtime.perf.window.rows["zupdate." .. label],label)
    assert(row.n==1 and row.errors==0,label)
end
runtime.perf.stop("test"); runtime.perf=nil
assert(not contains("CALL TRACE |"),"Expired trace must stop verbose update logging")
assert(worker.check_live(draft) and generation==1 and worker.source_owned)
-- Events arriving during a native write must invalidate reuse as well.
on_rgb=function() worker.context_changed("UpdateCurrentCustomizationSlotVM") end
assert(worker.update_live(draft,green)); on_rgb=nil
before_context=context_reads
assert(worker.update_live(draft,violet))
assert(context_reads==before_context+1,"Busy native notification must force next-check discovery")
assert(worker.cancel_live("Cancel")); original_source(); assert(generation==2 and not draft.live)
-- Drafts remain live through three minutes of idle source/creator checks.
draft=assert(worker.begin_live()); assert(not jobs["zabrak-cp:draft-timeout"])
assert(worker.update_live(draft,green) and not jobs["zabrak-cp:draft-timeout"])
for _=1,720 do
    assert(jobs["zabrak-cp:watch"].ms==250); run("zabrak-cp:watch")
    assert(worker.pending==draft and draft.live and worker.check_live(draft))
end
assert(worker.cancel_live("Cancel after extended draft")); original_source()
-- Apply/radial/stock hover perform NO reapplication or MID writes.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,violet))
assert(worker.apply_live(draft) and not worker.pending and worker.applied and not draft.live)
local count=writes; local refresh_count=refreshes
stack.WidgetList={master}; stack.top=master; page.inactive=true
worker.context_changed("page closed"); run("zabrak-cp:context"); run("zabrak-cp:watch")
assert(worker.applied and writes==count and refreshes==refresh_count)
stack.WidgetList={master,page}; stack.top=page; page.inactive=false
worker.context_changed("PreviewCustomizationPart"); run("zabrak-cp:context")
worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context")
assert(equal(current("MaterialColor").color,violet) and writes==count)
-- Health reads stay bounded independently of the duration of an Apply.
for i=1,80 do run("zabrak-cp:watch") end
assert(worker.applied and not worker.blocked and writes==count)
-- Editing an applied color then cancelling retains the previous Apply.
draft=assert(worker.begin_live()); assert(equal(draft.test_color,violet))
assert(worker.update_live(draft,green)); assert(worker.cancel_live("Cancel edit"))
assert(equal(current("MaterialColor").color,violet) and worker.applied)
draft=assert(worker.begin_live()); assert(worker.update_live(draft,green))
assert(not jobs["zabrak-cp:draft-timeout"]); assert(worker.cancel_live("Cancel edit")); assert(equal(current("MaterialColor").color,violet) and worker.applied)
draft=assert(worker.begin_live()); assert(worker.update_live(draft,green)); assert(worker.apply_live(draft))
assert(equal(worker.applied.chosen,green)); assert(worker.restore("Restore all")); original_source()
-- Creator exit is deferred and wins over ordinary navigation.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange)); assert(worker.apply_live(draft))
worker.context_changed("creator closed",master.n); worker.context_changed("ResetPreviewedPart")
assert(worker.applied); run("zabrak-cp:exit"); original_source()
-- Draft slot changes close/restore rather than accidentally Apply another zone.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
selected=false; worker.context_changed("UpdateCurrentCustomizationSlotVM"); run("zabrak-cp:context"); original_source()
selected=true
-- A lookup hint cannot hide selection drift even without a native event.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
selected=false
assert(not worker.check_live(draft),"Bound route must recheck the selected slot")
assert(not worker.update_live(draft,violet)); original_source(); selected=true
-- Reentrant invalidation during a bound read must not reinstall that route.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
do
    local read=base.read_selected_context
    base.read_selected_context=function(route)
        local c=read(route); worker.context_changed("ResetPreviewedPart"); return c
    end
    assert(not worker.check_live(draft) and not draft.selected_context)
    base.read_selected_context=read
    assert(worker.cancel_live("validation interrupted")); original_source()
end
-- Opening over a stock hover emits ResetPreviewedPart. Keep only an unchanged
-- live draft; no source writes/refresh or elapsed-time expiry for that reset.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
assert(not jobs["zabrak-cp:draft-timeout"])
local reset_writes,reset_refreshes,reset_disk=writes,refreshes,disk_writes
local context_before,vm_before=context_reads,vm_reads
worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context")
assert(worker.pending==draft and draft.live and equal(current("MaterialColor").color,orange))
assert(writes==reset_writes and refreshes==reset_refreshes and disk_writes==reset_disk)
assert(context_reads==context_before+1 and not jobs["zabrak-cp:draft-timeout"])
assert(vm_reads==vm_before+1,"Reset must validate source membership once, not twice")
assert(contains("HOVER RESET | kept verified draft"))
-- A stale reset callback must not read, cancel or refresh a replacement draft.
worker.context_changed("ResetPreviewedPart"); local stale_reset=jobs["zabrak-cp:context"].cb
assert(worker.cancel_live("reopen")); draft=assert(worker.begin_live())
context_before=context_reads; reset_writes=writes
stale_reset(); assert(worker.pending==draft and context_reads==context_before and writes==reset_writes)
-- Reset is not a general exemption: slot/page/creator transitions still stop.
selected=false; worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context"); original_source()
selected=true; draft=assert(worker.begin_live()); page.inactive=true
worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context"); original_source()
page.inactive=false; draft=assert(worker.begin_live()); stack.WidgetList={}; stack.top=nil
worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context"); original_source()
stack.WidgetList={master,page}; stack.top=page
-- Other event types keep their conservative cancellation behavior.
for _,event in ipairs({"PreviewCustomizationPart","EquipCustomizationPart","ResetToDefault","page closed"}) do
    draft=assert(worker.begin_live())
    worker.context_changed(event); run("zabrak-cp:context"); original_source()
end
-- Even on Reset, source replacement retires ownership without writing over it.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
values=clone_all(values); current("MaterialColor").color=copy(stock)
reset_writes=writes
worker.context_changed("ResetPreviewedPart"); run("zabrak-cp:context")
assert(not worker.pending and not worker.source_owned and files.journal=="" and writes==reset_writes)
reset(); boot()
-- Native stock choices retire exact old ownership, leaving replacements alone.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange)); assert(worker.apply_live(draft))
values=clone_all(values); current("MaterialColor").color=copy(stock)
count=writes; worker.context_changed("EquipCustomizationPart"); run("zabrak-cp:context")
assert(not worker.applied and not worker.source_owned and files.journal=="" and writes==count)
-- An external RGB edit on still-installed IDs wins as well; no restore setter.
reset(); boot(); draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange)); assert(worker.apply_live(draft))
current("MaterialColor").color={R=.12,G=.34,B=.56,A=1}
count=writes; run("zabrak-cp:watch")
assert(not worker.applied and not worker.source_owned and files.journal=="" and writes==count)
assert(current("MaterialColor").color.R==.12)
-- Save snapshot: cleanup doesn't mutate the serialized copy; saved corrected
-- order/scalar and RGB are treated as the NEXT editor visit's baseline.
reset(); boot(); draft=assert(worker.begin_live()); assert(worker.update_live(draft,violet)); assert(worker.apply_live(draft))
local saved=deep(values)
assert(worker.restore("exit")); original_source()
values=clone_all(saved); boot()
draft=assert(worker.begin_live()); assert(equal(draft.test_color,violet)); assert(worker.update_live(draft,green))
assert(worker.cancel_live("saved baseline")); assert(equal(current("MaterialColor").color,violet))
assert(values[2]==current("MaterialSwap") and #current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags==6)
-- Owned in-process recovery restores; interrupted handoffs don't adopt guesses.
reset(); boot(); draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange)); assert(worker.apply_live(draft))
boot(); worker.start(); assert(worker.source_owned); run("zabrak-cp:recovery"); original_source()
reset(); boot(); on_install=function() current("MaterialColor").color.R=.123 end
assert(not worker.begin_live() and worker.blocked and worker.source_owned)
count=writes; assert(not worker.restore("held") and writes==count)
local journal=files.journal; boot(); worker.start()
assert(worker.blocked and not jobs["zabrak-cp:recovery"] and files.journal==journal)
-- Journal failure prevents RGB writes; later RGB/Refresh replacements aren't adopted.
reset(); boot(); fail_at=3
assert(not worker.begin_live() and worker.blocked and rgb_writes==0 and writes==1)
-- Unsupported read-only source layouts don't strand a draft or block others.
reset(); boot(); current("MaterialSwap").MaterialTarget.MaterialSlotNames={"MI_Body"}
assert(not worker.begin_live() and not worker.pending and not worker.blocked and writes==0 and not files.journal)
selected=false; assert(worker.begin_live().normal)
reset(); boot(); files["journal.previous"]="retained interrupted journal"
worker.start()
assert(worker.blocked and not worker.begin_live() and writes==0 and files["journal.previous"]~="")
for _,phase in ipairs({"rgb","refresh"}) do
    reset(); boot(); draft=assert(worker.begin_live())
    local ids=files.journal
    if phase=="rgb" then on_rgb=function() values=clone_all(values) end
    else on_refresh=function() values=clone_all(values) end end
    assert(not worker.update_live(draft,violet) and worker.blocked and worker.source_owned)
    assert(not files.journal:find(current("MaterialColor").n,1,true),"Adopted unexpected late replacement")
end
reset(); boot()
-- Actual picker coordinator uses this backend's live/Apply/Cancel contract.
local ui={rgb={R=255,G=128,B=32},open=function() end,close=function() end}
-- Define closures after the local binding exists.
ui.set_rgb=function(rgb) ui.rgb=rgb end
ui.show=function() end
ui.read=function() return ui.rgb end
local picker=load("live_picker").new(runtime,worker,ui,load("rgb_input"))
runtime.picker=picker
assert(picker.open())
ui.rgb={R=160,G=64,B=224}
assert(picker.apply() and not picker.active and worker.applied and not worker.pending)
local applied_rgb=copy(current("MaterialColor").color)
assert(picker.open()); assert(worker.update_live(worker.pending,green))
assert(picker.close("Cancel") and equal(current("MaterialColor").color,applied_rgb))
assert(worker.restore("Restore")); original_source()
runtime.picker=nil
reset(); boot()
-- Reload is explicitly held while the source correction is active.
draft=assert(worker.begin_live()); assert(worker.update_live(draft,green)); assert(worker.apply_live(draft))
local owned=load("hook_registry").start("ZabrakPickerRuntimeTest"); owned.tint=worker
assert(not pcall(owned.teardown,owned) and owned.alive)
assert(worker.restore("reload preparation")); owned:teardown(); _G.ZabrakPickerRuntimeTest=nil
-- Captured Hum_Zabrak_1B0 starts with swap,tags,color,scalar, including an
-- already expanded tint target. Accept that exact ordering without choosing
-- another swatch, and preserve it through Cancel/Restore and journal recovery.
local function swap_first(expanded,clones)
    reset()
    clone_setter=clones
    source_part={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_H_SkinTone_Hum_Zabrak_1B0"}
    current("GameplayTags").GameplayTags.GameplayTags={{TagName="br.Customization.Part.Character.Race.1B"}}
    current("MaterialSwap").MaterialTarget.MaterialSlotNames={"MI_Head0"}
    if expanded then current("MaterialScalar").MaterialTarget=target("Enable Tinting",meshes) end
    values={baseline[4],baseline[1],baseline[2],baseline[3]}
    boot()
end
local function restored_swap_first(expanded)
    assert(values[1]==current("MaterialSwap") and values[2]==current("GameplayTags")
        and values[3]==current("MaterialColor") and values[4]==current("MaterialScalar"),"Original swap-first order lost")
    assert(equal(current("MaterialColor").color,stock))
    assert(#current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags==(expanded and 6 or 1))
    assert(source_part.PrimaryAssetName=="CPD_H_SkinTone_Hum_Zabrak_1B0" and forbidden_reads==0)
    assert(current("MaterialSwap").MaterialTarget.MaterialSlotNames[1]=="MI_Head0","Swap material slot was renamed")
    assert(files.journal=="" and not worker.pending and not worker.applied and not worker.blocked)
end
for _,expanded in ipairs({false,true}) do
    for _,clones in ipairs({false,true}) do
        swap_first(expanded,clones)
        draft=assert(worker.begin_live(),errors())
        assert(delegated==0 and values[2]==current("MaterialSwap"))
        assert(files.journal:find("\n4,1,2,3\n",1,true),"Baseline order must be durable")
        assert(worker.update_live(draft,orange) and worker.check_live(draft))
        assert(worker.cancel_live("swap-first Cancel")); restored_swap_first(expanded)
        assert(contains("RESTORE ORDER BEGIN | MaterialSwap,GameplayTags,MaterialColor,MaterialScalar"))
        draft=assert(worker.begin_live()); assert(worker.update_live(draft,violet) and worker.apply_live(draft))
        stack.WidgetList={master}; stack.top=master; page.inactive=true
        worker.context_changed("page closed"); run("zabrak-cp:context"); run("zabrak-cp:watch")
        assert(worker.applied and equal(current("MaterialColor").color,violet))
        stack.WidgetList={master,page}; stack.top=page; page.inactive=false
        draft=assert(worker.begin_live()); assert(worker.update_live(draft,green))
        assert(worker.cancel_live("Cancel applied edit") and equal(current("MaterialColor").color,violet))
        assert(worker.restore("Restore swap-first")); restored_swap_first(expanded)
        draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
        boot(); worker.start(); run("zabrak-cp:recovery"); restored_swap_first(expanded)
    end
end
-- Do not broaden to arbitrary permutations or trust malformed baseline order
-- strings in a journal. A failed restore setter remains held, never adopted.
for _,bad in ipairs({"4,1,2,2","4,1,3,2","4,1,2,3,4","4,1,2,03"}) do
    swap_first(true,true); draft=assert(worker.begin_live())
    files.journal=files.journal:gsub("\n4,1,2,3\n","\n" .. bad .. "\n")
    count=writes; boot(); worker.start()
    assert(worker.blocked and not jobs["zabrak-cp:recovery"] and writes==count)
end
swap_first(true,true)
values={values[1],values[2],values[4],values[3]} -- swap,tags,scalar,color
assert(not worker.begin_live() and writes==0 and not files.journal)
swap_first(true,true); draft=assert(worker.begin_live()); assert(worker.update_live(draft,orange))
on_install=function() error("restore array setter failed after cloning") end
assert(not worker.cancel_live("interrupted swap-first restore") and worker.blocked)
assert(files.journal:find("\nrestore_order_pending\n",1,true))
local retained=files.journal; count=writes
boot(); worker.start()
assert(worker.blocked and not jobs["zabrak-cp:recovery"] and files.journal==retained and writes==count)
-- Refused swap targeting is logged without accessing either material pointer
-- or starting a native/journal mutation.
reset(); values[4].MaterialTarget.MaterialSlotNames={"MI_Head0"}; boot()
assert(not worker.begin_live() and writes==0 and not files.journal and forbidden_reads==0,
    "MI_Head0 must not be accepted for another Zabrak asset")
swap_first(true,true)
values[1].MaterialTarget.MaterialSlotNames={"MI_Head","MI_Body"}
assert(not worker.begin_live() and writes==0 and not files.journal and forbidden_reads==0)
assert(contains("SWAP TARGET | part=CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_1B0 | order=4,1,2,3"))
assert(contains("|MI_Head,MI_Body | expected=Skin Coloration|"))
assert(contains("Unsupported recovery swap target"))
-- In-game (hub) editor: the hub menu hosts the editor; leaving keeps Apply.
local tabs=obj("WBP_CentralUITabs_C " .. host .. ".WBP_CentralUITabs_C_7",{IsActivated=function(self) return not self.inactive end})
local tab_stack=obj("BitReactorActivatableWidgetTabStack " .. host .. ".WBP_CentralUITabs_C_7.WidgetTree_8.TabStack",
    {GetActiveWidget=function(self) return self.top end})
local hub_master=obj("WBP_Customization_MasterPage_C " .. host .. ".WBP_CentralUITabs_C_7.WidgetTree_8.WBP_Customization_MasterPage_C_9",
    {IsActivated=function(self) return not self.inactive end})
local armory=obj("WBP_TabbedMenu_Armory_C " .. host .. ".WBP_CentralUITabs_C_7.WidgetTree_8.WBP_TabbedMenu_Armory_C_10")
tabs.TabStack=tab_stack
local function hub_boot()
    reset(); boot(); stack.WidgetList={tabs,page}; stack.top=page; tabs.inactive=true; tab_stack.top=hub_master
end
-- A main-menu character never opens through the hub menu.
hub_boot(); assert(not worker.begin_live() and writes==0 and not worker.pending)
assert(contains("other editor"))
local MAIN=owner.n:match("^[^ ]+ (.+)$")
local HUB="/Game/Game/Maps/Hub/HUB_Root.HUB_Root:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance"
local function rehome(o)
    local class,path=o.n:match("^([^ ]+) (.+)$")
    objects[path]=nil; path=HUB .. path:sub(#MAIN+1); o.n=class .. " " .. path; objects[path]=o
end
rehome(owner); rehome(slot); for _,m in pairs(mesh_slots) do rehome(m) end
local function hub_kept(message)
    assert(not worker.applied and not worker.pending and not worker.source_owned,message)
    assert(equal(current("MaterialColor").color,orange),message .. ": applied color kept")
    assert(files.journal=="" and contains("KEPT | hub editor"),message .. ": journal cleared")
end
local function hub_apply()
    hub_boot(); draft=assert(worker.begin_live(),errors()); assert(worker.update_live(draft,orange))
    assert(worker.apply_live(draft))
end
-- Back to the master page is the same visit; leaving keeps the color.
hub_apply()
stack.WidgetList={tabs}; stack.top=tabs; tabs.inactive=nil; page.inactive=true
worker.context_changed("page closed"); run("zabrak-cp:context"); run("zabrak-cp:watch")
assert(worker.applied and equal(current("MaterialColor").color,orange))
stack.WidgetList={tabs,page}; stack.top=page; tabs.inactive=true; page.inactive=false
local count=writes
worker.context_changed("creator closed"); run("zabrak-cp:exit")
hub_kept("hub exit"); assert(writes==count,"Keeping writes nothing")
-- Another hub tab ends the visit through the watch.
hub_apply(); tab_stack.top=armory; run("zabrak-cp:watch"); hub_kept("hub tab change")
-- An open draft over an Apply returns to the applied color, then keeps it.
hub_apply(); draft=assert(worker.begin_live()); assert(worker.update_live(draft,violet))
worker.context_changed("creator closed"); run("zabrak-cp:exit"); hub_kept("draft over Apply")
-- A draft without Apply still restores the original source.
hub_boot(); draft=assert(worker.begin_live()); assert(worker.update_live(draft,violet))
worker.context_changed("creator closed"); run("zabrak-cp:exit"); original_source()
io.open,os.rename,os.remove=original.open,original.rename,original.remove
print("Zabrak CP (hub): exit/tab change keep Apply, drafts return to Apply, unapplied drafts restore, cross-editor refusal passed")
print("Zabrak CP: arbitrary RGB, rebuilt Start/Restore, extended idle drafts, Apply/reopen/Cancel, radial/hover no repaint, creator exit, saved-layout baseline, recovery/retirement, disk failure and reload holds passed")
