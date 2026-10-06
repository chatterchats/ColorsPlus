-- Plain RGB input only: never execute user configuration as Lua.
local M = {}
local function linear(byte)
    local value = byte / 255
    if value <= 0.04045 then return value / 12.92 end
    return ((value + 0.055) / 1.055) ^ 2.4
end
function M.parse(text)
    assert(type(text) == "string" and #text <= 256, "RGB input must be at most 256 bytes")
    local r, g, b = text:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    assert(r, "Use three integer sRGB values: R, G, B (0-255)")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    assert(r and g and b and r <= 255 and g <= 255 and b <= 255, "RGB channels must be integers from 0 to 255")
    return {R=linear(r), G=linear(g), B=linear(b), A=1}, string.format("%d,%d,%d",r,g,b)
end
function M.to_srgb(color)
    local bytes = {}
    for _, key in ipairs({"R","G","B"}) do
        local v = color[key]
        assert(type(v) == "number" and v == v and v >= 0 and v <= 1, "Invalid linear RGB")
        local encoded = v <= 0.0031308 and v * 12.92 or 1.055 * v ^ (1/2.4) - 0.055
        bytes[key] = math.floor(encoded * 255 + 0.5)
    end
    return bytes
end
return M
