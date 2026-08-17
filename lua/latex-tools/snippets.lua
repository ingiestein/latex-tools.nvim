local util = require("latex-tools.util")

local M = {}

local snippets = {
  p = {
    "\\begin{lstlisting}[style=latextoolspython,caption={Model training loop},label={lst:python-model}]",
    "import pandas as pd",
    "from sklearn.model_selection import train_test_split",
    "\\end{lstlisting}",
  },
  r = {
    "\\begin{lstlisting}[style=latextoolsr,caption={Basic R summary},label={lst:r-summary}]",
    "summary(df)",
    "\\end{lstlisting}",
  },
  s = {
    "\\begin{lstlisting}[style=latextoolssql,caption={Cohort extraction query},label={lst:sql-cohort}]",
    "SELECT patient_id, encounter_date",
    "FROM encounters",
    "WHERE diagnosis_code = 'I10';",
    "\\end{lstlisting}",
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