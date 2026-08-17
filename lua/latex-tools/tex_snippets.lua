local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local function relative_path(path, directory)
  local prefix = directory:gsub("/+$", "") .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return vim.fn.fnamemodify(path, ":t")
end

local function list_files(directory)
  local seen = {}
  local files = {}

  for _, pattern in ipairs({ "*.tex", "**/*.tex" }) do
    for _, path in ipairs(vim.fn.globpath(directory, pattern, false, true)) do
      if vim.fn.filereadable(path) == 1 and not seen[path] then
        seen[path] = true
        table.insert(files, path)
      end
    end
  end

  table.sort(files)
  return files
end

function M.insert_custom_snippet()
  local directory = state.get_paths().custom_snippets_dir
  local files = list_files(directory)
  if #files == 0 then
    vim.notify("No custom .tex snippets found in " .. directory, vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, path in ipairs(files) do
    table.insert(items, { path = path, label = relative_path(path, directory) })
  end

  vim.ui.select(items, {
    prompt = "Select LaTeX snippet",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local ok, lines = pcall(vim.fn.readfile, choice.path)
    if not ok then
      vim.notify("Unable to read LaTeX snippet: " .. choice.path, vim.log.levels.ERROR)
      return
    end
    util.insert_lines_at_cursor(lines)
  end)
end

return M