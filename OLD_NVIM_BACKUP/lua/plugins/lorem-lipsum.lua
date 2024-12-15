return {
  "derektata/lorem.nvim",
  props = {
    sentenceLength = "medium",
    comma_chance = 0.2,
    max_commas_per_sentence = 2,
  },
  config = function(_, opts)
    require("lorem").opts(opts)
  end,
}
