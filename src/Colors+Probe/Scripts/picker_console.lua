-- Standalone entry point; no Dev Panel UI or action-file dispatch required.
local M = {}
function M.attach(runtime)
    if type(RegisterConsoleCommandHandler) ~= "function" then
        runtime.log("PICKER CONSOLE | Unavailable: RegisterConsoleCommandHandler missing")
        return
    end
    runtime:console("colors_picker", function(_, parameters, output)
        local function reply(message)
            runtime.log("PICKER CONSOLE | " .. message)
            -- OutputDevice belongs to this invocation; never retain it in a job.
            if output then pcall(function() output:Log(message) end) end
        end
        parameters = parameters or {}
        local action = string.lower(tostring(parameters[1] or "open"))
        if #parameters > 1 or (action ~= "open" and action ~= "trace" and action ~= "close" and action ~= "apply" and action ~= "restore") then
            reply("Usage: colors_picker [open|trace|close|apply|restore]")
            return
        end
        if not runtime.picker then
            reply("Disabled: " .. (runtime.tint_disabled_reason or "picker unavailable"))
            return
        end
        -- Share the existing open-action key so page exit, Restore and stock
        -- tracing cancel queued opens regardless of which entry point was used.
        -- Repeated commands coalesce; close also supersedes a queued open.
        runtime:after("panel:open_picker", 1, function()
            if action == "close" then runtime.picker.close("console close")
            elseif action == "apply" then runtime.picker.apply()
            elseif action == "restore" then
                runtime.picker.close("console restore")
                if runtime.tint then runtime.tint.restore("console restore") end
            else
                runtime.picker_trace_next=action=="trace"
                runtime.picker.open()
                runtime.picker_trace_next=nil -- also clear when opening was refused
            end
        end)
        reply("Queued picker " .. action .. "; close the game console to interact.")
    end)
    runtime.log("PICKER CONSOLE | Ready: colors_picker [open|trace|close|apply|restore]")
end
return M
