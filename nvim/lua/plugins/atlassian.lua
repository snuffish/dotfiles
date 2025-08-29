return {
  {
    "rcarriga/nvim-notify",
  },
  {
    "IwasakiYuuki/ai-assistant.nvim",
    branch = "develop",
    build = ":UpdateRemotePlugins",
    dependencies = { "rcarriga/nvim-notify" },
  },
}
