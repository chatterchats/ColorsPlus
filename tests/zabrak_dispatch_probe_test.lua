local scripts=assert(arg[1])
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
        assert(files.journal and files.journal:match("^zabrak%-dispatch%-v3"),"Setter before durable intent")
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
    runtime.skin_target=nil; runtime.picker=nil; runtime.skin_enable=nil; runtime.eye_preview=nil; runtime.stock_call_trace=nil
    runtime.tint={read_context=function() return {owner=owner,source_slot=slot,part={AssetId=part},profile=profile} end}
end
function owner:GetSlotInstance(t) assert(t.TagName==SKIN); return slot end
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
    assert(files.journal and files.journal:match("^zabrak%-dispatch%-v3"),"Order setter before durable intent")
    assert(files.journal:find("_pending\n"),"Order setter without durable in-flight phase")
    values={}; for i,f in ipairs(v) do values[i]=f end
    if clone_setter then values=clone_all(values) end
    writes=writes+1
    if on_install then on_install() end
end
local function boot()
    local router=load("skin_target_probe").new(runtime,a,"journal")
    runtime.skin_target=router; router.attach(); return router,router.dispatch
end
local function current(role)
    for _,f in ipairs(values) do
        if f:GetClass().n=="Class /Script/BitReactorCore.CustomizationFragmentInstance" .. role then return f end
    end
end
local function restored(router)
    assert(not router.pending and not router.blocked and files.journal=="")
    for i,role in ipairs({"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}) do
        assert(values[i]==current(role),"Original role order lost")
    end
    assert(equal(current("MaterialColor").color,stock))
    assert(#current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags==1)
    assert(current("MaterialScalar").Value==1 and forbidden_reads==0)
end

reset(); local router,probe=boot()
commands.colors_zabrak(nil,{"capture"}); run("zabrak:command")
assert(writes==0 and refreshes==0 and not files.journal and contains("CAPTURE COMPLETE"))
commands.colors_zabrak(nil,{"start"}); assert(writes==0); run("zabrak:command")
assert(router.pending==probe.pending and probe.pending.phase=="owned" and probe.pending.order=="1,4,2,3")
assert(equal(current("MaterialColor").color,orange) and not baseline[2].valid)
assert(files.journal:find(current("MaterialColor").n,1,true) and contains("HANDOFF VERIFIED"))
assert(#current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags==6 and refreshes==1)
assert(contains("RETURN | test SetFragmentInstances") and contains("RETURN | test SetColor orange"))
local picker=load("live_picker").new(runtime,runtime.tint,{}, {})
assert(not picker.open(),"CP overlaps source dispatch")
assert(not load("skin_enable_probe").new(runtime,a).start())
assert(not load("eye_preview").new(runtime,a,"eye-journal").begin())
assert(jobs["zabrak:timeout"].ms==60000)
local count=writes; router.context_changed("page closed"); router.context_changed("ResetPreviewedPart")
run("zabrak:context"); assert(router.pending and writes==count and refreshes==1)
assert(not router.begin())
local active=current("MaterialColor")
run("zabrak:timeout"); restored(router)
assert(not active.valid and refreshes==2 and rgb_writes==2 and generation==2)
-- Refresh capture reads the stock profile but slot owns the new canonical IDs.
assert(probe.begin()); assert(router.stop("manual")); restored(router)
assert(probe.begin()); commands.colors_target(nil,{"stop"}); run("target:command"); restored(router)
assert(probe.begin()); router.context_changed("creator closed"); router.context_changed("ResetPreviewedPart")
assert(router.pending); run("zabrak:exit"); restored(router); assert(not jobs["zabrak:context"])
-- A stale deadline cannot close a later test.
assert(probe.begin()); local stale=jobs["zabrak:timeout"].cb
assert(router.stop("manual")); assert(probe.begin()); stale(); assert(router.pending)
assert(router.stop("manual")); restored(router)
-- Exact owned recovery may perform its OWN synchronous restoration handoff.
assert(probe.begin()); runtime:cancel("zabrak:timeout")
router,probe=boot(); router.start(); assert(jobs["zabrak:recovery"])
run("zabrak:recovery"); restored(router)
-- Identity-preserving setters are also supported.
reset(); clone_setter=false; router,probe=boot(); assert(probe.begin())
assert(values[2]==baseline[4]); assert(router.stop("manual")); restored(router)
-- Partial known-owned RGB failure rolls back; a failed restore remains retryable.
reset(); router,probe=boot()
on_rgb=function(c) if equal(c,orange) then error("failed after RGB write") end end
assert(not probe.begin()); restored(router)
on_rgb=nil; fail_restore=true
on_rgb=function(c) if equal(c,orange) then error("failed after RGB write") end end
assert(not probe.begin() and router.pending and router.blocked and files.journal~="")
on_rgb=nil; fail_restore=false; assert(router.stop("retry")); restored(router)
assert(probe.begin()); fail_refresh=true
assert(not router.stop("refresh failure") and router.pending and router.blocked)
fail_refresh=false; assert(router.stop("retry")); restored(router)
-- Malformed copies must not get target/RGB writes or later inferred recovery.
local corruptions={
    function() values[2],values[3]=values[3],values[2] end,
    function() table.remove(values) end,
    function() values[4]=values[3] end,
    function() current("MaterialColor").GetOwningCustomizationInstance=function() return obj("CustomizationInstance Foreign") end end,
    function() current("MaterialColor").GetOwningCustomizationSlot=function() return obj("CustomizationFragmentInstanceSlot Foreign") end end,
    function() current("MaterialColor").GetClass=function() return obj("Class /Script/BitReactorCore.Unknown") end end,
    function() current("MaterialColor").color.R=.1 end,
    function() current("MaterialColor").GetColor=function() error("returned getter failure") end end,
    function() current("MaterialColor").MaterialTarget.MaterialParameterName="Foreign" end,
    function() current("MaterialColor").n="CustomizationFragmentInstanceMaterialColor Foreign" end,
    function() current("MaterialScalar").Value=0 end,
    function() current("MaterialScalar").MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=meshes[1]}} end,
    function() current("GameplayTags").GameplayTags.GameplayTags[1].TagName="Foreign" end,
    function() current("MaterialSwap").MaterialTarget.MaterialSlotNames={"Foreign"} end,
    function() source_part={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="Other"} end,
    function() error("setter partial return failure") end,
}
for _,corrupt in ipairs(corruptions) do
    reset(); router,probe=boot(); on_install=corrupt
    assert(not probe.begin() and rgb_writes==0 and router.pending and router.blocked)
    assert(probe.pending.phase=="reorder_pending" and probe.hold and files.journal:find("\nreorder_pending\n",1,true))
    count=writes; assert(not router.stop("held") and writes==count)
    local evidence=files.journal
    router,probe=boot(); router.start()
    assert(probe.hold and not jobs["zabrak:recovery"] and files.journal==evidence and writes==count)
end
-- Commit failure BEFORE native array mutation and AFTER returned-copy evidence.
for _,index in ipairs({1,2,3}) do
    reset(); router,probe=boot(); fail_at=index
    assert(not probe.begin() and rgb_writes==0 and router.blocked)
    assert(writes==(index==3 and 1 or 0))
    count=writes; assert(not router.stop("held") and writes==count)
end
-- Unknown replacement during RGB or Refresh is never adopted, never overwritten.
for _,stage in ipairs({"rgb","refresh","later"}) do
    reset(); router,probe=boot()
    local replace=function() values=clone_all(values) end
    if stage=="rgb" then on_rgb=replace elseif stage=="refresh" then on_refresh=replace end
    if stage=="later" then
        assert(probe.begin()); replace(); count=writes
        router.context_changed("page closed"); run("zabrak:context")
    else assert(not probe.begin()); count=writes end
    assert(router.pending and router.blocked and files.journal~="")
    assert(not router.stop("foreign") and writes==count)
    assert(not files.journal:find(current("MaterialColor").n,1,true),"Adopted replacement outside own order return")
end
-- Restoration failures retain in-flight evidence and never claim success.
reset(); router,probe=boot(); assert(probe.begin())
on_install=function() current("MaterialColor").color.R=.2 end
assert(not router.stop("bad restore") and probe.hold and probe.pending.phase=="restore_order_pending")
count=writes; assert(not router.stop("held") and writes==count and files.journal~="")
-- Restoration handoff promotion / final-clear disk failures also retain intent.
for _,offset in ipairs({2,3}) do
    reset(); router,probe=boot(); assert(probe.begin()); fail_at=disk_writes+offset
    assert(not router.stop("disk failure") and probe.hold and router.pending and router.blocked)
    assert(files.journal~="" and not contains("RESTORED"))
    count=writes; assert(not router.stop("held") and writes==count)
end
-- Retired race/owner cannot be treated as successful restoration.
reset(); router,probe=boot(); assert(probe.begin()); source_part={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="Other"}
count=writes; assert(not router.stop("race replaced") and writes==count and router.pending)
assert(not contains("RESTORED"))
-- Refuse foreign inputs/overlap before mutation.
reset(); router,probe=boot(); runtime.picker={active={}}; assert(not probe.begin() and writes==0); runtime.picker=nil
runtime.tint.applied={}; assert(not probe.begin() and writes==0); runtime.tint.applied=nil
baseline[4].MaterialTarget.MaterialSlotNames={"MI_Body"}
assert(not probe.begin() and writes==0 and not files.journal)
-- Legacy v2/v65 inspection, malformed and untrusted journals never execute.
for _,data in ipairs({"zabrak-dispatch-v1\nold\n","zabrak-dispatch-v2\nold\n",
    "zabrak-rebuild-inspection-v1\nold\n","zabrak-dispatch-v3\nreturn os.execute('anything')\n"}) do
    reset(); files.journal=data; router,probe=boot(); router.start()
    assert(router.blocked and not jobs["zabrak:recovery"] and writes==0 and files.journal==data)
    assert(not probe.begin() and not probe.capture())
end
-- Teardown must not strand the experiment.
local owned=load("hook_registry").start("ZabrakDispatchTestRuntime")
owned.skin_target={dispatch={pending={}}}
assert(not pcall(owned.teardown,owned) and owned.alive)
owned.skin_target.dispatch.pending=nil; owned:teardown(); _G.ZabrakDispatchTestRuntime=nil
assert(forbidden_reads==0)
io.open,os.rename,os.remove=original.open,original.rename,original.remove
print("Zabrak dispatch: synchronous cloned/unchanged handoffs, durable v3 recovery, restoration clones, malformed copies, disk failures, later replacement refusal, lifetime and pointer traps passed")
