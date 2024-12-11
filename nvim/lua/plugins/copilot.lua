local mode = { 'v', 'n', 'x' }

return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("render-markdown").setup({
        file_types = { "markdown", "copilot-chat" },
      })
      require('copilot').setup({
        panel = {
          enabled = false
        },
        highlight_headers = false,
        separator = '---',
        error_header = '> [!ERROR] Error',

      })

      -- Enable markdown_inline highlight group
      vim.cmd([[
      syntax enable
      syntax on
      highlight markdown_inline ctermfg=NONE guifg=NONE
      ]])
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    build = "make tiktoken",
    keys = function ()
      local chat = require('CopilotChat')
      local actions = require("CopilotChat.actions")
      local fzf = require("CopilotChat.integrations.fzflua")

      return {
        {
          "<leader>ccq",
          function ()
            local input = vim.fn.input("Quick chat: ")

            chat.open({
              window = {
                layout = "float",
                title = "Quickchat = agent [" .. chat.config.agent .. "]"
              }
            })

            chat.ask(input, {
              selection = require('CopilotChat.select').buffer
            })
          end,
          desc = "Quickchat"
        },
        {
          "<leader>ccm",
          "<cmd>CopilotChatModels<CR>",
          desc = "Chat Models",
          mode = mode
        },
        {
          "<leader>ccf",
          "<cmd>CopilotChatFix<CR>",
          desc = "Fix",
          mode = mode
        },
        {
          "<leader>cce",
          "<cmd>CopilotChatExplain<CR>",
          desc = "Explain",
          mode = mode
        },
        {
          "<leader>ccC",
          "<cmd>CopilotChatToggle<CR>",
          desc = "Copilot",
          mode = mode
        },
        {
          "<leader>ccc",
          function ()
            chat.open({
              window = {
                title = "Quickchat - [agent: " .. chat.config.agent .. "]",
                layout = "float",
                relative = "editor",
              },
            })
          end,
          desc = "Copilot (Overlay)",
          mode = mode
        },
        {
          "<leader>ccp",
          function()
            fzf.pick(actions.prompt_actions())
          end,
          desc = "Prompt actions",
          mode = mode
        },
        {
          "<leader>ccw",
          function()
            chat.open({
              window = {
                title = "Quickchat - [agent: " .. chat.config.agent .. "]",
                layout = "float",
                relative = "cursor",
                width = 1,
                height = 0.4,
                row = 1,
              },
            })
          end,
          desc = "Cursor Inline Window",
          mode = mode
        },
        {
          "<leader>cca",
          function()
            actions.pick(actions.prompt_actions({
              selection = require("CopilotChat.select").visual,
            }))
          end,
          desc = "Help Actions",
        }
      },
      {
        "<leader>ccc",
        "<cmd>CopilotChatToggle<CR>",
        desc = "Toggle",
        mode = mode
      },
      {
        "<leader>ccr",
        function()
          chat.restart()
        end,
        desc = "Restart",
        mode = mode
      }
    end,
  }
}
