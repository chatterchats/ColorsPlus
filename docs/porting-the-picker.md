# Porting the Colors+ picker into another mod

A starting guide for reusing Colors+'s color picker (color box, hue bar, hex
box, Apply and Cancel) inside another UE4SS Lua mod. It was written for
**ZCShipPaint**, so the examples use its names (`S.colors`, `S.part`,
`S.sel`, `PARTS`, `repaint_part`, `refresh_part`, `hex_lin`) as read from
ZCShipPaint v55. Adapt them to whatever your code calls them now.

Colors+ is MIT-licensed (see [`LICENSE`](../LICENSE)). Keep that notice with
the copied files; a line in your README crediting Colors+ is appreciated.

## How the picker is put together

The picker is three layers. You copy the first two unchanged and write the
third yourself, plus a small "runtime" table they all share.

| Layer | Files | What it does |
| --- | --- | --- |
| **View** | `picker_view.lua`, `hsv_controls.lua`, `sv_picker_input.lua`, `color_math.lua`, `rgb_input.lua`, `gradient_assets.lua`, `button_clicks.lua`, `button_class.lua`, `hsv_shift_controls.lua` | Builds the widgets, reads the mouse and the hex box, and shows the current color. |
| **Coordinator** | `live_picker.lua`, `color_rules.lua` | Opens and closes the picker, polls the view every 16 ms, and forwards colors to the backend. |
| **Host + backend** | *yours* | The **host** says where the picker goes and hides your palette while it's open. The **backend** applies colors to your thing. |

All picker code must run on the game thread.

## 1. Copy the files

From `src/ColorsPlus/Scripts/` (Colors+ v1.1.0 or later) into your
`Scripts/` folder:

```text
picker_view.lua   live_picker.lua    hsv_controls.lua   hsv_shift_controls.lua
sv_picker_input.lua  color_math.lua  rgb_input.lua      color_rules.lua
gradient_assets.lua  button_clicks.lua  button_class.lua
```

And from `src/ColorsPlus/Assets/` into an `Assets/` folder next to your
`Scripts/` folder (`gradient_assets.lua` loads `../Assets/<name>.png`
relative to itself):

```text
hue.png   saturation.png   value.png
```

`hsv_shift_controls.lua` and `color_rules.lua` are only used by Colors+'s
scar-adjustment mode. They're copied so the files load unchanged; the picker
never enters that mode for your colors.

## 2. Make two required edits

**Rename the picker's widget names.** At startup and on its first opening,
the picker removes any leftover widget whose name matches its own prefix. If both
mods use `ColorsPlusPicker_Root_`, each would delete the other's picker. In
`picker_view.lua`, change:

```lua
local ROOT = "^UserWidget .+%.ColorsPlusPicker_Root_(%d+)$"
-- ...
local root=construct("/Script/UMG.UserWidget",pc,"ColorsPlusPicker_Root_" .. next_id)
-- ...
FName(name or ("ColorsPlusPicker_Widget_" .. count))
```

to your own prefix, for example `ZCShipPaintPicker_Root_` and
`ZCShipPaintPicker_Widget_`. Keep the `(%d+)$` part of the pattern.

**Optional: change the log prefixes.** The modules log through
`runtime.log`, with prefixes such as `PICKER |` and `PICKER VIEW |`. They go
to your log, so there's no clash, but you may want your own tag.

## 3. Provide the runtime table

Every module takes a `runtime` table. The picker needs only these four
members; everything else it looks for (`runtime.perf`, `runtime.objects`,
`runtime.known`, `runtime.skin_enable`) is optional and skipped when absent.

| Member | Contract |
| --- | --- |
| `runtime.log(text)` | Write one log line. |
| `runtime:after(key, delay_ms, fn)` | Run `fn` once on the game thread after `delay_ms`. A second call with the same `key` replaces the first. |
| `runtime:cancel(key)` | Drop the pending job for `key`, if any. |
| `runtime:hook(path, fn)` | Register a UE4SS post-hook on `path`; `fn(context)` gets the hooked object as `context:get()`. Return true on success. Used once, for `/Script/CommonUI.CommonButtonBase:HandleButtonClicked` (the picker's Apply and Cancel buttons). |

ZCShipPaint already runs everything from a per-frame loop on the game
thread, so `after` and `cancel` can ride on it. A keyed version of its
`DEFER` queue:

```lua
local JOBS = {}   -- key -> { at = seconds, fn = function }
local runtime = {}
function runtime.log(s) log("[picker] " .. tostring(s)) end
function runtime:after(key, delay_ms, fn) JOBS[key] = { at = os.clock() + delay_ms / 1000, fn = fn } end
function runtime:cancel(key) JOBS[key] = nil end
function runtime:hook(path, fn)
    return (pcall(RegisterHook, path, function(context) pcall(fn, context) end))
end

-- In the existing per-frame loop. Collect first: a job may schedule another.
local function run_picker_jobs()
    local now, due = os.clock(), {}
    for key, job in pairs(JOBS) do if now >= job.at then due[#due + 1] = key end end
    for _, key in ipairs(due) do
        local job = JOBS[key]; JOBS[key] = nil
        if job then try("picker job " .. key, job.fn) end
    end
end
```

## 4. Write the host

The host tells the picker where to attach and hides your palette while it's
open. The view finds it as `runtime.color_host`. The picker fills an
**Overlay** you name: it adds itself as a child that fills the Overlay,
and reserves at least 560 px of height.

ZCShipPaint's page is its own widget asset, so the simplest route is to wrap
the palette grid (the `Btn_Pal_*` buttons, tabs and shade buttons) in an
Overlay in `WBP_ShipPaint`, for example named `PaletteOverlay`.

| Function | Contract |
| --- | --- |
| `host.binding` | The table `prepare_picker()` returned, kept until release. The view checks `host.binding == binding` on every frame. |
| `host.prepare_picker()` | Return a binding table with `overlay` set to the Overlay's **full name** (`"Overlay /Game/…"`, as `GetFullName()` gives it). Error if the picker can't open now. |
| `host.validate_picker(binding)` | Error if the page closed or the overlay changed. Called on every frame; an error closes the picker. |
| `host.hide_palette(binding, root_name)` | Collapse the palette widgets the picker replaces (`SetVisibility(1)`). `root_name` is the picker root's full name. |
| `host.release_picker(binding)` | Restore what `hide_palette` hid and clear `host.binding`. **Also called with `nil`** during cleanup before each opening; that call must do nothing harmful. |

```lua
local host = { binding = nil }
local hidden = {}
function host.prepare_picker()
    assert(S.shown and S.page == 1, "Open a part's colour page first")
    local overlay = widget("PaletteOverlay")
    assert(overlay and overlay:IsValid(), "Palette overlay missing")
    host.binding = { overlay = overlay:GetFullName(), part = S.part, slot = S.sel }
    return host.binding
end
function host.validate_picker(b)
    assert(b and host.binding == b and S.shown and S.page == 1, "Paint page closed")
    local overlay = widget("PaletteOverlay")
    assert(overlay and overlay:IsValid() and overlay:GetFullName() == b.overlay, "Palette overlay replaced")
end
function host.hide_palette(b, root_name)
    hidden = {}
    for _, name in ipairs(PALETTE_WIDGETS) do      -- the grid, tabs and shade buttons
        local w = widget(name)
        if w then hidden[#hidden + 1] = { w = w, v = w:GetVisibility() }; w:SetVisibility(1) end
    end
end
function host.release_picker(b)
    if b == nil and host.binding == nil then return end   -- cleanup call before an opening
    for _, h in ipairs(hidden) do pcall(function() if h.w:IsValid() then h.w:SetVisibility(h.v) end end) end
    hidden = {}; host.binding = nil
end
runtime.color_host = host
```

The view also requires `PlayerController.bShowMouseCursor == true` when it
opens, which your page already arranges if it uses the mouse.

## 5. Write the backend

The coordinator calls the backend with colors in **linear** RGBA (`R`, `G`,
`B` from 0 to 1, plus `A`). ZCShipPaint stores **sRGB hex**, so convert with
`rgb_input.to_srgb`, which returns 0–255 bytes.

| Function | Contract |
| --- | --- |
| `backend.pending` | The open session, or `nil`. The coordinator refuses to open while it's set. |
| `backend.read_context()` | Optional: `{ original = linear RGBA, profile = {} }`, the color the picker starts on. |
| `backend.begin_live()` | Start a session and return it: `{ live = true, test_color = linear RGBA, preview_policy = "color", profile = {} }`. Set `backend.pending` to it. `"color"` gives smooth live previews with a 75 ms gap between updates. |
| `backend.update_live(s, color)` | Preview `color`. Return `true, true` on success; `false` closes the picker. |
| `backend.check_live(s)` | Return `true`, or `false, reason` to close the picker. Called about every half second. |
| `backend.apply_live(s)` | Keep the color. Set `s.live = false` and `backend.pending = nil`; return `true`. |
| `backend.cancel_live(reason)` | Put the original colors back. Clear `backend.pending`; return `true`. |
| `backend.restore` | Same as `cancel_live` (used as a fallback). |

```lua
local DIR = MOD_DIR .. "/Scripts/"
local function module(name) return assert(loadfile(DIR .. name .. ".lua"))() end
local rgb_input = module("rgb_input")

local function hex_of(c) local b = rgb_input.to_srgb(c); return string.format("%02X%02X%02X", b.R, b.G, b.B) end
local function lin_of(hex) local c = hex_lin(hex); return { R = c.R, G = c.G, B = c.B, A = 1 } end
local function targets(part) return (part[1] == "All") and PARTS or { part } end
local function current_hex(part, slot)
    if part[1] == "All" then return common_hex(slot) end
    return (S.colors[part[1]] or {})[slot]
end

local backend = { pending = nil }
function backend.read_context()
    local hex = current_hex(S.part, S.sel)
    return { original = hex and lin_of(hex) or { R = 1, G = 1, B = 1, A = 1 }, profile = {} }
end
function backend.begin_live()
    local originals = {}
    for _, p in ipairs(targets(S.part)) do originals[p[1]] = (S.colors[p[1]] or {})[S.sel] or false end
    local s = { live = true, part = S.part, slot = S.sel, originals = originals,
        test_color = backend.read_context().original, preview_policy = "color", profile = {} }
    backend.pending = s
    return s
end
function backend.update_live(s, color)
    if s ~= backend.pending or not s.live then return false end
    local hex = hex_of(color)
    for _, p in ipairs(targets(s.part)) do S.colors[p[1]] = S.colors[p[1]] or {}; S.colors[p[1]][s.slot] = hex end
    repaint_part(s.part); refresh_part()
    s.test_color = color
    return true, true
end
function backend.check_live(s)
    if s ~= backend.pending or not s.live then return false, "session ended" end
    if not S.shown or S.part ~= s.part or S.sel ~= s.slot then return false, "page or slot changed" end
    return true
end
function backend.apply_live(s)
    if s ~= backend.pending then return false end
    s.live = false; backend.pending = nil       -- SAVE / revert-on-close keep working as before
    return true
end
function backend.cancel_live(reason)
    local s = backend.pending
    if not s then return true end
    for key, hex in pairs(s.originals) do
        S.colors[key] = S.colors[key] or {}; S.colors[key][s.slot] = hex or nil
    end
    repaint_part(s.part); refresh_part()
    s.live = false; backend.pending = nil
    return true
end
backend.restore = backend.cancel_live
```

Custom colors bypass the SHADE setting, which only applies to palette
swatches.

## 6. Wire it up

```lua
local view = module("picker_view").new(runtime)
local picker = module("live_picker").new(runtime, backend, view, rgb_input)
picker.start()   -- removes any picker left over from a Lua reload

-- Your CUSTOM COLOR button's click action:
local function open_custom_color()
    if picker.active then return end
    picker.open()   -- logs "OPEN REFUSED/FAILED | …" with the reason when it can't
end

-- When the page closes for any reason (CLOSE, Esc, leaving the hangar):
local function close_custom_color() if picker.active then picker.close("page closed") end end
```

While the picker is open, skip your own 60 ms button poll for the palette
buttons it covers. The picker also places an invisible button over the
overlay, so clicks don't reach the hidden swatches.

## Things that can bite

- **Classes the picker borrows from the game.** Its buttons use
  `WBP_CharacterDataBank_TopNavButton_C` (`button_class.lua` loads it with
  `LoadAsset` when missing). Its heading uses
  `WBP_Customization_SlotSubItemName_C`, which may not be loaded in the
  hangar. If opening fails there, load it the same way, or replace
  `native_heading(...)` in `picker_view.lua` with
  `label(body, "CUSTOM COLOR", 16)`.
- **Size.** The picker reserves at least 560 px of height and its color box is
  400 × 240 (`hsv_controls.lua`: `WIDTH`, `HEIGHT`). If your page is
  shorter, change the `SetHeightOverride(560)` in `picker_view.lua`.
- **Mouse only.** Like Colors+, the picker isn't reachable with a
  controller.
- **Game thread.** Never call picker functions from a key-bind callback.
  Set a flag and act on it in your frame loop, as ZCShipPaint already does.
- **Reloading.** `picker.start()` cleans up after a Lua reload, but UE4SS's
  Reload All Mods can still crash this game; test with restarts.
- **Both mods installed.** Each mod runs in its own Lua state and hooks
  `HandleButtonClicked` separately; with the renamed prefix they don't touch
  each other's widgets.

## Checking it works

The coordinator logs each step through `runtime.log`. A healthy opening
looks like:

```text
PICKER | OPEN BEGIN
PICKER VIEW | ATTACHED | UserWidget /Game/…ZCShipPaintPicker_Root_1
PICKER | VIEW READY | starting verified tint preview
PICKER | OPEN | color controls; color latest-only preview; 75ms post-update cooldown; …
```

An `OPEN FAILED | <reason>` line names the check that refused: a host
`assert` message, the cursor check, or a missing widget class.
