local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/multi_editor.lua"))()
local jobs,workers,proxies,logs={},{},{},{}
local runtime={generic_colors=true,skin_enable={sentinel=true},log=function(s) logs[#logs+1]=s end}
function runtime:after(k,ms,fn) jobs[k]=fn end
function runtime:cancel(k) jobs[k]=nil end
local selected="VM_A"
local function factory(r,i)
    proxies[i]=r
    local w={restores=0,events=0,starts=0}
    workers[i]=w
    function w.selected_slot_identity() return selected end
    function w.begin_live()
        assert(not w.pending)
        w.pending={key=selected,index=i}; return w.pending
    end
    function w.apply_live(s)
        assert(s==w.pending)
        w.applied={vm=s.key,chosen=i}; w.pending=nil
        r:after("editor:watch",250,function() w.watched=true end)
        return true
    end
    function w.update_live(s) assert(s==w.pending); return true end
    function w.cancel_live() w.pending=nil; return true end
    function w.restore()
        w.restores=w.restores+1
        if w.fail_restore then w.blocked="repair needed"; return false end
        w.pending=nil; w.applied=nil; w.blocked=nil; w.source_owned=nil; r:cancel("editor:watch"); return true
    end
    function w.context_changed(reason)
        w.events=w.events+1
        if reason=="creator closed" then w.restore() end
    end
    function w.invalidate_context_lookup() w.invalidations=(w.invalidations or 0)+1 end
    function w.start() w.starts=w.starts+1 end
    function w.read_context() return {slot=selected} end
    function w.apply() return true end
    w.apply_rgb=w.apply; w.cycle_rgb=w.apply
    return w
end
local m=module.new(runtime,factory); runtime.tint=m
m.start(); assert(#workers==32 and workers[32].starts==1)
local a=m.begin_live(); assert(a.index==1); assert(m.apply_live(a))
selected="VM_B"; local b=m.begin_live(); assert(b.index==2 and workers[1].applied)
assert(proxies[1].skin_enable==nil and proxies[2].skin_enable==runtime.skin_enable)
workers[1].source_owned={sentinel="inactive Zabrak source"}
assert(m.source_owned==workers[1].source_owned,"Reload guard lost inactive source ownership")
assert(proxies[2].tint==workers[2])
assert(not m.begin_live(),"cannot open concurrent drafts")
assert(m.update_live(b)); assert(m.apply_live(b))
assert(jobs["editor:watch"] and jobs["zone2:editor:watch"])
jobs["editor:watch"](); jobs["zone2:editor:watch"](); assert(workers[1].watched and workers[2].watched)
assert(not m.apply_rgb(),"diagnostics may not overwrite applied zones")
selected="VM_A"; a=m.begin_live(); assert(a.index==1)
assert(m.cancel_live() and workers[1].applied and workers[2].applied)
m.context_changed("page closed"); assert(workers[1].events==1 and workers[2].events==1)
assert(workers[32].invalidations==1 and workers[32].events==0,"Inactive lookup invalidation must not dispatch native context work")
workers[2].fail_restore=true; assert(not m.restore("all") and m.blocked and not workers[1].applied)
assert(not m.begin_live(),"one blocked journal holds all new edits")
workers[2].fail_restore=nil; assert(m.restore("retry") and not m.applied and not m.blocked)
selected="VM_C"; local c=m.begin_live(); assert(c.index==1); m.apply_live(c)
selected="VM_D"; local d=m.begin_live(); assert(d.index==2); m.apply_live(d)
m.context_changed("creator closed"); assert(not m.applied and not jobs["editor:watch"] and not jobs["zone2:editor:watch"])
print("Multi editor: independent drafts, slot reuse, Apply retention, scheduler namespaces, Restore-all, blocked recovery and lifecycle passed")
