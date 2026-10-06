local scripts=assert(arg[1])
local objects={}
local function widget(name)
    local o={}
    function o:IsValid() return true end
    function o:IsHovered() return self.hovered==true end
    function o:IsPressed() return self.pressed==true end
    function o:GetFullName() return name end
    function o:GetChildAt(i) return objects[self.children[i+1]] end
    function o:GetChildrenCount() return #self.children end
    objects[name]=o; return o
end
local pc=widget("pc"); pc.bShowMouseCursor=true
local x,y,scale=100,200,1
local unavailable=false
local lib=widget("lib")
function lib:GetMousePositionScaledByDPI(controller,a,b)
    assert(controller==objects.pc and a==b)
    a.LocationX=20; a.LocationY=20 -- frozen during every drag
    return not unavailable
end
function lib:GetMousePositionOnPlatform() return {X=x,Y=y} end
function lib:GetViewportScale() return scale end
StaticFindObject=function(path) assert(path=="/Script/UMG.Default__WidgetLayoutLibrary"); return lib end
local rows={{name="r1",cells={"c11","c12"}},{name="r2",cells={"c21","c22"}}}
for _,row in ipairs(rows) do widget(row.name); for _,name in ipairs(row.cells) do widget(name) end end
widget("grid").children={"r1","r2"}
for _,row in ipairs(rows) do objects[row.name].children=row.cells end
local logs={}
local lookups=0
local input=assert(loadfile(scripts .. "/sv_picker_input.lua"))().new({pc_name="pc",
    fresh=function(name) lookups=lookups+1; assert(name=="grid" or name=="pc","No per-row/cell global lookup"); return assert(objects[name]) end,
    log=function(s) logs[#logs+1]=s end},rows,400,240,"grid")
assert(input.read()==nil)
objects.r1.hovered=true; assert(input.read()==nil,"Hover cannot edit")
objects.c11.pressed=true
local s,v=input.read(); assert(s==0 and v==1)
local before=lookups
objects.r1.hovered=false; x,y=200,260
s,v=input.read(); assert(s==.25 and v==.75,"Desktop deltas must work with frozen viewport coords")
assert(lookups-before==2,"Held input should reacquire only grid and controller globally")
x,y=900,-100; s,v=input.read(); assert(s==1 and v==1)
x,y=200,260; s,v=input.read(); assert(s==.25 and v==.75,"Clamping must not accumulate drift")
-- Focus loss, then return while still held: do not resume a stale anchor.
unavailable=true; assert(input.read()==nil and input.held.suspended)
unavailable=false; x,y=350,280; assert(input.read()==nil)
objects.c11.pressed=false; assert(input.read()==nil and not input.held)
-- Rapid distinct presses, release, then a fresh anchor at 2x UI scale.
scale=2
objects.r2.hovered=true; objects.c22.pressed=true
s,v=input.read(); assert(s==1 and v==0)
x,y=x-200,y-120; s,v=input.read(); assert(s==.75 and v==.25)
scale=1; assert(input.read()==nil and input.held.suspended)
objects.c22.pressed=false; input.read()
objects.r2.hovered=false; objects.r1.hovered=true; objects.c12.pressed=true
input.read(); pc.bShowMouseCursor=false; assert(input.read()==nil and input.held.suspended)
pc.bShowMouseCursor=true; objects.c12.pressed=false; input.read()
-- Reacquire controller and captured cell wrappers by identity every time.
objects.c12.pressed=true; input.read()
local old=objects.c12; local replacement=widget("c12"); replacement.pressed=true
old.IsPressed=function() error("stale cell") end
local retired=objects.pc; pc=widget("pc"); pc.bShowMouseCursor=true
setmetatable(retired,{__index=function() error("stale controller") end})
x=x-40; s,v=input.read(); assert(s==.9)
-- Bad coordinates fail to caller's normal picker cleanup; never manufacture RGB.
x=0/0; assert(not pcall(input.read)); x=100
input.reset(); assert(not input.held)
objects.r1.children={"c12","c11"}
assert(not pcall(input.read),"Reordered native cells must fail identity validation")
objects.r1.children=rows[1].cells
assert(#logs==3)
print("SV picker input: captured deltas, frozen viewport, clamp, rapid presses, DPI/focus suspension and fresh identities passed")
