-- Captured race-specific tint bundles. Plain descriptions are journal-safe;
-- UObject wrappers never leave a call. Companions are cloned, never rewritten.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local rules=assert(loadfile(directory .. "color_rules.lua"))()
local PREFIX="Class /Script/BitReactorCore.CustomizationFragmentInstance"
local KEYS={"R","G","B","A"}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local BLUSH="br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Blush.Color"
local SCAR_MESHES="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh,br.Customization.Slot.Character.Horns.Mesh"
local MARKINGS={
    ["br.Customization.Slot.Character.Lekku.Markings.Color"]=true,
    ["br.Customization.Slot.Character.Appearance.Humanoid.Head.Markings.Color"]=true,
}
function M.parameter(slot)
    local iris=rules.iris(slot)
    if iris then return iris.parameter end
    if slot==BLUSH then return "Cheek / Blush Color" end
    if slot==rules.SCAR then return rules.SCAR_PARAMETER end
    if MARKINGS[slot] then return "Tattoo Color" end
    if slot==SKIN or slot=="br.Customization.Slot.Character.Horns.Color" then return "Skin Coloration" end
end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function encode(c) return string.format("%.17g,%.17g,%.17g,%.17g",c.R,c.G,c.B,c.A) end
local function decode(s,parameter)
    local r,g,b,a=s:match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
    local c={R=tonumber(r),G=tonumber(g),B=tonumber(b),A=tonumber(a)}
    local slot=parameter==rules.SCAR_PARAMETER and rules.SCAR or nil
    if not rules.color(c,slot,parameter) or c.A~=1 or encode(c)~=s then return nil end
    return c
end
function M.parse(s)
    if type(s)~="string" or #s>8192 then return nil end
    local primary,signature,snapshot=s:match("^b1@(%d+)@([^@\r\n]+)@([^@\r\n]+)$")
    primary=tonumber(primary)
    if not primary or primary<1 or primary>16 or not signature:match("^[%w_%. ,;/+=%%%-]+$") then return nil end
    local originals,entries,expected={},{},{}
    local count,editable=0,nil
    for row in signature:gmatch("[^;]+") do
        count=count+1
        local parameter=row:match("^MaterialColor/([^/]+)/")
        if parameter then parameter=parameter:gsub("%%2F","/") end
        if parameter=="Skin Coloration" or parameter=="Tattoo Color" or parameter=="Cheek / Blush Color"
            or parameter==rules.SCAR_PARAMETER or parameter=="MM Iris Color Outer" or parameter=="MM Iris Color Inner" then
            if editable and editable~=parameter then return nil end
            editable=parameter; expected[count]=true
        end
    end
    if count<1 or count>16 then return nil end
    for entry in snapshot:gmatch("[^;]+") do
        local index,rgba=entry:match("^(%d+)=(.+)$"); index=tonumber(index)
        local c=rgba and decode(rgba,editable)
        if not index or not expected[index] or originals[index] or not c then return nil end
        originals[index]=c; entries[#entries+1]=index .. "=" .. encode(c)
    end
    for index in pairs(expected) do if not originals[index] then return nil end end
    if not originals[primary] or #entries>16 or table.concat(entries,";")~=snapshot then return nil end
    return {primary=primary,signature=signature,originals=originals,parameter=editable}
end
function M.same(p,q)
    local x,y=M.parse(p),M.parse(q)
    return x and y and x.primary==y.primary and x.signature==y.signature or false
end
-- The captured Zabrak bundle enables only the Outfit parent, leaving its
-- face MID untinted. This predicate grants transient display ownership only;
-- it does not authorize changing source companions or saved targeting.
function M.zabrak_face_enable(p)
    if type(p)~="table" or p.slot~=SKIN then return false end
    local d=M.parse(p.bundle)
    if not d or d.primary~=2 or d.parameter~="Skin Coloration" then return false end
    local rows={}; for row in d.signature:gmatch("[^;]+") do rows[#rows+1]=row end
    local meshes={"br.Customization.Slot.Character.Outfit.Arms.Mesh",
        "br.Customization.Slot.Character.Outfit.Legs.Mesh",
        "br.Customization.Slot.Character.Outfit.Boots.Mesh",
        "br.Customization.Slot.Character.Outfit.Torso.Mesh",
        "br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh",
        "br.Customization.Slot.Character.Horns.Mesh"}
    return #rows==4
        and rows[1]:match("^GameplayTags/br%.Customization%.Part%.Character%.Race%.[%w_]+$")~=nil
        and rows[2]=="MaterialColor/Skin Coloration/" .. table.concat(meshes,",") .. "/MI_Head,MI_Body"
        and rows[3]=="MaterialScalar/Enable Tinting/br.Customization.Slot.Character.Outfit/MI_Head,MI_Body/1"
        and rows[4]=="MaterialSwap"
end
function M.new(a)
    local self={}
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Tint bundle object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function color(f,normalized,profile)
        local native=object(f):GetColor(); local c={}
        for _,k in ipairs(KEYS) do
            c[k]=a.prop(native,k)
            assert(finite(c[k]),"Invalid bundle color")
        end
        assert(not normalized or c.A==1 and rules.color(c,profile and profile.slot,
            profile and M.parameter(profile.slot)),"Invalid tint bundle color/alpha")
        return c
    end
    local function same(x,y)
        for _,k in ipairs(KEYS) do if math.abs(x[k]-y[k])>.00001 then return false end end
        return true
    end
    local function target(f,scalar)
        local t=f.MaterialTarget
        local parameter=a.text(t.MaterialParameterName)
        assert(rules.parameter(parameter),"Invalid bundle parameter")
        local tags,materials=a.values(t.SlotNameTagsToApply.GameplayTags),a.values(t.MaterialSlotNames)
        assert(#tags>=1 and #tags<=16 and #materials<=16,"Tint bundle target limit")
        local meshes,names,seen={},{},{}
        for _,tag in ipairs(tags) do
            local s=a.text(tag.TagName)
            assert(s:match("^br%.Customization%.Slot%.Character%.[%w_.]+%.Mesh$")
                or scalar and s=="br.Customization.Slot.Character.Outfit","Invalid bundle mesh tag")
            assert(not seen[s],"Duplicate bundle mesh tag"); seen[s]=true; meshes[#meshes+1]=s
        end
        for _,v in ipairs(materials) do
            local s=a.text(v)
            assert(s=="" or s:match("^[%w_]+$"),"Invalid bundle material slot")
            names[#names+1]=s=="" and "-" or s
        end
        assert(scalar or #names>0,"Tint color has no material slots")
        return parameter,table.concat(meshes,","),table.concat(names,",")
    end
    function self.read(array,profile,stock)
        local values=a.values(array)
        local editable=assert(M.parameter(profile and profile.slot),"Unsupported tint bundle slot")
        local markings=editable=="Tattoo Color"
        local blush=profile.slot==BLUSH
        local scar=profile.slot==rules.SCAR
        local iris=rules.iris(profile.slot)
        assert(#values>=1 and #values<=16,"Tint bundle fragment limit")
        assert(not markings or #values==2,"Marking tint requires its observed color/scalar pair")
        assert(not blush or #values==2,"Blush requires its color/blend-mode pair")
        assert(not scar or #values==2 or #values==3,"Scar RGB tint requires its tint/strength pair or swatch/tint/strength bundle")
        local scar_swatch=scar and #values==3
        assert(not iris or #values==2,"Iris tint requires its captured color/amount pair")
        local rows,snapshots,selected,seen={},{},{},{}
        local owner,slot,primary,mesh_targets,material_targets,iris_meshes,swatch_meshes
        for i,v in ipairs(values) do
            local f=object(v); local full=name(f)
            assert(not seen[full],"Tint bundle fragment alias"); seen[full]=true
            local current_owner,current_slot=name(f:GetOwningCustomizationInstance()),name(f:GetOwningCustomizationSlot())
            owner,slot=owner or current_owner,slot or current_slot
            assert(owner==current_owner and slot==current_slot,"Tint bundle companion ownership mismatch")
            local class=name(f:GetClass())
            local suffix=class:sub(#PREFIX+1)
            assert(class==PREFIX .. suffix,"Invalid tint bundle class")
            if markings or blush or scar or iris then
                assert(suffix==((i==1 or scar_swatch and i==2) and "MaterialColor" or "MaterialScalar"),"Tint pair fragment order/class changed")
            end
            local row=suffix
            if suffix=="MaterialColor" or suffix=="MaterialScalar" then
                local parameter,meshes,materials=target(f,suffix=="MaterialScalar")
                if iris then
                    assert(meshes=="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
                        and materials==iris.materials,"Iris material target differs from its captured eye side")
                end
                if scar_swatch then
                    assert(meshes==SCAR_MESHES,"Scar material target differs from its captured face/horns group")
                    assert(i==1 and parameter=="COS Swatch" and materials=="COS_SwatchOnly"
                        or i==2 and parameter==editable and materials=="MI_Head"
                        or i==3 and parameter=="MM Scar Tint Strength" and materials=="MI_Head",
                        "Scar swatch/tint/strength target changed")
                end
                row=row .. "/" .. parameter:gsub("/","%%2F") .. "/" .. meshes .. "/" .. materials
                if suffix=="MaterialColor" then
                    if parameter==editable then
                        assert(not mesh_targets or mesh_targets==meshes,"Tint color mesh groups differ")
                        mesh_targets,material_targets=meshes,materials; selected[#selected+1]=i
                        snapshots[#snapshots+1]=i .. "=" .. encode(color(f,true,profile))
                        primary=primary or i
                        if ("," .. materials .. ","):find(",MI_Head,",1,true) then primary=i end
                    else
                        assert(scar_swatch and i==1 and parameter=="COS Swatch"
                            or not markings and not blush and not scar and not iris and parameter=="Scar HSV Shift",
                            "Unsupported tint bundle color parameter")
                        local companion=color(f,false)
                        if scar_swatch then
                            assert(rules.normalized(companion) and companion.A==1,"Invalid scar display swatch")
                            swatch_meshes=meshes
                        end
                        row=row .. "/" .. encode(companion)
                    end
                else
                    local value=f.Value
                    assert(finite(value) and (blush and parameter=="MM Blush Blend Mode"
                        or scar and parameter=="MM Scar Tint Strength" and value>=0 and value<=1
                        or iris and parameter==iris.amount and value>=0 and value<=1
                        or not blush and not scar and not iris and parameter=="Enable Tinting" and value==1
                        or not markings and not blush and not scar and not iris and parameter=="Hue Shift"
                        or profile.slot==SKIN and parameter=="IrisUVRadius" and materials=="MI_EyeRight"),"Unsupported tint bundle scalar")
                    if markings then
                        assert(parameter=="Enable Tinting" and meshes==mesh_targets and materials==material_targets,
                            "Marking enable target differs from its color target")
                    end
                    if blush then
                        assert(parameter=="MM Blush Blend Mode" and meshes==mesh_targets and materials==material_targets,
                            "Blush blend-mode target differs from its color target")
                    end
                    if scar then
                        assert(parameter=="MM Scar Tint Strength" and meshes==mesh_targets and materials==material_targets,
                            "Scar tint-strength target differs from its color target")
                    end
                    if iris then
                        assert(parameter==iris.amount and meshes==mesh_targets and materials==material_targets,
                            "Iris amount target differs from its color target")
                    end
                    if parameter=="IrisUVRadius" then
                        assert(not iris_meshes,"Duplicate iris companion"); iris_meshes=meshes
                    end
                    row=row .. "/" .. string.format("%.17g",value)
                end
            elseif suffix=="GameplayTags" then
                local tags=a.values(f.GameplayTags.GameplayTags)
                assert(#tags==1,"Unsupported race tag bundle")
                local race=a.text(tags[1].TagName)
                assert(race:match("^br%.Customization%.Part%.Character%.Race%.[%w_]+$"),"Invalid bundle race tag")
                row=row .. "/" .. race
            else
                assert(suffix=="MaterialSwap","Unsupported tint bundle companion")
                -- Native CloneFragments copies both the hard and soft material
                -- references. No Lua setters touch either reference.
            end
            rows[#rows+1]=row
        end
        assert(primary,"Tint bundle has no editable color fragment")
        assert(not scar_swatch or primary==2 and swatch_meshes==mesh_targets,"Scar display swatch differs from its tint target")
        assert(not iris_meshes or iris_meshes==mesh_targets,"Iris companion mesh group differs from skin")
        local description="b1@" .. primary .. "@" .. table.concat(rows,";") .. "@" .. table.concat(snapshots,";")
        assert(M.parse(description),"Invalid tint bundle description")
        if profile and profile.bundle and not stock then
            assert(M.same(description,profile.bundle),"Recorded tint bundle layout changed")
        end
        return object(values[primary]),values,description,selected
    end
    function self.write(array,p,c,restore,reacquire)
        local _,values,_,selected=self.read(array,p)
        local recorded=assert(M.parse(p.bundle),"Invalid tint bundle restore record")
        local identities={}
        for i,f in ipairs(values) do identities[i]=name(f) end
        local function checked()
            if reacquire then values=a.values(reacquire()) end
            self.read(values,p)
            assert(#values==#identities,"Tint bundle changed during setter")
            for i,f in ipairs(values) do assert(name(f)==identities[i],"Tint companion replaced during setter") end
        end
        for _,i in ipairs(selected) do
            checked()
            local value=restore and i~=recorded.primary and assert(recorded.originals[i]) or c
            object(values[i]):SetColor(value)
            checked()
            assert(same(color(values[i],true,p),value),"Tint bundle SetColor readback failed")
        end
    end
    -- Consume the scalar snapshot produced by a fresh read in this pass only.
    -- This compares values, not liveness: callers must not use an old journal
    -- description as a substitute for reading the current native bundle.
    function self.matches_description(description,p,c,restore)
        local current=assert(M.parse(description),"Invalid fresh tint bundle snapshot")
        local recorded=assert(M.parse(p.bundle))
        assert(current.primary==recorded.primary and current.signature==recorded.signature,
            "Recorded tint bundle layout changed")
        for i,value in pairs(current.originals) do
            local expected=restore and i~=recorded.primary and assert(recorded.originals[i]) or c
            if not same(value,expected) then return false end
        end
        return true
    end
    function self.matches(array,p,c,restore)
        local _,_,description=self.read(array,p)
        return self.matches_description(description,p,c,restore)
    end
    function self.owned(array,p,chosen,previous,original)
        local _,values,_,selected=self.read(array,p); local recorded=assert(M.parse(p.bundle))
        for _,i in ipairs(selected) do
            local c=color(values[i],true,p)
            local baseline=i==recorded.primary and original or recorded.originals[i]
            if not baseline or not (same(c,chosen) or previous and same(c,previous) or same(c,baseline)) then return false end
        end
        return true
    end
    return self
end
return M
