local config = require("latex-tools.config")
local snippets = require("latex-tools.snippets")
local figures = require("latex-tools.figures")
local tables = require("latex-tools.tables")
local references = require("latex-tools.references")
local assignment = require("latex-tools.assignment")
local tex_snippets = require("latex-tools.tex_snippets")
local tests = require("latex-tools.tests")
local util = require("latex-tools.util")

local M = {}

local initialized = false

function M.setup(opts)
  config.setup(opts)
  local options = config.get()

  if options.commands.enable then
    require("latex-tools.commands").setup()
  end

  if options.keymaps.enable then
    require("latex-tools.keymaps").setup(options)
  end

  initialized = true
end

function M.get_config()
  return config.get()
end

function M.insert_snippet(snippet_key)
  return snippets.insert_snippet(snippet_key)
end

function M.insert_custom_snippet()
  return tex_snippets.insert_custom_snippet()
end

function M.insert_figure_snippet()
  return figures.insert_figure_snippet()
end

function M.insert_basic_figure_snippet()
  return figures.insert_basic_figure_snippet()
end

function M.insert_footnote_snippet()
  local content = vim.fn.input("Footnote content: ")
  if content == "" then
    vim.notify("Footnote cancelled: no content entered", vim.log.levels.INFO)
    return
  end
  util.insert_inline_text_at_cursor("\\footnote{" .. util.escape_latex_text(content) .. "}")
end

function M.insert_table_snippet()
  return tables.insert_table_snippet()
end

function M.insert_basic_table_snippet()
  return tables.insert_basic_table_snippet()
end

function M.insert_reference_snippet()
  return references.insert_reference_snippet()
end

function M.insert_bib_key_snippet()
  return references.insert_bib_key_snippet()
end

function M.insert_table_from_csv()
  return tables.insert_table_from_csv()
end

function M.insert_assignment_template()
  return assignment.insert_assignment_template()
end

function M.init_course_metadata(opts)
  return require("latex-tools.state").initialize_course_metadata(opts)
end

function M.init_assignment_template(opts)
  return require("latex-tools.state").initialize_assignment_template(opts)
end

function M.run_tests()
  return tests.run_tests()
end

function M.is_initialized()
  return initialized
end

return M