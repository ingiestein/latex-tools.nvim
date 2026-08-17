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
    vim.notify(label .. " already exists at " .. destination, vim.log.levels.WARN)
    return destination
  end

  local ok, lines = pcall(vim.fn.readfile, source)
  if not ok then
    vim.notify("Unable to read bundled " .. label:lower(), vim.log.levels.ERROR)
    return nil
  end

  vim.fn.mkdir(vim.fn.fnamemodify(destination, ":h"), "p")

  local write_ok, write_result = pcall(vim.fn.writefile, lines, destination)
  if not write_ok or write_result ~= 0 then
    vim.notify("Unable to write " .. label:lower() .. " to " .. destination, vim.log.levels.ERROR)
    return nil
  end

  vim.notify("Created " .. label:lower() .. " at " .. destination, vim.log.levels.INFO)
  return destination
end

local function default_paths()
  local root = plugin_root()
  local template_dir = root .. "/templates"
  local bundled_yaml_path = template_dir .. "/courses.yaml"
  local preferred_yaml_path = user_yaml_path()
  local bundled_template_path = template_dir .. "/assignment.tex"
  local preferred_template_path = user_template_path()
  return {
    template_dir = template_dir,
    yaml_path = is_readable(preferred_yaml_path) and preferred_yaml_path or bundled_yaml_path,
    tex_template_path = is_readable(preferred_template_path) and preferred_template_path or bundled_template_path,
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
  return user_template_path()
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

function M.initialize_assignment_template(opts)
  local options = opts or {}
  local paths = M.get_paths()
  local destination = options.destination or paths.tex_template_path
  local bundled_template_path = default_paths().template_dir .. "/assignment.tex"

  if destination == bundled_template_path then
    destination = user_template_path()
  end

  return copy_bundled_file({
    source = bundled_template_path,
    destination = destination,
    force = options.force,
    label = "Assignment template",
  })
end

function M.run_command(argv)
  local output = vim.fn.system(argv)
  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    local err = output ~= "" and output or "Command failed"
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  return output
end

return M