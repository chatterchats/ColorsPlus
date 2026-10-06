-- Run: tools/run-tests.sh default_selection
local scripts=assert(arg[1])
local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
helpers.share_modules(scripts)
local zones=assert(loadfile(scripts .. "/color_zone.lua"))()
local original_open=io.open
local files,objects,messages,jobs={},{},{},{}
local fail_write,fail_equip,fail_restore,fail_preview,fail_context,fail_clear
local fail_bound_write
local equips={}
local COLOR="CustomizationPartDefinition:CPD_H_Outfit_Color_"
local NONE,WHITE,RED,BLUE=COLOR .. "None",COLOR .. "NeutralGrey_01",COLOR .. "Red_06",COLOR .. "Blue_14"
local ACCENT="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"
local VM_OUTER="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local OWNER="CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance"
local SOURCE="CustomizationFragmentInstanceSlot " .. OWNER:match("^[^ ]+ (.+)$") .. ".CustomizationFragmentInstanceSlot_1"
local function asset(s) local t,n=s:match("^([^:]+):(.+)$"); return {PrimaryAssetType={Name=t},PrimaryAssetName=n} end
local function object(n,t)
    t=t or {}; t.name=n
    function t:IsValid() return not self.invalid end
    function t:GetFullName() assert(not self.invalid); return self.name end
    objects[n]=t; return t
end
local class=object("Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local function part(i,id)
    return object("BitReactorCustomizationPartViewModel " .. VM_OUTER .. "BitReactorCustomizationPartViewModel_" .. i,
        {AssetId=asset(id),GetClass=function() return class end})
end
local default,white,red,blue=part(1,NONE),part(2,WHITE),part(3,RED),part(4,BLUE)
local slot=object("BitReactorCustomizationSlotViewModel " .. VM_OUTER .. "BitReactorCustomizationSlotViewModel_5",
    {SlotTag={TagName=ACCENT},EquippedCustomizationPartViewModel=default})
local owner=object(OWNER)
local source=object(SOURCE)
local fragment=object("CustomizationFragmentInstanceMaterialColor /Game/Test.Fragment",{
    GetOwningCustomizationInstance=function() return owner end,
    GetOwningCustomizationSlot=function() return source end,
})
local function current() return slot.EquippedCustomizationPartViewModel end
function slot:GetFragments() return current()==default and {} or {fragment} end
function source:GetFragmentInstances() return slot:GetFragments() end
function source:GetCustomizationPartPrimaryAssetId() return current().AssetId end
function owner:GetSlotInstance(t) assert(t.TagName==ACCENT); return source end
-- The live creator layout: item page above the creator master in the game's
-- layer stack (what generic discovery and creator binding verify).
local LAYOUT=VM_OUTER .. "WBP_OverallUILayout_C_15.WidgetTree_16."
local page=object("WBP_Customization_ItemPage_C " .. LAYOUT .. "WBP_Customization_ItemPage_C_19",{IsActivated=function(self) return not self.inactive end})
local master=object("WBP_CustomCharacter_Master_C " .. LAYOUT .. "WBP_CustomCharacter_Master_C_18",{IsActivated=function() return true end})
local stack_parent=object("Panel /Game/Test.StackParent")
object("BitReactorActivatableWidgetStack " .. LAYOUT .. "GameLayer_Stack",
    {WidgetList={master,page},GetActiveWidget=function() return page end,GetParent=function() return stack_parent end})
local aux=object("CustomizationAuxVM_C /Game/Test.Aux",{CurrentCustomizationSlotVM=slot})
local palette={default,white,red,blue}
local grid=object("BitReactorTileView /Game/Test.Grid",{
    GetNumItems=function() return #palette end,
    GetItemAt=function(_,i) return palette[i+1] end,
    GetIndexForItem=function(_,p) for i,v in ipairs(palette) do if v==p then return i-1 end end end,
})
local widget=object("WBP_Customization_SelectionTiles_C /Game/Test.Tiles",{
    CurrentSlotTag={TagName=ACCENT},PartsGridList=grid,IsVisible=function(self) return not self.hidden end,
})
local lists={widget}
function widget:GetParent() return page end
local panel=object("WBP_CustomizationSlotPanel_C " .. LAYOUT .. "WBP_Customization_ItemPage_C_19.Panel",
    {WBP_Customization_SelectionTiles=widget,IsVisible=function() return true end})
page.WBP_CustomizationSlotPanel=panel
page.SlotWidgetSwitcher=object("CommonActivatableWidgetSwitcher " .. LAYOUT .. "WBP_Customization_ItemPage_C_19.Switcher",
    {GetActiveWidget=function() return panel end})
function FindAllOf(c)
    if c=="CustomizationAuxVM_C" then return {aux} end
    if c=="WBP_Customization_ItemPage_C" then return {page} end
    if c=="WBP_Customization_SelectionTiles_C" then return lists end
    local out={}; for n,v in pairs(objects) do if n:match("^([^ ]+) ")==c then out[#out+1]=v end end; return out
end
function StaticFindObject(p)
    for n,v in pairs(objects) do if n:match("^[^ ]+ (.+)$")==p and not v.invalid then return v end end
end
function FName(s) return s end
io.open=function(p,mode)
    if mode=="r" and files[p]==nil then return nil,p .. ": No such file or directory",2 end
    if mode=="w" and fail_write then return nil end
    if mode=="w" then files[p]="" end
    return {read=function() return files[p] end,write=function(self,s)
        if fail_bound_write and s:find("\nselected\n",1,true) then fail_bound_write=false; error("bound journal failed") end
        if fail_clear and s=="" then error("clear failed") end
        files[p]=s; return self
    end,flush=function() return true end,close=function() return true end}
end
local a={unwrap=function(v) return v end,live=function(v) return type(v)=="table" and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,
    text=function(v) return tostring(v) end,values=function(v) assert(type(v)=="table"); return v end}
local runtime={log=function(s) messages[#messages+1]=s end}
function runtime:after(key,delay,cb) jobs[key]={delay=delay,cb=cb} end
function runtime:cancel(key) jobs[key]=nil end
local function run(k) local j=assert(jobs[k],k); jobs[k]=nil; j.cb() end
local function has(s) for _,v in ipairs(messages) do if v:find(s,1,true) then return true end end end
local journal=helpers.journal({["tint_recovery.txt"]="tint"})
local base,wrapped
local function boot()
    local b={}
    function b.read_context()
        assert(not fail_context,"regular context rejected")
        assert(current()~=default)
        return {slot=slot,part=current(),owner=owner,source_slot=source}
    end
    function b.restore(reason)
        if fail_restore then return false end
        if b.pending then b.pending.live=false end
        b.pending=nil; files.tint=""
        if b.after_restore then return b.after_restore(reason) end -- as the real engine does
        return true
    end
    function b.invalidate_context_lookup() end
    function b.begin_live()
        assert(current()~=default,"Must equip a stock swatch before using regular preview")
        b.pending={live=true,test_color={R=1,G=.2,B=.1,A=1},profile={slot=slot.SlotTag.TagName}}
        files.tint="RGB pending"
        if fail_preview then b.restore("open failed"); return nil end
        return b.pending
    end
    function b.update_live(s) assert(s==b.pending); return true end
    function b.check_live(s) return s==b.pending and s.live end
    function b.context_changed()
        if b.pending then runtime:after("tint:context",1,function() b.restore("context") end) end
    end
    function b.start()
        if files.tint and files.tint~="" then
            b.pending={live=false}
            runtime:after("tint:recovery",1,function() b.restore("reload") end)
        end
    end
    function b.inspect() return "regular" end
    local w=zones.new(runtime,a,journal,{preview=b})
    base,wrapped=b,w; return w
end
function slot:EquipCustomizationPart(p)
    if p~=default then
        assert(files.selection and files.selection:match("^selection%-v2\n"),"Journal must precede temporary equip")
    end
    if p==default then
        assert(not base.pending and files.tint~="RGB pending","Restore RGB before Default")
        if fail_equip=="restore" then error("Default equip failed") end
    elseif fail_equip=="before" then error("equip failed before mutation") end
    equips[#equips+1]=p
    self.EquippedCustomizationPartViewModel=p
    -- Re-entrant stock notifications must not cancel our own selection.
    wrapped.context_changed("EquipCustomizationPart")
    if p~=default and fail_equip=="after" then error("equip failed after mutation") end
end
local function clean()
    files={}; jobs={}; messages={}; equips={}; lists={widget}; palette={default,white,red,blue}
    fail_equip=nil; fail_write=nil; fail_restore=nil; fail_preview=nil; fail_context=nil; fail_clear=nil; fail_bound_write=nil
    slot.EquippedCustomizationPartViewModel=default; slot.invalid=nil
    widget.hidden=nil; page.inactive=nil; aux.CurrentCustomizationSlotVM=slot
    boot()
end
local function begin()
    local s=wrapped.begin_live(); assert(s,table.concat(messages,"\n"))
    assert(current()==white and wrapped.pending==s and files.selection:find("\nselected\n",1,true))
    assert(equips[#equips]==white and not jobs["tint:context"])
    return s
end
local function restored()
    assert(current()==default and not wrapped.pending and files.selection=="" and files.tint=="")
end
clean(); local s=begin(); assert(s.perf_selection=="Default"); assert(wrapped.update_live(s,{})); assert(wrapped.check_live(s))
assert(wrapped.inspect()==false,"Inspection waits for the temporary selection to end")
assert(wrapped.restore("Cancel")); restored()
assert(has("RESTORED | equipped Default"))
begin(); assert(base.restore("external backend restore")); restored() -- internal base.restore must reach adapter
-- Leaving the item page ends the draft at once (no scheduled context restore).
begin(); page.inactive=true; wrapped.context_changed("page closed"); assert(not jobs["tint:context"]); restored()
clean(); begin(); aux.CurrentCustomizationSlotVM=object("BitReactorCustomizationSlotViewModel /Game/Test.OtherSlot")
wrapped.context_changed("slot changed"); run("tint:context"); restored() -- restore recorded, not newly selected slot

-- No missing auxiliary root/character VM is ever consulted.
clean(); assert(aux.RootCustomizationSlotVM==nil and aux.CharacterCustomizationVM==nil)
begin(); assert(wrapped.restore("missing roots")); restored()
-- List order, not asset sort order / FindAllOf order, determines first swatch.
clean(); palette={default,red,white,blue}; assert(wrapped.begin_live()); assert(current()==red)
assert(wrapped.restore("order")); restored()
-- Any non-Default stock swatch may be the temporary selection, Blue included.
clean(); palette={default,blue,white}; assert(wrapped.begin_live() and current()==blue)
assert(wrapped.restore("blue first")); restored()
clean(); widget.hidden=true; assert(not wrapped.begin_live() and current()==default and #equips==0)
clean(); palette={white,red}; assert(not wrapped.begin_live() and current()==default and #equips==0)
clean(); fail_write=true; assert(not wrapped.begin_live() and current()==default and #equips==0)
for _,mode in ipairs({"before","after"}) do
    clean(); fail_equip=mode; assert(not wrapped.begin_live()); restored()
end
clean(); fail_context=true; assert(not wrapped.begin_live()); restored()
clean(); fail_preview=true; assert(not wrapped.begin_live()); restored()
clean(); fail_bound_write=true; assert(not wrapped.begin_live()); restored()

-- Default restore failure retains the record; retry never needs the RGB session.
clean(); begin(); fail_equip="restore"; assert(not wrapped.restore("Cancel"))
assert(wrapped.pending and current()==white and files.selection~="" and not base.pending)
assert(not wrapped.begin_live()); fail_equip=nil; assert(wrapped.restore("retry")); restored()
clean(); begin(); fail_restore=true; assert(not wrapped.restore("Cancel") and current()==white)
assert(files.selection~="" and base.pending); fail_restore=nil; assert(wrapped.restore("retry")); restored()
clean(); begin(); fail_clear=true; assert(not wrapped.restore("clear failure") and wrapped.pending)
fail_clear=nil; assert(wrapped.restore("retry clear")); restored()
-- External stock choices must not be overwritten by delayed cleanup.
clean(); begin(); slot.EquippedCustomizationPartViewModel=red
assert(wrapped.restore("user selected red") and current()==red and files.selection=="")
assert(has("another stock swatch"))
-- Invalid/rebound objects retain recovery rather than touching another character.
clean(); begin(); slot.invalid=true; assert(not wrapped.restore("missing slot") and files.selection~="")
slot.invalid=false; assert(wrapped.restore("retry")); restored()
clean(); begin(); local original_owner=fragment.GetOwningCustomizationInstance
fragment.GetOwningCustomizationInstance=function() return object("CustomizationInstance /Game/Test.OtherOwner") end
assert(not wrapped.restore("rebound VM") and current()==white and files.selection~="")
fragment.GetOwningCustomizationInstance=original_owner; assert(wrapped.restore("retry")); restored()

-- Hot reload/cold Lua runtime: RGB is restored first, then Default, never resumed.
clean(); begin(); boot(); wrapped.start(); assert(wrapped.pending and not wrapped.pending.live)
run("tint:recovery"); restored(); run("selection:recovery"); restored()
clean(); begin(); files.tint=""; boot(); wrapped.start(); run("selection:recovery"); restored()
-- A crash between equip and owner binding cannot authorize a guessed owner.
clean(); begin(); local selected_record=files.selection
files.selection=selected_record:gsub("[^\n]+\n[^\n]+\nselected\n","unbound\nunbound\nselecting\n")
files.tint=""; boot(); wrapped.start(); run("selection:recovery")
assert(wrapped.pending and current()==white and has("Unbound selection recovery"))
slot.EquippedCustomizationPartViewModel=default
assert(wrapped.restore("manually selected Default")); restored()
-- Truncated, unsupported and mismatched-instance journals never cause equip.
for _,bad in ipairs({selected_record .. "extra\n",selected_record:sub(1,-2),
    selected_record:gsub("\nselected\n","\nunknown\n"),
    selected_record:gsub("BP_BrunoGameInstance_C_0.BitReactorCustomizationPartViewModel_1",
        "BP_BrunoGameInstance_C_8.BitReactorCustomizationPartViewModel_1"),
    (selected_record:gsub("NeutralGrey_01","None"))}) do
    clean(); files.selection=bad; wrapped.start()
    assert(wrapped.blocked and not wrapped.begin_live() and #equips==0)
end
-- Existing non-Default behavior delegates without an extra equip or journal.
clean(); slot.EquippedCustomizationPartViewModel=red
s=assert(wrapped.begin_live()); assert(#equips==0 and files.selection==nil)
assert(wrapped.restore("regular Cancel") and current()==red and #equips==0)
io.open=original_open
print("Default selection: list order, temporary equip, rollback, context/external restore, reload, stale ownership and malformed recovery passed")
