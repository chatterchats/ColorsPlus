-- luajit tests/tint_test.lua src/Colors+Probe/Scripts
local scripts = assert(arg[1])
local original_open = io.open
local messages, files, jobs, objects = {}, {}, {}, {}
local game_thread, fail_write, fail_refresh, fail_reset, alias_clone = true, false, false, false, false
local clone8, pages, proxy_part, proxy_mesh = true, 1, "Red", true
local fail_recovery_lookup = false
local install_behavior, refresh_behavior, fragment_read_error
local copy_on_install, reject_owned_write = true, false
local refresh_calls = 0
local color_reads, clone_writes, source_writes, resets, preview_creates = 0, 0, 0, 0, 0
local function has(s)
    for _, line in ipairs(messages) do if line:find(s, 1, true) then return true end end
    return false
end
io.open = function(path, mode)
    if mode == "r" and files[path] == nil then return nil end
    if mode == "w" and fail_write then return nil end
    if mode == "w" then files[path] = "" end
    return { read = function() return files[path] end,
        write = function(self, s)
            if reject_owned_write and s:match("\nowned\n$") then error("test installed record write failed") end
            files[path] = (files[path] or "") .. s; return self
        end,
        flush = function() return true end, close = function() return true end }
end
local runtime = {alive = true, log = function(s) messages[#messages + 1] = s end}
local last_diagnostic_timeout
function runtime:after(key, delay, cb)
    jobs[key] = {delay = delay, cb = cb}
    if key=="tint:timeout" and delay==15000 then last_diagnostic_timeout=cb end
end
function runtime:cancel(key) jobs[key] = nil end
function runtime:guard(cb) return function(...) if self.alive then return cb(...) end end end
local function run(key)
    local job = assert(jobs[key], "missing job " .. key); jobs[key] = nil
    game_thread = true; job.cb()
end
local function obj(name, fields)
    fields = fields or {}
    fields.type = function() return "UObject" end
    fields.IsValid = function(self) assert(game_thread, "off-thread UObject read"); return not self.invalid end
    fields.GetFullName = function(self) assert(not self.invalid); return name end
    fields.get = function() error("arbitrary UObject unwrapped") end
    objects[name] = fields
    return fields
end
local function wrap(value) return {type = function() return "RemoteUnrealParam" end, get = function() return value end} end
local function array(values) local out = {}; for i,v in ipairs(values) do out[i] = wrap(v) end; return out end
local function asset(name) return {PrimaryAssetType = {Name = "CustomizationPartDefinition"}, PrimaryAssetName = name} end
local function tag(s) return {TagName = s} end
local base = "br.Customization.Slot.Character.Outfit.Torso"
local owner_name = "CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.Char_Hero_Humanoid_C_0.CustomizationInstance"
local preview_name = "CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel.BP_CustomizationPreviewProxyCharacter_C_4.CustomizationInstance"
local owner, preview, source_slot, preview_slot, source, clone, slot
local original = {R = 0.08, G = 0.03, B = 0.02, A = 0.7}
local clone_color, proxy_fragment, clone_serial
clone_serial = 0
local material = { MaterialParameterName = "Color 02", MaterialSlotNames = array({"MI_TORS", "MI_ARMS"}),
    SlotNameTagsToApply = {GameplayTags = array({tag(base .. ".Mesh")})} }
local class = obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local part = obj("Part /Engine/Transient.StockRed", {AssetId = asset("Red")})
source = obj("CustomizationFragmentInstanceMaterialColor /Game/Test.Source", {
    MaterialTarget = material,
    GetClass = function() return class end,
    GetColor = function() color_reads = color_reads + 1; return original end,
    SetColor = function() source_writes = source_writes + 1; error("source mutation") end,
    GetOwningCustomizationInstance = function() return owner end,
    GetOwningCustomizationSlot = function() return source_slot end,
})
local function new_clone(initial)
clone_serial = clone_serial + 1
initial = initial or original
local own_color = {R=initial.R, G=initial.G, B=initial.B, A=initial.A}
return obj("CustomizationFragmentInstanceMaterialColor " .. preview_name:match("^[^ ]+ (.+)$") .. ".Slot.Clone_" .. clone_serial, {
    MaterialTarget = material, GetClass = function() return class end,
    GetColor = function() return own_color end,
    SetColor = function(_, value)
        assert(game_thread)
        if fail_reset and value.R == original.R then error("test restore failed") end
        clone_writes = clone_writes + 1; own_color = value; clone_color = value
        if runtime.test_set_event then runtime.test_set_event() end
    end,
    GetOwningCustomizationInstance = function() return preview end,
    GetOwningCustomizationSlot = function() return preview_slot end,
})
end
source_slot = obj("CustomizationFragmentInstanceSlot /Game/Test.SourceSlot", {
    GetFragmentInstances = function() return array({source}) end,
    GetSlotNameTag = function() return tag(base .. ".Color.Secondary") end,
    GetCustomizationPartPrimaryAssetId = function() return part.AssetId end,
})
local mesh_slot = obj("CustomizationFragmentInstanceSlot /Game/Test.MeshSlot", {
    GetCustomizationPartPrimaryAssetId = function() return asset(clone8 and "CPD_H_Outfit_Clo001_TORS_TintF" or "OtherArmor") end,
})
preview_slot = obj("CustomizationFragmentInstanceSlot /Game/Test.PreviewSlot", {
    SetFragmentInstances = function(_, values)
        assert(values[1] == clone, "direct UObject array input required")
        assert(files.recovery:match("\ninstalling\n"), "persist installation intent before setter")
        if install_behavior then install_behavior(values)
        else proxy_fragment = copy_on_install and new_clone(values[1]:GetColor()) or values[1] end
    end,
    GetFragmentInstances = function()
        if fragment_read_error then error("test fragment read failed") end
        return array({proxy_fragment})
    end,
    GetCustomizationPartPrimaryAssetId = function() return asset(proxy_part) end,
    GetSlotNameTag = function() return tag(base .. ".Color.Secondary") end,
})
local proxy_mesh_slot = obj("CustomizationFragmentInstanceSlot /Game/Test.ProxyMeshSlot", {
    GetCustomizationPartPrimaryAssetId = function() return asset(proxy_mesh and "CPD_H_Outfit_Clo001_TORS_TintF" or "OtherArmor") end,
})
preview = obj(preview_name, {
    GetSlotInstance = function(_, t)
        local name = t.TagName
        if type(name) ~= "string" then
            if fail_recovery_lookup then return nil end
            name = name:ToString()
        end
        assert(name == base .. ".Mesh" or name == base .. ".Color.Secondary", "unexpected lookup tag")
        return name == base .. ".Mesh" and proxy_mesh_slot or preview_slot
    end,
    RefreshCustomization = function()
        assert(game_thread); refresh_calls = refresh_calls + 1
        if fail_refresh then error("test refresh failed") end
        if refresh_behavior then refresh_behavior() end
    end,
})
proxy_fragment = new_clone()
local active_preview = preview
owner = obj(owner_name, {
    GetSlotInstance = function(_, t) return t.TagName == base .. ".Mesh" and mesh_slot or source_slot end,
    GetPreviewCustomizationInstance = function() return wrap(active_preview) end,
    PreviewPart = function(_, t, value)
        preview_creates = preview_creates + 1
        error("must not create or replace game-owned proxy")
    end,
    ResetPreview = function() resets = resets + 1; error("must not clear game-owned proxy") end,
})
slot = obj("BitReactorCustomizationSlotViewModel /Engine/Transient.TestSlot", {
    SlotTag = tag(base .. ".Color.Secondary"), EquippedCustomizationPartViewModel = part,
    GetFragments = function() return array({source}) end,
    CloneFragments = function(_, outer)
        assert(outer == preview_slot); clone = new_clone()
        return array({alias_clone and source or clone})
    end,
})
local aux = obj("CustomizationAuxVM_C /Engine/Transient.TestAux", {CurrentCustomizationSlotVM = slot})
local page = obj("WBP_Customization_ItemPage_C /Engine/Transient.TestPage", {IsActivated = function() return true end})
function FindAllOf(name)
    if name == "WBP_Customization_ItemPage_C" then return pages == 1 and {page} or {} end
    if name == "CustomizationAuxVM_C" then return {aux} end
    if name == "CustomizationInstance" then return {owner, preview} end
    error("unexpected class scan")
end
function StaticFindObject(path)
    for name, value in pairs(objects) do if name:match("^[^ ]+ (.+)$") == path then return value end end
end
FName = newproxy(true)
getmetatable(FName).__call = function(_, value)
    assert(game_thread)
    local name = newproxy(true)
    getmetatable(name).__index = {ToString = function() assert(game_thread); return value end}
    getmetatable(name).__metatable = false
    return name
end
getmetatable(FName).__metatable = false
local fname_constructor = FName
local probe = assert(loadfile(scripts .. "/customization_probe.lua"))().new(runtime)
local module = assert(loadfile(scripts .. "/tint_test.lua"))()
local tint = module.new(runtime, probe.access, "recovery")
tint.start()
tint.inspect()
assert(has("Target verified") and clone_writes == 0 and preview_creates == 0)
assert(has("Recovery lookup verified"))
tint.apply()
assert(has("PREVIEW APPLIED") and source_writes == 0 and clone_writes == 1)
assert(has("CHECKPOINT after-install | matches | preview=true | slot=true | part=true | fragment=true | owner=true | target=true | color=true | source=true | fragment_slot=true | passed=true"))
assert(has("CHECKPOINT after-refresh | matches | preview=true | slot=true | part=true | fragment=true | owner=true | target=true | color=true | source=true | fragment_slot=true | passed=true"))
assert(clone_color.R == 0 and clone_color.G == 1 and clone_color.B == 1 and clone_color.A == original.A)
assert(files.recovery:find("proxy-v2\n" .. owner_name .. "\n" .. preview_name .. "\n", 1, true) == 1)
assert(type(tint.pending.owner) == "string" and type(tint.pending.preview) == "string")
assert(proxy_fragment ~= clone, "default fixture must reproduce the game's copying setter")
assert(tint.pending.fragment == proxy_fragment:GetFullName() and tint.pending.phase == "owned")
assert(files.recovery:find("\n" .. proxy_fragment:GetFullName() .. "\n", 1, true))
assert(has("INSTALLED FRAGMENT TRACKED"))
assert(jobs["tint:timeout"].delay == 15000)
tint.apply(); assert(clone_writes == 1 and has("Restore the previous test first"))
tint.restore("manual"); assert(active_preview == preview and files.recovery == "" and not tint.pending)
assert(clone_color.R == original.R and clone_color.A == original.A)
assert(proxy_fragment:GetColor().R == original.R and clone:GetColor().G == 1,
    "restore the installed copy, not the submitted detached clone")

-- Also support builds/setters that retain the submitted object directly.
copy_on_install = false; tint.apply()
assert(tint.pending and proxy_fragment == clone)
assert(tint.restore("direct-install variant")); copy_on_install = true

-- The installed identity must be durable before explicit refresh.
messages = {}; reject_owned_write = true; local before_failed_persist = refresh_calls
tint.apply(); reject_owned_write = false
assert(has("test installed record write failed") and not has("CALL | RefreshCustomization"))
assert(not tint.pending and files.recovery == "" and proxy_fragment:GetColor().R == original.R)
assert(refresh_calls == before_failed_persist + 1, "only rollback refresh should run after persistence failure")

-- A copied install followed by an exception is ambiguous. Keep its journal,
-- never adopt it during rollback/reload, and block another apply.
messages = {}; jobs = {}; install_behavior = function(values)
    proxy_fragment = new_clone(values[1]:GetColor()); error("setter threw after copying")
end
local before_uncertain_writes = clone_writes
tint.apply(); install_behavior = nil
assert(has("setter threw after copying") and has("Untracked non-original fragment"))
assert(tint.pending and tint.pending.phase == "installing" and files.recovery:match("\ninstalling\n$"))
assert(clone_writes == before_uncertain_writes + 1, "do not overwrite an unverified copy")
local interrupted = module.new(runtime, probe.access, "recovery")
interrupted.start(); run("tint:recovery")
assert(interrupted.pending and has("RESTORE FAILED"))
interrupted.apply(); assert(has("Restore the previous test first"))
proxy_fragment = new_clone() -- simulate game reset/reopen without saving
assert(interrupted.restore("game reset to stock"))
tint = interrupted

-- Do not claim cleanup if refresh leaves a different cyan object installed.
messages = {}; refresh_behavior = function()
    refresh_behavior = nil; proxy_fragment = new_clone(proxy_fragment:GetColor())
end
tint.apply()
assert(has("Preview verification failed at after-refresh") and has("Untracked non-original fragment"))
assert(tint.pending and files.recovery ~= "")
proxy_fragment = new_clone(); assert(tint.restore("game reset after unknown refresh copy"))

-- Restore accepts a rebuilt live fragment only when it is already original;
-- it must not verify success solely on the detached fragment it recolored.
tint.apply(); refresh_behavior = function()
    refresh_behavior = nil; proxy_fragment = new_clone()
end
assert(tint.restore("restore rebuilt stock fragment") and not tint.pending)
tint.apply(); refresh_behavior = function()
    refresh_behavior = nil; proxy_fragment = new_clone({R=0,G=1,B=1,A=original.A})
end
assert(not tint.restore("restore left live cyan") and tint.pending)
assert(has("Restore live fragment verification failed"))
proxy_fragment = new_clone(); assert(tint.restore("reset after failed live verification"))

-- Copy adoption is not blanket permission to use any new/colored fragment.
local function bad_install(change, expected_error, cleanup)
    messages = {}; local before_refresh = refresh_calls
    install_behavior = function(values)
        proxy_fragment = new_clone(values[1]:GetColor()); change(proxy_fragment)
    end
    tint.apply(); install_behavior = nil
    assert(has("Preview verification failed at after-install") and has(expected_error))
    assert(not has("INSTALLED FRAGMENT TRACKED") and not has("CALL | RefreshCustomization"))
    assert(refresh_calls == before_refresh and tint.pending and files.recovery ~= "")
    if cleanup then cleanup() end
    proxy_fragment = new_clone(); assert(tint.restore("game reset after rejected copy"))
end
bad_install(function(f) f.GetOwningCustomizationSlot = function() return source_slot end end, "fragment_slot=false")
bad_install(function(f) f.GetOwningCustomizationInstance = function() return owner end end, "owner=false")
bad_install(function(f) f.GetClass = function() return obj("Class /Script/Test.NotColor") end end, "Checkpoint fragment is not a material color")
bad_install(function(f) f.MaterialTarget = {MaterialParameterName="Other"} end, "target=false")
bad_install(function(f) f:SetColor({R=0,G=1,B=1,A=0.1}) end, "color=false")
local original_source_get = source.GetColor
bad_install(function() source.GetColor = function() return {R=0,G=0,B=0,A=1} end end,
    "source=false", function() source.GetColor = original_source_get end)

-- A no-op setter that edits/reuses the stock object is not an adoptable copy.
messages = {}; local old_stock = proxy_fragment
install_behavior = function(values) old_stock:SetColor(values[1]:GetColor()) end
tint.apply(); install_behavior = nil
assert(has("fragment=false") and not has("INSTALLED FRAGMENT TRACKED") and tint.pending)
proxy_fragment = new_clone(); assert(tint.restore("game reset after stock reuse"))

-- Distinguish setter/no-op, refresh replacement, and an in-place color reset.
messages = {}; jobs = {}; local before_refresh = refresh_calls
install_behavior = function() end
tint.apply(); install_behavior = nil
assert(has("Preview verification failed at after-install"))
assert(has("fragment=false") and has("color=false | source=true"))
assert(has("source_linear_rgba=0.080000,0.030000,0.020000,0.700000"))
assert(refresh_calls == before_refresh and not has("CALL | RefreshCustomization"))
assert(not tint.pending and files.recovery == "" and not jobs["tint:timeout"])

messages = {}; refresh_behavior = function() proxy_fragment = new_clone() end
tint.apply(); refresh_behavior = nil
assert(has("CHECKPOINT after-install | matches | preview=true | slot=true | part=true | fragment=true"))
assert(has("Preview verification failed at after-refresh"))
assert(has("fragment=false | owner=true | target=true | color=false | source=true"))
assert(not tint.pending and files.recovery == "" and not jobs["tint:timeout"])

messages = {}; refresh_behavior = function()
    refresh_behavior = nil; proxy_fragment:SetColor(original)
end
tint.apply()
assert(has("Preview verification failed at after-refresh"))
assert(has("fragment=true | owner=true | target=true | color=false | source=true"))
assert(not tint.pending and files.recovery == "")

-- A replaced live slot must not be confused with the captured old slot.
messages = {}; local saved_slot = preview_slot
refresh_behavior = function()
    refresh_behavior = nil
    local fields = {}; for key, value in pairs(saved_slot) do fields[key] = value end
    preview_slot = obj("CustomizationFragmentInstanceSlot /Game/Test.RebuiltSlot", fields)
end
tint.apply()
assert(has("CHECKPOINT after-refresh | slot=CustomizationFragmentInstanceSlot /Game/Test.RebuiltSlot"))
assert(has("matches | preview=true | slot=false"))
assert(has("Preview verification failed at after-refresh") and not tint.pending)
preview_slot = saved_slot

-- Read failures must retain the error and still report other fields/source.
messages = {}; install_behavior = function(values)
    proxy_fragment = values[1]; fragment_read_error = true
end
tint.apply(); install_behavior = nil
assert(has("CHECKPOINT after-install | fragment_count.error=") and has("test fragment read failed"))
assert(has("source_linear_rgba=0.080000,0.030000,0.020000,0.700000"))
assert(has("RESTORE FAILED") and tint.pending and files.recovery ~= "")
fragment_read_error = nil; assert(tint.restore("read recovered"))

-- Target mismatch still logs color and source, and keeps rollback safeguards.
messages = {}; refresh_behavior = function()
    refresh_behavior = nil
    proxy_fragment.MaterialTarget = {MaterialParameterName="Other", MaterialSlotNames=material.MaterialSlotNames,
        SlotNameTagsToApply=material.SlotNameTagsToApply}
end
tint.apply()
assert(has("CHECKPOINT after-refresh | materials.error=") and has("Not the Color 02 accent target"))
assert(has("CHECKPOINT after-refresh | parameter=Other"))
assert(has("CHECKPOINT after-refresh | linear_rgba=0.000000,1.000000,1.000000,0.700000"))
assert(has("target=false | color=true | source=true") and tint.pending)
proxy_fragment.MaterialTarget = material; assert(tint.restore("target recovered"))

local function refused(setup, cleanup, expected)
    messages = {}; local before = clone_writes
    setup(); tint.apply(); cleanup()
    assert(clone_writes == before and has(expected), "missing refusal: " .. expected)
    assert(not tint.pending)
end
-- Opaque constructors are called, not inspected. Failures are refused before
-- cloning, writing a recovery record, or changing any color.
for _, value in ipairs({ {}, newproxy(true), false, function() error("constructor unavailable") end,
    function() return "None" end }) do
    local before_clones, before_record = clone_serial, files.recovery
    refused(function() FName = value end, function() FName = fname_constructor end, "Recovery FName construction failed")
    assert(clone_serial == before_clones and files.recovery == before_record)
end
refused(function() FName = nil end, function() FName = fname_constructor end, "Recovery FName construction failed")
refused(function() fail_recovery_lookup = true end, function() fail_recovery_lookup = false end, "reconstructed recovery slot")
messages = {}; FName = {}; tint.inspect(); FName = fname_constructor
assert(has("INSPECT REFUSED") and has("Recovery FName construction failed"))
refused(function() pages = 0 end, function() pages = 1 end, "Open exactly one")
refused(function() slot.SlotTag = tag(base .. ".Color.Primary") end,
    function() slot.SlotTag = tag(base .. ".Color.Secondary") end, "Select Tops")
refused(function() clone8 = false end, function() clone8 = true end, "Equip Clone 8")
refused(function() source.invalid = true end, function() source.invalid = nil end, "Required live object")
refused(function() active_preview = nil end, function() active_preview = preview end, "Required live object")
refused(function() proxy_part = "Blue" end, function() proxy_part = "Red" end, "different swatch")
refused(function() proxy_mesh = false end, function() proxy_mesh = true end, "different armor")
refused(function() fail_write = true end, function() fail_write = false end, "Cannot write tint recovery")
refused(function() alias_clone = true end, function() alias_clone = false end, "Clone aliases")
assert(active_preview == preview)
fail_refresh = true; tint.apply(); fail_refresh = false
assert(active_preview == preview and tint.pending and has("test refresh failed"))
assert(tint.restore("refresh retry"))
tint.apply(); run("tint:timeout"); assert(not tint.pending and active_preview == preview)
tint.apply(); tint.context_changed("swatch changed"); run("tint:context-restore"); assert(not tint.pending)

-- Redundant slot notifications retain only a fully verified live test and
-- never move its original timeout, write colors, or rewrite recovery.
messages = {}; tint.apply()
local retained_session, retained_timeout, retained_record = tint.pending, jobs["tint:timeout"], files.recovery
local before_notifications = clone_writes
for _ = 1, 3 do
    game_thread = false; tint.context_changed("UpdateCurrentCustomizationSlotVM")
    assert(clone_writes == before_notifications, "notification must not read/mutate on the calling thread")
    run("tint:context-restore")
    assert(tint.pending == retained_session and jobs["tint:timeout"] == retained_timeout)
    assert(files.recovery == retained_record and clone_writes == before_notifications)
end
assert(has("CONTEXT UNCHANGED") and has("existing restore deadline unchanged"))
for _, value in pairs(retained_session.context) do assert(type(value) == "string", "context retains scalar identities only") end
run("tint:timeout"); assert(not tint.pending and proxy_fragment:GetColor().R == original.R)

-- Destructive/ambiguous events win in either notification order. A coalesced
-- slot update must not suppress page-close, equip, hover, or reset cleanup.
for _, reason in ipairs({"page closed", "EquipCustomizationPart", "PreviewCustomizationPart",
    "ResetPreviewedPart", "ResetToDefault", "TileCustomizationPartWasClickedOn",
    "UpdateCurrentCustomizationPartVM", "UpdateRootCustomizationSlotVM"}) do
    for _, hard_first in ipairs({true, false}) do
        messages = {}; tint.apply()
        tint.context_changed(hard_first and reason or "UpdateCurrentCustomizationSlotVM")
        tint.context_changed(hard_first and "UpdateCurrentCustomizationSlotVM" or reason)
        run("tint:context-restore")
        assert(not tint.pending and has("context changed: " .. reason))
        assert(not has("CONTEXT UNCHANGED"))
    end
end

local function changed_context(change, reset_change, expected)
    messages = {}; tint.apply(); assert(tint.pending)
    change()
    tint.context_changed("UpdateCurrentCustomizationSlotVM"); run("tint:context-restore")
    assert(has("CONTEXT CHANGED/UNVERIFIED") and has(expected), "missing context refusal: " .. expected)
    assert(not has("CONTEXT UNCHANGED"))
    reset_change()
    if tint.pending then assert(tint.restore("context test cleanup")) end
end
changed_context(function() slot.SlotTag = tag(base .. ".Color.Primary") end,
    function() slot.SlotTag = tag(base .. ".Color.Secondary") end, "Select Tops")
local original_part_id = part.AssetId
changed_context(function() part.AssetId = asset("Blue") end,
    function() part.AssetId = original_part_id end, "Equipped accent swatch changed")
changed_context(function() clone8 = false end, function() clone8 = true end, "Equip Clone 8")
changed_context(function() proxy_mesh = false end, function() proxy_mesh = true end, "Preview armor changed")
changed_context(function() pages = 0 end, function() pages = 1 end, "Open exactly one")
local original_page = page
changed_context(function() page = obj("WBP_Customization_ItemPage_C /Engine/Transient.NewPage", {IsActivated=function() return true end}) end,
    function() page = original_page end, "Active customization page changed")
changed_context(function()
    local fields = {}; for key, value in pairs(slot) do fields[key] = value end
    aux.CurrentCustomizationSlotVM = obj("BitReactorCustomizationSlotViewModel /Engine/Transient.NewSlotVM", fields)
end, function() aux.CurrentCustomizationSlotVM = slot end, "Selected slot view model changed")
local original_find_all = FindAllOf
changed_context(function() FindAllOf = function(name)
    if name == "CustomizationAuxVM_C" then return {aux, aux} end
    return original_find_all(name)
end end, function() FindAllOf = original_find_all end, "context is missing or ambiguous")
local original_slot_get = slot.GetFragments
changed_context(function() slot.GetFragments = function() error("context source unreadable") end end,
    function() slot.GetFragments = original_slot_get end, "context source unreadable")
local context_source_color = source.GetColor
changed_context(function() source.GetColor = function() return {R=0.11,G=0.22,B=0.33,A=original.A} end end,
    function() source.GetColor = context_source_color end, "Equipped accent color/target changed")
changed_context(function() active_preview = obj(preview_name .. "Replacement", {}) end,
    function() active_preview = preview; proxy_fragment = new_clone() end, "Linked preview changed")
changed_context(function() proxy_fragment = new_clone() end, function() end, "Tracked preview fragment changed")
changed_context(function() proxy_fragment:SetColor({R=0.1,G=0.2,B=0.3,A=original.A}) end,
    function() proxy_fragment = new_clone() end, "Tracked preview color/target changed")
changed_context(function() proxy_part = "Blue" end,
    function() proxy_part = "Red"; proxy_fragment = new_clone() end, "Preview accent swatch changed")

-- Queued checks from a restored session cannot affect a subsequent preview.
tint.apply(); tint.context_changed("UpdateCurrentCustomizationSlotVM")
local stale_context_callback = jobs["tint:context-restore"].cb
assert(tint.restore("before next session")); tint.apply()
local next_session = tint.pending
stale_context_callback(); assert(tint.pending == next_session)
assert(tint.restore("after stale context callback"))

-- A recovered session has no live UI baseline; never use a notification to
-- prolong it instead of completing the existing recovery path.
tint.apply()
local context_recovery = module.new(runtime, probe.access, "recovery")
context_recovery.start(); assert(context_recovery.pending and not context_recovery.pending.context)
context_recovery.context_changed("UpdateCurrentCustomizationSlotVM"); run("tint:context-restore")
assert(not context_recovery.pending and has("No active-test context baseline"))
tint = context_recovery
tint.apply(); fail_reset = true; assert(not tint.restore("failure"))
assert(tint.pending and files.recovery ~= "")
fail_reset = false; assert(tint.restore("retry"))
tint.apply(); FName = {}; local before_constructor_failure = clone_writes
assert(not tint.restore("constructor unavailable"))
assert(tint.pending and files.recovery ~= "" and clone_writes == before_constructor_failure)
FName = fname_constructor; assert(tint.restore("constructor retry"))
tint.apply()
local replacement = obj(preview_name .. "Other", {})
active_preview = replacement
local before = resets; tint.restore("new preview")
assert(resets == before and active_preview == replacement, "do not clear another preview")
active_preview = preview
proxy_fragment = new_clone() -- game refreshed its proxy while the previous test was displaced
tint.apply()
-- Simulate a full Lua reload: recreate the module object from scalar recovery.
local reloaded = module.new(runtime, probe.access, "recovery")
reloaded.start(); assert(reloaded.pending); run("tint:recovery")
assert(active_preview == preview and files.recovery == "")
tint = reloaded
tint.apply()
proxy_fragment = new_clone()
before = clone_writes; assert(tint.restore("fragment replaced"))
assert(clone_writes == before and not tint.pending, "do not overwrite a new fragment on the same proxy")
tint.apply()
proxy_fragment:SetColor({R=0.1, G=0.2, B=0.3, A=original.A})
before = clone_writes; assert(tint.restore("external edit"))
assert(clone_writes == before and not tint.pending, "do not overwrite an external edit on the same fragment")
proxy_fragment = new_clone()
files.recovery = owner_name .. "\n" .. preview_name .. "\n"
local legacy = module.new(runtime, probe.access, "recovery")
legacy.start(); assert(legacy.blocked and not legacy.pending, "old whole-preview recovery must not reset the game's persistent proxy")
-- v1 records remain readable, but cannot silently discard an untracked cyan
-- copy left by the old probe. An invalid v2 phase is never executable recovery.
tint.apply()
local v2_record = files.recovery
files.recovery = v2_record:gsub("^proxy%-v2", "proxy-v1"):gsub("owned\n$", "")
local v1 = module.new(runtime, probe.access, "recovery")
v1.start(); run("tint:recovery"); assert(not v1.pending and files.recovery == "")
tint = v1
files.recovery = v2_record:gsub("owned\n$", "unknown-phase\n")
local invalid_phase = module.new(runtime, probe.access, "recovery")
invalid_phase.start(); assert(invalid_phase.blocked and not invalid_phase.pending)
files.recovery = "this is not executable recovery data"
local blocked = module.new(runtime, probe.access, "recovery")
blocked.start(); before = clone_writes; blocked.apply(); assert(clone_writes == before and blocked.blocked)
files.recovery = ""

-- Optional read-only diagnostics bracket the cyan experiment and restoration.
-- A failing diagnostic cannot prevent apply or owned cleanup.
local trace_calls = {}
runtime.material_trace = {
    capture = function(reason) assert(game_thread); trace_calls[#trace_calls + 1] = reason end,
    event = function(reason) trace_calls[#trace_calls + 1] = reason end,
}
tint.apply(); assert(tint.pending)
assert(trace_calls[1] == "before cyan" and trace_calls[2] == "after cyan refresh")
assert(trace_calls[3] == "cyan settled")
assert(tint.restore("trace integration"))
assert(trace_calls[4] == "after restore: trace integration")
runtime.material_trace.capture = function() error("diagnostic unavailable") end
runtime.material_trace.event = function() error("diagnostic unavailable") end
tint.apply(); assert(tint.pending)
assert(tint.restore("trace failure") and files.recovery == "")
runtime.material_trace = nil


-- The new action uses the real handoff module with the existing tint engine.
-- Old apply() must remain free of native PreviewPart/ResetPreview calls.
runtime.material_trace = nil
local world = "/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local display_path = "/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel.BP_HawksCustomizationProxyCharacter_C_0"
local source_actor = obj("Char_Hero_Humanoid_C " .. world .. "Char_Hero_Humanoid_C_0")
local data_actor = obj("BP_CustomizationPreviewProxyCharacter_C " .. world .. "BP_CustomizationPreviewProxyCharacter_C_4")
owner.GetOwner = function() return source_actor end
preview.GetOwner = function() return data_actor end
local display, display_instance, display_slot, display_color
display_color = original
local display_fragment = obj("CustomizationFragmentInstanceMaterialColor " .. display_path .. ".Color", {
    MaterialTarget=material, GetClass=function() return class end,
    GetColor=function() return display_color end,
    GetOwningCustomizationInstance=function() return display_instance end,
    GetOwningCustomizationSlot=function() return display_slot end,
})
display_slot = obj("CustomizationFragmentInstanceSlot " .. display_path .. ".Slot", {
    GetFragmentInstances=function() return array({display_fragment}) end,
    GetCustomizationPartPrimaryAssetId=function() return part.AssetId end,
})
display_instance = obj("CustomizationInstance " .. display_path .. ".CustomizationInstance", {
    GetOwner=function() return display end,
    GetSlotInstance=function(_, t)
        local name = type(t.TagName) == "string" and t.TagName or t.TagName:ToString()
        return name == base .. ".Mesh" and mesh_slot or display_slot
    end,
})
display = obj("BP_CustomCharacter_CustomizationProxy_C " .. display_path, {
    CustomizationInstance=display_instance, ClonedFromCharacter=source_actor,
})
local container = obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "BP_CustomizationPreviewProxyContainer_C_4", {
    ProxyDataStorage=data_actor, ProxyCharacter=display, IsPreviewing=false,
})
local normal_find = FindAllOf
local duplicate_container, preview_mode, reset_mode, frozen_display
FindAllOf = function(name)
    if name == "BP_CustomizationPreviewProxyContainer_C" then
        return duplicate_container and {container, container} or {container}
    end
    return normal_find(name)
end
owner.PreviewPart = function(_, t, value)
    assert(game_thread and t == slot.SlotTag and value == part.AssetId)
    assert(files.recovery:match("^proxy%-v3\n") and files.recovery:match("\nhandoff\n"),
        "handoff intent must be durable before activation")
    preview_creates = preview_creates + 1
    if preview_mode == "throw-before" then error("activation failed before switch") end
    if preview_mode == "no-op" then return end
    container.IsPreviewing = true; display.ClonedFromCharacter = data_actor
    proxy_fragment = new_clone(); display_color = original
    if preview_mode == "throw-after" then error("activation failed after switch") end
end
owner.ResetPreview = function()
    assert(game_thread and container.IsPreviewing and display.ClonedFromCharacter == data_actor)
    assert(proxy_fragment:GetColor().R == original.R, "restore color before resetting display")
    resets = resets + 1
    if reset_mode == "throw" then error("reset failed") end
    if reset_mode == "no-op" then return end
    container.IsPreviewing = false; display.ClonedFromCharacter = source_actor
    display_color = reset_mode == "wrong-color" and {R=0,G=1,B=1,A=original.A} or original
end
refresh_behavior = function()
    if container.IsPreviewing and display.ClonedFromCharacter == data_actor and not frozen_display then
        display_color = proxy_fragment:GetColor()
    end
end
messages = {}; tint.apply(true)
assert(tint.pending and tint.pending.handoff and files.recovery:match("^proxy%-v3\n"))
assert(container.IsPreviewing and display.ClonedFromCharacter == data_actor and display_color.G == 1)
run("tint:handoff-check"); assert(has("DISPLAY COLOR VERIFIED"))
run("tint:timeout"); assert(not tint.pending and not container.IsPreviewing and files.recovery == "")
assert(display.ClonedFromCharacter == source_actor and display_color.R == original.R)
-- Refuse ambiguous links and existing stock hovers without any preview/color write.
local function refused_handoff(setup, cleanup, reason)
    setup(); local calls_before, writes_before = preview_creates, clone_writes
    messages = {}; tint.apply(true)
    assert(not tint.pending and has(reason))
    assert(preview_creates == calls_before and clone_writes == writes_before)
    cleanup()
end
refused_handoff(function() duplicate_container = true end, function() duplicate_container = false end, "exactly one matched")
refused_handoff(function() container.IsPreviewing = true end, function() container.IsPreviewing = false end, "existing hover")
refused_handoff(function() display.ClonedFromCharacter = data_actor end, function() display.ClonedFromCharacter = source_actor end, "equipped character")
-- Native no-op/throw paths roll back activation without ever installing cyan.
for _, mode in ipairs({"no-op", "throw-before", "throw-after"}) do
    preview_mode = mode; messages = {}; tint.apply(true); preview_mode = nil
    assert(not tint.pending and not container.IsPreviewing and files.recovery == "")
    assert(not has("CLONE COLOR VERIFIED"))
end
-- A display that does not consume the refreshed cyan is restored at the
-- settled verification, not silently reported as a successful visible change.
frozen_display = true; tint.apply(true); assert(tint.pending)
run("tint:handoff-check"); frozen_display = false
assert(not tint.pending and has("HANDOFF VERIFICATION FAILED") and not container.IsPreviewing)
-- Reset failures preserve the v3 journal for retry/reload.
for _, mode in ipairs({"throw", "no-op"}) do
    tint.apply(true); reset_mode = mode
    assert(not tint.restore("reset failure") and tint.pending and files.recovery ~= "")
    reset_mode = nil; assert(tint.restore("retry reset"))
    assert(not container.IsPreviewing and files.recovery == "")
end
tint.apply(true); reset_mode = "wrong-color"
assert(not tint.restore("wrong display color") and tint.pending)
reset_mode = nil
assert(not tint.restore("still wrong despite restored link") and files.recovery ~= "")
display_color = original; assert(tint.restore("display fixed"))
-- Display replacement must not be reset or silently adopted.
tint.apply(true)
local original_display = container.ProxyCharacter
container.ProxyCharacter = obj("BP_CustomCharacter_CustomizationProxy_C " .. display_path .. "Other", {
    CustomizationInstance=display_instance, ClonedFromCharacter=data_actor,
})
local resets_before_replacement = resets
assert(not tint.restore("display replaced") and tint.pending and resets == resets_before_replacement)
container.ProxyCharacter = original_display; assert(tint.restore("original display restored"))
-- Stale settled-check callbacks from a completed test cannot affect a new one.
tint.apply(true); local old_check = jobs["tint:handoff-check"].cb
assert(tint.restore("end old test")); tint.apply(true)
local next_handoff = tint.pending
old_check(); assert(tint.pending == next_handoff)
assert(tint.restore("end new test"))
-- Recovery rebinds identities; no cached objects or user-visible active-test
-- baseline is necessary to undo the owned display handoff.
tint.apply(true)
local recovered_handoff = module.new(runtime, probe.access, "recovery")
recovered_handoff.start(); assert(recovered_handoff.pending.handoff)
run("tint:recovery"); assert(not recovered_handoff.pending and not container.IsPreviewing and files.recovery == "")
tint = recovered_handoff
tint.apply(true)
-- A different game swatch displaces the test. Never reset that new hover.
proxy_part = "Blue"; proxy_fragment = new_clone()
local resets_before = resets
tint.context_changed("PreviewCustomizationPart"); run("tint:context-restore")
assert(not tint.pending and resets == resets_before and container.IsPreviewing)
proxy_part = "Red"; container.IsPreviewing = false; display.ClonedFromCharacter = source_actor; display_color = original
-- Invalid v3 targets cannot become recovery writes.
files.recovery = "proxy-v3\n" .. owner_name .. "\n" .. preview_name .. "\n" .. proxy_fragment:GetFullName()
    .. "\nCustomizationPartDefinition:Red\nMI_TORS,MI_ARMS\n0.08,0.03,0.02,0.7\nowned\nbad-container\nbad-display\n"
local invalid_handoff = module.new(runtime, probe.access, "recovery")
invalid_handoff.start(); assert(invalid_handoff.blocked and not invalid_handoff.pending)
files.recovery = ""
-- Blue uses the observed slot-VM entry point and a distinct transient baseline.
local red_id, blue_id = "CPD_H_Outfit_Color_Red_14", "CPD_H_Outfit_Color_Blue_14"
local blue_color = {R=0,G=1/15,B=0.2,A=1}
original = {R=0.25,G=0.0075,B=0.0075,A=1}
part.AssetId = asset(red_id); proxy_part = red_id
proxy_fragment = new_clone(); display_color = original
local vm_outer = "/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0."
local slot_name = "BitReactorCustomizationSlotViewModel " .. vm_outer .. "BitReactorCustomizationSlotViewModel_141"
slot.GetFullName = function() return slot_name end
local vm_class = obj("Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel")
local blue_vm = obj("BitReactorCustomizationPartViewModel " .. vm_outer .. "BitReactorCustomizationPartViewModel_330", {
    AssetId=asset(blue_id), GetClass=function() return vm_class end,
})
local cached_blue = {blue_vm}
local handoff_find = FindAllOf
FindAllOf = function(name)
    if name == "BitReactorCustomizationPartViewModel" then return cached_blue end
    if name == "BitReactorCustomizationSlotViewModel" then return {slot} end
    return handoff_find(name)
end
display_slot.GetCustomizationPartPrimaryAssetId = function()
    return container.IsPreviewing and asset(proxy_part) or part.AssetId
end
owner.PreviewPart = function() error("blue test must not call owner PreviewPart") end
owner.ResetPreview = function() error("blue test must not call owner ResetPreview") end
local blue_calls, blue_resets, blue_mode = 0, 0, nil
slot.PreviewCustomizationPart = function(_, vm)
    assert(game_thread and vm == blue_vm)
    assert(files.recovery:match("^proxy%-v[45]\n") and files.recovery:match("\nhandoff\n"))
    blue_calls = blue_calls + 1
    if blue_mode == "throw-before" then error("blue failed before") end
    if blue_mode == "no-op" then return end
    proxy_part = blue_id; proxy_fragment = new_clone(blue_color)
    container.IsPreviewing = true; display.ClonedFromCharacter = data_actor
    display_color = blue_mode == "wrong-display" and original or blue_color
    if blue_mode == "throw-after" then error("blue failed after") end
end
slot.ResetPreviewedPart = function()
    assert(game_thread and proxy_part == blue_id)
    local c = proxy_fragment:GetColor()
    assert(c.R == 0 and c.G == blue_color.G and c.B == blue_color.B and c.A == 1,
        "restore transient blue baseline before slot reset")
    blue_resets = blue_resets + 1
    if reset_mode == "throw" then error("slot reset failed") end
    if reset_mode == "no-op" then return end
    proxy_part = red_id; proxy_fragment = new_clone()
    container.IsPreviewing = false; display.ClonedFromCharacter = source_actor
    display_color = original
end
messages = {}; tint.apply("blue")
assert(tint.pending and tint.pending.blue and has("BLUE BASELINE VERIFIED"))
assert(tint.pending.part == "CustomizationPartDefinition:" .. red_id and tint.pending.original.R == 0.25)
assert(tint.pending.blue.part == "CustomizationPartDefinition:" .. blue_id and proxy_part == blue_id)
assert(part.AssetId.PrimaryAssetName == red_id and display_color.G == 1)
assert(tint.pending.fragment == proxy_fragment:GetFullName() and proxy_fragment ~= clone)
run("tint:handoff-check"); assert(tint.pending)
run("tint:timeout")
assert(not tint.pending and files.recovery == "" and proxy_part == red_id and display_color == original)
assert(blue_calls == 1 and blue_resets == 1)
-- No-op/throws/mismatched display must never reach cyan; after-switch failures
-- restore the known stock blue and reset through the slot VM.
for _, mode in ipairs({"no-op","throw-before","throw-after","wrong-display"}) do
    blue_mode = mode; messages = {}; tint.apply("blue"); blue_mode = nil
    assert(not has("CLONE COLOR VERIFIED"))
    assert(not tint.pending and files.recovery == "" and not container.IsPreviewing)
    assert(proxy_part == red_id and display_color == original)
end
-- Cache ambiguity and unsupported source alpha are rejected before activation.
local before_blue = blue_calls
for _, cache in ipairs({{}, {blue_vm,blue_vm}}) do
    cached_blue = cache; messages={}; tint.apply("blue")
    assert(not tint.pending and blue_calls == before_blue and has("Expected one cached"))
end
cached_blue = {blue_vm}; original.A = 0.7; proxy_fragment = new_clone(); messages={}; tint.apply("blue")
assert(not tint.pending and blue_calls == before_blue and has("opaque equipped accent"))
original.A = 1; proxy_fragment = new_clone()
-- Blue journal recovery rebinds the exact slot and preserves source red.
tint.apply("blue"); local blue_record = files.recovery
assert(tint.pending and blue_record:match("^proxy%-v4\n"))
local recovered_blue = module.new(runtime, probe.access, "recovery")
recovered_blue.start(); assert(recovered_blue.pending and recovered_blue.pending.blue)
run("tint:recovery")
assert(not recovered_blue.pending and proxy_part == red_id and display_color == original and files.recovery == "")
tint = recovered_blue
-- Bad v4 asset, color, slot or field count cannot trigger any recovery writes.
for _, bad in ipairs({
    blue_record:gsub(blue_id, "CPD_H_Outfit_Color_Blue_99"),
    blue_record:gsub("\n0,0%.066[^\n]+", "\n0,2,0.2,1"),
    blue_record:gsub("BitReactorCustomizationSlotViewModel_141", "Default__Slot"),
    blue_record .. "extra\n",
}) do
    files.recovery = bad
    local invalid = module.new(runtime, probe.access, "recovery")
    invalid.start(); assert(invalid.blocked and not invalid.pending)
end
files.recovery = ""
-- Failed slot resets retain the journal and retry without native-owner fallback.
for _, mode in ipairs({"throw","no-op"}) do
    tint.apply("blue"); reset_mode = mode
    assert(tint.pending and not tint.restore("slot reset failure") and files.recovery ~= "")
    reset_mode = nil; assert(tint.restore("retry slot reset"))
    assert(not tint.pending and files.recovery == "" and display_color == original)
end
-- A replacement stock hover is game-owned and must not be reset.
tint.apply("blue"); local before_reset = blue_resets
proxy_part = "Other"; proxy_fragment = new_clone(original)
tint.context_changed("PreviewCustomizationPart"); run("tint:context-restore")
assert(not tint.pending and blue_resets == before_reset and container.IsPreviewing)
-- Arbitrary RGB follows the same blue handoff, but tracks its actual target
-- through display checks, context notifications, timeout and cold recovery.
proxy_part = red_id; proxy_fragment = new_clone()
container.IsPreviewing = false; display.ClonedFromCharacter = source_actor; display_color = original
local rgb_module = assert(loadfile(scripts .. "/rgb_input.lua"))()
for _, input in ipairs({"255,128,32", "160,64,224", "64,208,112", "0,0,0", "255,255,255"}) do
    files["rgb.txt"] = input; messages = {}; tint.apply_rgb()
    local intended = rgb_module.parse(input)
    assert(tint.pending and tint.pending.test_color and files.recovery:match("^proxy%-v5\n"))
    assert(has("RGB INPUT | srgb_255=" .. input) and has("PREVIEW APPLIED | custom_linear_rgba="))
    for _, k in ipairs({"R","G","B","A"}) do assert(math.abs(display_color[k]-intended[k]) < 1e-9) end
    assert(part.AssetId.PrimaryAssetName == red_id and source_writes == 0)
    local active = tint.pending
    files["rgb.txt"] = "bad edit during test"
    tint.apply_rgb(); assert(tint.pending == active, "second click must not replace owned RGB")
    tint.context_changed("UpdateCurrentCustomizationSlotVM"); run("tint:context-restore")
    assert(tint.pending == active)
    run("tint:handoff-check"); assert(tint.pending == active)
    run("tint:timeout")
    assert(not tint.pending and proxy_part == red_id and display_color == original and files.recovery == "")
end
-- Invalid/missing configuration cannot invoke blue or touch the recovery file.
local before_rgb = blue_calls
for _, input in ipairs({"", "256,0,0", "1,2,3,4", "1,,2,3", "NaN,2,3"}) do
    files["rgb.txt"] = input; messages={}; tint.apply_rgb()
    assert(not tint.pending and blue_calls == before_rgb and has("RGB APPLY REFUSED") and files.recovery == "")
end
files["rgb.txt"] = nil; tint.apply_rgb(); assert(blue_calls == before_rgb)
-- v5 recovery depends on the journal, never on the currently edited RGB file.
files["rgb.txt"] = "160,64,224"; tint.apply_rgb()
local rgb_record = files.recovery
assert(tint.pending and tint.pending.test_color)
files["rgb.txt"] = "0,255,0"
local recovered_rgb = module.new(runtime, probe.access, "recovery")
recovered_rgb.start(); assert(recovered_rgb.pending and recovered_rgb.pending.test_color)
run("tint:recovery")
assert(not recovered_rgb.pending and files.recovery == "" and display_color == original)
tint = recovered_rgb
for _, last in ipairs({"2,0,0,1", "nan,0,0,1", "0,0,0,0.5", "0,,0,0,1", "0,0,0,1,1"}) do
    files.recovery = rgb_record:gsub("[^\n]+\n$", last .. "\n")
    local invalid = module.new(runtime, probe.access, "recovery")
    invalid.start(); assert(invalid.blocked and not invalid.pending)
end
files.recovery = ""
-- Activation failure and failed reset retain the existing blue cleanup rules.
files["rgb.txt"] = "255,128,32"; blue_mode = "throw-after"; messages={}; tint.apply_rgb(); blue_mode=nil
assert(not tint.pending and not has("CLONE COLOR VERIFIED") and files.recovery == "")
tint.apply_rgb(); reset_mode="throw"
assert(tint.pending and not tint.restore("RGB reset failure") and files.recovery ~= "")
reset_mode=nil; assert(tint.restore("RGB reset retry") and files.recovery == "")
-- Stale callbacks from a previous RGB test cannot restore a newer one.
tint.apply_rgb(); local stale_rgb = jobs["tint:handoff-check"].cb
assert(tint.restore("finish orange"))
files["rgb.txt"]="64,208,112"; tint.apply_rgb(); local next_rgb=tint.pending
stale_rgb(); assert(tint.pending == next_rgb)
assert(tint.restore("finish green") and files.recovery == "")
-- Cycle: one stock activation and installed fragment, three five-second holds.
files["rgb.txt"]="255,128,32"; messages={}
local cycle_calls, cycle_resets = blue_calls, blue_resets
tint.cycle_rgb()
local cycle_session = assert(tint.pending)
local cycle_fragment = proxy_fragment
assert(cycle_session.cycle.index == 1 and jobs["tint:rgb-cycle"].delay == 5000)
assert(jobs["tint:timeout"].delay == 20000)
local watchdog = jobs["tint:timeout"]
local stale_step = jobs["tint:rgb-cycle"].cb
local stale_first_check = jobs["tint:handoff-check"].cb
run("tint:handoff-check")
files["rgb.txt"]="not valid during cycle"
for i, input in ipairs({"160,64,224", "64,208,112"}) do
    local chosen = rgb_module.parse(input)
    run("tint:rgb-cycle")
    assert(tint.pending == cycle_session and cycle_session.cycle.index == i+1)
    assert(proxy_fragment == cycle_fragment and blue_calls == cycle_calls+1 and blue_resets == cycle_resets)
    assert(jobs["tint:rgb-cycle"].delay == 5000 and jobs["tint:timeout"] == watchdog)
    for _, k in ipairs({"R","G","B","A"}) do assert(math.abs(display_color[k]-chosen[k]) < 1e-9) end
    assert(files.recovery:match("^proxy%-v5\n") and not cycle_session.previous_color)
    run("tint:handoff-check")
    stale_step(); stale_first_check()
    assert(tint.pending == cycle_session and cycle_session.cycle.index == i+1)
end
run("tint:rgb-cycle")
assert(not tint.pending and files.recovery == "" and display_color == original and blue_resets == cycle_resets+1)
assert(not jobs["tint:rgb-cycle"] and not jobs["tint:timeout"] and not jobs["tint:handoff-check"])
-- Manual restore invalidates callbacks; old closures cannot affect a new cycle.
files["rgb.txt"]="255,128,32"; tint.cycle_rgb()
local cancelled_step = jobs["tint:rgb-cycle"].cb
assert(tint.restore("manual cycle stop") and not jobs["tint:rgb-cycle"])
tint.cycle_rgb(); local next_cycle=tint.pending
cancelled_step(); assert(tint.pending == next_cycle and next_cycle.cycle.index == 1)
assert(tint.restore("finish next cycle"))
-- Context events stop before a queued color step can write.
tint.cycle_rgb()
tint.context_changed("page closed")
run("tint:rgb-cycle")
assert(not tint.pending and not jobs["tint:rgb-cycle"] and files.recovery == "")
run("tint:context-restore"); assert(not tint.pending)
-- If the display doesn't consume a new color, its settled check stops cycling.
tint.cycle_rgb(); run("tint:handoff-check")
frozen_display=true; run("tint:rgb-cycle"); run("tint:handoff-check"); frozen_display=false
assert(not tint.pending and not jobs["tint:rgb-cycle"] and display_color == original)
-- Watchdog does not depend on successful step scheduling.
tint.cycle_rgb(); run("tint:timeout")
assert(not tint.pending and not jobs["tint:rgb-cycle"] and files.recovery == "")
-- Transition journal is durable before the in-place write. Capture it and
-- test recovery on both sides of SetColor (old and next color).
tint.cycle_rgb()
local owned_fragment = proxy_fragment
local normal_set = owned_fragment.SetColor
local transition_record, before_color = nil, owned_fragment:GetColor()
owned_fragment.SetColor = function(self, value)
    assert(files.recovery:match("^proxy%-v6\n"), "transition intent must precede in-place write")
    transition_record = files.recovery
    return normal_set(self,value)
end
run("tint:rgb-cycle"); owned_fragment.SetColor=normal_set
assert(transition_record and tint.pending and files.recovery:match("^proxy%-v5\n"))
local after_color = owned_fragment:GetColor()
for _, during in ipairs({before_color, after_color}) do
    -- Simulate a cold reload: discard old runtime work, retain exact objects.
    normal_set(owned_fragment,during); proxy_fragment=owned_fragment; proxy_part=blue_id
    container.IsPreviewing=true; display.ClonedFromCharacter=data_actor; display_color=during
    files.recovery=transition_record; jobs={}
    local recovery = module.new(runtime, probe.access, "recovery")
    recovery.start()
    assert(recovery.pending and recovery.pending.previous_color and not recovery.pending.cycle)
    run("tint:recovery")
    assert(not recovery.pending and display_color == original and files.recovery == "" and not jobs["tint:rgb-cycle"])
    tint=recovery
end
-- Malformed transitional old color or phase cannot authorize recovery.
for _, invalid_record in ipairs({
    transition_record:gsub("[^\n]+\n$", "2,0,0,1\n"),
    transition_record:gsub("[^\n]+\n$", "0,0,0,0.5\n"),
    transition_record:gsub("[^\n]+\n$", "0,,0,0,1\n"),
    (transition_record:gsub("\nowned\n", "\nprepared\n")),
}) do
    files.recovery=invalid_record
    local invalid=module.new(runtime, probe.access, "recovery")
    invalid.start(); assert(invalid.blocked and not invalid.pending)
end
files.recovery=""
-- Failure before or after an in-place setter write restores either accepted
-- transition color and does not schedule another stage.
for _, mode in ipairs({"before", "after"}) do
    tint.cycle_rgb(); local f=proxy_fragment; local setter=f.SetColor; local once=true
    f.SetColor=function(self,value)
        if once then
            once=false
            if mode == "after" then setter(self,value) end
            error("injected cycle setter failure")
        end
        return setter(self,value)
    end
    run("tint:rgb-cycle")
    assert(not tint.pending and files.recovery == "" and not jobs["tint:rgb-cycle"] and display_color == original)
end
-- Interactive lifetime reuses the same journaled in-place updates, with a
-- no elapsed-time expiry; diagnostic expiry cannot close a live draft.
-- Clean tester installs omit developer inputs. Even an old/malformed file
-- must not seed the picker or stop it from opening on the selected color.
do
    local saved_open=io.open
    local reads=0
    io.open=function(path,mode)
        if path:match("rgb%.txt$") then reads=reads+1; error("Picker must not read developer RGB input") end
        return saved_open(path,mode)
    end
    for _,value in ipairs({false,"malformed RGB","0,255,0"}) do
        files["rgb.txt"]=value or nil
        local s=assert(tint.begin_live(),table.concat(messages,"\n"))
        assert(s.test_color.R==original.R and s.test_color.G==original.G and s.test_color.B==original.B)
        assert(tint.restore("initial color regression"))
    end
    assert(reads==0)
    io.open=saved_open
end
files["rgb.txt"]=nil
local live=assert(tint.begin_live())
assert(live.live and not live.cycle and not jobs["tint:timeout"])
last_diagnostic_timeout(); assert(tint.pending==live and live.live,"A cancelled diagnostic timer cannot expire the live draft")
local live_fragment=proxy_fragment
assert(tint.check_live(live))
local first_live_check=jobs["tint:handoff-check"].cb
for _,input in ipairs({"160,64,224","64,208,112","8,127,243"}) do
    assert(tint.update_live(live,rgb_module.parse(input)))
    assert(not jobs["tint:timeout"] and proxy_fragment==live_fragment)
    assert(tint.check_live(live) and files.recovery:match("^proxy%-v5\n"))
    run("tint:handoff-check")
end
first_live_check(); assert(tint.pending==live)
for _=1,400 do assert(tint.check_live(live) and tint.pending==live and not jobs["tint:timeout"]) end
assert(tint.restore("picker Cancel"))
assert(not tint.pending and not live.live and display_color==original and files.recovery=="")
assert(not tint.update_live(live,rgb_module.parse("255,0,0")) and not tint.check_live(live))
live=assert(tint.begin_live()); assert(tint.restore("picker Cancel") and not live.live)
assert(not tint.update_live(live,rgb_module.parse("1,2,3")))
live=assert(tint.begin_live())
tint.context_changed("page closed")
assert(not tint.check_live(live))
run("tint:context-restore"); assert(not tint.pending and not live.live)
live=assert(tint.begin_live()); assert(tint.update_live(live,rgb_module.parse("8,127,243")))
local live_recovery=module.new(runtime,probe.access,"recovery")
live_recovery.start(); assert(live_recovery.pending and not live_recovery.pending.live)
run("tint:recovery"); assert(not live_recovery.pending and files.recovery=="")
tint=live_recovery
live=assert(tint.begin_live())
assert(not tint.update_live(live,{R=2,G=0,B=0,A=1}) and not tint.pending)
assert(source_writes == 0)

-- v0.2.18 integration: temporary editor selection -> REAL regular tint engine
-- v0.2.27: real dynamic palette, measured donor baseline, display and recovery.
do
    local session=assert(tint.begin_live())
    local calls_before=refresh_calls
    runtime.test_set_event=function() runtime.test_set_event=nil; active_preview=replacement end
    assert(not tint.update_live(session,rgb_module.parse("41,51,61")))
    assert(refresh_calls==calls_before,"Never refresh the old preview after SetColor replaces the link")
    assert(not tint.pending and files.recovery=="")
    active_preview=preview
    proxy_part=red_id; proxy_fragment=new_clone(); container.IsPreviewing=false
    display.ClonedFromCharacter=source_actor; display_color=original
end
do
    local saved={base=base,page=page,find=FindAllOf,preview_get=preview.GetSlotInstance,owner_get=owner.GetSlotInstance,
        source_tag=source_slot.GetSlotNameTag,preview_tag=preview_slot.GetSlotNameTag,
        part_name=part.GetFullName,part_class=part.GetClass,activate=slot.PreviewCustomizationPart,reset=slot.ResetPreviewedPart,
        display_get=display_instance.GetSlotInstance,horn_tag="br.Customization.Slot.Character.Horns.Mesh"}
    local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
    page=obj("WBP_Customization_ItemPage_C " .. host .. ".WBP_Customization_ItemPage_C_19",{IsActivated=function() return true end})
    local master=obj("WBP_CustomCharacter_Master_C " .. host .. ".WBP_CustomCharacter_Master_C_18")
    local parent=obj("CanvasPanel /Game/Test.Parent")
    obj("BitReactorActivatableWidgetStack " .. host .. ".GameLayer_Stack",{
        WidgetList=array({master,page}),GetActiveWidget=function() return page end,GetParent=function() return parent end})
    part.GetFullName=function() return "BitReactorCustomizationPartViewModel " .. vm_outer .. "BitReactorCustomizationPartViewModel_331" end
    part.GetClass=function() return vm_class end
    local function text_tag(t) return type(t.TagName)=="string" and t.TagName or t.TagName:ToString() end
    source_slot.GetSlotNameTag=function() return slot.SlotTag end
    preview_slot.GetSlotNameTag=function() return slot.SlotTag end
    mesh_slot.GetSlotNameTag=function() return tag(base .. ".Mesh") end
    proxy_mesh_slot.GetSlotNameTag=mesh_slot.GetSlotNameTag
    saved.horn=obj("CustomizationFragmentInstanceSlot /Game/Test.Horns",{
        GetSlotNameTag=function() return tag(saved.horn_tag) end,
        GetCustomizationPartPrimaryAssetId=function() return asset("HornsA") end})
    owner.GetSlotInstance=function(_,t)
        if text_tag(t)==saved.horn_tag and saved.horn_tag~=base .. ".Mesh" then return saved.horns_enabled and saved.horn or nil end
        return text_tag(t)==base .. ".Mesh" and mesh_slot or source_slot
    end
    preview.GetSlotInstance=function(_,t)
        if text_tag(t)==saved.horn_tag and saved.horn_tag~=base .. ".Mesh" then return saved.horns_enabled and not saved.proxy_horns_missing and saved.horn or nil end
        local n=text_tag(t); assert(n==base .. ".Mesh" or n==slot.SlotTag.TagName)
        return n==base .. ".Mesh" and proxy_mesh_slot or preview_slot
    end
    display_instance.GetSlotInstance=function(self,t)
        if text_tag(t)==saved.horn_tag and saved.horn_tag~=base .. ".Mesh" then return saved.horns_enabled and not saved.display_horns_missing and saved.horn or nil end
        return saved.display_get(self,t)
    end
    local palette={part,blue_vm}
    local grid=obj("BitReactorTileView /Game/Test.DynamicGrid",{
        GetNumItems=function() return #palette end,GetItemAt=function(_,i) return palette[i+1] end,
        GetIndexForItem=function(_,v) for i,item in ipairs(palette) do if item==v then return i-1 end end end})
    local tiles=obj("WBP_Customization_SelectionTiles_C /Game/Test.DynamicTiles",{
        PartsGridList=grid,IsVisible=function() return true end,GetParent=function() return page end})
    local duplicate=false
    local panel=obj("WBP_CustomizationSlotPanel_C /Game/Test.DynamicPanel",{
        WBP_Customization_SelectionTiles=tiles,IsVisible=function() return true end})
    page.WBP_CustomizationSlotPanel=panel
    page.SlotWidgetSwitcher=obj("CommonActivatableWidgetSwitcher /Game/Test.DynamicSwitcher",{GetActiveWidget=function() return panel end})
    local stale=obj("WBP_Customization_SelectionTiles_C /Game/Test.StaleTiles",{
        PartsGridList=obj("BitReactorTileView /Game/Test.StaleGrid"),IsVisible=function() return true end,GetParent=function() return nil end})
    FindAllOf=function(c)
        if c=="WBP_Customization_SelectionTiles_C" then return duplicate and {stale,tiles} or {tiles} end
        return saved.find(c)
    end
    local donor_color={R=.13,G=.27,B=.39,A=1}; local mode
    slot.PreviewCustomizationPart=function(_,vm)
        assert(vm==blue_vm and files.recovery:match("^proxy%-v[78]\n") and files.recovery:match("\npending\n"))
        if mode=="before" then error("before donor activation") end
        if mode=="no-op" then return end
        proxy_part=blue_vm.AssetId.PrimaryAssetName; proxy_fragment=new_clone(donor_color)
        container.IsPreviewing=true; display.ClonedFromCharacter=data_actor; display_color=donor_color
        if mode=="after" then error("after donor activation") end
        if mode=="wrong-display" then display_color=original end
    end
    slot.ResetPreviewedPart=function()
        if reset_mode=="throw" then error("dynamic reset interrupted") end
        assert(proxy_fragment:GetColor().R==donor_color.R,"Restore measured baseline, not hardcoded Blue_14")
        proxy_part=part.AssetId.PrimaryAssetName; proxy_fragment=new_clone()
        container.IsPreviewing=false; display.ClonedFromCharacter=source_actor; display_color=original
    end
    runtime.generic_colors=true
    for _,case in ipairs({
        {"br.Customization.Slot.Character.Outfit.Legs","Color 04","MI_LEGS","CPD_H_Outfit_Color_Test"},
        {"br.Customization.Slot.Character.Horns","Skin Coloration","MI_Horns","CPD_H_HornsColor_Zabrak_02",
            nil,nil,"br.Customization.Slot.Character.Horns.Color"},
        {"br.Customization.Slot.Character.Hair.Hair","Root Color","MI_Hair","CPD_H_Human_Hair_Color_Test"},
        {"br.Customization.Slot.Character.Appearance.Humanoid.Head.Face","Lipstick Color","MI_Head","CPD_H_Makeup_Color_Test"},
        {"br.Customization.Slot.Character.Appearance.Humanoid.Head.Face","Tattoo Color","MI_Head","CPD_H_Tattoo_Color_Test",
            "br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color",false},
        {"br.Customization.Slot.Character.Appearance.Humanoid.Head.Face","Tattoo Color","MI_Head","CPD_H_Tattoo_Color_Test",
            "br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color",true},
    }) do
        base=case[1]; slot.SlotTag=tag(case[7] or case[5] or base .. ".Color.Primary"); saved.horns_enabled=case[6]
        material.MaterialParameterName=case[2]; material.MaterialSlotNames=array({case[3]})
        material.SlotNameTagsToApply.GameplayTags=array({tag(base .. ".Mesh")})
        if case[5] then material.SlotNameTagsToApply.GameplayTags=array({tag(base .. ".Mesh"),tag(saved.horn_tag)}) end
        tiles.CurrentSlotTag=slot.SlotTag; stale.CurrentSlotTag=slot.SlotTag
        -- Real failure: Aux remains at Style while the simple panel displays
        -- hair/lipstick Color. The default wrapper and tint engine must agree.
        slot.CustomizationChildSlotViewModels=array({})
        case.style=obj("BitReactorCustomizationSlotViewModel " .. vm_outer .. "BitReactorCustomizationSlotViewModel_401",{
            SlotTag=tag(base .. ".Mesh"),CustomizationChildSlotViewModels=array({slot}),
            GetFragments=function() error("Must not read Style fragments") end})
        aux.RootCustomizationSlotVM=obj("BitReactorCustomizationSlotViewModel " .. vm_outer .. "BitReactorCustomizationSlotViewModel_400",{
            SlotTag=tag(base),CustomizationChildSlotViewModels=array({case.style,slot})})
        aux.CurrentCustomizationSlotVM=case[2]=="Color 04" and slot or case.style
        blue_vm.AssetId=asset(case[4]); clone8=false; proxy_mesh=false -- not Clone 8
        messages={}; local g=module.new(runtime,probe.access,"recovery")
        duplicate=true -- attached live palette beats unparented stale palette
        local s=assert(assert(loadfile(scripts .. "/default_selection.lua"))().wrap(runtime,probe.access,"selection",g,g).begin_live(),table.concat(messages,"\n"))
        assert(files["rgb.txt"]==nil and s.test_color.R==original.R and s.test_color.G==original.G and s.test_color.B==original.B,
            "Armor, horn and appearance pickers must start from the selected color without a developer input file")
        if case[2]~="Color 04" then assert(has("COLOR SLOT | RESOLVED DISPLAYED")) end
        assert(s.profile.parameter==case[2] and s.profile.asset=="CustomizationPartDefinition:OtherArmor")
        assert(s.blue.original.R==donor_color.R and not s.blue.pending_baseline and source_writes==0)
        case.perf_find,case.perf_scans=FindAllOf,0
        FindAllOf=function(class)
            if class=="WBP_Customization_ItemPage_C" or class=="CustomizationAuxVM_C" then case.perf_scans=case.perf_scans+1 end
            return case.perf_find(class)
        end
        assert(g.update_live(s,rgb_module.parse("17,91,231")))
        assert(case.perf_scans==0,"Each supported color draft must reuse opening discovery on its first update")
        case.perf_scans=0
        assert(g.update_live(s,rgb_module.parse("18,92,232")))
        assert(case.perf_scans==0,"Warm color draft must freshly validate without global discovery")
        assert(g.check_live(s)); assert(g.check_live(s))
        run("tint:handoff-check")
        assert(case.perf_scans==0,"Armor and appearance idle/handoff checks must reuse the validated draft route")
        case.perf_scans=0
        runtime.test_set_event=function() runtime.test_set_event=nil; g.context_changed("UpdateCurrentCustomizationSlotVM") end
        assert(g.update_live(s,rgb_module.parse("19,93,233")))
        assert(case.perf_scans==0,"A non-structural event keeps the fully revalidated lookup hint")
        g.invalidate_context_lookup("UpdateRootCustomizationSlotVM")
        assert(g.update_live(s,rgb_module.parse("20,94,234")))
        assert(case.perf_scans==2,"A structural event must force fresh discovery")
        case.perf_scans=0
        assert(g.update_live(s,rgb_module.parse("21,95,235")))
        assert(case.perf_scans==0,"Next update may reuse the fresh post-event discovery")
        FindAllOf=case.perf_find
        run("tint:handoff-check"); assert(g.pending)
        local record=files.recovery
        if case[5] then
            assert(record:match("^proxy%-v8\n") and #s.profile.targets==2)
            assert(s.profile.targets[2].asset==(case[6] and "CustomizationPartDefinition:HornsA" or "-"))
            saved.horns_enabled=not case[6]
            assert(not g.check_live(s),"Presence change must invalidate preview")
            saved.horns_enabled=case[6]
            if case[6] then
                saved.proxy_horns_missing=true; assert(not g.check_live(s)); saved.proxy_horns_missing=nil
                saved.display_horns_missing=true; assert(not g.check_live(s)); saved.display_horns_missing=nil
            end
            assert(g.check_live(s))
        end
        local recovered=module.new(runtime,probe.access,"recovery"); recovered.start()
        assert(recovered.pending and recovered.pending.profile.slot==slot.SlotTag.TagName)
        -- Selected UI can move; recovery must still use its recorded zone.
        aux.CurrentCustomizationSlotVM=nil
        run("tint:recovery"); aux.CurrentCustomizationSlotVM=case[2]=="Color 04" and slot or case.style
        assert(not recovered.pending and files.recovery=="" and display_color==original)
        -- v0.2.29: the selected slot's verified stock hover is settled before
        -- donor activation. An inactive proxy may still contain the last hover.
        slot.PreviewedCustomizationPartViewModel=function() return blue_vm end
        local function hover(active)
            proxy_part=blue_vm.AssetId.PrimaryAssetName; proxy_fragment=new_clone(donor_color)
            container.IsPreviewing=active
            display.ClonedFromCharacter=active and data_actor or source_actor
            display_color=active and donor_color or original
        end
        for _,active in ipairs({true,false}) do
            hover(active); messages={}
            local handoff_test=module.new(runtime,probe.access,"recovery")
            assert(handoff_test.begin_live(),table.concat(messages,"\n"))
            assert(has(active and "reset verified selected-slot stock hover" or "idle preview data may be stale"))
            assert(handoff_test.restore("hover test") and files.recovery=="" and display_color==original)
        end
        -- A no-op native reset must not reach clone/custom color writes.
        hover(true); local reset_hover=slot.ResetPreviewedPart; slot.ResetPreviewedPart=function() end
        local before_hover=clone_writes
        local refused=module.new(runtime,probe.access,"recovery")
        assert(not refused.begin_live() and not refused.pending and clone_writes==before_hover)
        slot.ResetPreviewedPart=reset_hover; slot:ResetPreviewedPart()
        -- A preview VM outside the active palette is not ours to reset.
        hover(true); slot.PreviewedCustomizationPartViewModel=function() return obj("Part /Game/Test.Foreign",{AssetId=asset("Other")}) end
        local resets_before=0
        slot.ResetPreviewedPart=function() resets_before=resets_before+1; reset_hover() end
        refused=module.new(runtime,probe.access,"recovery")
        assert(not refused.begin_live() and not refused.pending and resets_before==0 and clone_writes==before_hover)
        slot.ResetPreviewedPart=reset_hover; slot:ResetPreviewedPart()
        slot.PreviewedCustomizationPartViewModel=function() return blue_vm end
        case.broken={record:gsub("\nverified\n","\npending\n"),record:gsub("\n"..case[2].."\n","\n!bad\n"),record .. "extra\n"}
        if case[5] then
            case.broken[#case.broken+1]=record:gsub("|[^\n]+\n$","|bad=-\n")
            case.broken[#case.broken+1]=record:gsub("^proxy%-v8","proxy-v7")
        end
        for _,broken in ipairs(case.broken) do
            files.recovery=broken; local invalid=module.new(runtime,probe.access,"recovery"); invalid.start()
            assert(invalid.blocked and not invalid.pending)
        end
        files.recovery=""
        for _,failure in ipairs({"before","after","wrong-display","no-op"}) do
            mode=failure; messages={}; local writes_before=clone_writes
            local failed=module.new(runtime,probe.access,"recovery")
            assert(not failed.begin_live() and not failed.pending,table.concat(messages,"\n"))
            assert(clone_writes==writes_before and files.recovery=="" and not container.IsPreviewing)
        end
        -- A reload between stock activation and baseline measurement has no
        -- known donor RGB. Reset only the owned stock hover, never SetColor.
        mode="after"; reset_mode="throw"
        local writes_before=clone_writes
        local interrupted=module.new(runtime,probe.access,"recovery")
        assert(not interrupted.begin_live() and interrupted.pending and files.recovery:match("\npending\n"))
        mode=nil; reset_mode=nil; jobs={}
        local resumed=module.new(runtime,probe.access,"recovery"); resumed.start()
        assert(resumed.pending and resumed.pending.blue.pending_baseline)
        run("tint:recovery")
        assert(not resumed.pending and clone_writes==writes_before and files.recovery=="" and display_color==original)
        mode=nil
        local next_preview=module.new(runtime,probe.access,"recovery")
        assert(next_preview.begin_live() and not jobs["tint:timeout"]); assert(next_preview.restore("picker Cancel"))
        assert(not next_preview.pending and display_color==original)
        if case[5] then
            -- A skin-like bundle must still fail BEFORE cloning or SetColor;
            -- accepting two mesh tags does not authorize companion replacement.
            case.fragments=slot.GetFragments; case.writes=clone_writes
            slot.GetFragments=function() return array({source,source,source}) end
            assert(not next_preview.begin_live() and not next_preview.pending and clone_writes==case.writes and source_writes==0)
            slot.GetFragments=case.fragments
        end
    end
    aux.CurrentCustomizationSlotVM=slot; aux.RootCustomizationSlotVM=nil
    runtime.generic_colors=nil; base=saved.base; page=saved.page; FindAllOf=saved.find
    preview.GetSlotInstance=saved.preview_get; owner.GetSlotInstance=saved.owner_get
    display_instance.GetSlotInstance=saved.display_get
    source_slot.GetSlotNameTag=saved.source_tag; preview_slot.GetSlotNameTag=saved.preview_tag
    part.GetFullName=saved.part_name; part.GetClass=saved.part_class
    slot.PreviewCustomizationPart=saved.activate; slot.ResetPreviewedPart=saved.reset
    slot.SlotTag=tag(base .. ".Color.Secondary"); material.MaterialParameterName="Color 02"
    material.MaterialSlotNames=array({"MI_TORS","MI_ARMS"}); material.SlotNameTagsToApply.GameplayTags=array({tag(base .. ".Mesh")})
    blue_vm.AssetId=asset(blue_id); clone8=true; proxy_mesh=true
end

-- v0.2.18 integration: temporary editor selection -> REAL regular tint engine
-- -> blue handoff -> RGB -> regular restore -> Default. No auxiliary roots.
do
    local selection_module=assert(loadfile(scripts .. "/default_selection.lua"))()
    local saved={slot_fragments=slot.GetFragments,source_fragments=source_slot.GetFragmentInstances,
        source_name=source_slot.GetFullName,display_fragments=display_slot.GetFragmentInstances,
        find=FindAllOf,asset=part.AssetId,equipped=slot.EquippedCustomizationPartViewModel}
    local none="CPD_H_Outfit_Color_None"
    local default_vm=obj("BitReactorCustomizationPartViewModel " .. vm_outer .. "BitReactorCustomizationPartViewModel_340",{
        AssetId=asset(none),GetClass=function() return vm_class end,
    })
    local stock_vm=obj("BitReactorCustomizationPartViewModel " .. vm_outer .. "BitReactorCustomizationPartViewModel_341",{
        AssetId=asset(red_id),GetClass=function() return vm_class end,
    })
    source_slot.GetFullName=function()
        return "CustomizationFragmentInstanceSlot " .. owner_name:match("^[^ ]+ (.+)$") .. ".CustomizationFragmentInstanceSlot_10"
    end
    slot.GetFragments=function()
        return part.AssetId.PrimaryAssetName==none and {} or array({source})
    end
    source_slot.GetFragmentInstances=slot.GetFragments
    display_slot.GetFragmentInstances=function()
        return not container.IsPreviewing and part.AssetId.PrimaryAssetName==none and {} or array({display_fragment})
    end
    local grid=obj("BitReactorTileView /Game/Test.Grid",{
        GetNumItems=function() return 3 end,
        GetItemAt=function(_,i) return ({default_vm,stock_vm,blue_vm})[i+1] end,
        GetIndexForItem=function(_,v) return v==default_vm and 0 or v==stock_vm and 1 or 2 end,
    })
    local tiles=obj("WBP_Customization_SelectionTiles_C /Game/Test.Tiles",{
        CurrentSlotTag=tag(base .. ".Color.Secondary"),PartsGridList=grid,IsVisible=function() return true end,
    })
    FindAllOf=function(c)
        if c=="WBP_Customization_SelectionTiles_C" then return {tiles} end
        return saved.find(c)
    end
    local regular,adapted
    local function boot()
        regular=module.new(runtime,probe.access,"recovery")
        adapted=selection_module.wrap(runtime,probe.access,"selection",regular,regular)
    end
    slot.EquipCustomizationPart=function(_,vm)
        assert(files.selection:match("^selection%-v1\n"))
        if vm==default_vm then
            assert(not regular.pending and files.recovery=="" and not container.IsPreviewing,
                "Regular RGB/handoff cleanup MUST precede Default equip")
        end
        slot.EquippedCustomizationPartViewModel=vm; part.AssetId=vm.AssetId
        proxy_part=vm.AssetId.PrimaryAssetName
        proxy_fragment=vm==default_vm and nil or new_clone()
        display_color=vm==default_vm and nil or original
        adapted.context_changed("EquipCustomizationPart")
    end
    slot.EquippedCustomizationPartViewModel=default_vm; part.AssetId=default_vm.AssetId
    proxy_part=none; proxy_fragment=nil; display_color=nil
    boot()
    local function begin()
        messages={}; local s=adapted.begin_live(); assert(s,table.concat(messages,"\n"))
        assert(s.live and regular.pending==s and slot.EquippedCustomizationPartViewModel==stock_vm)
        assert(container.IsPreviewing and files.selection:find("\nselected\n",1,true))
        return s
    end
    local function finished()
        assert(not adapted.pending and not regular.pending and files.selection=="" and files.recovery=="")
        assert(slot.EquippedCustomizationPartViewModel==default_vm and #source_slot:GetFragmentInstances()==0)
        assert(not container.IsPreviewing and proxy_part==none)
    end
    local s=begin(); assert(adapted.update_live(s,rgb_module.parse("160,64,224")))
    assert(adapted.restore("picker Cancel")); finished()
    begin(); assert(not jobs["tint:timeout"]); assert(regular.restore("external backend restore")); finished()
    begin(); adapted.context_changed("page closed"); run("tint:context-restore"); finished()
    begin(); boot(); adapted.start(); run("tint:recovery"); finished(); run("selection:recovery")
    -- Actual regular blue-activation failure still undoes the temporary equip.
    blue_mode="throw-before"; assert(not adapted.begin_live()); blue_mode=nil; finished()
    -- Editor Apply integration uses the REAL tint/handoff/default stack too.
    -- Simulate native refresh copying the source into the display/data actors.
    do
        local retained={color=original,set=source.SetColor,name=source.GetFullName,
            refresh=owner.RefreshCustomization,slot=owner.GetSlotInstance,
            rename=os.rename,remove=os.remove,lookup=StaticFindObject,find=FindAllOf,page_name=page.GetFullName}
        local layout="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
        local creator=obj("WBP_CustomCharacter_Master_C " .. layout .. ".WBP_CustomCharacter_Master_C_1",{
            IsActivated=function() return false end,IsInViewport=function() return false end,GetParent=function() return nil end})
        local parent=obj("CanvasPanel " .. layout .. ".MainOverlay")
        local game_stack=obj("BitReactorActivatableWidgetStack " .. layout .. ".GameLayer_Stack",{
            WidgetList={creator,page},GetParent=function() return parent end,GetActiveWidget=function() return page end})
        page.GetFullName=function() return "WBP_Customization_ItemPage_C " .. layout .. ".WBP_Customization_ItemPage_C_2" end
        FindAllOf=function(c) if c=="WBP_CustomCharacter_Master_C" then return {creator} end; return retained.find(c) end
        source.GetFullName=function()
            return "CustomizationFragmentInstanceMaterialColor " .. owner_name:match("^[^ ]+ (.+)$") .. ".CustomizationFragmentInstanceMaterialColor_444"
        end
        source.SetColor=function(_,c)
            assert(files.editor and files.editor:match("^editor%-v1\n"))
            original={R=c.R,G=c.G,B=c.B,A=c.A}
        end
        owner.GetSlotInstance=function(_,t)
            local n=type(t.TagName)=="string" and t.TagName or t.TagName:ToString()
            return n==base .. ".Mesh" and mesh_slot or source_slot
        end
        owner.RefreshCustomization=function()
            assert(not container.IsPreviewing)
            display_color=original; proxy_fragment=new_clone(original)
        end
        StaticFindObject=function(p)
            for _,v in pairs(objects) do if v:GetFullName():match("^[^ ]+ (.+)$")==p then return v end end
        end
        os.rename=function(from,to)
            assert(files[from]~=nil and files[to]==nil); files[to],files[from]=files[from],nil; return true
        end
        os.remove=function(p) files[p]=nil; return true end
        local editor_module=assert(loadfile(scripts .. "/editor_session.lua"))()
        boot()
        local session=editor_module.wrap(runtime,probe.access,"editor",adapted)
        local draft=assert(session.begin_live())
        assert(session.update_live(draft,rgb_module.parse("160,64,224")))
        assert(session.apply_live(draft),table.concat(messages,"\n"))
        assert(session.applied and not session.pending and not container.IsPreviewing)
        assert(rgb_module.to_srgb(display_color).R==160)
        draft=assert(session.begin_live(),table.concat(messages,"\n"))
        assert(rgb_module.to_srgb(draft.test_color).R==160)
        assert(session.update_live(draft,rgb_module.parse("64,208,112")))
        assert(session.cancel_live("reopen Cancel"))
        assert(rgb_module.to_srgb(display_color).R==160 and session.applied)
        session.context_changed("creator closed")
        assert(not session.applied and not session.pending,table.concat(messages,"\n"))
        assert(slot.EquippedCustomizationPartViewModel==default_vm and files.editor=="")
        source.SetColor,source.GetFullName=retained.set,retained.name
        owner.RefreshCustomization,owner.GetSlotInstance=retained.refresh,retained.slot
        os.rename,os.remove,StaticFindObject=retained.rename,retained.remove,retained.lookup
        FindAllOf,page.GetFullName=retained.find,retained.page_name
        original=retained.color
    end
    slot.GetFragments=saved.slot_fragments; source_slot.GetFragmentInstances=saved.source_fragments
    source_slot.GetFullName=saved.source_name; display_slot.GetFragmentInstances=saved.display_fragments
    FindAllOf=saved.find; part.AssetId=saved.asset; slot.EquippedCustomizationPartViewModel=saved.equipped
    slot.EquipCustomizationPart=nil; proxy_part=red_id; proxy_fragment=new_clone(); display_color=original
end

io.open = original_open
print("Tint test: regular swatches, Default selection, donor isolation, failure rollback, indefinite drafts, diagnostic timeout and cold recovery passed")
