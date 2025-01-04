local dap = require("dap")
local dapui = require("dapui")

vim.keymap.set("n", "<F1>", function()
  dap.step_into()
end)

vim.keymap.set("n", "<F2>", function()
  dap.step_over()
end)

vim.keymap.set("n", "<F3>", function()
  dap.step_out()
end)

vim.keymap.set("n", "<F4>", function()
  dap.step_over()
end)

vim.keymap.set("n", "<F5>", function()
  dap.continue()
end)

-- Keybinding to open the floating window
vim.utils.map("n", "<F6>", vim.utils.trigger_keys_fn("<leader>dr<C-w>ji"), { noremap = true, silent = true })

vim.keymap.set("n", "<Leader>d", function()
  dap.continue()
end)

vim.keymap.set("n", "<Leader>b", function()
  dap.toggle_breakpoint()
end)

vim.keymap.set("n", "<Leader>B", function()
  dap.set_breakpoint()
end)

vim.keymap.set("n", "<Leader>lp", function()
  dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end)

vim.keymap.set("n", "<Leader>dr", function()
  dap.repl.open()
end)

vim.keymap.set("n", "<Leader>dl", function()
  dap.run_last()
end)

vim.keymap.set({ "n", "v" }, "<Leader>dh", function()
  require("dap.ui.widgets").hover()
end)

vim.keymap.set({ "n", "v" }, "<Leader>dp", function()
  require("dap.ui.widgets").preview()
end)

vim.keymap.set("n", "<Leader>df", function()
  local widgets = require("dap.ui.widgets")

  widgets.centered_float(widgets.frames)
end)

vim.keymap.set("n", "<Leader>ds", function()
  local widgets = require("dap.ui.widgets")

  widgets.centered_float(widgets.scopes)
end)
