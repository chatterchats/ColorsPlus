local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/display_handoff.lua"))()
local function obj(n,fields) local v=fields or {}; v.n=n; return v end
local a={unwrap=function(v) return v end,live=function(v) return v and not v.invalid end,
    name=function(v) return v.n end,prop=function(v,k) return v[k] end,values=function(v) return v end}
local world="/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local display_world="/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel."
local data,source=obj("Actor /data"),obj("Actor /source")
local preview=obj("Instance /preview",{GetOwner=function() return data end})
local owner=obj("Instance /owner",{GetOwner=function() return source end,GetPreviewCustomizationInstance=function() return preview end})
local display=obj("BP_CustomCharacter_CustomizationProxy_C " .. display_world .. "BP_HawksCustomizationProxyCharacter_C_0",{ClonedFromCharacter=source})
local instance=obj("Instance /display",{GetOwner=function() return display end})
display.CustomizationInstance=instance
local container=obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "BP_CustomizationPreviewProxyContainer_C_0",
    {ProxyDataStorage=data,ProxyCharacter=display,IsPreviewing=false})
local inventory={container}
local lookup=container
local scans,lookups,colors,meshes=0,0,0,0
function FindAllOf(class)
    assert(class=="BP_CustomizationPreviewProxyContainer_C"); scans=scans+1; return inventory
end
function StaticFindObject(path)
    assert(path==container.n:match("^[^ ]+ (.+)$")); lookups=lookups+1; return lookup
end
local handoff=module.new({log=function() end},a,function() colors=colors+1 end,function() meshes=meshes+1 end)
local record=handoff.prepare({owner=owner,part={AssetId={}}},preview)
assert(scans==1 and lookups==0 and colors==1,"Initial discovery must remain unique/global")
local session={handoff=record,profile={targets={}},phase="owned"}
container.IsPreviewing=true; display.ClonedFromCharacter=data
handoff.verify(session,owner,preview)
handoff.verify(session,owner,preview,{R=1})
assert(scans==1 and lookups==2 and meshes==2 and colors==2,"Bound verification must retain checks without global discovery")
lookup=nil
handoff.verify(session,owner,preview)
assert(scans==2,"Missing direct lookup must fall back to unique discovery")
inventory={container,container}
assert(not pcall(handoff.verify,session,owner,preview),"Ambiguous fallback must fail")
inventory={obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "BP_CustomizationPreviewProxyContainer_C_1",
    {ProxyDataStorage=data,ProxyCharacter=display})}
assert(not pcall(handoff.verify,session,owner,preview),"Fallback must not adopt a replacement")
inventory={container}; lookup=container
for _,field in ipairs({"ProxyDataStorage","ProxyCharacter","IsPreviewing"}) do
    local old=container[field]; container[field]=nil
    local before=scans
    assert(not pcall(handoff.verify,session,owner,preview),"Accepted changed " .. field)
    assert(scans==before,"Changed link must fail, not scan for a substitute")
    container[field]=old
end
local original=instance.GetOwner; instance.GetOwner=function() return source end
assert(not pcall(handoff.verify,session,owner,preview)); instance.GetOwner=original
display.ClonedFromCharacter=source
assert(not pcall(handoff.verify,session,owner,preview)); display.ClonedFromCharacter=data
lookup=obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "BP_CustomizationPreviewProxyContainer_C_9")
assert(not pcall(handoff.verify,session,owner,preview),"Direct lookup identity must match")
lookup=container; container.invalid=true
assert(not pcall(handoff.verify,session,owner,preview),"Retired container must fail")
container.invalid=false
handoff.verify(session,owner,preview)
container.IsPreviewing=false; display.ClonedFromCharacter=source; inventory={container,container}
assert(not pcall(handoff.prepare,{owner=owner,part={AssetId={}}},preview),"Fresh open must still reject ambiguity")
print("Display handoff: exact lookup, fresh links, fallback, replacement refusal, mesh/color checks and unique opening passed")
