-- Follow displayed palettes into the explicit category tree; never global VMs.
local scripts=assert(arg[1])
local objects,logs={},{}
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local function obj(kind,path,fields)
    local o=fields or {}; o.full=kind .. " " .. path; objects[o.full]=o
    function o:IsValid() return not self.invalid end
    function o:GetFullName() return self.full end
    function o:IsVisible() return not self.hidden end
    return o
end
local a={unwrap=function(v) return v end,live=function(v) return v and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,text=tostring,
    values=function(v) assert(type(v)=="table","unreadable children"); return v end}
function StaticFindObject(path)
    for n,o in pairs(objects) do if n:match("^[^ ]+ (.+)$")==path then return o end end
end
function FindAllOf() error("No global VM/palette scan") end
local function vm(n,tag)
    return obj("BitReactorCustomizationSlotViewModel",host .. "BitReactorCustomizationSlotViewModel_" .. n,
        {SlotTag={TagName=tag},CustomizationChildSlotViewModels={}})
end
local style=vm(1,"br.Customization.Slot.Character.Hair.Hair.Mesh")
local root=vm(2,"br.Customization.Slot.Character.Hair.Hair")
-- Live game tags: root is Secondary, tips are Primary (do not infer by label).
local color=vm(3,"br.Customization.Slot.Character.Hair.Hair.Color.Secondary")
local tips=vm(4,"br.Customization.Slot.Character.Hair.Hair.Color.Primary")
root.CustomizationChildSlotViewModels={style,color,tips}
local partclass=obj("Class","/Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local function part(n)
    return obj("BitReactorCustomizationPartViewModel",host .. "BitReactorCustomizationPartViewModel_" .. n,{
        AssetId={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_Test_" .. n},
        GetClass=function() return partclass end})
end
local selected,other=part(1),part(2)
color.EquippedCustomizationPartViewModel=selected; tips.EquippedCustomizationPartViewModel=selected
local items={selected,other}
local grid=obj("BitReactorTileView","/Game/Test.Grid",{GetNumItems=function() return #items end,
    GetItemAt=function(_,i) return items[i+1] end,
    GetIndexForItem=function(_,v) for i,item in ipairs(items) do if item==v then return i-1 end end end})
local tiles=obj("WBP_Customization_SelectionTiles_C","/Game/Test.Tiles",{CurrentSlotTag=color.SlotTag,PartsGridList=grid})
local panel=obj("WBP_CustomizationSlotPanel_C","/Game/Test.Panel",{WBP_Customization_SelectionTiles=tiles})
local switcher=obj("CommonActivatableWidgetSwitcher","/Game/Test.Switcher",{GetActiveWidget=function() return panel end})
local page=obj("WBP_Customization_ItemPage_C","/Game/Test.Page",{SlotWidgetSwitcher=switcher,
    WBP_CustomizationSlotPanel=panel,IsActivated=function(self) return not self.inactive end})
local target=assert(loadfile(scripts .. "/color_target.lua"))().new(a,function(s) logs[#logs+1]=s end)
local function resolve() return target.selected(style,page.full,root) end
assert(resolve()==color and logs[#logs]:find("RESOLVED DISPLAYED",1,true))
-- Repeated selection checks must not walk unrelated palette swatches. Exact
-- equipped identity/index/class/owner are enough; donor discovery stays strict.
do
    local getter=grid.GetItemAt; local reads=0
    grid.GetItemAt=function(self,index) reads=reads+1; return getter(self,index) end
    assert(resolve()==color and reads==1,"Selection resolution should read only the equipped palette item")
    reads=0; target.palette(color,page.full); assert(reads==#items,"Donor palette still validates every item")
    grid.GetItemAt=getter
end
assert(target.selected(color,page.full,nil)==color,"Existing correct selection needs no tree override")
tiles.CurrentSlotTag=tips.SlotTag; assert(resolve()==tips,"Must follow exact root/tip palette tag")
tiles.CurrentSlotTag=color.SlotTag
local function refuse(change,undo,expected)
    change(); local ok,err=pcall(resolve); undo()
    assert(not ok and tostring(err):find(expected,1,true),tostring(err))
end
-- Diamond-shaped graph: the same color VM is reachable via Style and root.
style.CustomizationChildSlotViewModels={color,tips}
assert(resolve()==color,"Shared color candidates are not ambiguous")
tiles.CurrentSlotTag=tips.SlotTag; assert(resolve()==tips)
assert(logs[#logs]:find("shared_references=2",1,true))
tiles.CurrentSlotTag=color.SlotTag
root.CustomizationChildSlotViewModels={color,style,tips,style}
assert(resolve()==color,"Shared references must work regardless of child order")
root.CustomizationChildSlotViewModels={style,color,tips}
style.CustomizationChildSlotViewModels={}
-- Shared non-target node/subtree and repeated current VM are also legitimate.
tips.CustomizationChildSlotViewModels={style}
assert(resolve()==color)
tips.CustomizationChildSlotViewModels={}
root.CustomizationChildSlotViewModels={style,color,color,tips}
assert(resolve()==color)
root.CustomizationChildSlotViewModels={style,color,tips}
-- Native Face Shape can point back to itself before the sibling Skin Tone.
-- Reopening must still find the exact displayed slot, without looping.
style.CustomizationChildSlotViewModels={style}
assert(resolve()==color)
tiles.CurrentSlotTag=tips.SlotTag; assert(resolve()==tips)
assert(logs[#logs]:find("back_edges=1",1,true))
tiles.CurrentSlotTag=color.SlotTag
assert(resolve()==color and resolve()==color,"Repeated reopen with self-reference")
style.CustomizationChildSlotViewModels={color}; color.CustomizationChildSlotViewModels={style}
assert(resolve()==color,"Multi-node back-edge must terminate")
color.CustomizationChildSlotViewModels={root}
assert(resolve()==color,"Root back-edge must terminate")
style.CustomizationChildSlotViewModels={}; color.CustomizationChildSlotViewModels={}
tips.CustomizationChildSlotViewModels={tips}
assert(resolve()==color,"Cycle after the candidate must terminate")
tips.CustomizationChildSlotViewModels={}
-- Do not stop scanning at the first match or loop: ambiguity still refuses.
refuse(function() style.CustomizationChildSlotViewModels={style}; tips.SlotTag=color.SlotTag end,
    function() style.CustomizationChildSlotViewModels={}; tips.SlotTag={TagName="br.Customization.Slot.Character.Hair.Hair.Color.Primary"} end,
    "Ambiguous displayed")
refuse(function() root.invalid=true end,function() root.invalid=nil end,"object unavailable")
refuse(function() root.CustomizationChildSlotViewModels={color} end,
    function() root.CustomizationChildSlotViewModels={style,color,tips} end,"missing from category tree")
refuse(function() tips.SlotTag=color.SlotTag end,
    function() tips.SlotTag={TagName="br.Customization.Slot.Character.Hair.Hair.Color.Primary"} end,"Ambiguous displayed")
refuse(function() root.CustomizationChildSlotViewModels={style,root} end,
    function() root.CustomizationChildSlotViewModels={style,color,tips} end,"missing from category tree")
refuse(function() root.CustomizationChildSlotViewModels={} for i=1,65 do root.CustomizationChildSlotViewModels[i]=color end end,
    function() root.CustomizationChildSlotViewModels={style,color,tips} end,"child limit")
refuse(function() color.full=color.full:gsub("GameInstance_C_0","GameInstance_C_1") end,
    function() color.full=color.full:gsub("GameInstance_C_1","GameInstance_C_0") end,"game-instance/class mismatch")
refuse(function() color.CustomizationChildSlotViewModels=nil end,
    function() color.CustomizationChildSlotViewModels={} end,"unreadable children")
-- A repeated identity must retain its tag; it is not permission to adopt a
-- node that changed while following the category references.
local original_prop=a.prop
refuse(function()
    style.CustomizationChildSlotViewModels={style}
    a.prop=function(v,k)
        if v==style and k=="CustomizationChildSlotViewModels" then style.SlotTag.TagName="changed" end
        return original_prop(v,k)
    end
end,function()
    a.prop=original_prop; style.SlotTag.TagName="br.Customization.Slot.Character.Hair.Hair.Mesh"
    style.CustomizationChildSlotViewModels={}
end,"Shared slot tag changed")
refuse(function()
    style.CustomizationChildSlotViewModels={style}
    a.prop=function(v,k)
        if v==style and k=="CustomizationChildSlotViewModels" then style.invalid=true end
        return original_prop(v,k)
    end
end,function()
    a.prop=original_prop; style.invalid=nil; style.CustomizationChildSlotViewModels={}
end,"object unavailable")
refuse(function()
    root.CustomizationChildSlotViewModels={color,style,tips}
    style.CustomizationChildSlotViewModels={color}
    a.prop=function(v,k)
        if v==style and k=="CustomizationChildSlotViewModels" then color.SlotTag.TagName="changed" end
        return original_prop(v,k)
    end
end,function()
    a.prop=original_prop; color.SlotTag.TagName="br.Customization.Slot.Character.Hair.Hair.Color.Secondary"
    root.CustomizationChildSlotViewModels={style,color,tips}; style.CustomizationChildSlotViewModels={}
end,"Shared slot tag changed")
refuse(function()
    local previous=root
    for i=1,9 do
        local child=vm(100+i,"br.Customization.Slot.Character.Deep" .. i)
        previous.CustomizationChildSlotViewModels={child}; previous=child
    end
end,function() root.CustomizationChildSlotViewModels={style,color,tips} end,"depth limit")
refuse(function()
    local branches={}
    for i=1,3 do
        local branch=vm(200+i,"br.Customization.Slot.Character.Branch" .. i)
        for j=1,43 do
            branch.CustomizationChildSlotViewModels[j]=vm(300+i*100+j,"br.Customization.Slot.Character.Leaf" .. i .. "_" .. j)
        end
        branches[i]=branch
    end
    root.CustomizationChildSlotViewModels=branches
end,function() root.CustomizationChildSlotViewModels={style,color,tips} end,"node limit")
-- An outfit can wear a swatch the palette does not offer (hub armor:
-- asset_matches=0). The grid stays bound by the exact tiles walk and tag;
-- the miss is logged, not refused.
do
    items={other}
    assert(resolve()==color and logs[#logs]:find("not a palette item",1,true)
        and logs[#logs]:find("asset_matches=0",1,true))
    local palette=target.palette(color,page.full); assert(#palette==1 and palette[1].object==other)
    local loaded=part(1); objects[loaded.full]=nil
    loaded.full=loaded.full:gsub("_1$","_901"); objects[loaded.full]=loaded
    color.EquippedCustomizationPartViewModel=loaded; tips.EquippedCustomizationPartViewModel=loaded
    items={selected,other}
    target.palette(color,page.full); assert(logs[#logs]:find("asset_matches=1",1,true))
    color.EquippedCustomizationPartViewModel=selected; tips.EquippedCustomizationPartViewModel=selected
end
refuse(function() tiles.hidden=true end,function() tiles.hidden=nil end,"found 0")
refuse(function() tiles.CurrentSlotTag={TagName="br.Customization.Slot.Character.Unrelated.Color"} end,
    function() tiles.CurrentSlotTag=color.SlotTag end,"missing from category tree")
refuse(function() page.inactive=true end,function() page.inactive=nil end,"no longer active")
local count=grid.GetNumItems
refuse(function() grid.GetNumItems=function() tiles.CurrentSlotTag=tips.SlotTag; return #items end end,
    function() grid.GetNumItems=count; tiles.CurrentSlotTag=color.SlotTag end,"changed during slot resolution")
assert(resolve()==color)
-- Reproduce the reported Face Shape auxiliary / Skin Tone palette mismatch.
root.SlotTag={TagName="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face"}
style.SlotTag={TagName=root.SlotTag.TagName .. ".Mesh"}
color.SlotTag={TagName=root.SlotTag.TagName .. ".SkinTone"}
root.CustomizationChildSlotViewModels={style,color}
style.CustomizationChildSlotViewModels={style}
tiles.CurrentSlotTag=color.SlotTag
assert(resolve()==color,"Skin Tone must reopen past Face Shape back-edge")
assert(logs[#logs]:find("back_edges=1",1,true))
assert(resolve()==color,"Repeated Skin Tone reopen must succeed")
print("Selected color slot: shared/cyclic graph references, reopen, exact root/tip tags, ownership, ambiguity, bounds and stale UI refusal passed")
