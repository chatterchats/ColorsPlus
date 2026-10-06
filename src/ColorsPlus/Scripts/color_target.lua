-- Scalar target descriptions and active-page palette discovery. No mutations.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local bundle=assert(loadfile(directory .. "color_fragments.lua"))()
local bundles=assert(loadfile(directory .. "color_bundle.lua"))()
local rules=assert(loadfile(directory .. "color_rules.lua"))()
local TATTOO="br.Customization.Slot.Character.Appearance.Humanoid.BodyArt.Tattoo.Color"
local FACE="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
local HORNS="br.Customization.Slot.Character.Horns.Mesh"
-- Every supported, validated picker profile uses the same preview cadence.
-- Classification is for logging, not permission to bypass target validation.
function M.preview_policy(p)
    if not p or type(p.slot)~="string" or not p.slot:match("^br%.Customization%.Slot%.Character%.[%w_.]+$") then return nil end
    if p.slot==bundle.SKIN then return "skin" end
    if p.slot:match("^br%.Customization%.Slot%.Character%.Outfit%.[%w_]+%.Color%.[%w_]+$") then return "armor" end
    return rules.hsv(p) and "hsv" or "color"
end
local function asset(s) return type(s)=="string" and s:match("^CustomizationPartDefinition:[%w_]+$") end
function M.valid(p)
    local basic=type(p)=="table" and type(p.slot)=="string" and p.slot:match("^br%.Customization%.Slot%.Character%.[%w_.]+$")
        and type(p.mesh)=="string" and p.mesh:match("^br%.Customization%.Slot%.Character%.[%w_.]+%.Mesh$")
        and rules.parameter(p.parameter)
        and asset(p.asset)
    if not basic then return false end
    if p.slot==rules.VITILIGO and p.parameter~=rules.VITILIGO_PARAMETER then return false end
    if p.slot==rules.SCAR and not (p.parameter==rules.SCAR_PARAMETER and p.bundle or rules.hsv(p)) then return false end
    local iris=rules.iris(p.slot)
    if iris and (p.parameter~=iris.parameter or not p.bundle or p.mesh~=FACE
        or p.targets~=nil and (type(p.targets)~="table" or #p.targets~=1)) then return false end
    if p.bundle then
        local description=bundles.parse(p.bundle)
        if not description or description.parameter~=p.parameter or bundles.parameter(p.slot)~=p.parameter
            or p.skin_race~=nil or p.skin_scalar~=nil then return false end
    end
    if p.slot==bundle.SKIN and not p.bundle then
        if p.parameter~="Skin Coloration" or not bundle.valid_race(p.skin_race)
            or p.skin_scalar~=nil and p.skin_scalar~="outfit"
            or type(p.targets)~="table" or #p.targets~=5 or p.mesh~=bundle.MESHES[1] then return false end
        for i,mesh in ipairs(bundle.MESHES) do
            local t=p.targets[i]
            if type(t)~="table" or t.mesh~=mesh or not asset(t.asset) then return false end
        end
        return p.asset==p.targets[1].asset
    end
    if p.skin_race~=nil or p.skin_scalar~=nil then return false end
    if p.targets==nil then return true end
    -- Generic multi-mesh color data: record exact targets, including absence.
    local t=p.targets
    if type(t)~="table" or #t<1 or #t>16 then return false end
    local seen={}
    for _,v in ipairs(t) do
        if type(v)~="table" or type(v.mesh)~="string"
            or not v.mesh:match("^br%.Customization%.Slot%.Character%.[%w_.]+%.Mesh$")
            or seen[v.mesh] or not (v.asset=="-" or asset(v.asset)) then return false end
        seen[v.mesh]=true
    end
    return t[1].mesh==p.mesh and t[1].asset==p.asset
end
function M.encode_targets(p)
    assert(M.valid(p) and p.targets,"Invalid multi-mesh profile")
    local result={}
    for _,t in ipairs(p.targets) do result[#result+1]=t.mesh .. "=" .. t.asset end
    return table.concat(result,"|")
end
function M.decode_targets(p,s)
    if type(s)~="string" then return false end
    if #s>4096 then return false end
    local parsed={}
    for entry in s:gmatch("[^|]+") do
        local mesh,value=entry:match("^([^=|]+)=([^=|]+)$")
        if not mesh or #parsed>=16 then return false end
        parsed[#parsed+1]={mesh=mesh,asset=value}
    end
    p.targets=parsed
    return M.valid(p) and M.encode_targets(p)==s
end
function M.same(p,q)
    return M.valid(p) and M.valid(q) and p.slot==q.slot and p.mesh==q.mesh and p.parameter==q.parameter and p.asset==q.asset
        and p.skin_race==q.skin_race and p.skin_scalar==q.skin_scalar
        and (p.bundle==nil and q.bundle==nil or bundles.same(p.bundle,q.bundle))
        and (p.targets==nil and q.targets==nil or p.targets~=nil and q.targets~=nil
            and M.encode_targets(p)==M.encode_targets(q))
end
-- Also retained for reading v0.2.111 recovery records. New openings do not
-- request self-preview; this predicate identifies the captured head-only source.
function M.self_preview(p,part)
    if not M.valid(p) or p.slot~=bundle.SKIN
        or part~="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_0B1" or not p.bundle then return false end
    local parsed=bundles.parse(p.bundle)
    local meshes=table.concat(bundle.MESHES,",") .. "," .. HORNS
    local companions="MaterialScalar/Enable Tinting/" .. meshes .. "/MI_Head/1;MaterialColor/Skin Coloration/" .. meshes .. "/MI_Head"
    local tags=parsed.signature:match("^(GameplayTags/[%w_.]+;)")
    return parsed.primary==3 and tags~=nil and parsed.signature==tags .. companions
end
-- The only observed cross-target donor route. Keep this separate from the
-- source profile: installed clones still require the source's exact targets.
function M.donor_materials(p,part,donor)
    if M.self_preview(p,part) and donor=="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_0B0" then
        return "MI_Head,MI_Body"
    end
end
function M.new(a,logger)
    local self={}
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local palettes=assert(loadfile(directory .. "active_palette.lua"))().new(a,logger)
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Color target object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function outer(s) return s:match("^[^ ]+ (.+)%.BitReactorCustomization%w+ViewModel_%d+$")
        or s:match("^[^ ]+ (.+)%.BitReactorNoneCustomizationPartViewModel_%d+$") end
    local function palette_part(item,host)
        local full=name(item); local cls=name(item:GetClass()); local value=id(item.AssetId)
        local empty=cls=="Class /Script/BitReactorGame.BitReactorNoneCustomizationPartViewModel" and value=="None:None"
        assert(outer(full)==host and (empty or cls=="Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel"),
            "Palette ownership/class mismatch: " .. full .. " | class=" .. cls)
        assert(empty or asset(value),"Invalid palette asset")
        return value,empty
    end
    -- The equipped swatch is normally one of the palette's own items, but a
    -- character can wear one the palette does not offer (hub: Hawks' armor
    -- wears NeutralGrey_10 and Blue_16, asset_matches=0, likely equipped
    -- under a swatch-unlocker mod and kept in the save). The grid is bound
    -- to this slot by the exact page/panel/tiles walk and its slot tag, the
    -- preview borrows another swatch, and Cancel/Restore write the source
    -- RGB, so an unoffered swatch is logged, not refused.
    local function unoffered(grid,count,host,equipped,current)
        local wanted=id(equipped.AssetId); local matches=0
        for i=0,count-1 do
            local value,empty=palette_part(object(grid:GetItemAt(i)),host)
            if not empty and value==wanted then matches=matches+1 end
        end
        if logger then logger("PALETTE | equipped swatch is not a palette item | asset=" .. wanted
            .. " | asset_matches=" .. matches .. " | equipped=" .. current) end
    end
    local last_selection
    function self.selected(vm,page,root)
        vm=object(vm)
        local original=a.text(vm.SlotTag.TagName)
        local grid,shown=palettes.resolve(page,original,true)
        if shown==original then return vm end
        -- The auxiliary VM can remain on Style while its simple panel shows a
        -- color subslot. Search only the explicit category tree, never global
        -- VMs, and require both the old and displayed slots to belong to it.
        local host=assert(outer(name(vm)),"Invalid selected slot VM location")
        local seen,visiting,found,contains_current,total,reused,back_edges={},{},nil,false,0,0,0
        local function walk(v,depth)
            v=object(v); local full=name(v)
            assert(full:match("^BitReactorCustomizationSlotViewModel ") and outer(full)==host,
                "Selected slot tree game-instance/class mismatch")
            -- The category is a graph: native child references can point back
            -- to an ancestor (including the current Style/Face Shape VM).
            -- Validate every reference, but expand each identity only once.
            -- Continue all other branches so cycles cannot hide ambiguity.
            local slot_tag=a.text(v.SlotTag.TagName)
            if seen[full] then
                assert(seen[full]==slot_tag,"Shared slot tag changed during traversal")
                reused=reused+1
                if visiting[full] then back_edges=back_edges+1 end
                return
            end
            assert(depth<=8,"Selected slot tree depth limit")
            seen[full]=slot_tag
            visiting[full]=true; total=total+1; assert(total<=128,"Selected slot tree node limit")
            contains_current=contains_current or full==name(vm)
            if slot_tag==shown then
                assert(not found,"Ambiguous displayed slot VM"); found=v
            end
            local children=a.values(a.prop(v,"CustomizationChildSlotViewModels"))
            assert(#children<=64,"Selected slot child limit")
            for _,child in ipairs(children) do walk(child,depth+1) end
            visiting[full]=nil
        end
        walk(root,0)
        assert(contains_current and found,"Displayed/current slot missing from category tree")
        -- Resolving the current slot needs exact equipped-item membership, not
        -- validation of every unrelated swatch on every preview/health check.
        -- Donor discovery still uses the full, ordered self.palette walk.
        self.equipped_in_palette(found,grid)
        local checked_grid=name(grid)
        local final_grid,final_tag=palettes.resolve(page,original,true)
        assert(checked_grid==name(grid) and name(final_grid)==checked_grid and final_tag==shown
            and a.text(found.SlotTag.TagName)==shown,"Displayed palette changed during slot resolution")
        local identity=name(vm) .. "|" .. name(found) .. "|" .. page .. "|" .. original .. "|" .. shown
        if logger and identity~=last_selection then
            logger("COLOR SLOT | RESOLVED DISPLAYED | auxiliary=" .. original .. " | displayed=" .. shown
                .. " | unique_nodes=" .. total .. " | shared_references=" .. reused
                .. " | back_edges=" .. back_edges)
            last_selection=identity
        end
        return found
    end
    function self.read(f,slot,owner,skin_race,skin_scalar,description)
        local t=f.MaterialTarget; local tags=a.values(t.SlotNameTagsToApply.GameplayTags)
        if slot==bundle.SKIN and not description then
            assert(bundle.valid_race(skin_race),"Skin companion verification required")
            bundle.new(a).skin_target(f,"Skin Coloration")
            local p={slot=slot,parameter="Skin Coloration",skin_race=skin_race,skin_scalar=skin_scalar,targets={}}
            for i,tag in ipairs(tags) do
                local mesh=object(owner:GetSlotInstance(tag))
                assert(a.text(mesh:GetSlotNameTag().TagName)==bundle.MESHES[i],"Skin target slot mismatch")
                p.targets[i]={mesh=bundle.MESHES[i],asset=id(mesh:GetCustomizationPartPrimaryAssetId())}
            end
            p.mesh,p.asset=p.targets[1].mesh,p.targets[1].asset
            assert(M.valid(p),"Invalid skin target description")
            return p
        end
        assert(#tags>=1 and #tags<=16,"Unsupported material target count")
        local mesh=object(owner:GetSlotInstance(tags[1]))
        local p={slot=slot,mesh=a.text(tags[1].TagName),parameter=a.text(t.MaterialParameterName),
            asset=id(mesh:GetCustomizationPartPrimaryAssetId()),bundle=description}
        if #tags>1 then
            p.targets={}
            for i,tag in ipairs(tags) do
                local tag_name=a.text(tag.TagName)
                local target=a.unwrap(owner:GetSlotInstance(tag)); local value="-"
                if a.live(target) then
                    assert(a.text(target:GetSlotNameTag().TagName)==tag_name,"Color target slot mismatch")
                    value=id(target:GetCustomizationPartPrimaryAssetId())
                end
                p.targets[i]={mesh=tag_name,asset=value}
            end
        end
        assert(M.valid(p),"Unsupported color target description")
        assert(a.text(mesh:GetSlotNameTag().TagName)==p.mesh,"Target mesh slot mismatch")
        return p
    end
    function self.target(f,p)
        assert(M.valid(p),"Invalid target description")
        local t=f.MaterialTarget; local tags=a.values(t.SlotNameTagsToApply.GameplayTags)
        assert(a.text(t.MaterialParameterName)==p.parameter and #tags==(p.targets and #p.targets or 1),"Recorded material target changed")
        for i,v in ipairs(tags) do
            assert(a.text(v.TagName)==(p.targets and p.targets[i].mesh or p.mesh),"Recorded material target changed")
        end
        local names={}
        for _,v in ipairs(a.values(t.MaterialSlotNames)) do
            local s=a.text(v); assert(rules.material(s),"Unreadable material slot")
            names[#names+1]=s
        end
        assert(#names>0,"No material slots in color target")
        return table.concat(names,",")
    end
    function self.mesh(owner,p)
        assert(M.valid(p),"Invalid mesh description")
        for _,t in ipairs(p.targets or {{mesh=p.mesh,asset=p.asset}}) do
            local tag={TagName=FName(t.mesh)}
            assert(a.text(tag.TagName)==t.mesh,"Target mesh FName round-trip failed")
            local mesh=a.unwrap(owner:GetSlotInstance(tag))
            if t.asset=="-" then
                assert(not a.live(mesh),"Previously absent target appeared: " .. t.mesh)
            else
                mesh=object(mesh)
                assert(a.text(mesh:GetSlotNameTag().TagName)==t.mesh and id(mesh:GetCustomizationPartPrimaryAssetId())==t.asset,
                    "Recorded mesh changed: " .. t.mesh)
            end
        end
    end
    -- strict: the equipped swatch must be a palette item (Default selection
    -- re-equips it from the palette).
    function self.palette(vm,page,strict)
        local slot=a.text(vm.SlotTag.TagName); local owner=assert(outer(name(vm)),"Invalid slot VM location")
        local current=name(vm.EquippedCustomizationPartViewModel)
        local grid=palettes.resolve(page,slot); local count=grid:GetNumItems()
        assert(type(count)=="number" and count%1==0 and count>0 and count<=1024,"Invalid palette size")
        local items,found={},false
        for i=0,count-1 do
            local item=object(grid:GetItemAt(i)); local full=name(item)
            local value,empty=palette_part(item,owner)
            assert(grid:GetIndexForItem(item)==i,"Palette order changed")
            found=found or full==current
            items[#items+1]={object=item,asset=value,index=i,name=full,empty=empty}
        end
        assert(found or not strict,"Equipped item absent from active palette")
        if not found then unoffered(grid,count,owner,object(vm.EquippedCustomizationPartViewModel),current) end
        return items,name(grid)
    end
    function self.equipped_in_palette(vm,grid)
        vm=object(vm); grid=object(grid)
        local host=assert(outer(name(vm)),"Invalid slot VM location")
        local item=object(vm.EquippedCustomizationPartViewModel); local full=name(item)
        palette_part(item,host)
        local count=grid:GetNumItems()
        assert(type(count)=="number" and count%1==0 and count>0 and count<=1024,"Invalid palette size")
        local index=grid:GetIndexForItem(item)
        if type(index)=="number" and index%1==0 and index>=0 and index<count then
            assert(name(grid:GetItemAt(index))==full and grid:GetIndexForItem(item)==index,"Palette order changed")
        else
            unoffered(grid,count,host,item,full)
        end
        assert(name(vm.EquippedCustomizationPartViewModel)==full,"Equipped item changed during palette verification")
    end
    function self.donor(vm,page,profile)
        local items=self.palette(vm,page); local current=id(vm.EquippedCustomizationPartViewModel.AssetId)
        local skin=a.text(vm.SlotTag.TagName)==bundle.SKIN
        -- Captured 0B0/0B1 are NOT interchangeable donors: 0B1 targets only
        -- MI_Head, whereas 0B0 and 0B2 target MI_Head,MI_Body. Prefer the
        -- matching 0B2 for 0B0. The unique head-only swatch uses 0B0 with a
        -- separately recorded stock target; previewing itself is a native no-op.
        -- These are routing hints, never substitutes for native target checks.
        local zabrak="CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_"
        if skin and profile and profile.bundle and (current==zabrak .. "0B0" or current==zabrak .. "0B1") then
            local parsed=assert(bundles.parse(profile.bundle),"Invalid donor bundle")
            local materials=parsed.signature:match("MaterialColor/Skin Coloration/[^/]+/([^;]+)")
            local expected=current==zabrak .. "0B1" and "MI_Head" or "MI_Head,MI_Body"
            assert(materials==expected,"Captured Zabrak donor target changed")
            assert(current~=zabrak .. "0B1" or M.self_preview(profile,current),"Unsupported head-only donor source layout")
            local wanted=current==zabrak .. "0B1" and zabrak .. "0B0" or zabrak .. "0B2"
            for _,item in ipairs(items) do
                if not item.empty and item.asset==wanted then
                    if logger then logger("COLOR DONOR | ZABRAK | source=" .. current .. " | donor=" .. wanted
                        .. " | materials=" .. materials .. " | self_preview=" .. tostring(wanted==current)) end
                    return item.object,item.asset
                end
            end
            error("Compatible Zabrak preview swatch absent from active palette")
        end
        -- Prefer the old family when available, but do not require its asset
        -- spelling. Cloned fragment validation still checks race and targets.
        local function family_of(value) return value:match("^(CustomizationPartDefinition:[%w_]+)%d$") end
        local family=family_of(current)
        if skin and family then
            for _,item in ipairs(items) do
                if not item.empty and item.asset~=current and family_of(item.asset)==family then return item.object,item.asset end
            end
        end
        for _,item in ipairs(items) do
            if not item.empty and item.asset~=current and not item.asset:match("_None$")
                and rules.preview_asset(a.text(vm.SlotTag.TagName),item.asset,profile and profile.parameter,profile and profile.bundle)
                then
                return item.object,item.asset
            end
        end
        error("No alternative non-Default preview swatch in active palette")
    end
    return self
end
return M
