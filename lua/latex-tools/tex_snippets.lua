local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

function M.insert_custom_snippet()
  local directory = state.get_paths().custom_snippets_dir
  local files = util.list_tex_files(directory, true)
  if #files == 0 then
    vim.notify("No custom .tex snippets found in " .. directory, vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, path in ipairs(files) do
    table.insert(items, { path = path, label = util.relative_path(path, directory) })
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
