local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local function is_readable(path)
  return vim.fn.filereadable(path) == 1
end

local function scaffold_dir_for_template(template_path, metadata)
  local dirname = metadata["scaffold-dir"]
  if not dirname or dirname == "" then
    dirname = vim.fn.fnamemodify(template_path, ":t:r")
  end

  local beside_template = vim.fn.fnamemodify(template_path, ":h") .. "/" .. dirname
  if vim.fn.isdirectory(beside_template) == 1 then
    return beside_template
  end

  local paths = state.get_paths()
  local user_dir = paths.user_templates_dir .. "/" .. dirname
  if vim.fn.isdirectory(user_dir) == 1 then
    return user_dir
  end

  local bundled_dir = state.bundled_template_dir() .. "/" .. dirname
  if vim.fn.isdirectory(bundled_dir) == 1 then
    return bundled_dir
  end

  return nil
end

local function copy_missing_file(source, destination)
  if is_readable(destination) then
    return "skipped"
  end

  local dest_dir = vim.fn.fnamemodify(destination, ":h")
  if vim.fn.mkdir(dest_dir, "p") == -1 and vim.fn.isdirectory(dest_dir) ~= 1 then
    return "failed"
  end

  local ok, lines = pcall(vim.fn.readfile, source)
  if not ok or type(lines) ~= "table" then
    return "failed"
  end

  local write_ok, write_result = pcall(vim.fn.writefile, lines, destination)
  if not write_ok or write_result ~= 0 then
    return "failed"
  end
  return "created"
end

--- Copy scaffold payload (sections/, refs.bib, …) beside a saved parent .tex.
function M.ensure_scaffold_files(parent_path, scaffold_dir)
  local parent_dir = vim.fn.fnamemodify(parent_path, ":h")
  if parent_dir == "" then
    parent_dir = "."
  end

  local created = {}
  local skipped = {}
  local failed = {}

  local sections_dir = scaffold_dir .. "/sections"
  local section_sources = util.list_tex_files(sections_dir, false)
  table.sort(section_sources)

  if #section_sources == 0 then
    return {
      created = created,
      skipped = skipped,
      failed = failed,
      missing_sections = true,
      sections_dir = sections_dir,
    }
  end

  if vim.fn.mkdir(parent_dir .. "/sections", "p") == -1 and vim.fn.isdirectory(parent_dir .. "/sections") ~= 1 then
    return {
      created = created,
      skipped = skipped,
      failed = { "sections/" },
      missing_sections = false,
      sections_dir = sections_dir,
    }
  end

  for _, source in ipairs(section_sources) do
    local name = vim.fn.fnamemodify(source, ":t")
    local destination = parent_dir .. "/sections/" .. name
    local status = copy_missing_file(source, destination)
    if status == "created" then
      table.insert(created, "sections/" .. name)
    elseif status == "skipped" then
      table.insert(skipped, "sections/" .. name)
    else
      table.insert(failed, "sections/" .. name)
    end
  end

  local bib_source = scaffold_dir .. "/refs.bib"
  if is_readable(bib_source) then
    local destination = parent_dir .. "/refs.bib"
    local status = copy_missing_file(bib_source, destination)
    if status == "created" then
      table.insert(created, "refs.bib")
    elseif status == "skipped" then
      table.insert(skipped, "refs.bib")
    else
      table.insert(failed, "refs.bib")
    end
  end

  return {
    created = created,
    skipped = skipped,
    failed = failed,
    missing_sections = false,
    sections_dir = sections_dir,
  }
end

function M.insert_scaffold_template(template_path)
  local parent_path = util.get_project_buffer_path(0)
  if not parent_path then
    vim.notify(
      "Name this buffer first (e.g. :edit main.tex) so sections/ can be written beside it.",
      vim.log.levels.ERROR
    )
    return
  end

  local metadata = util.parse_template_metadata(template_path)
  local scaffold_dir = scaffold_dir_for_template(template_path, metadata)
  if not scaffold_dir then
    vim.notify(
      "Scaffold directory not found for "
        .. vim.fn.fnamemodify(template_path, ":t")
        .. " (expected sibling dir or bundled templates/"
        .. (metadata["scaffold-dir"] or vim.fn.fnamemodify(template_path, ":t:r"))
        .. "/)",
      vim.log.levels.ERROR
    )
    return
  end

  local ok, lines = pcall(vim.fn.readfile, template_path)
  if not ok then
    vim.notify("Unable to read template: " .. template_path, vim.log.levels.ERROR)
    return
  end

  -- Ensure the parent directory exists before writing companions.
  local parent_dir = vim.fn.fnamemodify(parent_path, ":h")
  if parent_dir ~= "" and parent_dir ~= "." then
    vim.fn.mkdir(parent_dir, "p")
  end

  util.insert_template_lines(lines)

  -- Persist the parent on disk so \\input{sections/...} resolves next to a real file.
  local write_ok, write_err = pcall(function()
    vim.cmd("silent write!")
  end)
  if not write_ok then
    vim.notify(
      "Inserted template text but could not write "
        .. parent_path
        .. ": "
        .. tostring(write_err),
      vim.log.levels.WARN
    )
  end

  local result = M.ensure_scaffold_files(parent_path, scaffold_dir)
  if result.missing_sections then
    vim.notify(
      "No section .tex files found in " .. tostring(result.sections_dir),
      vim.log.levels.ERROR
    )
    return
  end

  if #result.failed > 0 then
    vim.notify(
      "Unable to create scaffold files: " .. table.concat(result.failed, ", "),
      vim.log.levels.ERROR
    )
  end

  local parts = {
    "Inserted scaffold template: " .. vim.fn.fnamemodify(template_path, ":t"),
  }
  if #result.created > 0 then
    table.insert(parts, "created " .. table.concat(result.created, ", "))
  end
  if #result.skipped > 0 then
    table.insert(parts, "kept existing " .. #result.skipped .. " file(s)")
  end
  if #result.created == 0 and #result.skipped == 0 and #result.failed == 0 then
    table.insert(parts, "no section files written (unexpected)")
  end
  vim.notify(table.concat(parts, "; "), vim.log.levels.INFO)
end

return M
