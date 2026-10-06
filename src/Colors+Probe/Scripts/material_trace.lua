-- Read-only, opt-in game-thread snapshots. Never creates/sets materials or
-- refreshes actors. Only scalar window state survives between captures.
local M = {}
local WORLD = "/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local PARAMS = {"Color 01", "Color 02"}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local SKIN_MATERIALS={MI_Head=true,MI_Body=true,MI_Neck=true}
local JOBS = {"materials:event", "materials:settled", "materials:expiry", "materials:command", "materials:save-command"}
function M.new(runtime, a, resolve_context)
    local self = {window=nil, serial=0}
    local function clean(v) return tostring(v):gsub("[\r\n\t]", " "):sub(1, 1400) end
    local function log(s) runtime.log("MATERIAL TRACE | " .. s) end
    local function object(v)
        v = a.unwrap(v); assert(a.live(v), "Required live object unavailable"); return v
    end
    local function prop(o, key)
        local v = o[key]; assert(v ~= nil, "Property unavailable: " .. key); return v
    end
    local function in_menu(v)
        if not a.live(v) then return false end
        local path = a.name(v):match("^[^ ]+ (.+)$")
        return path and path:sub(1, #WORLD) == WORLD
    end
    local function rgba(v)
        v = a.unwrap(v)
        local out = {}
        for _, key in ipairs({"R","G","B","A"}) do
            local n = a.prop(v, key)
            assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Unreadable RGBA." .. key)
            out[#out + 1] = string.format("%.6f", n)
        end
        return table.concat(out, ",")
    end
    function self.stop(reason)
        self.window = nil
        for _, key in ipairs(JOBS) do runtime:cancel(key) end
        log("STOP | " .. (reason or "panel"))
    end
    function self.capture(reason,once)
        if not once then
            if not self.window then return end
            if self.window.captures >= 20 then self.stop("20-capture limit"); return end
            self.window.captures = self.window.captures + 1
        end
        self.serial = self.serial + 1
        local function emit(s) log("capture=" .. self.serial .. " | " .. s) end
        local function read(key, getter, display)
            local ok, v = pcall(getter)
            if not ok then emit(key .. ".error=" .. clean(v)); return nil end
            local shown_ok, shown = pcall(display or tostring, v)
            emit(key .. "=" .. (shown_ok and clean(shown) or "<display error>"))
            return v
        end
        local function fields(label, o, keys)
            for _, key in ipairs(keys) do read(label .. "." .. key, function() return prop(o, key) end) end
        end
        local ok, err = pcall(function()
            local c = resolve_context()
            emit("BEGIN | " .. reason .. " | read-only | visibility is a hint, not proof of screen ownership")
            local skin=c.profile and c.profile.slot==SKIN
            local parameters=skin and {"Skin Coloration"} or PARAMS
            local parameter_set={}; for _,p in ipairs(parameters) do parameter_set[p]=true end
            if skin then
                emit("skin.source_layout=" .. (c.profile.skin_scalar or "meshes"))
                read("skin.source_asset",function()
                    local id=object(c.part).AssetId
                    return a.text(id.PrimaryAssetType.Name) .. ":" .. a.text(id.PrimaryAssetName)
                end)
            end
            read("source.fragment", function() return object(c.fragment) end, a.name)
            read("source.fragment_rgba", function() return rgba(c.fragment:GetColor()) end)
            local pending = runtime.tint and runtime.tint.pending
            emit("test_fragment=" .. (pending and pending.fragment or "<none>"))
            local source_actor = read("source.actor", function() return object(c.owner:GetOwner()) end, a.name)
            read("source.fragment_actor", function() return object(c.fragment:GetOwningActor()) end, a.name)
            local preview = read("data.instance", function() return object(c.owner:GetPreviewCustomizationInstance()) end, a.name)
            local data_actor = read("data.actor", function() return object(object(preview):GetOwner()) end, a.name)
            local mesh_class = read("mesh_class", function()
                local v = object(StaticFindObject("/Script/Engine.MeshComponent"))
                assert(a.name(v) == "Class /Script/Engine.MeshComponent", "Unexpected mesh class lookup"); return v
            end, a.name)
            local names = {}
            local name_parameters={}; for _,p in ipairs(parameters) do name_parameters[#name_parameters+1]=p end
            if skin then name_parameters[#name_parameters+1]="Enable Tinting" end
            for _, parameter in ipairs(name_parameters) do
                names[parameter] = read("fname." .. parameter, function()
                    local v = FName(parameter); assert(a.text(v) == parameter, "FName round-trip mismatch"); return v
                end, a.text)
            end
            local actors, actor_seen = {}, {}
            local function add_actor(label, actor, instance, linked_display)
                if not a.live(actor) or (not linked_display and not in_menu(actor)) then
                    emit(label .. "=<unavailable/outside main menu>"); return
                end
                local name = a.name(actor); emit(label .. "=" .. name)
                if actor_seen[name] then return end
                if #actors >= 4 then emit("actors.truncated=true"); return end
                actor_seen[name] = true
                local entry = {label=label, actor=actor, instance=instance}
                -- The display candidate is the missing measurement. Read it
                -- before the source/data actors can exhaust the material budget.
                if linked_display then table.insert(actors, 1, entry)
                else actors[#actors + 1] = entry end
            end
            add_actor("equipped", source_actor, c.owner)
            add_actor("preview-data", data_actor, preview)
            local containers = read("containers.count", function()
                local v = FindAllOf("BP_CustomizationPreviewProxyContainer_C")
                return v == nil and {} or a.values(v)
            end, function(v) return #v end)
            local matched = 0
            for index = 1, math.min(containers and #containers or 0, 8) do
                local container = containers[index]
                if in_menu(container) then
                    local label = "container[" .. index .. "]"
                    local storage = read(label .. ".ProxyDataStorage", function() return object(container.ProxyDataStorage) end, a.name)
                    if in_menu(data_actor) and a.live(storage) and a.name(storage) == a.name(data_actor) then
                        matched = matched + 1; emit(label .. ".matched=" .. a.name(container))
                        fields(label, container, {"IsPreviewing", "DelayProxyRefreshing", "PreviousDelayProxyRefreshing"})
                        local actor = read(label .. ".ProxyCharacter", function() return object(container.ProxyCharacter) end, a.name)
                        if a.live(actor) then
                            -- Only this exact reference from the matched main-menu
                            -- container may cross levels. Never scan display actors
                            -- globally or resolve one by a guessed name/path.
                            emit(label .. ".display_link=matched-container.ProxyCharacter | outside_main_menu=" .. tostring(not in_menu(actor)))
                            local instance = read(label .. ".display_instance", function()
                                local v = object(actor.CustomizationInstance)
                                assert(a.name(object(v:GetOwner())) == a.name(actor), "Display instance owner mismatch")
                                return v
                            end, a.name)
                            fields(label .. ".display", actor, {"ListenToRefreshEvent", "DelayCustomizationRefresh", "DelayEnabled", "In Main Menu Character Customization"})
                            read(label .. ".display.ClonedFromCharacter", function() return object(actor.ClonedFromCharacter) end, a.name)
                            add_actor(label .. ".display-candidate", actor, instance, true)
                        else
                            emit(label .. ".display-candidate=<unavailable linked actor>")
                        end
                    end
                end
            end
            emit("matched_containers=" .. matched)
            if containers and #containers > 8 then emit("containers.truncated=true") end
            local material_seen, material_count = {}, 0
            local function material_detail(material)
                local name = a.name(material)
                if material_seen[name] then return end
                if material_count >= 48 then emit("materials.truncated=true"); return end
                material_seen[name] = true; material_count = material_count + 1
                local label = "material[" .. material_count .. "]"
                emit(label .. ".object=" .. name)
                local function supported(v)
                    return v == "Class /Script/Engine.MaterialInstanceDynamic" or v == "Class /Script/Engine.MaterialInstanceConstant"
                end
                local class = read(label .. ".class", function() return a.name(object(material:GetClass())) end)
                if not supported(class) then emit(label .. ".getter=unsupported material class; skipped"); return end
                for _, parameter in ipairs(parameters) do
                    if names[parameter] then read(label .. "." .. parameter .. ".getter_rgba", function()
                        return rgba(material:K2_GetVectorParameterValue(names[parameter]))
                    end) end
                end
                if skin and names["Enable Tinting"] and class=="Class /Script/Engine.MaterialInstanceDynamic" then
                    read(label .. ".Enable Tinting.getter_scalar",function()
                        local v=object(material):K2_GetScalarParameterValue(names["Enable Tinting"])
                        assert(type(v)=="number" and v==v and math.abs(v)<math.huge,"Unreadable scalar")
                        return v
                    end)
                end
                emit(label .. ".getter_parameter_presence=unverified; zero/default is not proof of a defined parameter")
                local current, seen = material, {}
                for depth = 0, 3 do
                    if not a.live(current) then break end
                    local n = a.name(current)
                    if seen[n] then emit(label .. ".parent_cycle=true"); break end
                    seen[n] = true
                    local chain = label .. ".chain[" .. depth .. "]"; emit(chain .. ".object=" .. n)
                    local cls = read(chain .. ".class", function() return a.name(object(current:GetClass())) end)
                    if not supported(cls) then break end
                    local overrides = read(chain .. ".vector_overrides.count", function()
                        return a.values(prop(current, "VectorParameterValues"))
                    end, function(v) return #v end)
                    for row=1,math.min(overrides and #overrides or 0,64) do
                        local override=overrides[row]
                        local success, value = pcall(function()
                            local info = prop(override, "ParameterInfo")
                            local parameter = a.text(prop(info, "Name"))
                            if parameter_set[parameter] then
                                return "name=" .. parameter .. " | association=" .. a.text(prop(info, "Association"))
                                    .. " | index=" .. a.text(prop(info, "Index")) .. " | rgba=" .. rgba(prop(override, "ParameterValue"))
                            end
                        end)
                        if not success then emit(chain .. ".override[" .. row .. "].error=" .. clean(value))
                        elseif value then emit(chain .. ".override[" .. row .. "] | " .. value) end
                    end
                    if overrides and #overrides>64 then emit(chain .. ".vector_overrides.truncated=true") end
                    if skin then
                        local scalars=read(chain .. ".scalar_overrides.count",function()
                            return a.values(prop(object(current),"ScalarParameterValues"))
                        end,function(v) return #v end)
                        for row=1,math.min(scalars and #scalars or 0,64) do
                            read(chain .. ".scalar_override[" .. row .. "]",function()
                                local info=prop(scalars[row],"ParameterInfo")
                                local parameter=a.text(prop(info,"Name"))
                                if parameter~="Enable Tinting" then return "unrelated" end
                                local value=prop(scalars[row],"ParameterValue")
                                assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Unreadable scalar override")
                                return "name=" .. parameter .. " | association=" .. a.text(prop(info,"Association"))
                                    .. " | index=" .. a.text(prop(info,"Index")) .. " | value=" .. value
                            end)
                        end
                        if scalars and #scalars>64 then emit(chain .. ".scalar_overrides.truncated=true") end
                    end
                    current = read(chain .. ".parent", function() return a.unwrap(prop(current, "Parent")) end, a.name)
                    if depth == 3 and a.live(current) then emit(label .. ".parent_depth_limit=true") end
                end
            end
            for _, entry in ipairs(actors) do
                local actor, label = entry.actor, entry.label
                fields(label, actor, {"bHidden"})
                read(label .. ".recently_rendered_hint", function() return actor:WasRecentlyRendered(0.25) end)
                read(label .. ".instance_refresh_disabled", function() return object(entry.instance):IsRefreshingDisabled() end)
                read(label .. ".accent_fragment_rgba", function()
                    local slot = object(object(entry.instance):GetSlotInstance(c.slot.SlotTag))
                    local fragments = a.values(slot:GetFragmentInstances())
                    assert(#fragments==(skin and 3 or 1), "Unexpected trace fragment count")
                    local fragment = object(fragments[skin and 2 or 1])
                    assert(a.name(object(fragment:GetClass())) == "Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor", "Unexpected accent class")
                    if skin then
                        local scalar=object(fragments[3])
                        assert(a.name(object(scalar:GetClass()))=="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialScalar","Unexpected scalar class")
                        emit(label .. ".skin.fragment_enable_tinting=" .. clean(scalar.Value))
                        local tags=a.values(scalar.MaterialTarget.SlotNameTagsToApply.GameplayTags)
                        assert(#tags<=5,"Unexpected scalar target count")
                        for i,t in ipairs(tags) do emit(label .. ".skin.scalar_target[" .. i .. "]=" .. a.text(t.TagName)) end
                    end
                    return a.name(fragment) .. " | rgba=" .. rgba(fragment:GetColor())
                end)
                if mesh_class then
                    local components = read(label .. ".meshes.count", function()
                        return a.values(actor:K2_GetComponentsByClass(mesh_class))
                    end, function(v) return #v end)
                    for index = 1, math.min(components and #components or 0, 24) do
                        read(label .. ".mesh[" .. index .. "]", function()
                            local component = object(components[index]); local key = label .. ".mesh[" .. index .. "]"
                            assert(a.name(object(component:GetOwner())) == a.name(actor), "Mesh owner mismatch")
                            emit(key .. ".object=" .. a.name(component))
                            read(key .. ".asset", function() return object(component:GetSkinnedAsset()) end, a.name)
                            read(key .. ".visible", function() return component:IsVisible() end)
                            read(key .. ".recently_rendered_hint", function() return component:WasRecentlyRendered(0.25) end)
                            fields(key, component, {"bHiddenInGame","bRenderInMainPass","bOwnerNoSee","bOnlyOwnerSee","bVisibleInSceneCaptureOnly","bHiddenInSceneCapture"})
                            local count = read(key .. ".material_count", function()
                                local n = component:GetNumMaterials()
                                assert(type(n) == "number" and n >= 0 and n < math.huge and n % 1 == 0, "Invalid material count"); return n
                            end)
                            local slots = read(key .. ".slot_names.count", function() return a.values(component:GetMaterialSlotNames()) end, function(v) return #v end)
                            local labels = {}
                            for slot_row=1,math.min(slots and #slots or 0,64) do
                                local slot_name=slots[slot_row]
                                local material_index = read(key .. ".slot_index." .. a.text(slot_name), function() return component:GetMaterialIndex(slot_name) end)
                                if type(material_index) == "number" then labels[material_index] = a.text(slot_name) end
                            end
                            for material_index = 0, math.min(count or 0, 16) - 1 do
                                local mat_key = key .. ".material[" .. material_index .. "]"
                                emit(mat_key .. ".slot=" .. (labels[material_index] or "<unavailable>"))
                                local material = read(mat_key .. ".object", function() return object(component:GetMaterial(material_index)) end, a.name)
                                if material and (not skin or SKIN_MATERIALS[labels[material_index]]) then material_detail(material) end
                            end
                            if count and count > 16 then emit(key .. ".materials.truncated=true") end
                            return "done"
                        end)
                    end
                    if components and #components > 24 then emit(label .. ".meshes.truncated=true") end
                end
            end
            emit("END | actors=" .. #actors .. " | unique_materials=" .. material_count)
        end)
        if not ok then emit("CAPTURE REFUSED/FAILED | " .. clean(err)) end
        return ok
    end
    function self.save_capture(stage)
        local ok,err=pcall(function()
            assert(stage=="baseline" or stage=="before" or stage=="after","Invalid save capture stage")
            local tint=assert(runtime.tint,"Tint context unavailable")
            assert(not runtime.skin_target or not (runtime.skin_target.pending or runtime.skin_target.blocked),
                "Stop/recover colors_target before save snapshots")
            assert(not tint.pending and not tint.blocked and not (runtime.picker and runtime.picker.active),
                "Close/Apply the picker first; no active draft or blocked recovery allowed")
            local applied=tint.applied
            if stage=="before" then assert(applied,"Apply the custom skin color before this capture")
            else
                assert(not applied and not (runtime.skin_enable and runtime.skin_enable.pending),
                    "Baseline/after must not contain an active Colors+ Apply or enable override")
            end
            local c=resolve_context()
            assert(c.profile and c.profile.slot==SKIN,"Select the skin color page first")
            if applied then
                assert(applied.owner==a.name(object(c.owner)) and applied.fragment==a.name(object(c.fragment)),
                    "Applied color belongs to a different source")
            end
            log("SAVE SNAPSHOT | stage=" .. stage .. " | BEGIN | next_capture=" .. (self.serial+1)
                .. " | version=" .. tostring(runtime.version) .. " | applied=" .. tostring(applied~=nil)
                .. " | enable_mode=" .. tostring(runtime.skin_enable and runtime.skin_enable.pending and runtime.skin_enable.pending.mode)
                .. " | runtime observations only; not direct save-file contents")
            if applied then
                log("SAVE SNAPSHOT | stage=" .. stage .. " | original=" .. rgba(applied.original)
                    .. " | chosen=" .. rgba(applied.chosen) .. " | part=" .. clean(applied.part))
            end
            assert(self.capture("SAVE SNAPSHOT " .. stage,true),"Snapshot context failed; do not treat missing values as zero")
            log("SAVE SNAPSHOT | stage=" .. stage .. " | END | capture=" .. self.serial
                .. " | individual read errors mark unavailable measurements")
        end)
        if not ok then log("SAVE SNAPSHOT | stage=" .. clean(stage) .. " | REFUSED/FAILED | " .. clean(err)) end
        return ok
    end
    function self.event(reason)
        local window = self.window
        if not window then return end
        for _, sample in ipairs({{key="materials:event", delay=150}, {key="materials:settled", delay=750}}) do
            runtime:after(sample.key, sample.delay, function()
                if self.window == window then self.capture(reason .. " +" .. sample.delay .. "ms") end
            end)
        end
    end
    function self.arm()
        self.stop("new window")
        local window = {captures=0}; self.window = window
        log("ARMED | 60 seconds | max 20 captures | read-only; no material creation or setters")
        runtime:after("materials:expiry", 60000, function() if self.window == window then self.stop("60-second timeout") end end)
        self.capture("armed baseline")
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then return end
        runtime:console("colors_save",function(_,args)
            args=args or {}; local stage=args[1]
            if #args~=1 or (stage~="baseline" and stage~="before" and stage~="after") then
                log("Usage: colors_save [baseline|before|after]"); return
            end
            runtime:after("materials:save-command",1,function() self.save_capture(stage) end)
        end)
        log("CONSOLE READY | colors_save [baseline|before|after] | read-only skin snapshots")
        runtime:console("colors_materials",function(_,args)
            args=args or {}; local action=tostring(args[1] or "start"):lower()
            if #args>1 or (action~="start" and action~="sample" and action~="stop") then
                log("Usage: colors_materials [start|sample|stop]"); return
            end
            runtime:after("materials:command",1,function()
                if action=="start" then self.arm()
                elseif action=="stop" then self.stop("console")
                elseif self.window then self.capture("console sample")
                else log("No active capture window; use colors_materials start") end
            end)
        end)
        log("CONSOLE READY | colors_materials [start|sample|stop]")
    end
    return self
end
return M
