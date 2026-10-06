-- Read-only selected-slot survey before replacing the probe's fixed preview
-- donor and recovery target. No equip, preview, cloning, setters or save calls.
local M={}
local COLOR="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"
local SCALAR="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialScalar"
local TAGS="Class /Script/BitReactorCore.CustomizationFragmentInstanceGameplayTags"
local PART="Class /Script/BitReactorGame.BitReactorCustomizationPartViewModel"
local function scalar(v) return tostring(v):gsub("[\r\n\t]"," "):sub(1,1024) end
function M.new(runtime,a)
    local self={}
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local targets=assert(loadfile(directory .. "color_target.lua"))().new(a,runtime.log)
    local bundle=assert(loadfile(directory .. "color_fragments.lua"))()
    local bundles=assert(loadfile(directory .. "color_bundle.lua"))()
    local rules=assert(loadfile(directory .. "color_rules.lua"))()
    local eyes=assert(loadfile(directory .. "eye_material_probe.lua"))().new(a,runtime.log)
    local function log(s) runtime.log("COLOR COMPAT | " .. s) end
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Live object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function id(v)
        return a.text(a.prop(a.prop(v,"PrimaryAssetType"),"Name")) .. ":" .. a.text(a.prop(v,"PrimaryAssetName"))
    end
    local function outer(full) return full:match("^[^ ]+ (.+)%.BitReactorCustomization%w+ViewModel_%d+$") end
    local function candidates(class,limit)
        local values=FindAllOf(class) or {}; assert(type(values)=="table","Unsupported " .. class .. " list")
        local n=0; for _ in pairs(values) do n=n+1; assert(n<=limit,"Scan limit: " .. class) end
        return values
    end
    local function palette(vm,slot_tag,page)
        if runtime.generic_colors then
            local items,grid=targets.palette(vm,page)
            log("PALETTE | grid=" .. grid .. " | count=" .. #items .. " | active-page discovery | donor not yet verified")
            for i,item in ipairs(items) do
                if i<=8 or item.name==name(vm.EquippedCustomizationPartViewModel) then
                    log("PALETTE ITEM | index=" .. item.index .. " | asset=" .. item.asset)
                end
            end
            return #items>1
        end
        local grids,seen={},{}
        for _,widget in pairs(candidates("WBP_Customization_SelectionTiles_C",256)) do
            if a.live(widget) and widget:IsVisible()==true
                and a.text(a.prop(a.prop(widget,"CurrentSlotTag"),"TagName"))==slot_tag then
                local grid=object(widget.PartsGridList); local full=name(grid)
                if not seen[full] then seen[full]=true; grids[#grids+1]=grid end
            end
        end
        assert(#grids==1,"Expected one visible palette for the selected slot; found " .. #grids)
        local grid=grids[1]
        local count=grid:GetNumItems()
        assert(type(count)=="number" and count%1==0 and count>0 and count<=1024,"Unsupported palette size")
        local current=name(vm.EquippedCustomizationPartViewModel)
        local vm_outer=assert(outer(name(vm)),"Unsupported slot VM location")
        local found,alternatives,blue=false,0,false
        local rows={}
        for i=0,count-1 do
            local item=object(grid:GetItemAt(i)); local full=name(item)
            assert(outer(full)==vm_outer and name(item:GetClass())==PART,"Palette VM ownership/class mismatch")
            assert(grid:GetIndexForItem(item)==i,"Palette ordering changed")
            local asset=id(item.AssetId)
            assert(asset:match("^CustomizationPartDefinition:[%w_]+$"),"Unexpected palette asset")
            local selected=full==current
            found=found or selected
            if not selected then alternatives=alternatives+1 end
            blue=blue or asset=="CustomizationPartDefinition:CPD_H_Outfit_Color_Blue_14"
            -- Names/membership are discovery only, not proof of donor fragments.
            if i<8 or selected or asset=="CustomizationPartDefinition:CPD_H_Outfit_Color_Blue_14" then
                rows[#rows+1]="PALETTE ITEM | index=" .. i .. " | selected=" .. tostring(selected)
                    .. " | name=" .. scalar(a.text(item.DisplayName)) .. " | asset=" .. asset
            end
        end
        assert(found,"Equipped VM is absent from the visible palette")
        log("PALETTE | grid=" .. name(grid) .. " | count=" .. count .. " | alternatives=" .. alternatives
            .. " | legacy_blue_present=" .. tostring(blue) .. " | donor not yet verified")
        for _,row in ipairs(rows) do log(row) end
        return alternatives>0
    end
    local function nested(values)
        local visited,total={},0
        local function walk(f,depth,owner)
            f=object(f); local full=name(f)
            assert(not visited[full],"Nested slot cycle/alias")
            visited[full]=true; total=total+1; assert(total<=32,"Nested fragment limit")
            local class=name(f:GetClass())
            local actual=name(f:GetOwningCustomizationInstance())
            assert(not owner or owner==actual,"Nested fragment owner mismatch")
            log("NESTED | depth=" .. depth .. " | class=" .. class .. " | object=" .. full)
            if class=="Class /Script/BitReactorCore.CustomizationFragmentInstanceSlot" then
                local visible_ok,visible=pcall(function() return f:GetSlotVisibleInUI() end)
                log("NESTED SLOT | tag=" .. scalar(a.text(f:GetSlotNameTag().TagName))
                    .. " | part=" .. id(f:GetCustomizationPartPrimaryAssetId())
                    .. " | visible_in_ui=" .. (visible_ok and scalar(visible) or "unavailable"))
                assert(depth<4,"Nested depth limit")
                local children=a.values(f:GetFragmentInstances()); assert(#children<=16,"Nested child limit")
                for _,child in ipairs(children) do walk(child,depth+1,actual) end
            elseif class==COLOR then
                local t=f.MaterialTarget; local c=f:GetColor(); local tags,materials={},{}
                for _,v in ipairs(a.values(t.SlotNameTagsToApply.GameplayTags)) do tags[#tags+1]=a.text(v.TagName) end
                for _,v in ipairs(a.values(t.MaterialSlotNames)) do materials[#materials+1]=a.text(v) end
                log("NESTED COLOR | parameter=" .. scalar(a.text(t.MaterialParameterName))
                    .. " | materials=" .. scalar(table.concat(materials,",")) .. " | mesh_tags=" .. scalar(table.concat(tags,","))
                    .. " | rgba=" .. scalar(tostring(c.R)..","..tostring(c.G)..","..tostring(c.B)..","..tostring(c.A)))
            elseif class=="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialSwap" then
                local read,err=pcall(eyes.inspect,f)
                if not read then log("MATERIAL SWAP GAP | " .. scalar(err)) end
            end
        end
        for _,f in ipairs(values) do
            if name(object(f):GetClass())=="Class /Script/BitReactorCore.CustomizationFragmentInstanceSlot" then walk(f,0) end
        end
    end
    local function fragment(f,vm,slot_tag,index,skin_race,skin_scalar,description)
        f=object(f); local class=name(f:GetClass())
        log("FRAGMENT | index=" .. index .. " | name=" .. name(f) .. " | class=" .. class)
        if class~=COLOR and class~=SCALAR and class~=TAGS then return false end
        local owner=object(f:GetOwningCustomizationInstance())
        local slot=object(f:GetOwningCustomizationSlot())
        assert(a.text(slot:GetSlotNameTag().TagName)==slot_tag,"Fragment slot tag differs from selection")
        assert(name(owner:GetSlotInstance(vm.SlotTag))==name(slot),"Fragment owner/slot mismatch")
        assert(id(slot:GetCustomizationPartPrimaryAssetId())==id(vm.EquippedCustomizationPartViewModel.AssetId),
            "Fragment equipped part mismatch")
        log("OWNER | " .. name(owner) .. " | slot=" .. name(slot))
        if class==TAGS then
            local container=assert(a.prop(f,"GameplayTags"),"Unreadable gameplay tags")
            local values=a.values(assert(a.prop(container,"GameplayTags"),"Unreadable gameplay tag array"))
            assert(#values<=128,"Gameplay tag detail limit")
            log("GAMEPLAY TAGS | index=" .. index .. " | count=" .. #values)
            for _,v in ipairs(values) do
                local tag=a.text(v.TagName)
                assert(tag~="" and tag~="<unavailable>","Unreadable gameplay tag")
                log("GAMEPLAY TAG | index=" .. index .. " | tag=" .. scalar(tag))
            end
            return false -- companion data is diagnostic-only, never a tint
        end
        local opaque,tintable=false,false
        if class==COLOR then
            local color=f:GetColor(); local rgba,plain={},{}; opaque=true
            for _,key in ipairs({"R","G","B","A"}) do
                local v=a.prop(color,key)
                assert(type(v)=="number" and v==v and math.abs(v)<math.huge,"Unreadable color")
                rgba[#rgba+1]=tostring(v)
                plain[key]=v
                opaque=opaque and v>=0 and v<=1 and (key~="A" or v==1)
            end
            local parameter=a.text(f.MaterialTarget.MaterialParameterName)
            local hsv=slot_tag==rules.SCAR and parameter==rules.SCAR_HSV_PARAMETER
            tintable=rules.color(plain,slot_tag,parameter) and not (slot_tag==rules.SCAR and parameter=="COS Swatch")
            log("COLOR | index=" .. index .. " | linear_rgba=" .. table.concat(rgba,",") .. " | normalized_opaque=" .. tostring(opaque)
                .. " | rgb_editable=" .. tostring(tintable and not hsv) .. " | hsv_adjustable=" .. tostring(tintable and hsv))
        else
            local value=a.prop(f,"Value")
            assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Unreadable material scalar")
            log("SCALAR | index=" .. index .. " | value=" .. tostring(value) .. " | diagnostic-only")
        end
        local target=f.MaterialTarget
        local parameter=a.text(target.MaterialParameterName)
        assert(parameter~="" and parameter~="<unavailable>","Unreadable material parameter")
        local tags=a.values(target.SlotNameTagsToApply.GameplayTags)
        local materials=a.values(target.MaterialSlotNames)
        assert(#tags<=32 and #materials<=32,"Material target detail limit")
        local material_names={}
        for _,v in ipairs(materials) do material_names[#material_names+1]=a.text(v) end
        log("TARGET | index=" .. index .. " | parameter=" .. scalar(parameter)
            .. " | materials=" .. scalar(table.concat(material_names,",")) .. " | mesh_tags=" .. #tags)
        for _,t in ipairs(tags) do
            local tag=a.text(t.TagName)
            local mesh=a.unwrap(owner:GetSlotInstance(t))
            if a.live(mesh) then
                assert(a.text(mesh:GetSlotNameTag().TagName)==tag,"Target mesh tag mismatch")
                log("TARGET SLOT | tag=" .. scalar(tag) .. " | equipped_part=" .. id(mesh:GetCustomizationPartPrimaryAssetId()))
            else
                log("TARGET SLOT | tag=" .. scalar(tag) .. " | state=absent")
            end
        end
        if not tintable or #materials==0 then return false end
        local eligible,err=pcall(targets.read,f,slot_tag,owner,skin_race,skin_scalar,description)
        if not eligible then log("TARGET INELIGIBLE | " .. scalar(err)) end
        return eligible
    end
    function self.capture()
        if runtime.eye_preview and (runtime.eye_preview.pending or runtime.eye_preview.blocked) then
            log("REFUSED | Stop/restore the eye probe before surveying"); return false
        end
        if runtime.picker and runtime.picker.active or runtime.tint and
            (runtime.tint.pending or runtime.tint.applied or runtime.tint.blocked) then
            log("REFUSED | Close/restore the picker session before surveying another slot"); return false
        end
        log("BEGIN | read-only selected color-slot survey")
        local ok,err=pcall(function()
            local page
            for _,p in pairs(candidates("WBP_Customization_ItemPage_C",128)) do
                if a.live(p) and p:IsActivated()==true then assert(not page,"Ambiguous active item page"); page=name(p) end
            end
            assert(page,"Open a customization color page first")
            local binding=lifetime.bind(page)
            log("CONTEXT | page=" .. page .. " | creator=" .. binding.master)
            local vm,root
            for _,aux in pairs(candidates("CustomizationAuxVM_C",128)) do
                if a.live(aux) then
                    local v=a.unwrap(a.prop(aux,"CurrentCustomizationSlotVM"))
                    if a.live(v) then
                        assert(not vm,"Ambiguous selected slot"); vm=v
                        root=a.prop(aux,"RootCustomizationSlotVM")
                    end
                end
            end
            vm=object(vm)
            if runtime.generic_colors then vm=targets.selected(vm,page,root) end
            local slot_tag=a.text(vm.SlotTag.TagName)
            local equipped=object(vm.EquippedCustomizationPartViewModel)
            log("SELECTED | name=" .. scalar(a.text(vm.DisplayName)) .. " | tag=" .. scalar(slot_tag)
                .. " | swatch=" .. scalar(a.text(equipped.DisplayName)) .. " | asset=" .. id(equipped.AssetId))
            local values=a.values(vm:GetFragments())
            log("FRAGMENTS | count=" .. #values)
            assert(#values<=16,"Fragment detail limit exceeded")
            local skin_race,skin_scalar,skin_candidate,description,primary_name,race_candidate
            if runtime.generic_colors and bundles.parameter(slot_tag) then
                local checked,why=pcall(function()
                    local f,_,race,scalar,layout=bundle.new(a).read(values,{slot=slot_tag})
                    local profile=targets.read(f,slot_tag,object(f:GetOwningCustomizationInstance()),race,scalar,layout)
                    targets.donor(vm,page,profile) -- membership/family only; no activation
                    skin_race,skin_scalar=race,scalar
                    description,primary_name=layout,name(f)
                end)
                if not checked then log("SKIN BUNDLE GAP | " .. scalar(why)) end
            end
            local single=false
            for i,f in ipairs(values) do
                local read,eligible=pcall(fragment,f,vm,slot_tag,i,skin_race,skin_scalar,description)
                if not read then log("FRAGMENT GAP | index=" .. i .. " | " .. scalar(eligible)) end
                single=read and eligible and #values==1
                if skin_race and i==2 then skin_candidate=read and eligible end
                if description and name(f)==primary_name then race_candidate=read and eligible end
            end
            local nested_ok,nested_error=pcall(nested,values)
            if not nested_ok then log("NESTED GAP | " .. scalar(nested_error)) end
            local palette_ok,alternatives=pcall(palette,vm,slot_tag,page)
            if not palette_ok then log("PALETTE GAP | " .. scalar(alternatives)) end
            local status=#values==0 and "EMPTY/DEFAULT: needs reversible fallback"
                or skin_candidate and palette_ok and alternatives and "CANDIDATE: human skin bundle; companions preserved; preview/write not verified"
                or race_candidate and palette_ok and alternatives and (bundles.parameter(slot_tag)=="Cheek / Blush Color"
                    and "CANDIDATE: blush color/blend-mode pair; blend mode preserved; preview/write not verified"
                    or rules.iris(slot_tag) and "CANDIDATE: iris color/amount pair; eye side and amount preserved; preview/write not verified"
                    or slot_tag==rules.SCAR and "CANDIDATE: scar tint/strength pair; display swatch and strength preserved; preview/write not verified"
                    or "CANDIDATE: race tint bundle; editable RGB; companions preserved; preview/write not verified")
                or single and palette_ok and alternatives and (slot_tag==rules.SCAR
                    and "CANDIDATE: scar HSV adjustments; selected Look retained; preview/write not verified"
                    or "CANDIDATE: single color target; source alpha preserved; preview/write not verified")
                or "UNVERIFIED: inspect fragment/target/palette gaps"
            log("RESULT | " .. status)
        end)
        if not ok then log("FAILED | " .. scalar(err)) end
        log("END | no game state written")
        return ok
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then log("Console unavailable"); return end
        runtime:console("colors_compat",function(_,parameters,output)
            local message
            if parameters and #parameters>0 then message="Usage: colors_compat"
            else
                runtime:after("color-compat:capture",1,self.capture)
                message="Queued read-only color compatibility snapshot."
            end
            log(message)
            if output then pcall(function() output:Log(message) end) end
        end)
        log("Ready: colors_compat (read-only; selected slot and palette)")
    end
    return self
end
return M
