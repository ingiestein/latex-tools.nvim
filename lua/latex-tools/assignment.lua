local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local function load_courses(tex_path)
  local paths = state.get_paths()
  local output = state.run_command({
    state.get_python_cmd(),
    paths.python_script_path,
    "--yaml",
    paths.yaml_path,
    "--template",
    tex_path,
    "--list-courses",
  })

  if not output then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" or type(decoded.courses) ~= "table" then
    vim.notify("Unable to parse course metadata JSON", vim.log.levels.ERROR)
    return {}
  end
  return decoded.courses
end

local function prompt_due_date(default)
  while true do
    local due_date = vim.fn.input("Due date (YYYY-MM-DD): ", default)
    if due_date == "" then
      due_date = default
    end
    if util.valid_date(due_date) then
      return due_date
    end
    vim.notify("Invalid due date. Use YYYY-MM-DD.", vim.log.levels.WARN)
  end
end

function M.insert_assignment_template(template_path)
  local paths = state.get_paths()
  local tex_path = template_path or paths.tex_template_path
  local courses = load_courses(tex_path)
  if #courses == 0 then
    vim.notify("No courses available in " .. paths.yaml_path, vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, course in ipairs(courses) do
    local label = string.format(
      "%s (%s) | %s | %s",
      course.course_code,
      course.class_number,
      course.course_title,
      course.instructors
    )
    table.insert(items, {
      key = course.key,
      label = label,
      course = course,
    })
  end

  vim.ui.select(items, {
    prompt = "Select course",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local title_default = "Assignment Title"
    local due_default = os.date("%Y-%m-%d")

    local assignment_title = vim.fn.input("Assignment title: ", title_default)
    if assignment_title == "" then
      assignment_title = title_default
    end

    local due_date = prompt_due_date(due_default)

    local rendered = state.run_command({
      state.get_python_cmd(),
      paths.python_script_path,
      "--yaml",
      paths.yaml_path,
      "--template",
      tex_path,
      "--render",
      "--course-key",
      choice.key,
      "--assignment-title",
      assignment_title,
      "--due-date",
      due_date,
    })

    if not rendered then
      return
    end

    local lines = util.split_lines(rendered)
    util.insert_template_lines(lines)
    vim.notify("Inserted rendered LaTeX template for " .. choice.course.course_code, vim.log.levels.INFO)
  end)
end

return M
