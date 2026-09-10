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
    [{ vim.fn, "input" }] = function(_prompt, _default)
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
  assert_true(line == "Prior work\\cite{smith2024}", "BibTeX key helper did not insert citation")
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
  local mkdir_path = nil

  templates.setup({
    keymaps = { enable = false },
    commands = { enable = false },
    paths = { custom_snippets_dir = destination },
  })

  with_stubs({
    [{ vim.fn, "mkdir" }] = function(path, flag)
      mkdir_path = path
      assert_true(flag == "p", "Expected mkdir -p semantics")
      return 1
    end,
  }, function()
    local result = templates.init_custom_snippets_dir()
    assert_true(result == destination, "Expected configured snippet directory")
  end)

  templates.setup({ keymaps = { enable = false }, commands = { enable = false } })
  assert_true(mkdir_path == destination, "Expected snippet directory to be created")
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
    assert_true(result == destination, "Expected bootstrap to target the user config YAML")
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
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nonexistent-nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(_path)
      return 0
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

  with_stubs({
    [{ vim.fn, "stdpath" }] = function(kind)
      assert_true(kind == "config", "Unexpected stdpath request")
      return "/tmp/nonexistent-nvim-config"
    end,
    [{ vim.fn, "filereadable" }] = function(_path)
      return 0
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
end)

io.write(string.format("\nRESULT: %d passed, %d failed\n", passed, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
