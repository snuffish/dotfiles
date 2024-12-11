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

      function OverlayWindow(agent)
        return {
          title = string.format("Quickchat - [agent: %s]", agent),
          layout = "float",
          relative = "editor"
        }
      end

      return {
        {
          "<leader>ccq",
          function ()
            local input = vim.fn.input("Quick chat: ")

            chat.open({
              window = {
                layout = "float",
                title = string.format("Quickchat - [agent: %s]", chat.config.agent)
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
              window = OverlayWindow(chat.config.agent),
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
            vim.ui.input({
              prompt = string.format("Quickchat - [agent: %s]", chat.config.agent),
            }, function (question)
                if question == "q" then
                  vim.notify("Input cancelled", vim.log.levels.INFO)
                  return
                end

                local selection = require("CopilotChat.select").visual
                chat.ask(question, {
                  window = OverlayWindow(chat.config.agent),
                  selection = selection,
                })
              end)
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
