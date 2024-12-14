return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    { "borderless_full" },
    winopts = {
      fullscreen = false,
      preview = {
        default = "bat",
      },
    },
  },
  keys = {},
  config = function(_, opts)
    require("fzf-lua").setup(opts)
  end,
}

--     require('').setup({'fzf-native'})
-- <
-- You can also start with a profile as "baseline" and customize it, for example,
-- telescope defaults with `bat` previewer:
--
-- >lua
--     :lua require"fzf-lua".setup({"telescope",winopts={preview={default="bat"}}})
-- <
-- Combining of profiles is also available by sending table instead of string as
-- the first argument:
--
-- >lua
--     :lua require"fzf-lua".setup({{"telescope","fzf-native"},winopts={fullscreen=true}})
-- <
-- See profiles
-- <https://github.com/ibhagwan/fzf-lua/tree/main/lua/fzf-lua/profiles> for more
-- info.
--
--
