-- One color zone: the preview engine and the steps around it, sequenced here
-- rather than through wrapper layers.
--   Open:    applied-record check, temporary Default selection, preview,
--            then the applied color and skin display on the new draft.
--   Apply:   journal the record, hold Default, end the preview, write the
--            source, verify the display, watch for the rest of the visit.
--   Restore: end the preview, restore the applied source, then Default.
-- Zabrak skins with material swaps take their own source route instead
-- (zabrak_picker): the zone offers it every opening and sends its drafts there.
-- Components own their native reads/writes and journals; this file owns order.
-- journal(leaf) gives this zone's recovery file paths. Tests may replace the
-- preview engine (parts.preview) or the whole regular backend (parts.regular).
local M={}
local SKIN="br.Customization.Slot.Character.Appearance.Humanoid.Head.Face.SkinTone"
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
-- Literal file names: the packager finds player scripts by these references.
local function load(file) return assert(loadfile(directory .. file))() end
local function timer(runtime)
    return function(label,fn,...)
        if runtime.perf then return runtime.perf.measure(label,fn,...) end
        return fn(...)
    end
end

-- The regular backend: preview, temporary Default selection, applied edits.
local function regular_backend(runtime,a,journal,preview_part)
    local target_module=load("color_target.lua")
    local preview=preview_part or load("tint_test.lua").new(runtime,a,journal("tint_recovery.txt"))
    local selection=load("default_selection.lua").new(runtime,a,journal("default_selection_recovery.txt"),preview)
    local editor=load("editor_session.lua").new(runtime,a,journal("editor_recovery.txt"))
    local opening=false -- an opening is running: its native events and rollbacks are ours
    local timed=timer(runtime)
    local restore_regular,keep_regular -- defined with Apply; the watch below needs them first
    -- Hub editor visits end by keeping the applied color: the hub has no Save
    -- step, leaving the editor is how its changes stick.
    local function hub_visit(record) return record and record.creator and record.creator.tab~=nil end
    local function regular_pending() return preview.pending or (not selection.held and selection.record()) end
    local function regular_blocked() return editor.blocked or selection.blocked or preview.blocked end
    local function skin_stop(reason)
        return not runtime.skin_enable or runtime.skin_enable.stop(reason)
    end
    local function skin_sync(s,mode,read_context)
        return not runtime.skin_enable or runtime.skin_enable.start(mode,s,read_context)
    end

    -- Preview plus temporary Default selection -------------------------------
    -- Any preview end (Cancel, timeout, context change, failed update) returns
    -- the slot to Default unless an Apply holds the selection or our own
    -- opening is still running (it restores below once it unwinds).
    preview.after_restore=function(reason)
        if selection.record() and not opening and not selection.busy and not selection.held then
            return selection.restore(reason)
        end
        return true
    end
    local function end_preview(reason)
        local ok=preview.restore(reason)
        if ok and selection.record() and not selection.held then return selection.restore(reason) end
        return ok and not selection.blocked
    end
    local function open_preview()
        if regular_pending() or regular_blocked() then return nil end
        opening=true
        local session
        local ok,err=pcall(function()
            if not selection.prepare() then session=preview.begin_live(); return end
            session=assert(preview.begin_live(),"Regular RGB preview could not start")
            session.perf_selection="Default"
            selection.opened()
        end)
        opening=false
        if not ok then
            selection.open_failed(err); end_preview("picker opening failed"); selection.open_ended()
            return nil
        end
        return session
    end

    -- Applied source edits ---------------------------------------------------
    local function watch(s)
        editor.hold_lookups(true)
        runtime:after("editor:watch",250,function()
            if editor.record()~=s or editor.blocked then
                if not editor.record() or editor.blocked then editor.hold_lookups(false) end
                return
            end
            local ok,err,external=editor.check_applied(s)
            if not ok then
                local why="editor context ended/changed: " .. tostring(err)
                if hub_visit(s) and not external then keep_regular(why) else restore_regular(why,external) end
                return
            end
            -- Rendering availability is not ownership of the source RGB. Keep
            -- the verified Apply through navigation gaps; never undo it solely
            -- because the preview/display object is temporarily absent.
            if not regular_pending() and (s.render_failures or 0)<8 then
                local rendered,result=pcall(skin_sync,s,"applied")
                if rendered and result then
                    if (s.render_failures or 0)>0 then editor.log("DISPLAY RESUMED | applied RGB retained") end
                    s.render_failures=0
                else
                    s.render_failures=(s.render_failures or 0)+1
                    if s.render_failures==1 then editor.log("DISPLAY WAIT | applied RGB retained; source/visit still verified") end
                    if s.render_failures==8 then
                        editor.log("DISPLAY PAUSED | retry budget exhausted; resumes on context event; applied RGB retained; Restore before saving")
                    end
                end
            end
            watch(s)
        end)
    end
    -- external: the applied source was replaced by a later stock edit; keep it.
    restore_regular=function(reason,external)
        if editor.busy then return false end
        if not skin_stop(reason or "editor Restore") then return false end
        local record=editor.record()
        if not record then
            if editor.blocked then editor.log("RESTORE BLOCKED | " .. editor.blocked); return false end
            return end_preview(reason)
        end
        editor.busy=true
        local ok,err=pcall(function()
            runtime:cancel("editor:watch"); runtime:cancel("editor:recovery")
            assert(end_preview(reason),"Finish hover recovery before editor restore")
            local outcome=external and "replaced" or editor.restore_source(record)
            if outcome=="replaced" then selection.forget() end
            -- Source RGB first, then any temporary Default -> stock selection.
            selection.hold(false)
            assert(end_preview(reason),"Finish Default selection recovery")
            if outcome=="restored" then
                local readable,c=pcall(preview.read_context)
                if readable and c and editor.owns_context(c,record) then
                    assert(preview.verify_editor_display(),"Restored editor display verification failed")
                end
            end
            editor.clear()
            editor.log("RESTORED | " .. tostring(reason) .. (outcome=="replaced" and " | later stock edit preserved" or ""))
        end)
        editor.busy=false
        if not ok then editor.fail(err) end
        return ok
    end
    -- An open draft still ends first; a source replaced by a later stock edit
    -- is left alone. Any failure falls back to the normal restore.
    keep_regular=function(reason)
        if editor.busy then return false end
        local record=editor.record()
        if not hub_visit(record) then return restore_regular(reason) end
        editor.busy=true
        local ok,err=pcall(function()
            runtime:cancel("editor:watch"); runtime:cancel("editor:recovery")
            assert(skin_stop(reason),"Skin display restore failed")
            assert(end_preview(reason),"Finish hover recovery before keeping")
            local outcome=editor.keep(record)
            -- The temporary stock swatch now carries the kept color (or was
            -- replaced); never re-equip Default over it.
            selection.forget()
            editor.clear()
            editor.log("KEPT | " .. tostring(reason) .. " | " .. (outcome=="kept"
                and "hub editor; applied color left on the character" or "later stock edit preserved"))
            if outcome=="kept" then editor.observe_kept(record) end
        end)
        editor.busy=false
        if not ok then
            editor.log("KEEP FAILED | " .. tostring(err) .. " | restoring")
            return restore_regular(reason)
        end
        return true
    end
    local function cancel_regular(reason)
        if not skin_stop(reason or "picker Cancel") then return false end
        local restored=end_preview(reason or "picker Cancel")
        local record=editor.record()
        if restored and record then
            local ok,err=pcall(function()
                editor.verify_applied(record)
                assert(skin_sync(record,"applied"),"Applied skin enable failed")
            end)
            if not ok then editor.log("CANCEL DISPLAY FAILED | " .. tostring(err)); return false end
        end
        return restored
    end
    local function apply_regular(session)
        if runtime.skin_enable and runtime.skin_enable.pending and not runtime.skin_enable.pending.mode then
            runtime.log("SKIN ENABLE | Apply blocked until temporary test is restored"); return false
        end
        if regular_blocked() or editor.busy then return false end
        editor.busy=true
        local ok,err=pcall(function()
            local healthy,why=preview.check_live(session); assert(healthy,why)
            local s,was_applied=editor.prepare(session,preview.read_context) -- write-ahead intent
            -- Restore the hover while its source baseline is still unchanged.
            -- Keep Default's temporary editor selection until this visit ends.
            selection.hold(true)
            assert(skin_stop("Apply preview handoff"),"Skin preview restore failed")
            assert(end_preview("Apply: end hover preview"),"Could not end hover preview")
            editor.write(s,was_applied)
            assert(preview.verify_editor_display(),"Applied display verification failed")
            assert(skin_sync(s,"applied"),"Applied face tint enable failed")
            watch(s)
            editor.log_applied(s)
        end)
        editor.busy=false
        if not ok then
            editor.log("APPLY FAILED | " .. tostring(err))
            restore_regular("failed editor Apply rollback")
        end
        return ok
    end

    -- Drafts ------------------------------------------------------------------
    local function begin_live()
        if regular_blocked() then return nil end
        local record=editor.record()
        if record then
            local ok,err=pcall(editor.reopen_check,preview.read_context)
            if not ok then editor.log("OPEN REFUSED | " .. tostring(err)); return nil end
        end
        if not skin_stop("opening skin draft") then return nil end
        local s=timed("begin.default_selection",open_preview)
        if s and record and not preview.update_live(s,record.chosen) then return nil end
        if s and not skin_sync(s,"preview") then cancel_regular("skin preview enable failed"); return nil end
        if s then s.preview_policy=target_module.preview_policy(s.profile) end
        return s
    end
    local function update_regular(s,chosen)
        if not timed("update.skin_stop",skin_stop,"RGB update") then return false end
        local ok
        if s.profile.slot==SKIN then
            -- Face skin display sync runs inside the preview's verified update.
            ok=preview.update_live_scoped(s,chosen,function(read_context)
                return timed("update.skin_enable",skin_sync,s,"preview",read_context)
            end)
        else
            if not preview.update_live(s,chosen) then return false end
            ok=timed("update.skin_enable",skin_sync,s,"preview")
        end
        -- The preview verifies context before writing and verifies the result;
        -- skin_sync must also succeed before issuing this receipt.
        return ok,ok==true
    end
    local function check_regular(s)
        local ok,why=preview.check_live(s)
        if not ok then return ok,why end
        return skin_sync(s,"preview"),"Skin preview enable failed"
    end

    -- Events and startup ------------------------------------------------------
    local function invalidate(reason)
        selection.invalidate_context_lookup(reason)
        preview.invalidate_context_lookup(reason)
    end
    local function context_regular(reason,identity)
        if editor.busy then return end
        local record=editor.record()
        if record then record.render_failures=0 end -- event-driven retry after a bounded display wait
        if reason=="creator closed" then
            if identity and record and record.creator and identity~=record.creator.master then return end
            if hub_visit(record) then keep_regular(reason) else restore_regular(reason) end
            return
        end
        if reason=="page closed" then
            -- Discard an open draft, but do not undo an already-applied source
            -- color just because the user returned to the radial slot selector.
            end_preview("item page closed")
            if record then editor.log("RETAINED | item page closed; waiting for creator navigation") end
            return
        end
        invalidate(reason)
        if opening or selection.busy then return end -- our own synchronous equip/reset events
        preview.context_changed(reason)
        -- The watcher checks the original source independently of selected slot.
        -- No reapplication loop: later stock edits win.
    end
    local function start_regular()
        local applied=editor.start()
        if applied==nil then return end -- blocked: recover nothing until inspected
        if applied then selection.hold(true) end
        local selected=selection.start()
        preview.start()
        if selected then
            runtime:after("selection:recovery",50,function()
                if selection.record() then end_preview("reload recovery") end
            end)
        end
        if applied then runtime:after("editor:recovery",25,function() restore_regular("reload recovery") end) end
    end

    return {
        pending=regular_pending, blocked=regular_blocked,
        applied=function() return editor.record() end,
        busy=function() return opening or editor.busy or selection.busy or preview.busy end,
        begin_live=function() return timed("begin.editor",begin_live) end,
        update_live=update_regular, check_live=check_regular, apply_live=apply_regular,
        cancel_live=cancel_regular, restore=restore_regular, context_changed=context_regular,
        invalidate_context_lookup=invalidate, start=start_regular,
        read_context=function() return preview.read_context() end,
        bind_selected_context=function(c) return preview.bind_selected_context(c) end,
        read_selected_context=function(route) return preview.read_selected_context(route) end,
        selected_slot_identity=function() return timed("context.selected_slot",selection.selected_slot_identity) end,
        inspect=function()
            if selection.record() or selection.blocked then selection.log("Finish Default selection recovery first"); return false end
            return preview.inspect()
        end,
    }
end

-- The zone chooses the backend: the Zabrak route claims its skins at opening
-- and owns its drafts; everything else goes to the regular backend. Restore
-- always ends the route before the regular steps.
function M.new(runtime,a,journal,parts)
    parts=parts or {}
    local timed=timer(runtime)
    local regular=parts.regular or regular_backend(runtime,a,journal,parts.preview)
    local route
    local self=setmetatable({}, {__index=function(_,k)
        if k=="pending" then return route.pending() or regular.pending() end
        if k=="applied" then return route.applied() or regular.applied() end
        if k=="blocked" then return route.blocked() or regular.blocked() end
        if k=="busy" then return route.busy() or regular.busy() end
        if k=="source_owned" then return route.source_owned() end
    end})
    route=load("zabrak_picker.lua").new(runtime,a,journal("zabrak_picker_recovery.txt"),self)
    local function routed(s) return s~=nil and s==route.draft() end
    function self.begin_live()
        return timed("begin.zabrak",function()
            if self.blocked or self.pending or self.busy then return nil end
            local claimed=route.claim()
            if claimed==nil then return regular.begin_live() end
            if not claimed then return nil end
            if regular.applied() then route.log("OPEN REFUSED | another zone owns this worker"); return nil end
            return route.begin(claimed)
        end)
    end
    function self.update_live(s,chosen)
        if routed(s) then return route.update(s,chosen) end
        return regular.update_live(s,chosen)
    end
    function self.check_live(s)
        if routed(s) then return route.check(s) end
        return regular.check_live(s)
    end
    function self.apply_live(s)
        if routed(s) then return route.apply(s) end
        return regular.apply_live(s)
    end
    function self.cancel_live(reason)
        if route.draft() then return route.cancel(reason) end
        return regular.cancel_live(reason)
    end
    function self.restore(reason,external)
        if not route.restore(reason) then return false end
        return regular.restore(reason,external)
    end
    function self.context_changed(reason,identity)
        if not route.invalidate() then return end -- the route's own source writes
        regular.context_changed(reason,identity)
        route.context_changed(reason,identity)
    end
    function self.invalidate_context_lookup(reason) regular.invalidate_context_lookup(reason) end
    function self.start() regular.start(); route.start() end
    function self.read_context() return regular.read_context() end
    function self.bind_selected_context(c) return regular.bind_selected_context(c) end
    function self.read_selected_context(route_hint) return regular.read_selected_context(route_hint) end
    function self.selected_slot_identity() return regular.selected_slot_identity() end
    function self.inspect() return regular.inspect() end
    return self
end
return M
