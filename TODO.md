# nvim-treesitter-textobjects
```
return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  lazy = true,
  config = function()
    require("nvim-treesitter.configs").setup({
      textobjects = {
        select = {
          enable = true,

          -- Automatically jump forward to textobj, similar to targets.vim
          lookahead = true,

          keymaps = {
            ["a="] = { query = "@assigmment.outer", desc = "Select outer part of an assignment" },
            ["i="] = { query = "@assigmment.inner", desc = "Select inner part of an assignment" },
            ["l="] = { query = "@assigmment.lhs", desc = "Select left part of an assignment" },
            ["r="] = { query = "@assigmment.rhs", desc = "Select right part of an assignment" },

            ["aa"] = { query = "@parameter.outer", desc = "Select outer part of parameter/argument" },
            ["ia"] = { query = "@parameter.inner", desc = "Select inner part of parameter/argument" },

            ["ai"] = { query = "@conditional.outer", desc = "Select outer part of a conditional" },
            ["ii"] = { query = "@conditional.inner", desc = "Select inner part of a conditional" },

            ["al"] = { query = "@loop.outer", desc = "Select outer part of a loop" },
            ["il"] = { query = "@loop.inner", desc = "Select inner part of a loop" },

            -- ["af"] = { query = "@call.outer", desc = "Select outer part of a function call" },
            -- ["if"] = { query = "@call.inner", desc = "Select inner part of a function call" },

            ["af"] = { query = "@function.outer", desc = "Select outer part of a method/function definition" },
            ["if"] = { query = "@function.inner", desc = "Select inner part of a method/function definition" },

            ["ac"] = { query = "@class.outer", desc = "Select outer part
            ["ic"] = { query = "@class.inner", desc = "Select inner part of a class" },
          },
        },
        -- swap = {
        --   enable = true,
        --   swap_next = {
        --     ["<leader>na"] = "@parameter.inner",
        --     ["<leader>nm"] = "@parameter.outer",
        --   },
        --   swap_previous = {
        --     ["<leader>pa"] = "@parameter.inner",
        --     ["<leader>pm"] = "@parameter.outer",
        --   },
        -- },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            ["]f"] = { query = "@call.outer", desc = "Next function call start" },
            ["]m"] = { query = "@function.outer", desc = "Next method/function def start" },
            ["]c"] = { query = "@class.outer", desc = "Next class start" },
            ["]i"] = { query = "@conditional.outer", desc = "Next conditional start" },
            ["]l"] = { query = "@loop.outer", desc = "Next loop start" },

            -- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
            -- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
            ["]s"] = { query = "@scope", query_group = "locals", desc = "Next scope" },
            ["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
          },
          goto_next_end = {
            ["]F"] = { query = "@call.outer", desc = "Next function call end" },
            ["]M"] = { query = "@function.outer", desc = "Next method/function def end" },
            ["]C"] = { query = "@class.outer", desc = "Next class end" },
            ["]I"] = { query = "@conditional.outer", desc = "Next conditional end" },
            ["]L"] = { query = "@loop.outer", desc = "Next loop end" },
          },
          goto_previous_start = {
            ["[f"] = { query = "@call.outer", desc = "Prev function call start" },
            ["[m"] = { query = "@function.outer", desc = "Prev method/function def start" },
            ["[c"] = { query = "@class.outer", desc = "Prev class start" },
            ["[i"] = { query = "@conditional.outer", desc = "Prev conditional start" },
            ["[l"] = { query = "@loop.outer", desc = "Prev loop start" },
          },
          goto_previous_end = {
            ["[F"] = { query = "@call.outer", desc = "Prev function call end" },
            ["[M"] = { query = "@function.outer", desc = "Prev method/function def end" },
            ["[C"] = { query = "@class.outer", desc = "Prev class end" },
            ["[I"] = { query = "@conditional.outer", desc = "Prev conditional end" },
            ["[L"] = { query = "@loop.outer", desc = "Prev loop end" },
          },
        },
      },
    })

    local map = require("utils").map
    local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

    -- map("nxo", ";", ts_repeat_move.repeat_last_move)
    -- map("nxo", ",", ts_repeat_move.repeat_last_move_opposite)

    map("nxo", "f", ts_repeat_move.builtin_f_expr)
    map("nxo", "F", ts_repeat_move.builtin_F_expr)
    map("nxo", "t", ts_repeat_move.builtin_t_expr)
    map("nxo", "T", ts_repeat_move.builtin_T_expr)
  end,
}
```
