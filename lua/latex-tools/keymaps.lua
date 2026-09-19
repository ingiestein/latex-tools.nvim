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

  local function lt()
    return require("latex-tools")
  end

  -- Top-level (two-key) document actions
  map(prefix .. "a", function()
    lt().insert_template()
  end, "Document Template Picker")

  map(prefix .. "x", function()
    vim.cmd("LatexToolsSnippet")
  end, "Custom LaTeX Snippet Picker")

  map(prefix .. "S", function()
    lt().create_subfile()
  end, "Create Subfile Chapter")

  map(prefix .. "T", function()
    lt().run_tests()
  end, "Run Template Tests")

  -- Figures \tf*
  map(prefix .. "ff", function()
    lt().insert_figure_snippet()
  end, "Figure (Picker + Caption)")

  map(prefix .. "fp", function()
    lt().insert_basic_figure_snippet()
  end, "Figure (Placeholder)")

  -- Tables \tb*
  map(prefix .. "bi", function()
    lt().insert_table_snippet()
  end, "Table (Interactive)")

  map(prefix .. "bp", function()
    lt().insert_basic_table_snippet()
  end, "Table (Placeholder)")

  map(prefix .. "bc", function()
    lt().insert_table_from_csv()
  end, "Table from CSV")

  -- Code fences \tc* (rich samples for p/r/s/m/l; catalog for the rest)
  map(prefix .. "cf", function()
    lt().pick_code_fence()
  end, "Code Fence Language Picker")

  map(prefix .. "cp", function()
    lt().insert_snippet("p")
  end, "Python Fence")

  map(prefix .. "cr", function()
    lt().insert_snippet("r")
  end, "R Fence")

  map(prefix .. "cs", function()
    lt().insert_snippet("s")
  end, "SQL Fence")

  map(prefix .. "cm", function()
    lt().insert_snippet("m")
  end, "Markdown Fence")

  map(prefix .. "cl", function()
    lt().insert_snippet("l")
  end, "Plain Text Fence")

  map(prefix .. "cj", function()
    lt().insert_fence_env("javascript")
  end, "JavaScript Fence")

  map(prefix .. "ct", function()
    lt().insert_fence_env("typescript")
  end, "TypeScript Fence")

  map(prefix .. "ca", function()
    lt().insert_fence_env("java")
  end, "Java Fence")

  map(prefix .. "cc", function()
    lt().insert_fence_env("ccode")
  end, "C Fence")

  map(prefix .. "cx", function()
    lt().insert_fence_env("cpp")
  end, "C++ Fence")

  map(prefix .. "ch", function()
    lt().insert_fence_env("csharp")
  end, "C# Fence")

  map(prefix .. "cu", function()
    lt().insert_fence_env("rust")
  end, "Rust Fence")

  map(prefix .. "co", function()
    lt().insert_fence_env("json")
  end, "JSON Fence")

  map(prefix .. "cg", function()
    lt().insert_fence_env("go")
  end, "Go Fence")

  map(prefix .. "cb", function()
    lt().insert_fence_env("bash")
  end, "Bash Fence")

  -- Refs / cites / notes \tr*
  map(prefix .. "rr", function()
    lt().insert_reference_snippet()
  end, "Reference to Label")

  map(prefix .. "rk", function()
    lt().insert_bib_key_snippet()
  end, "BibTeX Citation")

  map(prefix .. "rc", function()
    lt().report_cited_keys()
  end, "Cited Keys Report")

  map(prefix .. "rn", function()
    lt().insert_footnote_snippet()
  end, "Footnote")

  -- Math \tm*
  map(prefix .. "me", function()
    lt().insert_equation_snippet()
  end, "Equation / Align")

  map(prefix .. "mh", function()
    lt().insert_theorem_snippet()
  end, "Theorem / Definition / Proof")

  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.add({
      { prefix, group = "LaTeX Tools" },
      { prefix .. "a", desc = "Document Template Picker" },
      { prefix .. "x", desc = "Custom LaTeX Snippet Picker" },
      { prefix .. "S", desc = "Create Subfile Chapter" },
      { prefix .. "T", desc = "Run Template Tests" },
      { prefix .. "f", group = "Figures" },
      { prefix .. "ff", desc = "Figure (Picker + Caption)" },
      { prefix .. "fp", desc = "Figure (Placeholder)" },
      { prefix .. "b", group = "Tables" },
      { prefix .. "bi", desc = "Table (Interactive)" },
      { prefix .. "bp", desc = "Table (Placeholder)" },
      { prefix .. "bc", desc = "Table from CSV" },
      { prefix .. "c", group = "Code fences" },
      { prefix .. "cf", desc = "Language Picker" },
      { prefix .. "cp", desc = "Python" },
      { prefix .. "cr", desc = "R" },
      { prefix .. "cs", desc = "SQL" },
      { prefix .. "cm", desc = "Markdown" },
      { prefix .. "cl", desc = "Plain text" },
      { prefix .. "cj", desc = "JavaScript" },
      { prefix .. "ct", desc = "TypeScript" },
      { prefix .. "ca", desc = "Java" },
      { prefix .. "cc", desc = "C" },
      { prefix .. "cx", desc = "C++" },
      { prefix .. "ch", desc = "C#" },
      { prefix .. "cu", desc = "Rust" },
      { prefix .. "co", desc = "JSON" },
      { prefix .. "cg", desc = "Go" },
      { prefix .. "cb", desc = "Bash" },
      { prefix .. "r", group = "Refs / cites / notes" },
      { prefix .. "rr", desc = "Reference to Label" },
      { prefix .. "rk", desc = "BibTeX Citation" },
      { prefix .. "rc", desc = "Cited Keys Report" },
      { prefix .. "rn", desc = "Footnote" },
      { prefix .. "m", group = "Math" },
      { prefix .. "me", desc = "Equation / Align" },
      { prefix .. "mh", desc = "Theorem / Definition / Proof" },
    })
  end
end

return M
