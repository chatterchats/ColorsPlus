-- Structurally verified skin source correction. No lookup, timers, RGB or stock writes.
local M={}
local PREFIX="Class /Script/BitReactorCore.CustomizationFragmentInstance"
function M.new(a,log)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local bundle=assert(loadfile(directory .. "color_fragments.lua"))()
    local fragments=bundle.new(a,log)
    local self={}
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Skin source target unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    function self.supports(s)
        return s.profile and s.profile.slot==bundle.SKIN
            and bundle.valid_race(s.profile.skin_race) and s.profile.skin_scalar=="outfit"
    end
    function self.valid(s)
        local owner=type(s.owner)=="string" and s.owner:match("^[^ ]+ (.+)$")
        if not owner then return false end
        local prefix="CustomizationFragmentInstanceMaterialScalar " .. owner .. "."
        return type(s.part)=="string" and s.part:match("^CustomizationPartDefinition:[%w_%-]+$") and s.profile and s.profile.slot==bundle.SKIN
            and bundle.valid_race(s.profile.skin_race) and s.profile.skin_scalar==nil
            and type(s.skin_target)=="string"
            and s.skin_target:sub(1,#prefix)==prefix
            and s.skin_target:sub(#prefix+1):match("^[%w_.]+$")~=nil
    end
    function self.read(values,s,repair)
        assert(self.valid(s),"Invalid skin target recovery")
        values=a.values(values); assert(#values==3,"Skin source bundle changed")
        for i,cls in ipairs({"GameplayTags","MaterialColor","MaterialScalar"}) do
            local f=object(values[i])
            assert(name(f:GetClass())==PREFIX .. cls
                and name(f:GetOwningCustomizationInstance())==s.owner
                and name(f:GetOwningCustomizationSlot())==s.slot,"Skin source companion ownership changed")
        end
        if name(values[2])~=s.fragment or name(values[3])~=s.skin_target then return nil end
        local tags=a.values(object(values[1]).GameplayTags.GameplayTags)
        assert(#tags==1 and a.text(tags[1].TagName)==s.profile.skin_race,"Skin source race changed")
        fragments.skin_target(values[2],"Skin Coloration")
        assert(object(values[3]).Value==1,"Skin source scalar changed")
        if not repair then
            assert(fragments.skin_target(values[3],"Enable Tinting",true)=="meshes","Applied skin scalar target changed")
        end
        return object(values[2]),object(values[3])
    end
    function self.write(f,restore)
        if restore then
            log("SKIN SOURCE | RESTORE parameter/materials")
            object(f).MaterialTarget.MaterialParameterName="Enable Tinting"
            assert(a.text(object(f).MaterialTarget.MaterialParameterName)=="Enable Tinting","Skin parameter restore failed")
            object(f).MaterialTarget.MaterialSlotNames={"MI_Head","MI_Body","MI_Neck"}
        end
        local tags={}
        for _,tag in ipairs(restore and {"br.Customization.Slot.Character.Outfit"} or bundle.MESHES) do
            local v=FName(tag); assert(a.text(v)==tag,"Skin target FName mismatch")
            tags[#tags+1]={TagName=v}
        end
        log("SKIN SOURCE | WRITE BEGIN | " .. (restore and "outfit" or "meshes"))
        object(f).MaterialTarget.SlotNameTagsToApply.GameplayTags=tags
        assert(fragments.skin_target(f,"Enable Tinting",true)==(restore and "outfit" or "meshes"),"Skin target readback failed")
        log("SKIN SOURCE | WRITE RETURN")
    end
    return self
end
return M
