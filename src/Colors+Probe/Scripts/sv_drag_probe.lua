-- Isolated, fixed-layout drag test: no tint backend, save, source, input-mode,
-- geometry conversion or FEventReply writes. Native Button owns mouse capture.
local directory=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local input_state=assert(loadfile(directory .. "sv_input_state.lua"))()
local M={}
local ROOT="^UserWidget .+%.ColorsPlusSVProbe_Root_(%d+)$"
local HOOK="/Script/UMG.UserWidget:OnPreviewMouseButtonDown"
local RECT={x=52,y=235,w=400,h=240}
function M.new(runtime)
    local self={active=nil,root_name=nil}
    local serial,count=0,0
    runtime.gradient_assets=runtime.gradient_assets or assert(loadfile(directory .. "gradient_assets.lua"))()
    local function log(s) runtime.log("SV INPUT PROBE | " .. s) end
    local function valid(o) return o and o:IsValid() end
    local function required(o,label) assert(valid(o),"SV probe object unavailable: " .. label); return o end
    local function fresh(name)
        local o=required(StaticFindObject(assert(name:match("^[^ ]+ (.+)$"))),name)
        assert(o:GetFullName()==name,"SV probe identity changed"); return o
    end
    local function construct(kind,outer,name)
        count=count+1
        return required(StaticConstructObject(required(StaticFindObject("/Script/UMG." .. kind),kind),
            required(outer,"outer"),FName(name or ("ColorsPlusSVProbe_Widget_" .. count))),kind)
    end
    local function place(canvas,widget,x,y,w,h)
        local slot=canvas:AddChild(widget)
        slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}})
        slot:SetAlignment({X=0,Y=0}); slot:SetOffsets({Left=x,Top=y,Right=w,Bottom=h})
        return slot
    end
    local function text(canvas,value,x,y,w,h)
        local t=construct("TextBlock",canvas); t:SetText(FText(value)); t:SetVisibility(3)
        t:SetColorAndOpacity({SpecifiedColor={R=.9,G=.93,B=.95,A=1},ColorUseRule=0})
        pcall(function() t.Font.Size=12 end); place(canvas,t,x,y,w,h); return t
    end
    local function out_number(t,key,label)
        -- Scalar UFunction outputs are keyed by FProperty name, not an
        -- arbitrary/single numeric entry. Never depend on pairs() order.
        local result=t[key]
        assert(type(result)=="number" and result==result and math.abs(result)<1e7,"Unreadable " .. label)
        return result
    end
    local function position(s)
        local pc=fresh(s.pc)
        if pc.bShowMouseCursor~=true then return nil,"cursor hidden" end
        local lib=required(StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary"),"layout library")
        -- Some UE4SS builds reuse the first scalar-out table. A shared table
        -- works with both that path and independently consumed out arguments.
        local out={}
        if lib:GetMousePositionScaledByDPI(pc,out,out)~=true then return nil,"viewport mouse unavailable" end
        local desktop=lib:GetMousePositionOnPlatform()
        assert(desktop,"Desktop mouse position unavailable")
        local scale=lib:GetViewportScale(pc)
        assert(type(scale)=="number" and scale==scale and scale>0 and scale<20,"Unreadable viewport scale")
        return {x=out_number(out,"LocationX","mouse X"),y=out_number(out,"LocationY","mouse Y"),
            px=out_number(desktop,"X","desktop X"),py=out_number(desktop,"Y","desktop Y"),scale=scale}
    end
    local function begin_press(s,p,event)
        if not s.input.press(p.x,p.y,event) then return false end
        s.anchor=p; s.last_pointer=p; s.note=nil
        log(string.format("PRESS | source=%s | viewport=%.1f,%.1f desktop=%.1f,%.1f dpi=%.3f",
            event and "event" or "fallback",p.x,p.y,p.px,p.py,p.scale))
        return true
    end
    local function suspend(s,reason)
        s.input.poll(false); s.anchor=nil; s.last_pointer=nil
        s.wait_release=true; s.note=reason
        log("DRAG SUSPENDED | " .. reason .. " | release then click again")
    end
    local function validate(s)
        assert(self.active==s,"SV probe retired")
        runtime.color_ui.validate_picker(s.binding)
        assert(fresh(self.root_name):IsInViewport()==true,"SV probe detached")
    end
    function self.close(reason)
        local s=self.active; self.active=nil
        runtime:cancel("sv-probe:poll"); runtime:cancel("sv-probe:timeout")
        runtime:cancel("sv-probe:command")
        if self.root_name then
            local root=StaticFindObject(self.root_name:match("^[^ ]+ (.+)$"))
            if valid(root) then
                assert(root:GetFullName()==self.root_name,"SV root identity changed")
                root:RemoveFromParent(); assert(root:IsInViewport()==false,"SV probe removal failed")
            end
            self.root_name=nil
        end
        if s then log(string.format("CLOSED | %s | presses=%d events=%d fallbacks=%d releases=%d moves=%d desktop_changes=%d viewport_changes=%d",
            reason or "stop",s.input.presses,s.input.events,s.input.fallbacks,s.input.releases,s.input.moves,
            s.desktop_changes,s.viewport_changes)) end
        return true
    end
    local function fail(why)
        log("FAILED | " .. tostring(why))
        local ok,err=pcall(self.close,"input failure")
        if not ok then log("CLEANUP FAILED | " .. tostring(err)) end
    end
    local function draw(s)
        local input=s.input
        local status=string.format("S %.3f   V %.3f   %s\nPress %d / event %d / fallback %d / release %d\nDesktop %d / viewport %d / capture %s%s",
            input.s,input.v,input.dragging and "DRAG" or "IDLE",input.presses,input.events,input.fallbacks,input.releases,
            s.desktop_changes,s.viewport_changes,s.captured and "yes" or "no",s.note and (" / " .. s.note) or "")
        if input.revision==s.drawn and status==s.drawn_status then return end
        local slot=fresh(s.marker)
        slot:SetOffsets({Left=RECT.x+input.s*RECT.w-9,Top=RECT.y+(1-input.v)*RECT.h-9,Right=18,Bottom=18})
        fresh(s.status):SetText(FText(status))
        s.drawn=input.revision; s.drawn_status=status
    end
    local function poll(s)
        runtime:after("sv-probe:poll",16,function()
            if self.active~=s then return end
            local ok,err=pcall(function()
                validate(s)
                if s.error then error(s.error,0) end
                if s.close_requested or fresh(s.close_button):IsPressed() then self.close("Close button"); return end
                local surface=fresh(s.surface)
                local pressed=surface:IsPressed()==true
                s.captured=surface:HasMouseCapture()==true
                if pressed then
                    if not s.wait_release then
                        local p,why=position(s)
                        if not p then suspend(s,why)
                        elseif not s.anchor then begin_press(s,p,false)
                        elseif p.scale~=s.anchor.scale then suspend(s,"UI scale changed")
                        else
                            local last=s.last_pointer
                            if p.px~=last.px or p.py~=last.py then s.desktop_changes=s.desktop_changes+1 end
                            if p.x~=last.x or p.y~=last.y then s.viewport_changes=s.viewport_changes+1 end
                            local anchor=s.anchor
                            -- The controller/viewport position can freeze during
                            -- capture. Use desktop deltas from this press only.
                            s.input.poll(true,anchor.x+(p.px-anchor.px)/anchor.scale,
                                anchor.y+(p.py-anchor.py)/anchor.scale)
                            s.last_pointer=p
                        end
                    end
                else
                    if s.input.dragging then log(string.format("RELEASE | desktop_changes=%d viewport_changes=%d",
                        s.desktop_changes,s.viewport_changes)) end
                    s.input.poll(false); s.anchor=nil; s.last_pointer=nil; s.wait_release=false; s.note=nil
                end
                draw(s); poll(s)
            end)
            if not ok then fail(err) end
        end)
    end
    local function on_press(context,_,event)
        local s=self.active
        if not s then return end
        local ok,err=pcall(function()
            -- Only this callback's documented RemoteUnrealParams are unwrapped.
            local root=context:get()
            if not valid(root) or root:GetFullName()~=self.root_name then return end
            validate(s)
            local lib=required(StaticFindObject("/Script/Engine.Default__KismetInputLibrary"),"input library")
            local key=lib:PointerEvent_GetEffectingButton(event:get()).KeyName
            local key_name=type(key)=="string" and key or key:ToString()
            if key_name~="LeftMouseButton" then return end
            local p,why=position(s)
            if not p then suspend(s,why); return end
            if p.x>=52 and p.x<=452 and p.y>=535 and p.y<=571 then s.close_requested=true; return end
            s.wait_release=false; begin_press(s,p,true)
        end)
        -- Do not remove a widget from inside its native event. Retire next poll.
        if not ok then s.error=tostring(err) end
        -- No return value: never override/marshal Slate's FEventReply.
    end
    function self.open()
        if self.active or self.root_name then log("OPEN REFUSED | already open or cleanup required"); return false end
        local ok,err=pcall(function()
            assert(runtime.color_ui and runtime.picker,"Creator UI unavailable")
            assert(not runtime.picker.active and not (runtime.tint and runtime.tint.pending),"Close CP/active previews first")
            local b=runtime.color_ui.prepare_picker()
            local pc=required(require("UEHelpers").GetPlayerController(),"player controller")
            assert(pc.bShowMouseCursor==true,"Open a cursor-driven color selector")
            -- Only clean exact roots from an interrupted previous probe.
            local seen=0
            for _,o in pairs(FindAllOf("UserWidget") or {}) do
                seen=seen+1; assert(seen<=8192,"SV root scan bound")
                if valid(o) then local suffix=o:GetFullName():match(ROOT)
                    if suffix then serial=math.max(serial,tonumber(suffix)); o:RemoveFromParent()
                        assert(not o:IsInViewport(),"Stale SV probe removal failed") end
                end
            end
            assert(runtime:hook(HOOK,function() end,on_press),"SV press-event hook unavailable")
            serial=serial+1
            local root=construct("UserWidget",pc,"ColorsPlusSVProbe_Root_" .. serial)
            self.root_name=root:GetFullName(); assert(self.root_name:match(ROOT),"Unexpected SV root")
            root:SetVisibility(4); root.bIsFocusable=false
            local tree=construct("WidgetTree",root); root.WidgetTree=tree
            local canvas=construct("CanvasPanel",tree); tree.RootWidget=canvas; canvas:SetVisibility(4)
            local bg=construct("Border",canvas); bg:SetBrushColor({R=.01,G=.018,B=.025,A=1}); bg:SetVisibility(0)
            place(canvas,bg,32,175,440,420)
            text(canvas,"SV INPUT TEST - NO CHARACTER COLOR WRITES",52,188,400,28)
            local base=construct("Border",canvas); base:SetVisibility(3); base:SetBrushColor({R=0,G=1,B=1,A=1})
            place(canvas,base,RECT.x,RECT.y,RECT.w,RECT.h)
            for _,key in ipairs({"saturation","value"}) do
                local image=construct("Image",canvas); runtime.gradient_assets.bind(image,key)
                place(canvas,image,RECT.x,RECT.y,RECT.w,RECT.h)
            end
            local surface=construct("Button",canvas); surface.IsFocusable=false
            surface:SetBackgroundColor({R=0,G=0,B=0,A=0}); place(canvas,surface,RECT.x,RECT.y,RECT.w,RECT.h)
            local marker=text(canvas,"+",RECT.x+191,RECT.y+111,18,18)
            local status=text(canvas,"Waiting for input",52,482,410,48)
            pcall(function() status.Font.Size=10 end)
            local close=construct("Button",canvas); close.IsFocusable=false; place(canvas,close,52,535,400,36)
            local caption=construct("TextBlock",close); caption:SetText(FText("Close input test")); close:AddChild(caption)
            text(canvas,"90-second timeout. Character is untouched.",52,574,410,20)
            local s={binding=b,pc=pc:GetFullName(),surface=surface:GetFullName(),marker=marker.Slot:GetFullName(),
                close_button=close:GetFullName(),status=status:GetFullName(),input=input_state.new(RECT),
                desktop_changes=0,viewport_changes=0}
            self.active=s
            root:AddToViewport(30020); validate(s)
            assert(position(s),"Mouse position unavailable at open") -- validate both coordinate sources
            draw(s); poll(s)
            runtime:after("sv-probe:timeout",90000,function() if self.active==s then self.close("90s timeout") end end)
            log("OPEN | desktop-delta drag | fixed viewport SV=52,235,400,240 | no tint writes")
        end)
        if not ok then fail(err) end
        return ok
    end
    function self.attach()
        runtime:console("colors_sv",function(_,params)
            params=params or {}; local action=tostring(params[1] or "start"):lower()
            if #params>1 or (action~="start" and action~="stop") then log("Usage: colors_sv start|stop"); return end
            runtime:after("sv-probe:command",1,function()
                if action=="start" then self.open() else self.close("console stop") end
            end)
            log("QUEUED | " .. action .. " | close the console")
        end)
        log("READY | colors_sv start|stop | isolated UI-only drag test")
    end
    return self
end
return M
