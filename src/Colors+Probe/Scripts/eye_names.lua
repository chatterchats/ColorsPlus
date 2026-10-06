-- FNames compare without case; UObject paths/ownership are NOT normalized.
-- Scope folding to these observed ASCII eye slot and parameter names only.
local M={}
local slots={mi_eyeleft="MI_EyeLeft",mi_eyeright="MI_EyeRight",mi_eyes="MI_Eyes"}
local parameters={iriscolor1="IrisColor1",iriscolor2="IrisColor2",cloudyiriscolor="CloudyIrisColor"}
local scalars={irissaturation="IrisSaturation",irisbrightness="IrisBrightness"}
function M.slot(s) return type(s)=="string" and slots[s:lower()] or nil end
function M.parameter(s) return type(s)=="string" and parameters[s:lower()] or nil end
function M.scalar(s) return type(s)=="string" and scalars[s:lower()] or nil end
function M.new(a,logger)
    local seen={}
    local function shown(v) return string.format("%q",tostring(v)):sub(1,512) end
    return function(requested)
        assert(M.slot(requested) or M.parameter(requested) or M.scalar(requested),"Unsupported eye FName: " .. shown(requested))
        local ok,value=pcall(function() return FName(requested) end)
        assert(ok,"Eye FName construction failed | requested=" .. shown(requested) .. " | error=" .. shown(value))
        local read,actual=pcall(a.text,value)
        local detail="requested=" .. shown(requested) .. " | returned=" .. shown(actual)
        assert(read and type(actual)=="string" and actual:lower()==requested:lower(),
            "Eye FName round-trip failed | " .. detail)
        if actual~=requested and not seen[requested] then
            seen[requested]=true
            if logger then logger("EYE FNAME | CASE NORMALIZED | " .. detail) end
        end
        return value -- pass the actual FName, not its normalized Lua string
    end
end
return M
