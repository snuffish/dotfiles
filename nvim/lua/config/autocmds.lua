local lfs = require("lfs")

local function require_all_autocmds()
  local path = vim.fn.stdpath("config") .. "/lua/config/autocmds"
  for file in lfs.dir(path) do
    if file:match("%.lua$") then
      local module_name = "config.autocmds." .. file:gsub("%.lua$", "")
      require(module_name)
    end
  end
end

require_all_autocmds()
