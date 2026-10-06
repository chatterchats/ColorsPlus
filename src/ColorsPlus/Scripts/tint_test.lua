-- Preview session: activate a verified palette donor in the game's preview,
-- then modify only a cloned fragment there. No SetColor on equipped
-- fragments; no default, equip, or save calls. ("blue" names the donor
-- record: the first donor was the stock Blue_14 swatch.)
local M = {}
local COLOR_CLASS = "Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"

function M.new(runtime, access, recovery_path)
    local self = { busy = false, pending = nil }
    local a = access
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local target_module=assert(loadfile(directory .. "color_target.lua"))()
    local rules=assert(loadfile(directory .. "color_rules.lua"))()
    local worlds=assert(loadfile(directory .. "editor_worlds.lua"))()
    local targets=target_module.new(a,runtime.log)
    local fragment_module=assert(loadfile(directory .. "color_fragments.lua"))()
    local fragments=fragment_module.new(a,runtime.log)
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local context_revision=0 -- every native event: refuses lookups in flight
    local route_epoch=0 -- structural events only: retires stored lookup hints
    -- Creator-page and draft discovery hints, never native objects or cached validation.
    -- Not serialized: reload recovery must restore rather than resume a route.
    local draft_route,draft_owner,lookup_route
    local function log(s) runtime.log("TINT | " .. s) end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function object(value, label)
        local result = a.unwrap(value)
        assert(a.live(result), "Required live object unavailable: " .. (label or "unnamed read"))
        return result
    end
    local function optional(value) return a.unwrap(value) end
    local function id(value)
        return a.text(a.prop(a.prop(value, "PrimaryAssetType"), "Name")) .. ":" .. a.text(a.prop(value, "PrimaryAssetName"))
    end
    local function tag(value) return a.text(a.prop(value, "TagName")) end
    local function recovery_tag(profile)
        -- Do not infer callability from UE4SS's protected metatable. This is
        -- reached only inside protected game-thread inspect/apply/restore work.
        local ok, value = pcall(function()
            local expected=profile.slot
            local name = FName(expected)
            assert(a.text(name) == expected, "FName round-trip did not match selected slot")
            return {TagName = name}
        end)
        assert(ok, "Recovery FName construction failed: " .. tostring(value))
        return value
    end
    local function color(fragment)
        local value, result = fragment:GetColor(), {}
        for _, key in ipairs({"R", "G", "B", "A"}) do
            local v = a.prop(value, key)
            assert(type(v) == "number" and v == v and math.abs(v) < math.huge, "Unreadable color component " .. key)
            result[key] = v
        end
        return result
    end
    local function same_color(x, y)
        for _, key in ipairs({"R", "G", "B", "A"}) do
            if math.abs(x[key] - y[key]) > 0.00001 then return false end
        end
        return true
    end
    local function rgba(c) return string.format("%.6f,%.6f,%.6f,%.6f", c.R, c.G, c.B, c.A) end
    local function preview_part(session) return session.blue and session.blue.part or session.part end
    local function preview_original(session)
        -- A cross-target donor never supplies the RGB baseline of our source
        -- clone. Its stock RGB is checked separately before clone installation.
        return session.blue and not session.blue.materials and session.blue.original or session.original
    end
    local function test_color(session) return session.test_color end
    local function asset_value(value)
        local kind, name = value:match("^([^:]+):(.+)$")
        return {PrimaryAssetType={Name=kind}, PrimaryAssetName=name}
    end
    local function allowed_slot_vm(name)
        return type(name) == "string" and name:match("^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$")
    end
    local function find_blue(c)
        local slot_name = a.name(c.slot)
        assert(allowed_slot_vm(slot_name), "Unsupported selected slot view model location")
        assert(rules.color(c.original,c.profile.slot,c.profile.parameter),"Unsupported source value/alpha")
        local vm,asset=targets.donor(c.slot,c.page,c.profile)
        return vm,{part=asset,original=c.original,slot_vm=slot_name,pending_baseline=true,
            materials=target_module.donor_materials(c.profile,id(c.part.AssetId),asset)}
    end
    local function target(fragment,profile) return targets.target(fragment,profile) end
    local function single_color(array,profile,stock_preview) return fragments.read(array,profile,stock_preview) end
    local function clone_name_for(preview, fragment)
        local prefix = "CustomizationFragmentInstanceMaterialColor " .. preview:match("^[^ ]+ (.+)$") .. "."
        return fragment:sub(1, #prefix) == prefix and not fragment:find("[\r\n]")
    end
    local function candidates(class)
        local found = FindAllOf(class)
        assert(found == nil or type(found) == "table", "FindAllOf returned an unsupported value")
        local count=0
        for _ in pairs(found or {}) do count=count+1; assert(count<=4096,"Tint object scan limit: " .. class) end
        return found or {}
    end
    local function resolve_impl(binding)
        local pages, page_name = 0, nil
        local selected, selected_root, aux_name = {}, nil, nil
        if binding then
            -- A scalar route is only a lookup hint. Reacquire and validate the
            -- exact active stack/page, VM, source and targets on every read.
            assert(lifetime.page_active(binding.creator,binding.page),"Bound color page changed")
            local aux=object((a.find or StaticFindObject)(assert(binding.aux:match("^[^ ]+ (.+)$"))))
            assert(a.name(aux)==binding.aux,"Bound color auxiliary VM changed")
            page_name=binding.page
            selected[1]=object(a.prop(aux,"CurrentCustomizationSlotVM"))
            selected_root=a.prop(aux,"RootCustomizationSlotVM")
            aux_name=binding.aux
        else
            for _, page in pairs(candidates("WBP_Customization_ItemPage_C")) do
                if a.live(page) and page:IsActivated() == true then
                    pages, page_name = pages + 1, a.name(page)
                end
            end
            assert(pages == 1, "Open exactly one customization item page")
            for _, aux in pairs(candidates("CustomizationAuxVM_C")) do
                if a.live(aux) and a.live(a.prop(aux, "CurrentCustomizationSlotVM")) then
                    selected[#selected + 1] = aux.CurrentCustomizationSlotVM
                    selected_root = a.prop(aux,"RootCustomizationSlotVM")
                    aux_name=a.name(aux)
                end
            end
            assert(#selected == 1, "Current customization context is missing or ambiguous")
        end
        local slot = targets.selected(selected[1],page_name,selected_root)
        local part = object(slot.EquippedCustomizationPartViewModel)
        local fragment,_,skin_race,skin_scalar,description = timed("validate.source_fragments",function()
            return single_color(slot:GetFragments(),{slot=tag(slot.SlotTag)})
        end)
        local owner = object(fragment:GetOwningCustomizationInstance())
        assert(worlds.owner(a.name(owner)), "Not a supported character editor character")
        local source_slot = object(fragment:GetOwningCustomizationSlot())
        assert(tag(source_slot:GetSlotNameTag()) == tag(slot.SlotTag), "Fragment belongs to another slot")
        assert(a.name(object(owner:GetSlotInstance(slot.SlotTag))) == a.name(source_slot), "Slot owner mismatch")
        local profile=timed("validate.source_profile",targets.read,fragment,tag(slot.SlotTag),owner,skin_race,skin_scalar,description)
        local materials = timed("validate.source_target",target,fragment,profile)
        timed("validate.source_meshes",targets.mesh,owner,profile)
        assert(id(source_slot:GetCustomizationPartPrimaryAssetId()) == id(part.AssetId), "Equipped swatch/fragment mismatch")
        return {page = page_name, slot = slot, part = part, fragment = fragment, owner = owner, source_slot = source_slot,
            original = color(fragment), materials = materials, profile=profile,aux=aux_name}
    end
    local function resolve(binding)
        local revision=context_revision
        local label=binding and "tint.resolve_bound" or "tint.resolve"
        -- A structural notification retires transaction and draft hints, even
        -- while ordinary event restoration is suppressed by self.busy. Other
        -- events keep the hint; resolve_impl revalidates it completely.
        if binding and binding.epoch~=route_epoch then
            binding=nil; label="tint.resolve_fallback"
        end
        if not binding and lookup_route then
            local route=lookup_route
            local ok,value=pcall(timed,"tint.resolve_lookup",resolve_impl,route)
            assert(revision==context_revision,"Context changed during lookup")
            if ok then return value end
            lookup_route=nil
        end
        local c=timed(label,resolve_impl,binding)
        local route={page=c.page,aux=c.aux,creator=binding and binding.creator or lifetime.bind(c.page),revision=revision,epoch=route_epoch}
        assert(revision==context_revision,"Context changed during discovery")
        lookup_route=route
        return c
    end
    local function resolve_proxy(c, blue, idle_baseline)
        local preview = object(c.owner:GetPreviewCustomizationInstance(), "linked preview instance")
        assert(worlds.same("owner",a.name(c.owner),"preview",a.name(preview)) and a.name(preview) ~= a.name(c.owner), "No verified linked customization preview proxy")
        local preview_slot = object(preview:GetSlotInstance(c.slot.SlotTag), "proxy color slot")
        assert(a.name(preview_slot) ~= a.name(c.source_slot), "Preview slot aliases the equipped slot")
        assert(tag(preview_slot:GetSlotNameTag()) == c.profile.slot, "Proxy slot changed")
        -- Exercise the exact reconstruction used by restore before any write.
        local recovery_slot = object(preview:GetSlotInstance(recovery_tag(c.profile)), "reconstructed recovery slot")
        assert(a.name(recovery_slot) == a.name(preview_slot), "Recovery slot lookup differs from selected proxy slot")
        log("Recovery lookup verified | FName round-trip and proxy slot match")
        local proxy_part, equipped_part = id(preview_slot:GetCustomizationPartPrimaryAssetId()), id(c.part.AssetId)
        if c.profile.skin_race then
            log("SKIN PROXY CHECK | phase=" .. (idle_baseline and "idle" or blue and "stock-preview" or "selected")
                .. " | source=" .. equipped_part .. " | requested=" .. (blue and blue.part or equipped_part)
                .. " | actual=" .. proxy_part)
        end
        assert(idle_baseline or proxy_part == (blue and blue.part or equipped_part), "Proxy is previewing a different swatch | proxy=" .. proxy_part .. " | equipped=" .. equipped_part)
        targets.mesh(preview,c.profile)
        -- Idle proxy data may be a different stock skin shade/race tag; it is
        -- never adopted. The verified same-family donor replaces it first.
        local existing = single_color(preview_slot:GetFragmentInstances(),idle_baseline
            and c.profile.skin_race and {slot=c.profile.slot} or c.profile,blue~=nil or idle_baseline==true)
        assert(a.name(existing) ~= a.name(c.fragment), "Proxy fragment aliases equipped fragment")
        assert(a.name(object(existing:GetOwningCustomizationInstance())) == a.name(preview), "Proxy fragment owner mismatch")
        local proxy_color, proxy_target = color(existing), target(existing,c.profile)
        assert(proxy_target == (blue and blue.materials or c.materials) and (idle_baseline or blue and blue.pending_baseline or same_color(proxy_color, blue and blue.original or c.original)),
            "Proxy color/target differs from equipped accent | proxy_rgba=" .. rgba(proxy_color)
            .. " | equipped_rgba=" .. rgba(c.original) .. " | proxy_materials=" .. proxy_target)
        return preview, preview_slot, existing
    end
    local source_file = debug.getinfo(1, "S").source:gsub("^@", "")
    local handoff_module = assert(loadfile(assert(source_file:match("^(.*[/\\])")) .. "display_handoff.lua"))()
    local function inspect_display(instance, expected_color, materials, part,profile,stock_preview,uniform)
        local slot = object(instance:GetSlotInstance(recovery_tag(profile)))
        local fragment = single_color(slot:GetFragmentInstances(),profile,stock_preview)
        assert(a.name(object(fragment:GetOwningCustomizationInstance())) == a.name(instance)
            and a.name(object(fragment:GetOwningCustomizationSlot())) == a.name(slot),
            "Display fragment ownership mismatch")
        assert(target(fragment,profile) == materials and same_color(color(fragment), expected_color),
            "Display accent color/target mismatch")
        if profile.bundle and not stock_preview then
            assert(fragments.matches(fragment,profile,expected_color,not uniform),"Display companion colors differ")
        end
        assert(id(slot:GetCustomizationPartPrimaryAssetId()) == id(part), "Display accent swatch mismatch")
        targets.mesh(instance,profile)
    end
    local handoff = handoff_module.new(runtime, a, inspect_display, targets.mesh)
    -- Read-only checkpoints: reacquire the linked slot, then log every field
    -- independently so an identity mismatch cannot hide its color or target.
    -- All UObject references remain local to this game-thread action.
    local function verify_checkpoint(stage, c, expected, chosen, accept_installed_copy)
        local read_failed = false
        local function read(field, getter, display)
            local ok, value = pcall(getter)
            if ok then
                log("CHECKPOINT " .. stage .. " | " .. field .. "=" .. (display or tostring)(value))
                return value
            end
            read_failed = true
            log("CHECKPOINT " .. stage .. " | " .. field .. ".error=" .. tostring(value):gsub("[\r\n]", " "))
        end
        local preview = read("preview", function()
            return object(object(c.owner):GetPreviewCustomizationInstance(), "checkpoint linked preview")
        end, a.name)
        local slot = read("slot", function()
            return object(object(preview):GetSlotInstance(recovery_tag(c.profile)), "checkpoint accent slot")
        end, a.name)
        local part = read("part", function() return id(object(slot):GetCustomizationPartPrimaryAssetId()) end)
        local values = read("fragment_count", function()
            return a.values(object(slot):GetFragmentInstances())
        end, function(v) return tostring(#v) end)
        local fragment = read("fragment", function()
            assert(values,"Missing checkpoint fragment array")
            return single_color(values,c.profile)
        end, a.name)
        local class = read("class", function() return a.name(object(object(fragment):GetClass())) end)
        local function checked_fragment()
            assert(class == COLOR_CLASS, "Checkpoint fragment is not a material color")
            return object(fragment)
        end
        local owner = read("fragment_owner", function()
            return a.name(object(checked_fragment():GetOwningCustomizationInstance()))
        end)
        local fragment_slot = read("fragment_slot", function()
            return a.name(object(checked_fragment():GetOwningCustomizationSlot()))
        end)
        read("parameter", function()
            return a.text(a.prop(a.prop(checked_fragment(), "MaterialTarget"), "MaterialParameterName"))
        end)
        read("slot_tags", function()
            local t = a.prop(checked_fragment(), "MaterialTarget")
            local tags = a.values(a.prop(a.prop(t, "SlotNameTagsToApply"), "GameplayTags"))
            local names = {}; for _, value in ipairs(tags) do names[#names + 1] = tag(value) end
            return table.concat(names, ",")
        end)
        local materials = read("materials", function() return target(checked_fragment(),c.profile) end)
        local current_color = read("linear_rgba", function() return color(checked_fragment()) end, rgba)
        read("companion_colors",function()
            assert(fragments.matches(checked_fragment(),c.profile,chosen),"Installed companion colors differ")
            return "verified"
        end)
        -- Audit the equipped fragment even when preview verification fails.
        local source = read("source_fragment", function()
            return single_color(object(c.slot):GetFragments(),c.profile)
        end, a.name)
        local source_color = read("source_linear_rgba", function() return color(object(source)) end, rgba)
        read("source_companion_colors",function()
            assert(fragments.matches(source,c.profile,c.original,true),"Equipped companion colors changed")
            return "verified"
        end)
        local fragment_name = a.name(fragment)
        -- Only this synchronous post-setter boundary may accept a new identity.
        -- Do not adopt the previous stock fragment, the equipped source, or a
        -- similarly colored object encountered later during refresh/recovery.
        local installed_copy = accept_installed_copy and stage == "after-install"
            and fragment_name ~= expected.previous and fragment_name ~= expected.source
            and clone_name_for(expected.preview, fragment_name)
        local checks = {
            {"preview", a.name(preview) == expected.preview}, {"slot", a.name(slot) == expected.slot},
            {"part", part == expected.part}, {"fragment", fragment_name == expected.fragment or not not installed_copy},
            {"owner", owner == expected.preview}, {"target", materials == expected.materials},
            {"color", current_color ~= nil and same_color(current_color, chosen)},
            {"source", a.name(source) == expected.source and source_color ~= nil and same_color(source_color, expected.original)},
            {"fragment_slot", fragment_slot == expected.slot},
        }
        local matches, passed = {}, not read_failed
        for _, check in ipairs(checks) do
            matches[#matches + 1] = check[1] .. "=" .. tostring(check[2])
            passed = passed and check[2]
        end
        log("CHECKPOINT " .. stage .. " | matches | " .. table.concat(matches, " | ") .. " | passed=" .. tostring(passed))
        assert(passed, "Preview verification failed at " .. stage .. "; see CHECKPOINT field values and matches")
        return fragment_name
    end
    -- Recovery is plain data, never Lua code or retained UObject wrappers.
    local function persist(session)
        local f = assert(io.open(recovery_path, "w"), "Cannot write tint recovery record")
        local ok, err = pcall(function()
            local data = ""
            if session then
                assert(target_module.valid(session.profile),"Invalid recovery target profile")
                assert(session.handoff and session.blue,"Preview sessions always own a donor handoff")
                local function encode(c) return string.format("%.17g,%.17g,%.17g,%.17g", c.R, c.G, c.B, c.A) end
                local fields = {"proxy-v7", session.owner, session.preview, session.fragment, session.part, session.materials,
                    encode(session.original), session.phase or "owned", session.handoff.container, session.handoff.display,
                    session.blue.part, encode(session.blue.original), session.blue.slot_vm, "", "",
                    session.profile.slot, session.profile.parameter, session.profile.mesh, session.profile.asset,
                    session.blue.pending_baseline and "pending" or "verified"}
                if session.test_color then
                    assert(rules.color(session.test_color,session.profile.slot,session.profile.parameter)
                        and session.test_color.A==session.original.A, "Invalid custom RGB session")
                    fields[14] = encode(session.test_color)
                end
                if session.previous_color then
                    assert(session.test_color and session.phase == "owned"
                        and rules.color(session.previous_color,session.profile.slot,session.profile.parameter)
                        and session.previous_color.A==session.original.A, "Invalid RGB transition")
                    fields[15] = encode(session.previous_color)
                end
                if session.profile.targets then
                    fields[1]="proxy-v8"; fields[21]=target_module.encode_targets(session.profile)
                end
                if session.profile.skin_race then fields[1]="proxy-v9"; fields[22]=session.profile.skin_race end
                if session.profile.skin_scalar then fields[1]="proxy-v10"; fields[23]=session.profile.skin_scalar end
                if session.profile.bundle then
                    fields[1]="proxy-v11"; fields[21]=session.profile.targets and target_module.encode_targets(session.profile) or ""
                    fields[22]=session.profile.bundle
                    if session.blue.materials then
                        assert(session.blue.materials==target_module.donor_materials(session.profile,session.part,session.blue.part),
                            "Unverified cross-target donor record")
                        fields[1]="proxy-v12"; fields[23]=session.blue.materials
                    end
                end
                data = table.concat(fields, "\n") .. "\n"
                assert(#data<=32768,"Tint recovery size limit")
            end
            assert(f:write(data))
            assert(f:flush())
        end)
        f:close()
        assert(ok, err)
    end
    local function lookup(name)
        assert(worlds.owner(name), "Untrusted recovery object name")
        local path = name:match("^[^ ]+ (.+)$")
        local found = StaticFindObject(path)
        if a.live(found) and a.name(found) == name then return found end
        -- Some builds differ on transient-object path lookup. Only exact names
        -- in this one class are eligible; never select a first/global instance.
        for _, candidate in pairs(candidates("CustomizationInstance")) do
            if a.live(candidate) and a.name(candidate) == name then return candidate end
        end
    end
    local function restore_impl(reason)
        local session = self.pending
        if not session then log("Nothing to restore"); return end
        local owner = lookup(session.owner)
        local restore_color = preview_original(session)
        if owner then
            local preview = optional(owner:GetPreviewCustomizationInstance())
            if a.live(preview) and a.name(preview) == session.preview then
                local may_reset = false
                local slot = object(preview:GetSlotInstance(recovery_tag(session.profile)))
                local values = a.values(slot:GetFragmentInstances())
                local current = values[1]
                local skin_stock=(session.profile.skin_race or session.profile.bundle)
                    and (session.phase=="handoff" or session.phase=="prepared")
                if (session.profile.skin_race or session.profile.bundle)
                    and not (session.blue and session.blue.pending_baseline)
                    and id(slot:GetCustomizationPartPrimaryAssetId())==preview_part(session) then
                    current=single_color(values,session.profile,skin_stock and true or nil)
                end
                if session.blue.pending_baseline then
                    -- Only stock preview activation has happened. No clone or
                    -- color write is permitted before its baseline is durable.
                    assert(session.phase=="handoff","Invalid unverified donor phase")
                    may_reset=id(slot:GetCustomizationPartPrimaryAssetId())==session.blue.part
                elseif skin_stock
                    and id(slot:GetCustomizationPartPrimaryAssetId())==session.blue.part then
                    -- Baseline is verified; any prepared clone is still detached. End
                    -- the stock hover without recoloring its scalar variant.
                    assert(a.name(object(current:GetOwningCustomizationInstance()))==session.preview
                        and a.name(object(current:GetOwningCustomizationSlot()))==a.name(slot)
                        and target(current,session.profile)==(session.blue.materials or session.materials)
                        and same_color(color(current),session.blue.original),"Skin donor changed before reset; recovery retained")
                    may_reset=true
                elseif (#values == 1 or session.profile.skin_race or session.profile.bundle) and a.live(current) and a.name(current) == session.fragment
                    and id(slot:GetCustomizationPartPrimaryAssetId()) == preview_part(session) then
                    assert(a.name(object(current:GetClass())) == COLOR_CLASS, "Owned clone class changed")
                    assert(a.name(object(current:GetOwningCustomizationInstance())) == session.preview
                        and a.name(object(current:GetOwningCustomizationSlot())) == a.name(slot)
                        and target(current,session.profile) == session.materials, "Owned clone targeting changed; recovery retained")
                    if (same_color(color(current), test_color(session)) or same_color(color(current), restore_color)
                        or session.previous_color and same_color(color(current), session.previous_color))
                        and fragments.owned(current,session.profile,test_color(session),session.previous_color,restore_color) then
                        may_reset = true
                        fragments.write(current,session.profile,restore_color,nil,true)
                        assert(same_color(color(current), restore_color), "Restore SetColor readback failed")
                        preview:RefreshCustomization()
                        -- Refresh may rebuild fragments. Verify what is actually
                        -- installed, not a detached wrapper we just recolored.
                        local live_preview = object(owner:GetPreviewCustomizationInstance())
                        assert(a.name(live_preview) == session.preview, "Restore preview changed during refresh")
                        local live_slot = object(live_preview:GetSlotInstance(recovery_tag(session.profile)))
                        assert(id(live_slot:GetCustomizationPartPrimaryAssetId()) == preview_part(session), "Restore swatch changed during refresh")
                        local restored = single_color(live_slot:GetFragmentInstances(),session.profile)
                        assert(fragments.matches(restored,session.profile,restore_color,true),"Restored tint companion colors changed")
                        assert(a.name(object(restored:GetOwningCustomizationInstance())) == session.preview
                            and a.name(object(restored:GetOwningCustomizationSlot())) == a.name(live_slot)
                            and target(restored,session.profile) == session.materials and same_color(color(restored), restore_color),
                            "Restore live fragment verification failed; recovery retained")
                        log("Restored owned clone color; game preview retained | live_fragment=" .. a.name(restored) .. " | " .. reason)
                    else
                        log("Owned clone color changed externally; not overwritten | " .. reason)
                    end
                else
                    if id(slot:GetCustomizationPartPrimaryAssetId()) == preview_part(session) then
                        -- A setter can install a copy before throwing or before
                        -- validation/persistence completes. Never dismiss an
                        -- unknown non-original fragment as successful cleanup.
                        local replacement = single_color(values,session.profile,skin_stock and true or nil)
                        assert(a.name(object(replacement:GetOwningCustomizationInstance())) == session.preview
                            and a.name(object(replacement:GetOwningCustomizationSlot())) == a.name(slot)
                            and target(replacement,session.profile) == session.materials
                            and same_color(color(replacement), restore_color),
                            "Untracked non-original fragment; no object modified; recovery retained")
                        log("Live slot already has original color; no fragment modified | " .. reason)
                        -- Activation may rebuild the stock fragment before cloning.
                        -- Only the pre-write handoff phase may own that original copy,
                        -- or an install that changed nothing: the exact donor object
                        -- this session activated, still at its baseline color.
                        may_reset = session.phase == "handoff" or session.phase == "prepared"
                            or session.phase == "installing" and session.donor_fragment ~= nil
                                and a.name(replacement) == session.donor_fragment
                    else
                        log("Owned swatch already replaced; no current fragment modified | " .. reason)
                    end
                end
                handoff.restore(session, owner, preview, may_reset, function(instance)
                        local source_slot = object(owner:GetSlotInstance(recovery_tag(session.profile)))
                        local source = single_color(source_slot:GetFragmentInstances(),session.profile)
                        assert(id(source_slot:GetCustomizationPartPrimaryAssetId()) == session.part
                            and same_color(color(source), session.original) and target(source,session.profile) == session.materials,
                            "Equipped source changed during blue cleanup; recovery retained")
                        inspect_display(instance, color(source), target(source,session.profile), source_slot:GetCustomizationPartPrimaryAssetId(),session.profile)
                    end, function()
                        -- Rebind the recorded slot VM, including after Lua reload.
                        -- No first-instance fallback and no native-owner reset for blue.
                        assert(allowed_slot_vm(session.blue.slot_vm), "Untrusted blue recovery slot")
                        local vm = optional(StaticFindObject(session.blue.slot_vm:match("^[^ ]+ (.+)$")))
                        if not a.live(vm) or a.name(vm) ~= session.blue.slot_vm then
                            vm = nil
                            for _, candidate in pairs(candidates("BitReactorCustomizationSlotViewModel")) do
                                if a.live(candidate) and a.name(candidate) == session.blue.slot_vm then vm = candidate; break end
                            end
                        end
                        vm = object(vm, "recorded blue slot VM")
                        assert(tag(vm.SlotTag) == session.profile.slot, "Preview reset slot tag changed")
                        local source = single_color(vm:GetFragments(),session.profile)
                        assert(a.name(object(source:GetOwningCustomizationInstance())) == session.owner
                            and id(object(vm.EquippedCustomizationPartViewModel).AssetId) == session.part
                            and same_color(color(source), session.original) and target(source,session.profile) == session.materials,
                            "Blue reset source/swatch changed; recovery retained")
                        vm:ResetPreviewedPart()
                    end)
            else
                log("Owned preview already replaced/cleared; no other preview modified | " .. reason)
            end
        else
            log("Original character no longer exists; no object modified | " .. reason)
        end
        persist(nil)
        self.pending = nil
    end
    function self.restore(reason)
        draft_route,draft_owner=nil,nil
        self.busy = true
        local ok, err = pcall(function()
            -- End the draft even if engine cancellation or cleanup fails.
            if self.pending then self.pending.live = nil end
            runtime:cancel("tint:handoff-check")
            runtime:cancel("tint:timeout")
            restore_impl(reason or "panel")
        end)
        self.busy = false
        if not ok then log("RESTORE FAILED | " .. tostring(err) .. " | Do not save; leave/reopen customization or restart the game") end
        -- Every successful preview end, including timeout, context and failure
        -- rollbacks started here, gives the zone its cleanup turn (Default).
        if ok and self.after_restore then return self.after_restore(reason) end
        return ok
    end
    function self.read_context()
        return resolve()
    end
    function self.bind_selected_context(c)
        assert(c.profile and c.profile.slot==fragment_module.SKIN and type(c.aux)=="string",
            "Selected skin context required")
        return {page=c.page,aux=c.aux,creator=lifetime.bind(c.page),revision=context_revision,epoch=route_epoch,
            vm=a.name(object(c.slot)),owner=a.name(object(c.owner)),part=id(object(c.part).AssetId)}
    end
    function self.read_selected_context(route)
        assert(type(route)=="table" and type(route.vm)=="string" and type(route.owner)=="string"
            and type(route.part)=="string","Selected context binding required")
        -- Native notifications invalidate discovery reuse. Even without a
        -- notification all native objects/relationships are read afresh.
        assert(lifetime.page_active(route.creator,route.page),"Bound selected creator changed")
        local c=resolve(route)
        assert(c.page==route.page and c.aux==route.aux and a.name(c.slot)==route.vm and a.name(c.owner)==route.owner
            and id(c.part.AssetId)==route.part,"Bound selected context changed")
        return c
    end
    function self.verify_editor_display()
        local c=resolve()
        -- Verifies the non-hover display follows the equipped source and has
        -- its color/target. Used only after an editor-session source write.
        handoff.prepare(c,object(c.owner:GetPreviewCustomizationInstance()))
        return true
    end
    function self.inspect()
        local ok, err = pcall(function()
            local c = resolve()
            local preview = resolve_proxy(c)
            log("Target verified | " .. tag(c.slot.SlotTag) .. " | materials=" .. c.materials
                .. " | original_linear_rgba=" .. rgba(c.original) .. " | linked_proxy=" .. a.name(preview))
        end)
        if not ok then log("INSPECT REFUSED | " .. tostring(err)) end
    end
    local function verify_unchanged_context(session,binding)
        -- This baseline is plain data from this apply, never cached UObjects.
        -- Reload recovery has no baseline and must restore, not prolong a test.
        assert(self.pending==session and not session.force_restore_reason,"Preview ownership ended")
        local baseline = session.context
        assert(session.phase == "owned" and baseline, "No active-test context baseline")
        local c = resolve(binding)
        assert(target_module.same(c.profile,session.profile),"Selected target profile changed")
        assert(c.page == baseline.page, "Active customization page changed")
        assert(a.name(c.slot) == baseline.slot_vm, "Selected slot view model changed")
        assert(a.name(c.owner) == session.owner, "Customization character changed")
        assert(id(c.part.AssetId) == session.part, "Equipped accent swatch changed")
        assert(a.name(c.source_slot) == baseline.source_slot and a.name(c.fragment) == baseline.source,
            "Equipped accent fragment/slot changed")
        assert(c.materials == session.materials and same_color(c.original, session.original),
            "Equipped accent color/target changed")
        assert(timed("validate.source_companions",fragments.matches,c.fragment,session.profile,session.original,true),"Equipped companion colors changed")
        local preview = object(c.owner:GetPreviewCustomizationInstance(), "context preview")
        assert(a.name(preview) == session.preview, "Linked preview changed")
        local slot = object(preview:GetSlotInstance(c.slot.SlotTag), "context preview slot")
        assert(a.name(slot) == baseline.preview_slot and tag(slot:GetSlotNameTag()) == session.profile.slot,
            "Preview accent slot changed")
        assert(id(slot:GetCustomizationPartPrimaryAssetId()) == preview_part(session), "Preview accent swatch changed")
        local fragment = timed("validate.preview_fragments",function()
            return fragments.read_matched(slot:GetFragmentInstances(),session.profile,test_color(session))
        end)
        assert(a.name(fragment) == session.fragment, "Tracked preview fragment changed")
        assert(a.name(object(fragment:GetOwningCustomizationInstance())) == session.preview
            and a.name(object(fragment:GetOwningCustomizationSlot())) == baseline.preview_slot,
            "Tracked fragment ownership changed")
        timed("validate.preview_color_target",function()
            assert(target(fragment,session.profile) == session.materials
                and same_color(color(fragment), test_color(session)),
                "Tracked preview color/target changed")
        end)
        timed("validate.preview_meshes",targets.mesh,preview,session.profile)
        timed("validate.display_links",handoff.verify,session,c.owner,preview)
        return c,preview,slot,fragment
    end
    local function verify_live_context(session)
        local reuse=session.live and target_module.preview_policy(session.profile)~=nil
        local revision=context_revision
        local binding=reuse and draft_owner==session and draft_route or nil
        local c,preview,slot,fragment=verify_unchanged_context(session,binding)
        if reuse then
            -- Retain scalar lookup hints only. All native objects, relationships
            -- and colors were freshly checked above, exactly as during a drag.
            binding=binding or {page=c.page,aux=c.aux,creator=lifetime.bind(c.page),revision=revision,epoch=route_epoch}
            assert(context_revision==revision and self.pending==session and session.live
                and not session.force_restore_reason,"Context changed during idle validation")
            draft_route,draft_owner=binding,session
        end
        return c,preview,slot,fragment
    end
    local function schedule_display_check(session)
        local revision = session.color_revision or 0
        runtime:after("tint:handoff-check", 750, function()
            if self.pending ~= session or (session.color_revision or 0) ~= revision then return end
            local verified, failure = pcall(function()
                local live = verify_live_context(session)
                handoff.verify(session, live.owner, object(live.owner:GetPreviewCustomizationInstance()),
                    test_color(session), session.materials, asset_value(session.blue.part))
            end)
            if not verified then
                log("HANDOFF VERIFICATION FAILED | " .. tostring(failure))
                if self.pending==session then self.restore("display handoff verification failed") end
            else
                log("DISPLAY SAMPLE VERIFIED | revision=" .. revision .. " | linear_rgba=" .. rgba(test_color(session)))
            end
        end)
    end
    local function update_owned_color(session, chosen)
        assert(self.pending == session and session.phase == "owned", "Preview session changed")
        assert(session.test_color and rules.input_color(chosen,session.profile.slot,session.profile.parameter)
            and (chosen.A==1 or chosen.A==session.original.A), "Invalid live color")
        assert(not session.force_restore_reason, "Context event already requested restore")
        local revision=(session.color_revision or 0)+1
        local function checkpoint(stage)
            -- Stage trace for the first update only; later stages are in PERF.
            if revision==1 then log("RGB UPDATE | revision=" .. revision .. " | " .. stage) end
        end
        checkpoint("VALIDATE BEGIN")
        local reuse=session.live and target_module.preview_policy(session.profile)~=nil
        local event_revision=context_revision
        local initial_binding=reuse and draft_owner==session and draft_route or nil
        local c,preview,slot,fragment=timed("update.validate_before",verify_unchanged_context,session,initial_binding)
        local binding
        if target_module.preview_policy(session.profile) then
            binding={page=c.page,aux=c.aux,creator=timed("update.bind_creator",lifetime.bind,c.page),revision=context_revision,epoch=route_epoch}
        end
        -- A callback during discovery/binding must not promote a route built
        -- from the old context or allow the first write through that result.
        if reuse then assert(event_revision==context_revision,"Context changed during preview validation") end
        checkpoint("VALIDATE END")
        session.previous_color = session.test_color
        session.test_color = {R=chosen.R,G=chosen.G,B=chosen.B,A=session.original.A}
        timed("update.journal_intent",persist,session) -- accept old/new only on this owned fragment if interrupted
        checkpoint("SET COLOR BEGIN")
        timed("update.write_color",fragments.write,object(fragment),session.profile,session.test_color)
        checkpoint("SET COLOR RETURN")
        -- A native setter may dispatch callbacks/rebuild objects. Reacquire
        -- and verify the owned fragment/link before touching the preview again.
        c,preview,slot,fragment=timed("update.validate_after_write",verify_unchanged_context,session,binding)
        checkpoint("REFRESH BEGIN")
        timed("update.refresh",function() object(preview):RefreshCustomization() end)
        checkpoint("REFRESH RETURN")
        timed("update.validate_after_refresh",verify_unchanged_context,session,binding)
        session.previous_color = nil
        timed("update.journal_complete",persist,session)
        session.color_revision = revision
        checkpoint("VERIFIED")
        schedule_display_check(session)
        if reuse and event_revision==context_revision and self.pending==session and session.live
            and not session.force_restore_reason then
            draft_route,draft_owner=binding,session
        end
        return binding -- returned reader scope stays synchronous; internal hint is draft-owned
    end
    local function apply(requested_color, input_mode)
        if self.blocked then log("APPLY REFUSED | " .. self.blocked); return end
        if self.pending then log("APPLY REFUSED | Restore the previous test first"); return end
        self.busy = true
        local ok, err = pcall(function()
            local revision=context_revision
            local c = timed("opening.resolve",resolve)
            local opening_route
            local hsv=rules.hsv(c.profile)
            assert(not hsv or input_mode=="hsv_shift" or input_mode=="selected","Open the HSV adjustment picker on this scar Look; RGB test inputs are unavailable")
            if input_mode=="selected" then
                -- Picker startup uses this freshly verified selection, never
                -- the developer RGB file. Keep native HSV values unconverted.
                -- RGB controls are bounded; HDR source baselines remain exact
                -- in the recovery record even when their initial UI is clipped.
                requested_color={R=c.original.R,G=c.original.G,B=c.original.B,A=1}
                if not hsv then
                    for _,key in ipairs({"R","G","B"}) do requested_color[key]=math.min(1,math.max(0,requested_color[key])) end
                end
            end
            assert(requested_color ~= nil and rules.input_color(requested_color,c.profile.slot,c.profile.parameter)
                and requested_color.A == 1,"Invalid custom RGB/HSV input")
            -- RGB controls preserve the native source alpha.
            local custom = {R=requested_color.R,G=requested_color.G,B=requested_color.B,A=c.original.A}
            local creator=timed("opening.bind_creator",lifetime.bind,c.page)
            if revision==context_revision then
                opening_route={page=c.page,aux=c.aux,creator=creator,revision=revision,epoch=route_epoch}
            end
            -- Palette/creator/source are verified before resetting anything.
            local blue_vm, blue = timed("opening.donor",find_blue,c)
            local handoff_record
            do
                local preview = object(c.owner:GetPreviewCustomizationInstance())
                assert(worlds.same("owner",a.name(c.owner),"preview",a.name(preview)), "Unsupported preview proxy")
                handoff_record = timed("open.settle", handoff.settle_selected, c, preview, function(instance)
                    local hovered=object(c.slot:PreviewedCustomizationPartViewModel(),"selected slot hover VM")
                    local found=false
                    for _,item in ipairs(targets.palette(c.slot,c.page)) do
                        if item.name==a.name(hovered) and item.asset==id(hovered.AssetId) then found=true end
                    end
                    assert(found,"Selected hover VM is not in the active palette")
                    local _,_,fragment=resolve_proxy(c,{part=id(hovered.AssetId),pending_baseline=true})
                    inspect_display(instance,color(fragment),c.materials,hovered.AssetId,c.profile,true)
                end)
                local checked=timed("opening.after_settle",resolve,opening_route)
                assert(checked.page==c.page and a.name(checked.slot)==a.name(c.slot)
                    and a.name(checked.owner)==a.name(c.owner) and id(checked.part.AssetId)==id(c.part.AssetId)
                    and target_module.same(checked.profile,c.profile) and same_color(checked.original,c.original),
                    "Source changed while settling stock hover")
                c=checked
            end
            -- An inactive proxy can retain the last native hovered swatch. It
            -- is not the visible baseline and will be replaced by our donor.
            local preview, preview_slot, existing = timed("open.proxy", resolve_proxy, c, nil, true)
            assert(rules.color(c.original,c.profile.slot,c.profile.parameter),"Unsupported original value")
            -- Check file access before any color write.
            timed("open.journal", persist, nil)
            handoff_record = timed("open.prepare", handoff.prepare, c, preview)
            assert(clone_name_for(a.name(preview), a.name(existing)), "Unexpected stock preview fragment location")
            self.pending = {owner=a.name(c.owner), preview=a.name(preview), fragment=a.name(existing),
                part=id(c.part.AssetId), materials=c.materials, original=c.original, phase="handoff", handoff=handoff_record, blue=blue, test_color=custom,profile=c.profile}
            timed("open.journal", persist, self.pending) -- activation intent must survive a throw/reload
            if c.profile.skin_race then
                log("SKIN DONOR | ACTIVATE | source=" .. self.pending.part .. " | donor=" .. blue.part)
            end
            timed("open.activate", handoff.activate, self.pending, c, preview, blue_vm)
            preview, preview_slot, existing = timed("open.proxy_donor", resolve_proxy, c, blue)
            assert(a.name(preview) == self.pending.preview, "Activation replaced data proxy")
            if blue.pending_baseline then
                local measured=color(existing)
                assert(rules.color(measured,c.profile.slot,c.profile.parameter),"Unsupported donor baseline value/alpha")
                -- Verify the displayed copy as well as the preview data,
                -- then journal the measured baseline before any color write.
                timed("open.verify_display", handoff.verify, self.pending,c.owner,preview,measured,blue.materials or c.materials,blue_vm.AssetId)
                blue.original=measured; blue.pending_baseline=nil
                self.pending.fragment=a.name(existing)
                timed("open.journal", persist, self.pending)
                log("PALETTE DONOR VERIFIED | " .. blue.part .. " | " .. rgba(measured)
                    .. " | donor_materials=" .. (blue.materials or c.materials) .. " | source_materials=" .. c.materials)
            end
            timed("open.verify_display", handoff.verify, self.pending, c.owner, preview, blue.original, blue.materials or c.materials, blue_vm.AssetId)
            -- Activation is not allowed to mutate the equipped source.
            local checked = timed("opening.after_activation",resolve,opening_route)
            assert(a.name(checked.owner) == a.name(c.owner) and a.name(checked.fragment) == a.name(c.fragment)
                and id(checked.part.AssetId) == id(c.part.AssetId) and same_color(checked.original,c.original),
                "Blue activation changed equipped source")
            assert(fragments.matches(checked.fragment,c.profile,c.original,true),"Donor activation changed source companion colors")
            log("BLUE BASELINE VERIFIED | preview_part=" .. blue.part .. " | preview_rgba=" .. rgba(blue.original)
                .. " | equipped_part=" .. id(c.part.AssetId) .. " | equipped_rgba=" .. rgba(c.original))
            local clone, clones = timed("open.clone", function() return single_color(c.slot:CloneFragments(preview_slot),c.profile) end)
            if c.profile.skin_race or c.profile.bundle then
                fragments.distinct(clones,c.slot:GetFragments(),preview_slot:GetFragmentInstances())
                log("TINT BUNDLE VERIFIED | complete clone array; companion fragments preserved")
            end
            assert(a.name(clone) ~= a.name(c.fragment) and a.name(clone) ~= a.name(existing), "Clone aliases an original fragment")
            assert(a.name(object(clone:GetOwningCustomizationInstance())) == a.name(preview), "Clone is not owned by preview")
            assert(target(clone,c.profile) == c.materials, "Cloning changed material targeting")
            assert(clone_name_for(a.name(preview), a.name(clone)), "Unexpected clone location")
            self.pending = {owner=a.name(c.owner), preview=a.name(preview), fragment=a.name(clone),
                part=id(c.part.AssetId), materials=c.materials, original=c.original, phase="prepared", handoff=handoff_record, blue=blue, test_color=custom,profile=c.profile,
                donor_fragment=a.name(existing), -- in memory only: proves an unchanged activation on rollback
                context={page=c.page, slot_vm=a.name(c.slot), source=a.name(c.fragment),
                    source_slot=a.name(c.source_slot), preview_slot=a.name(preview_slot)}}
            timed("open.journal", persist, self.pending)
            local expected = {preview=self.pending.preview, slot=a.name(preview_slot), fragment=self.pending.fragment,
                part=preview_part(self.pending), materials=c.materials, source=a.name(c.fragment), original=c.original,
                previous=a.name(existing)}
            log("EXPECT | preview=" .. expected.preview .. " | slot=" .. expected.slot .. " | fragment=" .. expected.fragment
                .. " | previous_fragment=" .. a.name(existing) .. " | part=" .. expected.part
                .. " | materials=" .. expected.materials .. " | source=" .. expected.source)
            local chosen = test_color(self.pending)
            timed("open.write_clone", fragments.write, clone, c.profile, chosen, clones)
            assert(same_color(color(clone), chosen), "Clone SetColor readback did not match")
            if c.profile.skin_race then fragments.read(clones,c.profile) end
            log("CLONE COLOR VERIFIED | linear_rgba=" .. rgba(chosen) .. " | original_linear_rgba=" .. rgba(c.original))
            self.pending.phase = "installing"
            timed("open.journal", persist, self.pending)
            log("CALL | SetFragmentInstances")
            timed("open.install", function() preview_slot:SetFragmentInstances(clones) end)
            local installed = timed("open.verify_install", verify_checkpoint, "after-install", c, expected, chosen, true)
            -- Update memory before persistence: a disk failure still permits
            -- immediate rollback of this fully validated installed fragment.
            self.pending.fragment, self.pending.phase = installed, "owned"
            timed("open.journal", persist, self.pending)
            log("INSTALLED FRAGMENT TRACKED | submitted=" .. expected.fragment .. " | installed=" .. installed)
            expected.fragment = installed
            log("CALL | RefreshCustomization")
            timed("open.refresh", function() preview:RefreshCustomization() end)
            timed("open.verify_refresh", verify_checkpoint, "after-refresh", c, expected, chosen)
            local session = self.pending
            runtime:after("tint:timeout", 15000, function()
                if self.pending == session and not session.live then self.restore("15-second timeout") end
            end)
            timed("open.verify_settled", handoff.verify, session, c.owner, preview)
            schedule_display_check(session)
            log("PREVIEW APPLIED | custom_linear_rgba=" .. rgba(chosen) .. " | original_linear_rgba=" .. rgba(c.original)
                .. " | source unchanged | preview=" .. session.preview .. " | auto-restore=15s | visual confirmation required")
        end)
        if not ok then
            log("APPLY REFUSED/FAILED | " .. tostring(err))
            if self.pending then
                self.restore("failed apply rollback")
            end
        end
        self.busy = false
        return ok
    end
    function self.begin_live()
        draft_route,draft_owner=nil,nil
        if not apply(nil,"selected") then return nil end
        local session = self.pending
        local ok, err = pcall(function()
            assert(session and session.phase == "owned" and session.test_color, "No owned picker preview")
            session.live = true
            -- apply arms the short diagnostic timer. A live draft
            -- instead ends on Cancel, Apply or a verified context change.
            runtime:cancel("tint:timeout")
            log("LIVE PICKER START | no draft timeout | no equip/save")
        end)
        if not ok then
            log("LIVE PICKER FAILED | " .. tostring(err)); self.restore("picker start failed"); return nil
        end
        return session
    end
    function self.check_live(session)
        if not session or self.pending ~= session or not session.live then return false, "Preview ended" end
        local ok,why=pcall(function()
            assert(not session.force_restore_reason, "Context event requested restore")
            verify_live_context(session)
        end)
        if not ok then
            lookup_route=nil
            if draft_owner==session then draft_route,draft_owner=nil,nil end
        end
        return ok,why
    end
    local function update_live(session, chosen, consumer)
        if not session or self.pending ~= session or not session.live then return false end
        self.busy = true
        local binding
        local ok, err = pcall(function()
            binding=timed("update.core",update_owned_color,session,chosen)
            -- Every log line is flushed and console-mirrored; log the first
            -- update only. Failures and Apply still record the exact value.
            if session.color_revision==1 then
                log("LIVE PICKER UPDATE | revision=1 | linear_rgba=" .. rgba(session.test_color) .. " | source unchanged")
            end
        end)
        self.busy = false
        if not ok then
            log("LIVE PICKER FAILED | " .. tostring(err))
            lookup_route=nil
            if self.pending==session then self.restore("live picker update failed") end
        end
        if ok and consumer then
            -- Do not retain native results or expose a reusable cross-tick cache.
            -- The consumer runs after busy is cleared, preserving event handling.
            local active,revision=true,session.color_revision
            local function read()
                assert(active and session.live and session.color_revision==revision,"Update context scope expired")
                return verify_unchanged_context(session,binding)
            end
            local completed,result=pcall(consumer,read)
            active=false
            if not completed or result~=true then
                lookup_route=nil
                if draft_owner==session then draft_route,draft_owner=nil,nil end
            end
            if not completed then log("UPDATE CONSUMER FAILED | " .. tostring(result)) end
            return completed and result==true
        end
        return ok
    end
    function self.update_live(session,chosen) return update_live(session,chosen) end
    function self.update_live_scoped(session,chosen,consumer)
        assert(type(consumer)=="function","Update consumer required")
        return update_live(session,chosen,consumer)
    end
    function self.invalidate_context_lookup(reason)
        context_revision=context_revision+1
        if rules.structural_context(reason) then
            route_epoch=route_epoch+1
            lookup_route=nil
            draft_route,draft_owner=nil,nil
        end
    end
    function self.context_changed(reason)
        self.invalidate_context_lookup(reason)
        -- Invalidation also retires draft routes, even during synchronous writes.
        if self.busy or not self.pending then return end
        local session = self.pending
        -- Only the observed redundant slot notification is eligible. Equip,
        -- hover, reset, page-close and other events remain unconditional stops.
        -- Latch those stops so a later slot notification cannot replace them
        -- when the runtime coalesces queued actions under this key.
        if reason ~= "UpdateCurrentCustomizationSlotVM" then
            session.force_restore_reason = session.force_restore_reason or tostring(reason)
        end
        runtime:after("tint:context-restore", 1, function()
            if self.pending ~= session then return end
            if session.force_restore_reason then
                self.restore("context changed: " .. session.force_restore_reason)
                return
            end
            local unchanged, err = pcall(verify_unchanged_context, session)
            if unchanged then
                log("CONTEXT UNCHANGED | UpdateCurrentCustomizationSlotVM | preview retained; "
                    .. (session.live and "no draft timeout" or "existing restore deadline unchanged"))
            else
                log("CONTEXT CHANGED/UNVERIFIED | " .. tostring(err):gsub("[\r\n]", " "))
                self.restore("context changed/unverified: UpdateCurrentCustomizationSlotVM")
            end
        end)
    end
    function self.start()
        local f = io.open(recovery_path, "r")
        if f then
            local data = f:read(32769); f:close()
            if data then data = data:gsub("\r\n", "\n") end
            if data and data ~= "" then
                local fields = {}
                for line in data:gmatch("([^\n]*)\n") do fields[#fields + 1] = line end
                local original, count = {}, 0
                for value in (fields[7] or ""):gmatch("[^,]+") do
                    count = count + 1
                    local number = tonumber(value)
                    if not number or number ~= number or math.abs(number)==math.huge or count > 4 then count = -1; break end
                    original[({"R","G","B","A"})[count]] = number
                end
                local blue_original, blue_count = {}, 0
                for value in (fields[12] or ""):gmatch("[^,]+") do
                    blue_count = blue_count + 1
                    local number = tonumber(value)
                    if not number or number ~= number or math.abs(number)==math.huge or blue_count > 4 then blue_count = -1; break end
                    blue_original[({"R","G","B","A"})[blue_count]] = number
                end
                local requested, requested_count = {}, 0
                for value in (fields[14] or ""):gmatch("[^,]+") do
                    requested_count = requested_count + 1
                    if requested_count > 4 then break end
                    requested[({"R","G","B","A"})[requested_count]] = tonumber(value)
                end
                local requested_ok = requested_count == 4 and rules.color(requested,fields[16],fields[17]) and requested.A==original.A
                    and (fields[14] or ""):match("^[^,]+,[^,]+,[^,]+,[^,]+$")
                local previous, previous_count = {}, 0
                for value in (fields[15] or ""):gmatch("[^,]+") do
                    previous_count = previous_count + 1
                    if previous_count > 4 then break end
                    previous[({"R","G","B","A"})[previous_count]] = tonumber(value)
                end
                local previous_ok = previous_count == 4 and rules.color(previous,fields[16],fields[17]) and previous.A==original.A
                    and (fields[15] or ""):match("^[^,]+,[^,]+,[^,]+,[^,]+$")
                local profile={slot=fields[16],parameter=fields[17],mesh=fields[18],asset=fields[19]}
                if fields[1]=="proxy-v11" or fields[1]=="proxy-v12" then profile.bundle=fields[22] end
                if fields[1]=="proxy-v9" or fields[1]=="proxy-v10" then profile.skin_race=fields[22] end
                if fields[1]=="proxy-v10" then profile.skin_scalar=fields[23] end
                local generic_ok=(#fields==20 and fields[1]=="proxy-v7"
                    or #fields==22 and fields[1]=="proxy-v11"
                        and (fields[21]=="" or target_module.decode_targets(profile,fields[21]))
                    or #fields==23 and fields[1]=="proxy-v12"
                        and (fields[21]=="" or target_module.decode_targets(profile,fields[21]))
                        and fields[23]==target_module.donor_materials(profile,fields[5],fields[11])
                        and fields[6]=="MI_Head"
                    or #fields==21 and fields[1]=="proxy-v8" and target_module.decode_targets(profile,fields[21])
                    or (#fields==22 and fields[1]=="proxy-v9"
                        or #fields==23 and fields[1]=="proxy-v10" and profile.skin_scalar=="outfit")
                        and fragment_module.valid_race(profile.skin_race)
                        and target_module.decode_targets(profile,fields[21]))
                    and target_module.valid(profile)
                    and (fields[11] or ""):match("^CustomizationPartDefinition:[%w_]+$")
                    and (fields[11]~=fields[5] or target_module.self_preview(profile,fields[5]))
                    and not fields[11]:match("_None$") and blue_count==4 and rules.color(blue_original,profile.slot,profile.parameter)
                    and rules.preview_asset(profile.slot,fields[11],profile.parameter,profile.bundle)
                    and (fields[12] or ""):match("^[^,]+,[^,]+,[^,]+,[^,]+$")
                    and (fields[7] or ""):match("^[^,]+,[^,]+,[^,]+,[^,]+$")
                    and allowed_slot_vm(fields[13]) and rules.color(original,profile.slot,profile.parameter)
                    and (fields[14]=="" or requested_ok) and (fields[15]=="" or previous_ok and requested_ok and fields[8]=="owned")
                    and (fields[20]=="verified" or fields[20]=="pending" and fields[8]=="handoff")
                    and handoff_module.valid_record(fields[9],fields[10])
                    and (fields[8]=="handoff" or fields[8]=="prepared" or fields[8]=="installing" or fields[8]=="owned")
                if #data <= 32768 and data:sub(-1) == "\n" and generic_ok and worlds.same("owner",fields[2],"preview",fields[3])
                    and clone_name_for(fields[3], fields[4]) and count == 4
                    and fields[5]:match("^CustomizationPartDefinition:[%w_]+$") and rules.materials(fields[6]) then
                    self.pending = {owner=fields[2], preview=fields[3], fragment=fields[4], part=fields[5], materials=fields[6],
                        original=original, phase=fields[8], profile=profile,
                        handoff={container=fields[9],display=fields[10]},
                        blue={part=fields[11],original=blue_original,slot_vm=fields[13],pending_baseline=fields[20]=="pending" or nil}}
                    if fields[1]=="proxy-v12" then self.pending.blue.materials=fields[23] end
                    if requested_ok then self.pending.test_color=requested end
                    if previous_ok then self.pending.previous_color=previous end
                    runtime:after("tint:recovery", 1, function() self.restore("startup/reload recovery") end)
                else
                    self.blocked = "Malformed tint recovery record; inspect Recovery/tint_recovery.txt before applying"
                    log(self.blocked)
                end
            end
        end
    end
    -- Inclusive per-layer opening time for the performance log; no behavior change.
    local timed_begin_live=self.begin_live
    function self.begin_live(...)
        if runtime.perf then return runtime.perf.measure("begin.regular",timed_begin_live,...) end
        return timed_begin_live(...)
    end
    return self
end
return M
