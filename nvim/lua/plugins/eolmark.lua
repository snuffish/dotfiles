return {
  "aidancz/eolmark.nvim",
  lazy = false,
  enabled = false,
  config = function()
    require("eolmark").setup({
      mark = " $",
    })
    vim.api.nvim_set_hl(0, "EolMark", { link = "NonText" })
  end,
}
