local dap = require("dap")
local dapui = require("dapui")

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup = Popup({
  enter = true,
  focusable = true,
  border = {
    style = "rounded",
    text = {
      top = "Evaulate expression",
      top_align = "center",
      bottom = "<q> close | <CR> eval",
    },
  },
  position = "50%",
  size = {
    width = "40%",
    height = "20%",
  },
})

local eval_modal = function()
  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", "q", function()
    popup:unmount()
  end, { noremap = true })

  local eval
  popup:map("n", "<CR>", function()
    local buffer_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local buffer_content = table.concat(buffer_lines, "\n")
    dap.repl.execute(buffer_content)
  end, { noremap = true })

  vim.bo[popup.bufnr].filetype = "typescript"
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, {})
end

return {
  {
    "mfussenegger/nvim-dap",
    recommended = true,
    desc = "Debugging support. Requires language specific adapters to be configured. (see lang extras)",

    dependencies = {
      "rcarriga/nvim-dap-ui",
      -- virtual text for the debugger
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },
    },

  -- stylua: ignore
  keys = {
    { "<leader>dB", function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
    { "<leader>db", function() dap.toggle_breakpoint() end, desc = "Toggle Breakpoint" },
    { "<leader>dc", function() dap.continue() end, desc = "Run/Continue" },
    { "<leader>da", function() dap.continue({ before = get_args }) end, desc = "Run with Args" },
    { "<leader>dC", function() dap.run_to_cursor() end, desc = "Run to Cursor" },
    { "<leader>dg", function() dap.goto_() end, desc = "Go to Line (No Execute)" },
    { "<leader>di", function() dap.step_into() end, desc = "Step Into" },
    { "<leader>dj", function() dap.down() end, desc = "Down" },
    { "<leader>dk", function() dap.up() end, desc = "Up" },
    { "<leader>dl", function() dap.run_last() end, desc = "Run Last" },
    { "<leader>do", function() dap.step_out() end, desc = "Step Out" },
    { "<leader>dO", function() dap.step_over() end, desc = "Step Over" },
    { "<leader>dP", function() dap.pause() end, desc = "Pause" },
    { "<leader>dr", function() dap.repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>ds", function() dap.session() end, desc = "Session" },
    { "<leader>dt", function() dap.terminate() end, desc = "Terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    { "<leader>de", function() dapui.eval() end, desc = "Evaluate Expression" },
    { "<leader>dx", function() eval_modal() end, desc = "Execute Expression" },
  },

    config = function()
      -- load mason-nvim-dap here, after all adapters have been setup
      if LazyVim.has("mason-nvim-dap.nvim") then
        require("mason-nvim-dap").setup(LazyVim.opts("mason-nvim-dap.nvim"))
      end

      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      for name, sign in pairs(LazyVim.config.icons.dap) do
        sign = type(sign) == "table" and sign or { sign }
        vim.fn.sign_define(
          "Dap" .. name,
          { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
        )
      end

      -- setup dap config by VsCode launch.json file
      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end

      dapui.setup()
    end,
  },
}
