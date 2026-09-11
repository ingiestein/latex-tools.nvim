local util = require("latex-tools.util")

local M = {}

function M.insert_equation_snippet()
  local choices = {
    { label = "equation (numbered)", env = "equation", starred = false },
    { label = "equation* (unnumbered)", env = "equation*", starred = true },
    { label = "align* (unnumbered multi-line)", env = "align*", starred = true },
    { label = "align (numbered multi-line)", env = "align", starred = false },
  }

  vim.ui.select(choices, {
    prompt = "Select math environment",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local lines = { "\\begin{" .. choice.env .. "}" }
    if choice.env:find("align", 1, true) then
      table.insert(lines, "  a &= b \\\\")
      table.insert(lines, "  c &= d")
    else
      table.insert(lines, "  ")
    end

    if not choice.starred then
      local label = vim.fn.input("Equation label (empty to skip): ", "eq:")
      if label ~= "" then
        table.insert(lines, "  \\label{" .. label .. "}")
      end
    end

    table.insert(lines, "\\end{" .. choice.env .. "}")
    util.insert_lines_at_cursor(lines)
  end)
end

function M.insert_theorem_snippet()
  local choices = {
    { label = "theorem", env = "theorem" },
    { label = "definition", env = "definition" },
    { label = "lemma", env = "lemma" },
    { label = "proof", env = "proof" },
  }

  vim.ui.select(choices, {
    prompt = "Select theorem-style environment",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local lines = {
      "% Requires amsthm + \\newtheorem{" .. choice.env .. "}{...} in the preamble (see assignment template).",
      "\\begin{" .. choice.env .. "}",
    }

    if choice.env ~= "proof" then
      local label = vim.fn.input("Label (empty to skip): ", choice.env:sub(1, 3) .. ":")
      if label ~= "" then
        table.insert(lines, "  \\label{" .. label .. "}")
      end
    end

    table.insert(lines, "  ")
    table.insert(lines, "\\end{" .. choice.env .. "}")
    util.insert_lines_at_cursor(lines)
  end)
end

return M
