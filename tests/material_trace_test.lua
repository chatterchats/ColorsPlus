-- luajit tests/material_trace_test.lua src/Colors+Probe/Scripts
local scripts = assert(arg[1])
local messages, jobs, game_thread, reads, mutations = {}, {}, true, 0, 0
local runtime = {log=function(s) messages[#messages + 1] = s end}
function runtime:after(key, delay, cb) jobs[key] = {delay=delay, cb=cb} end
function runtime:cancel(key) jobs[key] = nil end
local function run(key)
    local job = assert(jobs[key], key); jobs[key] = nil; game_thread = true; job.cb()
end
local function has(s)
    for _, line in ipairs(messages) do if line:find(s, 1, true) then return true end end
    return false
end
local function obj(name, fields)
    fields = fields or {}
    fields.type = function() return "UObject" end
    fields.IsValid = function(self) assert(game_thread); return not self.invalid end
    fields.GetFullName = function(self) assert(not self.invalid); return name end
    fields.get = function() error("arbitrary UObject unwrapped") end
    for _, method in ipairs({"SetColor", "SetMaterial", "CreateDynamicMaterialInstance",
        "SetVectorParameterValue", "RefreshCustomization", "CloneFrom", "Refresh"}) do
        fields[method] = function() mutations = mutations + 1; error("trace attempted mutation: " .. method) end
    end
    return fields
end
local function wrap(v) return {type=function() return "RemoteUnrealParam" end, get=function() return v end} end
local function array(v) local out = {}; for i,x in ipairs(v) do out[i] = wrap(x) end; return out end
local world = "/Game/Game/Maps/MainMenu/MainMenu.MainMenu:PersistentLevel."
local display_world = "/Game/Game/Maps/StoryMissions/MM_01_010_TheSerolonisJob/MM_01_010_TheSerolonisJob_HawksCustomization.MM_01_010_TheSerolonisJob_HawksCustomization:PersistentLevel."
local red, blue, cyan = {R=.25,G=.0075,B=.0075,A=1}, {R=0,G=0,B=.25,A=1}, {R=0,G=1,B=1,A=1}
local source_color, data_color, display_color = red, cyan, red
local skin_mode=false
local scalar_class=obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialScalar")
local enable_fragment=obj("CustomizationFragmentInstanceMaterialScalar /Game/Test.Enable",{
    GetClass=function() return scalar_class end,Value=1,
    MaterialTarget={SlotNameTagsToApply={GameplayTags={{TagName="br.Customization.Slot.Character.Outfit"}}}}})
local color_class = obj("Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor")
local mesh_class = obj("Class /Script/Engine.MeshComponent")
local mid_class = obj("Class /Script/Engine.MaterialInstanceDynamic")
local constant_class = obj("Class /Script/Engine.MaterialInstanceConstant")
local material_class = obj("Class /Script/Engine.Material")
local source_actor, data_actor, display_actor
local function fragment(name, getter, actor_getter)
    return obj("CustomizationFragmentInstanceMaterialColor " .. world .. name, {
        GetClass=function() return color_class end, GetColor=getter,
        GetOwningActor=actor_getter,
    })
end
local source_fragment = fragment("Source.Color", function() return source_color end, function() return source_actor end)
local data_fragment = fragment("Data.Color", function() return data_color end, function() return data_actor end)
local display_fragment = fragment("Display.Color", function() return display_color end, function() return display_actor end)
local function instance(name, f, actor_getter)
    return obj("CustomizationInstance " .. world .. name, {
        GetOwner=actor_getter, IsRefreshingDisabled=function() return false end,
        GetSlotInstance=function() return obj("CustomizationFragmentInstanceSlot " .. world .. name .. ".Slot",
            {GetFragmentInstances=function() return array(skin_mode and {{},f,enable_fragment} or {f}) end}) end,
    })
end
local source_instance = instance("Source.Instance", source_fragment, function() return source_actor end)
local data_instance = instance("Data.Instance", data_fragment, function() return data_actor end)
local display_instance = instance("Display.Instance", display_fragment, function() return display_actor end)
source_instance.GetPreviewCustomizationInstance = function() return wrap(data_instance) end
local base_material = obj("Material /Game/Test.Base", {GetClass=function() return material_class end})
local parent_material = obj("MaterialInstanceConstant /Game/Test.Parent", {
    GetClass=function() return constant_class end, Parent=base_material,
    VectorParameterValues=array({{ParameterInfo={Name="Color 02", Association=1, Index=2}, ParameterValue=red}}),
})
local fail_getter, oversized_components = false, false
local function material(name, getter)
    return obj("MaterialInstanceDynamic " .. world .. name, {
        GetClass=function() return mid_class end, Parent=parent_material, VectorParameterValues={},
        K2_GetVectorParameterValue=function(_, parameter)
            assert(game_thread); reads = reads + 1
            if fail_getter then error("getter unavailable") end
            assert(parameter:ToString() == "Color 01" or parameter:ToString() == "Color 02" or parameter:ToString()=="Skin Coloration")
            return getter()
        end,
    })
end
local source_material = material("Source.MID", function() return source_color end)
local data_material = material("Data.MID", function() return data_color end)
local display_material = material("Display.MID", function() return display_color end)
local function actor(name, instance_value, mat, hidden, level)
    level = level or world
    local actor_value = obj("TestActor " .. level .. name, {
        bHidden=hidden, CustomizationInstance=instance_value,
        WasRecentlyRendered=function() return not hidden end,
    })
    local mesh = obj("SkeletalMeshComponent " .. level .. name .. ".Mesh", {
        GetOwner=function() return actor_value end,
        GetSkinnedAsset=function() return obj("SkeletalMesh /Game/Armor.Clone8") end,
        IsVisible=function() return not hidden end, WasRecentlyRendered=function() return not hidden end,
        bHiddenInGame=hidden, bRenderInMainPass=true, bOwnerNoSee=false, bOnlyOwnerSee=false,
        bVisibleInSceneCaptureOnly=false, bHiddenInSceneCapture=false,
        GetNumMaterials=function() return 2 end,
        -- Deliberately reverse labels: must use GetMaterialIndex, not Lua array position.
        GetMaterialSlotNames=function() return array({"MI_ARMS", "MI_TORS"}) end,
        GetMaterialIndex=function(_, slot) return slot == "MI_TORS" and 0 or 1 end,
        GetMaterial=function(_, index) assert(index == 0 or index == 1); return wrap(mat) end,
    })
    actor_value.K2_GetComponentsByClass = function(_, class)
        assert(game_thread and class == mesh_class)
        local out = {mesh}
        if oversized_components then for i=2,25 do out[i] = mesh end end
        return array(out)
    end
    return actor_value, mesh
end
local source_mesh, data_mesh, display_mesh
source_actor, source_mesh = actor("Source", source_instance, source_material, true)
data_actor, data_mesh = actor("Data", data_instance, data_material, true)
display_actor, display_mesh = actor("Display", display_instance, display_material, false, display_world)
display_actor.ClonedFromCharacter = data_actor
display_actor.ListenToRefreshEvent = true; display_actor.DelayCustomizationRefresh = false
display_actor.DelayEnabled = false; display_actor["In Main Menu Character Customization"] = true
local container = obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "Container", {
    ProxyDataStorage=data_actor, ProxyCharacter=display_actor, IsPreviewing=true,
    DelayProxyRefreshing=false, PreviousDelayProxyRefreshing=false,
})
local unrelated = obj("BP_CustomizationPreviewProxyContainer_C " .. world .. "OtherContainer", {
    ProxyDataStorage=source_actor, ProxyCharacter=obj("TestActor " .. world .. "Unrelated", {
        K2_GetComponentsByClass=function() error("unrelated actor inspected") end}),
})
function FindAllOf(class)
    assert(game_thread and class == "BP_CustomizationPreviewProxyContainer_C")
    return {unrelated, container}
end
function StaticFindObject(path) assert(game_thread and path == "/Script/Engine.MeshComponent"); return mesh_class end
FName = newproxy(true)
getmetatable(FName).__call = function(_, value)
    assert(game_thread); return {ToString=function() return value end}
end
getmetatable(FName).__metatable = false
local access = assert(loadfile(scripts .. "/customization_probe.lua"))().new(runtime).access
local fail_context = false
local skin_part=obj("BitReactorCustomizationPartViewModel /Game/Test.Skin5",{
    AssetId={PrimaryAssetType={Name="CustomizationPartDefinition"},PrimaryAssetName="CPD_H_SkinTone_Human_0B1"}})
local trace = assert(loadfile(scripts .. "/material_trace.lua"))().new(runtime, access, function()
    assert(game_thread); if fail_context then error("wrong customization context") end
    return {owner=source_instance, fragment=source_fragment, slot={SlotTag={TagName="accent"}},part=skin_part,
        profile=skin_mode and {slot="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone",skin_scalar="outfit"} or nil}
end)
trace.capture("inactive"); trace.event("inactive"); assert(reads == 0 and next(jobs) == nil)
trace.arm()
assert(jobs["materials:expiry"].delay == 60000 and has("matched_containers=1"))
assert(has("container[2].display-candidate=TestActor " .. display_world .. "Display"))
assert(has("display_link=matched-container.ProxyCharacter | outside_main_menu=true"))
assert(has("container[2].display-candidate.accent_fragment_rgba="))
assert(has("container[2].display-candidate.mesh[1].object=SkeletalMeshComponent " .. display_world .. "Display.Mesh"))
assert(not has("Unrelated") and not has("unrelated actor inspected"))
assert(has("preview-data.accent_fragment_rgba=") and has("rgba=0.000000,1.000000,1.000000,1.000000"))
assert(has("material[1].Color 02.getter_rgba=0.250000,0.007500,0.007500,1.000000"))
assert(has("name=Color 02 | association=1 | index=2"))
assert(has(".material[0].slot=MI_TORS") and has(".material[1].slot=MI_ARMS"))
assert(reads == 6, "shared material assignments should be detailed once per capture")
assert(has("getter_parameter_presence=unverified") and has("visibility is a hint"))
assert(not has("attempted mutation") and not has("CAPTURE REFUSED/FAILED"))
source_color, data_color, display_color = blue, blue, blue
local before = reads; game_thread = false
trace.event("stock blue"); assert(reads == before)
assert(jobs["materials:event"].delay == 150 and jobs["materials:settled"].delay == 750)
run("materials:event"); assert(has("stock blue +150ms") and has("0.000000,0.000000,0.250000,1.000000"))
run("materials:settled"); assert(has("stock blue +750ms"))
messages = {}; fail_getter = true; trace.capture("getter gaps"); fail_getter = false
assert(has("getter unavailable") and has("END | actors=3"))
parent_material.Parent = parent_material; trace.capture("cycle")
assert(has("parent_cycle=true")); parent_material.Parent = base_material
display_mesh.invalid = true; trace.capture("invalid component"); display_mesh.invalid = nil
assert(has("Required live object unavailable"))
oversized_components = true; trace.capture("bounded components"); oversized_components = false
assert(has("meshes.truncated=true"))
fail_context = true; trace.capture("bad context"); fail_context = false
assert(has("CAPTURE REFUSED/FAILED") and has("wrong customization context"))
trace.event("old window"); local stale = jobs["materials:event"].cb
trace.stop("test stop"); before = reads; stale(); assert(reads == before and next(jobs) == nil)
trace.arm(); local serial = trace.serial; stale(); assert(trace.serial == serial)
run("materials:expiry"); assert(not trace.window and has("60-second timeout"))
-- Cross-level access is limited to the fresh matched-container reference.
trace.arm()
messages = {}; container.ProxyDataStorage = source_actor
trace.capture("unmatched container")
assert(has("matched_containers=0") and has("END | actors=2") and not has("display_link="))
container.ProxyDataStorage = data_actor
messages = {}; display_actor.invalid = true
trace.capture("invalid linked actor"); display_actor.invalid = nil
assert(has("unavailable linked actor") and has("END | actors=2"))
messages = {}; container.ProxyCharacter = source_actor
trace.capture("replacement linked actor")
assert(has("display-candidate=TestActor " .. world .. "Source"))
assert(not has(display_world .. "Display") and has("END | actors=2"))
container.ProxyCharacter = display_actor
messages = {}; display_actor.CustomizationInstance = source_instance
trace.capture("wrong instance owner"); display_actor.CustomizationInstance = display_instance
assert(has("Display instance owner mismatch") and not has("display-candidate.accent_fragment_rgba="))
assert(has("display-candidate.mesh[1].object="), "owned meshes remain readable despite missing instance")
-- A foreign container is not eligible even if it references our data actor.
local container_name = container.GetFullName
container.GetFullName = function() return "BP_CustomizationPreviewProxyContainer_C " .. display_world .. "ForeignContainer" end
messages = {}; trace.capture("foreign container")
assert(has("matched_containers=0") and not has("display_link="))
container.GetFullName = container_name
-- The source/data scope is not widened by the display exception.
local data_name = data_actor.GetFullName
data_actor.GetFullName = function() return "TestActor " .. display_world .. "ForeignData" end
messages = {}; trace.capture("foreign data")
assert(has("preview-data=<unavailable/outside main menu>") and not has("display_link="))
data_actor.GetFullName = data_name
trace.stop("scope tests")
trace.arm()
for _=1,21 do trace.capture("budget") end
assert(not trace.window and has("20-capture limit"))
-- Fragment RGB can match while the rendered material's tint switch is off.
skin_mode=true
for _,mesh in ipairs({source_mesh,data_mesh,display_mesh}) do
    mesh.GetMaterialSlotNames=function() return array({"MI_Head","MI_ARMS"}) end
    mesh.GetMaterialIndex=function(_,slot) return slot=="MI_Head" and 0 or 1 end
end
for _,mat in ipairs({source_material,data_material,display_material}) do
    mat.K2_GetScalarParameterValue=function(_,n)
        assert(game_thread and n:ToString()=="Enable Tinting"); return mat==display_material and 0 or 1
    end
    mat.ScalarParameterValues={}
end
parent_material.VectorParameterValues=array({{ParameterInfo={Name="Skin Coloration",Association=1,Index=2},ParameterValue=blue}})
parent_material.ScalarParameterValues=array({{ParameterInfo={Name="Enable Tinting",Association=1,Index=2},ParameterValue=0}})
messages={}; trace.arm()
assert(has("skin.source_layout=outfit") and has("skin.source_asset=CustomizationPartDefinition:CPD_H_SkinTone_Human_0B1"))
assert(has("skin.fragment_enable_tinting=1") and has("skin.scalar_target[1]=br.Customization.Slot.Character.Outfit"))
assert(has("material[1].Skin Coloration.getter_rgba=") and has("material[1].Enable Tinting.getter_scalar=0"))
assert(has("name=Enable Tinting | association=1 | index=2 | value=0"))
assert(has("name=Skin Coloration | association=1 | index=2 | rgba="))
assert(not has("Expected one accent fragment") and not has("CAPTURE REFUSED/FAILED"))
display_material.K2_GetScalarParameterValue=function() error("scalar getter gap") end
messages={}; trace.capture("missing scalar getter"); assert(has("scalar getter gap") and has("END | actors=3"))
for i=1,66 do parent_material.ScalarParameterValues[i]=wrap({ParameterInfo={Name="Enable Tinting",Association=0,Index=0},ParameterValue=1}) end
messages={}; trace.capture("scalar budget"); assert(has("Unreadable or oversized array") and not has("scalar_override[65]"))
-- Console path works without Dev Panel and never reads UObjects on dispatch.
RegisterConsoleCommandHandler=function() end
local command,save_command
function runtime:console(name,fn)
    if name=="colors_save" then save_command=fn
    else assert(name=="colors_materials"); command=fn end
end
trace.attach(); trace.stop("before commands")
game_thread=false; command(nil,{"start"}); before=reads
assert(jobs["materials:command"] and not trace.window and reads==before)
run("materials:command"); assert(trace.window)
game_thread=false; command(nil,{"sample"}); before=reads; assert(reads==before)
run("materials:command"); assert(trace.window.captures==2)
command(nil,{"bad"}); assert(not jobs["materials:command"])
command(nil,{"sample","extra"}); assert(not jobs["materials:command"])
command(nil,{"sample"})
-- Runtime owns cancellation; the event/expiry callbacks also gate old windows.
trace.stop("navigation"); assert(not jobs["materials:command"])
command(nil,{"stop"}); run("materials:command"); assert(not trace.window)
command(nil,{"sample"}); run("materials:command"); assert(has("No active capture window"))
runtime.tint={}
game_thread=false; before=reads; save_command(nil,{"baseline"})
assert(reads==before and jobs["materials:save-command"])
run("materials:save-command"); assert(has("SAVE SNAPSHOT | stage=baseline | END") and not trace.window)
runtime.tint.pending={}; assert(not trace.save_capture("after")); runtime.tint.pending=nil
assert(not trace.save_capture("before"))
runtime.tint.applied={owner=source_instance:GetFullName(),fragment=source_fragment:GetFullName(),
    original=source_color,chosen=blue,part="CustomizationPartDefinition:CPD_H_SkinTone_Human_0B1"}
assert(trace.save_capture("before") and has("SAVE SNAPSHOT | stage=before | original="))
runtime.tint.applied.fragment="another fragment"; assert(not trace.save_capture("before"))
runtime.tint.applied={}; assert(not trace.save_capture("after")); runtime.tint.applied=nil
runtime.skin_enable={pending={}}; assert(not trace.save_capture("after")); runtime.skin_enable=nil
assert(trace.save_capture("after"))
save_command(nil,{"after"}); trace.stop("page closed"); assert(not jobs["materials:save-command"])
save_command(nil,{"bad"}); assert(not jobs["materials:save-command"])
assert(mutations == 0, "read-only trace attempted a mutation even if its error was caught")
print("Material trace: linked display actor, live/override colors, read-only bounds, gaps, expiry and stale-window tests passed")
