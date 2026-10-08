-- Stock-preview handoff through a palette donor's slot-VM hover. No direct Blueprint flag, actor-clone, equip,
-- material or save writes. The tint module journals intent before activation.
local M = {}
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[/\\])")
local worlds = assert(loadfile(directory .. "editor_worlds.lua"))()
-- Container and display must belong to the same editor.
function M.valid_record(container, display)
    return worlds.same("container", container, "display", display) ~= nil
end
function M.new(runtime, a, inspect_display, inspect_meshes)
    local self = {}
    local function log(s) runtime.log("HANDOFF | " .. s) end
    local function object(v)
        v = a.unwrap(v); assert(a.live(v), "Handoff live object unavailable"); return v
    end
    local function same(v, other) return a.name(object(v)) == a.name(object(other)) end
    local function discover(data)
        local function linked_to(container)
            if not (a.live(container) and worlds.container(a.name(container))) then return false end
            local storage = a.unwrap(a.prop(container, "ProxyDataStorage"))
            return a.live(storage) and a.name(storage) == a.name(data)
        end
        local matches = {}
        if runtime.known then
            -- Known containers first; a scan only when none links to this preview.
            matches = runtime.known.select("BP_CustomizationPreviewProxyContainer_C",4096,linked_to)
        else
            local containers=a.values(FindAllOf("BP_CustomizationPreviewProxyContainer_C") or {})
            assert(#containers<=4096,"Handoff container scan limit")
            for _, container in ipairs(containers) do
                if linked_to(container) then matches[#matches + 1] = container end
            end
        end
        assert(#matches == 1, "Expected exactly one matched preview container")
        return matches[1]
    end
    local function linked(owner, preview, record, bound)
        assert(same(owner:GetPreviewCustomizationInstance(), preview), "Handoff preview link changed")
        local source, data = object(owner:GetOwner()), object(preview:GetOwner())
        local container
        if bound and record then
            assert(M.valid_record(record.container,record.display),"Invalid handoff binding")
            local found=a.unwrap((a.find or StaticFindObject)(assert(record.container:match("^[^ ]+ (.+)$"))))
            if a.live(found) then
                assert(a.name(found)==record.container,"Handoff lookup identity changed")
                container=found
            end
        end
        -- Missing lookup uses the original unique discovery, but the recorded
        -- identity below must still match. Never adopt a replacement container.
        container=container or discover(data)
        assert(same(object(container).ProxyDataStorage,data),"Handoff storage link changed")
        local display = object(container.ProxyCharacter)
        assert(M.valid_record(a.name(container), a.name(display))
            and worlds.same("owner", a.name(owner), "container", a.name(container)),
            "Unsupported handoff container/display: owner=" .. a.name(owner) .. " | container=" .. a.name(container)
            .. " | display=" .. a.name(display))
        if record then
            assert(a.name(container) == record.container and a.name(display) == record.display,
                "Handoff container/display replaced")
        end
        local instance = object(display.CustomizationInstance)
        assert(same(instance:GetOwner(), display), "Handoff display instance owner mismatch")
        return container, display, instance, source, data
    end
    local function flag(container)
        local v = a.prop(container, "IsPreviewing")
        assert(type(v) == "boolean", "Unreadable IsPreviewing")
        return v
    end
    -- Synchronous only: callers must not retain these objects in delayed work.
    function self.display(owner, preview)
        local container, display, instance, source = linked(owner, preview)
        assert(not flag(container) and same(display.ClonedFromCharacter, source),
            "Move off swatches before starting the eye probe")
        return container, display, instance
    end
    function self.settle_selected(c, preview, verify_hover)
        local container, display, instance, source, data = linked(c.owner, preview)
        if flag(container) then
            assert(same(display.ClonedFromCharacter, data), "Hover display link changed")
            -- Verify the selected slot's own preview VM and displayed fragment;
            -- never reset a different slot's preview or simply ignore a mismatch.
            verify_hover(instance)
            log("SETTLE | reset verified selected-slot stock hover")
            c.slot:ResetPreviewedPart()
        else
            assert(same(display.ClonedFromCharacter, source), "Idle display link changed")
            log("SETTLE | idle preview data may be stale; donor will replace it")
        end
        return self.prepare(c, preview)
    end
    function self.prepare(c, preview)
        local container, display, instance, source = linked(c.owner, preview)
        assert(not flag(container), "An existing hover preview is active; move off swatches")
        assert(same(display.ClonedFromCharacter, source), "Display is not following the equipped character")
        inspect_display(instance, c.original, c.materials, c.part.AssetId,c.profile)
        log("BASELINE VERIFIED | container=" .. a.name(container) .. " | display=" .. a.name(display))
        return {container=a.name(container), display=a.name(display)}
    end
    function self.activate(session, c, preview, blue_vm)
        local container, display, _, source = linked(c.owner, preview, session.handoff)
        assert(not flag(container) and same(display.ClonedFromCharacter, source), "Handoff baseline changed")
        assert(session.blue and blue_vm, "Validated palette donor required")
        log("CALL | SlotVM.PreviewCustomizationPart | palette donor; no equip")
        c.slot:PreviewCustomizationPart(blue_vm)
        self.verify(session, c.owner, preview)
        log("ACTIVE | IsPreviewing=true | display follows preview-data")
    end
    function self.verify(session, owner, preview, expected_color, materials, part)
        -- Fresh lookup and all live links on every check; no retained UObject.
        -- Initial discovery, activation and restoration keep full discovery.
        local container, display, instance, _, data = linked(owner, preview, session.handoff,true)
        assert(flag(container) and same(display.ClonedFromCharacter, data),
            "Stock preview did not switch display to preview-data")
        if session.profile.targets then
            assert(inspect_meshes,"Multi-mesh handoff verifier unavailable")(instance,session.profile)
        end
        if expected_color then
            -- Donor baseline only. Owned custom display checks never inherit
            -- the stock scalar-layout exception, including after recovery.
            local skin_stock=session.phase=="handoff" and session.blue~=nil
                and (session.profile.skin_race~=nil or session.profile.bundle~=nil)
            inspect_display(instance, expected_color, materials, part,session.profile,skin_stock and true or nil,
                session.phase=="owned")
            log("DISPLAY COLOR VERIFIED | fragment/target/armor match; visual confirmation still required")
        end
    end
    function self.restore(session, owner, preview, may_reset, verify_restored, reset_slot)
        local container, display, instance, source, data = linked(owner, preview, session.handoff)
        if not flag(container) and same(display.ClonedFromCharacter, source) then
            if may_reset then verify_restored(instance) end
            log("Already back on equipped character; no reset"); return
        end
        if not may_reset then
            log("Preview changed externally; no reset of current game preview"); return
        end
        assert(flag(container) and same(display.ClonedFromCharacter, data), "Unexpected display link; recovery retained")
        assert(session.blue, "Owned handoff without a palette donor")
        log("CALL | SlotVM.ResetPreviewedPart | owned donor handoff")
        reset_slot()
        container, display, instance, source = linked(owner, preview, session.handoff)
        assert(not flag(container) and same(display.ClonedFromCharacter, source),
            "ResetPreview did not restore display link; recovery retained")
        verify_restored(instance)
        log("RESTORED | display follows equipped character; data proxy retained")
    end
    return self
end
return M
