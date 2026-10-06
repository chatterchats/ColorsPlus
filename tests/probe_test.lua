-- Run: tools/run-tests.sh probe
local scripts = assert(arg[1], "pass probe Scripts directory")
local messages, hooks, commands, queue, cancelled = {}, {}, {}, {}, {}
local next_id, blueprint_ready, native_unhooks, console_count = 0, false, 0, 0
local original_print, original_open = print, io.open
local original_rename,original_remove,original_mod=os.rename,os.remove,ModRef
local session_files,shared={},{}
ModRef={GetSharedVariable=function(_,k) return shared[k] end,SetSharedVariable=function(_,k,v) shared[k]=v end}
print = function(line) messages[#messages + 1] = tostring(line) end
io.open = function(path,mode)
    if not (path:find("process_session_counter.txt",1,true) or path:find("recovery_session.txt",1,true)) then
        return nil,"test file disabled",2
    end
    if mode=="r" and not session_files[path] then return nil,"missing",2 end
    if mode=="w" then session_files[path]="" end
    return {read=function() return session_files[path] end,
        write=function(self,s) session_files[path]=s; return self end,
        flush=function() return true end,close=function() return true end}
end
os.rename=function(from,to)
    assert(session_files[from]~=nil and session_files[to]==nil)
    session_files[to],session_files[from]=session_files[from],nil; return true
end
os.remove=function(path) assert(session_files[path]~=nil); session_files[path]=nil; return true end
local function has(message)
    for _, line in ipairs(messages) do if line:find(message, 1, true) then return true end end
    return false
end
local function wrap(value) return {
    get = function() return value end,
    type = function() return "RemoteUnrealParam" end,
} end
local function array(values)
    return { ForEach = function(_, callback)
        for i, value in ipairs(values) do callback(i - 1, wrap(value)) end
    end }
end
local function object(fullname, fields)
    fields = fields or {}
    fields.IsValid = function(self) return not self.invalid end
    fields.GetFullName = function(self) assert(not self.invalid); return fullname end
    fields.get = function() error("arbitrary UObject unwrapped") end
    fields.SetColor = function() error("probe attempted mutation") end
    fields.SetFragmentInstances = fields.SetColor
    return fields
end
local function tags(value) return { GameplayTags = array({ { TagName = value } }) } end
local color = { R = 0.2, G = 0.04, B = 0.03, A = 1 }
local fragment = object("CustomizationFragmentInstanceMaterialColor /Engine/Transient.TestColor", {
    GetClass = function() return object("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor") end,
    GetColor = function() return color end,
    MaterialTarget = {
        MaterialParameterName = "TestAccentParameter", MaterialSlotNames = array({ "TestArmor" }),
        SlotNameTagsToApply = tags("test.torso"),
    },
})
local red = object("BitReactorCustomizationPartViewModel /Engine/Transient.TestRed", {
    DisplayName = "Red 6", AssetId = { PrimaryAssetType = { Name = "CustomizationPart" }, PrimaryAssetName = "TestRed6" },
    AllowedSlots = tags("br.Customization.Accepts.Outfit.Color"),
})
local hovered = object("BitReactorCustomizationPartViewModel /Engine/Transient.TestBlue", {
    DisplayName = "Blue 1", AssetId = { PrimaryAssetType = { Name = "CustomizationPart" }, PrimaryAssetName = "TestBlue1" },
})
local reads = 0
local slot = object("BitReactorCustomizationSlotViewModel /Engine/Transient.TestSlot", {
    DisplayName = "PRIMARY ACCENT", SlotTag = { TagName = "test.accent" },
    EquippedCustomizationPartViewModel = red,
    GetFragments = function(self) assert(not self.invalid); reads = reads + 1; return array({ fragment }) end,
    PreviewedCustomizationPartViewModel = function() return hovered end,
})
local aux = object("CustomizationAuxVM_C /Engine/Transient.TestAux", {
    CurrentCustomizationSlotVM = slot, RootCustomizationSlotVM = slot,
    CurrentCustomizationPartVM = hovered, ActiveTab = "Tops",
})
local active = true
local page = object("WBP_Customization_ItemPage_C /Engine/Transient.TestPage", {
    IsActivated = function() return active end,
})
local default_aux = object("CustomizationAuxVM_C /Game/Test.Default__CustomizationAuxVM_C", {
    CurrentCustomizationSlotVM = slot,
})
function FindAllOf(class)
    if class == "WBP_Customization_ItemPage_C" then return {page} end
    if class == "CustomizationAuxVM_C" then return {aux, default_aux} end
    error("unexpected broad scan")
end
function ExecuteInGameThread(callback) callback() end
function StaticFindObject() error("bootstrap must not look up tint objects") end
-- Match UE4SS's actual global constructor shape. Never call it at bootstrap.
local fname_constructor = newproxy(true)
getmetatable(fname_constructor).__call = function() error("bootstrap invoked FName") end
getmetatable(fname_constructor).__metatable = false
FName = fname_constructor
function RegisterHook(path, first, second)
    if path:sub(1, 6) == "/Game/" and not blueprint_ready then error("function not loaded") end
    assert(not hooks[path], "duplicate hook")
    next_id = next_id + 2
    hooks[path] = { first = first, second = second, pre = next_id - 1, post = next_id }
    return next_id - 1, next_id
end
local fail_unregister = false
function UnregisterHook(path, pre, post)
    if fail_unregister then error("test unregister failure") end
    local hook = assert(hooks[path], "unknown hook")
    assert(hook.pre == pre and hook.post == post, "both hook IDs must be retained")
    hooks[path] = nil
    native_unhooks = native_unhooks + 1
end
function MakeActionHandle() next_id = next_id + 1; return next_id end
function ExecuteInGameThreadWithDelay(handle, delay, callback)
    assert(type(delay) == "number")
    queue[handle] = callback
end
function CancelDelayedAction(handle) cancelled[handle] = true; return true end
function RegisterConsoleCommandHandler(command, callback)
    assert(not commands[command], "duplicate persistent command")
    console_count = console_count + 1
    commands[command] = callback
end
local function drain()
    local pending = queue
    queue = {}
    -- Also dispatch cancelled callbacks to exercise the stale-callback guard.
    for _, callback in pairs(pending) do callback() end
end
local function boot() return assert(loadfile(scripts .. "/main.lua"))() end
local native = "/Script/BitReactorGame.BitReactorCustomizationSlotViewModel:"
local base = "/Game/Game/UI/Strategy/Customization/Widgets/New/"
local aux_path = base .. "CustomizationAuxVM.CustomizationAuxVM_C:"
local page_path = base .. "WBP_Customization_ItemPage.WBP_Customization_ItemPage_C:"

local first = boot()
assert(commands.colors_picker, "standalone picker command must register at bootstrap")
assert(first.tint, "callable userdata FName must not disable tint actions")
assert(getmetatable(FName) == false, "match UE4SS's protected metatable")
assert(has("TINT | API presence checks passed | FName=userdata"))
drain()
assert(has("Hook pending"))
assert(has("STARTUP | REGISTER HOOK BEGIN") and has("STARTUP | REGISTER HOOK RETURN"))
assert(has("STARTUP | RUN BEGIN | startup:") and has("STARTUP | RUN END | startup:"))
assert(hooks[native .. "EquipCustomizationPart"])
assert(not hooks[aux_path .. "UpdateCurrentCustomizationSlotVM"])
blueprint_ready = true
local equip = hooks[native .. "EquipCustomizationPart"]
equip.first(wrap(slot))
assert(reads == 0, "native pre-hook must not inspect pre-equip state")
assert(equip.second(wrap(slot)) == nil, "native return value must remain untouched")
assert(reads == 0, "inspection should wait for native stack to unwind")
drain()
assert(reads==0 and not has("SNAPSHOT 1 BEGIN"),"Stock equip must not collect detailed diagnostics")
first.probe.capture_slot(slot,"explicit slot diagnostic")
assert(has("linear_rgba=0.2,0.04,0.03,1"))
assert(has("target.parameter=TestAccentParameter materials=[TestArmor] slot_tags=[test.torso]"))
assert(has("diagnostics=fragment-read-v4"))
assert(has("fragments.get.status=ok return_type=table"))
assert(has("fragments.iteration.status=ok visited=1"))
assert(has("fragments=1 material_color_instances=1"))
assert(has("event_slot.equipped.name=Red 6"))
assert(has("previewed.name=Blue 1"))
local selected = assert(hooks[aux_path .. "UpdateCurrentCustomizationSlotVM"])
assert(selected.second == nil, "Blueprint hook must use first callback argument")
local event_reads=reads
local context_events,launcher_events=0,0
local original_context,original_launcher=first.probe.on_context_event,first.color_ui.context_changed
first.probe.on_context_event=function(...) context_events=context_events+1; return original_context(...) end
first.color_ui.context_changed=function(...) launcher_events=launcher_events+1; return original_launcher(...) end
selected.first(wrap(aux))
drain()
for _,event in ipairs({"PreviewCustomizationPart","ResetPreviewedPart","ResetToDefault"}) do
    hooks[native .. event].second(wrap(slot)); drain()
end
for _,event in ipairs({"BP_OnActivated","DisplayCustomizationList"}) do
    hooks[page_path .. event].first(wrap(page)); drain()
end
assert(reads==event_reads,"Stock events and page activation must not collect snapshots")
assert(context_events==4 and launcher_events==6,"Removing snapshots must preserve context/launcher notifications")
first.probe.on_context_event,first.color_ui.context_changed=original_context,original_launcher
commands.colors_probe(); drain()
assert(has("current.name=PRIMARY ACCENT tag=test.accent"))
assert(has("selected_or_hovered.name=Blue 1"))
local before = #messages
selected.first(wrap(aux)); drain()
assert(#messages == before, "Stock selection must not emit automatic diagnostics")
first.probe.capture_aux(aux,"explicit duplicate")
assert(#messages==before,"Explicit non-forced snapshots remain deduplicated")

-- Trace before collecting fields, including duplicate snapshots and failures.
do
    local window=first.call_trace.start("snapshot regression")
    first.probe.capture_slot(slot,"trace regression")
    assert(has("BEGIN | SNAPSHOT READ capture_slot"))
    assert(has("BEGIN | SNAPSHOT READ GetFragments"))
    assert(has("RETURN | SNAPSHOT READ fragment[0].GetColor"))
    local original=fragment.GetColor
    fragment.GetColor=function() error("injected snapshot color failure",0) end
    first.probe.capture_slot(slot,"trace regression")
    assert(has("ERROR | SNAPSHOT READ fragment[0].GetColor | injected snapshot color failure"))
    assert(has("RETURN | SNAPSHOT READ capture_slot"),"diagnostic read errors remain recoverable")
    fragment.GetColor=original
    first.call_trace.stop(window,"test complete")
end

-- Invalidated captured UObjects must not be accessed when delayed work runs.
commands.colors_probe(); slot.invalid = true
local before_reads = reads
drain()
assert(reads == before_reads)
slot.invalid = nil
commands.colors_probe()
first.picker.active={session={}}
local lateAction=false
first:after("panel:open_picker",1,function() lateAction=true end)
commands.colors_picker("colors_picker",{})
assert(first.actions["panel:open_picker"],"console open uses the navigation-owned action slot")
hooks[page_path .. "BP_OnDeactivated"].first(wrap(page))
assert(not first.actions["panel:open_picker"],"page exit cancels queued console opening")
assert(not first.picker.active,"page exit must end picker ownership synchronously")
before_reads = reads; drain()
assert(reads == before_reads, "closing the page must cancel pending snapshots")
assert(not lateAction,"closing the page must cancel a queued picker-open action")
local original_boundary=first.probe.on_context_event
local boundary,identity
first.probe.on_context_event=function(reason,who)
    boundary,identity=reason,who; original_boundary(reason,who)
end
commands.colors_picker("colors_picker",{})
hooks[aux_path .. "ClearCustomizationAuxData"].first(wrap(aux))
assert(boundary=="creator closed" and not identity and not first.actions["panel:open_picker"])
local master_path="/Game/Game/UI/Strategy/Customization/Widgets/CustomCharacter/WBP_CustomCharacter_Master.WBP_CustomCharacter_Master_C:CloseMenu"
local creator=object("WBP_CustomCharacter_Master_C /Game/Test.Creator")
hooks[master_path].first(wrap(creator))
assert(boundary=="creator closed" and identity==creator:GetFullName())
first.probe.on_context_event=original_boundary

active = false
commands.colors_probe(); drain()
assert(has("No active customization item page"))
active = true
commands.colors_probe(); drain()
assert(has("auxiliary_candidates=1"), "CDO should not be captured")
assert(has("page association unverified"))

-- Pending work and console registrations across same-state reload.
selected.first(wrap(aux))
commands.colors_screens("colors_screens",{})
commands.colors_compat("colors_compat",{})
assert(first.actions["screen-trace:command"],"read-only trace command is runtime-owned")
local pending_handles = {}
for handle in pairs(queue) do pending_handles[#pending_handles + 1] = handle end
local second = boot()
assert(not first.alive and second.alive and second.generation == 2)
assert(console_count == 7,"probe, picker, performance, screen, compatibility, skin enable and panel status reuse registrations")
assert(commands.colors_perf,"Performance console dispatcher must survive same-state reload")
assert(native_unhooks == 13)
for _, handle in ipairs(pending_handles) do assert(cancelled[handle]) end
before_reads = reads; drain()
assert(reads == before_reads, "retired callbacks must remain inert")
commands.colors_probe(); drain()
assert(reads > before_reads, "persistent command must route to current runtime")

-- A cleanup failure must block replacements and retain IDs for another attempt.
fail_unregister = true
local ok, err = pcall(boot)
assert(not ok and tostring(err):find("Cleanup incomplete", 1, true))
assert(ColorsPlusProbeRuntime == second and not second.alive)
assert(next(second.hooks) ~= nil)
fail_unregister = false
local third = boot(); drain()
assert(third.generation == 3)

-- Unsupported fields are diagnostic gaps, not a reason to mutate or crash.
fragment.MaterialTarget = nil
color = nil
commands.colors_probe(); drain()
assert(has("linear_rgba=<unavailable>"))
assert(has("target.parameter=<unavailable>"))

-- Distinguish function failures, unexpected returns, and iteration failures.
-- Use fresh output for each assertion, so earlier successful reads cannot mask
-- missing diagnostics. Manual captures deliberately bypass deduplication.
local original_get = slot.GetFragments
local function capture(getter)
    messages = {}
    slot.GetFragments = getter
    commands.colors_probe(); drain()
    assert(not has("Callback failed"), "diagnostic errors must stay contained")
end
capture(function() error("test GetFragments failure\nsecond line") end)
assert(has("fragments.get.status=error error="))
assert(has("test GetFragments failure second line"))
assert(not has("fragments.iteration.status="), "do not iterate a failed return")
assert(has("fragments=<unavailable> material_color_instances=<unavailable>"))
capture(function() return nil end)
assert(has("fragments.get.status=ok return_type=nil"))
assert(has("fragments.iteration.status=error error=array is nil visited=0"))
capture(function() return { fragment } end)
assert(has("fragments.get.status=ok return_type=table"))
assert(has("fragments.iteration.status=ok visited=1 format=lua-table"))
assert(has("fragment[1].class=Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"))
assert(has("fragments=1 material_color_instances=1"), "returned UObjects must be read directly, not unwrapped")
color = { R = 0.2, G = 0.04, B = 0.03, A = 1 }
fragment.MaterialTarget = { MaterialParameterName = "TestAccentParameter", MaterialSlotNames = array({"TestArmor"}) }
capture(function() return { fragment } end)
assert(has("linear_rgba=0.2,0.04,0.03,1"))
assert(has("target.parameter=TestAccentParameter materials=[TestArmor]"))
-- The installed UE4SS array-return pusher creates RemoteUnrealParam entries,
-- not direct UObject values. Reproduce that exact table-of-wrappers shape.
capture(function() return { wrap(fragment) } end)
assert(has("fragment[1].class=Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"))
assert(has("linear_rgba=0.2,0.04,0.03,1"))
assert(has("source_ue4ss_type=RemoteUnrealParam unwrapped=true"))
capture(function() return { { type = function() return "LocalUnrealParam" end,
    get = function() return fragment end } } end)
assert(has("source_ue4ss_type=LocalUnrealParam unwrapped=true"))
assert(has("fragments=1 material_color_instances=1"))
capture(function() return { { type = function() return "RemoteUnrealParam" end,
    get = function() error("test returned wrapper failure") end } } end)
assert(has("test returned wrapper failure"))
assert(has("material_color_instances=<unavailable>"))
capture(function() return { wrap(nil) } end)
assert(has("fragment[1]=<invalid>"))
assert(has("material_color_instances=<unavailable>"))
capture(function() return { { type = function() return "UnrecognizedValue" end,
    get = function() error("unknown value was unwrapped") end } } end)
assert(has("validity.status=error"))
assert(not has("unknown value was unwrapped"))
assert(has("material_color_instances=<unavailable>"))
capture(function() return { [0] = fragment, [3] = fragment } end)
assert(has("fragment[0].class="))
assert(has("fragment[3].class="), "preserve numeric keys without assuming a dense one-based sequence")
assert(has("fragments=2 material_color_instances=2"))
capture(function() return { ReturnValue = { fragment } } end)
assert(has("unexpected array table key: ReturnValue"))
assert(not has("material_color_instances=0"))
capture(function() return {} end)
assert(has("fragments=0 material_color_instances=0"))
fragment.invalid = true
capture(function() return { wrap(fragment) } end)
assert(has("fragment[1]=<invalid>"))
assert(not has("fragment[1].class="), "invalid objects must not reach GetClass")
assert(has("material_color_instances=<unavailable>"))
assert(has("unreadable_fragments=1"))
capture(function() return { fragment } end)
assert(has("fragment[1]=<invalid>"))
assert(not has("arbitrary UObject unwrapped"))
assert(has("unreadable_fragments=1"))
fragment.invalid = nil
capture(function()
    local many = {}
    for i = 1, 65 do many[i] = fragment end
    return many
end)
assert(has("fragment[64].class="))
assert(not has("fragment[65].class="))
assert(has("fragments=65 material_color_instances=<unavailable> (truncated at 64)"))
assert(has("material_color_instances_observed=64"))
capture(function() return { ForEach = function() error("test iterator failure") end } end)
assert(has("test iterator failure"))
capture(function() return { ForEach = function(_, callback)
    callback(0, {get = function() error("test unwrap failure") end})
end } end)
assert(has("test unwrap failure"))
assert(has("visited=1"))
assert(has("material_color_instances=<unavailable>"))
capture(function() return array({}) end)
assert(has("fragments.iteration.status=ok visited=0"))
assert(has("fragments=0 material_color_instances=0"), "a readable empty array is a genuine zero")
fragment.GetColor = function() error("test GetColor failure") end
capture(original_get)
assert(has("get_color.status=error error="))
assert(has("test GetColor failure"))
assert(has("linear_rgba=<unavailable>"))
assert(not has("Callback failed"))
third:teardown()
assert(next(hooks) == nil)
assert(has("TEARDOWN | UNREGISTER BEGIN") and has("TEARDOWN | UNREGISTER RETURN"))

-- Without process provenance, even a usable UObject API must not enable tint
-- recovery/actions. Read-only hook diagnostics can still start.
local valid_mod=ModRef; ModRef=nil
local no_session=boot()
assert(not no_session.tint and no_session.tint_disabled_reason:find("ModRef unavailable",1,true))
no_session:teardown(); ModRef=valid_mod

-- Bootstrap does not inspect hidden metatables or execute constructors.
FName = setmetatable({}, { __call = function() error("bootstrap invoked FName") end })
local table_constructor = boot()
assert(table_constructor.tint and has("TINT | API presence checks passed | FName=table"))
table_constructor:teardown()
FName = function() error("bootstrap invoked FName") end
local function_constructor = boot()
assert(function_constructor.tint and has("TINT | API presence checks passed | FName=function"))
function_constructor:teardown()
for _, value in ipairs({ {}, newproxy(true) }) do
    FName = value
    local deferred = boot()
    assert(deferred.tint, "non-callable candidates are checked by game-thread actions, not bootstrap")
    deferred:teardown()
end
for _, value in ipairs({ false, "FName" }) do
    FName = value
    local unsupported = boot()
    assert(not unsupported.tint)
    assert(unsupported.tint_disabled_reason:find("FName (type=" .. type(value), 1, true))
    unsupported:teardown()
end
FName = nil
local missing_constructor = boot()
assert(not missing_constructor.tint)
assert(has("FName (type=nil; expected constructor value)"))
missing_constructor:teardown()
FName = fname_constructor

-- Missing required runtime APIs should produce an explicit inert probe.
MakeActionHandle = nil
local disabled = boot()
assert(has("Probe disabled: required UE4SS API unavailable: MakeActionHandle"))
assert(next(disabled.hooks) == nil and next(disabled.actions) == nil)
assert(not disabled.tint)
assert(disabled.tint_disabled_reason:find("MakeActionHandle (type=nil; expected function)", 1, true))
disabled:teardown()
assert(has("STARTUP | BOOTSTRAP COMPLETE"))
assert(has("SESSION | CLASSIFIED | same-process-reload"))
io.open, print = original_open, original_print
os.rename,os.remove,ModRef=original_rename,original_remove,original_mod
print("Colors+Probe: hooks, snapshots, no mutation, invalidation, reload, cleanup and fragment-read diagnostics tests passed")
