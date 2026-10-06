local scripts=assert(arg[1])
local objects,lists,logs={},{},{}
local host="/Engine/Transient.GameEngine_0:BP_BrunoGameInstance_C_0.WBP_OverallUILayout_C_15.WidgetTree_16"
local function widget(class,path)
    local o={full=class .. " " .. path,active=true}
    function o:IsValid() return not self.invalid end
    -- Real trace: even active screens have no parent and are not in viewport.
    function o:IsInViewport() error("Do not use screen viewport state") end
    function o:GetParent() return nil end
    function o:IsActivated() return self.active end
    function o:GetFullName() return self.full end
    objects[o.full]=o
    lists[class]=lists[class] or {}; table.insert(lists[class],o)
    return o
end
local a={live=function(o) return o and o:IsValid() end,unwrap=function(o) return o end,
    name=function(o) return o:GetFullName() end,values=function(v) assert(type(v)=="table"); return v end}
local lookup=true
function StaticFindObject(path)
    if lookup then for n,o in pairs(objects) do if n:match("^[^ ]+ (.+)$")==path then return o end end end
end
function FindAllOf(c) return lists[c] end
local bank=widget("WBP_CharacterBank_Master_C",host .. ".WBP_CharacterBank_Master_C_1")
local master=widget("WBP_CustomCharacter_Master_C",host .. ".WBP_CustomCharacter_Master_C_2")
local page=widget("WBP_Customization_ItemPage_C",host .. ".WBP_Customization_ItemPage_C_3")
local other=widget("WBP_CustomCharacter_Master_C",host .. ".WBP_CustomCharacter_Master_C_4")
local stack=widget("BitReactorActivatableWidgetStack",host .. ".GameLayer_Stack")
local parent=widget("CanvasPanel",host .. ".MainOverlay")
function stack:GetParent() return not self.detached and parent or nil end
function stack:GetActiveWidget() return self.top end
local factory=assert(loadfile(scripts .. "/creator_lifetime.lua"))()
local life=factory.new(a,function(s) logs[#logs+1]=s end)
local function reset()
    master.active=false; master.invalid=nil; page.active=true; page.invalid=nil
    stack.invalid=nil; stack.detached=nil
    stack.WidgetList={bank,master,page}; stack.top=page
end
local function refused(fn,expected)
    local ok,err=pcall(fn); assert(not ok,"must fail closed")
    if expected then assert(tostring(err):find(expected,1,true),tostring(err)) end
end
reset()
local binding=life.bind(page.full)
assert(binding.master==master.full and binding.stack==stack.full and life.active(binding))
assert(life.page_active(binding,page.full))
for _,v in pairs(binding) do assert(type(v)=="string","scalar identities only") end
assert(life.bind(page.full).master==master.full,"cached other creator is ignored")
lookup=false; assert(life.active(binding),"exact-name fallback"); lookup=true
-- Recorded color -> radial -> color path, with the same creator member.
stack.WidgetList={bank,master}; stack.top=master; master.active=true; page.active=false
assert(life.active(binding))
assert(not life.page_active(binding,page.full),"Radial is not the bound color page")
stack.WidgetList={bank,master,page}; stack.top=page; master.active=false; page.active=true
assert(life.active(binding))
local rebuilt=widget("WBP_Customization_ItemPage_C",host .. ".WBP_Customization_ItemPage_C_5")
stack.WidgetList={bank,master,rebuilt}; stack.top=rebuilt
assert(life.belongs(binding,rebuilt.full) and life.active(binding))
assert(not life.page_active(binding,page.full) and life.page_active(binding,rebuilt.full))
refused(function() life.bind(page.full) end,"Active item page")
-- Creator removed on Databank exit even though the cached UObject remains valid.
reset(); stack.WidgetList={bank}; stack.top=bank
refused(function() life.active(binding) end,"Creator removed")
refused(function() life.bind(page.full) end,"Creator removed")
-- Reopening a new creator never silently transfers the old binding.
reset(); stack.WidgetList={bank,other,page}
refused(function() life.active(binding) end,"Creator replaced")
reset(); stack.WidgetList={bank,master,other,page}
refused(function() life.bind(page.full) end,"Ambiguous creators")
reset(); stack.WidgetList={bank,master,master,page}
refused(function() life.active(binding) end,"Duplicate")
reset(); stack.WidgetList={bank,page,master}
refused(function() life.bind(page.full) end,"Active item page")
-- An unrelated top screen, nonmember top, inactive top or transition gap is not
-- an active visit. Only the editor watcher's bounded grace may tolerate it.
reset(); stack.top=bank; assert(not life.active(binding))
reset(); stack.top=nil; assert(not life.active(binding))
reset(); page.active=false; assert(not life.active(binding))
reset(); stack.WidgetList={bank,master,page,bank}
refused(function() life.active(binding) end,"Duplicate")
local unrelated=widget("WBP_Test_C",host .. ".OtherScreen")
reset(); stack.WidgetList={bank,master,unrelated}; stack.top=unrelated
assert(not life.active(binding))
reset(); stack.WidgetList={bank,master,unrelated,page}; assert(not life.active(binding))
local foreign=widget("WBP_Customization_ItemPage_C","/Game/Other.WBP_Customization_ItemPage_C_6")
reset(); stack.WidgetList={bank,master,foreign}; stack.top=foreign
assert(not life.active(binding) and not life.belongs(binding,foreign.full))
-- Missing, unreadable and oversized lists never fall back to global activation.
reset(); stack.detached=true; refused(function() life.active(binding) end,"stack detached")
reset(); stack.invalid=true; refused(function() life.active(binding) end,"stack unavailable")
reset(); master.invalid=true; refused(function() life.active(binding) end,"object unavailable")
reset(); stack.WidgetList=nil; refused(function() life.active(binding) end)
reset(); stack.WidgetList={}; for i=1,65 do stack.WidgetList[i]=bank end
refused(function() life.active(binding) end,"Unsupported creator stack members")
refused(function() life.active(nil) end)
refused(function() life.bind("WBP_Customization_ItemPage_C /Game/Template") end,"Unsupported item-page layout")
-- Diagnostic output never controls ownership, and active polling stays quiet.
reset(); local count=#logs; assert(life.active(binding)); assert(#logs==count)
assert(table.concat(logs,"\n"):find("CREATOR BIND | REFUSED",1,true))
local broken=factory.new(a,function() error("logger failure") end)
assert(broken.bind(page.full).master==master.full)
stack.WidgetList={bank}; refused(function() broken.bind(page.full) end,"Creator removed")
print("Creator lifetime: verified stack membership, radial round-trip, cache/replacement, boundaries and fail-closed reads passed")
