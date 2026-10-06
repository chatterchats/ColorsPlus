local M=assert(loadfile(assert(arg[1]) .. "/sv_input_state.lua"))()
local input=M.new({x=52,y=235,w=400,h=240})
assert(not input.press(0,0,true))
assert(input.press(52,235,true) and input.s==0 and input.v==1)
-- Quick click survives release and moving elsewhere before the next poll.
input.poll(false); assert(input.s==0 and input.v==1 and input.releases==1)
input.poll(false); assert(input.releases==1)
assert(input.press(452,475,true)); input.poll(true,252,355)
assert(input.s==.5 and input.v==.5 and input.dragging)
input.poll(true,900,900); assert(input.s==1 and input.v==0)
input.poll(true,0,0); assert(input.s==0 and input.v==1)
input.poll(false); local revision=input.revision
input.poll(false); assert(input.revision==revision)
input.poll(true,252,355); assert(input.fallbacks==1)
input.poll(false)
-- Two real event presses between polls must not collapse into one click.
local presses=input.presses
input.press(52,235,true); input.press(452,475,true); input.poll(false)
assert(input.presses==presses+2 and input.presses==input.releases and input.s==1 and input.v==0)
assert(not pcall(input.press,0/0,235,true))
print("SV input: retained quick clicks, continuous movement, clamping, release, hover and repeated event presses passed")
