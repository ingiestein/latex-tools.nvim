local util = require("latex-tools.util")

local M = {}

-- Rich sample bodies for frequent languages (\tcp / \tcr / \tcs / \tcm / \tcl)
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
  m = {
    "\\begin{markdown}",
    "# Heading",
    "",
    "Paragraph with **bold** and `code`.",
    "\\end{markdown}",
  },
  l = {
    "\\begin{plaintext}",
    "Plain text or log output.",
    "\\end{plaintext}",
  },
}

-- Catalog for :LatexToolsCodeFence / \tcf and insert_fence_env
local fence_catalog = {
  { label = "Python", env = "python", placeholder = "# code" },
  { label = "R", env = "rcode", placeholder = "# code" },
  { label = "SQL", env = "sql", placeholder = "-- query" },
  { label = "Markdown", env = "markdown", placeholder = "# Heading" },
  { label = "Plain text", env = "plaintext", placeholder = "text" },
  { label = "JavaScript", env = "javascript", placeholder = "// code" },
  { label = "TypeScript", env = "typescript", placeholder = "// code" },
  { label = "Java", env = "java", placeholder = "// code" },
  { label = "C", env = "ccode", placeholder = "/* code */" },
  { label = "C++", env = "cpp", placeholder = "// code" },
  { label = "C#", env = "csharp", placeholder = "// code" },
  { label = "Rust", env = "rust", placeholder = "// code" },
  { label = "JSON", env = "json", placeholder = "{}" },
  { label = "Go", env = "go", placeholder = "// code" },
  { label = "Bash", env = "bash", placeholder = "# code" },
}

local function fence_lines(env, placeholder)
  return {
    "\\begin{" .. env .. "}",
    placeholder,
    "\\end{" .. env .. "}",
  }
end

local function find_fence(env)
  for _, item in ipairs(fence_catalog) do
    if item.env == env then
      return item
    end
  end
  return nil
end

function M.insert_snippet(snippet_key)
  local snippet = snippets[snippet_key]
  if not snippet then
    vim.notify("Unknown snippet key: " .. tostring(snippet_key), vim.log.levels.WARN)
    return
  end
  util.insert_lines_at_cursor(snippet)
end

function M.insert_fence_env(env)
  local item = find_fence(env)
  if not item then
    vim.notify("Unknown code fence env: " .. tostring(env), vim.log.levels.WARN)
    return
  end
  util.insert_lines_at_cursor(fence_lines(item.env, item.placeholder))
end

function M.pick_code_fence()
  vim.ui.select(fence_catalog, {
    prompt = "Code fence language",
    format_item = function(item)
      return string.format("%s (\\begin{%s})", item.label, item.env)
    end,
  }, function(choice)
    if not choice then
      return
    end
    util.insert_lines_at_cursor(fence_lines(choice.env, choice.placeholder))
  end)
end

return M
