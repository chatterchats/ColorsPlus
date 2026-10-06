-- Read-only material-swap evidence. No asset loads, guessed parameter getters,
-- dynamic material creation, setters, equip, refresh, or save operations.
local M={}
local SWAP="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialSwap"
local SUPPORTED={["Class /Script/Engine.MaterialInstanceConstant"]=true,
    ["Class /Script/Engine.MaterialInstanceDynamic"]=true,["Class /Script/Engine.MaterialInstance"]=true}
function M.new(a,logger)
    local self={}
    local function scalar(v) return tostring(v):gsub("[\r\n\t]"," "):sub(1,1024) end
    local function log(s) logger("EYE MATERIAL | " .. s) end
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Material probe object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function color(v)
        local values={}
        for _,k in ipairs({"R","G","B","A"}) do
            local n=a.prop(v,k); assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Unreadable material RGBA")
            values[#values+1]=tostring(n)
        end
        return table.concat(values,",")
    end
    local function switches(current,depth,remaining)
        -- Inspect only reflected runtime records. Never change static switches,
        -- load editor-only data, or infer effective shader behavior from a row.
        log("STATIC BEGIN | depth=" .. depth .. " | recorded runtime switches; not resolved shader defaults")
        local read,values=pcall(function()
            local data=assert(a.prop(object(current),"StaticParametersRuntime"),"StaticParametersRuntime unavailable")
            local array=assert(a.prop(data,"StaticSwitchParameters"),"StaticSwitchParameters unavailable")
            return a.values(array)
        end)
        if not read then log("STATIC GAP | depth=" .. depth .. " | " .. scalar(values)); return 0 end
        log("STATIC SWITCHES | depth=" .. depth .. " | count=" .. #values)
        local shown=math.min(#values,32,remaining)
        for i=1,shown do
            local ok,value=pcall(function()
                local row=values[i]
                local info=assert(a.prop(row,"ParameterInfo"),"Switch ParameterInfo unavailable")
                local parameter=a.text(a.prop(info,"Name"))
                assert(type(parameter)=="string" and parameter~="" and parameter~="<unavailable>"
                    and parameter~="nil","Switch name unavailable")
                local enabled,override=a.prop(row,"Value"),a.prop(row,"bOverride")
                assert(type(enabled)=="boolean","Switch Value is not a boolean")
                assert(type(override)=="boolean","Switch bOverride is not a boolean")
                return "depth=" .. depth .. " | row=" .. i .. " | name=" .. scalar(parameter)
                    .. " | association=" .. scalar(a.text(a.prop(info,"Association")))
                    .. " | index=" .. scalar(a.text(a.prop(info,"Index"))) .. " | value=" .. tostring(enabled)
                    .. " | override=" .. tostring(override)
            end)
            log((ok and "STATIC SWITCH | " or "STATIC ROW GAP | depth=" .. depth .. " | row=" .. i .. " | ") .. scalar(value))
        end
        if #values>shown then log("STATIC TRUNCATED | depth=" .. depth .. " | shown=" .. shown .. " | count=" .. #values
            .. " | limits=32 per material,64 per swap") end
        return shown
    end
    function self.inspect(fragment)
        fragment=object(fragment)
        assert(name(fragment:GetClass())==SWAP,"Expected material-swap fragment")
        log("SWAP | fragment=" .. name(fragment) .. " | owner=" .. name(fragment:GetOwningCustomizationInstance()))
        local t=a.prop(fragment,"MaterialTarget")
        local ok,err=pcall(function()
            local materials,tags={},{}
            for _,v in ipairs(a.values(a.prop(t,"MaterialSlotNames"))) do materials[#materials+1]=a.text(v) end
            for _,v in ipairs(a.values(a.prop(a.prop(t,"SlotNameTagsToApply"),"GameplayTags"))) do tags[#tags+1]=a.text(v.TagName) end
            log("TARGET | materials=" .. scalar(table.concat(materials,",")) .. " | mesh_tags=" .. scalar(table.concat(tags,","))
                .. " | parameter=" .. scalar(a.text(a.prop(t,"MaterialParameterName"))))
        end)
        if not ok then log("TARGET GAP | " .. scalar(err)) end
        local replacement=a.unwrap(a.prop(fragment,"ReplacementMaterial"))
        if not a.live(replacement) then
            log("REPLACEMENT UNAVAILABLE | no asset loaded by probe | soft=" .. scalar(a.text(a.prop(fragment,"ReplacementMaterialSoft"))))
            return
        end
        local current,seen,rows,static_rows=replacement,{},0,0
        for depth=0,3 do
            current=object(current); local full=name(current)
            if seen[full] then log("PARENT CYCLE | " .. full); return end
            seen[full]=true
            local class=name(current:GetClass())
            log("MATERIAL | depth=" .. depth .. " | object=" .. full .. " | class=" .. class)
            if not SUPPORTED[class] then
                log("CHAIN END | non-instance material; compiled defaults/expressions not inspected"); return
            end
            -- Separate budget: static evidence must not displace the 43-scalar
            -- special-race captures or their texture records.
            static_rows=static_rows+switches(current,depth,64-static_rows)
            for _,kind in ipairs({"Vector","Scalar","Texture"}) do
                local read,values=pcall(function() return a.values(a.prop(current,kind .. "ParameterValues")) end)
                if not read then log("PARAMETER GAP | depth=" .. depth .. " | kind=" .. kind .. " | " .. scalar(values))
                else
                    log("OVERRIDES | depth=" .. depth .. " | kind=" .. kind .. " | count=" .. #values)
                    -- Special-race eyes have up to 43 scalar overrides. Capture
                    -- those without lifting the overall 64-row-per-swap budget.
                    local limit=kind=="Scalar" and 64 or 16
                    for i=1,math.min(#values,limit) do
                        rows=rows+1
                        if rows>64 then log("PARAMETER LIMIT | 64 rows per swap"); return end
                        local good,value=pcall(function()
                            local info=a.prop(values[i],"ParameterInfo"); local parameter=a.text(a.prop(info,"Name"))
                            local v=a.prop(values[i],"ParameterValue")
                            if kind=="Vector" then v=color(v)
                            elseif kind=="Scalar" then
                                assert(type(v)=="number" and v==v and math.abs(v)<math.huge,"Unreadable scalar")
                            else
                                v=a.unwrap(v); v=a.live(v) and name(v) or "<unavailable texture>"
                            end
                            return "depth=" .. depth .. " | kind=" .. kind .. " | name=" .. scalar(parameter)
                                .. " | association=" .. scalar(a.text(a.prop(info,"Association")))
                                .. " | index=" .. scalar(a.text(a.prop(info,"Index"))) .. " | value=" .. scalar(v)
                        end)
                        log((good and "PARAMETER | " or "PARAMETER GAP | ") .. scalar(value))
                    end
                    if #values>limit then log("TRUNCATED | " .. kind .. " | shown=" .. limit .. " | count=" .. #values) end
                end
            end
            local parent=a.unwrap(a.prop(current,"Parent"))
            if not a.live(parent) then log("CHAIN END | parent unavailable; no asset loaded"); return end
            if depth==3 then log("PARENT LIMIT | next=" .. name(parent)); return end
            current=parent
        end
    end
    return self
end
return M
