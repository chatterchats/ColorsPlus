local scripts=assert(arg[1])
local assets=assert(loadfile(scripts .. "/gradient_assets.lua"))()
local objects,imports={},0
local fail=false
local function texture(path)
    local o={path=path}
    function o:IsValid() return not self.dead end
    function o:GetFullName() return "Texture2D " .. self.path end
    objects[path]=o; return o
end
local library={IsValid=function() return true end}
function library:ImportFileAsTexture2D(image,path)
    imports=imports+1
    local file=assert(io.open(path,"rb")); assert(file:read(8)=="\137PNG\r\n\26\n"); file:close()
    if fail then return nil end
    return texture("/Engine/Transient.Gradient_" .. imports)
end
function StaticFindObject(path)
    if path=="/Script/Engine.Default__KismetRenderingLibrary" then return library end
    return objects[path]
end
local image={SetColorAndOpacity=function(_,color) assert(color.A==1) end,
    SetVisibility=function(_,v) assert(v==3) end}
function image:SetBrushFromTexture(t,match,...) assert(match==false and select("#",...)==0); self.texture=t end
assets.bind(image,"hue"); assert(imports==1 and image.texture)
-- No by-name reacquisition: each bind imports (a lookup cost a full scan).
local looked=false
local find=StaticFindObject
StaticFindObject=function(path) if path~="/Script/Engine.Default__KismetRenderingLibrary" then looked=true end; return find(path) end
assets.bind(image,"hue"); assert(imports==2 and not looked,"Bind never looks a texture up by name")
assets.bind(image,"saturation"); assets.bind(image,"value"); assert(imports==4)
fail=true; image.texture.dead=true
assert(not pcall(assets.bind,image,"value"),"Failed texture import must not silently present a blank field")
assert(not pcall(assets.bind,image,"unknown"))
print("Gradient textures: assets, fresh import without lookups and import failure passed")
