P = function(v)
  local ch = vim.inspect(v)

  local o = {}
  for i = 1, #ch do
    local c = ch:sub(i, i)
    o[#o + 1] = c ~= "\n" and c or " "
  end

  local s = table.concat(o)
  vim.print(s)
  return s
end
