-- Run from the repository root:
-- luajit tests/bootstrap_test.lua "src/Colors+/Scripts"

local scripts = assert(arg[1], "pass the mod Scripts directory")
local entrypoint = scripts .. "/main.lua"

local original_print = print
local messages = {}
print = function(message)
    messages[#messages + 1] = tostring(message)
end

local first = assert(loadfile(entrypoint))()
assert(first.alive == true)
assert(first.generation == 1)
assert(first.version == "0.1.0")
assert(ColorsPlusRuntime == first)

local second = assert(loadfile(entrypoint))()
assert(first.alive == false, "reload must retire the previous runtime")
assert(second.alive == true)
assert(second.generation == 2)
assert(ColorsPlusRuntime == second)

print = original_print
assert(#messages == 2)
assert(messages[1]:find("[Colors+] Loaded v0.1.0", 1, true))
assert(messages[2]:find("generation 2", 1, true))

print("Colors+ bootstrap and same-state reload test passed")
