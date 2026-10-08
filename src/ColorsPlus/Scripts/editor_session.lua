-- Applied colors for this creator visit. Unlike the hover preview, Apply
-- writes the verified per-character source fragment. Never edits stock assets.
-- The original is journaled before mutation; exit/reload restores, never saves.
-- color_zone sequences these steps with the preview and Default selection.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local rules=assert(loadfile(directory .. "color_rules.lua"))()
local CLASS="Class /Script/BitReactorCore.CustomizationFragmentInstanceMaterialColor"
local worlds=assert(loadfile(directory .. "editor_worlds.lua"))()
local VM="^BitReactorCustomizationSlotViewModel /Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.BitReactorCustomizationSlotViewModel_%d+$"
local function copy(c) return {R=c.R,G=c.G,B=c.B,A=c.A} end
local function valid_color(c,p) return rules.color(c,p.slot,p.parameter) end
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
function M.new(runtime,a,path)
    local record
    -- blocked: a journal or restore failure retains recovery. busy: Apply or
    -- Restore is writing (the zone ignores events and refuses re-entry).
    local self={busy=false}
    local source_path=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local lifetime=assert(loadfile(source_path .. "creator_lifetime.lua"))().new(a,runtime.log)
    local target_module=assert(loadfile(source_path .. "color_target.lua"))()
    local targets=target_module.new(a)
    local fragment_module=assert(loadfile(source_path .. "color_fragments.lua"))()
    local fragments=fragment_module.new(a)
    local function log(s) runtime.log("EDITOR COLOR | " .. s) end
    self.log=log
    -- The 250ms watch reacquires the same verified objects for the whole visit.
    -- Hold the shared hook-invalidated lookup cache while an Apply is owned.
    local holder="editor:" .. tostring(path)
    local function hold_lookups(on)
        if not runtime.objects then return end
        if on then runtime.objects.hold(holder) else runtime.objects.release(holder) end
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
        assert(worlds.owner(s.owner) and s.vm:match(VM)
            and child(s.owner,s.slot,"CustomizationFragmentInstanceSlot")
            and child(s.owner,s.fragment,"CustomizationFragmentInstanceMaterialColor")
            and s.part:match("^CustomizationPartDefinition:[%w_%-]+$")
            and rules.materials(s.materials) and s.page:match("^WBP_Customization_ItemPage_C /[^\r\n]+$"),
            "Untrusted editor recovery identity")
        assert(target_module.valid(s.profile),"Invalid editor target profile")
        assert(valid_color(s.original,s.profile) and valid_color(s.chosen,s.profile) and valid_color(s.previous,s.profile)
            and s.chosen.A==s.original.A and s.previous.A==s.original.A,"Invalid editor colors")
        if s.profile.bundle then
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
            local fields={"editor-v2",s.owner,s.slot,s.fragment,s.part,s.materials,
                encoded(s.original),encoded(s.chosen),encoded(s.previous),s.page,s.vm,
                s.profile.slot,s.profile.parameter,s.profile.mesh,s.profile.asset}
            if s.profile.targets then fields[1]="editor-v3"; fields[16]=target_module.encode_targets(s.profile) end
            if s.profile.skin_race then fields[1]="editor-v4"; fields[17]=s.profile.skin_race end
            if s.profile.skin_scalar then fields[1]="editor-v5"; fields[18]=s.profile.skin_scalar end
            if s.skin_target then fields[1]="editor-v6"; fields[18]="outfit"; fields[19]=s.skin_target end
            if s.profile.bundle then
                fields[1]="editor-v7"; fields[16]=s.profile.targets and target_module.encode_targets(s.profile) or ""
                fields[17]=s.profile.bundle
                fields[18]=s.bundle_ids
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
        assert(targets.target(f,s.profile)==s.materials,"Editor materials changed")
    end
    local function source(s,repair)
        local owner=find(s.owner)
        local slot=a.unwrap(owner:GetSlotInstance({TagName=FName(s.profile.slot)}))
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
        elseif s.profile.skin_race or s.profile.bundle then
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
        targets.mesh(owner,s.profile)
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
    function self.record() return record end
    function self.hold_lookups(on) hold_lookups(on) end
    -- Reopening continues from the applied color on the same character,
    -- slot and source. read: the preview's context reader.
    function self.reopen_check(read)
        visit(record)
        local c=read()
        assert(lifetime.belongs(record.creator,c.page) and name(c.owner)==record.owner and name(c.slot)==record.vm
            and name(c.fragment)==record.fragment and same(c.original,record.chosen)
            and target_module.same(c.profile,record.profile),
            "One applied zone per visit in this test build; restore it before opening another zone")
    end
    -- Apply, step 1: the write-ahead record, journaled before any teardown.
    function self.prepare(session,read)
        assert(valid_color(session.test_color,session.profile),"Invalid Apply value")
        local c=read()
        if record then
            assert(name(c.owner)==record.owner and name(c.fragment)==record.fragment
                and name(c.slot)==record.vm and lifetime.belongs(record.creator,c.page)
                and target_module.same(c.profile,record.profile),"Applied editor target changed")
            visit(record)
        end
        local was_applied=record~=nil
        local s=record or {owner=name(c.owner),slot=name(c.source_slot),fragment=name(c.fragment),
            vm=name(c.slot),part=id(c.part.AssetId),page=c.page,materials=c.materials,original=copy(c.original),profile=c.profile}
        s.creator=s.creator or lifetime.bind(c.page)
        assert(lifetime.active(s.creator),"Creator not active")
        assert((worlds.owner(s.owner)=="hub")==(s.creator.tab~=nil),"Character belongs to the other editor")
        s.previous=copy(c.original); s.chosen=copy(session.test_color)
        if s.profile.bundle and not s.bundle_ids then
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
        persist(s)
        return s,was_applied
    end
    -- Apply, step 2 (the preview has ended): write the chosen color into the
    -- verified source fragment, refresh, and read everything back.
    function self.write(s,was_applied)
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
    end
    function self.log_applied(s)
        log("APPLIED | linear_rgba=" .. encoded(s.chosen) .. " | creator=" .. s.creator.master
            .. (s.creator.tab and " | hub editor; kept when the visit ends" or " | creator visit only; no save; restores on exit"))
    end
    -- Watch: the applied source still holds our color and the visit continues.
    -- Returns ok, error, and whether the source was changed by someone else.
    function self.check_applied(s)
        local external=false
        local ok,err=pcall(function()
            local f=source(s)
            external=not f or not same(color(f),s.chosen) or not fragments.matches(f,s.profile,s.chosen)
            assert(not external,"Applied source changed externally")
            visit(s,true)
        end)
        return ok,err,external
    end
    function self.verify_applied(s)
        visit(s)
        local f=assert(source(s),"Applied skin source replaced")
        assert(same(color(f),s.chosen),"Applied skin source changed")
    end
    function self.restore_source(s) return restore_source(s) end
    -- Hub editor: leaving the editor is the game's own commit, so an applied
    -- color is kept rather than restored. "kept" only when the verified
    -- source still holds it; otherwise a later stock edit replaced it.
    function self.keep(s)
        local f=source(s)
        if not f or not same(color(f),s.chosen) or not fragments.matches(f,s.profile,s.chosen) then return "replaced" end
        return "kept"
    end
    -- Read-only: does the game keep the color once the editor is gone?
    function self.observe_kept(s)
        for _,delay in ipairs({2000,10000}) do
            runtime:after("editor:kept-check:" .. delay,delay,function()
                local ok,result=pcall(function()
                    local f=source(s)
                    if not f then return "source replaced" end
                    local now=color(f)
                    return "rgba=" .. encoded(now) .. " | still_applied=" .. tostring(same(now,s.chosen))
                end)
                log("AFTER KEEP | +" .. (delay/1000) .. "s | " .. (ok and result or ("unreadable: " .. tostring(result))))
            end)
        end
    end
    function self.owns_context(c,s) return name(c.owner)==s.owner and name(c.slot)==s.vm end
    function self.clear() persist(nil); record=nil; self.blocked=nil; hold_lookups(false) end
    function self.fail(err)
        self.blocked=tostring(err); hold_lookups(false)
        log("RESTORE FAILED | " .. self.blocked .. " | recovery retained; do not save")
    end
    -- Reads the journal. Returns nil when recovery is blocked (the zone then
    -- reads nothing else), true when an applied record needs restoring.
    function self.start()
        local previous=io.open(path .. ".previous","r")
        if previous then
            previous:close(); self.blocked="Interrupted editor journal replacement; restart game before writes"
            log("RECOVERY BLOCKED | " .. self.blocked); return nil
        end
        local f,read_err,read_code=io.open(path,"r")
        if not f and read_code and read_code~=2 then
            self.blocked="Cannot read editor recovery: " .. tostring(read_err); log("RECOVERY BLOCKED | " .. self.blocked); return nil
        end
        if f then
            local data=f:read(32769) or ""; f:close(); data=data:gsub("\r\n","\n")
            if data~="" then
                local ok,err=pcall(function()
                    local v={}; for line in data:gmatch("([^\n]*)\n") do v[#v+1]=line end
                    assert(#data<=32768 and data:sub(-1)=="\n" and (#v==15 and v[1]=="editor-v2" or #v==16 and v[1]=="editor-v3"
                        or #v==17 and v[1]=="editor-v4" or #v==18 and v[1]=="editor-v5"
                        or #v==19 and v[1]=="editor-v6" or #v==18 and v[1]=="editor-v7"),"Malformed editor recovery")
                    local s={owner=v[2],slot=v[3],fragment=v[4],part=v[5],materials=v[6],original=parsed(v[7]),
                        chosen=parsed(v[8]),previous=parsed(v[9]),page=v[10],vm=v[11]}
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
                    validate(s); record=s
                end)
                if not ok then self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked); return nil end
            end
        end
        return record~=nil
    end
    return self
end
return M
