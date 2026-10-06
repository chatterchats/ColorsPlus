-- Read-only ownership proof for an empty Default accent. The auxiliary root
-- is optional in-game; use the selected character's documented slot tree.
local M={}
local MESH="br.Customization.Slot.Character.Outfit.Torso.Mesh"
local ARMOR="CustomizationPartDefinition:CPD_H_Outfit_Clo001_TORS_TintF"
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
function M.new(a)
    local function object(v,label)
        v=a.unwrap(v); assert(a.live(v),"Default ownership: " .. label .. " unavailable"); return v
    end
    local function name(v) return a.name(object(v,"object")) end
    local function asset(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function tree(root,selected)
        local selected_name=name(selected)
        local outer=selected_name:match("^[^ ]+ (.+)%.BitReactorCustomizationSlotViewModel_%d+$")
        assert(selected_name:match(VM),"Default ownership: unsupported selected slot")
        local seen,count,found,mesh={},0,false,nil
        local function visit(v,depth)
            v=object(v,"tree slot"); local full=name(v)
            assert(full:match(VM) and full:match("^[^ ]+ (.+)%.BitReactorCustomizationSlotViewModel_%d+$")==outer,
                "Default ownership: slot tree identity mismatch")
            count=count+1
            assert(count<=256 and depth<=32 and not seen[full],"Default ownership: cyclic/oversized slot tree")
            seen[full]=true; found=found or full==selected_name
            if a.text(v.SlotTag.TagName)==MESH then
                assert(not mesh,"Default ownership: ambiguous torso Style slot"); mesh=v
            end
            for _,child in ipairs(a.values(v.CustomizationChildSlotViewModels)) do visit(child,depth+1) end
        end
        visit(root,0)
        assert(found,"Default ownership: selected accent is outside character slot tree")
        assert(mesh,"Default ownership: torso Style slot missing")
        assert(asset(object(mesh.EquippedCustomizationPartViewModel,"Style part").AssetId)==ARMOR,
            "Default ownership: Style is not Clone 8")
        return mesh
    end
    local function owner(mesh)
        local fragments=a.values(mesh:GetFragments()); local result
        assert(#fragments>0,"Default ownership: Style has no fragments")
        for _,f in ipairs(fragments) do
            f=object(f,"Style fragment")
            local candidate=object(f:GetOwningCustomizationInstance(),"Style fragment owner")
            assert(not result or name(result)==name(candidate),"Default ownership: mixed Style fragment owners")
            local mesh_slot=object(candidate:GetSlotInstance({TagName=FName(MESH)}),"source mesh slot")
            assert(name(f:GetOwningCustomizationSlot())==name(mesh_slot),"Default ownership: Style fragment slot mismatch")
            result=candidate
        end
        return result
    end
    return {
        resolve=function(aux,selected)
            local character=object(aux.CharacterCustomizationVM,"CharacterCustomizationVM")
            -- Despite its plural name this reflected field is one root UObject.
            local root=object(character.CustomizationSlotViewModels,"character slot tree root")
            local mesh=tree(root,selected)
            return owner(mesh),name(mesh),name(root)
        end,
        verify=function(root,selected,expected_mesh,expected_owner)
            local mesh=tree(root,selected)
            assert(name(mesh)==expected_mesh and name(owner(mesh))==expected_owner,
                "Default ownership: Style association changed")
        end,
    }
end
return M
