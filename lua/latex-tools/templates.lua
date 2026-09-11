local assignment = require("latex-tools.assignment")
local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local HIDDEN_TEMPLATES = {
  ["subfile.tex"] = true,
  ["latex-tools-code.tex"] = true,
  ["latex-tools-code-minted.tex"] = true,
}

local function template_label(name, path)
  if util.is_course_aware_template(path) then
    return name .. " (course-aware)"
  end
  return name
end

function M.describe_template(path)
  local name = vim.fn.fnamemodify(path, ":t")
  return {
    name = name,
    path = path,
    label = template_label(name, path),
    course_aware = util.is_course_aware_template(path),
  }
end

function M.list_templates()
  local paths = state.get_paths()
  local by_name = {}

  local function add_from_dir(directory, source_label)
    for _, path in ipairs(util.list_tex_files(directory, false)) do
      local name = vim.fn.fnamemodify(path, ":t")
      if not HIDDEN_TEMPLATES[name] then
        local item = M.describe_template(path)
        if source_label then
          item.label = item.label .. " [" .. source_label .. "]"
        end
        by_name[item.name] = item
      end
    end
  end

  add_from_dir(paths.template_dir, nil)
  add_from_dir(paths.user_templates_dir, "user")

  local items = {}
  for _, item in pairs(by_name) do
    table.insert(items, item)
  end

  table.sort(items, function(a, b)
    return a.name < b.name
  end)

  return items
end

function M.insert_static_template(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify("Unable to read template: " .. path, vim.log.levels.ERROR)
    return
  end

  util.insert_template_lines(lines)
  vim.notify("Inserted template: " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
end

function M.insert_template()
  local items = M.list_templates()
  if #items == 0 then
    vim.notify("No .tex templates found in template directories", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Select template",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.course_aware then
      assignment.insert_assignment_template(choice.path)
      return
    end

    M.insert_static_template(choice.path)
  end)
end

return M
