-- Exact observed human skin bundle. Read-only; callers change only GetColor's
-- fragment and pass the complete cloned array back to the native slot.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local bundles=assert(loadfile(directory .. "color_bundle.lua"))()
local rules=assert(loadfile(directory .. "color_rules.lua"))()
M.SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
M.MESHES={"br.Customization.Slot.Character.Outfit.Arms.Mesh",
    "br.Customization.Slot.Character.Outfit.Legs.Mesh",
    "br.Customization.Slot.Character.Outfit.Boots.Mesh",
    "br.Customization.Slot.Character.Outfit.Torso.Mesh",
    "br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"}
M.MATERIALS={"MI_Head","MI_Body","MI_Neck"}
local OUTFIT_SCALAR_MESHES={"br.Customization.Slot.Character.Outfit"}
local PREFIX="Class /Script/BitReactorCore.CustomizationFragmentInstance"
function M.valid_race(s)
    return type(s)=="string" and s:match("^br%.Customization%.Part%.Character%.Race%.[%w_]+$")~=nil
end
function M.human_family(s)
    return type(s)=="string" and s:match("^(CustomizationPartDefinition:CPD_H_SkinTone_Human_[%w]+)%d$") or nil
end
function M.new(a,diagnostic_log)
    local self={}
    local generic=bundles.new(a)
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Required live object unavailable: color bundle"); return v end
    local function name(v) return a.name(object(v)) end
    function self.skin_target(f,parameter,allow_outfit)
        local t=object(f).MaterialTarget
        local actual=a.text(t.MaterialParameterName)
        local meshes,materials
        local expected_meshes=M.MESHES
        local function refuse(reason)
            -- Only failed validation emits details. Reuse the arrays already
            -- read by the guard; never scan objects or reacquire a stale target.
            -- Diagnostic failures cannot mask the refusal or bypass rollback.
            if diagnostic_log then pcall(function()
                local function clean(s) return tostring(s):gsub("[\r\n\t]"," "):sub(1,256) end
                diagnostic_log("SKIN TARGET | REFUSED | " .. reason .. " | expected_parameter=" .. clean(parameter)
                    .. " | actual_parameter=" .. clean(actual))
                diagnostic_log("SKIN TARGET | COUNTS | meshes=" .. (meshes and #meshes or "not-read")
                    .. " expected=" .. #expected_meshes .. " | materials=" .. (materials and #materials or "not-read") .. " expected=3")
                for _,list in ipairs({{label="MESH",values=meshes,expected=expected_meshes},
                    {label="MATERIAL",values=materials,expected=M.MATERIALS}}) do
                    if list.values then
                        for i=1,math.min(#list.values,16) do
                            local ok,value=pcall(function()
                                if list.label=="MESH" then return a.text(list.values[i].TagName) end
                                return a.text(list.values[i])
                            end)
                            diagnostic_log("SKIN TARGET | " .. list.label .. " | index=" .. i
                                .. " | actual=" .. (ok and clean(value) or "<read-failed>")
                                .. " | expected=" .. (list.expected[i] or "<none>"))
                        end
                        if #list.values>16 then diagnostic_log("SKIN TARGET | " .. list.label .. " | omitted=" .. (#list.values-16)) end
                    end
                end
            end) end
            error(reason,0)
        end
        if actual~=parameter then refuse("Skin material parameter changed") end
        meshes=a.values(t.SlotNameTagsToApply.GameplayTags)
        materials=a.values(t.MaterialSlotNames)
        -- Only the tint-enable scalar has two observed layouts. The actual
        -- color target always retains the exact five meshes.
        if allow_outfit==true and parameter=="Enable Tinting" and #meshes==1 then expected_meshes=OUTFIT_SCALAR_MESHES end
        if #meshes~=#expected_meshes or #materials~=3 then refuse("Unsupported skin target layout") end
        for i,s in ipairs(expected_meshes) do if a.text(meshes[i].TagName)~=s then refuse("Skin mesh target changed") end end
        for i,s in ipairs(M.MATERIALS) do if a.text(materials[i])~=s then refuse("Skin material target changed") end end
        return expected_meshes==OUTFIT_SCALAR_MESHES and "outfit" or "meshes"
    end
    function self.read(array,profile,stock_preview)
        local values=a.values(array)
        if profile and profile.bundle then
            local f,list,description=generic.read(values,profile,stock_preview)
            return f,list,nil,nil,description
        end
        if profile and profile.slot==rules.SCAR and #values==1 then
            local f=object(values[1])
            assert(name(f:GetClass())==PREFIX .. "MaterialColor"
                and a.text(f.MaterialTarget.MaterialParameterName)==rules.SCAR_HSV_PARAMETER
                and (not profile.parameter or profile.parameter==rules.SCAR_HSV_PARAMETER),"Scar HSV fragment layout changed")
            return f,values
        end
        -- Retain the separately verified human source-target recovery path.
        -- Race bundles without that exact shape use a captured description.
        if profile and not profile.skin_race then
            local skin=profile.slot==M.SKIN
            local legacy=skin and #values==3
                and name(object(values[1]):GetClass())==PREFIX .. "GameplayTags"
                and name(object(values[2]):GetClass())==PREFIX .. "MaterialColor"
                and #a.values(object(values[2]).MaterialTarget.SlotNameTagsToApply.GameplayTags)==5
                and #a.values(object(values[2]).MaterialTarget.MaterialSlotNames)==3
            local horns=profile.slot and profile.slot:match("%.Horns%.[%w_.]*Color")
            local markings=bundles.parameter(profile.slot)=="Tattoo Color"
            local blush=bundles.parameter(profile.slot)=="Cheek / Blush Color"
            if skin and not legacy or profile.slot==rules.SCAR or rules.iris(profile.slot) or (horns or markings or blush) and #values>1 then
                local f,list,description=generic.read(values,profile,stock_preview)
                return f,list,nil,nil,description
            end
        end
        if not profile or profile.slot~=M.SKIN then
            assert(#values==1,"Expected exactly one accent fragment")
            local f=object(values[1])
            assert(name(f:GetClass())==PREFIX .. "MaterialColor","Accent fragment is not a material color")
            return f,values
        end
        assert(#values==3,"Skin requires the observed three-fragment bundle")
        local seen,owner,slot={},nil,nil
        for i,suffix in ipairs({"GameplayTags","MaterialColor","MaterialScalar"}) do
            local f=object(values[i]); local full=name(f)
            assert(not seen[full] and name(f:GetClass())==PREFIX .. suffix,"Skin fragment order/class/identity changed")
            seen[full]=true
            local current_owner=name(f:GetOwningCustomizationInstance())
            local current_slot=name(f:GetOwningCustomizationSlot())
            owner,slot=owner or current_owner,slot or current_slot
            assert(owner==current_owner and slot==current_slot,"Skin companion ownership mismatch")
        end
        local tags=a.values(object(values[1]).GameplayTags.GameplayTags)
        assert(#tags==1,"Unsupported skin gameplay-tag bundle")
        local race=a.text(tags[1].TagName)
        assert(M.valid_race(race) and (not profile.skin_race or profile.skin_race==race),"Skin race tag changed")
        self.skin_target(values[2],"Skin Coloration")
        local layout=self.skin_target(values[3],"Enable Tinting",true)
        -- Initial source discovery records the layout. Thereafter every owned
        -- bundle must match it; stock donor/hover data is inspected separately.
        if profile.skin_race and not stock_preview then
            assert(layout==(profile.skin_scalar or "meshes"),"Skin scalar layout changed")
        end
        assert(object(values[3]).Value==1,"Skin Enable Tinting changed")
        return object(values[2]),values,race,layout=="outfit" and "outfit" or nil
    end
    function self.read_matched(array,p,c,restore)
        local f,values,race,scalar,description=self.read(array,p)
        -- Do not repeat bundle traversal/GetColor after read already checked
        -- every companion. No snapshot is retained beyond this synchronous call.
        if p and p.bundle then
            assert(generic.matches_description(description,p,c,restore),"Tracked tint companion colors changed")
        end
        return f,values,race,scalar,description
    end
    function self.write(f,p,c,array,restore)
        if p and p.bundle then
            if array then generic.write(array,p,c,restore)
            else
                local slot=object(f:GetOwningCustomizationSlot())
                local primary=generic.read(slot:GetFragmentInstances(),p)
                assert(name(primary)==name(f),"Tint bundle write source replaced")
                generic.write(slot:GetFragmentInstances(),p,c,restore,function()
                    local owner=object(f:GetOwningCustomizationInstance())
                    local current=object(owner:GetSlotInstance({TagName=FName(p.slot)}))
                    assert(name(current)==name(slot),"Tint bundle slot replaced during setter")
                    return current:GetFragmentInstances()
                end)
            end
        else object(f):SetColor(c) end
    end
    function self.matches(f,p,c,restore)
        if not (p and p.bundle) then return true end
        return generic.matches(object(f:GetOwningCustomizationSlot()):GetFragmentInstances(),p,c,restore)
    end
    function self.identities(array)
        local values=a.values(array); assert(#values>=1 and #values<=16,"Tint identity limit")
        local identities={}
        for _,f in ipairs(values) do
            local full=name(f); assert(not full:find("[|\r\n]"),"Invalid tint identity")
            identities[#identities+1]=full
        end
        return table.concat(identities,"|")
    end
    function self.owned(f,p,chosen,previous,original)
        if not (p and p.bundle) then return true end
        return generic.owned(object(f:GetOwningCustomizationSlot()):GetFragmentInstances(),p,chosen,previous,original)
    end
    function self.distinct(clones,source,previous)
        local seen={}
        for _,array in ipairs({source,previous}) do
            for _,f in ipairs(a.values(array)) do seen[name(f)]=true end
        end
        for _,f in ipairs(a.values(clones)) do
            local full=name(f)
            assert(not seen[full],"Skin clone aliases a source, stock or companion fragment")
            seen[full]=true
        end
    end
    return self
end
return M
