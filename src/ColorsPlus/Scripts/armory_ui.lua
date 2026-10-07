-- Custom Color button on the vanilla Paint Color row of Armory > Customize
-- Weapon > COLOR, and the picker's host there (the same calls color_ui
-- answers in the character editors: binding, prepare_picker,
-- validate_picker, hide_palette, release_picker). The backend is
-- armory_paint. Scalar identities only; every use re-finds and re-checks.
-- Discovery runs only while the Customize Weapon screen is active (its own
-- hooks, see customization_probe): the armory classes do not exist anywhere
-- else, and looking for them would cost a full object scan each time.
local M={}
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local SCREEN="WBP_Menu_Armory_CustomizeWeapon_C"
local SECTION="WBP_CustomizationSection_Tiles_C"
local ROW_WIDGET="WBP_Customization_PartTiles_C"
local ROOT="^UserWidget .+%.ColorsPlusArmory_Root_(%d+)$"
local buttons=assert(loadfile(directory .. "button_class.lua"))()
local button_clicks=assert(loadfile(directory .. "button_clicks.lua"))()
function M.new(runtime,a)
    local self={binding=nil,root_name=nil,button_name=nil,picker_owner=nil,screen=nil}
    local paint_module=assert(loadfile(directory .. "armory_paint.lua"))()
    -- Row checks belong to the backend instance (runtime.armory_paint).
    local paint={TAG=paint_module.TAG,qualifies=function(row)
        return runtime.armory_paint~=nil and runtime.armory_paint.qualifies(row)
    end,row=function(vm)
        return runtime.armory_paint~=nil and runtime.armory_paint.paint_row(vm) or nil
    end}
    runtime.gradient_assets=runtime.gradient_assets or assert(loadfile(directory .. "gradient_assets.lua"))()
    local gradients=runtime.gradient_assets
    local serial,epoch,request=0,0,0
    local hidden={} -- {widget=full,original=visibility} while the picker is open
    local function log(s) runtime.log("ARMORY UI | " .. tostring(s):gsub("[\r\n]"," ")) end
    local function obj(v,label) v=a.unwrap(v); assert(a.live(v),"Armory UI unavailable: " .. (label or "object")); return v end
    local function name(v) return a.name(obj(v)) end
    local function kind(v) return name(v):match("^([^ ]+) ") end
    local function fresh(full,label)
        local v=a.unwrap((a.find or StaticFindObject)(assert(full:match("^[^ ]+ (.+)$"),"Invalid identity")))
        assert(a.live(v) and a.name(v)==full,(label or "Armory widget") .. " changed")
        return v
    end
    local function remember(v) if runtime.objects then runtime.objects.remember(v) end end
    local function select(class,limit,accept)
        if runtime.known then return runtime.known.select(class,limit,accept) end
        local out={}
        for _,v in pairs(FindAllOf(class) or {}) do if accept(a.unwrap(v)) then out[#out+1]=a.unwrap(v) end end
        return out
    end
    local function construct(path,outer,identity)
        local class=obj(StaticFindObject(path),path)
        return obj(StaticConstructObject(class,obj(outer,"outer"),FName(identity)),path)
    end
    function self.bound_row() return self.binding and self.binding.row end

    -- Discovery ---------------------------------------------------------------
    local function active_screen()
        if self.screen then
            local ok,screen=pcall(fresh,self.screen,"Customize Weapon screen")
            if ok and screen:IsActivated()==true then return screen end
        end
        local found=select(SCREEN,8,function(v) return a.live(v) and v:IsActivated()==true end)
        assert(#found==1,"Open Armory > Customize Weapon (found " .. #found .. " active screens)")
        self.screen=name(found[1])
        return found[1]
    end
    local function discover()
        local screen=active_screen()
        local screen_name=name(screen)
        local prefix=screen_name:match("^[^ ]+ (.+)$") .. ".WidgetTree"
        -- Vanilla Paint Color rows on every live weapon customization VM.
        local rows={}
        select("VM_WeaponCustomization_C",16,function(vm)
            if not a.live(vm) then return false end
            local r=paint.row(vm)
            if not r then return false end
            local index
            for i,row in ipairs(a.values(a.prop(vm,"ColorSlotVMs") or {})) do if a.unwrap(row)==r or name(row)==name(r) then index=i; break end end
            local f=obj(a.values(r:GetFragments())[1],"paint fragment")
            rows[#rows+1]={row=r,index=index,fragment=name(f)}
            return true
        end)
        assert(#rows>0,"No vanilla Paint Color row on this weapon")
        -- The COLOR section shown on this screen.
        local sections=select(SECTION,8,function(s)
            return a.live(s) and name(s):match("^[^ ]+ (.+)$"):sub(1,#prefix)==prefix and s:IsVisible()==true
        end)
        assert(#sections==1,"Open the COLOR section (found " .. #sections .. ")")
        local section=sections[1]
        local entries=a.values(obj(section.TileEntries,"colour rows"):GetAllEntries())
        assert(#entries<=32,"Too many colour rows")
        -- Pair the row VM with its row widget: the widget's swatch grid holds
        -- the row's equipped swatch; entry order breaks ties with the VM order.
        local pairs_found={}
        for e,entry in ipairs(entries) do
            local w=a.unwrap(entry)
            if a.live(w) and kind(w)==ROW_WIDGET and w:IsVisible()==true then
                local grid=a.unwrap(w.PartsGrid)
                if a.live(grid) then
                    for _,r in ipairs(rows) do
                        local index=grid:GetIndexForItem(r.row.EquippedCustomizationPartViewModel)
                        if type(index)=="number" and index>=0 then pairs_found[#pairs_found+1]={r=r,entry=w,grid=grid,e=e} end
                    end
                end
            end
        end
        if #pairs_found>1 then
            local ordered={}
            for _,p in ipairs(pairs_found) do if p.e==p.r.index then ordered[#ordered+1]=p end end
            if #ordered>=1 then pairs_found=ordered end
        end
        local fragments={}
        for _,p in ipairs(pairs_found) do fragments[p.r.fragment]=true end
        local distinct=0; for _ in pairs(fragments) do distinct=distinct+1 end
        assert(#pairs_found>=1,"Paint Color row widget not found on screen")
        assert(distinct==1 and #pairs_found==1,"Ambiguous Paint Color row (" .. #pairs_found .. " widgets, " .. distinct .. " weapons)")
        local p=pairs_found[1]
        -- The grid's ancestry inside its row widget: an Overlay hosts the
        -- picker, a VerticalBox takes the launcher below the swatches.
        local entry_name=name(p.entry)
        local tree=entry_name:match("^[^ ]+ (.+)$") .. ".WidgetTree"
        local chain,overlay,stack={},nil,nil
        local current=p.grid
        for depth=1,12 do
            current=a.unwrap(current:GetParent())
            if not a.live(current) then break end
            local full=name(current)
            if full:match("^[^ ]+ (.+)$"):sub(1,#tree)~=tree then break end
            chain[#chain+1]=full; remember(current)
            if kind(current)=="Overlay" and not overlay then overlay=full end
            if kind(current)=="VerticalBox" and not stack then stack=full end
            assert(depth<12,"Row ancestry limit")
        end
        log("FOUND | row=" .. name(p.r.row) .. " | entry=" .. entry_name .. " | grid=" .. name(p.grid)
            .. " | ancestry=" .. table.concat((function() local t={} for _,c in ipairs(chain) do t[#t+1]=c:match("^([^ ]+) ") end return t end)()," < "))
        assert(overlay and stack,"Paint Color row needs an Overlay and VerticalBox around its swatches")
        return {screen=screen_name,section=name(section),entry=entry_name,grid=name(p.grid),row=name(p.r.row),
            fragment=p.r.fragment,overlay=overlay,stack=stack,chain=chain,tag=paint.TAG}
    end
    -- Changing Location or Finish can recreate the row VMs while the row
    -- widget stays: follow the weapon's paint fragment to its new row VM.
    local function rebind_row(b)
        local found={}
        select("VM_WeaponCustomization_C",16,function(vm)
            if not a.live(vm) then return false end
            local r=paint.row(vm)
            if r and name(obj(a.values(r:GetFragments())[1],"paint fragment"))==b.fragment then found[#found+1]=name(r); return true end
            return false
        end)
        if #found==1 then
            log("ROW REBOUND | " .. b.row .. " -> " .. found[1])
            b.row=found[1]; return
        end
        -- Another weapon (or a new paint fragment) in the same row widget:
        -- with no picker open, keep the launcher where discovery lands on the
        -- same widgets (a new button would show its designer text again).
        assert(not self.picker_owner,"Paint Color row changed (" .. #found .. " rows hold the weapon's paint)")
        local d=discover()
        assert(d.section==b.section and d.entry==b.entry and d.grid==b.grid and d.stack==b.stack
            and table.concat(d.chain,"|")==table.concat(b.chain,"|"),"Paint Color row moved")
        log("ROW REBOUND | weapon paint changed | " .. b.row .. " -> " .. d.row)
        b.row=d.row; b.fragment=d.fragment
    end
    local function validate(b)
        assert(b and self.binding==b,"Armory pane ownership ended")
        local screen=fresh(b.screen,"Customize Weapon screen")
        assert(screen:IsActivated()==true,"Customize Weapon closed")
        local section=fresh(b.section,"COLOR section")
        assert(section:IsVisible()==true,"COLOR section hidden")
        local entry=fresh(b.entry,"Paint Color row widget")
        local ok,row=pcall(fresh,b.row,"Paint Color row")
        if not (ok and paint.qualifies(row)) then rebind_row(b) end
        local grid=obj(entry.PartsGrid,"swatch grid")
        assert(name(grid)==b.grid,"Swatch grid replaced")
        local current=grid
        for _,full in ipairs(b.chain) do current=obj(current:GetParent(),"row ancestor"); assert(name(current)==full,"Row ancestry changed") end
        if self.root_name then
            local root=fresh(self.root_name,"Custom Color button")
            assert(name(obj(root:GetParent(),"button parent"))==b.stack,"Custom Color button detached")
        end
        return true
    end

    -- Launcher ------------------------------------------------------------------
    local function retire()
        epoch=epoch+1
        runtime:cancel("armory-ui:poll"); runtime:cancel("armory-ui:open")
        if self.root_name then button_clicks.get(runtime).retire(self.root_name) end
        if runtime.objects then runtime.objects.release("armory-ui") end
        self.binding=nil; self.button_name=nil
        if self.root_name then
            local ok,root=pcall(fresh,self.root_name,"Custom Color button")
            if ok then root:RemoveFromParent() end
            self.root_name=nil
        end
    end
    local function launch(b,generation)
        if generation~=epoch or self.binding~=b or self.picker_owner or runtime.picker.active then return end
        if runtime.perf then runtime.perf.begin_picker("Custom Color button (armory)",b.tag) end
        runtime:after("armory-ui:open",100,function()
            if generation~=epoch or self.binding~=b then return end
            local ok,why=pcall(validate,b)
            if not ok then
                log("LAUNCH REFUSED | " .. tostring(why))
                if runtime.perf then runtime.perf.cancel_launch("launch refused: " .. tostring(why)) end
                return
            end
            -- This picker session talks to the armory backend and host.
            runtime.color_host=self; runtime.color_backend=runtime.armory_paint
            log("LAUNCH | " .. b.row)
            if not runtime.picker.open() and not runtime.picker.active then
                runtime.color_host=nil; runtime.color_backend=nil
            end
        end)
    end
    local function poll(b,generation,delay)
        runtime:after("armory-ui:poll",delay or 500,function()
            if generation~=epoch or self.binding~=b then return end
            local ok,err=pcall(validate,b)
            if ok then
                -- The button can reset its label to the designer text after
                -- it is placed (seen up to seconds later): keep setting it.
                if self.button_name and not self.picker_owner then
                    pcall(function() fresh(self.button_name,"Custom Color button"):UpdateText(FText("CUSTOM COLOR")) end)
                end
                poll(b,generation); return
            end
            log("RETIRED | " .. tostring(err))
            if self.picker_owner and runtime.picker.active then runtime.picker.close("armory row changed") end
            local removed,why=pcall(retire)
            if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
        end)
    end
    local function install(b)
        assert(not self.root_name,"Armory launcher cleanup required")
        if runtime.objects then runtime.objects.hold("armory-ui") end
        serial=serial+1
        local root=construct("/Script/UMG.UserWidget",fresh(b.entry,"Paint Color row widget"),"ColorsPlusArmory_Root_" .. serial)
        self.root_name=name(root); remember(root)
        assert(self.root_name:match(ROOT),"Unexpected armory launcher root")
        root:SetVisibility(4); root.bIsFocusable=false
        local tree=construct("/Script/UMG.WidgetTree",root,"WidgetTree"); root.WidgetTree=tree
        local size=construct("/Script/UMG.SizeBox",tree,"ColorsPlusArmory_Size_" .. serial); tree.RootWidget=size
        size:SetHeightOverride(40)
        local row=construct("/Script/UMG.HorizontalBox",size,"ColorsPlusArmory_Row_" .. serial); size:AddChild(row)
        local rainbow=construct("/Script/UMG.Image",row,"ColorsPlusArmory_Hue_" .. serial)
        gradients.bind(rainbow,"hue")
        local box=construct("/Script/UMG.SizeBox",row,"ColorsPlusArmory_HueBox_" .. serial)
        box:SetWidthOverride(42); box:SetHeightOverride(24); box:AddChild(rainbow)
        local box_slot=row:AddChild(box); box_slot:SetVerticalAlignment(2)
        box_slot:SetPadding({Left=0,Top=0,Right=8,Bottom=0})
        local pc=obj(runtime.known and runtime.known.player_controller() or require("UEHelpers").GetPlayerController(),"player controller")
        local library=StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        assert(library and library:IsValid()==true,"Widget library unavailable")
        local class=obj(buttons.find(log),"button class")
        local button=obj(library:Create(pc,class,pc),"Custom Color button")
        button:SetIsFocusable(false); button:SetIsSelectable(false); button:SetIsToggleable(false)
        self.button_name=name(button); remember(button)
        local button_slot=row:AddChild(button); button_slot:SetSize({SizeRule=1,Value=1}); button_slot:SetVerticalAlignment(2)
        local slot=fresh(b.stack,"row column"):AddChild(root)
        slot:SetPadding({Left=0,Top=6,Right=0,Bottom=2})
        fresh(self.button_name,"Custom Color button"):UpdateText(FText("CUSTOM COLOR"))
        local generation=epoch
        button_clicks.get(runtime).bind(self.button_name,self.root_name,"launch",function()
            if runtime.picker.active then return end
            runtime:after("armory-ui:launch",1,function() launch(b,generation) end)
        end)
        self.binding=b
        validate(b)
        log("ATTACHED | row=" .. b.row .. " | entry=" .. b.entry)
        poll(b,epoch,100)
    end
    function self.reconcile()
        if self.binding and pcall(validate,self.binding) then return self.binding end
        if self.picker_owner then return nil end -- never rebind under an open picker
        local b=discover()
        if self.binding and self.binding.entry==b.entry and self.binding.row==b.row and self.binding.grid==b.grid then return self.binding end
        local removed,why=pcall(retire)
        if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
        local ok,err=pcall(install,b)
        if not ok then
            log("ATTACH FAILED | " .. tostring(err))
            pcall(retire)
            error(err,0)
        end
        return b
    end

    -- Picker host (picker_view) ---------------------------------------------------
    function self.prepare_picker()
        local b=assert(self.binding,"No armory Paint Color row bound")
        validate(b)
        log("SWITCH | picker in the Paint Color row")
        return b
    end
    function self.validate_picker(b) return validate(b) end
    function self.hide_palette(b,root_name)
        validate(b)
        hidden={}
        for _,full in ipairs({b.grid,self.root_name}) do
            local w=fresh(full,"row widget")
            hidden[#hidden+1]={widget=full,original=w:GetVisibility()}
            w:SetVisibility(1) -- collapsed: the picker takes the row's place
        end
        self.picker_owner=root_name
        log("PALETTE HIDDEN | " .. #hidden .. " widgets")
    end
    -- picker_view also calls release_picker(nil) during its pre-open cleanup:
    -- only a real release of an armory picker hands control back.
    function self.release_picker(b)
        if b==nil and not self.picker_owner then return end
        for _,h in ipairs(hidden) do
            local ok,w=pcall(fresh,h.widget,"row widget")
            if ok then w:SetVisibility(h.original) end
        end
        hidden={}
        self.picker_owner=nil
        if runtime.color_host==self then runtime.color_host=nil end
        if runtime.color_backend==runtime.armory_paint then runtime.color_backend=nil end
    end

    -- Events --------------------------------------------------------------------
    -- identity: the screen's full name for armory screen events.
    function self.context_changed(reason,identity)
        if reason=="armory deactivated" then
            if self.picker_owner and runtime.picker.active then runtime.picker.close("armory closed") end
            request=request+1; self.screen=nil
            runtime:cancel("armory-ui:install")
            local removed,why=pcall(retire)
            if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
            return
        end
        if reason=="armory activated" or reason=="armory section" then
            if type(identity)=="string" then self.screen=identity end
        elseif reason~="armory hooks ready" and not self.screen then
            return -- not in Customize Weapon: never look for armory widgets
        end
        if self.picker_owner then return end
        request=request+1
        local generation=request
        local function attempt(left)
            runtime:after("armory-ui:install",150,function()
                if generation~=request then return end
                local ok,err=pcall(self.reconcile)
                if ok then return end
                if left>1 then attempt(left-1) else
                    -- Hooks can install after leaving the armory (the class
                    -- stays loaded): stay quiet unless a screen was seen.
                    if self.screen then log("NOT ATTACHED | " .. tostring(err)) end
                    local removed,why=pcall(retire); if not removed then log("CLEANUP FAILED | " .. tostring(why)) end
                end
            end)
        end
        attempt(3)
    end
    function self.start()
        runtime:after("armory-ui:startup",1,function()
            -- A Lua reload can leave a launcher behind: remove only ours.
            local ok,err=pcall(function()
                for _,root in pairs(FindAllOf("UserWidget") or {}) do
                    root=a.unwrap(root)
                    if a.live(root) then
                        local suffix=a.name(root):match(ROOT)
                        if suffix then serial=math.max(serial,tonumber(suffix)); root:RemoveFromParent() end
                    end
                end
            end)
            if not ok then log("STALE CLEANUP FAILED | " .. tostring(err)) end
        end)
    end
    return self
end
return M
