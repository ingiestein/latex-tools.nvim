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
    require("latex-tools").insert_assignment_template()
  end, "Assignment Template Picker")

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
  end, "Insert BibTeX Citation Key")

  map(prefix .. "v", function()
    require("latex-tools").insert_table_from_csv()
  end, "Insert Table from CSV")

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
      { prefix, desc = "Templates" },
      { prefix .. "a", desc = "Assignment Template Picker" },
      { prefix .. "f", desc = "Figure (Picker + Caption)" },
      { prefix .. "F", desc = "Figure (Placeholder)" },
      { prefix .. "b", desc = "Table (Interactive)" },
      { prefix .. "B", desc = "Table (Placeholder)" },
      { prefix .. "n", desc = "Footnote (Input)" },
      { prefix .. "R", desc = "Reference to Label" },
      { prefix .. "k", desc = "BibTeX Citation Key" },
      { prefix .. "v", desc = "Table from CSV" },
      { prefix .. "p", desc = "Python Code" },
      { prefix .. "r", desc = "R Code" },
      { prefix .. "s", desc = "SQL Code" },
      { prefix .. "T", desc = "Run Template Tests" },
    })
  end
end

return M