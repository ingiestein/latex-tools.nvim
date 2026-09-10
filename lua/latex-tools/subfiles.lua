local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local SUBFILE_DIR = "subfile"
local SUBFILE_TEMPLATE = "subfile.tex"

local function get_subfile_template_path()
  local paths = state.get_paths()
  local user_path = paths.user_templates_dir .. "/" .. SUBFILE_TEMPLATE
  if vim.fn.filereadable(user_path) == 1 then
    return user_path
  end
  return paths.template_dir .. "/" .. SUBFILE_TEMPLATE
end

function M.render_subfile_template(lines, parent_path)
  local parent_name = vim.fn.fnamemodify(parent_path, ":t")
  local parent_stem = vim.fn.fnamemodify(parent_path, ":t:r")
  local rendered = {}

  for _, line in ipairs(lines) do
    local updated = line:gsub("main%.tex", parent_name):gsub("%.%./main", "../" .. parent_stem)
    table.insert(rendered, updated)
  end

  return rendered
end

function M.build_subfile_include_path(subfile_name)
  return "./" .. SUBFILE_DIR .. "/" .. subfile_name
end

function M.insert_subfile_include(buf, cursor, subfile_name)
  local row = cursor[1] - 1
  local include_line = "\\subfile{" .. M.build_subfile_include_path(subfile_name) .. "}"
  vim.api.nvim_buf_set_lines(buf, row, row, false, { include_line })
end

function M.create_subfile()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  -- Capture before vim.fn.input(); cmdline input leaves the window cursor stale.
  local cursor = vim.api.nvim_win_get_cursor(win)

  if not util.is_course_aware_buffer(buf) then
    vim.notify(
      "Subfiles can only be created from a saved course-aware document (% latex-tools: course-aware).",
      vim.log.levels.ERROR
    )
    return
  end

  local parent_path = util.get_saved_buffer_path(buf)
  if not parent_path then
    vim.notify("Save the course-aware document before creating a subfile.", vim.log.levels.ERROR)
    return
  end

  local raw_name = vim.fn.input("Subfile name: ", "")
  if raw_name == "" then
    vim.notify("Subfile creation cancelled: no name entered", vim.log.levels.INFO)
    return
  end

  local subfile_name = util.sanitize_filename(raw_name)
  if not subfile_name then
    vim.notify("Subfile creation cancelled: invalid name", vim.log.levels.WARN)
    return
  end

  local parent_dir = vim.fn.fnamemodify(parent_path, ":h")
  local subfile_dir = parent_dir .. "/" .. SUBFILE_DIR
  local destination = subfile_dir .. "/" .. subfile_name

  if vim.fn.filereadable(destination) == 1 then
    vim.notify("Subfile already exists: " .. destination, vim.log.levels.ERROR)
    return
  end

  local template_path = get_subfile_template_path()
  local ok, template_lines = pcall(vim.fn.readfile, template_path)
  if not ok then
    vim.notify("Unable to read subfile template: " .. template_path, vim.log.levels.ERROR)
    return
  end

  vim.fn.mkdir(subfile_dir, "p")

  local lines = M.render_subfile_template(template_lines, parent_path)
  local write_ok, write_result = pcall(vim.fn.writefile, lines, destination)
  if not write_ok or write_result ~= 0 then
    vim.notify("Unable to write subfile to " .. destination, vim.log.levels.ERROR)
    return
  end

  M.insert_subfile_include(buf, cursor, subfile_name)
  vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(destination))
  vim.notify("Created subfile: " .. destination, vim.log.levels.INFO)
end

return M
