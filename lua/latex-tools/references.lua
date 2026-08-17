local util = require("latex-tools.util")

local M = {}

local function collect_labels_from_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local labels = {}
  local seen = {}

  for _, line in ipairs(lines) do
    for label in line:gmatch("\\label%{([^}]+)%}") do
      if not seen[label] then
        seen[label] = true
        table.insert(labels, label)
      end
    end
  end

  table.sort(labels)
  return labels
end

local function collect_bib_entries()
  local bib_files = util.list_files_depth_one({ "bib" })
  local entries = {}

  for _, rel_path in ipairs(bib_files) do
    local lines = vim.fn.readfile(rel_path)
    for _, line in ipairs(lines) do
      local entry_type, key = line:match("^@([%w_]+)%s*{%s*([^,%s]+)")
      if entry_type and key then
        table.insert(entries, {
          key = key,
          entry_type = entry_type,
          file = rel_path,
          label = string.format("%s [%s] - %s", key, entry_type, rel_path),
        })
      end
    end
  end

  table.sort(entries, function(a, b)
    return a.label < b.label
  end)
  return entries
end

function M.insert_reference_snippet()
  local labels = collect_labels_from_buffer()
  if #labels == 0 then
    vim.notify("No \\label{...} entries found in current buffer", vim.log.levels.WARN)
    return
  end

  local ref_commands = {
    { label = "\\ref", value = "ref" },
    { label = "\\pageref", value = "pageref" },
    { label = "\\autoref", value = "autoref" },
  }

  vim.ui.select(ref_commands, {
    prompt = "Select reference command",
    format_item = function(item)
      return item.label
    end,
  }, function(ref_choice)
    if not ref_choice then
      return
    end

    vim.ui.select(labels, {
      prompt = "Select label",
      format_item = function(item)
        return item
      end,
    }, function(label_choice)
      if not label_choice then
        return
      end

      util.insert_inline_text_at_cursor("\\" .. ref_choice.value .. "{" .. label_choice .. "}")
    end)
  end)
end

function M.insert_bib_key_snippet()
  local entries = collect_bib_entries()
  if #entries == 0 then
    vim.notify("No .bib files or BibTeX entries found in current directory (depth <= 1)", vim.log.levels.WARN)
    return
  end

  local cite_commands = {
    { label = "\\cite", value = "cite" },
    { label = "\\citep", value = "citep" },
    { label = "\\citet", value = "citet" },
  }

  vim.ui.select(cite_commands, {
    prompt = "Select citation command",
    format_item = function(item)
      return item.label
    end,
  }, function(cite_choice)
    if not cite_choice then
      return
    end

    vim.ui.select(entries, {
      prompt = "Select BibTeX key",
      format_item = function(item)
        return item.label
      end,
    }, function(entry_choice)
      if not entry_choice then
        return
      end

      util.insert_inline_text_at_cursor("\\" .. cite_choice.value .. "{" .. entry_choice.key .. "}")
    end)
  end)
end

return M