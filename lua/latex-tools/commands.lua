local M = {}

local created = false

function M.setup()
  if created then
    return
  end

  created = true

  vim.api.nvim_create_user_command("LatexToolsTest", function()
    require("latex-tools").run_tests()
  end, { desc = "Run LaTeX tools regression tests" })

  vim.api.nvim_create_user_command("LatexToolsTemplate", function()
    require("latex-tools").insert_template()
  end, { desc = "Insert a document template" })

  vim.api.nvim_create_user_command("LatexToolsAssignment", function()
    require("latex-tools").insert_assignment_template()
  end, { desc = "Insert course-aware assignment template" })

  vim.api.nvim_create_user_command("LatexToolsInitMetadata", function(opts)
    require("latex-tools").init_metadata({ force = opts.bang })
  end, { bang = true, desc = "Create user course metadata from the bundled example" })

  vim.api.nvim_create_user_command("LatexToolsInitCourses", function(opts)
    require("latex-tools").init_metadata({ force = opts.bang })
  end, { bang = true, desc = "Alias for :LatexToolsInitMetadata" })

  vim.api.nvim_create_user_command("LatexToolsInitTemplates", function(opts)
    require("latex-tools").init_templates({ force = opts.bang })
  end, { bang = true, desc = "Create user document templates from bundled templates" })

  vim.api.nvim_create_user_command("LatexToolsInitAssignment", function(opts)
    require("latex-tools").init_templates({ force = opts.bang })
  end, { bang = true, desc = "Alias for :LatexToolsInitTemplates" })

  vim.api.nvim_create_user_command("LatexToolsInitSnippets", function()
    require("latex-tools").init_snippets()
  end, { desc = "Create the custom LaTeX snippet directory" })

  vim.api.nvim_create_user_command("LatexToolsInit", function(opts)
    require("latex-tools").init_all({ force = opts.bang })
  end, { bang = true, desc = "Initialize metadata, templates, and snippets" })

  vim.api.nvim_create_user_command("LatexToolsSubfile", function()
    require("latex-tools").create_subfile()
  end, { desc = "Create a subfile from the current course-aware document" })

  vim.api.nvim_create_user_command("LatexToolsSnippet", function()
    require("latex-tools").insert_custom_snippet()
  end, { desc = "Insert a custom LaTeX snippet" })

  vim.api.nvim_create_user_command("LatexToolsFigure", function()
    require("latex-tools").insert_figure_snippet()
  end, { desc = "Insert figure with picker" })

  vim.api.nvim_create_user_command("LatexToolsFigurePlaceholder", function()
    require("latex-tools").insert_basic_figure_snippet()
  end, { desc = "Insert placeholder figure" })

  vim.api.nvim_create_user_command("LatexToolsTable", function()
    require("latex-tools").insert_table_snippet()
  end, { desc = "Insert interactive table" })

  vim.api.nvim_create_user_command("LatexToolsTablePlaceholder", function()
    require("latex-tools").insert_basic_table_snippet()
  end, { desc = "Insert placeholder table" })

  vim.api.nvim_create_user_command("LatexToolsFootnote", function()
    require("latex-tools").insert_footnote_snippet()
  end, { desc = "Insert footnote" })

  vim.api.nvim_create_user_command("LatexToolsReference", function()
    require("latex-tools").insert_reference_snippet()
  end, { desc = "Insert reference to label" })

  vim.api.nvim_create_user_command("LatexToolsBib", function()
    require("latex-tools").insert_bib_key_snippet()
  end, { desc = "Insert BibTeX citation" })

  vim.api.nvim_create_user_command("LatexToolsCSVTable", function()
    require("latex-tools").insert_table_from_csv()
  end, { desc = "Insert table from CSV" })
end

return M