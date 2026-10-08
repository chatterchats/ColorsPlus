-- Plain values shared by live writes and journals. Native material selectors
-- are preserved verbatim; Lua never evaluates their regular expressions.
local M={}
M.FRECKLES="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Freckles.Color"
M.VITILIGO="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Vitiligo.Tint"
M.SCAR="br.Customization.Slot.Character.Appearance.Humanoid.FacialDetails.Group.Scar.Look"
M.VITILIGO_PARAMETER="Vitilago Color Override"
M.SCAR_PARAMETER="MM Scar Tint"
M.SCAR_HSV_PARAMETER="Scar HSV Shift"
M.IRIS_LEFT="br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintLeft"
M.IRIS_RIGHT="br.Customization.Slot.Character.Appearance.Humanoid.Head.IrisTintRight"
M.IRIS_INNER="br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisInner"
M.IRIS_SHARED="br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.IrisTint"
local IRIS={
    [M.IRIS_LEFT]={parameter="MM Iris Color Outer",amount="MM Iris Recolour",materials="MI_EyeLeft",prefix="CPD_COS_IrisTint_"},
    [M.IRIS_RIGHT]={parameter="MM Iris Color Outer",amount="MM Iris Recolour",materials="MI_EyeRight",prefix="CPD_COS_IrisTint_"},
    [M.IRIS_INNER]={parameter="MM Iris Color Inner",amount="MM Iris Inner Amount",materials="MI_EyeLeft,MI_EyeRight",prefix="CPD_COS_IrisInner_"},
    [M.IRIS_SHARED]={parameter="MM Iris Color Outer",amount="MM Iris Recolour",materials="MI_EyeLeft,MI_EyeRight",prefix="CPD_COS_IrisTint_"},
}
function M.iris(slot) return IRIS[slot] end
M.HSV_CHANNELS={{key="R",label="Hue adjustment",min=-180,max=180},
    {key="G",label="Saturation adjustment",min=-100,max=100},
    {key="B",label="Value adjustment",min=-100,max=100}}
function M.hsv(p) return type(p)=="table" and p.slot==M.SCAR and p.parameter==M.SCAR_HSV_PARAMETER and not p.bundle end
function M.scar_swatch(description)
    return type(description)=="string" and description:match("^b1@2@MaterialColor/COS Swatch/")~=nil
end
function M.preview_asset(slot,asset,parameter,description)
    local iris=M.iris(slot)
    if iris then return type(asset)=="string" and asset:match("^CustomizationPartDefinition:" .. iris.prefix .. "[%w_]+$")~=nil end
    -- The rebuilt Look presets share the RGB swatch/tint/strength layout.
    -- Earlier HSV Looks still require a Look donor; None borrows an RGB tint.
    if slot==M.SCAR and parameter==M.SCAR_PARAMETER and M.scar_swatch(description) then
        return type(asset)=="string" and (asset:match("^CustomizationPartDefinition:CPD_COS_ScarLook_[%w_]+$")~=nil
            or asset:match("^CustomizationPartDefinition:CPD_COS_ScarTint_[%w_]+$")~=nil)
    end
    local pattern=parameter==M.SCAR_HSV_PARAMETER and "^CustomizationPartDefinition:CPD_COS_ScarLook_[%w_]+$"
        or "^CustomizationPartDefinition:CPD_COS_ScarTint_[%w_]+$"
    return slot~=M.SCAR or type(asset)=="string" and asset:match(pattern)~=nil
end
function M.parameter(s)
    return type(s)=="string" and #s>0 and #s<=128 and s:match("^[%w_ /]+$")~=nil
end
function M.material(s)
    return type(s)=="string" and #s>0 and #s<=256 and s:match("^[%w_%^%$%(%)|%.%[%]%+%*%?%-]+$")~=nil
end
function M.materials(s)
    if type(s)~="string" or #s>4096 then return false end
    local names={}
    for v in s:gmatch("[^,]+") do
        if not M.material(v) or #names>=16 then return false end
        names[#names+1]=v
    end
    return #names>0 and table.concat(names,",")==s
end
function M.alpha(slot,n)
    return n==1 or slot==M.FRECKLES and type(n)=="number" and math.abs(n-.99)<.000001
end
function M.finite(c)
    if type(c)~="table" then return false end
    for _,k in ipairs({"R","G","B","A"}) do
        local v=c[k]
        if type(v)~="number" or v~=v or math.abs(v)==math.huge then return false end
    end
    return true
end
function M.normalized(c)
    if not M.finite(c) then return false end
    for _,k in ipairs({"R","G","B","A"}) do if c[k]<0 or c[k]>1 then return false end end
    return true
end
function M.color(c,slot,parameter)
    if slot==M.SCAR and parameter==M.SCAR_HSV_PARAMETER then
        if not M.finite(c) or c.A~=1 then return false end
        for _,channel in ipairs(M.HSV_CHANNELS) do
            if c[channel.key]<channel.min or c[channel.key]>channel.max then return false end
        end
        return true
    end
    -- Native scar tints are shader multipliers, including values above 1.
    -- Preserve these baselines in clones/journals/restoration without clipping.
    if slot==M.SCAR and parameter==M.SCAR_PARAMETER then
        return M.finite(c) and c.A==1 and c.R>=0 and c.G>=0 and c.B>=0
    end
    return M.normalized(c) and M.alpha(slot,c.A)
end
function M.input_color(c,slot,parameter)
    if slot==M.SCAR and parameter==M.SCAR_HSV_PARAMETER then return M.color(c,slot,parameter) end
    return M.normalized(c) and M.alpha(slot,c.A)
end
function M.empty_color_slot(slot)
    return type(slot)=="string" and (slot==M.VITILIGO or slot==M.SCAR or M.iris(slot)~=nil or slot:find("Color",1,true)~=nil or slot:match("%.SkinTone$")~=nil
        or slot:match("%.Sclera$")~=nil or slot:match("%.ScleraLeft$")~=nil or slot:match("%.ScleraRight$")~=nil)
end
function M.empty_editable_slot(slot) return M.empty_color_slot(slot) end
-- UI eligibility is about the displayed selector, not the selected asset's
-- incidental material fragments. Vanilla Eyes.Color is an eye preset list;
-- the added iris/sclera tint palettes have their own distinct slot tags.
-- A mesh slot tag: humanoid meshes end in ".Mesh"; astromech droids number
-- theirs (".Body.Mesh_0", ".Head.Mesh_2", observed 2026-10-08).
function M.mesh_tag(s)
    return type(s)=="string" and (s:match("^br%.Customization%.Slot%.Character%.[%w_.]+%.Mesh$")~=nil
        or s:match("^br%.Customization%.Slot%.Character%.[%w_.]+%.Mesh_%d+$")~=nil)
end
function M.launcher_color_slot(slot)
    return M.empty_color_slot(slot)
        and slot~="br.Customization.Slot.Character.Appearance.Humanoid.Head.Eyes.Color"
        and not slot:match("%.Mesh$") and not slot:match("%.Mesh_%d+$")
end
-- Context events that retire scalar lookup hints: the page, creator or slot
-- category itself changed (unknown reasons count). Every other event only
-- refuses lookups in flight; hints are fully revalidated on each use and a
-- failed hint falls back to full discovery.
local STRUCTURAL={["page closed"]=true,["creator closed"]=true,UpdateRootCustomizationSlotVM=true}
function M.structural_context(reason) return reason==nil or STRUCTURAL[reason]==true end
return M
