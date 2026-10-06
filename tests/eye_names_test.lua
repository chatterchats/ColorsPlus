local names=assert(loadfile(assert(arg[1]) .. "/eye_names.lua"))()
local logs,returned={},nil
local a={text=function(v) return v:ToString() end}
local make=names.new(a,function(s) logs[#logs+1]=s end)
FName=function(s)
    local value=returned or s
    return {ToString=function() return value end}
end
for _,s in ipairs({"MI_EyeLeft","MI_EyeRight","MI_Eyes","IrisColor1","IrisColor2","CloudyIrisColor","IrisSaturation","IrisBrightness"}) do
    returned=s; assert(make(s):ToString()==s)
    returned=s:lower(); local count=#logs
    assert(make(s):ToString()==returned and #logs==count+1)
    assert(logs[#logs]:find("requested=",1,true) and logs[#logs]:find("returned=",1,true))
    assert(make(s):ToString()==returned and #logs==count+1,"Case logging must be bounded")
    returned=s:upper(); assert(make(s):ToString()==returned)
end
for _,bad in ipairs({"None","<unavailable>","MI_EyeRight","MI_EyeLeft_0","MI_EyeLeft ","MI_EyeLeft\0"}) do
    returned=bad; local ok,err=pcall(make,"MI_EyeLeft")
    assert(not ok and tostring(err):find('requested="MI_EyeLeft"',1,true) and tostring(err):find("returned=",1,true))
end
assert(names.slot("mi_EYEleft")=="MI_EyeLeft" and names.parameter("IRISCOLOR2")=="IrisColor2")
assert(not names.slot("MI_EyeLeft_0") and not names.parameter("IrisColor3"))
assert(names.scalar("IRISSATURATION")=="IrisSaturation" and names.scalar("irisbrightness")=="IrisBrightness")
assert(not names.parameter("IrisSaturation") and not names.scalar("IrisColor1") and not names.scalar("Color TEX/GEN"))
for _,bad in ipairs({"None","/Game/Test.Object","IrisColor3","MI_EyeLeft_0"}) do assert(not pcall(make,bad)) end
FName=function() error("constructor unavailable") end
local ok,err=pcall(make,"IrisColor1"); assert(not ok and tostring(err):find("requested=",1,true))
FName=function() return {ToString=function() error("unreadable") end} end
ok,err=pcall(make,"IrisColor1"); assert(not ok and tostring(err):find("returned=",1,true))
print("Eye FNames: bounded case folding/logging, real name values, unknown/None/suffix/read/construction failure guards passed")
