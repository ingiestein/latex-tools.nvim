local M = {}

local registered_prefix = nil

function M.setup(opts)
  local prefix = opts.keymaps.prefix
  if registered_prefix == prefix then
    return
  end

  registered_prefix = prefix

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
  end

  map(prefix .. "a", function()
    require("latex-tools").insert_template()
  end, "Document Template Picker")

  map(prefix .. "x", function()
    vim.cmd("LatexToolsSnippet")
  end, "Custom LaTeX Snippet Picker")

  map(prefix .. "f", function()
    require("latex-tools").insert_figure_snippet()
  end, "Insert Figure (Picker + Caption)")

  map(prefix .. "F", function()
    require("latex-tools").insert_basic_figure_snippet()
  end, "Insert Figure (Placeholder)")

  map(prefix .. "b", function()
    require("latex-tools").insert_table_snippet()
  end, "Insert Table (Interactive)")

  map(prefix .. "B", function()
    require("latex-tools").insert_basic_table_snippet()
  end, "Insert Table (Placeholder)")

  map(prefix .. "n", function()
    require("latex-tools").insert_footnote_snippet()
  end, "Insert Footnote (Input)")

  map(prefix .. "R", function()
    require("latex-tools").insert_reference_snippet()
  end, "Insert Reference to Label")

  map(prefix .. "k", function()
    require("latex-tools").insert_bib_key_snippet()
  end, "Insert BibTeX Citation")

  map(prefix .. "c", function()
    require("latex-tools").report_cited_keys()
  end, "Report Cited Keys vs .bib")

  map(prefix .. "e", function()
    require("latex-tools").insert_equation_snippet()
  end, "Insert Equation / Align")

  map(prefix .. "h", function()
    require("latex-tools").insert_theorem_snippet()
  end, "Insert Theorem / Definition / Proof")

  map(prefix .. "v", function()
    require("latex-tools").insert_table_from_csv()
  end, "Insert Table from CSV")

  map(prefix .. "S", function()
    require("latex-tools").create_subfile()
  end, "Create Subfile Chapter")

  map(prefix .. "p", function()
    require("latex-tools").insert_snippet("p")
  end, "Insert Python Code Snippet")

  map(prefix .. "r", function()
    require("latex-tools").insert_snippet("r")
  end, "Insert R Code Snippet")

  map(prefix .. "s", function()
    require("latex-tools").insert_snippet("s")
  end, "Insert SQL Code Snippet")

  map(prefix .. "T", function()
    require("latex-tools").run_tests()
  end, "Run Template Tests")

  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.add({
      { prefix, group = "LaTeX Tools" },
      { prefix .. "a", desc = "Document Template Picker" },
      { prefix .. "x", desc = "Custom LaTeX Snippet Picker" },
      { prefix .. "f", desc = "Figure (Picker + Caption)" },
      { prefix .. "F", desc = "Figure (Placeholder)" },
      { prefix .. "b", desc = "Table (Interactive)" },
      { prefix .. "B", desc = "Table (Placeholder)" },
      { prefix .. "n", desc = "Footnote (Input)" },
      { prefix .. "R", desc = "Reference to Label" },
      { prefix .. "k", desc = "BibTeX Citation" },
      { prefix .. "c", desc = "Cited Keys Report" },
      { prefix .. "e", desc = "Equation / Align" },
      { prefix .. "h", desc = "Theorem / Definition / Proof" },
      { prefix .. "v", desc = "Table from CSV" },
      { prefix .. "S", desc = "Create Subfile Chapter" },
      { prefix .. "p", desc = "Python Code" },
      { prefix .. "r", desc = "R Code" },
      { prefix .. "s", desc = "SQL Code" },
      { prefix .. "T", desc = "Run Template Tests" },
    })
  end
end

return M