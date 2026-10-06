local M = {}

function M.new(path, generation, options)
    options=options or {}
    local ok, file = pcall(io.open, path, "a")
    if not ok then file = nil end
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
            lines[#lines+1]=string.format("%s [Colors+Probe] [generation=%d] %s",
                stamp, generation, tostring(message):gsub("[\r\n]", " "))
        end
        local output=table.concat(lines,"\n") .. "\n"
        -- Flush the independent file before entering UE4SS's output path so a
        -- logging lock during reload cannot hide the last checkpoint too.
        if file then
            local written = pcall(function() assert(file:write(output)); assert(file:flush()) end)
            if not written then
                logger.close()
                pcall(print,"[Colors+Probe] Dedicated log write failed; using UE4SS.log\n")
            end
        end
        if options.mirror~=false or not file then pcall(print,output) end
    end
    function logger.write(message) logger.write_batch({message}) end
    return logger
end

return M
