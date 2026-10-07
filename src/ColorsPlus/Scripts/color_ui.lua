-- Rainbow launcher / lower-pane switch. Only our own children are appended or
-- removed. Native palette controls are temporarily Hidden by the open picker;
-- tiles, list items, focus and switchers are intact.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local ROOT="^UserWidget .+%.ColorsPlusLauncher_Root_(%d+)$"
local buttons=assert(loadfile(directory .. "button_class.lua"))()
local button_clicks=assert(loadfile(directory .. "button_clicks.lua"))()
local palette_layout=assert(loadfile(directory .. "palette_layout.lua"))()
function M.new(runtime,a,tint)
    local self={binding=nil,root_name=nil}
    runtime.gradient_assets=runtime.gradient_assets or assert(loadfile(directory .. "gradient_assets.lua"))()
    local gradients=runtime.gradient_assets
    local palettes=assert(loadfile(directory .. "active_palette.lua"))().new(a)
    local rules=assert(loadfile(directory .. "color_rules.lua"))()
    local lifetime=assert(loadfile(directory .. "creator_lifetime.lua"))().new(a)
    local visibility=assert(loadfile(directory .. "palette_visibility.lua"))().new(a,runtime.log)
    local serial,count,epoch,request=0,0,0,0
    local function log(s) runtime.log("COLOR UI | " .. s) end
    local function timed(label,fn)
        if runtime.perf then return runtime.perf.measure(label,fn) end
        return fn()
    end
    local function call(label,fn)
        return fn()
    end
    local function find(path) if a.find then return a.find(path) end; return StaticFindObject(path) end
    -- Record wrappers already in hand so a first by-name lookup never scans.
    local function remember(v) if runtime.objects then runtime.objects.remember(v) end end
    local function obj(v,label) v=a.unwrap(v); assert(a.live(v),"Color UI unavailable: " .. label); return v end
    local function name(v) return a.name(obj(v,"identity")) end
    local function fresh(full)
        assert(type(full)=="string","Missing color UI identity")
        local v=obj(call("find",function() return find(full:match("^[^ ]+ (.+)$")) end),full)
        assert(name(v)==full,"Color UI identity changed"); return v
    end
    local function parent(v) return obj(call("GetParent",function() return obj(v,"child"):GetParent() end),"parent") end
    local function kind(v) return name(v):match("^([^ ]+) ") end
    local function construct(path,outer,identity)
        count=count+1
        local class=obj(StaticFindObject(path),path)
        return obj(call("construct " .. path,function()
            return StaticConstructObject(class,obj(outer,"outer"),FName(identity or ("ColorsPlusLauncher_Widget_" .. count)))
        end),path)
    end
    local function scan(class,limit)
        local values=FindAllOf(class) or {}; assert(type(values)=="table","Unsupported color UI scan")
        local n=0; for _ in pairs(values) do n=n+1; assert(n<=limit,"Color UI scan limit") end
        return values
    end
    local function discover()
        local page,page_name
        local function active(v) return a.live(v) and v:IsActivated()==true end
        local pages
        if runtime.known then pages=runtime.known.select("WBP_Customization_ItemPage_C",128,active)
        else pages={}; for _,v in pairs(scan("WBP_Customization_ItemPage_C",128)) do if active(v) then pages[#pages+1]=v end end end
        for _,v in ipairs(pages) do assert(not page,"Ambiguous color page"); page=v; page_name=name(v); remember(v) end
        assert(page,"Open a customization color selector")
        local creator=lifetime.bind(page_name) -- creator stack, not merely an inactive visible tree
        -- Same-call object when available: no by-name round trip (scan).
        local vm
        if tint.selected_slot then vm=obj(tint.selected_slot(),"selected slot")
        else vm=fresh(tint.selected_slot_identity()) end
        local vm_name=name(vm); local tag=a.text(vm.SlotTag.TagName)
        assert(rules.launcher_color_slot(tag),"Selected selector is not a color palette")
        local grid=palettes.resolve(page_name,tag)
        local grid_name=name(grid); remember(grid)
        local tree=assert(grid_name:match("^[^ ]+ (.+)%.PartsGridList$"),"Unexpected swatch tree")
        local current=grid; local overlay,stack,chain={},{},{}
        -- Ancestry must remain inside this exact SelectionTiles WidgetTree.
        -- Never borrow a page-wide overlay that also covers the slot header.
        for depth=1,16 do
            current=a.unwrap(call("GetParent",function() return current:GetParent() end))
            if not a.live(current) then break end
            local full=name(current); local path=full:match("^[^ ]+ (.+)$")
            if path:sub(1,#tree+1)~=tree .. "." then break end
            chain[#chain+1]=full; remember(current)
            if kind(current)=="Overlay" and not overlay.name then overlay.name=full end
            if kind(current)=="VerticalBox" and not stack.name then stack.name=full end
            assert(depth<16,"Swatch ancestry limit")
        end
        assert(overlay.name and stack.name,"Swatch tree needs an Overlay and VerticalBox ancestor")
        return {page=page_name,vm=vm_name,tag=tag,grid=grid_name,tree=tree,
            overlay=overlay.name,stack=stack.name,chain=chain,creator=creator}
    end
    function self.validate_picker(b)
        assert(b and self.binding==b,"Color pane ownership ended")
        assert(rules.launcher_color_slot(b.tag),"Selected selector is not a color palette")
        local page=fresh(b.page)
        assert(page:IsActivated()==true,"Color page closed")
        local tiles_path=assert(b.tree:match("^(.+)%.WidgetTree[^.]*$"),"Invalid swatch owner")
        local tiles=obj(find(tiles_path),"selection tiles")
        assert(kind(tiles)=="WBP_Customization_SelectionTiles_C" and tiles:IsVisible()==true
            and a.text(tiles.CurrentSlotTag.TagName)==b.tag
            and name(obj(tiles.PartsGridList,"parts grid"))==b.grid,"Displayed color zone changed")
        -- The verified native owner already returned this grid. Do not repeat
        -- a full-path global lookup within the same synchronous validation.
        local current=obj(tiles.PartsGridList,"parts grid")
        for _,full in ipairs(b.chain) do
            current=parent(current); assert(name(current)==full,"Color pane ancestry changed")
        end
        local root=fresh(self.root_name)
        assert(name(parent(root))==(self.launcher_parent or b.stack),"Rainbow launcher detached")
        visibility.validate(b)
        return true
    end
    -- From the launch press until the picker hides the palette, the swatch
    -- grid ignores the mouse (HitTestInvisible: still drawn). Slate delivers a
    -- hover preview, or the mouse-leave reset of hiding a hovered swatch, on a
    -- later frame; arriving after the preview session started it read as a
    -- context change and closed the picker. Now those land during the 100ms
    -- launch delay, before any session. Scalar identity/original only.
    local frozen
    local function freeze(b)
        if frozen then return end
        local grid=fresh(b.grid)
        local original=grid:GetVisibility()
        if original~=0 and original~=4 then return end -- already ignores the mouse
        frozen={grid=b.grid,original=original}
        grid:SetVisibility(3)
        log("PALETTE INPUT PAUSED | launch pending")
    end
    local function thaw()
        local f=frozen; frozen=nil
        if not f then return end
        -- A destroyed or replaced grid has nothing left to restore.
        local ok,grid=pcall(fresh,f.grid)
        if ok and grid:GetVisibility()==3 then grid:SetVisibility(f.original) end
    end
    -- Palette box layout (measured in-game on v0.3.0). The game caps the
    -- swatch area's height so the palette exactly fills its background box,
    -- and creator overhauls may keep re-applying their own cap. The launcher
    -- never adds height: it sits in the column's overlay, aligned to the
    -- bottom, over a band reserved by extra bottom padding on the swatch
    -- grid's own slot; the capped area keeps its height and the grid scrolls.
    -- The stock padding survives Lua reloads and is restored when the picker
    -- opens and when the launcher retires, only if it still holds our value.
    -- Slots are read through WidgetLayoutLibrary (the Blueprint way); the raw
    -- Slot property is only a fallback.
    local BAND=44+6+2 -- launcher height plus its top/bottom gaps
    local layouts=rawget(_G,"ColorsPlusProbeLauncherBand") or {}
    rawset(_G,"ColorsPlusProbeLauncherBand",layouts)
    local reserved
    local SLOT_AS={VerticalBox="SlotAsVerticalBoxSlot",Overlay="SlotAsOverlaySlot",SizeBox="SlotAsSizeBoxSlot",
        HorizontalBox="SlotAsHorizontalBoxSlot",Border="SlotAsBorderSlot",ScrollBox="SlotAsScrollBoxSlot",
        CanvasPanel="SlotAsCanvasSlot",GridPanel="SlotAsGridSlot",UniformGridPanel="SlotAsUniformGridSlot",
        WrapBox="SlotAsWrapBoxSlot"}
    local function num(fn) local ok,v=pcall(fn); return ok and tonumber(v) or nil end
    local function pad(slot,side) return num(function() return slot.Padding[side] end) or 0 end
    local function slot_of(widget,holder)
        local fn=SLOT_AS[kind(holder)]
        if fn then
            local lib=StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
            if lib and lib:IsValid()==true then
                local ok,v=pcall(function() return a.unwrap(lib[fn](lib,widget)) end)
                if ok and a.live(v) then return v end
            end
        end
        local ok,v=pcall(function() return a.unwrap(widget.Slot) end)
        if ok and a.live(v) then return v end
        error("Unreadable " .. kind(widget) .. " slot in " .. kind(holder))
    end
    local function margin(slot)
        return {Left=pad(slot,"Left"),Top=pad(slot,"Top"),Right=pad(slot,"Right"),Bottom=pad(slot,"Bottom")}
    end
    local function same_margin(p,q)
        for _,k in ipairs({"Left","Top","Right","Bottom"}) do
            if math.abs((p[k] or 0)-(q[k] or 0))>0.01 then return false end
        end
        return true
    end
    local function grid_slot(key)
        local grid=fresh(key)
        return slot_of(grid,parent(grid))
    end
    local function reserve_band(b)
        if reserved then return end
        local s=grid_slot(b.grid)
        local stock=layouts[b.grid] and layouts[b.grid].stock or margin(s)
        local ours={Left=stock.Left,Top=stock.Top,Right=stock.Right,Bottom=stock.Bottom+BAND}
        layouts[b.grid]={stock=stock,ours=ours}
        s:SetPadding(ours)
        reserved=b.grid
        return stock.Bottom,ours.Bottom
    end
    -- Another widget may re-apply the grid's padding after ours: adopt its
    -- value as stock and reserve the band again; back off after a few
    -- corrections rather than fight a widget that keeps resetting it.
    local MAX_RESERVES=3
    local function refresh_band()
        local record=reserved and layouts[reserved]
        if not record then return end
        local ok,s=pcall(grid_slot,reserved)
        if not ok then return end
        local current=margin(s)
        if same_margin(current,record.ours) then return end
        record.resets=(record.resets or 0)+1
        if record.resets>MAX_RESERVES then
            if record.resets==MAX_RESERVES+1 then log("LAUNCHER LAYOUT | band=left to another widget (keeps resetting the grid padding)") end
            return
        end
        record.stock=current
        record.ours={Left=current.Left,Top=current.Top,Right=current.Right,Bottom=current.Bottom+BAND}
        s:SetPadding(record.ours)
        log(string.format("LAUNCHER LAYOUT | band=re-reserved bottom %s->%s (changed by another widget)",
            tostring(current.Bottom),tostring(record.ours.Bottom)))
    end
    local function release_band()
        local key=reserved; reserved=nil
        local record=key and layouts[key]
        if not record then return end
        layouts[key]=nil
        -- A destroyed page has nothing left to restore; padding someone else
        -- changed after us is theirs to keep.
        local ok,s=pcall(grid_slot,key)
        if ok and same_margin(margin(s),record.ours) then s:SetPadding(record.stock) end
    end
    -- Width: the grid's laid-out width derived from the live chain (Slate
    -- geometry is not readable from Lua), then the tile row inside it.
    local function swatch_row(b)
        local records,w={},fresh(b.grid)
        local stack_offset,before_stack,stack_pad=0,true,0
        for _=1,20 do
            local r={desired=num(function() return w:GetDesiredSize().X end)}
            if kind(w)=="SizeBox" and w.bOverride_WidthOverride==true then r.width_override=num(function() return w.WidthOverride end) end
            local up=a.unwrap(w:GetParent())
            if a.live(up) then
                local s=slot_of(w,up)
                r.parent_kind=kind(up); r.h=num(function() return s.HorizontalAlignment end)
                r.pad_l,r.pad_r=pad(s,"Left"),pad(s,"Right")
                r.parent_size_rule=num(function() return s.Size.SizeRule end)
                if before_stack then stack_offset=stack_offset+r.pad_l
                elseif name(w)==b.stack then stack_pad=r.pad_l end
                if name(up)==b.stack then before_stack=false end
            else
                -- A widget-tree root fills its owning UserWidget.
                r.h,r.pad_l,r.pad_r=0,0,0
                local ok,owner=pcall(function() return a.unwrap(w:GetOuter():GetOuter()) end)
                if ok and a.live(owner) then r.parent_kind=kind(owner); up=owner else r.root=true end
            end
            records[#records+1]=r
            if r.width_override or r.root or r.parent_kind=="CanvasPanel"
                or (r.parent_kind=="HorizontalBox" and r.parent_size_rule==0) then break end
            w=up
        end
        local width=assert(palette_layout.column_width(records),"Swatch column width not derivable")
        local grid=fresh(b.grid)
        local row=palette_layout.swatch_row(width,num(function() return grid:GetEntryWidth() end),
            num(function() return grid.HorizontalEntrySpacing end),grid.bEntrySizeIncludesEntrySpacing==true,
            num(function() return grid.TileAlignment end),num(function() return grid:GetNumItems() end))
        row.left=row.left+stack_offset; row.column=width; row.stack_pad=stack_pad
        return row
    end
    local function retire()
        thaw()
        release_band()
        if runtime.perf then runtime.perf.cancel_launch("launcher retired before opening") end
        if runtime.objects then runtime.objects.release("color-ui") end
        epoch=epoch+1
        runtime:cancel("color-ui:poll")
        runtime:cancel("color-ui:launch")
        runtime:cancel("color-ui:open")
        if self.root_name then button_clicks.get(runtime).retire(self.root_name) end
        self.binding=nil; self.button_name=nil; self.launcher_parent=nil
        if self.root_name then
            local root=StaticFindObject(self.root_name:match("^[^ ]+ (.+)$"))
            if a.live(root) then
                assert(name(root)==self.root_name,"Launcher identity changed")
                call("launcher.RemoveFromParent",function() root:RemoveFromParent() end)
                assert(not a.live(a.unwrap(root:GetParent())),"Launcher removal failed")
            end
            self.root_name=nil
        end
    end
    function self.close(reason)
        request=request+1
        runtime:cancel("color-ui:install")
        retire(); log("CLOSED | " .. (reason or "context ended"))
    end
    function self.cleanup()
        assert(not self.root_name,"Retire current launcher before cleanup")
        for _,root in pairs(scan("UserWidget",8192)) do
            if a.live(root) then
                local suffix=name(root):match(ROOT)
                if suffix then serial=math.max(serial,tonumber(suffix)); root:RemoveFromParent() end
            end
        end
    end
    -- Clicks arrive through the CommonUI hook (button_clicks) inside native
    -- dispatch: latch and schedule only. The launch job pauses swatch input
    -- and defers opening until the click frame has retired.
    local function launch(b,generation)
        if generation~=epoch or self.binding~=b or self.picker_owner or runtime.picker.active then return end
        if runtime.perf then runtime.perf.begin_picker("Custom Color button",b.tag) end
        local paused,why=pcall(freeze,b)
        if not paused then log("PALETTE INPUT PAUSE FAILED | " .. tostring(why)) end
        runtime:after("color-ui:open",100,function()
            if generation~=epoch or self.binding~=b then thaw(); return end
            local valid,why=pcall(self.validate_picker,b)
            if valid then
                runtime.color_host=nil; runtime.color_backend=nil -- the character editor's own
                log("LAUNCH | " .. b.tag); runtime.picker.open()
            else
                log("LAUNCH REFUSED | " .. tostring(why))
                if runtime.perf then runtime.perf.cancel_launch("launch refused: " .. tostring(why)) end
            end
            -- No-op after a successful open (hide_palette took over).
            thaw()
        end)
    end
    local function clicked(b,generation)
        if runtime.picker.active then return end
        runtime:after("color-ui:launch",1,function() launch(b,generation) end)
    end
    -- Backstop only: native context hooks drive reconciliation, and a launch
    -- validates afresh. This catches a pane changed without a hooked event.
    local function poll(b,generation,delay)
        runtime:after("color-ui:poll",delay or 500,function()
            if generation~=epoch or self.binding~=b then return end
            -- The picker validates this exact binding on every UI read.
            if self.picker_owner or runtime.picker.active then poll(b,generation); return end
            local ok,err=pcall(self.validate_picker,b)
            if ok then
                local refreshed,why=pcall(refresh_band)
                if not refreshed then log("LAUNCHER LAYOUT | height check failed | " .. tostring(why):match("[^:]*$")) end
                poll(b,generation); return
            end
            log("RETIRED | " .. tostring(err))
            if runtime.picker.active then runtime.picker.close("color pane context ended") end
            local removed,why=pcall(retire)
            if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
        end)
    end
    local function install(b)
        assert(not self.root_name,"Launcher cleanup required")
        -- Released by retire(), which every failed install also runs.
        if runtime.objects then runtime.objects.hold("color-ui") end
        serial=serial+1
        local root=construct("/Script/UMG.UserWidget",fresh(b.page),"ColorsPlusLauncher_Root_" .. serial)
        self.root_name=name(root); remember(root)
        assert(self.root_name:match(ROOT),"Unexpected launcher root")
        root:SetVisibility(4); root.bIsFocusable=false
        local tree=construct("/Script/UMG.WidgetTree",root); root.WidgetTree=tree
        -- Absorb remaining vertical selector space; only the footer button is
        -- hit-testable. Stock list sizing/children are not modified.
        local footer=construct("/Script/UMG.Overlay",tree); tree.RootWidget=footer; footer:SetVisibility(4)
        local size=construct("/Script/UMG.SizeBox",footer); size:SetHeightOverride(44)
        local footer_slot=footer:AddChild(size); footer_slot:SetHorizontalAlignment(0); footer_slot:SetVerticalAlignment(2)
        local footer_size=size
        local row=construct("/Script/UMG.HorizontalBox",size); size:AddChild(row)
        local rainbow=construct("/Script/UMG.Image",row)
        call("rainbow gradient",function() gradients.bind(rainbow,"hue") end)
        local box=construct("/Script/UMG.SizeBox",row)
        box:SetWidthOverride(42); box:SetHeightOverride(24); box:AddChild(rainbow)
        local rainbow_slot=row:AddChild(box); rainbow_slot:SetVerticalAlignment(2)
        rainbow_slot:SetPadding({Left=0,Top=0,Right=8,Bottom=0})
        -- CreateWidget initializes the Blueprint button (style, text, click
        -- wiring); a bare StaticConstructObject would not.
        local pc=obj(call("GetPlayerController",function()
            if runtime.known then return runtime.known.player_controller() end
            return require("UEHelpers").GetPlayerController()
        end),"player controller")
        -- A class default object: a.live() rejects Default__ names by design.
        local library=StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        assert(library and library:IsValid()==true,"Color UI unavailable: widget library")
        local class=obj(buttons.find(log),"launcher button class")
        local button=obj(call("launcher.Create",function() return library:Create(pc,class,pc) end),"native launcher button")
        assert(name(button):match("^WBP_CharacterDataBank_TopNavButton_C /"),"Unexpected launcher button class")
        button:SetIsFocusable(false); button:SetIsSelectable(false); button:SetIsToggleable(false)
        self.button_name=name(button); remember(button)
        local button_slot=row:AddChild(button); button_slot:SetSize({SizeRule=1,Value=1}); button_slot:SetVerticalAlignment(2)
        -- Keep the launcher inside the palette box and as wide as the swatches.
        -- Reserve the band first; only then sit in the overlay over it. Without
        -- a band the launcher stays below the swatches (it never covers them).
        local stack=fresh(b.stack)
        local banded,stock_pad,our_pad=false,"column is not in an overlay"
        if name(parent(stack))==b.overlay then banded,stock_pad,our_pad=pcall(reserve_band,b) end
        local holder=banded and fresh(b.overlay) or stack
        local slot=holder:AddChild(root)
        self.launcher_parent=name(holder)
        if banded then
            slot:SetHorizontalAlignment(0); slot:SetVerticalAlignment(3)
            slot:SetPadding({Left=0,Top=0,Right=0,Bottom=2})
        else
            slot:SetPadding({Left=0,Top=6,Right=0,Bottom=2})
            slot:SetSize({SizeRule=0,Value=1})
        end
        local fitted,row=pcall(swatch_row,b)
        if fitted then
            footer_size:SetWidthOverride(row.width)
            footer_slot:SetHorizontalAlignment(1)
            footer_slot:SetPadding({Left=row.left+(banded and row.stack_pad or 0),Top=0,Right=0,Bottom=0})
        end
        log(string.format("LAUNCHER LAYOUT | height=%s | width=%s",
            banded and string.format("band bottom %s->%s",tostring(stock_pad),tostring(our_pad)) or ("below swatches (" .. tostring(stock_pad):match("[^:]*$") .. ")"),
            fitted and string.format("%.1f left=%.1f column=%.1f per_line=%d align=%s",row.width,row.left,row.column,row.per_line,row.align)
                or ("full (" .. tostring(row):match("[^:]*$") .. ")")))
        -- Reacquire after native attachment/Construct before setting text.
        fresh(self.button_name):UpdateText(FText("CUSTOM COLOR"))
        local generation=epoch
        button_clicks.get(runtime).bind(self.button_name,self.root_name,"launch",function() clicked(b,generation) end)
        self.binding=b
        self.validate_picker(b)
        log("ATTACHED | slot=" .. b.tag .. " | grid=" .. b.grid .. " | overlay=" .. b.overlay .. " | stack=" .. b.stack)
        -- First check soon: other widgets settle their layout after the page builds.
        poll(b,epoch,100)
    end
    function self.reconcile()
        -- Reuse only a live binding whose selected VM, active palette, creator
        -- stack and ancestry are all verified now. No cached native wrappers.
        if self.binding then
            local b=self.binding
            local ok=pcall(timed,"context.reuse_binding",function()
                self.validate_picker(b)
                assert(lifetime.active(b.creator),"Creator changed")
                assert(tint.selected_slot_identity()==b.vm,"Selected VM changed")
                assert(name(palettes.resolve(b.page,b.tag))==b.grid,"Active palette changed")
            end)
            if ok then return b end
        end
        local b=timed("context.discover",function() return discover() end)
        if self.binding and self.binding.page==b.page and self.binding.vm==b.vm
            and self.binding.grid==b.grid and self.binding.tag==b.tag then
            self.validate_picker(self.binding); return self.binding
        end
        if runtime.picker.active then runtime.picker.close("color zone changed") end
        retire()
        local ok,err=pcall(install,b)
        if not ok then local cleaned,why=pcall(retire); if not cleaned then log("CLEANUP FAILED | " .. tostring(why)) end; error(err,0) end
        return self.binding
    end
    function self.prepare_picker()
        local b=self.reconcile() -- reconcile already verified this binding
        -- This exact SelectionTiles ancestor is already the lower selector
        -- region. Let native layout fill it; do not round-trip opaque FGeometry
        -- through reflected Lua calls (v0.2.68 produced unreadable positions).
        -- The slot/zone header outside SelectionTiles remains untouched.
        log("SWITCH | layout=fill | " .. b.tag)
        return b
    end
    function self.hide_palette(b,root_name)
        -- Restore the true original first, in this same synchronous call, so
        -- the visibility record and later restore keep the stock value.
        thaw()
        release_band() -- the picker keeps the stock swatch layout
        self.validate_picker(b)
        -- Hide disjoint native branches beside the grid's ancestry. This also
        -- covers mod-added labels/sliders without guessing their names, while
        -- keeping every ancestor of our picker visible and laid out.
        local protected={[b.grid]=true,[root_name]=true,[self.root_name]=true}
        for _,full in ipairs(b.chain) do protected[full]=true end
        local targets,seen={},{}
        local function add(full,owner)
            assert(not seen[full],"Duplicate palette visibility target")
            assert(#targets<64,"Palette controls limit")
            seen[full]=true; targets[#targets+1]={widget=full,parent=owner}
        end
        add(b.grid,b.chain[1])
        for _,owner in ipairs(b.chain) do
            local children=a.values(call("GetAllChildren",function() return fresh(owner):GetAllChildren() end))
            assert(#children<=64,"Palette siblings limit")
            for _,child in ipairs(children) do
                local full=name(child); remember(child)
                assert(name(parent(child))==owner,"Palette child ownership changed")
                -- Injected UserWidgets may have a different UObject outer.
                -- Their verified panel parent defines the palette UI branch.
                if not protected[full] then add(full,owner) end
            end
        end
        add(self.root_name,self.launcher_parent or b.stack)
        visibility.hide(b,root_name,targets)
        self.picker_owner=root_name
    end
    function self.release_picker(b)
        visibility.restore() -- Keep the verified launcher when the pane closes.
        self.picker_owner=nil
        if self.binding and self.launcher_parent==self.binding.overlay then
            local ok,why=pcall(reserve_band,self.binding)
            if not ok then log("LAUNCHER LAYOUT | band unavailable | " .. tostring(why):match("[^:]*$")) end
        end
    end
    function self.context_changed(reason)
        if reason=="page closed" or reason=="creator closed" then
            if runtime.perf then runtime.perf.cancel_launch(reason) end
            request=request+1
            epoch=epoch+1; self.binding=nil
            runtime:cancel("color-ui:poll"); runtime:cancel("color-ui:launch"); runtime:cancel("color-ui:open"); runtime:cancel("color-ui:install")
            runtime:after("color-ui:retire",1,function() self.close(reason) end)
            return
        end
        -- Hover/reset events do not trigger new discovery. A displayed slot
        -- change is checked by the active poll and these native update events.
        if reason~="UpdateCurrentCustomizationSlotVM" and reason~="UpdateRootCustomizationSlotVM"
            and reason~="BP_OnActivated" and reason~="DisplayCustomizationList" and reason~="startup" then return end
        runtime:cancel("color-ui:retire")
        request=request+1
        local generation=request
        local function attempt(left)
            runtime:after("color-ui:install",150,function()
                if generation~=request then return end
                local ok,err=pcall(self.reconcile)
                if ok then return end
                if left>1 then attempt(left-1) else
                    log("NOT ATTACHED | " .. tostring(err))
                    local removed,why=pcall(retire); if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
                end
            end)
        end
        attempt(4)
    end
    function self.start()
        runtime:after("color-ui:startup",1,function()
            local ok,err=pcall(self.cleanup)
            if not ok then log("STALE CLEANUP FAILED | " .. tostring(err)); return end
            self.context_changed("startup")
        end)
    end
    return self
end
return M
