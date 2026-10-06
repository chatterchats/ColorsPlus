-- luajit tests/rgb_input_test.lua src/Colors+Probe/Scripts
local input = assert(loadfile(assert(arg[1]) .. "/rgb_input.lua"))()
local function near(a,b) assert(math.abs(a-b) < 1e-9, tostring(a) .. " ~= " .. tostring(b)) end
local c, label = input.parse(" 255, 128, 32\r\n")
assert(label == "255,128,32" and c.A == 1)
near(c.R,1); near(c.G,0.215860500114); near(c.B,0.014443843596)
c = input.parse("0, 10, 11")
near(c.R,0); near(c.G,0.003035269835); near(c.B,0.003346535764)
c = input.parse("255,255,255")
assert(c.R == 1 and c.G == 1 and c.B == 1)
for _, invalid in ipairs({"", "255,0", "1,2,3,4", "-1,2,3", "256,2,3", "1.5,2,3",
    "nan,2,3", "inf,2,3", "1e2,2,3", "0xFF,2,3", "1,,2,3", "1,2,3,",
    "return {1,2,3}", "1,2,3 -- comment", string.rep(" ",257) .. "1,2,3"}) do
    assert(not pcall(input.parse, invalid), "accepted invalid input: " .. invalid)
end
assert(not pcall(input.parse, nil))
-- Bounded plain-text read and close even if the read throws.
local original_open, closed = io.open, 0
io.open = function(path, mode)
    assert(path == "rgb" and mode == "r")
    return {read=function(_, bytes) assert(bytes == 257); return "160,64,224" end,
        close=function() closed=closed+1 end}
end
c = input.read("rgb")
near(c.R,0.351532599500); near(c.G,0.051269458374); near(c.B,0.745404209540)
io.open = function() return {read=function() error("read failed") end, close=function() closed=closed+1 end} end
assert(not pcall(input.read,"rgb") and closed == 2)
io.open = function() return nil end
assert(not pcall(input.read,"missing"))
io.open = original_open
for i=0,255 do
    local bytes=input.to_srgb(input.parse(string.format("%d,%d,%d",i,i,i)))
    assert(bytes.R==i and bytes.G==i and bytes.B==i,"8-bit sRGB round-trip")
end
assert(not pcall(input.to_srgb,{R=0/0,G=0,B=0}))
print("RGB input: strict bounded 0-255 parsing, sRGB conversion, endpoints and file failure handling passed")
