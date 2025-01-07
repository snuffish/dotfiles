local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local input = Input({
  position = "50%",
  relative = "buf",
  size = {
    width = 20,
  },
  border = {
    style = "single",
    text = {
      top = "Hi there",
      top_align = "center",
    },
  },
}, {
  prompt = "> ",
  default_value = "Empty",
})

input:mount()
