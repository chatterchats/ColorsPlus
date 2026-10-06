-- Real editor-session + Default-selection modules; engine and hover backend fake.
-- luajit tests/editor_session_test.lua src/Colors+Probe/Scripts
local scripts=assert(arg[1])
local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
helpers.share_modules(scripts)
local zones=assert(loadfile(scripts .. "/color_zone.lua"))()
local old_open=io.open
local old_rename,old_remove=os.rename,os.remove
local files,objects,jobs,logs={},{},{},{}
local COLOR="CustomizationPartDefinition:CPD_H_Outfit_Color_"
local ACCENT="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"
local MESH="br.Customization.Slot.Character.Outfit.Torso.Mesh"
local HORNS="br.Customization.Slot.Character.Horns.Mesh"
local horns_present=false
local OWNER="CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance"
local PREFIX=OWNER:match("^[^ ]+ (.+)$")
local VMOUT="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local red={R=.25,G=.0075,B=.0075,A=1}
local white={R=.8,G=.8,B=.8,A=1}
local orange={R=1,G=.2,B=.01,A=1}
local violet={R=.35,G=.05,B=.75,A=1}
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function equal(a,b) return a.R==b.R and a.G==b.G and a.B==b.B and a.A==b.A end
local on_thread=true
local fail_write,fail_preview_restore,fail_set,fail_refresh,fail_display,fail_default,fail_clear
local writes,refreshes=0,0
local function obj(n,t)
    t=t or {}; t.name=n; objects[n]=t
    function t:IsValid() assert(on_thread); return not self.invalid end
    function t:GetFullName() assert(on_thread and not self.invalid); return self.name end
    return t
end
local function asset(id) local t,n=id:match("^([^:]+):(.+)$"); return {PrimaryAssetType={Name=t},PrimaryAssetName=n} end
local partclass=obj("Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local colorclass=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local function part(i,s)
    return obj("BitReactorCustomizationPartViewModel " .. VMOUT .. "BitReactorCustomizationPartViewModel_" .. i,
        {AssetId=asset(COLOR .. s),GetClass=function() return partclass end})
end
local none,stock,light,blue=part(1,"None"),part(2,"Red_14"),part(3,"NeutralGrey_01"),part(4,"Blue_14")
local vm=obj("BitReactorCustomizationSlotViewModel " .. VMOUT .. "BitReactorCustomizationSlotViewModel_5",
    {SlotTag={TagName=ACCENT},EquippedCustomizationPartViewModel=stock})
local owner=obj(OWNER)
local slot=obj("CustomizationFragmentInstanceSlot " .. PREFIX .. ".CustomizationFragmentInstanceSlot_1")
local mesh=obj("CustomizationFragmentInstanceSlot " .. PREFIX .. ".CustomizationFragmentInstanceSlot_2")
local armor="CustomizationPartDefinition:CPD_H_Outfit_Clo001_TORS_TintF"
local source_rgb=copy(red)
local fragment=obj("CustomizationFragmentInstanceMaterialColor " .. PREFIX .. ".CustomizationFragmentInstanceMaterialColor_3",{
    MaterialTarget={MaterialParameterName="Color 02",MaterialSlotNames={"MI_TORS","MI_ARMS"},
        SlotNameTagsToApply={GameplayTags={{TagName=MESH}}}},
    GetClass=function() return colorclass end,
    GetOwningCustomizationInstance=function() return owner end,
    GetOwningCustomizationSlot=function() return slot end,
    GetColor=function() assert(on_thread); return copy(source_rgb) end,
    SetColor=function(self,c)
        assert(on_thread and files.editor and files.editor:match("^editor%-v[123]\n"),"Journal before source mutation")
        if fail_set then error("SetColor failed") end
        writes=writes+1; source_rgb=copy(c)
        if self.after_set then self.after_set() end
    end,
})
local installed=fragment
function vm:GetFragments() return self.EquippedCustomizationPartViewModel==none and {} or {installed} end
function slot:GetFragmentInstances() return vm:GetFragments() end
function slot:GetCustomizationPartPrimaryAssetId() return vm.EquippedCustomizationPartViewModel.AssetId end
function mesh:GetCustomizationPartPrimaryAssetId() return asset(armor) end
function mesh:GetSlotNameTag() return {TagName=MESH} end
local horns=obj("CustomizationFragmentInstanceSlot " .. PREFIX .. ".CustomizationFragmentInstanceSlot_4",{
    GetSlotNameTag=function() return {TagName=HORNS} end,
    GetCustomizationPartPrimaryAssetId=function() return asset("CustomizationPartDefinition:HornsA") end})
function owner:GetSlotInstance(t)
    if t.TagName==HORNS then return horns_present and horns or nil end
    return t.TagName==ACCENT and slot or mesh
end
function owner:RefreshCustomization() assert(on_thread); refreshes=refreshes+1; if fail_refresh then error("Refresh failed") end end
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local page=obj("WBP_Customization_ItemPage_C " .. host .. ".WBP_Customization_ItemPage_C_1828",{IsActivated=function(self) return not self.inactive end})
local parent=obj("Panel /Game/Test.CreatorParent")
local master=obj("WBP_CustomCharacter_Master_C " .. host .. ".WBP_CustomCharacter_Master_C_1800",{
    IsActivated=function(self) return not self.inactive end,
    IsInViewport=function() error("Do not require screen viewport attachment") end,GetParent=function() return nil end})
local stack=obj("BitReactorActivatableWidgetStack " .. host .. ".GameLayer_Stack",{
    GetParent=function(self) return not self.detached and parent or nil end,
    GetActiveWidget=function(self) return self.top end})
local aux=obj("CustomizationAuxVM_C /Game/Test.Aux",{CurrentCustomizationSlotVM=vm})
local palette={none,light,stock,blue}
local grid=obj("BitReactorTileView /Game/Test.Grid",{
    GetNumItems=function() return #palette end,GetItemAt=function(_,i) return palette[i+1] end,
    GetIndexForItem=function(_,p) for i,v in ipairs(palette) do if p==v then return i-1 end end end})
local tiles=obj("WBP_Customization_SelectionTiles_C /Game/Test.Tiles",{
    CurrentSlotTag={TagName=ACCENT},PartsGridList=grid,IsVisible=function() return true end})
local panel=obj("WBP_CustomizationSlotPanel_C /Game/Test.Panel",{
    WBP_Customization_SelectionTiles=tiles,IsVisible=function() return true end})
page.WBP_CustomizationSlotPanel=panel
page.SlotWidgetSwitcher=obj("CommonActivatableWidgetSwitcher /Game/Test.Switcher",{GetActiveWidget=function() return panel end})
function StaticFindObject(path)
    assert(on_thread)
    for n,v in pairs(objects) do if n:match("^[^ ]+ (.+)$")==path and not v.invalid then return v end end
end
function FindAllOf(class)
    assert(on_thread)
    local found={}
    for n,v in pairs(objects) do if n:match("^([^ ]+) ")==class then found[#found+1]=v end end
    return found
end
function FName(s) assert(on_thread); return s end
io.open=function(path,mode)
    if mode=="r" and not files[path] then return nil end
    if mode=="w" and fail_write and path=="editor.tmp" then return nil end
    if mode=="w" then files[path]="" end
    return {read=function() return files[path] end,write=function(self,data)
        if fail_clear and data=="" and path=="editor.tmp" then error("clear failed") end
        files[path]=data; return self
    end,flush=function() return true end,close=function() return true end}
end
os.rename=function(from,to)
    assert(files[from]~=nil and files[to]==nil,"Windows journal rename must not clobber")
    files[to],files[from]=files[from],nil; return true
end
os.remove=function(p) assert(files[p]~=nil); files[p]=nil; return true end
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,
    text=tostring,values=function(v) assert(type(v)=="table"); return v end}
local targets=assert(loadfile(scripts .. "/color_target.lua"))().new(a)
local runtime={log=function(s) logs[#logs+1]=s end}
runtime.objects=assert(loadfile(scripts .. "/object_cache.lua"))().new(function() end)
function runtime:after(k,ms,cb) jobs[k]={ms=ms,cb=cb} end
function runtime:cancel(k) jobs[k]=nil end
local function run(k) local job=assert(jobs[k],k); jobs[k]=nil; job.cb() end
local journal=helpers.journal({["tint_recovery.txt"]="tint"})
local base,session
local function boot()
    local b={}
    function b.read_context()
        assert(not page.inactive and aux.CurrentCustomizationSlotVM==vm and installed==fragment)
        assert(vm.EquippedCustomizationPartViewModel~=none)
        return {owner=owner,source_slot=slot,slot=vm,part=vm.EquippedCustomizationPartViewModel,
            fragment=fragment,page=page.name,materials=table.concat(fragment.MaterialTarget.MaterialSlotNames,","),original=copy(source_rgb),
            profile=targets.read(fragment,ACCENT,owner)}
    end
    function b.restore(reason)
        if fail_preview_restore then return false end
        if b.pending then b.pending.live=nil end
        b.pending=nil; files.tint=""; runtime:cancel("tint:timeout")
        if b.after_restore then return b.after_restore(reason) end -- as the real engine does
        return true
    end
    function b.invalidate_context_lookup() end
    function b.begin_live()
        local c=b.read_context(); assert(not b.pending)
        b.pending={live=true,test_color=copy(orange),original=c.original,profile=c.profile}; files.tint="preview"
        return b.pending
    end
    function b.check_live(s) return s==b.pending and s and s.live,"inactive preview" end
    function b.update_live(s,c) assert(b.check_live(s)); s.test_color=copy(c); return true end
    -- As the engine: the consumer runs after a successful update; receipt only if it returns true.
    function b.update_live_scoped(s,c,consumer)
        if not b.update_live(s,c) then return false end
        local completed,result=pcall(consumer,function() return b.read_context() end)
        return completed and result==true
    end
    function b.verify_editor_display() assert(not b.pending,"Return display to source first"); assert(not fail_display,"Display color mismatch"); return true end
    function b.context_changed(reason)
        if b.pending then runtime:after("tint:context",1,function() b.restore(reason) end) end
    end
    function b.start()
        if files.tint=="preview" then
            b.pending={live=false}; runtime:after("tint:recovery",1,function() b.restore("recovery") end)
        end
    end
    local s=zones.new(runtime,a,journal,{preview=b})
    base,session=b,s; return s
end
function vm:EquipCustomizationPart(p)
    if p==none then
        assert(not base.pending and equal(source_rgb,white),"RGB rollback before Default restore")
        if fail_default then error("Default restore failed") end
    end
    self.EquippedCustomizationPartViewModel=p
    source_rgb=copy(p==stock and red or white)
    session.context_changed("EquipCustomizationPart")
end
local function clean(default)
    files,jobs,logs={},{},{}; writes,refreshes=0,0
    fail_write,fail_preview_restore,fail_set,fail_refresh,fail_display,fail_default,fail_clear=nil,nil,nil,nil,nil,nil,nil
    vm.EquippedCustomizationPartViewModel=default and none or stock
    source_rgb=copy(default and white or red); owner.invalid=nil; page.inactive=nil
    master.inactive=true; master.invalid=nil
    stack.detached=nil; stack.invalid=nil; stack.WidgetList={master,page}; stack.top=page
    installed=fragment; aux.CurrentCustomizationSlotVM=vm; boot()
end
local function apply(c)
    local s=assert(session.begin_live(),table.concat(logs,"\n"))
    assert(session.update_live(s,c or orange))
    assert(session.apply_live(s),table.concat(logs,"\n"))
    assert(session.applied and not session.pending and not jobs["tint:timeout"])
    assert(equal(source_rgb,c or orange) and files.editor:match("^editor%-v[123]\n"))
end
for _,default in ipairs({false,true}) do
    clean(default); apply()
    -- Applied state retains its creator watcher.
    run("editor:watch"); assert(equal(source_rgb,orange))
    aux.CurrentCustomizationSlotVM=obj("BitReactorCustomizationSlotViewModel /Game/Test.Other")
    session.context_changed("UpdateCurrentCustomizationSlotVM"); run("editor:watch")
    assert(equal(source_rgb,orange),"slot navigation keeps applied source color")
    aux.CurrentCustomizationSlotVM=vm
    -- Back to radial selector is not a creator exit. Nor is a brief interval
    -- where both widgets are inactive during the CommonUI stack transition.
    page.inactive=true; master.inactive=true
    stack.WidgetList={master}; stack.top=master
    session.context_changed("page closed"); run("editor:watch"); run("editor:watch")
    assert(session.applied and equal(source_rgb,orange))
    master.inactive=nil; run("editor:watch")
    assert(session.applied and equal(source_rgb,orange))
    -- Reenter a fresh item widget in the same creator layout.
    objects[page.name]=nil
    page.name="WBP_Customization_ItemPage_C " .. host .. ".WBP_Customization_ItemPage_C_1829"
    objects[page.name]=page; page.inactive=nil; master.inactive=true
    stack.WidgetList={master,page}; stack.top=page
    local s=assert(session.begin_live()); assert(equal(s.test_color,orange),"reopen starts at applied RGB")
    session.update_live(s,violet); assert(session.cancel_live("Cancel"))
    assert(equal(source_rgb,orange) and session.applied,"Cancel preserves last Apply")
    s=assert(session.begin_live()); session.update_live(s,violet); assert(base.restore("external backend restore"))
    assert(equal(source_rgb,orange) and session.applied,"external draft restoration preserves Apply")
    apply(violet)
    local stale=jobs["editor:watch"].cb
    session.context_changed("creator closed",master.name)
    assert(not session.applied and not session.pending and not jobs["editor:watch"])
    assert(equal(source_rgb,default and white or red))
    assert(vm.EquippedCustomizationPartViewModel==(default and none or stock))
    assert(files.editor==""); stale(); assert(not jobs["editor:watch"])
end
-- Missing exit notification is covered by stack removal and bounded inactivity.
clean(); apply(); page.inactive=true; master.inactive=true
run("editor:watch"); run("editor:watch"); assert(session.applied)
run("editor:watch"); assert(not session.applied and equal(source_rgb,red))
clean(); apply(); stack.detached=true; run("editor:watch"); assert(not session.applied)
for _,from_default in ipairs({false,true}) do
    clean(from_default); apply(); stack.WidgetList={}; stack.top=nil
    run("editor:watch")
    assert(not session.applied and not jobs["editor:watch"] and not session.blocked)
    assert(vm.EquippedCustomizationPartViewModel==(from_default and none or stock))
    assert(equal(source_rgb,from_default and white or red))
end
-- Another cached creator's CloseMenu cannot end this applied session.
clean(); apply(); session.context_changed("creator closed","WBP_CustomCharacter_Master_C /Game/Other")
assert(session.applied); assert(runtime.objects.active(),"An owned Apply holds the lookup cache for its watch")
assert(session.restore("cleanup")); assert(not runtime.objects.active(),"Restore releases the editor lookup hold")
-- An open second draft is discarded on item-page exit, but Apply survives.
clean(true); apply(); local draft=assert(session.begin_live()); session.update_live(draft,violet)
page.inactive=true; session.context_changed("page closed")
assert(not session.pending and session.applied and equal(source_rgb,orange))
session.context_changed("creator closed"); assert(vm.EquippedCustomizationPartViewModel==none)
-- No Apply: existing preview-only Default cancellation remains unchanged.
clean(true); assert(session.begin_live()); assert(session.cancel_live("Cancel"))
assert(vm.EquippedCustomizationPartViewModel==none and not session.applied)
-- Fresh Lua recovery restores, never resumes Apply; Default comes last.
clean(true); apply(); jobs={}; boot(); on_thread=false; session.start(); on_thread=true
assert(session.applied and not jobs["editor:watch"])
run("editor:recovery"); run("selection:recovery")
assert(not session.applied and vm.EquippedCustomizationPartViewModel==none and files.editor=="")
-- Recovery with a second hover in flight restores the hover before its source.
clean(true); apply(); assert(session.begin_live()); jobs={}; boot(); session.start()
run("tint:recovery"); assert(equal(source_rgb,orange))
run("editor:recovery"); assert(equal(source_rgb,white) and vm.EquippedCustomizationPartViewModel==none)
-- A later stock edit/fragment replacement wins, including the temporary swatch.
clean(true); apply(); source_rgb=copy(white); run("editor:watch")
assert(not session.applied and vm.EquippedCustomizationPartViewModel==light and files.selection=="")
clean(); apply(); installed=obj("CustomizationFragmentInstanceMaterialColor " .. PREFIX .. ".Replacement")
local before=writes; run("editor:watch"); assert(writes==before and not session.applied)
-- Missing/rebound objects fail closed and preserve the rollback obligation.
clean(); apply(); owner.invalid=true; run("editor:watch")
assert(session.blocked and session.applied and files.editor~="" and not session.begin_live())
owner.invalid=nil; assert(session.restore("retry") and equal(source_rgb,red))
-- No source writes if the write-ahead journal or hover teardown fails.
for _,from_default in ipairs({false,true}) do
    clean(from_default); local preview=assert(session.begin_live()); stack.WidgetList={page}
    assert(not session.apply_live(preview) and writes==0 and not session.applied and not session.pending)
    assert(not session.blocked and not jobs["editor:watch"])
    assert(vm.EquippedCustomizationPartViewModel==(from_default and none or stock))
    assert(table.concat(logs,"\n"):find("CREATOR BIND | REFUSED",1,true))
end
clean(); local s=assert(session.begin_live()); fail_write=true
assert(not session.apply_live(s) and writes==0); fail_write=nil; assert(session.restore("retry"))
clean(true); s=assert(session.begin_live()); fail_preview_restore=true
assert(not session.apply_live(s) and writes==0 and session.blocked)
fail_preview_restore=nil; assert(session.restore("retry") and vm.EquippedCustomizationPartViewModel==none)
-- Verification failures roll back; failed rollback stays blocked and retryable.
clean(); s=assert(session.begin_live()); fail_display=true
assert(not session.apply_live(s) and equal(source_rgb,red) and session.blocked)
fail_display=nil; assert(session.restore("retry display verification") and not session.applied)
clean(); s=assert(session.begin_live()); fail_refresh=true
assert(not session.apply_live(s) and session.blocked and session.applied)
fail_refresh=nil; assert(session.restore("retry") and equal(source_rgb,red))
clean(); apply(); fail_set=true; assert(not session.restore("failure") and session.blocked)
fail_set=nil; assert(session.restore("retry"))
clean(true); apply(); fail_default=true
assert(not session.restore("failure") and session.applied and equal(source_rgb,white))
fail_default=nil; assert(session.restore("retry") and vm.EquippedCustomizationPartViewModel==none)
clean(); apply(); fail_clear=true; assert(not session.restore("failure") and session.applied)
fail_clear=nil; assert(session.restore("retry"))
-- Malformed journals are not cleared, executed or allowed to start a preview.
clean(); files.editor="bad\n"; session.start()
assert(session.blocked and not session.begin_live() and not session.restore("malformed") and files.editor=="bad\n")
clean(); apply(); local recovery=files.editor
files["editor.previous"]=recovery; files.editor=nil; boot(); session.start()
assert(session.blocked and files["editor.previous"]==recovery and not session.begin_live())
-- Dynamic target journals retain the exact zone through Apply, reopen, timeout,
-- Default restoration, cold Lua reload and a changed UI selection.
for _,case in ipairs({
    {"br.Customization.Slot.Character.Outfit.Legs.Color.Visor","br.Customization.Slot.Character.Outfit.Legs.Mesh","Color 04","MI_LEGS"},
    {"br.Customization.Slot.Character.Hair.Hair.Color.Primary","br.Customization.Slot.Character.Hair.Hair.Mesh","Tip Color","MI_Hair"},
    {"br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color","br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh","Tattoo Color","MI_Head",false},
    {"br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color","br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh","Tattoo Color","MI_Head",true},
}) do
    ACCENT,MESH=case[1],case[2]; vm.SlotTag.TagName=ACCENT; tiles.CurrentSlotTag.TagName=ACCENT
    fragment.MaterialTarget.MaterialParameterName=case[3]
    fragment.MaterialTarget.MaterialSlotNames={case[4]}; fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags={{TagName=MESH}}
    horns_present=case[5]
    if case[5]~=nil then fragment.MaterialTarget.SlotNameTagsToApply.GameplayTags[2]={TagName=HORNS} end
    armor="CustomizationPartDefinition:CPD_OtherMesh"
    for _,from_default in ipairs({false,true}) do
        -- Default fallback remains restricted to the verified outfit palette.
        if not from_default or case[1]:find("Outfit",1,true) then
            clean(from_default); apply()
            assert(files.editor:match(case[5]~=nil and "^editor%-v3\n" or "^editor%-v2\n") and session.applied.profile.slot==ACCENT)
            if case[5]~=nil then assert(session.applied.profile.targets[2].asset==(case[5] and "CustomizationPartDefinition:HornsA" or "-")) end
            if from_default then assert(files.selection:match("^selection%-v2\n")) end
            run("editor:watch"); assert(session.applied)
            local draft=assert(session.begin_live()); session.update_live(draft,violet)
            assert(session.cancel_live("cancel") and equal(source_rgb,orange))
            aux.CurrentCustomizationSlotVM=nil
            assert(not session.begin_live(),"Do not open another applied zone")
            jobs={}; boot(); session.start(); assert(session.applied)
            run("editor:recovery")
            assert(not session.applied and files.editor=="" and equal(source_rgb,from_default and white or red))
            assert(vm.EquippedCustomizationPartViewModel==(from_default and none or stock))
        end
    end
    clean(); apply(); local dynamic_record=files.editor; local initial_writes=writes
    files.editor=dynamic_record:gsub("\n" .. case[3] .. "\n","\nWrong Parameter\n")
    jobs={}; boot(); session.start(); if jobs["editor:recovery"] then run("editor:recovery") end
    assert(session.blocked and writes==initial_writes,"Do not restore across changed recorded targeting")
    files.editor=dynamic_record; jobs={}; boot(); session.start(); run("editor:recovery")
    assert(not session.applied and equal(source_rgb,red))
    if case[5]~=nil then
        clean(); apply(); local tattoo_record=files.editor; local tattoo_writes=writes
        files.editor=tattoo_record:gsub("|[^\n]+\n$","|unexpected=-\n")
        jobs={}; boot(); session.start()
        assert(session.blocked and not session.applied and writes==tattoo_writes)
        files.editor=tattoo_record; jobs={}; boot(); session.start(); run("editor:recovery")
        assert(not session.applied and equal(source_rgb,red))
        clean(); apply(); horns_present=not case[5]
        run("editor:watch")
        assert(not session.applied and equal(source_rgb,red),"Changed mesh presence restores only our source tint")
        horns_present=case[5]
    end
end
do
    clean(); local draft=assert(session.begin_live()); local before_refresh=refreshes
    fragment.after_set=function()
        fragment.after_set=nil
        installed=obj("CustomizationFragmentInstanceMaterialColor " .. PREFIX .. ".SetterReplacement")
    end
    assert(not session.apply_live(draft) and refreshes==before_refresh,
        "Apply must not refresh a source replaced by the native setter")
    assert(not session.applied and files.editor=="")
end
-- Scheduling policy is offered for every supported picker profile; a receipt
-- requires both the validated base update and skin companion sync to succeed.
do
    clean(); local ordinary=assert(session.begin_live()); assert(ordinary.preview_policy=="color")
    assert(session.cancel_live("ordinary cadence"))
    local begin=base.begin_live
    base.begin_live=function()
        local draft=begin()
        draft.profile={slot="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"}
        return draft
    end
    local draft=assert(session.begin_live()); assert(draft.preview_policy=="skin")
    local ok,receipt=session.update_live(draft,orange); assert(ok and receipt==true)
    runtime.skin_enable={stop=function() return true end,start=function() return false end}
    ok,receipt=session.update_live(draft,violet); assert(not ok and receipt~=true)
    runtime.skin_enable=nil
    local update=base.update_live
    base.update_live=function() return false end
    ok,receipt=session.update_live(draft,orange); assert(not ok and receipt~=true)
    base.update_live=update
    assert(session.cancel_live("receipt tests"))
    base.begin_live=function()
        local draft=begin(); draft.profile={slot="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"}; return draft
    end
    draft=assert(session.begin_live()); assert(draft.preview_policy=="armor")
    ok,receipt=session.update_live(draft,orange); assert(ok and receipt==true)
    assert(session.cancel_live("armor cadence"))
    base.begin_live=function()
        local draft=begin(); draft.profile={slot="br.Customization.Slot.Character.Hair.Hair.Color.Root"}; return draft
    end
    draft=assert(session.begin_live()); assert(draft.preview_policy=="color")
    assert(session.cancel_live("other appearance cadence"))
    base.begin_live=function()
        local draft=begin(); draft.profile={slot="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Scar.Look",parameter="Scar HSV Shift"}; return draft
    end
    draft=assert(session.begin_live()); assert(draft.preview_policy=="hsv")
    assert(session.cancel_live("native HSV cadence"))
end
io.open=old_open
os.rename,os.remove=old_rename,old_remove
print("Editor Apply: source ownership, Default, reopen/cancel/external restore, slot/exit, replacement, rollback and reload tests passed")
