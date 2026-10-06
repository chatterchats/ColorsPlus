-- No UObject access. Only a UE4SS shared string (survives Lua hot reload) can
-- authorize replay of disk recovery in this process. Lua generation/name reuse
-- and a disk stamp alone are NOT evidence of the same editor session.
local M={}
local KEY="ColorsPlusProbe.RecoveryProcess.v1"
local PREFIX="colors-process-v1:"
local function valid(value)
    if type(value)~="string" then return false end
    local n=value:match("^colors%-process%-v1:([1-9]%d*)$")
    return n and #n<=12 and tonumber(n)<=999999999999
end
function M.prepare(runtime,directory)
    local function log(s) runtime.log("SESSION | " .. s) end
    local function open_read(path)
        local f,err,code=io.open(path,"r")
        if not f then assert(code==2,"Cannot read session file: " .. tostring(err)) end
        return f
    end
    local function read(path,limit)
        local f=open_read(path); if not f then return nil end
        local data=f:read(limit+1) or ""; f:close()
        assert(#data<=limit,"Oversized session metadata: " .. path)
        return data:gsub("\r\n","\n")
    end
    local function exists(path)
        local f=open_read(path); if not f then return false end
        f:close(); return true
    end
    local function pending(path)
        local f=open_read(path); if not f then return false end
        local b=f:read(1); f:close(); return b~=nil and b~=""
    end
    local function write(path,data)
        -- Preserve the previous metadata if write/flush fails.
        local previous=path .. ".previous"
        assert(not exists(previous),"Interrupted metadata replacement; preserve and inspect " .. previous)
        local f=assert(io.open(path .. ".tmp","w"),"Cannot write session metadata")
        local ok,err=pcall(function() assert(f:write(data)); assert(f:flush()) end)
        local closed=f:close(); assert(ok,err); assert(closed~=false,"Session metadata close failed")
        -- Windows CRT rename does not replace an existing destination. Keep a
        -- recoverable previous file during the swap; never silently delete it.
        local had_previous=exists(path)
        if had_previous then assert(os.rename(path,previous),"Cannot preserve session metadata") end
        local renamed=os.rename(path .. ".tmp",path)
        if not renamed then
            if had_previous then os.rename(previous,path) end
            error("Cannot replace session metadata")
        end
        if had_previous then assert(os.remove(previous),"Cannot retire previous session metadata") end
    end
    local ok,result=pcall(function()
        log("SHARED READ BEGIN")
        local mod=assert(rawget(_G,"ModRef"),"ModRef unavailable; recovery disabled")
        local shared=mod:GetSharedVariable(KEY)
        log("SHARED READ RETURN | present=" .. tostring(shared~=nil))
        local held=mod:GetSharedVariable(KEY .. ".Blocked")
        assert(held==nil,"This process is held after unrecognized recovery; restart the game: " .. tostring(held))
        local same_process=shared~=nil
        assert(not same_process or valid(shared),"Invalid process shared marker; recovery disabled")
        local counter_path=directory .. "process_session_counter.txt"
        if not same_process then
            local previous=read(counter_path,32)
            local count=0
            if previous then
                assert(previous:match("^[1-9]%d*\n$") and #previous<=13,"Invalid process counter")
                count=tonumber(previous)
            end
            assert(count<999999999999,"Process counter exhausted")
            shared=PREFIX .. string.format("%.0f",count+1)
            write(counter_path,string.format("%.0f\n",count+1))
            log("SHARED WRITE BEGIN | " .. shared)
            mod:SetSharedVariable(KEY,shared)
            assert(mod:GetSharedVariable(KEY)==shared,"Process marker readback failed")
            log("SHARED WRITE RETURN")
        end
        local stamp_path=directory .. "recovery_session.txt"
        local stamp=read(stamp_path,64)
        local known_stamp=stamp and stamp:sub(-1)=="\n" and valid(stamp:sub(1,-2))
        local authorized=same_process and stamp==shared .. "\n"
        local mode=same_process and "same-process-reload" or "first-attach/new-process"
        log("CLASSIFIED | " .. mode .. " | " .. shared .. " | recovery_authorized=" .. tostring(authorized))
        local quarantined=false
        -- The eye and skin-target journals belong to retired dev probes; they are
        -- still archived so a leftover from an older dev build is never stranded.
        local leaves={"tint_recovery.txt","default_selection_recovery.txt","editor_recovery.txt","editor_recovery.txt.previous",
            "eye_recovery.txt","eye_recovery.txt.previous","skin_target_recovery.txt","skin_target_recovery.txt.previous",
            "zabrak_picker_recovery.txt","zabrak_picker_recovery.txt.previous"}
        for i=2,32 do
            for _,leaf in ipairs({"tint_recovery.txt","default_selection_recovery.txt","editor_recovery.txt","editor_recovery.txt.previous",
                "zabrak_picker_recovery.txt","zabrak_picker_recovery.txt.previous"}) do
                leaves[#leaves+1]="zone" .. i .. "_" .. leaf
            end
        end
        for _,leaf in ipairs(leaves) do
            local path=directory .. leaf
            if (pending(path) or leaf:match("%.previous$") and exists(path)) and not authorized then
                local destination
                for i=1,1000 do
                    local candidate=path .. ".archive-" .. shared:sub(#PREFIX+1) .. "-" .. i
                    if not exists(candidate) then destination=candidate; break end
                end
                assert(destination,"Recovery archive limit exceeded")
                log("ARCHIVE BEGIN | " .. path .. " -> " .. destination)
                assert(os.rename(path,destination),"Cannot archive untrusted recovery: " .. leaf)
                log("ARCHIVED | " .. destination .. " | no game objects touched")
                quarantined=true
            end
        end
        -- A legacy/unstamped upgrade inside an editor cannot prove the old
        -- preview is gone. Archive it, but require a fresh game before writes.
        if quarantined and (same_process or not known_stamp) then
            local reason="Unrecognized in-process/legacy recovery archived; restart the game before preview writes"
            mod:SetSharedVariable(KEY .. ".Blocked",reason)
            assert(mod:GetSharedVariable(KEY .. ".Blocked")==reason,"Cannot retain process recovery hold")
            error(reason)
        end
        write(stamp_path,shared .. "\n")
        runtime.process_session=shared
        log("READY | " .. mode)
        return mode
    end)
    if not ok then log("BLOCKED | " .. tostring(result)); return false,tostring(result) end
    return true,result
end
return M
