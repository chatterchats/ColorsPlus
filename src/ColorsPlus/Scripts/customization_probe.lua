-- Observational only. Names and fields are from the local RE reference corpus.
local M = {}
local BASE = "/Game/Game/UI/Strategy/Customization/Widgets/New/"
local AUX = BASE .. "CustomizationAuxVM.CustomizationAuxVM_C:"
local PAGE = BASE .. "WBP_Customization_ItemPage.WBP_Customization_ItemPage_C:"
local MASTER = "/Game/Game/UI/Strategy/Customization/Widgets/CustomCharacter/WBP_CustomCharacter_Master.WBP_CustomCharacter_Master_C:"
local SLOT = "/Script/BitReactorGame.BitReactorCustomizationSlotViewModel:"

local function attempt(callback)
    local ok, value = pcall(callback)
    if ok then return value end
end
local function valid(object)
    return object ~= nil and attempt(function() return object:IsValid() end) == true
end
local function prop(object, key)
    if object == nil then return nil end
    return attempt(function() return object[key] end)
end
local function text(value)
    if value == nil then return "<unavailable>" end
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    local string_value = attempt(function() return value:ToString() end)
    return type(string_value) == "string" and string_value or "<unavailable>"
end
local function name(object)
    if not valid(object) then return "<invalid>" end
    return text(attempt(function() return object:GetFullName() end))
end
local function live(object)
    if not valid(object) then return false end
    local n = name(object)
    return n ~= "<unavailable>" and not n:find("Default__", 1, true)
end
local function unwrap(parameter)
    -- Hook contexts are known wrappers. Returned array entries are checked below.
    return attempt(function() return parameter:get() end)
end
local function diagnostic(value)
    -- Keep exception messages on one bounded log line; do not inspect UObjects.
    local ok, result = pcall(tostring, value)
    return ok and result:gsub("[\r\n\t]", " "):sub(1, 768) or "<unprintable>"
end
local function unreal_type(value)
    -- This is the Lua binding's type identifier, not UObject:GetClass().
    local kind = attempt(function() return value:type() end)
    return type(kind) == "string" and kind or "<unavailable>"
end
local function array_value(value)
    local kind = unreal_type(value)
    local wrapped = kind == "RemoteUnrealParam" or kind == "LocalUnrealParam"
    local info = "source_lua_type=" .. type(value) .. " source_ue4ss_type=" .. kind
        .. " unwrapped=" .. tostring(wrapped)
    -- Never try :get() on arbitrary UObjects (including invalid ones). Failures
    -- from a recognized wrapper remain visible through each()'s outer pcall.
    if wrapped then return value:get(), info end
    return value, info
end
local function each(array, callback)
    if array == nil then return false, 0, "array is nil" end
    local count = 0
    local format = type(array) == "table" and rawget(array, "ForEach") == nil and "lua-table" or "tarray"
    local ok, err = pcall(function()
        if format == "lua-table" then
            -- GetFragments returned Lua tables in the tested build.
            -- The installed a1e7f571 array pusher uses GetParam for each entry,
            -- producing RemoteUnrealParam wrappers even inside a Lua table.
            -- Preserve numeric keys (including zero/sparse keys), and reject
            -- unexpected record-shaped tables instead of reporting false zeros.
            local indices = {}
            for index in next, array do
                assert(type(index) == "number" and index >= 0 and index % 1 == 0,
                    "unexpected array table key: " .. diagnostic(index))
                indices[#indices + 1] = index
            end
            table.sort(indices)
            for _, index in ipairs(indices) do
                count = count + 1
                if count <= 64 then
                    local value, info = array_value(rawget(array, index))
                    callback(index, value, info)
                end
            end
            return
        end
        array:ForEach(function(index, wrapper)
            count = count + 1
            -- Keep failures inside the outer pcall, but preserve their cause.
            if count <= 64 then callback(index, wrapper:get(), "source=ForEach unwrapped=true") end
        end)
    end)
    return ok, count, ok and nil or err, format
end
local function tag(value) return text(prop(value, "TagName")) end
local function tags(container)
    local values = {}
    local ok = each(prop(container, "GameplayTags"), function(_, item) values[#values + 1] = tag(item) end)
    return ok and ("[" .. table.concat(values, ", ") .. "]") or "<unavailable>"
end
local function asset(value)
    return text(prop(prop(value, "PrimaryAssetType"), "Name")) .. ":" .. text(prop(value, "PrimaryAssetName"))
end

function M.new(runtime)
    local self = {}
    local log = runtime.log
    local last = {}
    local serial = 0
    -- Shared, already-tested read boundary for the opt-in tint experiment.
    self.access = { live = live, name = name, prop = prop, text = text, unwrap = array_value,
        values = function(array)
            local result = {}
            local ok, count, err = each(array, function(_, value) result[#result + 1] = value end)
            assert(ok and count <= 64 and #result == count, "Unreadable or oversized array: " .. diagnostic(err))
            return result
        end,
        -- Full-path lookup; reused only within a held, hook-invalidated scope.
        find = function(path)
            if runtime.objects then return runtime.objects.find(path) end
            return StaticFindObject(path)
        end,
    }

    -- Only observational snapshots use these wrappers. Tint validation keeps
    -- the original access helpers above. Labels never inspect native objects.
    local function call(label, fn, ...)
        return fn(...)
    end
    local function traced(label, fn)
        return function(...) return call(label, fn, ...) end
    end
    local live = traced("live (validity/name)", live)
    local name = traced("name (validity/GetFullName)", name)
    local text = traced("text (ToString if needed)", text)
    local each = traced("array traversal/unwrap", each)
    local tags = traced("gameplay tags", tags)
    local asset = traced("asset identity", asset)
    local original_prop = prop
    local function prop(object, key) return call("property " .. key, original_prop, object, key) end

    local function part(lines, label, object)
        lines[#lines + 1] = label .. "=" .. name(object)
        if not live(object) then return end
        lines[#lines + 1] = label .. ".name=" .. text(prop(object, "DisplayName"))
            .. " asset=" .. asset(prop(object, "AssetId"))
            .. " allowed=" .. tags(prop(object, "AllowedSlots"))
    end

    local function slot(lines, label, object)
        lines[#lines + 1] = label .. "=" .. name(object)
        if not live(object) then return end
        lines[#lines + 1] = label .. ".name=" .. text(prop(object, "DisplayName"))
            .. " tag=" .. tag(prop(object, "SlotTag"))
        part(lines, label .. ".equipped", prop(object, "EquippedCustomizationPartViewModel"))
    end

    local function fragments(lines, object)
        if not live(object) then return end
        local called, array = pcall(function()
            return call("GetFragments", function() return object:GetFragments() end)
        end)
        if not called then
            lines[#lines + 1] = "fragments.get.status=error error=" .. diagnostic(array)
            lines[#lines + 1] = "fragments=<unavailable> material_color_instances=<unavailable>"
            return
        end
        lines[#lines + 1] = "fragments.get.status=ok return_type=" .. type(array)
        local colors, unreadable = 0, 0
        local ok, count, err, format = each(array, function(index, fragment, info)
            local label = "fragment[" .. tostring(index) .. "]"
            lines[#lines + 1] = label .. ".value " .. (info or "") .. " value_lua_type=" .. type(fragment)
                .. " value_ue4ss_type=" .. unreal_type(fragment)
            local checked, is_valid = pcall(function()
                return call(label .. ".IsValid", function() return fragment:IsValid() end)
            end)
            lines[#lines + 1] = label .. ".validity.status=" .. (checked and "ok value=" .. diagnostic(is_valid)
                or "error error=" .. diagnostic(is_valid))
            lines[#lines + 1] = label .. "=" .. name(fragment)
            if not checked or is_valid ~= true or not live(fragment) then unreadable = unreadable + 1; return end
            local class = name(attempt(function()
                return call(label .. ".GetClass", function() return fragment:GetClass() end)
            end))
            lines[#lines + 1] = label .. ".class=" .. class
            if class == "<invalid>" or class == "<unavailable>" then unreadable = unreadable + 1; return end
            if class == "Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor" then
                colors = colors + 1
                local color_ok, color = pcall(function()
                    return call(label .. ".GetColor", function() return fragment:GetColor() end)
                end)
                lines[#lines + 1] = label .. ".get_color.status=" .. (color_ok and "ok return_type=" .. type(color)
                    or "error error=" .. diagnostic(color))
                if not color_ok then color = nil end
                lines[#lines + 1] = label .. ".linear_rgba=" .. table.concat({
                    text(prop(color, "R")), text(prop(color, "G")),
                    text(prop(color, "B")), text(prop(color, "A")),
                }, ",")
                local target = prop(fragment, "MaterialTarget")
                local slots = {}
                local readable = each(prop(target, "MaterialSlotNames"), function(_, value)
                    slots[#slots + 1] = text(value)
                end)
                lines[#lines + 1] = label .. ".target.parameter=" .. text(prop(target, "MaterialParameterName"))
                    .. " materials=" .. (readable and ("[" .. table.concat(slots, ", ") .. "]") or "<unavailable>")
                    .. " slot_tags=" .. tags(prop(target, "SlotNameTagsToApply"))
            end
        end)
        lines[#lines + 1] = "fragments.iteration.status=" .. (ok and "ok" or "error error=" .. diagnostic(err))
            .. " visited=" .. count .. " format=" .. (format or "<unavailable>")
        lines[#lines + 1] = "fragments=" .. (ok and tostring(count) or "<unavailable>")
            .. " material_color_instances=" .. (ok and unreadable == 0 and count <= 64 and tostring(colors) or "<unavailable>")
            .. (count > 64 and " (truncated at 64)" or "")
        lines[#lines + 1] = "material_color_instances_observed=" .. colors .. " unreadable_fragments=" .. unreadable
    end

    local function emit(key, reason, lines, force)
        local signature = table.concat(lines, "\n")
        if not force and last[key] == signature then return end
        last[key] = signature
        serial = serial + 1
        log("SNAPSHOT " .. serial .. " BEGIN | " .. reason)
        for _, line in ipairs(lines) do log("snapshot=" .. serial .. " " .. line) end
        log("SNAPSHOT " .. serial .. " END")
    end

    function self.capture_aux(aux, reason, force)
        if not live(aux) then log("Snapshot skipped: auxiliary view model invalid or default"); return end
        local lines = { "aux=" .. name(aux), "active_tab=" .. text(prop(aux, "ActiveTab")) }
        local current = prop(aux, "CurrentCustomizationSlotVM")
        local root = prop(aux, "RootCustomizationSlotVM")
        slot(lines, "root", root)
        if live(root) then
            local ok, count = each(prop(root, "CustomizationChildSlotViewModels"), function(index, child)
                slot(lines, "root.child[" .. tostring(index) .. "]", child)
            end)
            lines[#lines + 1] = "root.children=" .. (ok and tostring(count) or "<unavailable>")
                .. (count > 64 and " (truncated at 64)" or "")
        end
        slot(lines, "current", current)
        part(lines, "selected_or_hovered", prop(aux, "CurrentCustomizationPartVM"))
        fragments(lines, current)
        emit("aux:" .. name(aux), reason, lines, force)
    end

    function self.capture_slot(object, reason)
        if not live(object) then log("Snapshot skipped: slot invalid or default"); return end
        local lines = {}
        slot(lines, "event_slot", object)
        -- This read is deliberately distinguished from the equipped part:
        -- hover can preview a different part without equipping it.
        part(lines, "previewed", attempt(function()
            return call("PreviewedCustomizationPartViewModel", function() return object:PreviewedCustomizationPartViewModel() end)
        end))
        fragments(lines, object)
        emit("slot:" .. name(object) .. ":" .. reason, reason, lines)
    end

    -- Unlike the deduplicated SNAPSHOT BEGIN (emitted after collecting fields),
    -- these boundaries precede all reads, even when the payload is unchanged.
    self.capture_aux = traced("capture_aux", self.capture_aux)
    self.capture_slot = traced("capture_slot", self.capture_slot)

    local function context_event(object, reason)
        if not live(object) then return end
        if self.on_context_event then self.on_context_event(reason) end
        if runtime.color_ui then runtime.color_ui.context_changed(reason) end
        -- Stock hover/selection still invalidates ownership and discovery.
        -- Detailed reads/logging are explicit diagnostics only (colors_probe).
    end

    local function candidates(class)
        local objects = attempt(function() return FindAllOf(class) end)
        return type(objects) == "table" and objects or {}
    end

    function self.manual(reason)
        self.install()
        local pages = 0
        for _, page in ipairs(candidates("WBP_Customization_ItemPage_C")) do
            if live(page) and attempt(function() return page:IsActivated() end) == true then
                pages = pages + 1
                log("Active item page=" .. name(page))
            end
        end
        if pages == 0 then log("No active customization item page; open Tops > Primary Accent and run colors_probe"); return end
        local count = 0
        for _, aux in ipairs(candidates("CustomizationAuxVM_C")) do
            if live(aux) and live(prop(aux, "CurrentCustomizationSlotVM")) then
                count = count + 1
                self.capture_aux(aux, reason .. " (candidate; page association unverified)", true)
            end
        end
        log("Manual snapshot: active_pages=" .. pages .. " auxiliary_candidates=" .. count)
    end

    local specs = {}
    for _, event in ipairs({ "UpdateCurrentCustomizationSlotVM", "UpdateCurrentCustomizationPartVM", "UpdateRootCustomizationSlotVM", "TileCustomizationPartWasClickedOn" }) do
        specs[#specs + 1] = { AUX .. event, function(context)
            local aux = unwrap(context)
            -- The game hands us its aux VM and pages: later lookups use these
            -- names instead of FindAllOf scans (known_instances).
            if runtime.known then runtime.known.note(aux) end
            context_event(aux, event)
        end }
    end
    for _, event in ipairs({ "EquipCustomizationPart", "PreviewCustomizationPart", "ResetPreviewedPart", "ResetToDefault" }) do
        specs[#specs + 1] = { SLOT .. event, function(context, ...)
            local object = unwrap(context)
            runtime:after("install", 1, self.install)
            context_event(object, event)
        end }
    end
    for _, event in ipairs({ "BP_OnActivated", "DisplayCustomizationList" }) do
        specs[#specs + 1] = { PAGE .. event, function(context)
            local page = unwrap(context)
            if not live(page) then return end
            if runtime.known then runtime.known.note(page) end
            if runtime.color_ui then runtime.color_ui.context_changed(event) end
            runtime:after("install:page", 1, function() self.install(true) end)
        end }
    end
    for _, spec in ipairs({ {PAGE .. "BP_OnDeactivated","page closed"},
        {AUX .. "ClearCustomizationAuxData","creator closed"}, {MASTER .. "CloseMenu","creator closed",true} }) do
        local path,reason,master=spec[1],spec[2],spec[3]
        -- The main-menu creator's class never loads in the hub editor, and a
        -- tester's hub log showed its retries bursting to 26/s on swatch
        -- events (each asks UE4SS for a missing UFunction; timed as
        -- hook.register). Retry it only at startup and page activation.
        specs[#specs + 1] = { path, page_only=master, function(context)
            -- End UI ownership at the screen boundary, not the next 33ms poll.
            if runtime.picker and runtime.picker.active then runtime.picker.close(reason) end
            if runtime.color_ui then runtime.color_ui.context_changed(reason) end
            if self.on_context_event then self.on_context_event(reason,master and name(unwrap(context)) or nil) end
            runtime:cancel_snapshots()
            last = {}
            log("Customization boundary | " .. reason .. " | " .. path)
        end }
    end

    -- Armory > Customize Weapon (weapon Paint Color, armory_ui). These classes
    -- load only in the armory, and a failed RegisterHook costs a full lookup,
    -- so they are retried at most every ARMORY_RETRY seconds from swatch
    -- events, plus at startup and page activation. A late install starts a
    -- discovery, since the screen's own activation has already passed.
    local ARMORY = "/Game/Game/UI/Strategy/Armory/WBP_Menu_Armory_CustomizeWeapon.WBP_Menu_Armory_CustomizeWeapon_C:"
    local ARMORY_RETRY = 10
    local function armory(reason, context)
        if not runtime.armory_ui then return end
        local screen = unwrap(context)
        local ok, err = pcall(runtime.armory_ui.context_changed, reason, live(screen) and name(screen) or nil)
        if not ok then log("Armory event failed | " .. tostring(err)) end
    end
    for _, spec in ipairs({ {"BP_OnActivated","armory activated"}, {"BP_OnDeactivated","armory deactivated"},
        {"UpdateStyleSection","armory section"} }) do
        local event, reason = spec[1], spec[2]
        specs[#specs + 1] = { ARMORY .. event, throttle=ARMORY_RETRY,
            on_installed=event=="BP_OnActivated" and function() armory("armory hooks ready", nil) end or nil,
            function(context) armory(reason, context) end }
    end

    local missing_reported = {}
    -- page_event: startup or an item page activation; only then are
    -- page_only hooks retried.
    function self.install(page_event)
        local now = os.clock()
        for _, spec in ipairs(specs) do
            local due = page_event or not spec.throttle or not spec.tried or now - spec.tried >= spec.throttle
            if not runtime.hooks[spec[1]] and (page_event or not spec.page_only) and due then
                spec.tried = now
                local ok, err = runtime:hook(spec[1], spec[2])
                if ok and spec.on_installed then spec.on_installed() end
                if not ok and not missing_reported[spec[1]] then
                    missing_reported[spec[1]] = true
                    log("Hook pending (function may not be loaded): " .. spec[1] .. " | " .. tostring(err))
                end
            end
        end
    end

    function self.start()
        for _, api in ipairs({ "RegisterHook", "UnregisterHook", "MakeActionHandle", "ExecuteInGameThreadWithDelay", "CancelDelayedAction", "FindAllOf" }) do
            if type(rawget(_G, api)) ~= "function" then
                log("Probe disabled: required UE4SS API unavailable: " .. api)
                return
            end
        end
        if type(RegisterConsoleCommandHandler) == "function" then
            runtime:console("colors_probe", function()
                runtime:after("snapshot:manual", 1, function() self.manual("colors_probe") end)
            end)
        else
            log("Manual command unavailable: RegisterConsoleCommandHandler missing")
        end
        -- Finite startup retries. Native events/console retry later-loaded UI.
        for index, delay in ipairs({ 0, 500, 2000, 5000 }) do
            runtime:after("startup:" .. index, delay, function() self.install(true) end)
        end
        log("Probe ready | diagnostics=fragment-read-v4 | command=colors_probe | detailed snapshots manual only; context hooks active")
    end
    return self
end

return M
