return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "leoluz/nvim-dap-go",
    "nvim-neotest/nvim-nio"
  },
  config = function ()
    local dap = require('dap')
    local dapui = require('dapui')

    require('dap-go').setup()

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    vim.keymap.set('n', '<leader>dt', dap.toggle_breakpoint, {})
    vim.keymap.set('n', '<leader>dc', dap.continue, {})

     -- Add configuration for sh
    dap.adapters.sh = {
      type = 'executable',
      command = 'bash-debug-adapter',
      args = {}
    }

    dap.configurations.sh = {
      {
        type = 'sh',
        request = 'launch',
        name = "Launch file",
        program = "${file}",
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
      },
    }
  end
}
