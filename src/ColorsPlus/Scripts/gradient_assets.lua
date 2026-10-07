-- Tiny packaged PNGs, imported on the game thread. Only identities survive calls;
-- UImage brushes own the textures while attached, never Lua wrapper caches.
-- Each bind imports afresh. Reusing an earlier texture meant a by-name lookup
-- that the lookup trace (2026-10-07) showed costing a full object scan (~33ms)
-- in 9 of 13 binds: the texture had been collected, or UE4SS had not seen its
-- name yet. Unreferenced textures are left to garbage collection.
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local files={saturation="saturation.png",value="value.png",hue="hue.png"}
local M={}
local function valid(o) return o and o:IsValid() end
function M.bind(image,key)
    local file=assert(files[key],"Unknown gradient asset")
    local library=StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
    assert(valid(library),"Gradient texture import library unavailable")
    -- The mod path follows the script's native Windows path in-game.
    local texture=library:ImportFileAsTexture2D(image,directory .. "../Assets/" .. file)
    assert(valid(texture),"Gradient texture import failed: " .. file)
    image:SetBrushFromTexture(texture,false)
    image:SetColorAndOpacity({R=1,G=1,B=1,A=1})
    image:SetVisibility(3)
end
return M
