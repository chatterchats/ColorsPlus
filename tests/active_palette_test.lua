local scripts=assert(arg[1])
local objects,logs={},{}
local function obj(kind,label,fields)
    local o=fields or {}; o.full=kind .. " /Game/Test." .. label
    function o:IsValid() return not self.invalid end
    function o:GetFullName() return self.full end
    function o:IsVisible() return not self.hidden end
    function o:GetParent() error("Parent traversal must not be used") end
    objects[o.full]=o; return o
end
local a={unwrap=function(v) return v end,live=function(v) return v and v.IsValid and v:IsValid() end,
    name=function(v) return v:GetFullName() end,prop=function(v,k) return v and v[k] end,text=tostring,
    values=function(v) assert(type(v)=="table"); return v end}
local scans=0
function FindAllOf(c)
    scans=scans+1; assert(c=="WBP_Customization_ItemPage_C","No global palette scan")
    local out={}; for _,o in pairs(objects) do if o.full:match("^"..c.." ") then out[#out+1]=o end end; return out
end
local fail_lookup=false
function StaticFindObject(path)
    if fail_lookup then return end
    for n,o in pairs(objects) do if n:match("^[^ ]+ (.+)$")==path then return o end end
end
local tag="br.Customization.Slot.Character.Hair.Hair.Color.Primary"
local grid=obj("BitReactorTileView","Grid")
local tiles=obj("WBP_Customization_SelectionTiles_C","Tiles",{CurrentSlotTag={TagName=tag},PartsGridList=grid})
local simple=obj("WBP_CustomizationSlotPanel_C","Simple",{WBP_Customization_SelectionTiles=tiles})
local children={tiles}
local list=obj("BitReactorStackBox","List",{GetAllChildren=function() return children end})
local combined=obj("WBP_CustomizationSlotPanelCombined_C","Combined",{CustomizationSlots=list})
local slotlist=obj("WBP_Customization_SlotList_C","SlotList",{SlotStack=list})
local active=simple
local switcher=obj("CommonActivatableWidgetSwitcher","Switcher",{GetActiveWidget=function() return active end})
local page=obj("WBP_Customization_ItemPage_C","Page",{SlotWidgetSwitcher=switcher,
    WBP_CustomizationSlotPanel=simple,WBP_CustomizationSlotPanelCombined=combined,WBP_Customization_SlotList=slotlist,
    IsActivated=function(self) return not self.inactive end})
local resolver=assert(loadfile(scripts .. "/active_palette.lua"))().new(a,function(s) logs[#logs+1]=s end)
local function resolve() return resolver.resolve(page.full,tag) end
assert(resolve()==grid and scans==0)
local logged=#logs
assert(resolve()==grid and #logs==logged,"Identical success logs must be suppressed, not validation")
grid.invalid=true; assert(not pcall(resolve),"A quiet repeat must still discover invalid objects"); grid.invalid=nil
local displayed_grid,displayed_tag=resolver.resolve(page.full,"br.Customization.Slot.Character.Hair.Hair.Mesh",true)
assert(displayed_grid==grid and displayed_tag==tag,"Simple panel exposes its displayed color slot")
assert(not pcall(resolver.resolve,page.full,"br.Customization.Slot.Character.Hair.Hair.Mesh"),"Exact palette lookup must not retarget")
-- Inactive panel and globally visible stale palettes cannot contend with root.
local stale=obj("WBP_Customization_SelectionTiles_C","Stale",{CurrentSlotTag=tiles.CurrentSlotTag,
    PartsGridList=obj("BitReactorTileView","StaleGrid")})
active=combined; assert(resolve()==grid)
assert(not pcall(resolver.resolve,page.full,"br.Customization.Slot.Character.Hair.Hair.Mesh",true),"Do not infer focus on a combined panel")
active=slotlist; assert(resolve()==grid)
-- Known container wrappers within an owned list, never arbitrary widget trees.
local border=obj("Border","Border",{GetAllChildren=function() return {tiles} end})
children={border}; assert(resolve()==grid)
local other=obj("WBP_Customization_SelectionTiles_C","Other",{CurrentSlotTag={TagName="other"},PartsGridList=stale.PartsGridList})
children={other,tiles}; assert(resolve()==grid)
local function refuse(change,undo,expected)
    change(); local ok,err=pcall(resolve); assert(not ok and tostring(err):find(expected,1,true),tostring(err)); undo()
end
refuse(function() children={tiles,stale} end,function() children={tiles} end,"found 2")
stale.hidden=true; children={tiles,stale}; assert(resolve()==grid); stale.hidden=nil; children={tiles}
refuse(function() children={list} end,function() children={tiles} end,"cycle/alias")
refuse(function() children={}; for i=1,65 do children[i]=tiles end end,function() children={tiles} end,"child limit")
refuse(function() page.inactive=true end,function() page.inactive=nil end,"no longer active")
refuse(function() page.SlotWidgetSwitcher=nil end,function() page.SlotWidgetSwitcher=switcher end,"object unavailable")
refuse(function() page.WBP_Customization_SlotList=combined end,function() page.WBP_Customization_SlotList=slotlist end,"differs from page reference")
refuse(function() tiles.CurrentSlotTag={TagName="changed"} end,function() tiles.CurrentSlotTag={TagName=tag} end,"found 0")
refuse(function() slotlist.hidden=true end,function() slotlist.hidden=nil end,"found 0")
local getter=switcher.GetActiveWidget; local calls=0
refuse(function() switcher.GetActiveWidget=function() calls=calls+1; return calls==1 and slotlist or simple end end,
    function() switcher.GetActiveWidget=getter end,"changed during discovery")
fail_lookup=true; assert(resolve()==grid and scans==1)
local missing=obj("WBP_Customization_ItemPage_C","Missing",{IsActivated=function() return true end})
assert(not pcall(resolver.resolve,missing.full,tag),"Never fall back to a global palette when page links are absent")
print("Active palette: simple/combined/list routes, stale exclusion, exact page, visibility, ambiguity, limits and transitions passed")
