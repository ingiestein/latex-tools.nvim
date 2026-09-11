local M = {}

local created = false

local function confirm_refresh(kind)
  local messages = {
    metadata = "Refresh courses.yaml?\nCurrent file will be moved to metadata-backup/<timestamp>/ then replaced with the plugin starter.",
    templates = "Refresh document templates?\nConflicting bundled files will be moved to templates-backup/<timestamp>/ then replaced with plugin defaults.\nUser-only templates are left untouched.",
    both = "Refresh courses.yaml and document templates?\nExisting files will be moved to metadata-backup/ and templates-backup/ then replaced with plugin defaults.\nSnippets are never removed.",
  }
  local message = messages[kind] or messages.both
  local choice = vim.fn.confirm(message, "&Yes\n&No", 2, "Question")
  return choice == 1
end

local function install_metadata()
  return require("latex-tools").install_metadata()
end

local function install_templates()
  return require("latex-tools").install_templates()
end

local function install_snippets()
  return require("latex-tools").install_snippets()
end

local function install_all()
  return require("latex-tools").install()
end

local function refresh_metadata()
  if not confirm_refresh("metadata") then
    vim.notify("Refresh metadata cancelled", vim.log.levels.INFO)
    return nil
  end
  return require("latex-tools").refresh_metadata()
end

local function refresh_templates()
  if not confirm_refresh("templates") then
    vim.notify("Refresh templates cancelled", vim.log.levels.INFO)
    return nil
  end
  return require("latex-tools").refresh_templates()
end

local function refresh_all()
  if not confirm_refresh("both") then
    vim.notify("Refresh cancelled", vim.log.levels.INFO)
    return nil
  end
  return require("latex-tools").refresh()
end

function M.open_menu()
  local items = {
    { label = "Insert: Document template picker", run = function()
      require("latex-tools").insert_template()
    end },
    { label = "Insert: Course-aware assignment", run = function()
      require("latex-tools").insert_assignment_template()
    end },
    { label = "Insert: Create subfile chapter", run = function()
      require("latex-tools").create_subfile()
    end },
    { label = "Insert: Custom .tex snippet", run = function()
      require("latex-tools").insert_custom_snippet()
    end },
    { label = "Insert: Figure (picker)", run = function()
      require("latex-tools").insert_figure_snippet()
    end },
    { label = "Insert: Figure (placeholder)", run = function()
      require("latex-tools").insert_basic_figure_snippet()
    end },
    { label = "Insert: Table (interactive)", run = function()
      require("latex-tools").insert_table_snippet()
    end },
    { label = "Insert: Table (placeholder)", run = function()
      require("latex-tools").insert_basic_table_snippet()
    end },
    { label = "Insert: Table from CSV", run = function()
      require("latex-tools").insert_table_from_csv()
    end },
    { label = "Insert: Footnote", run = function()
      require("latex-tools").insert_footnote_snippet()
    end },
    { label = "Insert: Reference to label", run = function()
      require("latex-tools").insert_reference_snippet()
    end },
    { label = "Insert: BibTeX citation", run = function()
      require("latex-tools").insert_bib_key_snippet()
    end },
    { label = "Insert: Equation / align", run = function()
      require("latex-tools").insert_equation_snippet()
    end },
    { label = "Insert: Theorem / definition / proof", run = function()
      require("latex-tools").insert_theorem_snippet()
    end },
    { label = "Report: Cited keys vs .bib (read-only)", run = function()
      require("latex-tools").report_cited_keys()
    end },
    { label = "Setup: Install missing files only (safe)", run = install_all },
    { label = "Setup: Install courses.yaml if missing", run = install_metadata },
    { label = "Setup: Install missing templates only", run = install_templates },
    { label = "Setup: Install snippets directory", run = install_snippets },
    { label = "Setup: Refresh courses.yaml (backs up then replaces)", run = refresh_metadata },
    { label = "Setup: Refresh templates (backs up then replaces)", run = refresh_templates },
    { label = "Setup: Refresh metadata + templates (backs up then replaces)", run = refresh_all },
    { label = "Code fences: Use minted companion", run = function()
      require("latex-tools").use_minted_companion({ minted = true })
    end },
    { label = "Code fences: Use listings companion", run = function()
      require("latex-tools").use_minted_companion({ minted = false })
    end },
    { label = "Dev: Run regression tests", run = function()
      require("latex-tools").run_tests()
    end },
  }

  vim.ui.select(items, {
    prompt = "LaTeX Tools",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice and choice.run then
      choice.run()
    end
  end)
end

function M.setup()
  if created then
    return
  end

  created = true

  vim.api.nvim_create_user_command("LatexTools", function()
    M.open_menu()
  end, { desc = "Open LaTeX Tools action menu" })

  vim.api.nvim_create_user_command("LatexToolsTest", function()
    require("latex-tools").run_tests()
  end, { desc = "Run LaTeX tools regression tests" })

  vim.api.nvim_create_user_command("LatexToolsTemplate", function()
    require("latex-tools").insert_template()
  end, { desc = "Insert a document template" })

  vim.api.nvim_create_user_command("LatexToolsAssignment", function()
    require("latex-tools").insert_assignment_template()
  end, { desc = "Insert course-aware assignment template" })

  -- Primary lifecycle: Install (create missing) / Refresh (backup then replace)
  vim.api.nvim_create_user_command("LatexToolsInstall", function()
    install_all()
  end, { desc = "Create missing courses.yaml, templates, and snippets dir (never replaces)" })

  vim.api.nvim_create_user_command("LatexToolsInstallMetadata", function()
    install_metadata()
  end, { desc = "Create courses.yaml if missing (never replaces)" })

  vim.api.nvim_create_user_command("LatexToolsInstallTemplates", function()
    install_templates()
  end, { desc = "Create missing bundled document templates (never replaces)" })

  vim.api.nvim_create_user_command("LatexToolsInstallSnippets", function()
    install_snippets()
  end, { desc = "Create snippets dir and seed missing bundled academic starters" })

  vim.api.nvim_create_user_command("LatexToolsRefresh", function()
    refresh_all()
  end, {
    desc = "Confirm, then backup-refresh courses.yaml and templates from plugin",
  })

  vim.api.nvim_create_user_command("LatexToolsRefreshMetadata", function()
    refresh_metadata()
  end, {
    desc = "Confirm, then move courses.yaml to metadata-backup/ and write plugin starter",
  })

  vim.api.nvim_create_user_command("LatexToolsRefreshTemplates", function()
    refresh_templates()
  end, {
    desc = "Confirm, then move conflicting templates to templates-backup/ and write defaults",
  })

  -- Legacy Init* aliases (bang → Refresh with confirm)
  vim.api.nvim_create_user_command("LatexToolsInitMetadata", function(opts)
    if opts.bang then
      refresh_metadata()
    else
      install_metadata()
    end
  end, {
    bang = true,
    desc = "Alias: InstallMetadata (bang: RefreshMetadata with confirm)",
  })

  vim.api.nvim_create_user_command("LatexToolsInitCourses", function(opts)
    if opts.bang then
      refresh_metadata()
    else
      install_metadata()
    end
  end, { bang = true, desc = "Alias for :LatexToolsInitMetadata" })

  vim.api.nvim_create_user_command("LatexToolsInitTemplates", function(opts)
    if opts.bang then
      refresh_templates()
    else
      install_templates()
    end
  end, {
    bang = true,
    desc = "Alias: InstallTemplates (bang: RefreshTemplates with confirm)",
  })

  vim.api.nvim_create_user_command("LatexToolsInitAssignment", function(opts)
    if opts.bang then
      refresh_templates()
    else
      install_templates()
    end
  end, { bang = true, desc = "Alias for :LatexToolsInitTemplates" })

  vim.api.nvim_create_user_command("LatexToolsInitSnippets", function()
    install_snippets()
  end, { desc = "Alias for :LatexToolsInstallSnippets" })

  vim.api.nvim_create_user_command("LatexToolsInit", function(opts)
    if opts.bang then
      refresh_all()
    else
      install_all()
    end
  end, {
    bang = true,
    desc = "Alias: Install (bang: Refresh metadata+templates with confirm)",
  })

  vim.api.nvim_create_user_command("LatexToolsSubfile", function()
    require("latex-tools").create_subfile()
  end, { desc = "Create a subfile from the current course-aware document" })

  vim.api.nvim_create_user_command("LatexToolsCodeMinted", function()
    require("latex-tools").use_minted_companion({ minted = true })
  end, { desc = "Switch parent \\input to minted code fences companion" })

  vim.api.nvim_create_user_command("LatexToolsCodeListings", function()
    require("latex-tools").use_minted_companion({ minted = false })
  end, { desc = "Switch parent \\input to portable listings companion" })

  vim.api.nvim_create_user_command("LatexToolsUseMinted", function(opts)
    -- Bang switches back to portable listings; default enables minted.
    require("latex-tools").use_minted_companion({ minted = not opts.bang })
  end, {
    bang = true,
    desc = "Alias: CodeMinted (bang: CodeListings)",
  })

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
  end, { desc = "Insert a BibTeX/biblatex citation from project .bib files" })

  vim.api.nvim_create_user_command("LatexToolsCitedKeys", function()
    require("latex-tools").report_cited_keys()
  end, { desc = "List cited keys in project .tex and mark missing from .bib (read-only)" })

  vim.api.nvim_create_user_command("LatexToolsEquation", function()
    require("latex-tools").insert_equation_snippet()
  end, { desc = "Insert equation or align environment" })

  vim.api.nvim_create_user_command("LatexToolsTheorem", function()
    require("latex-tools").insert_theorem_snippet()
  end, { desc = "Insert theorem, definition, lemma, or proof environment" })

  vim.api.nvim_create_user_command("LatexToolsCSVTable", function()
    require("latex-tools").insert_table_from_csv()
  end, { desc = "Insert table from CSV" })
end

-- Exported for tests and Lua callers that want the confirm gate.
M.confirm_refresh = confirm_refresh
M.install_all = install_all
M.install_metadata = install_metadata
M.install_templates = install_templates
M.install_snippets = install_snippets
M.refresh_all = refresh_all
M.refresh_metadata = refresh_metadata
M.refresh_templates = refresh_templates

return M
