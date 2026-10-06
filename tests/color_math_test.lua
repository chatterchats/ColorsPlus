local scripts=assert(arg[1])
local m=assert(loadfile(scripts .. "/color_math.lua"))()
local function equals(a,b) assert(a.R==b.R and a.G==b.G and a.B==b.B) end
for _,rgb in ipairs({{R=0,G=0,B=0},{R=255,G=255,B=255},{R=128,G=128,B=128},
    {R=255,G=0,B=0},{R=0,G=255,B=0},{R=0,G=0,B=255},{R=255,G=128,B=32},
    {R=17,G=84,B=213},{R=1,G=2,B=3}}) do
    local h,s,v=m.to_hsv(rgb); equals(m.from_hsv(h,s,v),rgb)
    equals(m.parse_hex(m.hex(rgb)),rgb)
end
for r=0,255,17 do for g=0,255,17 do for b=0,255,17 do
    local rgb={R=r,G=g,B=b}; equals(m.from_hsv(m.to_hsv(rgb)),rgb)
end end end
equals(m.from_hsv(0,1,1),m.from_hsv(1,1,1))
local h,s,v=m.to_hsv({R=128,G=128,B=128},.7); assert(h==.7 and s==0 and v==128/255)
equals(m.parse_hex(" ff8020 "),{R=255,G=128,B=32})
for _,raw in ipairs({"#123","#12345678","#GG0000","0x123456","#123456junk","#12 3456",string.rep("a",100)}) do assert(not m.parse_hex(raw)) end
assert(not m.parse_hex(nil))
for _,rgb in ipairs({{R=0/0,G=0,B=0},{R=-1,G=0,B=0},{R=256,G=0,B=0},{R=1.5,G=0,B=0}}) do assert(not pcall(m.to_hsv,rgb)) end
assert(not pcall(m.from_hsv,0/0,1,1)); assert(not pcall(m.from_hsv,0,2,1))
print("Color math: sRGB/HSV round trips, endpoints, hue retention and strict bounded hex parsing passed")
