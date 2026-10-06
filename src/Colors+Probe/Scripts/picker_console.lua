-- Console entry point for the picker (UE4SS console: colors_picker).
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
        -- One queued action: repeated commands coalesce and close supersedes
        -- a queued open. Leaving the page or creator cancels it (below).
        runtime:after("console:picker", 1, function()
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
    -- Never run a queued action on the next screen.
    runtime.dev_context = {before=function(reason)
        if reason == "page closed" or reason == "creator closed" then runtime:cancel("console:picker") end
    end}
    runtime.log("PICKER CONSOLE | Ready: colors_picker [open|trace|close|apply|restore]")
end
return M
