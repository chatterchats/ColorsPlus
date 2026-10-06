-- Visibility ownership and same-process recovery, with no disk or game writes.
local scripts=assert(arg[1])
local module=assert(loadfile(scripts .. "/palette_visibility.lua"))()
local old_mod,old_find=ModRef,StaticFindObject
local objects,shared,writes,events={}, {},0,{}
local fail_shared,fail_hide,fail_restore,expected_targets
local function object(class,path)
    local o={full=class .. " " .. path,visibility=0}
    function o:IsValid() return not self.invalid end
    function o:GetFullName() assert(not self.invalid); return self.full end
    function o:GetParent() assert(not self.invalid); return self.parent end
    function o:GetVisibility() assert(not self.invalid); return self.visibility end
    function o:SetVisibility(v)
        local record=module.parse(shared[module.KEY])
        assert(not self.invalid and record,"Recovery intent precedes every visibility write")
        assert(not expected_targets or #record.targets==expected_targets,"Snapshot every control before the first setter")
        if (fail_restore==true or fail_restore==self) and v~=2 then error("restore failed before setter") end
        writes=writes+1; self.visibility=v; events[#events+1]={self.full,v}
        if (fail_hide==true or fail_hide==self) and v==2 then error("hide failed after setter") end
    end
    objects[path]=o; return o
end
local a={unwrap=function(v) return v end,live=function(v) return v and v:IsValid() end,name=function(v) return v:GetFullName() end}
StaticFindObject=function(path) return objects[path] end
ModRef={GetSharedVariable=function(_,key) return shared[key] end,
    SetSharedVariable=function(_,key,value)
        assert(type(value)=="string","Only scalar strings may survive a Lua reload")
        if not fail_shared then shared[key]=value end
    end}
local grid,parent,overlay,root,b,visibility
local tree="/Game/Test.Tiles.WidgetTree_4"
local function reset(original)
    objects,shared,writes,events={}, {},0,{}
    fail_shared,fail_hide,fail_restore,expected_targets=nil,nil,nil,nil
    parent=object("ScrollBox",tree .. ".PaletteScroll")
    overlay=object("Overlay",tree .. ".Overlay_0")
    grid=object("BitReactorTileView",tree .. ".PartsGridList"); grid.parent=parent; grid.visibility=original or 0
    root=object("UserWidget","/Game/Test.PC.ColorsPlusPicker_Root_1"); root.parent=overlay
    b={grid=grid.full,overlay=overlay.full,chain={parent.full,overlay.full}}
    visibility=module.new(a)
end
for _,original in ipairs({0,1,2,3,4}) do
    reset(original); visibility.hide(b,root.full)
    assert(grid.visibility==2 and visibility.validate(b))
    assert(not pcall(visibility.restore) and writes==1,"An attached picker retains exclusive palette ownership")
    root.parent=nil; assert(visibility.restore() and grid.visibility==original and shared[module.KEY]=="")
    local before=writes; assert(visibility.restore() and writes==before,"Restoration is idempotent")
end
-- Reload reconstructs only strings; native objects must be looked up afresh.
reset(4); visibility.hide(b,root.full)
visibility=module.new(a); assert(visibility.validate(b)); root.parent=nil
assert(visibility.restore() and grid.visibility==4)
reset(); visibility.hide(b,root.full)
local stale=grid
grid=object("BitReactorTileView",tree .. ".PartsGridList"); grid.parent=parent; grid.visibility=2
stale.GetVisibility=function() error("Stale native wrapper touched") end
root.parent=nil; assert(visibility.restore() and grid.visibility==0)
-- Native visibility/reparenting wins over the previous UI hold.
reset(); visibility.hide(b,root.full); grid.visibility=4
assert(not pcall(visibility.validate,b)); root.parent=nil
assert(visibility.restore() and grid.visibility==4 and writes==1)
reset(); visibility.hide(b,root.full); grid.parent=overlay; root.parent=nil
assert(visibility.restore() and writes==1 and grid.visibility==2)
reset(); visibility.hide(b,root.full); grid.invalid=true; root.parent=nil
assert(visibility.restore() and writes==1)
reset(); visibility.hide(b,root.full); root.invalid=true
assert(visibility.restore() and grid.visibility==0)
-- Partial hide and failed restoration keep an actionable recovery record.
reset(3); fail_hide=true
assert(not pcall(visibility.hide,b,root.full) and grid.visibility==2 and module.parse(shared[module.KEY]))
fail_hide=nil; root.parent=nil; assert(visibility.restore() and grid.visibility==3)
reset(); visibility.hide(b,root.full); root.parent=nil; fail_restore=true
assert(not pcall(visibility.restore) and grid.visibility==2 and module.parse(shared[module.KEY]))
fail_restore=nil; visibility=module.new(a); assert(visibility.restore() and grid.visibility==0)
reset(); fail_shared=true
assert(not pcall(visibility.hide,b,root.full) and grid.visibility==0 and writes==0)
-- Hide/restore a complete selector, including our launcher outside WidgetTree.
local label,slider,launcher,targets
local function multi()
    reset()
    label=object("TextBlock",tree .. ".Label"); label.parent=parent; label.visibility=3
    slider=object("WBP_COS_SliderRow_C","/Game/Test.PC.InjectedSlider"); slider.parent=parent; slider.visibility=4; slider.value=1
    launcher=object("UserWidget","/Game/Test.Page.ColorsPlusLauncher_Root_1"); launcher.parent=parent; launcher.visibility=4
    targets={{widget=grid.full,parent=parent.full},{widget=label.full,parent=parent.full},
        {widget=slider.full,parent=parent.full},{widget=launcher.full,parent=parent.full}}
    expected_targets=#targets
end
local function restored()
    assert(grid.visibility==0 and label.visibility==3 and slider.visibility==4 and launcher.visibility==4 and slider.value==1)
end
multi(); visibility.hide(b,root.full,targets)
assert(grid.visibility==2 and label.visibility==2 and slider.visibility==2 and launcher.visibility==2 and visibility.validate(b))
local record=assert(module.parse(shared[module.KEY])); assert(#record.targets==4 and record.targets[4].original==4)
root.parent=nil; assert(visibility.restore()); restored()
-- Failure after a label setter also recovers the untouched later controls.
multi(); fail_hide=label
assert(not pcall(visibility.hide,b,root.full,targets) and grid.visibility==2 and label.visibility==2 and slider.visibility==4)
root.parent=nil; fail_hide=nil; visibility=module.new(a); assert(visibility.restore()); restored()
-- An interrupted restoration retains all intents; retry skips restored targets.
multi(); visibility.hide(b,root.full,targets); root.parent=nil; fail_restore=label
assert(not pcall(visibility.restore) and grid.visibility==0 and label.visibility==2 and slider.visibility==2)
assert(#module.parse(shared[module.KEY]).targets==4)
local before_retry=writes; fail_restore=nil; visibility=module.new(a); assert(visibility.restore()); restored()
assert(writes-before_retry==3,"Retry must not rewrite the already-restored grid")
-- Per-control native changes/reparenting win without preventing other restores.
multi(); visibility.hide(b,root.full,targets); label.visibility=0; slider.parent=overlay
assert(not pcall(visibility.validate,b)); root.parent=nil; assert(visibility.restore())
assert(grid.visibility==0 and label.visibility==0 and slider.visibility==2 and launcher.visibility==4)
-- Recover a v0.2.91 grid-only journal when upgrading within the same process.
reset(4); grid.visibility=2; root.parent=nil
shared[module.KEY]=table.concat({"palette-visibility-v1",grid.full,parent.full,overlay.full,root.full,"4"},"\n") .. "\n"
assert(module.parse(shared[module.KEY])); assert(visibility.restore() and grid.visibility==4)
-- Fresh processes have no shared record, even when transient names repeat.
reset(); visibility.hide(b,root.full); shared={}; grid.visibility=0
visibility=module.new(a); local before=writes
assert(visibility.restore() and writes==before and grid.visibility==0)
-- Malformed or out-of-scope shared strings never authorize native writes.
reset(); visibility.hide(b,root.full); local valid=shared[module.KEY]
for _,bad in ipairs({valid .. "x",valid:gsub("\n0\n$","\n5\n"),
    valid:gsub("BitReactorTileView","OtherWidget",1),valid:gsub("ColorsPlusPicker_Root_1","StockPicker",1),
    valid:gsub("ScrollBox /Game/Test.Tiles.WidgetTree_4.PaletteScroll","ScrollBox /Game/Other.Parent",1),
    "return os.execute('anything')",string.rep("x",131073)}) do
    assert(not module.parse(bad))
    shared[module.KEY]=bad; visibility=module.new(a); before=writes
    assert(not pcall(visibility.restore) and writes==before and shared[module.KEY]==bad)
end
multi(); visibility.hide(b,root.full,targets); valid=shared[module.KEY]
for _,bad in ipairs({valid:gsub("\n4\nBitReactorTileView","\n65\nBitReactorTileView",1),
    valid:gsub("TextBlock /Game/Test.Tiles.WidgetTree_4.Label",grid.full,1),
    valid:gsub("TextBlock /Game/Test.Tiles.WidgetTree_4.Label",parent.full,1),
    valid:gsub("TextBlock /Game/Test.Tiles.WidgetTree_4.Label",overlay.full,1),
    valid:gsub("\nScrollBox /Game/Test.Tiles.WidgetTree_4.PaletteScroll\n3\n","\nScrollBox /Game/Other.Parent\n3\n",1),
    valid:gsub("UserWidget /Game/Test.Page.ColorsPlusLauncher_Root_1",root.full,1)}) do
    assert(not module.parse(bad)); shared[module.KEY]=bad; visibility=module.new(a); before=writes
    assert(not pcall(visibility.restore) and writes==before)
end
ModRef,StaticFindObject=old_mod,old_find
print("Palette visibility: multi-control Hidden layout, exact restoration, fresh wrappers, Lua/process recovery, partial failures and ownership guards passed")
