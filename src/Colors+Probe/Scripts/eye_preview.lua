-- Temporary DISPLAY-only MID parameters. No source fragments, stock assets,
-- material swaps, equip, refresh or save calls. Scalar identities across jobs.
local M={}
local PARAMETERS={IrisColor1=true,IrisColor2=true,CloudyIrisColor=true}
local SCALARS={IrisSaturation=true,IrisBrightness=true}
local TEXTURE_PRESETS={
    ["CustomizationPartDefinition:CPD_H_Eyes_Brown_02"]="MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/_Eyes/MI_Eyes_Brown_02.MI_Eyes_Brown_02",
    ["CustomizationPartDefinition:CPD_H_Eyes_Rodian_03"]="MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/Rodian/Rod_R01/Materials/MI_Rod_R01_Eyes_Star02.MI_Rod_R01_Eyes_Star02",
}
local function scalar(v)
    assert(type(v)=="number" and v==v and v>=0 and v<=64,"Invalid eye scalar")
    return v
end
local MID="Class /Script/Engine.MaterialInstanceDynamic"
local FACE="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.Mesh"
local function color(v)
    local out={}
    for _,k in ipairs({"R","G","B","A"}) do
        local n=v and v[k]
        assert(type(n)=="number" and n==n and math.abs(n)<=64,"Invalid eye RGBA")
        out[k]=n
    end
    return out
end
local function equal(x,y)
    if type(x)=="number" or type(y)=="number" then
        return type(x)=="number" and type(y)=="number" and math.abs(x-y)<=0.00001
    end
    for _,k in ipairs({"R","G","B","A"}) do if math.abs(x[k]-y[k])>0.00001 then return false end end
    return true
end
local function encode(v)
    if type(v)=="number" then return string.format("%.9g",scalar(v)) end
    return string.format("%.9g,%.9g,%.9g,%.9g",v.R,v.G,v.B,v.A)
end
local function decode(v,parameter)
    if SCALARS[parameter] then return scalar(tonumber(v)) end
    local parts={}; for s in (v .. ","):gmatch("([^,]*),") do parts[#parts+1]=tonumber(s) or false end
    assert(#parts==4,"Invalid eye RGBA record")
    return color({R=parts[1],G=parts[2],B=parts[3],A=parts[4]})
end
function M.new(runtime,a,path,resolve_context)
    local self={pending=nil,blocked=nil,busy=false}
    local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
    local handoff=assert(loadfile(directory .. "display_handoff.lua"))()
    resolve_context=resolve_context or assert(loadfile(directory .. "eye_target.lua"))().new(runtime,a).resolve
    local function log(s) runtime.log("EYE PREVIEW | " .. s) end
    local function object(v) v=a.unwrap(v); assert(a.live(v),"Eye object unavailable"); return v end
    local function name(v) return a.name(object(v)) end
    local function find(full)
        local v=StaticFindObject(full:match("^[^ ]+ (.+)$"))
        if a.live(v) then assert(name(v)==full,"Eye lookup identity mismatch"); return v end
        -- StaticFindObject can miss live components. Confirm absence with a
        -- bounded exact-name component scan before declaring a target retired.
        -- Never scan materials or adopt a similarly named replacement.
        local count,found=0,nil
        for _,candidate in pairs(FindAllOf("SkeletalMeshComponent") or {}) do
            count=count+1; assert(count<=4096,"Eye recovery component scan limit")
            if a.live(candidate) and name(candidate)==full then
                assert(not found,"Ambiguous eye recovery mesh"); found=candidate
            end
        end
        return found
    end
    local fname=assert(loadfile(directory .. "eye_names.lua"))().new(a,runtime.log)
    local function validate(s)
        assert(handoff.valid_record(s.container,s.display) and #s.rows>=1 and #s.rows<=4,"Invalid eye recovery target")
        local display_path=assert(s.display:match("^[^ ]+ (.+)$"))
        local prefix="SkeletalMeshComponent " .. display_path .. "." .. FACE .. "_"
        local seen={}
        for _,r in ipairs(s.rows) do
            assert(r.component:sub(1,#prefix)==prefix and r.component:sub(#prefix+1):match("^%d+$"),"Invalid eye mesh identity")
            local mp="MaterialInstanceDynamic " .. r.component:match("^[^ ]+ (.+)$") .. "."
            assert(r.mid:sub(1,#mp)==mp and r.mid:sub(#mp+1):match("^[%w_]+$"),"Invalid eye MID identity")
            assert(r.parent:match("^MaterialInstanceConstant /Game/Game/Characters/Humanoid/_Heads/[%w_/.]+$"),"Invalid eye preset identity")
            assert(r.index>=0 and r.index<32 and r.index%1==0 and (r.slot=="MI_EyeLeft" or r.slot=="MI_EyeRight" or r.slot=="MI_Eyes")
                and (PARAMETERS[r.parameter] or SCALARS[r.parameter]),"Invalid eye parameter target")
            assert((SCALARS[r.parameter] or false)==(SCALARS[s.rows[1].parameter] or false),"Mixed eye recovery kinds")
            local key=r.component .. ":" .. r.index .. ":" .. r.parameter
            assert(not seen[key],"Duplicate eye recovery row"); seen[key]=true
            if SCALARS[r.parameter] then
                local allowed=false
                for _,parent in pairs(TEXTURE_PRESETS) do if r.parent==parent then allowed=true end end
                assert(allowed,"Unverified texture-control preset")
                scalar(r.original); scalar(r.chosen); scalar(r.previous)
            else color(r.original); color(r.chosen); color(r.previous) end
        end
    end
    local function exists(p)
        local f,err,code=io.open(p,"r")
        if not f then assert(code==2,"Cannot read eye recovery: " .. tostring(err)); return false end
        f:close(); return true
    end
    local function persist(s)
        local data=""
        if s then
            validate(s)
            local fields={SCALARS[s.rows[1].parameter] and "eye-scalar-v1" or "eye-v1",s.container,s.display,tostring(#s.rows)}
            for _,r in ipairs(s.rows) do
                for _,v in ipairs({r.component,r.mid,r.parent,tostring(r.index),r.slot,r.parameter,
                    encode(r.original),encode(r.chosen),encode(r.previous)}) do fields[#fields+1]=v end
            end
            data=table.concat(fields,"\n") .. "\n"
        end
        assert(not exists(path .. ".previous"),"Interrupted eye journal replacement; restart the game")
        local f=assert(io.open(path .. ".tmp","w"),"Cannot write eye recovery")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Eye journal close failed")
        local had=exists(path)
        if had then assert(os.rename(path,path .. ".previous"),"Cannot preserve eye recovery") end
        if not os.rename(path .. ".tmp",path) then
            if had then os.rename(path .. ".previous",path) end
            error("Cannot install eye recovery")
        end
        if had then assert(os.remove(path .. ".previous"),"Cannot retire previous eye recovery") end
    end
    local function material(s,r)
        local component=find(r.component)
        if not component then return nil,"mesh retired" end
        assert(name(component:GetOwner())==s.display,"Eye mesh owner changed")
        assert(component:GetMaterialIndex(fname(r.slot))==r.index,"Eye slot ordering changed")
        local mid=a.unwrap(component:GetMaterial(r.index))
        if not a.live(mid) or name(mid)~=r.mid then return nil,"material replaced by game" end
        assert(name(mid:GetClass())==MID and name(mid:GetOuter())==r.component and name(mid.Parent)==r.parent,
            "Eye MID ownership/parent changed")
        return mid
    end
    local function read(mid,r)
        if SCALARS[r.parameter] then return scalar(object(mid):K2_GetScalarParameterValue(fname(r.parameter))) end
        return color(object(mid):K2_GetVectorParameterValue(fname(r.parameter)))
    end
    local function write(mid,r,value)
        if SCALARS[r.parameter] then object(mid):SetScalarParameterValue(fname(r.parameter),scalar(value))
        else object(mid):SetVectorParameterValue(fname(r.parameter),color(value)) end
    end
    function self.stop(reason)
        runtime:cancel("eyes:stage"); runtime:cancel("eyes:watch"); runtime:cancel("eyes:event")
        runtime:cancel("eyes:timeout"); runtime:cancel("eyes:recovery")
        local s=self.pending
        if not s then return not self.blocked end
        self.busy=true
        local ok,err=pcall(function()
            validate(s)
            for _,r in ipairs(s.rows) do
                local mid,why=material(s,r)
                if mid then
                    local current=read(mid,r)
                    if equal(current,r.original) then -- already restored, including partial retries
                    elseif equal(current,r.chosen) or equal(current,r.previous) then
                        write(mid,r,r.original)
                        assert(equal(read(mid,r),r.original),"Eye restore readback failed")
                    else log("EXTERNAL CHANGE | leave " .. r.parameter .. " unchanged") end
                else log("RETIRED | " .. why) end
            end
            persist(nil); self.pending=nil; self.blocked=nil
        end)
        self.busy=false
        if not ok then self.blocked=tostring(err); log("RESTORE FAILED | " .. self.blocked .. " | restart if retry fails")
        else log("RESTORED | " .. (reason or "stop") .. " | no source/save writes") end
        return ok
    end
    local function verify(s)
        assert(self.pending==s and not self.blocked,"Eye session inactive")
        local c=resolve_context(s.mode)
        assert(c.signature==s.signature,"Eye page/preset/display changed")
        for _,r in ipairs(s.rows) do
            local mid=assert(material(s,r),"Eye material replaced")
            assert(equal(read(mid,r),r.chosen),"Eye parameter changed externally")
        end
    end
    local function stage(s,n)
        verify(s)
        local selected=n==1 and s.parameters[1] or n==3 and s.parameters[#s.parameters] or nil
        for _,r in ipairs(s.rows) do
            r.previous=r.chosen
            if selected==r.parameter and SCALARS[r.parameter] then
                r.chosen=n==1 and 0 or r.original*0.25
            else
                r.chosen=selected==r.parameter and (n==1 and {R=0,G=1,B=1,A=r.original.A}
                    or {R=1,G=0,B=1,A=r.original.A}) or r.original
            end
        end
        persist(s) -- durable previous/new values before the first setter
        for _,r in ipairs(s.rows) do
            local mid=assert(material(s,r),"Eye material replaced before setter")
            assert(equal(read(mid,r),r.previous),"Eye parameter changed before setter")
            write(mid,r,r.chosen)
            assert(equal(read(mid,r),r.chosen),"Eye setter readback failed")
            log("PARAMETER | " .. r.slot .. " | " .. r.parameter .. "=" .. encode(r.chosen))
        end
        log("STAGE " .. n .. " | " .. (selected or "original colors") .. " | 5 seconds; visual confirmation required")
        runtime:after("eyes:stage",5000,function()
            if self.pending~=s or self.blocked then return end
            if n==4 then self.stop("20-second cycle complete"); return end
            local ok,err=pcall(stage,s,n+1)
            if not ok then log("CYCLE STOP | " .. tostring(err)); self.stop("stage failure") end
        end)
    end
    local function watch(s)
        runtime:after("eyes:watch",250,function()
            if self.pending~=s or self.blocked then return end
            local ok,err=pcall(verify,s)
            if not ok then log("CONTEXT STOP | " .. tostring(err)); self.stop("context changed")
            else watch(s) end
        end)
    end
    function self.begin(mode)
        if runtime.skin_target and (runtime.skin_target.pending or runtime.skin_target.blocked) then
            log("REFUSED | Stop/recover colors_target first"); return false
        end
        if self.pending or self.blocked then log("REFUSED | Stop/recover the previous eye test first"); return false end
        if runtime.tint and (runtime.tint.pending or runtime.tint.applied or runtime.tint.blocked)
            or runtime.picker and runtime.picker.active
            or runtime.stock_call_trace and runtime.stock_call_trace.window then
            log("REFUSED | Restore CP / stop stock tracing before testing eyes"); return false
        end
        self.busy=true
        local ok,err=pcall(function()
            assert(mode==nil or mode=="start" or mode=="texture","Unsupported eye test mode")
            local c=resolve_context(mode)
            if mode=="texture" then assert(TEXTURE_PRESETS[c.asset],"Texture controls: select Light Brown or Rodian Star Blue") end
            local parameters=mode=="texture" and {"IrisSaturation","IrisBrightness"}
                or c.rows[1].parameters.CloudyIrisColor and {"CloudyIrisColor"} or {"IrisColor1","IrisColor2"}
            local s={container=c.container,display=c.display,signature=c.signature,parameters=parameters,rows={},mode=mode}
            for _,target in ipairs(c.rows) do
                if mode=="texture" then assert(target.parent==TEXTURE_PRESETS[c.asset],"Texture-control material/preset mismatch") end
                for _,parameter in ipairs(parameters) do
                    local available=mode=="texture" and target.scalars or target.parameters
                    assert(available and available[parameter],"Preset has no explicit " .. parameter .. " override; not guessing support")
                    local r={component=target.component,mid=target.mid,parent=target.parent,index=target.index,slot=target.slot,parameter=parameter}
                    local mid=assert(material(s,r),"Eye target unavailable")
                    r.original=read(mid,r); r.previous=r.original; r.chosen=r.original
                    if SCALARS[parameter] then assert(r.original>0.0001,"Eye scalar baseline too small for a visible test") end
                    s.rows[#s.rows+1]=r
                end
            end
            validate(s); persist(s); self.pending=s
            log("BEGIN | " .. c.asset .. " | mode=" .. (mode or "start") .. " | display-only MID probe; no Apply/save")
            stage(s,1); watch(s)
            runtime:after("eyes:timeout",20000,function()
                if self.pending==s then self.stop("20-second safety timeout") end
            end)
        end)
        self.busy=false
        if not ok then log("REFUSED/FAILED | " .. tostring(err)); if self.pending then self.stop("start failure") end end
        return ok
    end
    function self.context_changed(reason)
        if self.busy or not self.pending then return end
        local s=self.pending
        runtime:after("eyes:event",1,function()
            if self.pending==s then self.stop("native event: " .. tostring(reason)) end
        end)
    end
    function self.start()
        -- The process-session gate in main must run before reading this record.
        local ok,err=pcall(function()
            assert(runtime.process_session,"No process-authorized eye recovery")
            assert(not exists(path .. ".previous"),"Interrupted eye journal replacement; restart game")
            if not exists(path) then return end
            local f=assert(io.open(path,"r")); local data=f:read(16385) or ""; f:close()
            if data=="" then return end
            data=data:gsub("\r\n","\n"); assert(#data<=16384 and data:sub(-1)=="\n","Invalid eye journal size")
            local lines={}; for line in data:gmatch("([^\n]*)\n") do lines[#lines+1]=line end
            local count=tonumber(lines[4]); assert((lines[1]=="eye-v1" or lines[1]=="eye-scalar-v1") and count and count%1==0 and count>=1 and count<=4
                and #lines==4+count*9,"Invalid eye recovery format")
            local s={container=lines[2],display=lines[3],rows={}}
            for i=1,count do
                local n=4+(i-1)*9
                local parameter=lines[n+6]
                assert((lines[1]=="eye-scalar-v1" and SCALARS[parameter]) or (lines[1]=="eye-v1" and PARAMETERS[parameter]),
                    "Eye recovery parameter kind mismatch")
                s.rows[i]={component=lines[n+1],mid=lines[n+2],parent=lines[n+3],index=assert(tonumber(lines[n+4])),
                    slot=lines[n+5],parameter=parameter,original=decode(lines[n+7],parameter),chosen=decode(lines[n+8],parameter),previous=decode(lines[n+9],parameter)}
            end
            validate(s); self.pending=s
            runtime:after("eyes:recovery",25,function()
                if self.pending==s then self.stop("reload recovery") end
            end)
        end)
        if not ok then self.blocked=tostring(err); log("RECOVERY BLOCKED | " .. self.blocked) end
    end
    function self.attach()
        if type(RegisterConsoleCommandHandler)~="function" then return end
        runtime:console("colors_eyes",function(_,parameters,output)
            parameters=parameters or {}; local action=tostring(parameters[1] or "start"):lower()
            local message="Usage: colors_eyes [start|texture|stop]"
            if #parameters<=1 and (action=="start" or action=="texture" or action=="stop") then
                runtime:after("eyes:command",1,function()
                    if action=="stop" then self.stop("console stop") else self.begin(action) end
                end)
                message="Queued eye " .. action .. "; close the console. No Apply/save."
            end
            log(message); if output then pcall(function() output:Log(message) end) end
        end)
        log("Ready: colors_eyes [start|texture|stop] | 5-second stages, 20-second timeout")
    end
    return self
end
return M
