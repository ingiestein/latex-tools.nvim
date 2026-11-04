local util = require("latex-tools.util")

local M = {}

-- Curated fences for keymaps, :LatexToolsCodeFence, and insert_fence_env.
-- `body` = lines inside the env; omit for a one-line `placeholder`.
local fence_catalog = {
  {
    label = "Python",
    env = "python",
    body = {
      "import pandas as pd",
      "from sklearn.model_selection import train_test_split",
    },
  },
  {
    label = "R",
    env = "rcode",
    body = { "summary(df)" },
  },
  {
    label = "SQL",
    env = "sql",
    body = {
      "SELECT patient_id, encounter_date",
      "FROM encounters",
      "WHERE diagnosis_code = 'I10';",
    },
  },
  {
    label = "Markdown",
    env = "markdown",
    body = {
      "# Heading",
      "",
      "Paragraph with **bold** and `code`.",
    },
  },
  {
    label = "Plain text",
    env = "plaintext",
    body = { "Plain text or log output." },
  },
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

local function fence_lines(item)
  local lines = { "\\begin{" .. item.env .. "}" }
  if item.body then
    for _, line in ipairs(item.body) do
      lines[#lines + 1] = line
    end
  else
    lines[#lines + 1] = item.placeholder or ""
  end
  lines[#lines + 1] = "\\end{" .. item.env .. "}"
  return lines
end

local function find_fence(env)
  for _, item in ipairs(fence_catalog) do
    if item.env == env then
      return item
    end
  end
  return nil
end

function M.insert_fence_env(env)
  local item = find_fence(env)
  if not item then
    vim.notify("Unknown code fence env: " .. tostring(env), vim.log.levels.WARN)
    return
  end
  util.insert_lines_at_cursor(fence_lines(item))
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
    util.insert_lines_at_cursor(fence_lines(choice))
  end)
end

return M
