-- Non-mutating before/after evidence for the source array setter.
-- Unknown/foreign payloads are not inspected. No material pointer access.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local PREFIX="Class /Script/BitReactorCore.CustomizationFragmentInstance"
local ROLES={"GameplayTags","MaterialColor","MaterialScalar","MaterialSwap"}
local function hex(s) return (s:gsub(".",function(ch) return string.format("%02x",ch:byte()) end)) end
function M.new(a,log,call,directory)
    local codec=assert(loadfile(directory .. "color_bundle.lua"))()
    local bundles=codec.new(a)
    local self={}
    local function clean(s) return tostring(s):gsub("[\r\n\t]"," "):sub(1,2048) end
    local function object(v,label)
        v=call(label .. " unwrap",function() return a.unwrap(v) end)
        assert(call(label .. " IsValid",function() return a.live(v) end),"Object unavailable: " .. label)
        return v
    end
    local function name(v,label)
        v=object(v,label)
        local n=call(label .. " GetFullName",function() return a.name(v) end)
        assert(type(n)=="string" and #n<=2048,"Invalid identity")
        return n
    end
    local function field(v,key,label)
        return call(label .. " " .. key,function() return object(v,label)[key] end)
    end
    local function text(v,label)
        local s=call(label .. " text",function() return a.text(v) end)
        assert(type(s)=="string" and #s<=256,"Text evidence bound")
        return s
    end
    local function target(f,label)
        local t=field(f,"MaterialTarget",label)
        local parameter=text(call(label .. " parameter",function() return t.MaterialParameterName end),label .. " parameter")
        local tag_values=call(label .. " tags ForEach/unwrap",function() return a.values(t.SlotNameTagsToApply.GameplayTags) end)
        local material_values=call(label .. " materials ForEach/unwrap",function() return a.values(t.MaterialSlotNames) end)
        assert(#tag_values<=16 and #material_values<=16,"Target evidence bounds")
        local tags,materials={},{}
        for i,v in ipairs(tag_values) do
            tags[i]=text(call(label .. " tag " .. i,function() return v.TagName end),label .. " tag " .. i)
        end
        for i,v in ipairs(material_values) do materials[i]=text(v,label .. " material " .. i) end
        local description=table.concat({parameter,table.concat(tags,","),table.concat(materials,",")},"|")
        assert(#description<=4096,"Target evidence bound")
        return description
    end
    local function same_rgb(x,y)
        for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>.00001 then return false end end
        return true
    end
    function self.inspect(array,s,phase,expected_order)
        local values=call(phase .. " array ForEach/unwrap",function() return a.values(array) end)
        assert(#values<=16,"Inspection fragment bound")
        log("REBUILD " .. phase .. " BEGIN | count=" .. #values .. " | expected=4 | pointers SKIPPED")
        local report={complete=#values==4,owned=true,original_ids=true,order={},rows={}}
        local canonical,seen={},{}
        for i,v in ipairs(values) do
            local label=phase .. " fragment " .. i
            report.order[i]="UNAVAILABLE"
            local row={}; report.rows[i]=row
            local ok,err=pcall(function()
                local f=object(v,label)
                row.id=name(f,label)
                row.class=name(call(label .. " GetClass",function() return object(f,label):GetClass() end),label .. " class")
                -- Emit each field immediately, retaining useful evidence even
                -- if a later native read fails before returning.
                log("REBUILD " .. phase .. " ITEM | index=" .. i .. " | id=" .. clean(row.id) .. " | class=" .. clean(row.class))
                row.owner=name(call(label .. " GetOwningCustomizationInstance",function()
                    return object(f,label):GetOwningCustomizationInstance()
                end),label .. " owner")
                log("REBUILD " .. phase .. " OWNER | index=" .. i .. " | actual=" .. clean(row.owner) .. " | expected=" .. s.owner)
                row.slot=name(call(label .. " GetOwningCustomizationSlot",function()
                    return object(f,label):GetOwningCustomizationSlot()
                end),label .. " slot")
                row.owned=row.owner==s.owner and row.slot==s.slot
                log("REBUILD " .. phase .. " SLOT | index=" .. i .. " | actual=" .. clean(row.slot) .. " | expected=" .. s.slot
                    .. " | owned=" .. tostring(row.owned))
                local role
                for index,suffix in ipairs(ROLES) do if row.class==PREFIX .. suffix then role=index end end
                row.role=role
                report.order[i]=role and ROLES[role] or "UNKNOWN"
                if not role or seen[role] or not row.owned then
                    report.complete=false
                    report.original_ids=false
                    if not row.owned then report.owned=false end
                    log("REBUILD " .. phase .. " PAYLOAD SKIPPED | index=" .. i .. " | unknown/duplicate class or foreign ownership")
                    return
                end
                seen[role]=true; canonical[role]=f
                local same_id=row.id==s.ids[role]
                report.original_ids=report.original_ids and same_id
                log("REBUILD " .. phase .. " IDENTITY | index=" .. i .. " | role=" .. ROLES[role]
                    .. " | original=" .. s.ids[role] .. " | same=" .. tostring(same_id))
                if role==1 then
                    local container=field(f,"GameplayTags",label)
                    local tags=call(label .. " race tags ForEach/unwrap",function() return a.values(container.GameplayTags) end)
                    assert(#tags<=16,"Race evidence bound")
                    local names={}
                    for j,t in ipairs(tags) do
                        names[j]=text(call(label .. " race TagName " .. j,function() return t.TagName end),label .. " race " .. j)
                    end
                    log("REBUILD " .. phase .. " RACE | index=" .. i .. " | tags=" .. table.concat(names,","))
                else
                    row.target=target(f,label)
                    log("REBUILD " .. phase .. " TARGET | index=" .. i .. " | " .. row.target .. " | pointers SKIPPED")
                    if role==2 then
                        local color=call(label .. " GetColor",function() return object(f,label):GetColor() end)
                        row.rgb={}
                        for _,k in ipairs({"R","G","B","A"}) do
                            local n=call(label .. " color " .. k,function() return a.prop(color,k) end)
                            assert(type(n)=="number" and n==n and n>=0 and n<=1,"Invalid RGB evidence")
                            row.rgb[k]=n
                        end
                        log(string.format("REBUILD %s RGB | index=%d | %.9f,%.9f,%.9f,%.9f",phase,i,
                            row.rgb.R,row.rgb.G,row.rgb.B,row.rgb.A))
                    elseif role==3 then
                        local n=field(f,"Value",label)
                        assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid scalar evidence")
                        log("REBUILD " .. phase .. " SCALAR | index=" .. i .. " | value=" .. n)
                    end
                end
            end)
            if not ok then
                report.complete=false
                report.owned=false; report.original_ids=false
                log("REBUILD " .. phase .. " ITEM FAILED | index=" .. i .. " | " .. clean(err))
            end
        end
        for i=1,4 do if not seen[i] then report.complete=false end end
        report.layout_match=false; report.rgb_match=false; report.swap_target_match=false
        if report.complete and report.owned then
            local ok,err=pcall(function()
                local _,_,description=call(phase .. " canonical bundle/ownership readback",function()
                    return bundles.read(canonical,{slot=SKIN})
                end)
                report.layout_match=codec.same(description,s.bundle)
                local original=assert(codec.parse(s.bundle)).originals[2]
                local current=assert(codec.parse(description)).originals[2]
                report.rgb_match=same_rgb(current,original)
                for _,row in ipairs(report.rows) do
                    if row.role==4 then report.swap_target_match=hex(row.target)==s.swap end
                end
                log("REBUILD " .. phase .. " BUNDLE | " .. description)
            end)
            if not ok then report.complete=false; log("REBUILD " .. phase .. " BUNDLE FAILED | " .. clean(err)) end
        end
        report.stock_order=table.concat(report.order,",")==table.concat(ROLES,",")
        expected_order=expected_order or (phase=="BEFORE" and table.concat(ROLES,",") or "GameplayTags,MaterialSwap,MaterialColor,MaterialScalar")
        report.order_match=table.concat(report.order,",")==expected_order
        report.verified=report.complete and report.owned and report.layout_match and report.rgb_match and report.swap_target_match
        log("REBUILD " .. phase .. " SUMMARY | count=" .. #values .. " | complete=" .. tostring(report.complete)
            .. " | owned=" .. tostring(report.owned) .. " | original_ids=" .. tostring(report.original_ids)
            .. " | layout_match=" .. tostring(report.layout_match) .. " | rgb_match=" .. tostring(report.rgb_match)
            .. " | swap_target_match=" .. tostring(report.swap_target_match) .. " | order=" .. table.concat(report.order,",")
            .. " | expected_order=" .. expected_order .. " | order_match=" .. tostring(report.order_match))
        return report -- Plain evidence; caller separately gates and journals a synchronous handoff.
    end
    return self
end
return M
