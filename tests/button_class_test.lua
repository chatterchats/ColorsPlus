local scripts=assert(arg[1])
local buttons=assert(loadfile(scripts .. "/button_class.lua"))()
local loaded,loads,logs=false,0,{}
local class={IsValid=function() return true end}
local missing={IsValid=function() return false end}
function StaticFindObject(path) assert(path==buttons.PATH); return loaded and class or missing end
local function log(s) logs[#logs+1]=s end
-- Main-menu creator: already loaded, never reloaded.
loaded=true; LoadAsset=function() loads=loads+1 end
assert(buttons.find(log)==class and loads==0 and #logs==0)
-- Hub editor: missing, loaded once on demand.
loaded=false; LoadAsset=function(path) assert(path==buttons.PATH); loads=loads+1; loaded=true end
assert(buttons.find(log)==class and loads==1 and logs[1]:find("loaded=true",1,true))
-- Failures refuse: no LoadAsset, a throwing load, or a load that finds nothing.
loaded=false; LoadAsset=nil
assert(not pcall(buttons.find,log))
LoadAsset=function() error("load failed") end
local ok,err=pcall(buttons.find,log); assert(not ok and tostring(err):find("could not be loaded",1,true))
assert(logs[#logs]:find("ok=false",1,true) and logs[#logs]:find("load failed",1,true))
LoadAsset=function() end
assert(not pcall(buttons.find))
print("Button class: loaded reuse, on-demand load and fail-closed loading passed")
