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

  vim.api.nvim_create_user_command("LatexToolsAssignment", function()
    require("latex-tools").insert_assignment_template()
  end, { desc = "Insert assignment template" })

  vim.api.nvim_create_user_command("LatexToolsInitCourses", function(opts)
    require("latex-tools").init_course_metadata({ force = opts.bang })
  end, { bang = true, desc = "Create user course metadata from the bundled template" })

  vim.api.nvim_create_user_command("LatexToolsInitAssignment", function(opts)
    require("latex-tools").init_assignment_template({ force = opts.bang })
  end, { bang = true, desc = "Create a user assignment template from the bundled template" })

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