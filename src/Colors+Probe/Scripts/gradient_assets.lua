-- Tiny packaged PNGs, imported on the game thread. Only identities survive calls;
-- UImage brushes own the textures while attached, never Lua wrapper caches.
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local files={saturation="saturation.png",value="value.png",hue="hue.png"}
local identities={}
local M={}
local function valid(o) return o and o:IsValid() end
function M.bind(image,key)
    local file=assert(files[key],"Unknown gradient asset")
    local name=identities[key]
    local texture=name and StaticFindObject(name:match("^[^ ]+ (.+)$"))
    if not valid(texture) or texture:GetFullName()~=name then
        local library=StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
        assert(valid(library),"Gradient texture import library unavailable")
        -- The mod path follows the script's native Windows path in-game.
        texture=library:ImportFileAsTexture2D(image,directory .. "../Assets/" .. file)
        assert(valid(texture),"Gradient texture import failed: " .. file)
        identities[key]=texture:GetFullName()
    end
    image:SetBrushFromTexture(texture,false)
    image:SetColorAndOpacity({R=1,G=1,B=1,A=1})
    image:SetVisibility(3)
end
return M
