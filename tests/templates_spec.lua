local function setup_runtime_path()
  local source = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ":p:h:h")
  local plugin_lua = plugin_root .. "/lua"
  package.path = plugin_lua .. "/?.lua;" .. plugin_lua .. "/?/init.lua;" .. package.path
end

local function assert_true(condition, message)
  if not condition then
    error(message or "assert_true failed")
  end
end

local function assert_contains(lines, needle, message)
  local haystack = table.concat(lines, "\n")
  if not haystack:find(needle, 1, true) then
    error(message or ("Expected to find: " .. needle))
  end
end

local function get_buffer_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function new_buffer()
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function with_stubs(stubs, fn)
  local original = {}
  for key, value in pairs(stubs) do
    local target = key[1]
    local field = key[2]
    original[key] = target[field]
    target[field] = value
  end

  local ok, err = pcall(fn)

  for key, _ in pairs(stubs) do
    local target = key[1]
    local field = key[2]
    target[field] = original[key]
  end

  if not ok then
    error(err)
  end
end

setup_runtime_path()
local templates = require("latex-tools")
local state = require("latex-tools.state")
local util = require("latex-tools.util")
templates.setup({ keymaps = { enable = false }, commands = { enable = false } })

local passed = 0
local failed = 0

local function run_test(name, fn)
  io.write("[TEST] " .. name .. " ... ")
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.write("OK\n")
  else
    failed = failed + 1
    io.write("FAIL\n")
    io.write("  " .. tostring(err) .. "\n")
  end
end

run_test("basic figure snippet inserts placeholder", function()
  new_buffer()
  templates.insert_basic_figure_snippet()
  local lines = get_buffer_lines()
  assert_contains(lines, "\\begin{figure}[htbp]")
  assert_contains(lines, "\\includegraphics[width=0.85\\linewidth]{figures/figure-file-name}")
  assert_contains(lines, "\\caption{Short, descriptive caption.}")
end)

run_test("basic table snippet inserts placeholder", function()
  new_buffer()
  templates.insert_basic_table_snippet()
  local lines = get_buffer_lines()
  assert_contains(lines, "\\begin{table}[htbp]")
  assert_contains(lines, "\\begin{tabular}{p{0.28\\linewidth}p{0.28\\linewidth}p{0.28\\linewidth}}")
  assert_contains(lines, "\\bottomrule")
end)

run_test("interactive footnote inserts inline content", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Hello" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })

  with_stubs({
    [{ vim.fn, "input" }] = function(_prompt, _default)
      return "Test note"
    end,
  }, function()
    templates.insert_footnote_snippet()
  end)

  local line = vim.api.nvim_get_current_line()
  assert_true(line == "Hello\\footnote{Test note}", "Footnote was not inserted as expected")
end)

run_test("interactive table builder uses prompted values", function()
  new_buffer()

  local responses = {
    "Model performance",
    "2",
    "2",
    "Metric",
    "Value",
    "tab:model-performance",
  }

  with_stubs({
    [{ vim.fn, "input" }] = function(_prompt, _default)
      return table.remove(responses, 1)
    end,
  }, function()
    templates.insert_table_snippet()
  end)

  local lines = get_buffer_lines()
  assert_contains(lines, "\\caption{Model performance}")
  assert_contains(lines, "\\label{tab:model-performance}")
  assert_contains(lines, "Metric & Value \\")
  assert_contains(lines, "Value 1.1 & Value 1.2 \\")
end)

run_test("interactive figure picker selects image and caption", function()
  new_buffer()

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/sub", "p")

  local f1 = io.open(tmp .. "/a.png", "w")
  if f1 then
    f1:write("x")
    f1:close()
  end

  local f2 = io.open(tmp .. "/sub/b.jpg", "w")
  if f2 then
    f2:write("x")
    f2:close()
  end

  local original_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(tmp))

  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      on_choice(items[1])
    end,
    [{ vim.fn, "input" }] = function(prompt, default)
      if prompt:find("width", 1, true) then
        return default
      end
      return "Chosen caption"
    end,
  }, function()
    templates.insert_figure_snippet()
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

  local lines = get_buffer_lines()
  assert_contains(lines, "\\includegraphics[width=0.85\\linewidth]{a.png}")
  assert_contains(lines, "\\caption{Chosen caption}")
  assert_contains(lines, "\\label{fig:a}")
end)

run_test("reference helper inserts selected label reference", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "See Figure.",
    "\\label{fig:overview}",
    "\\label{tab:results}",
  })
  vim.api.nvim_win_set_cursor(0, { 1, 10 })

  local select_calls = 0
  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      select_calls = select_calls + 1
      if select_calls == 1 then
        on_choice(items[1])
      else
        on_choice(items[2])
      end
    end,
  }, function()
    templates.insert_reference_snippet()
  end)

  local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
  assert_true(line == "See Figure.\\ref{tab:results}", "Reference helper did not insert selected label")
end)

run_test("BibTeX key helper inserts selected citation", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Prior work" })
  vim.api.nvim_win_set_cursor(0, { 1, 10 })

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  vim.fn.writefile({
    "@article{smith2024,",
    "  title={Example Title}",
    "}",
  }, tmp .. "/refs.bib")

  local original_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(tmp))

  local select_calls = 0
  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      select_calls = select_calls + 1
      on_choice(items[1])
    end,
  }, function()
    templates.insert_bib_key_snippet()
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

  local line = vim.api.nvim_get_current_line()
  assert_true(line == "Prior work\\citep{smith2024}", "BibTeX helper did not insert citation")
end)

run_test("custom snippet picker inserts selected file", function()
  new_buffer()

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/nested", "p")
  vim.fn.writefile({ "\\section{Reusable}" }, tmp .. "/section.tex")
  vim.fn.writefile({ "\\textbf{Nested}" }, tmp .. "/nested/text.tex")

  templates.setup({
    keymaps = { enable = false },
    commands = { enable = false },
    paths = { custom_snippets_dir = tmp },
  })

  with_stubs({
    [{ vim.ui, "select" }] = function(items, options, on_choice)
      assert_true(#items == 2, "Expected two custom snippets")
      assert_true(options.format_item(items[2]) == "section.tex", "Expected relative snippet labels")
      on_choice(items[2])
    end,
  }, function()
    templates.insert_custom_snippet()
  end)

  templates.setup({ keymaps = { enable = false }, commands = { enable = false } })
  assert_contains(get_buffer_lines(), "\\section{Reusable}")
end)

run_test("CSV helper converts selected file into a table", function()
  new_buffer()

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  vim.fn.writefile({
    "Metric,Value",
    "AUROC,0.91",
    "F1,0.72",
  }, tmp .. "/metrics.csv")

  local original_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(tmp))

  local select_calls = 0
  local inputs = { "Performance summary", "tab:perf-summary" }
  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      select_calls = select_calls + 1
      on_choice(items[1])
    end,
    [{ vim.fn, "input" }] = function(_prompt, default)
      return table.remove(inputs, 1) or default or ""
    end,
  }, function()
    templates.insert_table_from_csv()
  end)

  vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

  local lines = get_buffer_lines()
  assert_contains(lines, "\\caption{Performance summary}")
  assert_contains(lines, "\\label{tab:perf-summary}")
  assert_contains(lines, "Metric & Value \\")
  assert_contains(lines, "AUROC & 0.91 \\")
  assert_contains(lines, "F1 & 0.72 \\")
end)

run_test("state prefers user config course metadata when present", function()
  local expected = "/tmp/nvim-config/latex-tools/courses.yaml"

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == expected then
        return 1
      end
      return 0
    end,
  }, function()
    local paths = state.get_paths()
    assert_true(paths.yaml_path == expected, "Expected user config YAML to be preferred")
  end)
end)

run_test("state prefers user templates directory assignment template when present", function()
  local expected = "/tmp/nvim-config/latex-tools/templates/assignment.tex"

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == expected then
        return 1
      end
      return 0
    end,
  }, function()
    local paths = state.get_paths()
    assert_true(paths.tex_template_path == expected, "Expected user templates assignment to be preferred")
  end)
end)

run_test("state falls back to legacy assignment template path", function()
  local legacy = "/tmp/nvim-config/latex-tools/assignment.tex"

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == legacy then
        return 1
      end
      return 0
    end,
  }, function()
    local paths = state.get_paths()
    assert_true(paths.tex_template_path == legacy, "Expected legacy assignment template to be preferred")
  end)
end)

run_test("custom snippet directory bootstrap creates configured directory", function()
  local destination = "/tmp/nvim-config/latex-tools/snippets"
  local mkdir_paths = {}

  templates.setup({
    keymaps = { enable = false },
    commands = { enable = false },
    paths = { custom_snippets_dir = destination },
  })

  with_stubs({
    [{ vim.fn, "mkdir" }] = function(path, flag)
      table.insert(mkdir_paths, path)
      assert_true(flag == "p", "Expected mkdir -p semantics")
      return 1
    end,
    [{ vim.fn, "isdirectory" }] = function(_path)
      return 0
    end,
  }, function()
    local result = templates.init_custom_snippets_dir()
    assert_true(result == destination, "Expected configured snippet directory")
  end)

  templates.setup({ keymaps = { enable = false }, commands = { enable = false } })
  assert_true(mkdir_paths[1] == destination, "Expected snippet directory to be created")
end)

run_test("combined user file bootstrap runs every initializer", function()
  local calls = {}

  with_stubs({
    [{ state, "initialize_custom_snippets_dir" }] = function()
      table.insert(calls, "snippets")
      return "/tmp/snippets"
    end,
    [{ state, "initialize_user_templates" }] = function(opts)
      table.insert(calls, "templates")
      assert_true(opts.force == true, "Expected force option for user templates")
      return { "/tmp/templates/assignment.tex" }
    end,
    [{ state, "initialize_course_metadata" }] = function(opts)
      table.insert(calls, "metadata")
      assert_true(opts.force == true, "Expected force option for course metadata")
      return "/tmp/courses.yaml"
    end,
  }, function()
    local result = templates.init_all({ force = true })
    assert_true(result.snippets_dir == "/tmp/snippets", "Expected snippet directory result")
    assert_true(result.templates[1] == "/tmp/templates/assignment.tex", "Expected templates result")
    assert_true(result.metadata == "/tmp/courses.yaml", "Expected metadata result")
  end)

  assert_true(table.concat(calls, ",") == "snippets,templates,metadata", "Expected every initializer to run")
end)

run_test("init_all can initialize templates without metadata", function()
  local calls = {}

  with_stubs({
    [{ state, "initialize_user_templates" }] = function(opts)
      table.insert(calls, "templates")
      assert_true(opts.force == true, "Expected force option for templates-only init")
      return { "/tmp/templates/assignment.tex" }
    end,
    [{ state, "initialize_course_metadata" }] = function()
      error("metadata init should not run")
    end,
    [{ state, "initialize_custom_snippets_dir" }] = function()
      error("snippets init should not run")
    end,
  }, function()
    local result = templates.init_all({ templates = true, metadata = false, snippets = false, force = true })
    assert_true(result.templates[1] == "/tmp/templates/assignment.tex", "Expected templates-only result")
    assert_true(result.metadata == nil, "Expected metadata to be skipped")
    assert_true(result.snippets_dir == nil, "Expected snippets to be skipped")
  end)

  assert_true(table.concat(calls, ",") == "templates", "Expected only templates initializer to run")
end)

run_test("course metadata bootstrap writes starter file to user config", function()
  local destination = "/tmp/nvim-config/latex-tools/courses.yaml"
  local wrote_lines = nil
  local wrote_path = nil
  local mkdir_path = nil

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == destination then
        return 0
      end
      if path:sub(-#"/templates/courses.yaml") == "/templates/courses.yaml" then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "readfile" }] = function(path)
      assert_true(path:sub(-#"/templates/courses.yaml") == "/templates/courses.yaml", "Unexpected source YAML path")
      return { "academic_profile:", "course_catalog:" }
    end,
    [{ vim.fn, "writefile" }] = function(lines, path)
      wrote_lines = lines
      wrote_path = path
      return 0
    end,
    [{ vim.fn, "mkdir" }] = function(path, flag)
      mkdir_path = path
      assert_true(flag == "p", "Expected mkdir -p semantics")
      return 1
    end,
  }, function()
    local result = templates.init_course_metadata()
    assert_true(result[1] == destination, "Expected bootstrap to target the user config YAML")
  end)

  assert_true(mkdir_path == "/tmp/nvim-config/latex-tools", "Expected bootstrap to create the config directory")
  assert_true(wrote_path == destination, "Expected bootstrap to write the user config YAML")
  assert_true(type(wrote_lines) == "table" and wrote_lines[1] == "academic_profile:", "Expected bootstrap to copy starter YAML content")
end)

run_test("user templates bootstrap writes bundled templates to user directory", function()
  local destination = "/tmp/nvim-config/latex-tools/templates/assignment.tex"
  local bundled_assignment = state.get_paths().template_dir .. "/assignment.tex"
  local wrote_lines = nil
  local wrote_path = nil
  local mkdir_path = nil

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == destination then
        return 0
      end
      if path == bundled_assignment then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "glob" }] = function(pattern, _a, _b)
      if pattern:find("/templates/*.tex", 1, true) then
        return { bundled_assignment }
      end
      return {}
    end,
    [{ vim.fn, "readfile" }] = function(path)
      assert_true(path == bundled_assignment, "Unexpected source template path")
      return { "\\documentclass{article}", "\\begin{document}" }
    end,
    [{ vim.fn, "writefile" }] = function(lines, path)
      wrote_lines = lines
      wrote_path = path
      return 0
    end,
    [{ vim.fn, "mkdir" }] = function(path, flag)
      mkdir_path = path
      assert_true(flag == "p", "Expected mkdir -p semantics")
      return 1
    end,
  }, function()
    local result = templates.init_user_templates()
    assert_true(type(result) == "table" and result[1] == destination, "Expected bootstrap to target the user templates directory")
  end)

  assert_true(mkdir_path == "/tmp/nvim-config/latex-tools/templates", "Expected bootstrap to create the templates directory")
  assert_true(wrote_path == destination, "Expected bootstrap to write the user assignment template")
  assert_true(type(wrote_lines) == "table" and wrote_lines[1] == "\\documentclass{article}", "Expected bootstrap to copy starter template content")
end)

run_test("force template refresh backs up conflicts then writes fresh copies", function()
  local templates_dir = "/tmp/nvim-config/latex-tools/templates"
  local destination = templates_dir .. "/assignment.tex"
  local custom_only = templates_dir .. "/my-custom.tex"
  local bundled_assignment = state.get_paths().template_dir .. "/assignment.tex"
  local renamed_from = nil
  local renamed_to = nil
  local wrote_path = nil
  local existing = {
    [destination] = true,
    [custom_only] = true,
    [bundled_assignment] = true,
  }

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return existing[path] and 1 or 0
    end,
    [{ vim.fn, "glob" }] = function(pattern, _a, _b)
      if pattern:find("/templates/*.tex", 1, true) then
        return { bundled_assignment }
      end
      return {}
    end,
    [{ vim.fn, "readfile" }] = function(path)
      assert_true(path == bundled_assignment, "Unexpected source template path")
      return { "% fresh bundled assignment" }
    end,
    [{ vim.fn, "writefile" }] = function(_lines, path)
      wrote_path = path
      existing[path] = true
      return 0
    end,
    [{ vim.fn, "mkdir" }] = function(_path, _flag)
      return 1
    end,
    [{ vim.fn, "rename" }] = function(from, to)
      renamed_from = from
      renamed_to = to
      existing[from] = nil
      existing[to] = true
      return 0
    end,
  }, function()
    local result = templates.init_user_templates({ force = true })
    assert_true(result[1] == destination, "Expected refreshed assignment path")
    assert_true(type(result.backup_dir) == "string", "Expected backup_dir on result")
    assert_true(result.backup_dir:find("templates%-backup/", 1) ~= nil, "Expected templates-backup path")
    assert_true(result.backed_up[1] == result.backup_dir .. "/assignment.tex", "Expected backed up assignment")
    assert_true(existing[custom_only] == true, "Expected user-only template to remain")
  end)

  assert_true(renamed_from == destination, "Expected existing assignment moved to backup")
  assert_true(renamed_to:find("templates%-backup/", 1) ~= nil, "Expected rename into backup dir")
  assert_true(wrote_path == destination, "Expected fresh assignment written to templates/")
end)

run_test("non-force template init skips existing files without backup", function()
  local destination = "/tmp/nvim-config/latex-tools/templates/assignment.tex"
  local bundled_assignment = state.get_paths().template_dir .. "/assignment.tex"
  local rename_called = false

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == destination or path == bundled_assignment then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "glob" }] = function(pattern, _a, _b)
      if pattern:find("/templates/*.tex", 1, true) then
        return { bundled_assignment }
      end
      return {}
    end,
    [{ vim.fn, "mkdir" }] = function(_path, _flag)
      return 1
    end,
    [{ vim.fn, "rename" }] = function(_from, _to)
      rename_called = true
      return 0
    end,
  }, function()
    local result = templates.init_user_templates()
    assert_true(result[1] == destination, "Expected existing path returned as skipped/copied entry")
    assert_true(result.backup_dir == nil, "Expected no backup dir without force")
    assert_true(#(result.backed_up or {}) == 0, "Expected no backups without force")
  end)

  assert_true(rename_called == false, "Expected rename not called without force")
end)

run_test("force metadata refresh backs up courses.yaml then writes fresh copy", function()
  local destination = "/tmp/nvim-config/latex-tools/courses.yaml"
  local bundled = state.get_paths().template_dir .. "/courses.yaml"
  local renamed_from = nil
  local renamed_to = nil
  local wrote_path = nil
  local existing = {
    [destination] = true,
    [bundled] = true,
  }

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return existing[path] and 1 or 0
    end,
    [{ vim.fn, "readfile" }] = function(path)
      assert_true(path == bundled, "Unexpected source YAML path")
      return { "academic_profile:", "  institution: Fresh University" }
    end,
    [{ vim.fn, "writefile" }] = function(_lines, path)
      wrote_path = path
      existing[path] = true
      return 0
    end,
    [{ vim.fn, "mkdir" }] = function(_path, _flag)
      return 1
    end,
    [{ vim.fn, "rename" }] = function(from, to)
      renamed_from = from
      renamed_to = to
      existing[from] = nil
      existing[to] = true
      return 0
    end,
  }, function()
    local result = templates.init_metadata({ force = true })
    assert_true(result[1] == destination, "Expected refreshed courses.yaml path")
    assert_true(type(result.backup_dir) == "string", "Expected backup_dir on result")
    assert_true(result.backup_dir:find("metadata%-backup/", 1) ~= nil, "Expected metadata-backup path")
    assert_true(result.backed_up == result.backup_dir .. "/courses.yaml", "Expected backed up courses.yaml")
  end)

  assert_true(renamed_from == destination, "Expected existing courses.yaml moved to backup")
  assert_true(renamed_to:find("metadata%-backup/", 1) ~= nil, "Expected rename into metadata-backup")
  assert_true(wrote_path == destination, "Expected fresh courses.yaml written")
end)

run_test("non-force metadata init skips existing courses.yaml without backup", function()
  local destination = "/tmp/nvim-config/latex-tools/courses.yaml"
  local rename_called = false

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == destination then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "rename" }] = function(_from, _to)
      rename_called = true
      return 0
    end,
  }, function()
    local result = templates.init_metadata()
    assert_true(result[1] == destination, "Expected existing path returned")
    assert_true(result.backup_dir == nil, "Expected no backup dir without force")
    assert_true(result.backed_up == nil, "Expected no backup without force")
  end)

  assert_true(rename_called == false, "Expected rename not called without force")
end)

run_test("template picker excludes subfile template", function()
  local document_templates = require("latex-tools.templates")
  local bundled_dir = state.get_paths().template_dir

  with_stubs({
    [{ vim.fn, "isdirectory" }] = function(path)
      if path == bundled_dir then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "globpath" }] = function(directory, pattern, _a, _b)
      if pattern == "*.tex" and directory == bundled_dir then
        return {
          bundled_dir .. "/assignment.tex",
          bundled_dir .. "/subfile.tex",
          bundled_dir .. "/latex-tools-code.tex",
          bundled_dir .. "/latex-tools-code-minted.tex",
        }
      end
      return {}
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return path:sub(-#".tex") == ".tex" and 1 or 0
    end,
    [{ vim.fn, "readfile" }] = function(path)
      if path:sub(-#"assignment.tex") == "assignment.tex" then
        return { "% latex-tools: course-aware" }
      end
      return {}
    end,
  }, function()
    local items = document_templates.list_templates()
    for _, item in ipairs(items) do
      assert_true(item.name ~= "subfile.tex", "Expected subfile.tex to be excluded from picker")
      assert_true(item.name ~= "latex-tools-code.tex", "Expected latex-tools-code.tex to be excluded from picker")
      assert_true(
        item.name ~= "latex-tools-code-minted.tex",
        "Expected latex-tools-code-minted.tex to be excluded from picker"
      )
    end
    assert_true(#items >= 1, "Expected other templates to remain available")
  end)
end)

run_test("subfile template rendering substitutes parent file name", function()
  local subfiles = require("latex-tools.subfiles")
  local rendered = subfiles.render_subfile_template({
    "% !TEX root = ../main.tex",
    "\\documentclass[../main]{subfiles}",
  }, "/tmp/project/assignment-3.tex")

  assert_contains(rendered, "% !TEX root = ../assignment-3.tex")
  assert_contains(rendered, "\\documentclass[../assignment-3]{subfiles}")
end)

run_test("subfile include path uses relative subfile directory", function()
  local subfiles = require("latex-tools.subfiles")
  assert_true(
    subfiles.build_subfile_include_path("chapter-one.tex") == "./subfile/chapter-one.tex",
    "Expected relative include path"
  )
end)

run_test("create subfile writes customized file and opens split", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "% latex-tools: course-aware",
    "\\documentclass{article}",
    "\\begin{document}",
    "",
    "\\end{document}",
  })
  -- Insert should use the pre-prompt cursor line (middle of buffer), not line 1.
  vim.api.nvim_win_set_cursor(0, { 4, 0 })

  local mkdir_path = nil
  local wrote_path = nil
  local wrote_lines = nil
  local split_cmd = nil
  local bundled_dir = state.get_paths().template_dir

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/assignment-3.tex"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == "/tmp/project/assignment-3.tex" then
        return 1
      end
      if path == bundled_dir .. "/subfile.tex" then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "readfile" }] = function(path)
      if path == bundled_dir .. "/subfile.tex" then
        return {
          "% !TEX root = ../main.tex",
          "\\documentclass[../main]{subfiles}",
          "\\begin{document}",
          "\\end{document}",
        }
      end
      return {}
    end,
    [{ vim.fn, "input" }] = function(prompt, _default)
      -- Simulate cmdline input leaving the window cursor stale at line 1.
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      if prompt:find("Subfile name", 1, true) then
        return "chapter-one"
      end
      return ""
    end,
    [{ vim.fn, "mkdir" }] = function(path, flag)
      mkdir_path = path
      assert_true(flag == "p", "Expected mkdir -p semantics")
      return 1
    end,
    [{ vim.fn, "writefile" }] = function(lines, path)
      wrote_lines = lines
      wrote_path = path
      return 0
    end,
    [{ vim, "cmd" }] = function(command)
      split_cmd = command
    end,
  }, function()
    require("latex-tools.subfiles").create_subfile()
  end)

  local lines = get_buffer_lines()
  assert_true(mkdir_path == "/tmp/project/subfile", "Expected subfile directory")
  assert_true(wrote_path == "/tmp/project/subfile/chapter-one.tex", "Expected subfile path")
  assert_contains(wrote_lines, "% !TEX root = ../assignment-3.tex")
  assert_contains(wrote_lines, "\\documentclass[../assignment-3]{subfiles}")
  assert_true(lines[4] == "\\subfile{./subfile/chapter-one.tex}", "Expected include at pre-prompt cursor line")
  assert_true(lines[1] ~= "\\subfile{./subfile/chapter-one.tex}", "Include must not use post-input cursor")
  assert_true(split_cmd:find("rightbelow vsplit", 1, true) ~= nil, "Expected right split")
end)

run_test("create subfile rejects unsaved course-aware buffer", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "% latex-tools: course-aware" })

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return ""
    end,
  }, function()
    require("latex-tools.subfiles").create_subfile()
  end)
end)

run_test("create subfile rejects non-course-aware buffer", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "\\documentclass{article}" })

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/assignment-3.tex"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return path == "/tmp/project/assignment-3.tex" and 1 or 0
    end,
    [{ vim.fn, "input" }] = function()
      error("input should not be called for non-course-aware buffer")
    end,
  }, function()
    require("latex-tools.subfiles").create_subfile()
  end)
end)

run_test("valid_date accepts ISO dates and rejects malformed values", function()
  assert_true(util.valid_date("2026-10-01"), "Expected valid date to pass")
  assert_true(util.valid_date("2024-02-29"), "Expected leap day to pass")
  assert_true(not util.valid_date("2026-13-01"), "Expected invalid month to fail")
  assert_true(not util.valid_date("2026-02-30"), "Expected invalid day to fail")
  assert_true(not util.valid_date("10/01/2026"), "Expected non-ISO format to fail")
end)

run_test("sanitize_message strips control characters and truncates output", function()
  local cleaned = util.sanitize_message("line one\nline two\tbad", 100)
  assert_true(cleaned == "line one line two bad", "Expected control characters to be normalized")
  assert_true(#util.sanitize_message(string.rep("x", 600), 100) == 103, "Expected truncation with ellipsis")
end)

run_test("template metadata marks bundled assignment as course-aware", function()
  local assignment_path = state.get_paths().template_dir .. "/assignment.tex"
  assert_true(util.is_course_aware_template(assignment_path), "Expected bundled assignment metadata to be detected")
end)

run_test("assignment flow rejects invalid due dates", function()
  new_buffer()
  local due_prompts = 0

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/main.tex"
    end,
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nonexistent-nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == "/tmp/project/main.tex" then
        return 1
      end
      return 0
    end,
    [{ state, "ensure_project_companions" }] = function(_path)
      return { created = {}, skipped = {}, failed = {} }
    end,
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      on_choice(items[1])
    end,
    [{ vim.fn, "input" }] = function(prompt, default)
      if prompt:find("Assignment title", 1, true) then
        return "Automated Test Assignment"
      end
      if prompt:find("Due date", 1, true) then
        due_prompts = due_prompts + 1
        if due_prompts == 1 then
          return "not-a-date"
        end
        return "2026-10-01"
      end
      return default or ""
    end,
  }, function()
    templates.insert_assignment_template()
  end)

  assert_true(due_prompts == 2, "Expected invalid due date to trigger a second prompt")
end)

run_test("assignment template flow inserts rendered document", function()
  new_buffer()
  local companion_parent = nil

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/main.tex"
    end,
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nonexistent-nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == "/tmp/project/main.tex" then
        return 1
      end
      return 0
    end,
    [{ state, "ensure_project_companions" }] = function(path)
      companion_parent = path
      return { created = { "latex-tools-code.tex" }, skipped = {}, failed = {} }
    end,
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      on_choice(items[1])
    end,
    [{ vim.fn, "input" }] = function(prompt, default)
      if prompt:find("Assignment title", 1, true) then
        return "Automated Test Assignment"
      end
      if prompt:find("Due date", 1, true) then
        return "2026-10-01"
      end
      return default or ""
    end,
  }, function()
    templates.insert_assignment_template()
  end)

  local lines = get_buffer_lines()
  assert_contains(lines, "\\newcommand{\\AssignmentTitle}{Automated Test Assignment}")
  assert_contains(lines, "\\newcommand{\\DueDate}{2026-10-01}")
  assert_contains(lines, "\\newcommand{\\CourseCode}{COURSE 6101-001}")
  assert_contains(lines, "\\input{latex-tools-code}")
  assert_true(companion_parent == "/tmp/project/main.tex", "Expected companions copied beside saved parent")
end)

run_test("assignment insert requires a saved buffer", function()
  new_buffer()

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return ""
    end,
    [{ vim.ui, "select" }] = function()
      error("course picker should not open for unsaved buffer")
    end,
  }, function()
    templates.insert_assignment_template()
  end)
end)

run_test("ensure_project_companions copies missing code styles beside parent", function()
  local project_dir = "/tmp/project-companions"
  local parent = project_dir .. "/main.tex"
  local wrote_paths = {}
  local bundled = state.get_paths().template_dir

  with_stubs({
    [{ vim.fn, "filereadable" }] = function(path)
      if path:find(project_dir, 1, true) then
        return 0
      end
      if path:sub(-#"latex-tools-code.tex") == "latex-tools-code.tex"
        or path:sub(-#"latex-tools-code-minted.tex") == "latex-tools-code-minted.tex" then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "readfile" }] = function(path)
      if path:sub(-#"latex-tools-code-minted.tex") == "latex-tools-code-minted.tex" then
        return { "% minted companion" }
      end
      if path:sub(-#"latex-tools-code.tex") == "latex-tools-code.tex" then
        return { "% listings companion" }
      end
      error("Unexpected companion source: " .. path)
    end,
    [{ vim.fn, "writefile" }] = function(_lines, path)
      table.insert(wrote_paths, path)
      return 0
    end,
    [{ vim.fn, "mkdir" }] = function(_path, _flag)
      return 1
    end,
  }, function()
    local result = state.ensure_project_companions(parent)
    assert_true(#result.created == 2, "Expected both companions created")
    assert_true(result.project_dir == project_dir, "Expected project directory")
    local companions = state.project_companions()
    assert_true(companions[1] == "latex-tools-code.tex", "Expected listings companion in manifest")
    assert_true(companions[2] == "latex-tools-code-minted.tex", "Expected minted companion in manifest")
  end)

  assert_true(#wrote_paths == 2, "Expected both companions written beside parent")
end)

run_test("UseMinted toggles active code companion input line", function()
  new_buffer()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "% latex-tools: course-aware",
    "\\input{latex-tools-code}",
    "\\begin{document}",
  })

  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/main.tex"
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      if path == "/tmp/project/main.tex" then
        return 1
      end
      return 0
    end,
    [{ state, "ensure_project_companions" }] = function(_path)
      return { created = {}, skipped = {}, failed = {} }
    end,
  }, function()
    local code_fences = require("latex-tools.code_fences")
    assert_true(code_fences.use_minted_companion({ minted = true }) == "latex-tools-code-minted")
    assert_contains(get_buffer_lines(), "\\input{latex-tools-code-minted}")
    assert_true(code_fences.use_minted_companion({ minted = false }) == "latex-tools-code")
    assert_contains(get_buffer_lines(), "\\input{latex-tools-code}")
  end)
end)

run_test("built-in code snippets use short fence environments", function()
  new_buffer()
  templates.insert_snippet("p")
  local lines = get_buffer_lines()
  assert_contains(lines, "\\begin{python}")
  assert_contains(lines, "\\end{python}")
end)

run_test("refresh_metadata aborts when confirm is declined", function()
  local commands = require("latex-tools.commands")
  local rename_called = false
  local refresh_called = false

  with_stubs({
    [{ vim.fn, "confirm" }] = function(_msg, _choices, default, _type)
      assert_true(default == 2, "Expected No as default confirm choice")
      return 2
    end,
    [{ templates, "refresh_metadata" }] = function()
      refresh_called = true
      return { "/tmp/courses.yaml" }
    end,
    [{ vim.fn, "rename" }] = function(_from, _to)
      rename_called = true
      return 0
    end,
  }, function()
    local result = commands.refresh_metadata()
    assert_true(result == nil, "Expected nil when refresh is cancelled")
  end)

  assert_true(refresh_called == false, "Expected Lua refresh not called after cancel")
  assert_true(rename_called == false, "Expected rename not called after cancel")
end)

run_test("refresh_metadata proceeds when confirm is accepted", function()
  local commands = require("latex-tools.commands")
  local refresh_called = false

  with_stubs({
    [{ vim.fn, "confirm" }] = function(_msg, _choices, _default, _type)
      return 1
    end,
    [{ templates, "refresh_metadata" }] = function()
      refresh_called = true
      return { "/tmp/courses.yaml" }
    end,
  }, function()
    local result = commands.refresh_metadata()
    assert_true(result[1] == "/tmp/courses.yaml", "Expected refresh result when confirmed")
  end)

  assert_true(refresh_called == true, "Expected Lua refresh after confirm")
end)

run_test("install and refresh Lua aliases map force correctly", function()
  with_stubs({
    [{ state, "initialize_course_metadata" }] = function(opts)
      assert_true(opts.force == false, "Expected install_metadata force false")
      return { "/tmp/courses.yaml" }
    end,
    [{ state, "initialize_user_templates" }] = function(opts)
      assert_true(opts.force == false, "Expected install_templates force false")
      return { "/tmp/templates/assignment.tex" }
    end,
  }, function()
    templates.install_metadata()
    templates.install_templates()
  end)

  with_stubs({
    [{ state, "initialize_course_metadata" }] = function(opts)
      assert_true(opts.force == true, "Expected refresh_metadata force true")
      return { "/tmp/courses.yaml" }
    end,
    [{ state, "initialize_user_templates" }] = function(opts)
      assert_true(opts.force == true, "Expected refresh_templates force true")
      return { "/tmp/templates/assignment.tex" }
    end,
    [{ state, "initialize_custom_snippets_dir" }] = function()
      error("snippets should not run during refresh()")
    end,
  }, function()
    templates.refresh_metadata()
    templates.refresh_templates()
    local refreshed = templates.refresh()
    assert_true(refreshed.snippets_dir == nil, "Expected refresh() to skip snippets")
  end)
end)

run_test("LatexTools menu lists install and refresh actions", function()
  local commands = require("latex-tools.commands")
  local labels = {}

  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      for _, item in ipairs(items) do
        table.insert(labels, item.label)
      end
      on_choice(nil)
    end,
  }, function()
    commands.open_menu()
  end)

  local haystack = table.concat(labels, "\n")
  assert_true(haystack:find("Install missing files only", 1, true) ~= nil, "Expected Install menu item")
  assert_true(haystack:find("Refresh courses.yaml", 1, true) ~= nil, "Expected Refresh metadata menu item")
  assert_true(haystack:find("Refresh templates", 1, true) ~= nil, "Expected Refresh templates menu item")
  assert_true(haystack:find("Use minted companion", 1, true) ~= nil, "Expected minted menu item")
  assert_true(haystack:find("Cited keys", 1, true) ~= nil, "Expected cited keys menu item")
  assert_true(haystack:find("Equation", 1, true) ~= nil, "Expected equation menu item")
end)

run_test("list_files_up_to_depth finds nested extensions", function()
  local found = nil
  with_stubs({
    [{ vim.fn, "getcwd" }] = function()
      return "/tmp/project"
    end,
    [{ vim.fn, "glob" }] = function(pattern, _a, _b)
      if pattern == "/tmp/project/*/*/*.bib" then
        return { "/tmp/project/refs/extra/refs.bib" }
      end
      return {}
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return path == "/tmp/project/refs/extra/refs.bib" and 1 or 0
    end,
    [{ vim.fn, "fnamemodify" }] = function(path, mod)
      if mod == ":." then
        return "refs/extra/refs.bib"
      end
      return path
    end,
  }, function()
    found = util.list_files_up_to_depth({ "bib" }, 4)
  end)
  assert_true(#found == 1 and found[1] == "refs/extra/refs.bib", "Expected nested bib path")
end)

run_test("bib entries parse title author year into labels", function()
  local references = require("latex-tools.references")
  local entries = nil
  with_stubs({
    [{ util, "list_files_up_to_depth" }] = function(_ext, _depth)
      return { "references.bib" }
    end,
    [{ vim.fn, "readfile" }] = function(_path)
      return {
        "@article{smith2020,",
        "  author = {Smith, Ada},",
        "  title = {A Study of Methods},",
        "  year = {2020},",
        "}",
      }
    end,
  }, function()
    entries = references.collect_bib_entries()
  end)
  assert_true(#entries == 1, "Expected one bib entry")
  assert_true(entries[1].key == "smith2020", "Expected key")
  assert_true(entries[1].label:find("Smith", 1, true) ~= nil, "Expected author in label")
  assert_true(entries[1].label:find("2020", 1, true) ~= nil, "Expected year in label")
  assert_true(entries[1].label:find("Study", 1, true) ~= nil, "Expected title in label")
end)

run_test("cited keys report marks missing keys", function()
  local references = require("latex-tools.references")
  new_buffer()

  local report = nil
  with_stubs({
    [{ vim.api, "nvim_buf_get_name" }] = function(_buf)
      return "/tmp/project/main.tex"
    end,
    [{ vim.fn, "fnamemodify" }] = function(path, mod)
      if mod == ":h" then
        return "/tmp/project"
      end
      if mod == ":t" then
        return "project"
      end
      return path
    end,
    [{ vim.fn, "isdirectory" }] = function(_path)
      return 0
    end,
    [{ util, "list_tex_files" }] = function(directory, _recursive)
      if directory == "/tmp/project" then
        return { "/tmp/project/main.tex" }
      end
      return {}
    end,
    [{ vim.fn, "readfile" }] = function(path)
      if path == "/tmp/project/main.tex" then
        return { "See \\citep{smith2020} and \\cite{missing2021}." }
      end
      return {}
    end,
    [{ references, "collect_bib_entries" }] = function()
      return { { key = "smith2020", label = "smith2020" } }
    end,
  }, function()
    report = references.build_cited_keys_report()
  end)

  assert_true(type(report) == "table", "Expected report lines")
  local text = table.concat(report, "\n")
  assert_true(text:find("smith2020", 1, true) ~= nil, "Expected present key")
  assert_true(text:find("missing2021", 1, true) ~= nil, "Expected missing key")
  assert_true(text:find("Missing from .bib: 1", 1, true) ~= nil, "Expected missing count")
end)

run_test("equation insert writes selected environment", function()
  local math_mod = require("latex-tools.math")
  new_buffer()
  with_stubs({
    [{ vim.ui, "select" }] = function(items, _opts, on_choice)
      on_choice(items[1])
    end,
    [{ vim.fn, "input" }] = function(_prompt, default)
      return default
    end,
  }, function()
    math_mod.insert_equation_snippet()
  end)
  local lines = get_buffer_lines()
  assert_contains(lines, "\\begin{equation}")
  assert_contains(lines, "\\label{eq:}")
  assert_contains(lines, "\\end{equation}")
end)

run_test("InstallSnippets seeds bundled academic starters without overwrite", function()
  local dest_dir = "/tmp/nvim-config/latex-tools/snippets"
  local written = {}
  local existing = {
    [dest_dir .. "/academic/align.tex"] = true,
  }

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config")
      return "/tmp/nvim-config"
    end,
    [{ vim.fn, "mkdir" }] = function(_path, _flag)
      return 1
    end,
    [{ vim.fn, "isdirectory" }] = function(path)
      if path:find("/snippets", 1, true) then
        return 1
      end
      return 0
    end,
    [{ vim.fn, "filereadable" }] = function(path)
      return existing[path] and 1 or 0
    end,
    [{ util, "list_tex_files" }] = function(directory, recursive)
      assert_true(recursive == true)
      assert_true(directory:find("/snippets", 1, true) ~= nil)
      return {
        directory .. "/academic/align.tex",
        directory .. "/academic/gather.tex",
      }
    end,
    [{ util, "relative_path" }] = function(path, directory)
      return path:sub(#directory + 2)
    end,
    [{ vim.fn, "readfile" }] = function(path)
      return { "% " .. path }
    end,
    [{ vim.fn, "writefile" }] = function(_lines, path)
      written[path] = true
      existing[path] = true
      return 0
    end,
    [{ vim.fn, "fnamemodify" }] = function(path, mod)
      if mod == ":h" then
        return path:match("(.+)/[^/]+$") or path
      end
      return path
    end,
  }, function()
    local result = templates.init_snippets()
    assert_true(result == dest_dir, "Expected snippets dir path")
  end)

  assert_true(written[dest_dir .. "/academic/align.tex"] == nil, "Expected existing align not overwritten")
  assert_true(written[dest_dir .. "/academic/gather.tex"] == true, "Expected gather seeded")
end)

io.write(string.format("\nRESULT: %d passed, %d failed\n", passed, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
