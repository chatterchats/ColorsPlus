-- Run: tools/run-tests.sh known_instances
local scripts=assert(arg[1])
local known_module=assert(loadfile(scripts .. "/known_instances.lua"))()
local objects,lists,finds,scans={},{},0,0
local function obj(class,path,fields)
    local o=fields or {}; o.full=class .. " " .. path; objects[path]=o
    lists[class]=lists[class] or {}; table.insert(lists[class],o)
    function o:IsValid() return not self.dead end
    function o:GetFullName() return self.full end
    return o
end
function StaticFindObject(path) finds=finds+1; local o=objects[path]; return o end
function FindAllOf(class) scans=scans+1; return lists[class] end
local a={unwrap=function(v) return v end,live=function(v) return v~=nil and v:IsValid() and not v.full:find("Default__",1,true) end,
    name=function(v) return v:GetFullName() end}
local known=known_module.new(a)
local PAGE="WBP_Customization_ItemPage_C"
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_1.WidgetTree_2."
local old=obj(PAGE,host .. "WBP_Customization_ItemPage_C_10",{active=false})
local page=obj(PAGE,host .. "WBP_Customization_ItemPage_C_11",{active=true})
local cdo=obj(PAGE,"/Game/Page.Default__WBP_Customization_ItemPage_C",{active=true})
local function active(p) return a.live(p) and p.active end
-- Nothing known yet: one scan, noting every live result (never the CDO).
local found,scanned=known.select(PAGE,128,active)
assert(#found==1 and found[1]==page and scanned and scans==1)
-- Known now: no scan, by-name lookups only.
finds=0; found,scanned=known.select(PAGE,128,active)
assert(#found==1 and found[1]==page and not scanned and scans==1 and finds==2,"two known pages looked up by name")
-- A hook notes a newer page; it is tried first.
local newer=obj(PAGE,host .. "WBP_Customization_ItemPage_C_12",{active=true}); page.active=false
known.note(newer); found=known.select(PAGE,128,active)
assert(#found==1 and found[1]==newer and scans==1)
-- Dead names are dropped after one miss and never looked up again.
old.dead=true; finds=0; known.select(PAGE,128,active); local first=finds
finds=0; known.select(PAGE,128,active); assert(finds==first-1,"dead name pruned")
-- A renamed/replaced object at the same path is not adopted.
objects[newer.full:match("^[^ ]+ (.+)$")]=obj("Other_C",newer.full:match("^[^ ]+ (.+)$"))
found,scanned=known.select(PAGE,128,active)
assert(scanned and scans==2,"no known instance qualifies: rescan")
-- Two qualifying known instances are both returned (callers refuse ambiguity).
local twin=obj(PAGE,host .. "WBP_Customization_ItemPage_C_13",{active=true}); page.active=true
known.note(twin); found=known.select(PAGE,128,active)
assert(#found==2)
-- Scan limits still apply to the fallback.
local many="Many_C"
for i=1,5 do obj(many,"/Game/M.M_" .. i,{active=false}) end
assert(not pcall(known.select,many,3,active),"Scan limit")
-- Notes ignore unusable values.
known.note(nil); known.note(cdo); known.note({IsValid=function() error("boom") end})
-- Player controller: one UEHelpers scan, then by-name reuse while it lives.
local pc=obj("BP_BrunoPlayerController_C","/Game/Maps/Hub.Hub:PersistentLevel.BP_BrunoPlayerController_C_0")
local helper_calls=0
package.loaded.UEHelpers={GetPlayerController=function() helper_calls=helper_calls+1; return pc end}
assert(known.player_controller()==pc and helper_calls==1)
assert(known.player_controller()==pc and helper_calls==1,"reused by name")
pc.dead=true
local pc2=obj("BP_BrunoPlayerController_C","/Game/Maps/Main.Main:PersistentLevel.BP_BrunoPlayerController_C_0")
package.loaded.UEHelpers.GetPlayerController=function() helper_calls=helper_calls+1; return pc2 end
assert(known.player_controller()==pc2 and helper_calls==2,"dead controller rediscovered")
print("Known instances: scan once then by-name, newest first, dead pruning, no adoption, ambiguity kept, limits and player controller passed")
