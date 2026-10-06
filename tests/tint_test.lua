-- Run: tools/run-tests.sh tint
local scripts = assert(arg[1])
local helpers=dofile((arg[0]:match("^(.*[/\\])") or "") .. "helpers.lua")
helpers.share_modules(scripts)
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
local zone_module = assert(loadfile(scripts .. "/color_zone.lua"))()
local journal=helpers.journal()
local tint = module.new(runtime, probe.access, "recovery")

-- Display handoff: stock preview proxy container, data proxy and display.
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
refresh_behavior = function()
    if container.IsPreviewing and display.ClonedFromCharacter == data_actor and not frozen_display then
        display_color = proxy_fragment:GetColor()
    end
end

-- Palette donor and the generic creator page (live palette, donor activation).
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
local rgb_module = assert(loadfile(scripts .. "/rgb_input.lua"))()
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

-- Every supported profile: begin, warm drafts, structural invalidation,
-- display checks, recovery and Cancel on the regular engine.
do
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
        -- hair/lipstick Color. The Default selection and preview engine must agree.
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
        local s=assert(zone_module.new(runtime,probe.access,journal,{preview=g}).begin_live(),table.concat(messages,"\n"))
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
        -- The selected slot's verified stock hover is settled before
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
end
aux.CurrentCustomizationSlotVM=slot; aux.RootCustomizationSlotVM=nil

-- Default integration on the real zone: temporary editor selection -> preview
-- engine -> palette donor -> RGB -> preview restore -> Default. No auxiliary roots.
do
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
    local saved_palette=palette
    palette={default_vm,stock_vm,blue_vm}
    local regular,adapted
    local function boot()
        regular=module.new(runtime,probe.access,"recovery")
        adapted=zone_module.new(runtime,probe.access,journal,{preview=regular})
    end
    slot.EquipCustomizationPart=function(_,vm)
        assert(files.selection:match("^selection%-v2\n"))
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
    -- A slot change ends the draft through the preview's scheduled context restore;
    -- leaving the item page ends it immediately. Both return the slot to Default.
    begin(); adapted.context_changed("UpdateRootCustomizationSlotVM"); run("tint:context-restore"); finished()
    begin(); adapted.context_changed("page closed"); assert(not jobs["tint:context-restore"]); finished()
    begin(); boot(); adapted.start(); run("tint:recovery"); finished(); run("selection:recovery")
    -- Actual regular blue-activation failure still undoes the temporary equip.
    mode="before"; assert(not adapted.begin_live()); mode=nil; finished()
    -- Editor Apply integration uses the REAL tint/handoff/default stack too.
    -- Simulate native refresh copying the source into the display/data actors.
    do
        local retained={color=original,set=source.SetColor,name=source.GetFullName,
            refresh=owner.RefreshCustomization,
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
            assert(files.editor and files.editor:match("^editor%-v%d\n"))
            original={R=c.R,G=c.G,B=c.B,A=c.A}
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
        boot()
        local session=adapted
        messages={}; local draft=assert(session.begin_live(),table.concat(messages,"\n"))
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
        owner.RefreshCustomization=retained.refresh
        os.rename,os.remove,StaticFindObject=retained.rename,retained.remove,retained.lookup
        FindAllOf,page.GetFullName=retained.find,retained.page_name
        original=retained.color
    end
    slot.GetFragments=saved.slot_fragments; source_slot.GetFragmentInstances=saved.source_fragments
    source_slot.GetFullName=saved.source_name; display_slot.GetFragmentInstances=saved.display_fragments
    FindAllOf=saved.find; part.AssetId=saved.asset; slot.EquippedCustomizationPartViewModel=saved.equipped
    palette=saved_palette
    slot.EquipCustomizationPart=nil; proxy_part=red_id; proxy_fragment=new_clone(); display_color=original
end

io.open = original_open
print("Tint test: regular swatches, Default selection, donor isolation, failure rollback, indefinite drafts, diagnostic timeout and cold recovery passed")
