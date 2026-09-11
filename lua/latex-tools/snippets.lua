local util = require("latex-tools.util")

local M = {}

local snippets = {
  p = {
    "\\begin{python}",
    "import pandas as pd",
    "from sklearn.model_selection import train_test_split",
    "\\end{python}",
  },
  r = {
    "\\begin{rcode}",
    "summary(df)",
    "\\end{rcode}",
  },
  s = {
    "\\begin{sql}",
    "SELECT patient_id, encounter_date",
    "FROM encounters",
    "WHERE diagnosis_code = 'I10';",
    "\\end{sql}",
  },
}

function M.insert_snippet(snippet_key)
  local snippet = snippets[snippet_key]
  if not snippet then
    vim.notify("Unknown snippet key: " .. tostring(snippet_key), vim.log.levels.WARN)
    return
  end
  util.insert_lines_at_cursor(snippet)
end

return M
