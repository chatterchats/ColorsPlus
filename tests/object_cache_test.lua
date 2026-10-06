local scripts=assert(arg[1])
local cache_module=assert(loadfile(scripts .. "/object_cache.lua"))()
local objects,lookups={},0
local function obj(class,path)
    local o={class=class,path=path}
    function o:IsValid() if self.throws then error("native") end; return not self.invalid end
    function o:GetFullName() return self.class .. " " .. self.path end
    objects[path]=o; return o
end
local function lookup(path) lookups=lookups+1; return objects[path] end
local cache=cache_module.new(lookup)
local root=obj("UserWidget","/Engine/Transient.Root_1")

-- Without a holder every call reaches the native lookup.
assert(cache.find(root.path)==root and cache.find(root.path)==root and lookups==2)
assert(not cache.active())

-- A held scope reuses a verified exact identity.
cache.hold("picker")
lookups=0
assert(cache.find(root.path)==root and cache.find(root.path)==root and cache.find(root.path)==root)
assert(lookups==1 and cache.hits==2,"held scope must reuse the verified object")

-- Native hook boundaries drop every entry.
cache.invalidate()
assert(cache.find(root.path)==root and lookups==2,"invalidate must force a fresh lookup")

-- Invalid, throwing or renamed hits are dropped and looked up again.
root.invalid=true
local replacement=obj("UserWidget","/Engine/Transient.Root_1")
assert(cache.find(root.path)==replacement and lookups==3,"invalid hit must not be returned")
replacement.throws=true
local third=obj("UserWidget","/Engine/Transient.Root_1")
assert(cache.find(root.path)==third and lookups==4,"throwing validity check must not be returned")
third.class="Border" -- same pointer, different identity
local fourth=obj("UserWidget","/Engine/Transient.Root_1")
assert(cache.find(root.path)==fourth and lookups==5,"identity change must not be returned")

-- Missing or invalid results are returned unchanged but never stored.
assert(cache.find("/Engine/Transient.Missing")==nil and cache.find("/Engine/Transient.Missing")==nil and lookups==7)
local dead=obj("Border","/Engine/Transient.Dead"); dead.invalid=true
assert(cache.find(dead.path)==dead and cache.find(dead.path)==dead and lookups==9)

-- A lookup returning another object's name (redirect/default) is not stored.
objects["/Engine/Transient.Alias"]=fourth
assert(cache.find("/Engine/Transient.Alias")==fourth and cache.find("/Engine/Transient.Alias")==fourth and lookups==11)

-- Overlapping owners: any release starts remaining owners fresh; last release disables.
cache.hold("color-ui")
assert(cache.find(fourth.path)==fourth and lookups==11)
cache.release("picker")
assert(cache.active() and cache.find(fourth.path)==fourth and lookups==12,"release must drop entries")
assert(cache.find(fourth.path)==fourth and lookups==12)
cache.release("color-ui")
assert(not cache.active() and cache.find(fourth.path)==fourth and cache.find(fourth.path)==fourth and lookups==14)
cache.release("color-ui") -- idempotent

-- Bounded entry count.
cache.hold("picker")
for i=1,cache_module.LIMIT+10 do obj("Border","/Engine/Transient.Many_" .. i) end
for i=1,cache_module.LIMIT+10 do cache.find("/Engine/Transient.Many_" .. i) end
lookups=0
for i=1,cache_module.LIMIT+10 do cache.find("/Engine/Transient.Many_" .. i) end
assert(lookups==10,"entries beyond the limit are looked up, not stored")
cache.release("picker")

-- Entries unverified for longer than MAX_AGE_MS are never touched again.
local now=0
local aged=cache_module.new(lookup,function() return now end)
aged.hold("picker")
local slow=obj("Border","/Engine/Transient.Slow")
lookups=0
aged.find(slow.path); now=.5; aged.find(slow.path); now=1.4; aged.find(slow.path)
assert(lookups==1,"entries verified within the window stay reusable")
now=2.5
local touched=false
slow.IsValid=function() touched=true; return true end
local renewed=obj("Border","/Engine/Transient.Slow")
assert(aged.find(slow.path)==renewed and lookups==2 and not touched,"stale entries must be looked up without touching the wrapper")
aged.release("picker")

-- remember() records held objects without a lookup; pinned entries survive
-- invalidation but not release, a failed recheck or the age window.
now=0
local seeded=cache_module.new(lookup,function() return now end)
local owned=obj("Border","/Engine/Transient.Owned")
local stock=obj("Border","/Engine/Transient.Stock")
seeded.remember(owned,true) -- inactive: ignored
seeded.hold("picker")
seeded.remember(owned,true); seeded.remember(stock); seeded.remember(nil); seeded.remember(dead)
lookups=0
assert(seeded.find(owned.path)==owned and seeded.find(stock.path)==stock and lookups==0,"remembered objects need no lookup")
seeded.invalidate()
assert(seeded.find(owned.path)==owned and lookups==0,"pinned entries survive hook invalidation")
assert(seeded.find(stock.path)==stock and lookups==1,"unpinned entries are dropped by invalidation")
owned.invalid=true; local owned2=obj("Border","/Engine/Transient.Owned")
assert(seeded.find(owned.path)==owned2 and lookups==2,"pinned entries still require a live exact identity")
seeded.remember(owned2,true); now=2
local touched_pinned=false; owned2.IsValid=function() touched_pinned=true; return true end
local owned3=obj("Border","/Engine/Transient.Owned")
assert(seeded.find(owned.path)==owned3 and not touched_pinned and lookups==3,"pinned entries obey the age window")
seeded.remember(owned3,true); seeded.release("picker"); seeded.hold("picker")
assert(seeded.find(owned.path)==owned3 and lookups==4,"release drops pinned entries")
seeded.release("picker")

-- Hook registry invalidates the cache in every native callback (pre and post).
local hooks={}
RegisterHook=function(path,a,b) hooks[path]={a,b}; return 1,2 end
local runtime=assert(loadfile(scripts .. "/hook_registry.lua"))().start("ObjectCacheTestRuntime")
runtime.log=function() end
runtime.objects=cache
cache.hold("picker")
local seen
assert(runtime:hook("/Game/Test.Test_C:Event",function() seen=cache.generation end))
local before=cache.generation
hooks["/Game/Test.Test_C:Event"][1]()
assert(seen==before+1,"hook callback must run after invalidation")
assert(runtime:hook("/Script/Test.Test:Native",function() end,function() end))
before=cache.generation
hooks["/Script/Test.Test:Native"][1](); hooks["/Script/Test.Test:Native"][2]()
assert(cache.generation==before+2,"native pre and post callbacks both invalidate")
print("object_cache_test passed")
