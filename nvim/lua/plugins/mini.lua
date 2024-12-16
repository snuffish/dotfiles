return {
  {
    "echasnovski/mini.operators",
    version = false,
    config = function()
      require("mini.operators").setup()
    end,
  },
  {
    "echasnovski/mini.move",
    version = false,
    config = function()
      require("mini.move").setup()
    end,
  },
  {
    "echasnovski/mini.splitjoin",
    version = false,
    config = function()
      require('mini.splitjoin').setup()end
  },
  {
    'echasnovski/mini.basics',
    version = false,
    config = function()
      require('mini.basics').setup()
    end
  },
}
