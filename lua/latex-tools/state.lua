local util = require("latex-tools.util")

local M = {}

local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":p:h:h:h")
end

local function user_config_dir()
  return vim.fn.stdpath("config") .. "/latex-tools"
end

local function user_yaml_path()
  return user_config_dir() .. "/courses.yaml"
end

local function user_templates_dir()
  return user_config_dir() .. "/templates"
end

local function user_template_path()
  return user_config_dir() .. "/assignment.tex"
end

local function user_custom_snippets_dir()
  return user_config_dir() .. "/snippets"
end

local function is_readable(path)
  return vim.fn.filereadable(path) == 1
end

local function copy_bundled_file(opts)
  local options = opts or {}
  local destination = options.destination
  local source = options.source
  local label = options.label or "File"

  if is_readable(destination) and not options.force then
    if not options.quiet then
      vim.notify(label .. " already exists at " .. destination, vim.log.levels.WARN)
    end
    return destination, "skipped"
  end

  local ok, lines = pcall(vim.fn.readfile, source)
  if not ok then
    if not options.quiet then
      vim.notify("Unable to read bundled " .. label:lower(), vim.log.levels.ERROR)
    end
    return nil, "failed"
  end

  vim.fn.mkdir(vim.fn.fnamemodify(destination, ":h"), "p")

  local write_ok, write_result = pcall(vim.fn.writefile, lines, destination)
  if not write_ok or write_result ~= 0 then
    if not options.quiet then
      vim.notify("Unable to write " .. label:lower() .. " to " .. destination, vim.log.levels.ERROR)
    end
    return nil, "failed"
  end

  if not options.quiet then
    vim.notify("Created " .. label:lower() .. " at " .. destination, vim.log.levels.INFO)
  end
  return destination, "created"
end

local function resolve_assignment_template_path(bundled_template_path, preferred_template_path, legacy_template_path)
  if is_readable(preferred_template_path) then
    return preferred_template_path
  end
  if is_readable(legacy_template_path) then
    return legacy_template_path
  end
  return bundled_template_path
end

local function default_paths()
  local root = plugin_root()
  local template_dir = root .. "/templates"
  local bundled_yaml_path = template_dir .. "/courses.yaml"
  local preferred_yaml_path = user_yaml_path()
  local bundled_template_path = template_dir .. "/assignment.tex"
  local preferred_template_path = user_templates_dir() .. "/assignment.tex"
  local legacy_template_path = user_template_path()
  return {
    template_dir = template_dir,
    user_templates_dir = user_templates_dir(),
    yaml_path = is_readable(preferred_yaml_path) and preferred_yaml_path or bundled_yaml_path,
    tex_template_path = resolve_assignment_template_path(
      bundled_template_path,
      preferred_template_path,
      legacy_template_path
    ),
    custom_snippets_dir = user_custom_snippets_dir(),
    python_script_path = root .. "/python/render_template.py",
    test_script_path = root .. "/tests/templates_spec.lua",
  }
end

function M.get_paths()
  local defaults = default_paths()
  local ok, config = pcall(require, "latex-tools.config")
  if not ok then
    return defaults
  end

  local opts = config.get()
  local path_overrides = (opts and opts.paths) or {}
  return vim.tbl_deep_extend("force", defaults, path_overrides)
end

function M.get_python_cmd()
  local ok, config = pcall(require, "latex-tools.config")
  if ok then
    local opts = config.get()
    if opts and opts.python_cmd and opts.python_cmd ~= "" then
      return opts.python_cmd
    end
  end

  return (vim.g.python3_host_prog and vim.g.python3_host_prog ~= "") and vim.g.python3_host_prog or "python3"
end

function M.get_user_yaml_path()
  return user_yaml_path()
end

function M.get_user_template_path()
  return user_templates_dir() .. "/assignment.tex"
end

local function user_templates_backup_root()
  return user_config_dir() .. "/templates-backup"
end

local function new_templates_backup_dir()
  return user_templates_backup_root() .. "/" .. os.date("%Y%m%d-%H%M%S")
end

local function relocate_to_backup(path, backup_dir)
  vim.fn.mkdir(backup_dir, "p")
  local destination = backup_dir .. "/" .. vim.fn.fnamemodify(path, ":t")
  if vim.fn.rename(path, destination) ~= 0 then
    return nil
  end
  return destination
end

function M.get_user_templates_backup_root()
  return user_templates_backup_root()
end

function M.initialize_user_templates(opts)
  local options = opts or {}
  local paths = M.get_paths()
  local bundled_dir = default_paths().template_dir
  local destination_dir = paths.user_templates_dir
  local bundled_files = vim.fn.glob(bundled_dir .. "/*.tex", false, true)

  if #bundled_files == 0 then
    vim.notify("No bundled templates found in " .. bundled_dir, vim.log.levels.WARN)
    return nil
  end

  vim.fn.mkdir(destination_dir, "p")

  local copied = {}
  local backed_up = {}
  local created = 0
  local skipped = 0
  local failed = 0
  local backup_dir = nil

  for _, source in ipairs(bundled_files) do
    local name = vim.fn.fnamemodify(source, ":t")
    local destination = destination_dir .. "/" .. name
    local ready_to_copy = true

    if options.force and is_readable(destination) then
      if not backup_dir then
        backup_dir = new_templates_backup_dir()
      end
      local relocated = relocate_to_backup(destination, backup_dir)
      if not relocated then
        failed = failed + 1
        ready_to_copy = false
        vim.notify("Unable to back up " .. destination, vim.log.levels.ERROR)
      else
        table.insert(backed_up, relocated)
      end
    end

    if ready_to_copy then
      local result, status = copy_bundled_file({
        source = source,
        destination = destination,
        force = false,
        label = name,
        quiet = true,
      })
      if result then
        table.insert(copied, result)
      end
      if status == "created" then
        created = created + 1
      elseif status == "skipped" then
        skipped = skipped + 1
      else
        failed = failed + 1
      end
    end
  end

  if options.force and (#backed_up > 0 or created > 0) and failed == 0 then
    local message = string.format("Refreshed %d template(s) in %s", created, destination_dir)
    if backup_dir and #backed_up > 0 then
      message = message .. string.format("; backed up %d to %s", #backed_up, backup_dir)
    end
    vim.notify(message, vim.log.levels.INFO)
  elseif created > 0 then
    vim.notify(
      string.format("Created %d template(s) in %s", created, destination_dir),
      vim.log.levels.INFO
    )
  elseif skipped > 0 and failed == 0 then
    vim.notify(
      "Templates already exist in "
        .. destination_dir
        .. ". Use :LatexToolsInitTemplates! to back up existing files and refresh from the plugin.",
      vim.log.levels.WARN
    )
  elseif failed > 0 then
    vim.notify("Unable to initialize one or more templates in " .. destination_dir, vim.log.levels.ERROR)
  end

  copied.backed_up = backed_up
  copied.backup_dir = backup_dir
  return copied
end

function M.initialize_assignment_template(opts)
  return M.initialize_user_templates(opts)
end

function M.initialize_course_metadata(opts)
  local options = opts or {}
  local paths = M.get_paths()
  local destination = options.destination or paths.yaml_path
  local bundled_yaml_path = default_paths().template_dir .. "/courses.yaml"

  if destination == bundled_yaml_path then
    destination = user_yaml_path()
  end

  return copy_bundled_file({
    source = bundled_yaml_path,
    destination = destination,
    force = options.force,
    label = "Course metadata",
  })
end

function M.initialize_custom_snippets_dir()
  local directory = M.get_paths().custom_snippets_dir
  local ok, result = pcall(vim.fn.mkdir, directory, "p")
  if not ok or result == 0 then
    vim.notify("Unable to create custom snippet directory at " .. directory, vim.log.levels.ERROR)
    return nil
  end

  vim.notify("Custom snippet directory ready at " .. directory, vim.log.levels.INFO)
  return directory
end

-- Companion .tex files that must live beside a course-aware parent (never plugin paths at compile time).
local PROJECT_COMPANIONS = {
  "latex-tools-code.tex",
  "latex-tools-code-minted.tex",
}

function M.project_companions()
  return vim.deepcopy(PROJECT_COMPANIONS)
end

function M.resolve_companion_source(name)
  local paths = M.get_paths()
  local user_path = paths.user_templates_dir .. "/" .. name
  if is_readable(user_path) then
    return user_path
  end
  local bundled_path = paths.template_dir .. "/" .. name
  if is_readable(bundled_path) then
    return bundled_path
  end
  return nil
end

--- Copy companion inputs next to a saved parent document. Never overwrites existing files.
function M.ensure_project_companions(parent_path)
  if not parent_path or parent_path == "" then
    return nil
  end

  local project_dir = vim.fn.fnamemodify(parent_path, ":h")
  local created = {}
  local skipped = {}
  local failed = {}

  for _, name in ipairs(PROJECT_COMPANIONS) do
    local destination = project_dir .. "/" .. name
    local source = M.resolve_companion_source(name)
    if not source then
      table.insert(failed, name)
    else
      local _, status = copy_bundled_file({
        source = source,
        destination = destination,
        force = false,
        label = name,
        quiet = true,
      })
      if status == "created" then
        table.insert(created, name)
      elseif status == "skipped" then
        table.insert(skipped, name)
      else
        table.insert(failed, name)
      end
    end
  end

  if #created > 0 then
    vim.notify(
      "Copied project companions: " .. table.concat(created, ", ") .. " → " .. project_dir,
      vim.log.levels.INFO
    )
  end
  if #failed > 0 then
    vim.notify(
      "Unable to copy project companions: " .. table.concat(failed, ", "),
      vim.log.levels.ERROR
    )
  end

  return {
    created = created,
    skipped = skipped,
    failed = failed,
    project_dir = project_dir,
  }
end

function M.run_command(argv)
  local output = vim.fn.system(argv)
  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    vim.notify(util.sanitize_message(output), vim.log.levels.ERROR)
    return nil
  end
  return output
end

return M