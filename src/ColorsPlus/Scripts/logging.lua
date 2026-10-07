local M = {}

-- options.mirror: also print each batch to UE4SS (default true).
-- options.limit: bytes; past it the file moves to <name>.previous.log
-- (replacing the older copy) and a fresh file starts, so a log never grows
-- without bound across play sessions.
function M.new(path, generation, options)
    options=options or {}
    local previous=path:gsub("%.log$","") .. ".previous.log"
    local file,size
    local function open()
        local ok, f = pcall(io.open, path, "a")
        file = ok and f or nil
        size = 0
        if file then
            local measured,at=pcall(function() return file:seek("end") end)
            if measured and type(at)=="number" then size=at end
        end
    end
    local function rotate()
        if file then pcall(function() file:close() end); file=nil end
        pcall(os.remove, previous)
        pcall(os.rename, path, previous)
        open()
    end
    open()
    if file and options.limit and size >= options.limit then rotate() end
    local logger = { path = file and path or "unavailable; using UE4SS.log" }
    function logger.close()
        if file then pcall(function() file:close() end); file = nil end
    end
    function logger.write_batch(messages)
        -- Logging must not abort the callback it is meant to diagnose.
        local dated,stamp=pcall(os.date,"!%Y-%m-%dT%H:%M:%SZ")
        if not dated or type(stamp)~="string" then stamp="[timestamp unavailable]" end
        local lines={}
        for _,message in ipairs(messages) do
            lines[#lines+1]=string.format("%s [Colors+] [generation=%d] %s",
                stamp, generation, tostring(message):gsub("[\r\n]", " "))
        end
        local output=table.concat(lines,"\n") .. "\n"
        if file and options.limit and size + #output > options.limit then rotate() end
        -- Flush the independent file before entering UE4SS's output path so a
        -- logging lock during reload cannot hide the last checkpoint too.
        local wrote=false
        if file then
            wrote = pcall(function() assert(file:write(output)); assert(file:flush()) end)
            if wrote then size=size+#output else
                logger.close()
                pcall(print,"[Colors+] Dedicated log write failed; using UE4SS.log\n")
            end
        end
        if options.mirror~=false or not wrote then pcall(print,output) end
    end
    function logger.write(message) logger.write_batch({message}) end
    return logger
end

return M
