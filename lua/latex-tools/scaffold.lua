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

  vim.fn.mkdir(vim.fn.fnamemodify(destination, ":h"), "p")
  local ok, lines = pcall(vim.fn.readfile, source)
  if not ok then
    return "failed"
  end
  local write_ok = pcall(vim.fn.writefile, lines, destination)
  if not write_ok then
    return "failed"
  end
  return "created"
end

--- Copy scaffold payload (sections/, refs.bib, …) beside a saved parent .tex.
function M.ensure_scaffold_files(parent_path, scaffold_dir)
  local parent_dir = vim.fn.fnamemodify(parent_path, ":h")
  local created = {}
  local skipped = {}
  local failed = {}

  local section_sources = util.list_tex_files(scaffold_dir .. "/sections", false)
  table.sort(section_sources)
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

  return { created = created, skipped = skipped, failed = failed }
end

function M.insert_scaffold_template(template_path)
  local parent_path = util.get_saved_buffer_path(0)
  if not parent_path then
    vim.notify(
      "Save this buffer first so scaffold files (sections/, refs.bib) can be written beside it.",
      vim.log.levels.ERROR
    )
    return
  end

  local metadata = util.parse_template_metadata(template_path)
  local scaffold_dir = scaffold_dir_for_template(template_path, metadata)
  if not scaffold_dir then
    vim.notify(
      "Scaffold directory not found for " .. vim.fn.fnamemodify(template_path, ":t"),
      vim.log.levels.ERROR
    )
    return
  end

  local ok, lines = pcall(vim.fn.readfile, template_path)
  if not ok then
    vim.notify("Unable to read template: " .. template_path, vim.log.levels.ERROR)
    return
  end

  util.insert_template_lines(lines)

  local result = M.ensure_scaffold_files(parent_path, scaffold_dir)
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
  vim.notify(table.concat(parts, "; "), vim.log.levels.INFO)
end

return M
