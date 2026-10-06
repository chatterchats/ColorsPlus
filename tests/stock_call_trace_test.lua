-- luajit tests/stock_call_trace_test.lua src/Colors+Probe/Scripts
local scripts = assert(arg[1])
local messages, hooks, queue, serial, mutations = {}, {}, {}, 0, 0
local game_thread = true
function RegisterHook(path, first, second)
    assert(not hooks[path], "duplicate hook")
    serial = serial + 2; hooks[path] = {first=first, second=second, pre=serial-1, post=serial}
    return serial-1, serial
end
function UnregisterHook(path, pre, post)
    assert(hooks[path].pre == pre and hooks[path].post == post); hooks[path] = nil
end
function MakeActionHandle() serial = serial + 1; return serial end
function ExecuteInGameThreadWithDelay(handle, delay, cb) queue[handle] = cb end
function CancelDelayedAction(handle) queue[handle] = nil end
local registry = assert(loadfile(scripts .. "/hook_registry.lua"))()
local runtime = registry.start("StockTraceTestRuntime")
runtime.log = function(s) messages[#messages+1] = s end
local function run(key)
    local job = assert(runtime.actions[key], key); local cb = assert(queue[job.handle])
    queue[job.handle] = nil; game_thread = true; cb()
end
local function has(s)
    for _, line in ipairs(messages) do if line:find(s,1,true) then return true end end
    return false
end
local function obj(name, fields)
    fields = fields or {}
    fields.type = function() return "UObject" end
    fields.IsValid = function(self) assert(game_thread); return not self.invalid end
    fields.GetFullName = function() return name end
    for _, method in ipairs({"PreviewPart","ResetPreview","SetColor","SetFragmentInstances","CloneFrom","RefreshCustomization"}) do
        fields[method] = function() mutations = mutations + 1; error("mutation attempted") end
    end
    return fields
end
local wrappers_live = true
local function wrap(v)
    return {type=function() return "RemoteUnrealParam" end,
        get=function() assert(wrappers_live, "expired hook argument"); return v end}
end
local world = "/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local asset = function(name) return {PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName=name} end
local tag = {TagName="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"}
local red, blue = {R=.25,G=.0075,B=.0075,A=1}, {R=0,G=.066667,B=.2,A=1}
local data_color, display_color, data_part = red, red, "Red"
local color_class = obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local function slot(name, get_color, get_part)
    local f = obj("CustomizationFragmentInstanceMaterialColor " .. world .. name .. ".Color", {
        GetClass=function() return color_class end, GetColor=get_color,
    })
    return obj("CustomizationFragmentInstanceSlot " .. world .. name .. ".Slot", {
        GetFragmentInstances=function() return {f} end,
        GetCustomizationPartPrimaryAssetId=function() return asset(get_part()) end,
    })
end
local source_actor = obj("Char_Hero_Humanoid_C " .. world .. "Char_Hero_Humanoid_C_0")
local data_actor = obj("BP_CustomizationPreviewProxyCharacter_C " .. world .. "BP_CustomizationPreviewProxyCharacter_C_1")
local source_slot = slot("Source",function() return red end,function() return "Red" end)
local data_slot = slot("Data",function() return data_color end,function() return data_part end)
local display_slot = slot("Display",function() return display_color end,function() return data_part end)
local preview = obj("CustomizationInstance " .. world .. "BP_CustomizationPreviewProxyCharacter_C_1.CustomizationInstance", {
    GetOwner=function() return data_actor end, GetSlotInstance=function() return data_slot end,
})
local owner = obj("CustomizationInstance " .. world .. "Char_Hero_Humanoid_C_0.CustomizationInstance", {
    GetPreviewCustomizationInstance=function() return preview end, GetSlotInstance=function() return source_slot end,
})
local display = obj("BP_CustomCharacter_CustomizationProxy_C /Game/Hawks.Hawks:PersistentLevel.Display", {
    ClonedFromCharacter=source_actor, DelayCustomizationRefresh=true,
})
display.CustomizationInstance = obj("CustomizationInstance /Game/Hawks.Hawks:PersistentLevel.Display.Instance", {
    GetOwner=function() return display end, GetSlotInstance=function() return display_slot end,
})
local container = obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "Container", {
    ProxyDataStorage=data_actor, ProxyCharacter=display, IsPreviewing=false, DelayProxyRefreshing=true,
})
local selected_slot = obj("BitReactorCustomizationSlotViewModel /Engine/Transient.Accent", {SlotTag=tag})
local part = obj("PartVM /Engine/Transient.Red", {AssetId=asset("Red")})
local blue_vm = obj("PartVM /Engine/Transient.Blue", {AssetId=asset("Blue")})
function FindAllOf(class)
    assert(game_thread and class == "BP_CustomizationPreviewProxyContainer_C")
    return {container}
end
local a = assert(loadfile(scripts .. "/customization_probe.lua"))().new(runtime).access
local fail_context = false
local trace = assert(loadfile(scripts .. "/stock_call_trace.lua"))().new(runtime,a,function()
    assert(game_thread); assert(not fail_context, "context unavailable")
    return {owner=owner, slot=selected_slot, page="page", part=part}
end)
assert(next(hooks) == nil)
trace.arm(); assert(trace.window and has("hooks=9/9") and has("IsPreviewing=false"))
for _, value in pairs(trace.window) do assert(type(value) ~= "table" and type(value) ~= "userdata") end
local native = assert(hooks["/Script/BitReactorCore.CustomizationInstance:PreviewPart"])
local bp_path = "/Game/Game/Cinematics/Blueprints/Hologram_Utility/BP_CustomizationPresentationFacilitator/"
local bp = assert(hooks[bp_path .. "Previews/BP_CustomizationPreviewProxyContainer.BP_CustomizationPreviewProxyContainer_C:CustomizationPrePreviewUpdated"])
local clone = assert(hooks[bp_path .. "BP_CustomizationProxyCharacter.BP_CustomizationProxyCharacter_C:CloneFrom"])
assert(native.first and native.second and bp.first and not bp.second)
assert(native.first(wrap(owner),wrap(tag),wrap(asset("Blue"))) == nil)
assert(not runtime.actions["stock:sample:50"], "native pre must not schedule settled work")
container.IsPreviewing = true
assert(bp.first(wrap(container),wrap(tag),wrap(asset("Blue"))) == nil)
display.ClonedFromCharacter = data_actor
data_color, display_color, data_part = blue, blue, "Blue"
assert(clone.first(wrap(display),wrap(data_actor),wrap(false),wrap(false),wrap(2)) == nil)
assert(native.second(wrap(owner),wrap(tag),wrap(asset("Blue"))) == nil)
trace.slot_event("PreviewCustomizationPart",wrap(selected_slot),wrap(blue_vm))
assert(has("sequence=1 | native-pre") and has("blueprint-post") and has("arg.part=CustomizationPartDefinition:Blue"))
assert(has("arg.slot=" .. tag.TagName) and has("arg.part_vm=PartVM /Engine/Transient.Blue | asset=CustomizationPartDefinition:Blue"))
assert(has("arg.show_weapon=false") and has("arg.pose=2"))
assert(trace.sequence == 5)
wrappers_live = false -- all delayed work must reacquire objects, not borrow hook args
run("stock:sample:50"); run("stock:sample:250"); run("stock:sample:1000")
assert(has("after_sequence=5") and has("settled +1000ms (coalesced)"))
assert(has("IsPreviewing=true") and has("data.accent=CustomizationPartDefinition:Blue"))
assert(not has("expired hook argument"))
wrappers_live = true
local seq = trace.sequence
native.second(wrap(obj("CustomizationInstance /Game/Other.Instance")),wrap(tag),wrap(asset("Other")))
assert(trace.sequence == seq, "unrelated native call must not be logged")
native.second(wrap(owner),{type=function() return "RemoteUnrealParam" end,get=function() error("bad tag") end},wrap(asset("Blue")))
assert(has("arg.slot.error=") and has("bad tag"))
local stale = queue[runtime.actions["stock:sample:50"].handle]
trace.stop("manual"); seq = trace.sequence
wrappers_live = false; native.second(wrap(owner)); assert(trace.sequence == seq)
trace.arm(); local samples = trace.window.samples
stale(); assert(trace.window.samples == samples, "old window must not sample new state")
wrappers_live = true
-- Hook errors preserve coverage gaps; re-arming retries missing registrations.
runtime:teardown()
local saved_native = native.second
seq = trace.sequence; saved_native(wrap(owner)); assert(trace.sequence == seq and next(hooks) == nil and next(queue) == nil)
runtime = registry.start("StockTraceTestRuntime"); runtime.log=function(s) messages[#messages+1]=s end
local register = RegisterHook
RegisterHook = function(path, ...)
    if path:find("CloneFrom",1,true) then error("Blueprint not loaded") end
    return register(path,...)
end
trace = assert(loadfile(scripts .. "/stock_call_trace.lua"))().new(runtime,a,function()
    assert(not fail_context, "context unavailable")
    return {owner=owner,slot=selected_slot,page="page",part=part}
end)
trace.arm(); assert(has("hooks=8/9") and has("HOOK UNAVAILABLE"))
RegisterHook = register
trace.arm(); assert(has("hooks=9/9"))
run("stock:expiry"); assert(not trace.window and has("60-second timeout"))
runtime.tint = {pending={}}
trace.arm(); assert(not trace.window and has("Restore the active tint"))
runtime.tint = nil
trace.arm(); fail_context=true; trace.sample("lost context",trace.sequence); fail_context=false
assert(not trace.window and has("SAMPLE FAILED"))
trace.arm()
for i=1,61 do trace.sample("bounded",i) end
assert(not trace.window and has("60-sample limit"))
trace.arm(); native=hooks["/Script/BitReactorCore.CustomizationInstance:PreviewPart"]
for i=1,161 do native.first(wrap(owner),wrap(tag),wrap(asset("Blue"))) end
assert(not trace.window and has("160-event limit"))
runtime:teardown()
assert(mutations == 0 and next(hooks) == nil and next(queue) == nil)
print("Stock call trace: native/Blueprint timing, scoped arguments, wrapper lifetime, coalescing, limits, reload and read-only checks passed")
