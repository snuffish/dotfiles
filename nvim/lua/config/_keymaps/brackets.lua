local set = require("../../utils").set

-- Bracket-jump keymaps
set("nv", "Q", "<cmd>TSTextobjectGotoPreviousStart @parameter.inner<cr>zz")
set("nv", "q", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<cr>zz")

-- set("n", "<Tab-q>", "<cmd>TSTextobjectGotoPreviousStart @function.inner<cr>", { noremap = true })
-- set("n", "kf", "<cmd>TSTextobjectGotoNextEnd @function<cr>", { noremap = true })
-- set("n", "kw", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<cr>", { noremap = true })

-- <Plug>(MatchitNormalForward)
