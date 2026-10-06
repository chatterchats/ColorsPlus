-- Session-owned bounded aggregate diagnostics. No native calls, hooks, per-input IO,
-- or retained function results. os.clock is a platform-dependent clock, NOT
-- a promise of frame/GPU/wall timing (CPU time on some Lua implementations).
local M={}
local unpack_values=assert(table.unpack or unpack)
local function pack(...) return {n=select("#",...),...} end
function M.new(runtime,options)
    options=options or {}
    local clock=options.clock or os.clock
    -- Bounded headroom for validation substages alongside opening/UI timings.
    local limit=options.limit or 192
    local self={window=nil}
    local serial=0
    local sample
    local function emit(lines)
        if options.sink then
            local ok=pcall(options.sink,lines)
            if ok then return end
        end
        for _,line in ipairs(lines) do runtime.log(line) end
    end
    local function label(s)
        return tostring(s):gsub("zone%d+:","zone:"):gsub("panel%-client:%d+","panel-client:poll")
            :gsub("snapshot:aux:.*","snapshot:aux"):gsub("snapshot:slot:.*","snapshot:slot")
            :gsub("[\r\n\t]"," "):sub(1,120)
    end
    local function record(w,name,ms,failed)
        if self.window~=w or ms<0 or ms~=ms then return end
        name=label(name)
        local row=w.rows[name]
        if not row then
            if w.labels>=limit then w.dropped=w.dropped+1; return end
            row={n=0,total=0,max=0,slow=0,ge50=0,ge100=0,ge250=0,errors=0}; w.rows[name]=row; w.labels=w.labels+1
        end
        row.n=row.n+1; row.total=row.total+ms; row.max=math.max(row.max,ms)
        if ms>=16 then row.slow=row.slow+1 end
        if ms>=50 then row.ge50=row.ge50+1 end
        if ms>=100 then row.ge100=row.ge100+1 end
        if ms>=250 then row.ge250=row.ge250+1 end
        if failed then row.errors=row.errors+1 end
    end
    -- One sample covers one synchronous picker tick, not elapsed user time.
    -- Classify after reading input so the first changing tick is not called idle.
    -- Only scalars are retained; no additional native reads or per-tick writes.
    function self.picker_sample(fn,...)
        local w=self.window
        if not w then return fn(...) end
        local previous=sample
        local current={window=w,activity="unclassified"}; sample=current
        local start=clock()
        local result=pack(pcall(fn,...))
        sample=previous
        record(w,"picker.sample." .. current.activity,(clock()-start)*1000,not result[1])
        if not result[1] then error(result[2],0) end
        return unpack_values(result,2,result.n)
    end
    function self.picker_activity(editing)
        if sample and sample.window==self.window then sample.activity=editing and "editing" or "idle" end
    end
    function self.measure(name,fn,...)
        local w=self.window
        if not w then return fn(...) end
        local start=clock()
        local result=pack(pcall(fn,...))
        record(w,name,(clock()-start)*1000,not result[1])
        if not result[1] then error(result[2],0) end
        return unpack_values(result,2,result.n)
    end
    function self.queue(name,delay)
        local w=self.window
        if not w then return end
        return {window=w,name=label(name),due=clock()+delay/1000}
    end
    function self.dispatch(ticket)
        if ticket and ticket.window==self.window then
            record(ticket.window,"queue_clock_late." .. ticket.name,math.max(0,(clock()-ticket.due)*1000))
        end
    end
    function self.report(reason)
        local w=self.window
        if not w then return end
        local names={}
        for name in pairs(w.rows) do names[#names+1]=name end
        table.sort(names,function(a,b) return w.rows[a].total>w.rows[b].total end)
        local lines={string.format("PERF | window=%d | %s | interval | labels=%d dropped=%d | inclusive os.clock ms; nested totals overlap",
            w.id,label(reason or "report"),#names,w.dropped)}
        for _,name in ipairs(names) do
            local row=w.rows[name]
            lines[#lines+1]=string.format("PERF | window=%d | %s | n=%d avg_ms=%.3f max_ms=%.3f total_ms=%.3f ge16ms=%d errors=%d ge50ms=%d ge100ms=%d ge250ms=%d",
                w.id,name,row.n,row.total/row.n,row.max,row.total,row.slow,row.errors,row.ge50,row.ge100,row.ge250)
        end
        local objects=runtime.objects
        if objects and w.object_hits then
            -- Scalar counters only; misses are full-path StaticFindObject calls.
            lines[#lines+1]=string.format("PERF | window=%d | object_cache | hits=%d misses=%d active=%s",
                w.id,objects.hits-w.object_hits,objects.misses-w.object_misses,tostring(objects.active()))
            w.object_hits,w.object_misses=objects.hits,objects.misses
        end
        emit(lines)
        w.rows={}; w.labels=0; w.dropped=0
    end
    function self.stop(reason)
        local w=self.window
        if not w then return end
        self.report(reason or "stop"); self.window=nil
        runtime:cancel("perf:summary"); runtime:cancel("perf:expiry")
        emit({string.format("PERF | window=%d | STOP | reason=%s | elapsed_clock_ms=%.3f",
            w.id,label(reason or "stop"),(clock()-w.started)*1000)})
    end
    -- Once per process. Host API scalars only; never a UObject read. Lets a
    -- tester's normal capture explain machine differences without UE4SS.log.
    local environment
    local function describe()
        if environment then return environment end
        local function try(fn)
            local result=pack(pcall(fn))
            if result[1] then return unpack_values(result,2,result.n) end
        end
        local ue4ss,engine="unknown","unknown"
        local major,minor,hotfix=try(function() return rawget(_G,"UE4SS").GetVersion() end)
        if type(major)=="number" then ue4ss=string.format("%d.%d.%d",major,tonumber(minor) or 0,tonumber(hotfix) or 0) end
        local unreal_major,unreal_minor=try(function()
            local v=rawget(_G,"UnrealVersion"); return v.GetMajor(),v.GetMinor()
        end)
        if type(unreal_major)=="number" then engine=string.format("%d.%d",unreal_major,tonumber(unreal_minor) or 0) end
        -- Proton passes Steam's compatibility variables into the game process.
        local proton=try(function() return os.getenv("STEAM_COMPAT_DATA_PATH") or os.getenv("WINEPREFIX") end)
        environment=string.format("ENV | ue4ss=%s | unreal=%s | lua=%s | proton=%s | lookup cost: see lookup.static_find",
            ue4ss,engine,label(_VERSION or "unknown"),proton and "detected" or "not detected")
        return environment
    end
    local function schedule(w)
        runtime:after("perf:summary",5000,function()
            if self.window~=w then return end
            self.report("5s summary"); schedule(w)
        end)
    end
    local function start(mode,source,slot)
        self.stop("replaced"); serial=serial+1
        local w={id=serial,rows={},labels=0,dropped=0,mode=mode,phase="queued",started=clock()}; self.window=w
        if runtime.objects then w.object_hits,w.object_misses=runtime.objects.hits,runtime.objects.misses end
        emit({string.format("PERF | window=%d | START | update-stages-v3 | build=%s | mode=%s | source=%s | slot=%s | %s | 5s summaries | clock=os.clock; platform-dependent, not GPU/frame timings; nested totals overlap | picker.sample: editing=observed input/held SV/pending color; idle=no observed edit; completed tick work, not time spent by user; thresholds inclusive",
            w.id,label(runtime.version or "unknown"),mode,label(source or "console"),label(slot or "resolved after opening"),
            mode=="picker" and "until picker closes; no timeout" or "120s capture"),
            "PERF | window=" .. w.id .. " | " .. describe()})
        schedule(w)
        if mode~="picker" then
            runtime:after("perf:expiry",120000,function() if self.window==w then self.stop("120s timeout") end end)
        end
        return w
    end
    function self.start()
        if self.window and self.window.mode=="picker" then return end
        return start("manual")
    end
    function self.begin_picker(source,slot)
        if self.window and self.window.mode=="picker" then return self.window end
        return start("picker",source,slot)
    end
    function self.event(message)
        local w=self.window
        if w then emit({"PERF | window=" .. w.id .. " | " .. tostring(message):gsub("[\r\n\t]"," "):sub(1,1024)}) end
    end
    function self.picker_opening()
        self.begin_picker("console/Dev Panel")
        self.window.phase="opening"
    end
    function self.picker_ready(session)
        local w=self.window
        if not w or w.mode~="picker" then return end
        w.phase="active"
        local profile=session.profile or {}
        self.event("READY | slot=" .. label(profile.slot or "see launch") .. " | policy=" .. label(session.preview_policy or "legacy")
            .. " | parameter=" .. label(profile.parameter or "unknown") .. " | race=" .. label(profile.skin_race or profile.bundle or "n/a"))
        -- Backends supply already-validated scalar metadata. Never stringify
        -- userdata, inspect a live asset, or guess a localized preset number.
        local target=session.perf_target or {}
        local function field(value)
            return type(value)=="string" and value:gsub("[\r\n\t|]"," "):sub(1,256) or "unknown"
        end
        self.event("TARGET | part=" .. field(target.part or session.part)
            .. " | backend=" .. field(target.backend or (type(session.part)=="string" and "regular"))
            .. " | selection=" .. field(session.perf_selection or "selected")
            .. " | preview_part=" .. field(session.blue and session.blue.part or target.part or session.part))
    end
    function self.end_picker(reason,expected)
        if self.window and self.window.mode=="picker" and (not expected or self.window==expected) then self.stop(reason) end
    end
    function self.cancel_launch(reason)
        if self.window and self.window.mode=="picker" and self.window.phase=="queued" then self.stop(reason) end
    end
    function self.attach()
        runtime:console("colors_perf",function(_,params)
            params=params or {}; local action=tostring(params[1] or "start"):lower()
            if #params>1 or (action~="start" and action~="stop" and action~="report") then
                runtime.log("PERF | Usage: colors_perf start|report|stop"); return
            end
            runtime:after("perf:command",1,function()
                if self.window and self.window.mode=="picker" and action~="report" then
                    runtime.log("PERF | Automatic capture stays active until the picker closes"); return
                end
                if action=="start" then self.start()
                elseif action=="stop" then self.stop("console stop")
                else self.report("console report") end
            end)
        end)
    end
    return self
end
return M
