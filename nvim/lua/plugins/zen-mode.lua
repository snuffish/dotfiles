return {
  "folke/zen-mode.nvim",
  opts = {
    window = {
      width = 0.85,
      backdrop = 0.95,
      height = 1,
      options = {
        signcolumn = "no",
        number = false,
        relativenumber = true,
        cursorline = false,
        cursorcolumn = false,
        foldcolumn = "0",
        list = true,
      },
    },
    plugins = {
      tmux = {
        enabled = true,
      },
      wezterm = {
        enabled = false,
      },
    },
    on_open = function()
      print("Entered ZenMode")
      _G.ZenMode = { enabled = true }
    end,
    on_close = function()
      print("Exited ZenMode")
      _G.ZenMode = { enabled = false }
    end,
  },
  keys = function()
    local toggle = function()
      require("zen-mode").toggle()
    end

    return {
      {
        "<leader>uz",
        toggle,
        desc = "Toggle Zen Mode",
      },
      {
        "<leader>z",
        toggle,
        desc = "Toggle Zen Mode",
      },
    }
  end,
  config = function(_, opts)
    require("zen-mode").setup(opts)
  end,
}
