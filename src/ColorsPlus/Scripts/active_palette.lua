-- Follow explicit live page -> active panel -> owned lists. Never scan global
-- selection widgets: inactive panels can contain equally "visible" palettes.
local M={}
local PANELS={WBP_CustomizationSlotPanel_C="WBP_CustomizationSlotPanel",
    WBP_CustomizationSlotPanelCombined_C="WBP_CustomizationSlotPanelCombined",
    WBP_Customization_SlotList_C="WBP_Customization_SlotList"}
local CONTAINERS={BitReactorStackBox=true,StackBox=true,SizeBox=true,Border=true,
    VerticalBox=true,HorizontalBox=true,Overlay=true,CanvasPanel=true,ScrollBox=true,
    WrapBox=true,GridPanel=true,UniformGridPanel=true}
function M.new(a,logger)
    local self={}
    local function log(s) if logger then logger("ACTIVE PALETTE | " .. s:gsub("[\r\n\t]"," ")) end end
    local function obj(v) v=a.unwrap(v); assert(a.live(v),"Active palette object unavailable"); return v end
    local function name(v) return a.name(obj(v)) end
    local function kind(v) return name(v):match("^([^ ]+) ") end
    local function field(v,k) return obj(a.prop(obj(v),k)) end
    local function exact_page(full)
        assert(type(full)=="string" and full:match("^WBP_Customization_ItemPage_C /[^\r\n]+$"),"Invalid palette page identity")
        local page=a.unwrap((a.find or StaticFindObject)(full:match("^[^ ]+ (.+)$")))
        if a.live(page) and name(page)==full then return page end
        local found,count=nil,0
        local pages=FindAllOf("WBP_Customization_ItemPage_C") or {}
        assert(type(pages)=="table","Invalid page list")
        for _,p in pairs(pages) do
            count=count+1; assert(count<=128,"Palette page scan limit")
            if a.live(p) and name(p)==full then assert(not found,"Duplicate palette page"); found=p end
        end
        return obj(found)
    end
    local function discover(page_name,slot_tag,displayed,log)
        local page=exact_page(page_name)
        assert(page:IsActivated()==true,"Palette page is no longer active")
        local switcher=field(page,"SlotWidgetSwitcher")
        assert(kind(switcher)=="CommonActivatableWidgetSwitcher","Unexpected slot switcher class")
        local root=obj(switcher:GetActiveWidget()); local root_name=name(root)
        local key=assert(PANELS[kind(root)],"Unsupported active customization panel: " .. root_name)
        assert(name(field(page,key))==root_name,"Active panel differs from page reference")
        log("ROOT | page=" .. page_name .. " | panel=" .. root_name .. " | slot=" .. slot_tag)
        local seen,grids,grid_seen,total={},{},{},0
        local selected_tag
        -- Only a simple panel has an unambiguous displayed-slot override.
        -- Combined/list panels retain exact current-slot matching.
        local use_displayed=displayed and kind(root)=="WBP_CustomizationSlotPanel_C"
        local function walk(v,depth,route)
            v=obj(v); local full=name(v)
            assert(depth<=8,"Palette traversal depth limit")
            assert(not seen[full],"Palette reference cycle/alias")
            seen[full]=true; total=total+1; assert(total<=128,"Palette traversal node limit")
            if v:IsVisible()~=true then log("HIDDEN | " .. route .. " | " .. full); return end
            local cls=kind(v)
            if cls=="WBP_Customization_SelectionTiles_C" then
                local current=a.text(a.prop(a.prop(v,"CurrentSlotTag"),"TagName"))
                log("TILES | " .. route .. " | slot=" .. current .. " | " .. full)
                if current==slot_tag or use_displayed then
                    assert(current:match("^br%.Customization%.Slot%.Character%.[%w_.]+$"),"Invalid displayed slot tag")
                    local grid=field(v,"PartsGridList"); local n=name(grid)
                    assert(kind(grid)=="BitReactorTileView","Unexpected palette grid class")
                    if not grid_seen[n] then grid_seen[n]=true; grids[#grids+1]=grid; selected_tag=current end
                end
            elseif cls=="WBP_CustomizationSlotPanel_C" then
                walk(field(v,"WBP_Customization_SelectionTiles"),depth+1,route .. ".SelectionTiles")
            elseif cls=="WBP_CustomizationSlotPanelCombined_C" or cls=="WBP_Customization_SlotList_C" then
                local property=cls=="WBP_CustomizationSlotPanelCombined_C" and "CustomizationSlots" or "SlotStack"
                local list=field(v,property)
                assert(kind(list)=="BitReactorStackBox","Unexpected customization list class")
                walk(list,depth+1,route .. "." .. property)
            elseif CONTAINERS[cls] then
                local children=a.values(v:GetAllChildren()); assert(#children<=64,"Palette child limit")
                for i,child in ipairs(children) do walk(child,depth+1,route .. "[" .. i .. "]") end
            else
                log("SKIP | unsupported child=" .. full .. " | route=" .. route)
            end
        end
        walk(root,0,key)
        assert(page:IsActivated()==true and name(switcher:GetActiveWidget())==root_name,"Active palette panel changed during discovery")
        assert(#grids==1,"Expected one palette in active panel; found " .. #grids)
        log("SELECTED | grid=" .. name(grids[1]) .. " | traversed=" .. total)
        return grids[1],selected_tag
    end
    local previous_trace
    function self.resolve(page_name,slot_tag,displayed)
        local lines={}
        local ok,grid,tag=pcall(discover,page_name,slot_tag,displayed,function(s) lines[#lines+1]=s end)
        local signature=table.concat(lines,"\n")
        if not ok or signature~=previous_trace then
            for _,line in ipairs(lines) do log(line) end
        end
        previous_trace=ok and signature or nil
        assert(ok,grid)
        return grid,tag
    end
    return self
end
return M
