-- Colors+ v0.1.0
-- Star Wars: Zero Company / UE4SS
--
-- Repository bootstrap. Customization hooks will be installed by the armor
-- tint-zone prototype after their preview and commit lifecycle is verified.

local VERSION = "0.1.0"
local MOD_TAG = "[Colors+]"
local RUNTIME_KEY = "ColorsPlusRuntime"

local previous = rawget(_G, RUNTIME_KEY)
if previous ~= nil then
    previous.alive = false
end

local runtime = {
    alive = true,
    generation = previous and (previous.generation + 1) or 1,
    version = VERSION,
}

rawset(_G, RUNTIME_KEY, runtime)
print(string.format("%s Loaded v%s (generation %d)\n", MOD_TAG, VERSION, runtime.generation))

return runtime
