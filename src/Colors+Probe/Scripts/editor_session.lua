-- One opt-in Clone 8 accent for this editor visit. Unlike hover preview, Apply
-- writes the verified per-character source fragment. Never edits stock assets.
-- The original is journaled before mutation; exit/reload restores, never saves.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local rules=assert(loadfile(directory .. "color_rules.lua"))()
local ACCENT="br.Customization.Slot.Character.Outfit.Torso.Color.Secondary"
local MESH="br.Customization.Slot.Character.Outfit.Torso.Mesh"
local ARMOR="CustomizationPartDefinition:CPD_H_Outfit_Clo001_TORS_TintF"
local CLASS="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"
local OWNER="^CustomizationInstance /Game/Game/Maps/MainMenu/MainMenu%.MainMenu:PersistentLevel%.Char_Hero_Humanoid_C_%d+%.CustomizationInstance$"
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function valid_color(c,p) return rules.color(c,p and p.slot,p and p.parameter) end
local function same(x,y)
    for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>0.00001 then return false end end
    return true
end
local function encoded(c) return string.format("%.17g,%.17g,%.17g,%.17g",c.R,c.G,c.B,c.A) end
local function parsed(s)
    local r,g,b,a=s:match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
    local c={R=tonumber(r),G=tonumber(g),B=tonumber(b),A=tonumber(a)}
    assert(rules.finite(c),"Invalid editor recovery value"); return c
end
function M.wrap(runtime,a,path,base)
    local record,blocked,busy
    local source_path=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local lifetime=assert(loadfile(source_path .. "creator_lifetime.lua"))().new(a,runtime.log)
    local target_module=assert(loadfile(source_path .. "color_target.lua"))()
    local targets=target_module.new(a)
    local fragment_module=assert(loadfile(source_path .. "color_fragments.lua"))()
    local fragments=fragment_module.new(a)
    local self=setmetatable({}, {__index=function(_,k)
        if k=="blocked" then return blocked or base.blocked end
        if k=="busy" then return busy or base.busy end
        if k=="applied" then return record end
        return base[k]
    end})
    local function log(s) runtime.log("EDITOR COLOR | " .. s) end
    -- The 250ms watch reacquires the same verified objects for the whole visit.
    -- Hold the shared hook-invalidated lookup cache while an Apply is owned.
    local holder="editor:" .. tostring(path)
    local function hold_lookups(on)
        if not runtime.objects then return end
        if on then runtime.objects.hold(holder) else runtime.objects.release(holder) end
    end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local skin_source=assert(loadfile(source_path .. "skin_source_target.lua"))().new(a,log)
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Editor object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function id(v) return a.text(v.PrimaryAssetType.Name) .. ":" .. a.text(v.PrimaryAssetName) end
    local function color(f)
        local c=f:GetColor(); local result={}
        for _,k in ipairs({"R","G","B","A"}) do result[k]=a.prop(c,k) end
        assert(rules.finite(result),"Unreadable editor source value"); return result
    end
    local function list(class)
        local values=FindAllOf(class) or {}; assert(type(values)=="table","Invalid object list")
        local n=0; for _ in pairs(values) do n=n+1; assert(n<=4096,"Editor object scan limit") end
        return values
    end
    local function find(full)
        local o=(a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$"))
        if a.live(o) and name(o)==full then return o end
        for _,v in pairs(list(full:match("^([^ ]+) "))) do
            if a.live(v) and name(v)==full then return v end
        end
        error("Recorded editor object unavailable: " .. full)
    end
    local function child(owner,full,class)
        local prefix=class .. " " .. owner:match("^[^ ]+ (.+)$") .. "."
        return full:sub(1,#prefix)==prefix and not full:find("[\r\n]")
    end
    local function validate(s)
        assert(s.owner:match(OWNER) and s.vm:match(VM)
            and child(s.owner,s.slot,"CustomizationFragmentInstanceSlot")
            and child(s.owner,s.fragment,"CustomizationFragmentInstanceMaterialColor")
            and s.part:match(s.profile and "^CustomizationPartDefinition:[%w_]+$" or "^CustomizationPartDefinition:CPD_H_Outfit_Color_[%w_]+$")
            and rules.materials(s.materials) and s.page:match("^WBP_Customization_ItemPage_C /[^\r\n]+$"),
            "Untrusted editor recovery identity")
        assert(valid_color(s.original,s.profile) and valid_color(s.chosen,s.profile) and valid_color(s.previous,s.profile)
            and s.chosen.A==s.original.A and s.previous.A==s.original.A,"Invalid editor colors")
        assert(not s.profile or target_module.valid(s.profile),"Invalid editor target profile")
        if s.profile and s.profile.bundle then
            assert(type(s.bundle_ids)=="string" and #s.bundle_ids<=8192 and not s.bundle_ids:find("[\r\n]"),"Invalid editor bundle identities")
            local ids={}
            for full in s.bundle_ids:gmatch("[^|]+") do
                local class=full:match("^(CustomizationFragmentInstance[%w]+) ")
                assert(class and (class=="CustomizationFragmentInstanceMaterialColor" or class=="CustomizationFragmentInstanceMaterialScalar"
                    or class=="CustomizationFragmentInstanceMaterialSwap" or class=="CustomizationFragmentInstanceGameplayTags")
                    and child(s.owner,full,class),"Untrusted editor companion identity")
                ids[#ids+1]=full
            end
            assert(#ids>=1 and #ids<=16 and table.concat(ids,"|")==s.bundle_ids,"Invalid companion identity list")
        end
        assert(not s.skin_target or skin_source.valid(s),"Invalid skin source target intent")
    end
    local function persist(s)
        local data=""
        if s then
            validate(s)
            local fields={s.profile and "editor-v2" or "editor-v1",s.owner,s.slot,s.fragment,s.part,s.materials,
                encoded(s.original),encoded(s.chosen),encoded(s.previous),s.page,s.vm}
            if s.profile then
                fields[12],fields[13],fields[14],fields[15]=s.profile.slot,s.profile.parameter,s.profile.mesh,s.profile.asset
                if s.profile.targets then fields[1]="editor-v3"; fields[16]=target_module.encode_targets(s.profile) end
                if s.profile.skin_race then fields[1]="editor-v4"; fields[17]=s.profile.skin_race end
                if s.profile.skin_scalar then fields[1]="editor-v5"; fields[18]=s.profile.skin_scalar end
                if s.skin_target then fields[1]="editor-v6"; fields[18]="outfit"; fields[19]=s.skin_target end
                if s.profile.bundle then
                    fields[1]="editor-v7"; fields[16]=s.profile.targets and target_module.encode_targets(s.profile) or ""
                    fields[17]=s.profile.bundle
                    fields[18]=s.bundle_ids
                end
            end
            data=table.concat(fields,"\n") .. "\n"
            assert(#data<=32768,"Editor recovery size limit")
        end
        local function exists(p)
            local f,err,code=io.open(p,"r")
            if not f then assert(code==nil or code==2,"Cannot inspect editor recovery: " .. tostring(err)); return false end
            f:close(); return true
        end
        local previous=path .. ".previous"
        assert(not exists(previous),"Interrupted editor journal replacement; preserve recovery and restart game")
        local f=assert(io.open(path .. ".tmp","w"),"Cannot write editor recovery")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Cannot close editor recovery")
        local had_previous=exists(path)
        if had_previous then assert(os.rename(path,previous),"Cannot preserve editor recovery") end
        if not os.rename(path .. ".tmp",path) then
            if had_previous then os.rename(previous,path) end
            error("Cannot install editor recovery")
        end
        if had_previous then assert(os.remove(previous),"Cannot retire previous editor recovery") end
    end
    local function target(f,s)
        assert(name(f:GetClass())==CLASS and name(f:GetOwningCustomizationInstance())==s.owner
            and name(f:GetOwningCustomizationSlot())==s.slot,"Editor fragment ownership changed")
        if s.profile then
            assert(targets.target(f,s.profile)==s.materials,"Editor materials changed"); return
        end
        local t=f.MaterialTarget
        local tags=a.values(t.SlotNameTagsToApply.GameplayTags)
        assert(a.text(t.MaterialParameterName)=="Color 02" and #tags==1 and a.text(tags[1].TagName)==MESH,
            "Editor fragment target changed")
        local materials={}; for _,v in ipairs(a.values(t.MaterialSlotNames)) do materials[#materials+1]=a.text(v) end
        assert(table.concat(materials,",")==s.materials,"Editor materials changed")
    end
    local function source(s,repair)
        local owner=find(s.owner)
        local slot=a.unwrap(owner:GetSlotInstance({TagName=FName(s.profile and s.profile.slot or ACCENT)}))
        -- A verified original owner may lose this slot when its race changes.
        -- Retire the old intent without touching the new race's replacement.
        if not a.live(slot) then return nil,"replaced" end
        -- A native stock choice may replace this slot/fragment. Never recolor
        -- its replacement or adopt it just because it has the same RGB.
        if name(slot)~=s.slot or id(slot:GetCustomizationPartPrimaryAssetId())~=s.part then return nil,"replaced" end
        local values=a.values(slot:GetFragmentInstances())
        assert(#values<=16,"Editor source fragment limit")
        local contains=false
        for _,value in ipairs(values) do
            if a.live(a.unwrap(value)) and name(value)==s.fragment then contains=true end
        end
        if not contains then return nil,"replaced" end
        if s.bundle_ids and fragments.identities(values)~=s.bundle_ids then return nil,"replaced" end
        local f
        if s.skin_target then
            f=skin_source.read(values,s,repair)
            if not f then return nil,"replaced" end
        elseif s.profile and (s.profile.skin_race or s.profile.bundle) then
            f=fragments.read(values,s.profile)
            if name(f)~=s.fragment then return nil,"replaced" end
        else
            if #values~=1 or name(values[1])~=s.fragment then return nil,"replaced" end
            f=object(values[1])
        end
        target(f,s)
        return f,owner
    end
    local function visit(s,allow_transition)
        if lifetime.active(s.creator) then s.inactive_checks=0
        else
            s.inactive_checks=(s.inactive_checks or 0)+1
            assert(allow_transition and s.inactive_checks<=2,"Creator visit ended")
        end
        local owner=find(s.owner)
        if s.profile then targets.mesh(owner,s.profile)
        else
            local mesh=object(owner:GetSlotInstance({TagName=FName(MESH)}))
            assert(id(mesh:GetCustomizationPartPrimaryAssetId())==ARMOR,"Applied armor changed")
        end
        -- The recorded VM must still point to this character, even when another
        -- slot is selected. Do not bind to a newly selected character by name.
        local vm=find(s.vm); local values=a.values(vm:GetFragments())
        assert(name(fragments.read(values,s.profile))==s.fragment,"Applied slot VM changed")
    end
    local function restore_source(s)
        local f,owner=source(s,true)
        if not f then return "replaced" end
        local now=color(f)
        if not same(now,s.chosen) and not same(now,s.previous) and not same(now,s.original) then return "replaced" end
        if not fragments.owned(f,s.profile,s.chosen,s.previous,s.original) then return "replaced" end
        if s.skin_target then
            local slot=object(f:GetOwningCustomizationSlot())
            local _,scalar=skin_source.read(slot:GetFragmentInstances(),s,true)
            skin_source.write(assert(scalar,"Skin restore source replaced"),true)
        end
        if not same(now,s.original) or not fragments.matches(f,s.profile,s.original,true) then
            fragments.write(object(f),s.profile,s.original,nil,true)
            f,owner=source(s,true); assert(f,"Editor source replaced during restore setter")
            assert(same(color(f),s.original),"Editor restore readback failed")
        end
        -- Retry refresh even if a prior SetColor succeeded before refresh threw.
        object(owner):RefreshCustomization()
        local restored=assert(source(s,true),"Editor restore replaced fragment; recovery retained")
        if s.skin_target then
            local _,scalar=skin_source.read(object(restored:GetOwningCustomizationSlot()):GetFragmentInstances(),s,true)
            assert(fragments.skin_target(scalar,"Enable Tinting",true)=="outfit","Skin refresh restore target changed")
        end
        assert(same(color(restored),s.original),"Editor refresh restore readback failed")
        assert(fragments.matches(restored,s.profile,s.original,true),"Editor companion restore readback failed")
        return "restored"
    end
    local function skin_stop(reason)
        return not runtime.skin_enable or runtime.skin_enable.stop(reason)
    end
    local function skin_sync(s,mode,read_context)
        return not runtime.skin_enable or runtime.skin_enable.start(mode,s,read_context)
    end
    function self.cancel_live(reason)
        if not skin_stop(reason or "picker Cancel") then return false end
        local restored=base.restore(reason or "picker Cancel")
        if restored and record then
            local ok,err=pcall(function()
                visit(record)
                local f=assert(source(record),"Applied skin source replaced")
                assert(same(color(f),record.chosen),"Applied skin source changed")
                assert(skin_sync(record,"applied"),"Applied skin enable failed")
            end)
            if not ok then log("CANCEL DISPLAY FAILED | " .. tostring(err)); return false end
        end
        return restored
    end
    function self.restore(reason,external)
        if busy then return false end
        if not skin_stop(reason or "editor Restore") then return false end
        if not record then
            if blocked then log("RESTORE BLOCKED | " .. blocked); return false end
            return base.restore(reason)
        end
        busy=true
        local ok,err=pcall(function()
            runtime:cancel("editor:watch"); runtime:cancel("editor:recovery")
            assert(base.restore(reason),"Finish hover recovery before editor restore")
            local outcome=external and "replaced" or restore_source(record)
            if outcome=="replaced" then base.forget_selection() end
            -- Source RGB first, then any temporary Default -> stock selection.
            base.hold_selection(false)
            assert(base.restore(reason),"Finish Default selection recovery")
            if outcome=="restored" then
                local readable,c=pcall(base.read_context)
                if readable and c and name(c.owner)==record.owner and name(c.slot)==record.vm then
                    assert(base.verify_editor_display(),"Restored editor display verification failed")
                end
            end
            persist(nil); record=nil; blocked=nil; hold_lookups(false)
            log("RESTORED | " .. tostring(reason) .. (outcome=="replaced" and " | later stock edit preserved" or ""))
        end)
        busy=false
        if not ok then
            blocked=tostring(err); hold_lookups(false)
            log("RESTORE FAILED | " .. blocked .. " | recovery retained; do not save")
        end
        return ok
    end
    local function watch(s)
        hold_lookups(true)
        runtime:after("editor:watch",250,function()
            if record~=s or blocked then
                if not record or blocked then hold_lookups(false) end
                return
            end
            local external=false
            local ok,err=pcall(function()
                local f=source(s)
                external=not f or not same(color(f),s.chosen) or not fragments.matches(f,s.profile,s.chosen)
                assert(not external,"Applied source changed externally")
                visit(s,true)
            end)
            if not ok then self.restore("editor context ended/changed: " .. tostring(err),external); return end
            -- Rendering availability is not ownership of the source RGB. Keep
            -- the verified Apply through navigation gaps; never undo it solely
            -- because the preview/display object is temporarily absent.
            if not base.pending and (s.render_failures or 0)<8 then
                local rendered,result=pcall(skin_sync,s,"applied")
                if rendered and result then
                    if (s.render_failures or 0)>0 then log("DISPLAY RESUMED | applied RGB retained") end
                    s.render_failures=0
                else
                    s.render_failures=(s.render_failures or 0)+1
                    if s.render_failures==1 then log("DISPLAY WAIT | applied RGB retained; source/visit still verified") end
                    if s.render_failures==8 then
                        log("DISPLAY PAUSED | retry budget exhausted; resumes on context event; applied RGB retained; Restore before saving")
                    end
                end
            end
            watch(s)
        end)
    end
    function self.apply_live(session)
        if runtime.skin_enable and runtime.skin_enable.pending and not runtime.skin_enable.pending.mode then
            runtime.log("SKIN ENABLE | Apply blocked until temporary test is restored"); return false
        end
        if self.blocked or busy then return false end
        busy=true
        local ok,err=pcall(function()
            local healthy,why=base.check_live(session); assert(healthy,why)
            assert(valid_color(session.test_color,session.profile),"Invalid Apply value")
            local c=base.read_context()
            if record then
                assert(name(c.owner)==record.owner and name(c.fragment)==record.fragment
                    and name(c.slot)==record.vm and lifetime.belongs(record.creator,c.page)
                    and (not record.profile or target_module.same(c.profile,record.profile)),"Applied editor target changed")
                visit(record)
            end
            local was_applied=record~=nil
            local s=record or {owner=name(c.owner),slot=name(c.source_slot),fragment=name(c.fragment),
                vm=name(c.slot),part=id(c.part.AssetId),page=c.page,materials=c.materials,original=copy(c.original),profile=c.profile}
            s.creator=s.creator or lifetime.bind(c.page)
            assert(lifetime.active(s.creator),"Creator not active")
            s.previous=copy(c.original); s.chosen=copy(session.test_color)
            if s.profile and s.profile.bundle and not s.bundle_ids then
                s.bundle_ids=fragments.identities(c.source_slot:GetFragmentInstances())
            end
            if not record and skin_source.supports(s) then
                local _,values=fragments.read(c.source_slot:GetFragmentInstances(),s.profile)
                s.skin_target=name(values[3])
                local profile={}; for k,v in pairs(s.profile) do profile[k]=v end
                profile.skin_scalar=nil; s.profile=profile
            end
            validate(s)
            record=s
            s.handoff=session.handoff -- plain identities for this visit, never persisted as saved support
            persist(s) -- write-ahead intent before preview teardown/source writes
            -- Restore the hover while its source baseline is still unchanged.
            -- Keep Default's temporary editor selection until this visit ends.
            base.hold_selection(true)
            assert(skin_stop("Apply preview handoff"),"Skin preview restore failed")
            assert(base.restore("Apply: end hover preview"),"Could not end hover preview")
            local f,owner=source(s,true); assert(f,"Source replaced before Apply")
            assert(same(color(f),s.previous),"Source color changed before Apply")
            assert(fragments.matches(f,s.profile,s.previous,not was_applied),"Source companion colors changed before Apply")
            if s.skin_target then
                local _,scalar=skin_source.read(object(f:GetOwningCustomizationSlot()):GetFragmentInstances(),s,true)
                skin_source.write(assert(scalar,"Skin Apply source replaced"),false)
            end
            fragments.write(object(f),s.profile,s.chosen)
            f,owner=source(s); assert(f,"Source replaced during Apply setter")
            assert(same(color(f),s.chosen),"Apply SetColor readback failed")
            object(owner):RefreshCustomization()
            local installed=assert(source(s),"Apply refresh replaced source fragment")
            assert(same(color(installed),s.chosen),"Apply refresh color readback failed")
            assert(fragments.matches(installed,s.profile,s.chosen),"Apply companion color readback failed")
            assert(base.verify_editor_display(),"Applied display verification failed")
            assert(skin_sync(s,"applied"),"Applied face tint enable failed")
            watch(s)
            log("APPLIED | linear_rgba=" .. encoded(s.chosen) .. " | creator=" .. s.creator.master .. " | creator visit only; no save; restores on exit")
        end)
        busy=false
        if not ok then
            log("APPLY FAILED | " .. tostring(err))
            self.restore("failed editor Apply rollback")
        end
        return ok
    end
    function self.begin_live()
        if self.blocked then return nil end
        if record then
            local ok,err=pcall(function()
                visit(record)
                local c=base.read_context()
                assert(lifetime.belongs(record.creator,c.page) and name(c.owner)==record.owner and name(c.slot)==record.vm
                    and name(c.fragment)==record.fragment and same(c.original,record.chosen)
                    and (not record.profile or target_module.same(c.profile,record.profile)),
                    "One applied zone per visit in this test build; restore it before opening another zone")
            end)
            if not ok then log("OPEN REFUSED | " .. tostring(err)); return nil end
        end
        if not skin_stop("opening skin draft") then return nil end
        local s=base.begin_live()
        if s and record and not base.update_live(s,record.chosen) then return nil end
        if s and not skin_sync(s,"preview") then self.cancel_live("skin preview enable failed"); return nil end
        if s then s.preview_policy=target_module.preview_policy(s.profile) end
        return s
    end
    function self.update_live(s,chosen)
        if not timed("update.skin_stop",skin_stop,"RGB update") then return false end
        local ok
        if s.profile and s.profile.slot=="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
            and type(base.update_live_scoped)=="function" then
            ok=base.update_live_scoped(s,chosen,function(read_context)
                return timed("update.skin_enable",skin_sync,s,"preview",read_context)
            end)
        else
            if not base.update_live(s,chosen) then return false end
            ok=timed("update.skin_enable",skin_sync,s,"preview")
        end
        -- base.update_live verifies context before writing and verifies the
        -- result; skin_sync must also succeed before issuing this receipt.
        return ok,ok==true
    end
    function self.check_live(s)
        local ok,why=base.check_live(s)
        if not ok then return ok,why end
        return skin_sync(s,"preview"),"Skin preview enable failed"
    end
    function self.context_changed(reason,identity)
        if busy then return end
        if record then record.render_failures=0 end -- event-driven retry after a bounded display wait
        if reason=="creator closed" then
            if identity and record and record.creator and identity~=record.creator.master then return end
            self.restore(reason); return
        end
        if reason=="page closed" then
            -- Discard an open draft, but do not undo an already-applied source
            -- color just because the user returned to the radial slot selector.
            base.restore("item page closed")
            if record then log("RETAINED | item page closed; waiting for creator navigation") end
            return
        end
        base.context_changed(reason)
        -- The watcher checks the original source independently of selected slot.
        -- No reapplication loop: later stock edits win.
    end
    function self.start()
        local previous=io.open(path .. ".previous","r")
        if previous then
            previous:close(); blocked="Interrupted editor journal replacement; restart game before writes"
            log("RECOVERY BLOCKED | " .. blocked); return
        end
        local f,read_err,read_code=io.open(path,"r")
        if not f and read_code and read_code~=2 then
            blocked="Cannot read editor recovery: " .. tostring(read_err); log("RECOVERY BLOCKED | " .. blocked); return
        end
        if f then
            local data=f:read(32769) or ""; f:close(); data=data:gsub("\r\n","\n")
            if data~="" then
                local ok,err=pcall(function()
                    local v={}; for line in data:gmatch("([^\n]*)\n") do v[#v+1]=line end
                    assert(#data<=32768 and data:sub(-1)=="\n" and (#v==11 and v[1]=="editor-v1"
                        or #v==15 and v[1]=="editor-v2" or #v==16 and v[1]=="editor-v3"
                        or #v==17 and v[1]=="editor-v4" or #v==18 and v[1]=="editor-v5"
                        or #v==19 and v[1]=="editor-v6" or #v==18 and v[1]=="editor-v7"),"Malformed editor recovery")
                    local s={owner=v[2],slot=v[3],fragment=v[4],part=v[5],materials=v[6],original=parsed(v[7]),
                        chosen=parsed(v[8]),previous=parsed(v[9]),page=v[10],vm=v[11]}
                    if v[1]=="editor-v2" or v[1]=="editor-v3" or v[1]=="editor-v4" or v[1]=="editor-v5" or v[1]=="editor-v6" or v[1]=="editor-v7" then
                        s.profile={slot=v[12],parameter=v[13],mesh=v[14],asset=v[15]}
                        if v[1]=="editor-v7" then
                            s.profile.bundle=v[17]
                            s.bundle_ids=v[18]
                            assert(v[16]=="" or target_module.decode_targets(s.profile,v[16]),"Invalid bundle mesh recovery")
                        end
                        if v[1]=="editor-v4" or v[1]=="editor-v5" or v[1]=="editor-v6" then
                            assert(fragment_module.valid_race(v[17]),"Invalid skin recovery race tag")
                            s.profile.skin_race=v[17]
                        end
                        if v[1]=="editor-v5" then
                            assert(v[18]=="outfit","Invalid skin scalar recovery layout")
                            s.profile.skin_scalar=v[18]
                        end
                        if v[1]=="editor-v6" then
                            assert(v[18]=="outfit","Invalid skin source original layout")
                            s.skin_target=v[19]
                        end
                        if v[1]=="editor-v3" or v[1]=="editor-v4" or v[1]=="editor-v5" or v[1]=="editor-v6" then
                            assert(target_module.decode_targets(s.profile,v[16]),"Invalid multi-mesh recovery")
                        end
                    end
                    validate(s); record=s; base.hold_selection(true)
                end)
                if not ok then blocked=tostring(err); log("RECOVERY BLOCKED | " .. blocked); return end
            end
        end
        base.start()
        if record then runtime:after("editor:recovery",25,function() self.restore("reload recovery") end) end
    end
    for _,key in ipairs({"apply","apply_rgb","cycle_rgb"}) do
        self[key]=function(...)
            if record or self.blocked then log("ACTION REFUSED | Restore editor Apply first"); return false end
            return base[key](...)
        end
    end
    return self
end
return M
