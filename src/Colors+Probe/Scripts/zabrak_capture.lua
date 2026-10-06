-- Proven read-only Zabrak capture; no hard/soft material-reference reads.
-- Returns plain source identities, bundle and target-only evidence.
local M={}
function M.new(runtime,a)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\\\])")
    local codec=assert(loadfile(directory .. "color_bundle.lua"))()
    local self={pending=nil,blocked=nil,busy=false}
    local serial=0
    local function log(s) runtime.log("ZABRAK DISPATCH | " .. s) end
    local function clean(s) return tostring(s):gsub("[\r\n\t]"," "):sub(1,512) end
    local function capture()
        assert(not self.busy and not self.blocked,"Capture blocked; restart without saving")
        assert(runtime.tint and not (runtime.tint.pending or runtime.tint.applied or runtime.tint.blocked),"Restore all CP colors first")
        assert(not (runtime.picker and runtime.picker.active),"Close CP first")
        assert(not runtime.skin_target or not (runtime.skin_target.pending or runtime.skin_target.blocked),"Stop other source test")
        for _,key in ipairs({"skin_enable","eye_preview"}) do
            local other=runtime[key]
            assert(not other or not (other.pending or other.blocked),"Restore other display preview first")
        end
        assert(not (runtime.stock_call_trace and runtime.stock_call_trace.window),"Stop stock trace first")
        serial=serial+1
        local run,calls=serial,0
        self.busy=true
        local function trace(label,fn)
            calls=calls+1
            assert(calls<=128,"Capture call bound")
            local prefix="CAPTURE TRACE | run=" .. run .. " | call=" .. calls .. " | "
            log(prefix .. "BEGIN | " .. label)
            local ok,result=pcall(fn)
            if not ok then
                log(prefix .. "ERROR | " .. label .. " | " .. clean(result))
                error(result,0)
            end
            -- Never stringify return values: some are reflected userdata.
            log(prefix .. "RETURN | " .. label)
            return result
        end
        local function live(v,label)
            v=trace(label .. " unwrap",function() return a.unwrap(v) end)
            assert(trace(label .. " IsValid",function() return a.live(v) end),"Source object unavailable: " .. label)
            return v
        end
        local function identity(v,label)
            v=live(v,label)
            local n=trace(label .. " GetFullName",function() return a.name(v) end)
            assert(type(n)=="string" and #n<=2048,"Invalid source identity")
            return n
        end
        log("CAPTURE BEGIN | run=" .. run .. " | READ ONLY")
        local ok,result=pcall(function()
            -- Existing picker resolver is traced as a helper boundary. Its
            -- internal calls are not individually traced by this module.
            local c=trace("tint.read_context",runtime.tint.read_context)
            assert(c.profile and codec.zabrak_face_enable(c.profile),"Select captured Zabrak skin (Skin Tone 8)")
            local slot=live(c.source_slot,"source slot")
            local fragments=trace("source slot GetFragmentInstances",function()
                return live(slot,"source slot before getter"):GetFragmentInstances()
            end)
            local values=trace("fragment array ForEach/unwrap",function() return a.values(fragments) end)
            assert(#values==4,"Source bundle count changed")
            local s={owner=identity(c.owner,"owner"),slot=identity(slot,"source slot"),bundle=c.profile.bundle,ids={}}
            local id=trace("part AssetId",function() return c.part.AssetId end)
            local primary=trace("AssetId PrimaryAssetType",function() return id.PrimaryAssetType end)
            local type_name=trace("PrimaryAssetType Name",function() return primary.Name end)
            local type_text=trace("PrimaryAssetType FName ToString",function() return a.text(type_name) end)
            local part_name=trace("AssetId PrimaryAssetName",function() return id.PrimaryAssetName end)
            local part_text=trace("PrimaryAssetName FName ToString",function() return a.text(part_name) end)
            s.part=type_text .. ":" .. part_text
            assert(s.part:match("^CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_[%w_]+$"),"Unsupported Zabrak part")
            for i,f in ipairs(values) do s.ids[i]=identity(f,"fragment " .. i) end
            -- Capture the swap target, but deliberately do NOT access either
            -- ReplacementMaterial property (hard or soft pointer).
            local swap=live(values[4],"swap fragment")
            local target=trace("swap MaterialTarget",function() return live(swap,"swap before target").MaterialTarget end)
            local parameter=trace("swap target MaterialParameterName",function() return target.MaterialParameterName end)
            s.parameter=trace("swap target parameter FString ToString",function() return a.text(parameter) end)
            local container=trace("swap target SlotNameTagsToApply",function() return target.SlotNameTagsToApply end)
            local tag_array=trace("swap target GameplayTags",function() return container.GameplayTags end)
            local tags=trace("swap target tag array ForEach/unwrap",function() return a.values(tag_array) end)
            assert(#tags>=1 and #tags<=16,"Swap tag bounds")
            s.tags={}
            for i,t in ipairs(tags) do
                local tag=trace("swap tag " .. i .. " TagName",function() return t.TagName end)
                s.tags[i]=trace("swap tag " .. i .. " FName ToString",function() return a.text(tag) end)
            end
            local material_array=trace("swap target MaterialSlotNames",function() return target.MaterialSlotNames end)
            local materials=trace("swap material array ForEach/unwrap",function() return a.values(material_array) end)
            assert(#materials<=16,"Swap material bounds")
            s.materials={}
            for i,n in ipairs(materials) do
                s.materials[i]=trace("swap material slot " .. i .. " FName ToString",function() return a.text(n) end)
            end
            log("CAPTURE | run=" .. run .. " | READ ONLY | part=" .. s.part .. " | owner=" .. s.owner
                .. " | slot=" .. s.slot .. " | bundle=" .. s.bundle)
            for i,n in ipairs(s.ids) do log("CAPTURE ID | run=" .. run .. " | index=" .. i .. " | " .. n) end
            log("CAPTURE SWAP TARGET | parameter=" .. s.parameter .. " | tags=" .. table.concat(s.tags,",")
                .. " | materials=" .. table.concat(s.materials,",") .. " | hard/soft material references SKIPPED")
            local description=table.concat({s.parameter,table.concat(s.tags,","),table.concat(s.materials,",")},"|")
            assert(#description<=4096,"Swap evidence bounds")
            s.swap=(description:gsub(".",function(ch) return string.format("%02x",ch:byte()) end))
            log("CAPTURE COMPLETE | run=" .. run .. " | calls=" .. calls .. " | NO WRITES / NO REFRESH")
            return s
        end)
        self.busy=false
        if not ok then log("CAPTURE FAILED | run=" .. run .. " | " .. clean(result)) end
        return ok and result or nil
    end
    function self.capture()
        local ok,result=pcall(capture)
        if not ok then log("CAPTURE REFUSED | " .. clean(result)); return false end
        return result
    end
    return self
end
return M
