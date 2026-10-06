-- Rainbow launcher / lower-pane switch. Only our own children are appended or
-- removed. Native palette controls are temporarily Hidden by the open picker;
-- tiles, list items, focus and switchers are intact.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local ROOT="^UserWidget .+%.ColorsPlusLauncher_Root_(%d+)$"
-- The game's own CommonUI button, as used by the picker's Apply/Cancel: its
-- HandleButtonClicked UFunction is hookable, so launches need no input poll.
local BUTTON_CLASS="/Game/Game/UI/Strategy/Customization/Widgets/CharacterDatabank/WBP_CharacterDataBank_TopNavButton.WBP_CharacterDataBank_TopNavButton_C"
local button_clicks=assert(loadfile(directory .. "button_clicks.lua"))()
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
        if runtime.call_trace then return runtime.call_trace.call("COLOR UI " .. label,fn) end
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
        for _,v in pairs(scan("WBP_Customization_ItemPage_C",128)) do
            if a.live(v) and v:IsActivated()==true then assert(not page,"Ambiguous color page"); page=v; page_name=name(v); remember(v) end
        end
        assert(page,"Open a customization color selector")
        local creator=lifetime.bind(page_name) -- creator stack, not merely an inactive visible tree
        local vm_name=tint.selected_slot_identity()
        local vm=fresh(vm_name); local tag=a.text(vm.SlotTag.TagName)
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
        assert(name(parent(root))==b.stack,"Rainbow launcher detached")
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
    local function retire()
        thaw()
        if runtime.perf then runtime.perf.cancel_launch("launcher retired before opening") end
        if runtime.objects then runtime.objects.release("color-ui") end
        epoch=epoch+1
        runtime:cancel("color-ui:poll")
        runtime:cancel("color-ui:launch")
        runtime:cancel("color-ui:open")
        if self.root_name then button_clicks.get(runtime).retire(self.root_name) end
        self.binding=nil; self.button_name=nil
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
            if valid then log("LAUNCH | " .. b.tag); runtime.picker.open()
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
    local function poll(b,generation)
        runtime:after("color-ui:poll",500,function()
            if generation~=epoch or self.binding~=b then return end
            -- The picker validates this exact binding on every UI read.
            if self.picker_owner or runtime.picker.active then poll(b,generation); return end
            local ok,err=pcall(self.validate_picker,b)
            if ok then poll(b,generation); return end
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
        local row=construct("/Script/UMG.HorizontalBox",size); size:AddChild(row)
        local rainbow=construct("/Script/UMG.Image",row)
        call("rainbow gradient",function() gradients.bind(rainbow,"hue") end)
        local box=construct("/Script/UMG.SizeBox",row)
        box:SetWidthOverride(42); box:SetHeightOverride(24); box:AddChild(rainbow)
        local rainbow_slot=row:AddChild(box); rainbow_slot:SetVerticalAlignment(2)
        rainbow_slot:SetPadding({Left=0,Top=0,Right=8,Bottom=0})
        -- CreateWidget initializes the Blueprint button (style, text, click
        -- wiring); a bare StaticConstructObject would not.
        local pc=obj(call("GetPlayerController",function() return require("UEHelpers").GetPlayerController() end),"player controller")
        -- A class default object: a.live() rejects Default__ names by design.
        local library=StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        assert(library and library:IsValid()==true,"Color UI unavailable: widget library")
        local class=obj(StaticFindObject(BUTTON_CLASS),"launcher button class")
        local button=obj(call("launcher.Create",function() return library:Create(pc,class,pc) end),"native launcher button")
        assert(name(button):match("^WBP_CharacterDataBank_TopNavButton_C /"),"Unexpected launcher button class")
        button:SetIsFocusable(false); button:SetIsSelectable(false); button:SetIsToggleable(false)
        self.button_name=name(button); remember(button)
        local button_slot=row:AddChild(button); button_slot:SetSize({SizeRule=1,Value=1}); button_slot:SetVerticalAlignment(2)
        local slot=fresh(b.stack):AddChild(root)
        slot:SetPadding({Left=0,Top=6,Right=0,Bottom=2})
        slot:SetSize({SizeRule=1,Value=1})
        -- Reacquire after native attachment/Construct before setting text.
        fresh(self.button_name):UpdateText(FText("CUSTOM COLOR"))
        local generation=epoch
        button_clicks.get(runtime).bind(self.button_name,self.root_name,"launch",function() clicked(b,generation) end)
        self.binding=b
        self.validate_picker(b)
        log("ATTACHED | slot=" .. b.tag .. " | grid=" .. b.grid .. " | overlay=" .. b.overlay .. " | stack=" .. b.stack)
        poll(b,epoch)
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
        add(self.root_name,b.stack)
        visibility.hide(b,root_name,targets)
        self.picker_owner=root_name
    end
    function self.release_picker(b)
        visibility.restore() -- Keep the verified launcher when the pane closes.
        self.picker_owner=nil
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
