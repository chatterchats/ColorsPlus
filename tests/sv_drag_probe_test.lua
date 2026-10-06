local scripts=assert(arg[1])
local objects,jobs,commands,logs,hooks={},{},{},{},{}
local failed_remove=false
local function obj(kind,path)
    local o={kind=kind,path=path,children={},Font={}}
    function o:IsValid() return not self.dead end
    function o:GetFullName() return self.kind .. " " .. self.path end
    function o:AddChild(child)
        self.children[#self.children+1]=child; child.parent=self
        child.Slot=obj("Slot",self.path .. ".Slot" .. #self.children); return child.Slot
    end
    function o:SetText(t) self.text=t end
    function o:IsPressed() return self.pressed==true end
    function o:HasMouseCapture() return self:IsPressed() and self.capture~=false end
    function o:AddToViewport() self.viewport=true end
    function o:IsInViewport() return self.viewport==true end
    function o:RemoveFromParent() assert(not failed_remove,"removal failed"); self.viewport=false end
    function o:GetCachedGeometry() error("No native geometry marshaling") end
    for _,name in ipairs({"SetVisibility","SetColorAndOpacity","SetAnchors","SetAlignment","SetOffsets",
        "SetBackgroundColor","SetBrushColor"}) do o[name]=function(self,value) self[name .. "_arg"]=value end end
    objects[path]=o; return o
end
function StaticFindObject(path)
    if path:match("^/Script/UMG%.[A-Z]") and not path:find("Default__",1,true) then
        objects[path]=objects[path] or obj("Class",path)
    end
    return objects[path]
end
function StaticConstructObject(class,outer,name) return obj(class.path:match("%.([^%.]+)$"),outer.path .. "." .. name) end
function FindAllOf(kind) local out={}; for _,o in pairs(objects) do if o.kind==kind then out[#out+1]=o end end; return out end
FName=function(v) return v end; FText=function(v) return v end
local pc=obj("PlayerController","/Game/Test.PC"); pc.bShowMouseCursor=true
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end} end
local px,py,dpi=252,355,1
local unreadable=false
local missing_y,invalid_number,split_outputs=false,nil,false
local unavailable,frozen_x,frozen_y,bad_desktop=false,nil,nil,false
local layout=obj("WidgetLayoutLibrary","/Script/UMG.Default__WidgetLayoutLibrary")
function layout:GetMousePositionScaledByDPI(controller,x,y)
    assert(controller==pc)
    if unavailable then return false end
    assert(x==y,"Both scalar outs must share their named result table")
    if not unreadable then
        -- Match UE4SS's first-table reuse, not the old one-number-per-table mock.
        x.LocationX=invalid_number or frozen_x or px/dpi
        if not missing_y then (split_outputs and y or x).LocationY=frozen_y or py/dpi end
        x.UnrelatedNumeric=987654 -- must never be mistaken for a coordinate
    end
    return true
end
function layout:GetMousePositionOnPlatform() return {X=bad_desktop and (0/0) or (px+1000),Y=py+500} end
function layout:GetViewportScale(controller) assert(controller==pc); return dpi end
local inputlib=obj("KismetInputLibrary","/Script/Engine.Default__KismetInputLibrary")
function inputlib:PointerEvent_GetEffectingButton(event) return {KeyName=event.key} end
local binding={}; local context_ok=true
local runtime={log=function(s) logs[#logs+1]=s end,picker={},tint={},
    gradient_assets={bind=function(image) image:SetVisibility(3) end},
    color_ui={prepare_picker=function() return binding end,
        validate_picker=function(b) assert(context_ok and b==binding,"Context changed") end}}
function runtime:after(key,ms,fn) jobs[key]={ms=ms,fn=fn} end
function runtime:cancel(key) jobs[key]=nil end
function runtime:console(name,fn) commands[name]=fn end
local hook_ok=true
function runtime:hook(path,post,pre)
    assert(path=="/Script/UMG.UserWidget:OnPreviewMouseButtonDown")
    if not hook_ok then return false end
    hooks.press=pre; return true
end
local function run(key) local j=assert(jobs[key],key); jobs[key]=nil; j.fn() end
local function find(name) return assert(objects[name:match("^[^ ]+ (.+)$")]) end
local probe=assert(loadfile(scripts .. "/sv_drag_probe.lua"))().new(runtime); runtime.sv_probe=probe
probe.attach(); commands.colors_sv(nil,{"bad"}); assert(not jobs["sv-probe:command"])
commands.colors_sv(nil,{"start"}); assert(not probe.active); run("sv-probe:command")
local s=assert(probe.active); assert(s.input.presses==0 and jobs["sv-probe:timeout"].ms==90000)
local function press(key,root)
    assert(hooks.press({get=function() return root or find(probe.root_name) end},nil,
        {get=function() return {key=key or "LeftMouseButton"} end})==nil,"Must not override FEventReply")
end
-- Events from other widgets must not unwrap their pointer params.
hooks.press({get=function() return pc end},nil,{get=function() error("Unrelated event read") end})
press("RightMouseButton"); assert(s.input.presses==0)
px,py=52,235; press(); px,py=900,900
run("sv-probe:poll"); assert(s.input.s==0 and s.input.v==1 and s.input.releases==1)
assert(find(s.status).text:find("event 1",1,true))
px,py=252,355; press(); find(s.surface).pressed=true
px,py=452,475; run("sv-probe:poll"); assert(s.input.s==1 and s.input.v==0)
px,py=0,0; run("sv-probe:poll"); assert(s.input.s==0 and s.input.v==1)
find(s.surface).pressed=false; run("sv-probe:poll"); local moves=s.input.moves
px,py=252,355; run("sv-probe:poll"); assert(s.input.moves==moves,"Hover does not edit")
-- Captured controller coordinates freeze, desktop cursor continues moving.
frozen_x,frozen_y=252,355; press(); find(s.surface).pressed=true
local viewport_changes=s.viewport_changes; local desktop_changes=s.desktop_changes
px,py=352,415; run("sv-probe:poll")
assert(s.input.s==.75 and s.input.v==.25,"Desktop delta must advance a frozen-viewport drag")
assert(s.viewport_changes==viewport_changes and s.desktop_changes==desktop_changes+1)
assert(find(s.status).text:find("capture yes",1,true))
-- Losing coordinates cancels drag, not the whole probe or its timeout.
unavailable=true; run("sv-probe:poll")
assert(probe.active==s and not s.input.dragging and s.wait_release and jobs["sv-probe:timeout"])
unavailable=false; px,py=0,0; run("sv-probe:poll")
assert(s.input.s==.75 and s.input.v==.25,"Focus return while still held must not resume")
find(s.surface).pressed=false; run("sv-probe:poll"); assert(not s.wait_release)
frozen_x,frozen_y=nil,nil
px,py=252,355; press(); find(s.surface).pressed=true
dpi=2; run("sv-probe:poll"); assert(s.wait_release and not s.input.dragging,"Scale change ends current drag")
dpi=1; find(s.surface).pressed=false; run("sv-probe:poll")
-- DPI-scaled coordinates and fresh PC wrappers, no geometry dependency.
pc=obj("PlayerController",pc.path); pc.bShowMouseCursor=true
dpi=2; px,py=504,710; press(); run("sv-probe:poll"); assert(s.input.s==.5 and s.input.v==.5)
local stale=jobs["sv-probe:poll"].fn
commands.colors_sv(nil,{"stop"}); run("sv-probe:command"); assert(not probe.active and not probe.root_name)
stale(); assert(not jobs["sv-probe:poll"])
assert(probe.open()); run("sv-probe:timeout"); assert(not probe.active)
assert(probe.open()); context_ok=false; run("sv-probe:poll"); assert(not probe.active and not probe.root_name); context_ok=true
runtime.picker.active={}; assert(not probe.open()); runtime.picker.active=nil
runtime.tint.pending={}; assert(not probe.open()); runtime.tint.pending=nil
unreadable=true; assert(not probe.open() and not probe.root_name); unreadable=false
missing_y=true; assert(not probe.open() and not probe.root_name); missing_y=false
invalid_number=math.huge; assert(not probe.open() and not probe.root_name)
invalid_number=0/0; assert(not probe.open() and not probe.root_name); invalid_number=nil
bad_desktop=true; assert(not probe.open() and not probe.root_name); bad_desktop=false
split_outputs=true; assert(probe.open()); probe.close("independent output semantics"); split_outputs=false
hook_ok=false; assert(not probe.open()); hook_ok=true
assert(probe.open()); s=probe.active
unreadable=true; press(); assert(s.error and probe.active,"Event failure must defer native cleanup")
run("sv-probe:poll"); assert(not probe.active and not probe.root_name); unreadable=false
assert(probe.open()); failed_remove=true; assert(not pcall(probe.close,"test") and probe.root_name)
assert(not probe.open()); failed_remove=false; probe.close("retry"); assert(not probe.root_name)
assert(probe.open()); px,py=504,1100; press(); run("sv-probe:poll"); assert(not probe.active,"Quick Close click retained")
local owned=assert(loadfile(scripts .. "/hook_registry.lua"))().start("SVProbeCleanupTest")
local cleaned=false
owned.sv_probe={close=function(reason) assert(reason=="runtime teardown"); cleaned=true; return true end}
owned:teardown(); assert(cleaned and not owned.alive); _G.SVProbeCleanupTest=nil
print("SV probe: scoped press events, quick clicks, capture drag, DPI, fresh wrappers, failure cleanup, context and timeout passed")
