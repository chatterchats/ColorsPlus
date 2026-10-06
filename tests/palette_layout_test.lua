local scripts=assert(arg[1])
local layout=assert(loadfile(scripts .. "/palette_layout.lua"))()
local function close(a,b) return math.abs(a-b)<1e-6 end

-- The in-game chain logged on v0.3.0 (Face skin tone palette), grid upward.
local function chain()
    return {
        {desired=452,h=0,pad_l=0,pad_r=0,parent_kind="SizeBox"},          -- PartsGridList
        {desired=452,h=0,pad_l=0,pad_r=0,parent_kind="VerticalBox",parent_size_rule=1}, -- SizeBox_0
        {desired=452,h=0,pad_l=0,pad_r=0,parent_kind="Overlay"},          -- VerticalBox_0 (stack)
        {desired=452,h=0,pad_l=0,pad_r=0,parent_kind="WBP_Customization_SelectionTiles_C"}, -- Overlay_0 (tree root)
        {desired=452,h=0,pad_l=0,pad_r=0,parent_kind="VerticalBox",parent_size_rule=0}, -- SelectionTiles
        {desired=452,h=0,pad_l=68,pad_r=30,parent_kind="Overlay"},        -- VerticalBox_123
        {desired=563,h=0,pad_l=0,pad_r=0,parent_kind="WBP_CustomizationSlotPanel_C"}, -- Overlay_1 (tree root)
        {desired=563,h=0,pad_l=0,pad_r=0,parent_kind="CommonActivatableWidgetSwitcher"}, -- SlotPanel
        {desired=563,h=0,pad_l=0,pad_r=0,parent_kind="VerticalBox",parent_size_rule=0}, -- SlotWidgetSwitcher
        {desired=563,h=0,pad_l=0,pad_r=0,parent_kind="SizeBox"},          -- VerticalBox_0
        {desired=563,h=0,pad_l=0,pad_r=0,parent_kind="HorizontalBox",parent_size_rule=0}, -- SizeBox_87
    }
end
assert(close(layout.column_width(chain()),465),"Column = 563 panel - 68 - 30 padding")

-- 64-wide tiles, 10 spacing (not included), left aligned: six per row,
-- visible from 5 to 439 (measured in-game: 6..438 of a 466-wide column).
local row=layout.swatch_row(465,64,10,false,3,30)
assert(row.per_line==6 and close(row.left,5) and close(row.width,434))
-- Short palettes span only their swatches.
row=layout.swatch_row(465,64,10,false,3,4)
assert(close(row.left,5) and close(row.width,4*74-10))

-- Untrusted chains return nil instead of guessing.
local fill=chain(); fill[11].parent_size_rule=1
assert(layout.column_width(fill)==nil,"Fill slots in a horizontal box share unknown space")
local unknown=chain(); for i=7,11 do unknown[i]=nil end
assert(layout.column_width(unknown)==nil,"No self-sized ancestor means no width")
-- A fixed-width SizeBox is trusted directly.
local fixed=chain(); fixed[2].width_override=300
assert(close(layout.column_width(fixed),300))
-- Non-fill alignment keeps the desired width when it fits.
local aligned=chain(); aligned[1].h=1; aligned[1].desired=400
assert(close(layout.column_width(aligned),400))

-- Other alignments stay inside the column.
for alignment=0,6 do
    local r=layout.swatch_row(465,64,10,false,alignment,30)
    assert(r.left>=0 and r.left+r.width<=465+1e-6,"alignment " .. alignment)
end
assert(not pcall(layout.swatch_row,nil,64,10,false,3,30))
print("Palette layout: column width from the live chain, swatch row edges, untrusted chains and alignments passed")
