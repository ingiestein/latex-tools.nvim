local config = require("latex-tools.config")
local snippets = require("latex-tools.snippets")
local figures = require("latex-tools.figures")
local tables = require("latex-tools.tables")
local references = require("latex-tools.references")
local assignment = require("latex-tools.assignment")
local document_templates = require("latex-tools.templates")
local subfiles = require("latex-tools.subfiles")
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

function M.report_cited_keys()
  return references.report_cited_keys()
end

function M.insert_equation_snippet()
  return require("latex-tools.math").insert_equation_snippet()
end

function M.insert_theorem_snippet()
  return require("latex-tools.math").insert_theorem_snippet()
end

function M.insert_table_from_csv()
  return tables.insert_table_from_csv()
end

function M.insert_assignment_template()
  return assignment.insert_assignment_template()
end

function M.insert_template()
  return document_templates.insert_template()
end

function M.create_subfile()
  return subfiles.create_subfile()
end

function M.use_minted_companion(opts)
  return require("latex-tools.code_fences").use_minted_companion(opts)
end

function M.init_metadata(opts)
  return require("latex-tools.state").initialize_course_metadata(opts)
end

function M.init_templates(opts)
  return require("latex-tools.state").initialize_user_templates(opts)
end

function M.init_snippets()
  return require("latex-tools.state").initialize_custom_snippets_dir()
end

--- Initialize user files. Pass opts to run a subset only.
--- @param opts table|nil { metadata?: boolean, templates?: boolean, snippets?: boolean, force?: boolean }
function M.init_all(opts)
  local options = vim.tbl_extend("force", {
    metadata = true,
    templates = true,
    snippets = true,
    force = false,
  }, opts or {})

  local result = {}
  if options.snippets then
    result.snippets_dir = M.init_snippets()
  end
  if options.templates then
    result.templates = M.init_templates({ force = options.force })
  end
  if options.metadata then
    result.metadata = M.init_metadata({ force = options.force })
  end
  return result
end

-- Clearer Lua aliases (Install = create missing; Refresh = backup-then-replace, no UI confirm)
function M.install_metadata()
  return M.init_metadata({ force = false })
end

function M.install_templates()
  return M.init_templates({ force = false })
end

function M.install_snippets()
  return M.init_snippets()
end

function M.install(opts)
  return M.init_all(vim.tbl_extend("force", opts or {}, { force = false }))
end

function M.refresh_metadata()
  return M.init_metadata({ force = true })
end

function M.refresh_templates()
  return M.init_templates({ force = true })
end

function M.refresh()
  return M.init_all({ metadata = true, templates = true, snippets = false, force = true })
end

function M.open_menu()
  return require("latex-tools.commands").open_menu()
end

-- Backward-compatible aliases
function M.init_course_metadata(opts)
  return M.init_metadata(opts)
end

function M.init_user_templates(opts)
  return M.init_templates(opts)
end

function M.init_assignment_template(opts)
  return M.init_templates(opts)
end

function M.init_custom_snippets_dir()
  return M.init_snippets()
end

function M.init_user_files(opts)
  return M.init_all(opts)
end

function M.run_tests()
  return tests.run_tests()
end

function M.is_initialized()
  return initialized
end

return M