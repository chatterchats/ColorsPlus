-- UI coordination only. Engine ownership/recovery stays in the tint backends.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local rules=assert(loadfile(directory .. "color_rules.lua"))()
function M.new(runtime,tint,view,rgb_input)
    local self={active=nil}
    local presets={orange={R=255,G=128,B=32},violet={R=160,G=64,B=224},green={R=64,G=208,B=112}}
    local function key(rgb) return string.format("%d,%d,%d",rgb.R,rgb.G,rgb.B) end
    local function input(active,value)
        if active.mode=="hsv_shift" then
            local c={R=value.R,G=value.G,B=value.B,A=1}
            assert(rules.color(c,rules.SCAR,rules.SCAR_HSV_PARAMETER),"Invalid scar HSV adjustments")
            return c
        end
        local c=rgb_input.parse(key(value)); return c
    end
    local function encoded_value(active,value)
        if active.mode=="hsv_shift" then
            local c=input(active,value); return string.format("%.17g,%.17g,%.17g",c.R,c.G,c.B)
        end
        return key(value)
    end
    local function log(s)
        runtime.log("PICKER | " .. s)
        if runtime.perf then runtime.perf.event("PICKER | " .. s) end
    end
    local function timed(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
    local function ui_frame(fn)
        if view.frame then return view.frame(fn) end
        return fn()
    end
    local function ui_sample(fn)
        if runtime.perf then return runtime.perf.picker_sample(ui_frame,fn) end
        return ui_frame(fn)
    end
    local function opening_step(label,fn,...)
        return fn(...)
    end
    local function close_current(active,reason)
        if self.active==active then return self.close(reason) end
    end
    local function cancel_jobs()
        -- Try every cancellation even if one native handle fails.
        local failure
        for _,job in ipairs({"picker:tick","picker:preview-ready","picker:health-ready"}) do
            local ok,err=pcall(runtime.cancel,runtime,job)
            if not ok then failure=failure or err end
        end
        if failure then error(failure,0) end
    end
    local function arm(active,field,job,delay)
        active[field]=false
        local ticket={}; active[job]=ticket
        runtime:after(job,delay,function()
            -- Timer callbacks only release a gate. Native writes always use
            -- the next fresh UI sample, never a queued color or native ref.
            if self.active==active and active[job]==ticket then active[field]=true end
        end)
    end
    local function close(reason)
        local skin_restored=true
        if runtime.skin_enable then skin_restored=runtime.skin_enable.stop(reason or "picker closing") end
        local active=self.active; self.active=nil
        local cancelled,cancelErr=pcall(cancel_jobs)
        if not cancelled then log("CANCEL FAILED | " .. tostring(cancelErr)) end
        -- Always attempt to remove the UI even if tint recovery fails.
        local restored=true
        if active and tint.pending == active.session then
            local ok,result=pcall(timed,"tint.cancel_restore",tint.cancel_live or tint.restore,reason or "picker Cancel")
            restored=ok and result==true
            if not ok then log("RESTORE FAILED | " .. tostring(result)) end
        end
        local ok,err=pcall(timed,"ui.close",view.close)
        if runtime.objects then runtime.objects.release("picker") end
        if not ok then log("CLOSE FAILED | " .. tostring(err) .. " | retry Cancel/Restore or restart") end
        log("CLOSED | " .. (reason or "Cancel") .. " | restored=" .. tostring(restored) .. " | removed=" .. tostring(ok))
        return ok and restored and cancelled and skin_restored
    end
    function self.close(reason)
        local capture=runtime.perf and runtime.perf.window
        local ok,result=pcall(timed,"picker.close",close,reason)
        if runtime.perf then runtime.perf.end_picker(reason or "Cancel",capture) end
        if not ok then error(result,0) end
        return result
    end
    function self.apply(rgb)
        local capture=runtime.perf and runtime.perf.window
        if runtime.skin_enable and runtime.skin_enable.pending and not runtime.skin_enable.pending.mode then
            log("APPLY REFUSED | Stop the temporary skin-enable test first"); return false
        end
        local active=self.active
        if not active or not tint.apply_live then return false end
        local refused=false
        local ok,err=pcall(function()
            if not rgb then
                local value,_,valid=view.read()
                if valid==false then log("APPLY REFUSED | Correct the picker input before Apply"); refused=true; return end
                rgb=value
            end
            log("APPLY BEGIN | flushing latest input")
            -- Apply must flush the latest value even during a preview cooldown.
            assert(timed("tint.final_update",tint.update_live,active.session,input(active,rgb)),"Final picker update failed")
            assert(self.active==active and tint.pending==active.session and active.session.live,"Picker closed during final update")
            assert(timed("tint.apply",tint.apply_live,active.session),"Editor Apply failed; see EDITOR COLOR log")
            log("APPLY COMPLETE | editor accepted color; removing picker")
            self.active=nil
            cancel_jobs()
            timed("ui.close",view.close)
            if runtime.objects then runtime.objects.release("picker") end
            log("APPLIED | picker closed; color retained for this editor visit")
        end)
        if not ok then
            log("APPLY FAILED | " .. tostring(err))
            if self.active==active or self.active==nil then self.close("Apply failure") end
        end
        if ok and not refused and runtime.perf then runtime.perf.end_picker("Apply",capture) end
        return ok and not refused
    end
    local function schedule(active)
        runtime:after("picker:tick",active.poll_ms,function()
            if self.active ~= active then return end
            local ok,err=pcall(ui_sample,function()
                if tint.pending ~= active.session or not active.session.live or active.session.force_restore_reason then
                    self.close("preview ended"); return
                end
                local rgb,action,_,editing=timed("ui.read",view.read)
                if self.active~=active then return end
                if runtime.perf then
                    runtime.perf.picker_activity(editing==true or action~=nil)
                end
                if action == "cancel" then self.close("picker Cancel"); return end
                if action == "apply" then
                    self.apply(rgb)
                    if self.active==active then schedule(active) end
                    return
                end
                if active.mode~="hsv_shift" and presets[action] then rgb=presets[action]; view.set_rgb(rgb) end
                if self.active~=active then return end
                local encoded=encoded_value(active,rgb)
                if runtime.perf then
                    runtime.perf.picker_activity(editing==true or action~=nil or encoded~=active.shown or encoded~=active.applied)
                end
                if encoded ~= active.shown then
                    timed("ui.show",view.show,rgb,input(active,rgb))
                    if self.active~=active then return end
                    active.shown=encoded
                end
                active.ticks=active.ticks+1
                -- Supported picker profiles use an owned elapsed-delay gate
                -- instead of counting slow UI polls. Legacy probes keep theirs.
                local update_due=active.smooth and active.preview_ready
                    or not active.smooth and active.ticks % active.update_ticks == 0
                if update_due and encoded ~= active.applied then
                    if runtime.skin_enable and not runtime.skin_enable.stop("RGB changed") then
                        self.close("skin-enable restore failed"); return
                    end
                    local updated,validated=timed("tint.preview_update",tint.update_live,active.session,input(active,rgb))
                    if not updated then
                        close_current(active,"live update refused/failed"); return
                    end
                    if self.active~=active then return end
                    active.applied=encoded
                    if active.smooth then
                        arm(active,"preview_ready","picker:preview-ready",75)
                        -- Only an explicit backend receipt can replace an
                        -- idle health check. Every write still validates.
                        if validated==true then arm(active,"health_ready","picker:health-ready",495) end
                    end
                end
                local check_due=active.smooth and active.health_ready
                    or not active.smooth and active.ticks % active.check_ticks == 0
                if check_due then
                    local healthy,why=timed("tint.context_check",tint.check_live,active.session)
                    if not healthy then close_current(active,"context changed: " .. tostring(why)); return end
                    if self.active~=active then return end
                    if active.smooth then arm(active,"health_ready","picker:health-ready",495) end
                end
                if self.active==active then schedule(active) end
            end)
            if not ok then log("FAILED | " .. tostring(err)); close_current(active,"picker UI failure") end
        end)
    end
    local function open()
        if runtime.skin_enable and runtime.skin_enable.pending and not runtime.skin_enable.pending.mode then
            log("OPEN REFUSED | Restore the skin-enable test first"); return false
        end
        if self.active then log("Already open"); return false end
        if tint.pending or tint.blocked then log("OPEN REFUSED | Restore pending tint/recovery first"); return false end
        log("OPEN BEGIN")
        -- Released by close(), including every failed or refused opening.
        if runtime.objects then runtime.objects.hold("picker") end
        local ok,err=pcall(function()
            local mode,initial,initialized
            if tint.read_context then
                local readable,c=pcall(timed,"opening.context",tint.read_context)
                if readable and c then
                    if rules.hsv(c.profile) then mode="hsv_shift" end
                    -- Plain values only. This is a UI seed, never authority for
                    -- a native write; begin_live still resolves independently.
                    if rules.finite(c.original) then
                        initial={R=c.original.R,G=c.original.G,B=c.original.B,A=c.original.A}
                        if not mode then
                            for _,k in ipairs({"R","G","B"}) do initial[k]=math.min(1,math.max(0,initial[k])) end
                        end
                    end
                end
            end
            timed("ui.open",function() ui_frame(function()
                view.open(mode) -- build before preview writes
                if initial then
                    timed("ui.seed",function()
                        local value=mode=="hsv_shift" and initial or rgb_input.to_srgb(initial)
                        view.set_rgb(value); view.show(value,initial)
                        initialized=value
                    end)
                end
            end) end)
            log("VIEW READY | starting verified tint preview")
            local session=assert(opening_step("tint.begin",timed,"tint.begin",tint.begin_live),"Could not start verified live preview")
            local poll_ms=view.poll_ms or 33
            local active={session=session,mode=mode,ticks=0,poll_ms=poll_ms,
                update_ticks=math.ceil(198/poll_ms),check_ticks=math.ceil(495/poll_ms),
                smooth=session.preview_policy=="skin" or session.preview_policy=="armor"
                    or session.preview_policy=="color" or session.preview_policy=="hsv",preview_ready=true}
            self.active=active
            if runtime.perf then opening_step("performance ready",runtime.perf.picker_ready,session) end
            opening_step("input mode validation",function()
                assert(rules.hsv(session.profile)==(mode=="hsv_shift"),"Picker input mode changed while opening")
            end)
            local rgb=opening_step("initial color conversion",function()
                return mode=="hsv_shift" and session.test_color or rgb_input.to_srgb(session.test_color)
            end)
            opening_step("initial color keys",function()
                active.shown,active.applied=encoded_value(active,rgb),encoded_value(active,rgb)
            end)
            -- Initialization used only freshly constructed, validated widgets.
            -- If preview setup changed/clipped the actual starting color, do
            -- the normal fresh UI pass. No wrappers survive tint.begin.
            if not initialized or initialized.R~=rgb.R or initialized.G~=rgb.G or initialized.B~=rgb.B
                or initial.R~=session.test_color.R or initial.G~=session.test_color.G
                or initial.B~=session.test_color.B or initial.A~=session.test_color.A then
                opening_step("UI initialization frame",function()
                    timed("ui.initialize",function() ui_frame(function()
                        opening_step("view.set_rgb",view.set_rgb,rgb)
                        opening_step("view.show",view.show,rgb,session.test_color)
                    end) end)
                end)
            elseif view.validate_ready then
                timed("ui.ready",function() ui_frame(view.validate_ready) end)
            end
            if active.smooth then opening_step("arm health",arm,active,"health_ready","picker:health-ready",495) end
            opening_step("schedule input polling",schedule,active)
            log("OPEN | " .. (mode=="hsv_shift" and "scar HSV adjustments; selected Look retained; " or "color controls; ")
                .. (active.smooth and (session.preview_policy .. " latest-only preview; 75ms post-update cooldown")
                or "live updates <=5Hz") .. "; Cancel restores; no draft timeout")
        end)
        if not ok then
            log("OPEN FAILED | " .. tostring(err))
            -- Retain diagnostics through rollback, then retire only our window.
            local closed,why=pcall(self.close,"picker open failed")
            if not closed then error(why,0) end
        end
        return ok
    end
    function self.open()
        if self.active then return open() end
        if runtime.perf then runtime.perf.picker_opening() end
        local capture=runtime.perf and runtime.perf.window
        local ok,result=pcall(timed,"picker.open",open)
        if not ok then
            log("OPEN FAILED | " .. tostring(result))
            pcall(self.close,"picker open exception")
        end
        if (not ok or not result) and runtime.perf then runtime.perf.end_picker("open refused/failed",capture) end
        return ok and result
    end
    function self.start()
        if type(StaticConstructObject) ~= "function" then return end
        runtime:after("picker:startup",1,function()
            if self.active then return end
            local ok,err=pcall(view.cleanup)
            if not ok then log("STALE UI CLEANUP FAILED | " .. tostring(err)) end
        end)
    end
    return self
end
return M
