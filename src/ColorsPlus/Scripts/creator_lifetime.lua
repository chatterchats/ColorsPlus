-- The live trace proved that stack-owned screens have no UMG parent/viewport
-- attachment. Bind to the exact GameLayer_Stack and its creator member instead.
-- Only scalar identities survive calls; recovery restores, never resumes visits.
-- Two editors: the main-menu creator puts its master screen in the stack; the
-- in-game (hub) editor puts the hub's tabbed menu there, with the
-- customization master page as that menu's active tab.
local M={}
local MASTER="WBP_CustomCharacter_Master_C"
local TABS="WBP_CentralUITabs_C"
local TAB_PAGE="WBP_Customization_MasterPage_C"
local PAGE="WBP_Customization_ItemPage_C"
local STACK="BitReactorActivatableWidgetStack"
local LAYOUT="^/Engine/Transient%.GameEngine_%d+:BP_BrunoGameInstance_C_%d+%.WBP_OverallUILayout_C_%d+%.WidgetTree_%d+$"
function M.new(a,logger)
    local self={}
    local function log(s)
        if logger then pcall(logger,"CREATOR BIND | " .. s:gsub("[\r\n\t]"," ")) end
    end
    local function object(o) o=a.unwrap(o); assert(a.live(o),"Creator object unavailable"); return o end
    local function name(o) return a.name(object(o)) end
    local function host(full,class) return full:match("^" .. class .. " (.+)%." .. class .. "_%d+$") end
    local function stack_name(layout) return STACK .. " " .. layout .. ".GameLayer_Stack" end
    local function editor_host(full)
        return host(full,MASTER) or host(full,TABS)
    end
    -- The hub menu counts as a creator only while customization is its tab.
    local function hub_tab(tabs_object)
        local tabs=name(tabs_object)
        local path=assert(tabs:match("^" .. TABS .. " (.+)$"))
        local tab_stack=a.unwrap(object(tabs_object).TabStack)
        assert(a.live(tab_stack),"Hub menu tab stack unavailable")
        local active=a.unwrap(tab_stack:GetActiveWidget())
        assert(a.live(active),"No active hub menu tab")
        local full=name(active)
        local prefix=TAB_PAGE .. " " .. path .. ".WidgetTree_"
        assert(full:sub(1,#prefix)==prefix and full:sub(#prefix+1):match("^%d+%." .. TAB_PAGE .. "_%d+$"),
            "Customization is not the active hub menu tab")
        return full,active
    end
    local function find_stack(full)
        local o=(a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$"))
        if a.live(o) and name(o)==full then return o end
        local values=FindAllOf(STACK) or {}
        assert(type(values)=="table","Unsupported creator stack list")
        local n,found=0,nil
        for _,v in pairs(values) do
            n=n+1; assert(n<=4096,"Creator stack scan limit")
            if a.live(v) and name(v)==full then
                assert(not found,"Ambiguous creator stack"); found=v
            end
        end
        return assert(found,"Recorded creator stack unavailable")
    end
    local function snapshot(binding)
        assert(binding and binding.host and binding.host:match(LAYOUT)
            and binding.stack==stack_name(binding.host),"No verified live creator stack binding")
        local stack=find_stack(binding.stack)
        -- Unlike the screens, this stack's live CanvasPanel parent was observed.
        assert(a.live(a.unwrap(stack:GetParent())),"Creator stack detached")
        object(stack)
        local members=a.values(stack.WidgetList)
        assert(type(members)=="table" and #members<=64,"Unsupported creator stack members")
        local ids,seen,master,index,tab={},{}
        for i,v in ipairs(members) do
            local full=name(v)
            assert(not seen[full],"Duplicate creator stack member"); seen[full]=true; ids[i]=full
            local hub=full:match("^" .. TABS .. " ")
            -- Other hub menu tabs are not creators; only a customization tab is.
            local tab_ok,tab_name=true,nil
            if hub then tab_ok,tab_name=pcall(hub_tab,v) end
            if full:match("^" .. MASTER .. " ") or (hub and tab_ok) then
                assert(editor_host(full)==binding.host,"Creator belongs to another layout")
                assert(not master,"Ambiguous creators in game stack"); master=full; index=i; tab=tab_name
            end
        end
        assert(master,"Creator removed from game stack")
        assert(not binding.master or master==binding.master,"Creator replaced in game stack")
        assert(not binding.master or tab==binding.tab,"Creator replaced in game stack")
        object(stack)
        local top=a.unwrap(stack:GetActiveWidget())
        local top_name=a.live(top) and name(top) or nil
        -- Unknown/no active top can occur during a push/pop. Only the existing
        -- watcher grants a short grace period; initial Apply/reopen require true.
        local current=false
        if top_name==ids[#ids] and (top_name==master
            or (host(top_name or "",PAGE)==binding.host and #ids==index+1)) then
            current=object(top):IsActivated()==true
        end
        if current and tab then
            local _,active=hub_tab(members[index])
            current=active:IsActivated()==true
        end
        return {master=master,tab=tab,index=index,ids=ids,top=top_name,current=current}
    end
    function self.belongs(binding,page)
        return binding and host(page,PAGE)==binding.host
    end
    function self.bind(page)
        log("BEGIN | page=" .. tostring(page))
        local ok,result=pcall(function()
            local layout=host(page,PAGE)
            assert(layout and layout:match(LAYOUT),"Unsupported item-page layout")
            local binding={host=layout,stack=stack_name(layout)}
            local s=snapshot(binding)
            assert(s.top==page and s.current and s.ids[s.index+1]==page,
                "Active item page is not directly above creator in game stack")
            binding.master=s.master; binding.tab=s.tab
            return binding
        end)
        if not ok then log("REFUSED | " .. tostring(result)); error(result,0) end
        log("BOUND | master=" .. result.master .. (result.tab and (" | tab=" .. result.tab) or "") .. " | stack=" .. result.stack)
        return result
    end
    function self.active(binding)
        assert(binding and binding.master,"No live creator binding; restore recovered sessions")
        return snapshot(binding).current
    end
    function self.page_active(binding,page)
        assert(binding and binding.master,"No live creator binding")
        local s=snapshot(binding)
        return self.belongs(binding,page) and s.current and s.top==page and s.ids[s.index+1]==page
    end
    return self
end
return M
