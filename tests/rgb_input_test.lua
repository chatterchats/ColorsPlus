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
for i=0,255 do
    local bytes=input.to_srgb(input.parse(string.format("%d,%d,%d",i,i,i)))
    assert(bytes.R==i and bytes.G==i and bytes.B==i,"8-bit sRGB round-trip")
end
assert(not pcall(input.to_srgb,{R=0/0,G=0,B=0}))
print("RGB input: strict bounded 0-255 parsing, sRGB conversion and endpoints passed")
