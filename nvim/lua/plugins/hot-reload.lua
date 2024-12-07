return {
  "Zeioth/hot-reload.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "BufEnter",
  opts = function()
    local config_dir = vim.fn.stdpath("config") .. "/lua/"

    return {
      reload_files = {
        config_dir .. "test.lua",
      },
      reload_callback = function()
        print("RELOADED HERE!")
      end,
    }
  end,
}
