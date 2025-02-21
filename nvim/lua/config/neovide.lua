vim.print(vim.g.neovide_version)

-- vim.o.guifont = "Source Code Pro:h14"

-- Helper function for transparency formatting
local alpha = function()
  return string.format("%x", math.floor(255 * (vim.g.transparency or 0.8)))
end
-- g:neovide_transparency should be 0 if you want to unify transparency of content and title bar.
-- vim.g.neovide_transparency = 1
-- vim.g.transparency = 0.8
-- vim.g.neovide_background_color = "#0f1117" .. alpha()

vim.g.neovide_scale_factor = 0.8
local change_scale_factor = function(delta)
  vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
end
vim.keymap.set("n", "<C-+>", function()
  change_scale_factor(1.25)
end)
vim.keymap.set("n", "<C-=>", function()
  change_scale_factor(1 / 1.25)
end)

vim.g.neovide_title_background_color =
  string.format("%x", vim.api.nvim_get_hl(0, { id = vim.api.nvim_get_hl_id_by_name("Normal") }).bg)

vim.g.neovide_title_text_color = "pink"

vim.g.neovide_cursor_vfx_mode = "ripple"

vim.g.neovide_scroll_animation_length = 0
-- vim.g.neovide_cursor_animation_length = 0

vim.keymap.set("n", "<D-s>", ":w<CR>") -- Save
vim.keymap.set("v", "<D-c>", '"+y') -- Copy
vim.keymap.set("n", "<D-v>", '"+P') -- Paste normal mode
vim.keymap.set("v", "<D-v>", '"+P') -- Paste visual mode
vim.keymap.set("c", "<D-v>", "<C-R>+") -- Paste command mode
vim.keymap.set("i", "<D-v>", '<ESC>l"+Pli') -- Paste insert mode

-- Remap keys
vim.api.nvim_set_keymap("", "å", "[", {})
vim.api.nvim_set_keymap("", "ö", ";", {})
vim.api.nvim_set_keymap("", "Ö", ":", {})
vim.api.nvim_set_keymap("", "ä", "'", {})
vim.api.nvim_set_keymap("", "Ä", '"', {})
vim.api.nvim_set_keymap("", "Å", "{", {})

