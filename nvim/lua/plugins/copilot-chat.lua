return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    build = "make tiktoken",
    opts = {
      debug = true,
    },
    config = function()
      require("which-key").add({
        "<leader>cc",
        desc = "Copilot",
        icon = "",
      })

      require("render-markdown").setup({
        file_types = { "markdown", "copilot-chat" },
      })
      require("CopilotChat").setup({
        highlight_headers = false,
        separator = "---",
        error_header = "> [!ERROR] Error",
      })
    end,
    keys = function()
      local chat = require("CopilotChat")
      local actions = require("CopilotChat.actions")
      local fzf = require("CopilotChat.integrations.fzflua")

      return {
        {
          "<leader>ccq",
          function()
            local input = vim.fn.input("Quick Chat: ")

            chat.open({
              window = {
                layout = "float",
                title = "Quickchat - [agent: " .. chat.config.agent .. "]",
              },
            })

            chat.ask(input)
          end,
          desc = "Quick chat",
        },
        {
          "<leader>ccm",
          "<cmd>CopilotChatModels<CR>",
          desc = "Chat Models",
        },
        {
          "<leader>ccp",
          function()
            fzf.pick(actions.prompt_actions())
          end,
          desc = "Prompt actions",
        },
        {
          "<leader>ccw",
          function()
            chat.open({
              window = {
                layout = "float",
                relative = "cursor",
                width = 1,
                height = 0.4,
                row = 1,
              },
            })
          end,
          desc = "Help Actions",
        },
        {
          "<leader>cca",
          function()
            actions.pick(actions.prompt_actions({
              selection = require("CopilotChat.select").visual,
            }))
          end,
          desc = "Help Actions",
        },
        {
          "<leader>ccc",
          "<cmd>CopilotChatToggle<CR>",
          desc = "Toggle",
        },
        {
          "<leader>ccr",
          function()
            chat.restart()
          end,
          desc = "Restart Copilot",
        },
      }
    end,
  },
}
