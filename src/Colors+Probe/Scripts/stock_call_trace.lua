-- Read-only stock-hover timeline. Borrowed hook parameters are rendered to
-- scalar strings inside their callback, never retained for delayed work.
local M = {}
local ROOT = "/Game/Game/Cinematics/Blueprints/Hologram_Utility/BP_CustomizationPresentationFacilitator/"
local CONTAINER = ROOT .. "Previews/BP_CustomizationPreviewProxyContainer.BP_CustomizationPreviewProxyContainer_C:"
local DISPLAY = ROOT .. "BP_CustomizationProxyCharacter.BP_CustomizationProxyCharacter_C:"
local INSTANCE = "/Script/BitReactorCore.CustomizationInstance:"
local MENU = "/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local DELAYS = {50, 250, 1000}
local SPECS = {
    {path=INSTANCE.."PreviewPart", target="instance", args={{"slot","tag"},{"part","asset"}}},
    {path=INSTANCE.."ResetPreview", target="instance", args={}},
    {path=INSTANCE.."SetPreviewCustomizationInstance", target="instance", args={{"new_preview","object"}}},
    {path=CONTAINER.."CustomizationPrePreviewUpdated", target="container", args={{"slot","tag"},{"part","asset"}}},
    {path=CONTAINER.."CustomizationPreviewSet", target="container", args={{"old_preview","object"},{"new_preview","object"}}},
    {path=CONTAINER.."CustomizationPreviewReset", target="container", args={}},
    {path=CONTAINER.."OnPreviewRefreshed", target="container", args={}},
    {path=DISPLAY.."CloneFrom", target="display", args={{"source","object"},{"show_weapon","value"},{"injured","value"},{"pose","value"}}},
    {path=DISPLAY.."RefreshCharacterCustomization", target="display", args={}},
}
function M.new(runtime, a, resolve_context)
    local self = {window=nil, sequence=0}
    local function log(s) runtime.log("STOCK CALL TRACE | " .. s) end
    local function clean(v) return tostring(v):gsub("[\r\n\t]", " "):sub(1, 1200) end
    local function object(v) v = a.unwrap(v); assert(a.live(v), "Live trace object unavailable"); return v end
    local function asset(v)
        return a.text(a.prop(a.prop(v,"PrimaryAssetType"),"Name")) .. ":" .. a.text(a.prop(v,"PrimaryAssetName"))
    end
    local function render(v, kind)
        v = a.unwrap(v)
        if kind == "object" then return a.name(v) end
        if kind == "tag" then return a.text(a.prop(v, "TagName")) end
        if kind == "asset" then return asset(v) end
        if kind == "part_vm" then return a.name(v) .. " | asset=" .. asset(a.prop(v, "AssetId")) end
        return a.text(v)
    end
    local function bindings()
        local c = resolve_context()
        local preview = object(c.owner:GetPreviewCustomizationInstance())
        local data = object(preview:GetOwner())
        local matches = {}
        for _, container in ipairs(a.values(FindAllOf("BP_CustomizationPreviewProxyContainer_C") or {})) do
            local name = a.name(container)
            local path = name:match("^[^ ]+ (.+)$")
            if a.live(container) and path and path:sub(1,#MENU) == MENU then
                local storage = a.unwrap(a.prop(container,"ProxyDataStorage"))
                if a.live(storage) and a.name(storage) == a.name(data) then matches[#matches+1] = container end
            end
        end
        assert(#matches == 1, "Expected one matched stock-preview container")
        local display = object(matches[1].ProxyCharacter)
        return c, preview, matches[1], display
    end
    function self.stop(reason)
        self.window = nil
        runtime:cancel("stock:expiry")
        for _, delay in ipairs(DELAYS) do runtime:cancel("stock:sample:" .. delay) end
        log("STOP | " .. (reason or "panel"))
    end
    function self.sample(reason, after_sequence)
        local w = self.window
        if not w then return end
        if w.samples >= 60 then self.stop("60-sample limit"); return end
        w.samples = w.samples + 1
        local prefix = "sample=" .. w.samples .. " | after_sequence=" .. (after_sequence or self.sequence) .. " | " .. reason
        local function read(key, getter)
            local ok, value = pcall(getter)
            log(prefix .. " | " .. key .. (ok and "=" or ".error=") .. clean(value))
        end
        local ok, err = pcall(function()
            local c, preview, container, display = bindings()
            assert(a.name(c.owner) == w.owner and a.name(c.slot) == w.slot and c.page == w.page
                and a.name(preview) == w.preview and a.name(container) == w.container
                and a.name(display) == w.display, "Trace context/link replaced; re-arm")
            read("equipped_part", function() return asset(c.part.AssetId) end)
            read("IsPreviewing", function() return container.IsPreviewing end)
            read("DelayProxyRefreshing", function() return container.DelayProxyRefreshing end)
            read("ClonedFromCharacter", function() return a.name(object(display.ClonedFromCharacter)) end)
            read("DelayCustomizationRefresh", function() return display.DelayCustomizationRefresh end)
            for label, instance in pairs({source=c.owner, data=preview, display=a.unwrap(a.prop(display,"CustomizationInstance"))}) do
                read(label .. ".accent", function()
                    local inst = object(instance)
                    if label == "display" then assert(a.name(object(inst:GetOwner())) == w.display, "Display instance owner mismatch") end
                    local slot = object(inst:GetSlotInstance(c.slot.SlotTag))
                    local values = a.values(slot:GetFragmentInstances()); assert(#values == 1, "Expected one accent fragment")
                    local f = object(values[1])
                    assert(a.name(object(f:GetClass())) == "Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor",
                        "Unexpected accent fragment class")
                    local rgba = f:GetColor(); local out = {}
                    for _, channel in ipairs({"R","G","B","A"}) do
                        local n = a.prop(rgba,channel)
                        assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Unreadable color")
                        out[#out+1] = string.format("%.6f",n)
                    end
                    return asset(slot:GetCustomizationPartPrimaryAssetId()) .. " | rgba=" .. table.concat(out,",")
                end)
            end
        end)
        if not ok then log(prefix .. " | SAMPLE FAILED | " .. clean(err)); self.stop("context unavailable/replaced") end
    end
    local function event(spec, phase, context, ...)
        local w = self.window
        if not w then return end
        local caller = object(context)
        local name = a.name(caller)
        local accepted = spec.target == "instance" and (name == w.owner or name == w.preview)
            or name == w[spec.target]
        if not accepted then return end
        if w.events >= 160 then self.stop("160-event limit"); return end
        w.events = w.events + 1; self.sequence = self.sequence + 1
        local seq = self.sequence
        log("sequence=" .. seq .. " | " .. phase .. " | " .. spec.path .. " | self=" .. name)
        local args = {...}
        for index, field in ipairs(spec.args) do
            local ok, value = pcall(render, args[index], field[2])
            log("sequence=" .. seq .. " | arg." .. field[1] .. (ok and "=" or ".error=") .. clean(value))
        end
        -- Immediate caller state supplies an ordering clue without an object
        -- scan or a guessed Blueprint pre-hook. Blueprint callbacks are post-only.
        if spec.target == "container" then
            log("sequence=" .. seq .. " | caller.IsPreviewing=" .. a.text(a.prop(caller,"IsPreviewing")))
        elseif spec.target == "display" then
            log("sequence=" .. seq .. " | caller.ClonedFromCharacter=" .. a.name(a.unwrap(a.prop(caller,"ClonedFromCharacter"))))
        end
        -- These are coalesced snapshots after the latest observed callback,
        -- not measurements of elapsed time or each individual call's latency.
        if phase ~= "native-pre" then
            for _, delay in ipairs(DELAYS) do
                runtime:after("stock:sample:" .. delay, delay, function()
                    if self.window == w then self.sample("settled +" .. delay .. "ms (coalesced)", seq) end
                end)
            end
        end
    end
    function self.slot_event(reason, context, part)
        event({path="SlotVM:"..reason, target="slot", args=reason == "PreviewCustomizationPart"
            and {{"part_vm","part_vm"}} or {}}, "native-post (existing hook)", context, part)
    end
    function self.arm()
        self.stop("new window")
        if runtime.tint and runtime.tint.pending then log("ARM REFUSED | Restore the active tint test first"); return end
        local ok, err = pcall(function()
            local c, preview, container, display = bindings()
            local w = {owner=a.name(c.owner), preview=a.name(preview), slot=a.name(c.slot), page=c.page,
                container=a.name(container), display=a.name(display), samples=0, events=0}
            local installed = 0
            for _, spec in ipairs(SPECS) do
                local native = spec.path:sub(1,8) == "/Script/"
                local success, failure = runtime:hook(spec.path,
                    function(...) event(spec, native and "native-post" or "blueprint-post", ...) end,
                    native and function(...) event(spec,"native-pre",...) end or nil)
                if success then installed = installed + 1
                else log("HOOK UNAVAILABLE | " .. spec.path .. " | " .. clean(failure)) end
            end
            self.window = w
            log("ARMED | 60 seconds | hooks=" .. installed .. "/" .. #SPECS
                .. " | read-only | no cyan/PreviewPart/ResetPreview calls | event order is callback order")
            runtime:after("stock:expiry",60000,function() if self.window == w then self.stop("60-second timeout") end end)
            self.sample("baseline",self.sequence)
        end)
        if not ok then self.stop("arm failed"); log("ARM REFUSED | " .. clean(err)) end
    end
    return self
end
return M
