-- Pure sRGB/HSV UI math. The existing RGB backend alone converts to linear.
local M={}
local function unit(v)
    assert(type(v)=="number" and v==v and v>=0 and v<=1,"Invalid HSV channel")
    return v
end
function M.from_hsv(h,s,v)
    h,s,v=unit(h),unit(s),unit(v)
    local sector=(h%1)*6
    local i=math.floor(sector); local f=sector-i
    local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
    local colors={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    local c=colors[i+1]
    return {R=math.floor(c[1]*255+.5),G=math.floor(c[2]*255+.5),B=math.floor(c[3]*255+.5)}
end
function M.to_hsv(rgb,previous_hue)
    local c={}
    for _,k in ipairs({"R","G","B"}) do
        local n=rgb[k]; assert(type(n)=="number" and n==n and n>=0 and n<=255 and n%1==0,"Invalid sRGB byte")
        c[k]=n/255
    end
    local hi=math.max(c.R,c.G,c.B); local lo=math.min(c.R,c.G,c.B); local d=hi-lo
    local h=previous_hue or 0
    if d>0 then
        if hi==c.R then h=((c.G-c.B)/d)%6 elseif hi==c.G then h=(c.B-c.R)/d+2 else h=(c.R-c.G)/d+4 end
        h=h/6
    end
    return unit(h),hi==0 and 0 or d/hi,hi
end
function M.hex(rgb)
    M.to_hsv(rgb)
    return string.format("#%02X%02X%02X",rgb.R,rgb.G,rgb.B)
end
function M.parse_hex(value)
    if type(value)~="string" or #value>32 then return nil end
    local digits=value:match("^%s*#?(%x%x%x%x%x%x)%s*$")
    if not digits then return nil end
    return {R=tonumber(digits:sub(1,2),16),G=tonumber(digits:sub(3,4),16),B=tonumber(digits:sub(5,6),16)}
end
return M
