-- Preview/editor-visit face tint ownership plus the original ten-second probe.
-- Never edits a part, parent material,
-- fragment or save. Only plain identities survive between game-thread calls.
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local PARENT="MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/Human/HF00/Materials/MI_HF00_Race0B.MI_HF00_Race0B"
function M.new(runtime,a)
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local bundles=assert(loadfile(directory .. "color_bundle.lua"))()
    local self={pending=nil}
    local function log(s) runtime.log("SKIN ENABLE | " .. s) end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function lookup(n)
        local v=a.unwrap((a.find or StaticFindObject)(assert(n:match("^[^ ]+ (.+)$"))))
        if not a.live(v) then return nil end
        assert(name(v)==n,"Object identity mismatch"); return v
    end
    local function parameter(s)
        local v=FName(s); assert(a.text(v)==s,"FName round-trip failed"); return v
    end
    local function scalar(m)
        local n=object(m):K2_GetScalarParameterValue(parameter("Enable Tinting"))
        assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Unreadable scalar")
        return n
    end
    local function color(v)
        local out={}
        for _,k in ipairs({"R","G","B","A"}) do
            local n=a.prop(v,k)
            assert(type(n)=="number" and n==n and n>=0 and n<=1,"Invalid face RGBA")
            out[k]=n
        end
        assert(out.A==1,"Expected opaque face RGB")
        return out
    end
    local function vector(mid) return color(object(mid):K2_GetVectorParameterValue(parameter("Skin Coloration"))) end
    local function same(x,y)
        for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>0.00001 then return false end end
        return true
    end
    local function rgba(v) return string.format("%.6f,%.6f,%.6f,%.6f",v.R,v.G,v.B,v.A) end
    local function face_component(mesh,actor)
        local root=name(actor):match("^[^ ]+ (.+)$") .. "."
        local path=name(mesh):match("^[^ ]+ (.+)$")
        if path:sub(1,#root)~=root then return false end
        local local_name=path:sub(#root+1)
        return local_name:match("^br%.Customization%.Slot%.Character%.Appearance%.Humanoid%.Head%.Face%.Mesh_?%d*$")~=nil
            or local_name:match("^br_Customization_Slot_Character_Appearance_Humanoid_Head_Face_Mesh_?%d*$")~=nil
    end
    local function assigned_impl(p,require_visible)
        -- Component names contain gameplay-tag dots; resolving that full path
        -- can fail even while the actor still owns the live component.
        local actor=lookup(p.actor)
        if not actor then return nil,"actor unavailable" end
        local cls=object(StaticFindObject("/Script/Engine.MeshComponent"))
        assert(name(cls)=="Class /Script/Engine.MeshComponent","Invalid mesh class")
        local meshes=a.values(actor:K2_GetComponentsByClass(cls))
        assert(#meshes<=24,"Unexpected reacquisition mesh count")
        local mesh
        for _,candidate in ipairs(meshes) do
            if a.live(candidate) and name(candidate)==p.mesh then
                assert(not mesh,"Duplicate face component identity")
                mesh=object(candidate)
            end
        end
        if not mesh then return nil,"face component no longer owned" end
        assert(name(mesh:GetOwner())==p.actor,"Face component owner mismatch")
        if p.face then
            assert(face_component(mesh,actor),"Recorded face component tag changed")
            if require_visible and object(mesh):IsVisible()~=true then return nil,"recorded face component hidden" end
        end
        if mesh:GetMaterialIndex(parameter("MI_Head"))~=p.index then return nil,"MI_Head index changed" end
        local mid=a.unwrap(object(mesh):GetMaterial(p.index))
        if not a.live(mid) or name(mid)~=p.mid then return nil,"assigned face MID changed" end
        assert(name(mid:GetClass())=="Class /Script/Engine.MaterialInstanceDynamic","Material class changed")
        assert(name(mid.Parent)==(p.parent or PARENT),"Material parent changed")
        if p.face then assert(name(mid:GetOuter())==p.mesh,"Face MID outer changed") end
        return mid
    end
    local function assigned(p,require_visible)
        return timed("skin.assigned",assigned_impl,p,require_visible)
    end
    function self.stop(reason)
        runtime:cancel("skin-enable:command")
        local p=self.pending
        if not p then return true end
        local ok,err=pcall(function()
            local errors={}
            -- Restore each owned value independently: a failed RGB restore
            -- must not leave the enable switch on (or abandon RGB ownership).
            if p.original_rgb then
                local restored,why=pcall(function()
                    local mid=assigned(p)
                    if not mid then return end
                    local value=vector(mid)
                    if same(value,p.chosen_rgb) and not same(value,p.original_rgb) then
                        log("RGB RESTORE BEGIN | " .. rgba(p.original_rgb) .. " | " .. p.mid)
                        mid=assert(assigned(p),"Face retired before RGB restore")
                        assert(same(vector(mid),value),"RGB changed before restore")
                        object(mid):SetVectorParameterValue(parameter("Skin Coloration"),color(p.original_rgb))
                        mid=assigned(p)
                        if mid then assert(same(vector(mid),p.original_rgb),"RGB restore readback failed") end
                    elseif not same(value,p.original_rgb) then log("EXTERNAL CHANGE | leaving face RGB=" .. rgba(value)) end
                end)
                if not restored then errors[#errors+1]=tostring(why) end
            end
            local restored,why=pcall(function()
                local mid=assigned(p)
                if not mid then log("RETIRED | original face material no longer assigned; replacement untouched"); return end
                local value=scalar(mid)
                if value==1 then
                    log("RESTORE BEGIN | " .. p.mid)
                    mid=assert(assigned(p),"Face retired before scalar restore")
                    assert(scalar(mid)==value,"Scalar changed before restore")
                    object(mid):SetScalarParameterValue(parameter("Enable Tinting"),p.original)
                    mid=assigned(p)
                    if mid then assert(scalar(mid)==p.original,"Restore readback failed") end
                elseif value~=p.original then
                    log("EXTERNAL CHANGE | leaving scalar=" .. value)
                end
            end)
            if not restored then errors[#errors+1]=tostring(why) end
            assert(#errors==0,table.concat(errors,"; "))
            runtime:cancel("skin-enable:watch")
            runtime:cancel("skin-enable:timeout")
            self.pending=nil
        end)
        if not ok then log("RESTORE FAILED | " .. tostring(err) .. " | retry colors_skin_enable stop; Apply blocked")
        else log("STOP | " .. tostring(reason) .. " | original switch restored or material retired") end
        return ok
    end
    local function watch(p)
        runtime:after("skin-enable:watch",250,function()
            if self.pending~=p then return end
            local ok,valid=pcall(function()
                local active=runtime.picker and runtime.picker.active
                return active and runtime.tint.pending==active.session
                    and active.session.fragment==p.fragment and assigned(p,true)~=nil
            end)
            if not ok or not valid then self.stop("preview/material changed")
            else watch(p) end
        end)
    end
    function self.supports(s)
        return s and s.profile and s.profile.slot==SKIN and (s.profile.skin_scalar=="outfit"
            or type(s.part)=="string" and s.part:match("^CustomizationPartDefinition:CPD_H_SkinTone_Hum_Zabrak_[%w_]+$")
                and bundles.zabrak_face_enable(s.profile))
    end
    function self.start(mode,session,read_context)
        if runtime.skin_target and (runtime.skin_target.pending or runtime.skin_target.blocked) then
            log("REFUSED | Stop/recover colors_target first"); return false
        end
        if mode and not self.supports(session) then return true end
        if self.pending then
            if not mode or not self.pending.mode then log("Already active; stop first"); return false end
            local p=self.pending
            local ok,mid=pcall(assigned,p,true)
            if not ok then log("REACQUIRE FAILED | " .. tostring(mid)); return false end
            -- A native stock hover can reuse the same MID with a different
            -- RGB. Check its display/source mode before classifying that RGB
            -- as a foreign edit of our applied rendering ownership.
            local applied_idle=false
            if mode=="applied" and p.mode==mode and p.fragment==session.fragment and mid then
                local linked,idle=pcall(function()
                    local container=object(lookup(session.handoff.container))
                    local owner=object(lookup(session.owner))
                    local actor=object(container.ProxyCharacter)
                    return container.IsPreviewing==false and name(actor)==p.actor
                        and name(actor.ClonedFromCharacter)==name(owner:GetOwner())
                end)
                applied_idle=linked and idle
            end
            local rgb_ready=true
            if mid and p.original_rgb and (mode=="preview" or applied_idle) then
                local checked,ready=pcall(function()
                    local value=vector(mid)
                    assert(same(value,p.chosen_rgb) or same(value,p.original_rgb),"Foreign face RGB; refusing reapply")
                    assert(same(color(mode=="applied" and session.chosen or session.test_color),p.chosen_rgb),"RGB session changed without handoff")
                    return same(value,p.chosen_rgb)
                end)
                if not checked then log("RGB OWNERSHIP REFUSED | " .. tostring(ready)); return false end
                rgb_ready=ready
            end
            if mode=="preview" and p.mode==mode and p.fragment==session.fragment and mid and scalar(mid)==1 and rgb_ready then return true end
            if applied_idle and scalar(mid)==1 and rgb_ready then return true end
            if not self.stop("ownership/refresh handoff") then return false end
        end
        local ok,err=pcall(function()
            local s=session or assert(runtime.tint.pending,"No tint preview")
            if mode=="applied" then
                assert(runtime.tint.applied==s,"Applied session changed")
            else
                if not mode then
                    local active=assert(runtime.picker and runtime.picker.active,"Open CP on Skin Tone 5 first")
                    assert(s==active.session,"Picker changed")
                end
                assert(s==runtime.tint.pending and s.live and s.phase=="owned","No owned live preview")
            end
            assert(self.supports(s),"No verified parent-target skin layout")
            if not mode then assert(s.part=="CustomizationPartDefinition:CPD_H_SkinTone_Human_0B1","Manual probe remains Skin Tone 5 only") end
            assert(s.handoff,"No verified display handoff")
            local owner=mode=="applied" and object(lookup(s.owner)) or object(timed(
                read_context and "skin.resolve_bound" or "skin.resolve_context",read_context or runtime.tint.read_context).owner)
            local container=object(lookup(s.handoff.container))
            if mode=="applied" and container.IsPreviewing==true then return end -- stock hover wins
            assert(container.IsPreviewing==(mode~="applied"),"Preview mode changed")
            local actor=object(container.ProxyCharacter)
            local expected
            if mode=="applied" then
                -- Radial navigation can retire hover data. Idle applied display
                -- belongs to the verified source actor, not its preview instance.
                expected=object(owner:GetOwner())
            else
                local data=object(object(owner:GetPreviewCustomizationInstance()):GetOwner())
                assert(name(container.ProxyDataStorage)==name(data),"Preview data link changed")
                expected=data
            end
            assert(name(actor)==s.handoff.display and name(actor.ClonedFromCharacter)==name(expected),"Display link changed")
            local cls=object(StaticFindObject("/Script/Engine.MeshComponent"))
            assert(name(cls)=="Class /Script/Engine.MeshComponent","Invalid mesh class")
            local meshes=a.values(actor:K2_GetComponentsByClass(cls))
            assert(#meshes<=24,"Unexpected mesh count")
            local candidates,discovery={},{}
            local zabrak=mode and bundles.zabrak_face_enable(s.profile)
            for _,v in ipairs(meshes) do
                local mesh=object(v)
                assert(name(mesh:GetOwner())==name(actor),"Mesh owner mismatch")
                local index=mesh:GetMaterialIndex(parameter("MI_Head"))
                assert(type(index)=="number" and index%1==0 and index>=-1 and index<16,"Invalid material index")
                local face=not zabrak or face_component(mesh,actor)
                local visible=not zabrak or object(mesh):IsVisible()
                if zabrak then assert(type(visible)=="boolean","Unreadable Zabrak component visibility") end
                discovery[#discovery+1]={mesh=name(mesh),index=index,face=face,visible=visible}
                if index>=0 and face and visible then
                    local mid=object(mesh:GetMaterial(index))
                    candidates[#candidates+1]={mesh=name(mesh),actor=name(actor),mid=name(mid),index=index,
                        fragment=s.fragment,original=0,mode=mode,parent=mode and name(mid.Parent) or nil,face=zabrak==true}
                end
            end
            if #candidates~=1 then
                log("DISCOVERY FAILED | actor=" .. name(actor) .. " | meshes=" .. #meshes
                    .. " | candidates=" .. #candidates .. " | face_filter=" .. tostring(zabrak==true))
                for i,row in ipairs(discovery) do
                    log("DISCOVERY MESH | index=" .. i .. " | " .. row.mesh .. " | MI_Head=" .. row.index
                        .. " | face=" .. tostring(row.face) .. " | visible=" .. tostring(row.visible))
                    -- Read-only evidence on refusal; never guess slot 0 or
                    -- choose the first material when the name cannot resolve.
                    local ok,slots=pcall(function()
                        local names=a.values(object(meshes[i]):GetMaterialSlotNames())
                        assert(#names<=16,"Material slot diagnostic limit")
                        local out={}; for _,n in ipairs(names) do out[#out+1]=a.text(n):sub(1,128) end
                        return table.concat(out,",")
                    end)
                    log("DISCOVERY SLOTS | index=" .. i .. " | " .. (ok and slots or "<read-failed>"))
                end
            end
            assert(#candidates==1,"Expected one assigned " .. (zabrak and "visible face " or "") .. "MI_Head; candidates=" .. #candidates)
            local p=candidates[1]; local mid,why=assigned(p,true)
            assert(mid,"Face reacquisition failed: " .. tostring(why))
            local original=scalar(mid)
            assert(original==0 or original==1,"Unexpected face tint state")
            p.original=original
            if p.face then
                -- Getter zero alone does not establish a declared parameter.
                -- This rendering probe is limited to the captured global
                -- Skin Coloration parameter on the verified face MID parent.
                local rows=a.values(object(mid.Parent).VectorParameterValues)
                assert(#rows<=64,"Unexpected vector count")
                local defined=0
                for _,row in ipairs(rows) do
                    local info=a.prop(row,"ParameterInfo")
                    if a.text(a.prop(info,"Name"))=="Skin Coloration" then
                        assert(a.text(a.prop(info,"Association"))=="2" and a.prop(info,"Index")==-1,"Unexpected face vector association")
                        color(a.prop(row,"ParameterValue")); defined=defined+1
                    end
                end
                assert(defined==1,"Expected declared Skin Coloration vector")
                p.original_rgb=vector(mid)
                p.chosen_rgb=color(mode=="applied" and s.chosen or s.test_color)
            end
            if not mode then
            local parent=object(mid.Parent)
            local rows=a.values(parent.ScalarParameterValues)
            assert(#rows<=64,"Unexpected scalar count")
            local defined=0
            for _,row in ipairs(rows) do
                local info=a.prop(row,"ParameterInfo")
                if a.text(a.prop(info,"Name"))=="Enable Tinting" then
                    assert(a.text(a.prop(info,"Association"))=="2" and a.prop(info,"Index")==-1
                        and a.prop(row,"ParameterValue")==0,"Unexpected parent scalar")
                    defined=defined+1
                end
            end
            assert(defined==1 and scalar(mid)==0,"Expected disabled face tint")
            end
            self.pending=p -- record intent before any setter (including partial failures)
            if not mode then
                runtime:after("skin-enable:timeout",10000,function()
                    if self.pending==p then self.stop("10-second timeout") end
                end)
            end
            if mode~="applied" then watch(p) end -- applied uses the editor's verified source/visit watcher
            log("SET BEGIN | Enable Tinting " .. original .. " -> 1 | " .. p.mid)
            mid=assert(assigned(p,true),"Face retired before enable")
            assert(scalar(mid)==original,"Scalar changed before enable")
            object(mid):SetScalarParameterValue(parameter("Enable Tinting"),1)
            mid=assert(assigned(p,true),"Face retired after enable")
            assert(scalar(mid)==1,"Enable readback failed")
            if p.original_rgb then
                mid=assert(assigned(p,true),"Face retired before RGB handoff")
                assert(same(vector(mid),p.original_rgb),"Face RGB changed before handoff")
                log("RGB SET BEGIN | " .. rgba(p.original_rgb) .. " -> " .. rgba(p.chosen_rgb) .. " | " .. p.mid)
                object(mid):SetVectorParameterValue(parameter("Skin Coloration"),color(p.chosen_rgb))
                mid=assert(assigned(p,true),"Face retired after RGB handoff")
                assert(same(vector(mid),p.chosen_rgb),"Face RGB readback failed")
                assert(scalar(mid)==1,"Enable changed during RGB handoff")
                log("RGB VERIFIED | " .. rgba(p.chosen_rgb) .. " | " .. p.mid)
            end
            log("ACTIVE | " .. (mode or "10 seconds; Apply blocked") .. " | no asset/save writes")
        end)
        if not ok then
            log("START REFUSED/FAILED | " .. tostring(err))
            if self.pending then self.stop("start failure") end
        end
        return ok
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then return end
        runtime:console("colors_skin_enable",function(_,args)
            args=args or {}; local action=args[1] or "start"
            if #args>1 or (action~="start" and action~="stop") then log("Usage: colors_skin_enable [start|stop]"); return end
            runtime:after("skin-enable:command",1,function()
                if action=="start" then self.start() else self.stop("console") end
            end)
        end)
        log("CONSOLE READY | colors_skin_enable [start|stop] | Skin Tone 5 only")
    end
    return self
end
return M
