-- Read-only binding for the opt-in eye experiment. Never follows a guessed
-- display actor: only the existing source -> preview container -> display link.
local M={}
local EYES="br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Color"
local FACE="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
local SLOT="Class /Script/BitReactorCore.CustomizationFragmentInstanceSlot"
local SWAP="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialSwap"
local MID="Class /Script/Engine.MaterialInstanceDynamic"
local MIC="Class /Script/Engine.MaterialInstanceConstant"
local BASE="Material /Game/Game/Characters/Materials/M_EyeRefractive.M_EyeRefractive"
local SOURCE="^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"
function M.new(runtime,a)
    local self={}
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local eye_names=assert(loadfile(directory .. "eye_names.lua"))()
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local handoff=assert(loadfile(directory .. "display_handoff.lua"))().new(runtime,a,function() end)
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Eye object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function tag(v) return a.text(v.TagName) end
    local fname=eye_names.new(a,runtime.log)
    local function list(class)
        local values=FindAllOf(class) or {}; local count=0
        for _ in pairs(values) do count=count+1; assert(count<=128,"Eye context scan limit") end
        return values
    end
    local function specs(instance,root,mode)
        root=object(root); assert(tag(root:GetSlotNameTag())==EYES
            and name(root:GetOwningCustomizationInstance())==name(instance),"Wrong eye root slot/owner")
        local out={}
        local children=a.values(root:GetFragmentInstances())
        assert(#children==2,"Expected two nested eye slots")
        local sides={}
        for _,child in ipairs(children) do
            child=object(child)
            local side=tag(child:GetSlotNameTag())
            assert(name(child:GetClass())==SLOT and (side==EYES .. ".Left" or side==EYES .. ".Right")
                and not sides[side] and name(child:GetOwningCustomizationInstance())==name(instance),"Unexpected nested eye slot")
            sides[side]=true
            local fragments=a.values(child:GetFragmentInstances())
            assert(#fragments==1,"Expected one material swap per eye")
            local f=object(fragments[1])
            assert(name(f:GetClass())==SWAP and name(f:GetOwningCustomizationInstance())==name(instance)
                and name(f:GetOwningCustomizationSlot())==name(child),"Eye swap ownership mismatch")
            local t=f.MaterialTarget
            local tags=a.values(t.SlotNameTagsToApply.GameplayTags)
            local materials=a.values(t.MaterialSlotNames)
            assert(#tags==1 and tag(tags[1])==FACE and #materials==1,"Unsupported eye target")
            local material=eye_names.slot(a.text(materials[1]))
            assert(material=="MI_Eyes" or material==(side==EYES .. ".Left" and "MI_EyeLeft" or "MI_EyeRight"),
                "Unexpected eye material slot")
            local replacement=object(f.ReplacementMaterial)
            assert(name(replacement:GetClass())==MIC and name(replacement.Parent)==BASE,"Unverified eye material family")
            local parameters={}
            for _,p in ipairs(a.values(replacement.VectorParameterValues)) do
                local info=p.ParameterInfo; local key=eye_names.parameter(a.text(info.Name))
                if key then
                    assert(a.text(info.Association)=="2" and a.text(info.Index)=="-1","Unsupported eye parameter association")
                    parameters[key]=true
                end
            end
            local scalars={}
            if mode=="texture" then
                for _,p in ipairs(a.values(replacement.ScalarParameterValues)) do
                    local info=p.ParameterInfo; local key=eye_names.scalar(a.text(info.Name))
                    if key then
                        assert(a.text(info.Association)=="2" and a.text(info.Index)=="-1" and not scalars[key],
                            "Unsupported/duplicate eye scalar override")
                        scalars[key]=true
                    end
                end
            end
            local prior=out[material]
            assert(not prior or prior.parent==name(replacement),"Two eyes disagree on shared material")
            out[material]={parent=name(replacement),parameters=parameters,scalars=scalars}
        end
        return out
    end
    function self.resolve(mode)
        local page,vm
        for _,p in pairs(list("WBP_Customization_ItemPage_C")) do
            if a.live(p) and p:IsActivated()==true then assert(not page,"Ambiguous eye page"); page=name(p) end
        end
        assert(page,"Open the Eyes preset page")
        lifetime.bind(page)
        for _,aux in pairs(list("CustomizationAuxVM_C")) do
            if a.live(aux) then
                local v=a.unwrap(a.prop(aux,"CurrentCustomizationSlotVM"))
                if a.live(v) then assert(not vm,"Ambiguous eye selection"); vm=v end
            end
        end
        vm=object(vm); assert(tag(vm.SlotTag)==EYES,"Select Eyes, not another appearance slot")
        local part=object(vm.EquippedCustomizationPartViewModel)
        local asset=id(part.AssetId); assert(asset:match("^CustomizationPartDefinition:CPD_H_Eyes_[%w_]+$"),"Unsupported eye preset")
        local fragments=a.values(vm:GetFragments()); assert(#fragments==2,"Expected nested eye fragments")
        local owner=object(object(fragments[1]):GetOwningCustomizationInstance())
        assert(name(owner):match(SOURCE),"Eye probe requires main-menu customization source")
        local root=object(owner:GetSlotInstance(vm.SlotTag))
        assert(id(root:GetCustomizationPartPrimaryAssetId())==asset,"Source eye preset mismatch")
        local children=a.values(root:GetFragmentInstances())
        assert(#children==#fragments,"Eye VM/root mismatch")
        local member={}; for _,f in ipairs(children) do member[name(f)]=true end
        for _,f in ipairs(fragments) do assert(member[name(f)],"Eye VM points outside selected root") end
        local source_specs=specs(owner,root,mode)
        local preview=object(owner:GetPreviewCustomizationInstance())
        local container,display,instance=handoff.display(owner,preview)
        local display_root=object(instance:GetSlotInstance(vm.SlotTag))
        assert(id(display_root:GetCustomizationPartPrimaryAssetId())==asset,"Displayed eye preset differs")
        local display_specs=specs(instance,display_root,mode)
        local signature={page,name(vm),name(owner),asset,name(container),name(display)}
        local mesh_class=object(StaticFindObject("/Script/Engine.MeshComponent"))
        assert(name(mesh_class)=="Class /Script/Engine.MeshComponent","Mesh class mismatch")
        local components=a.values(display:K2_GetComponentsByClass(mesh_class))
        assert(#components<=32,"Display mesh scan limit")
        local rows,seen={},{}
        local materials={}; for key in pairs(source_specs) do materials[#materials+1]=key end; table.sort(materials)
        for _,material in ipairs(materials) do
            local spec=source_specs[material]; local other=display_specs[material]
            assert(other and other.parent==spec.parent,"Source/display eye material mismatch")
            local found
            for _,component in ipairs(components) do
                component=object(component)
                assert(name(component:GetOwner())==name(display),"Display mesh owner mismatch")
                local index=component:GetMaterialIndex(fname(material))
                if type(index)=="number" and index>=0 then
                    assert(index%1==0 and index<component:GetNumMaterials() and not found,"Ambiguous eye mesh material")
                    local mid=object(component:GetMaterial(index))
                    assert(name(mid:GetClass())==MID and name(mid.Parent)==spec.parent,"Eye material is not an isolated expected MID")
                    assert(name(mid:GetOuter())==name(component),"Eye MID is not owned by this mesh")
                    assert(not seen[name(mid)],"Eye material aliases another eye target"); seen[name(mid)]=true
                    found={component=name(component),mid=name(mid),parent=spec.parent,index=index,slot=material,
                        parameters=spec.parameters,scalars=spec.scalars}
                end
            end
            assert(found,"Eye target material missing from linked display")
            -- An owned MID must not also serve a different material slot.
            local references=0
            for _,component in ipairs(components) do
                local count=object(component):GetNumMaterials(); assert(count>=0 and count<=32 and count%1==0,"Material scan limit")
                for index=0,count-1 do
                    local mat=a.unwrap(component:GetMaterial(index))
                    if a.live(mat) and name(mat)==found.mid then references=references+1 end
                end
            end
            assert(references==1,"Eye MID is shared across display slots")
            rows[#rows+1]=found
            signature[#signature+1]=found.component; signature[#signature+1]=found.mid
            signature[#signature+1]=found.parent; signature[#signature+1]=tostring(found.index)
        end
        assert(#rows>0 and #rows<=2,"Unsupported eye material count")
        return {signature=table.concat(signature,"\n"),container=name(container),display=name(display),rows=rows,asset=asset}
    end
    return self
end
return M
