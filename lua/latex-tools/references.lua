local util = require("latex-tools.util")

local M = {}

local CITE_MACROS = {
  "cite",
  "citep",
  "citet",
  "citepp",
  "citepalp",
  "citepalt",
  "citepyear",
  "citeauthor",
  "parencite",
  "textcite",
  "autocite",
  "footcite",
  "smartcite",
  "fullcite",
}

local function extract_field(block, field)
  local pattern = field:lower() .. "%s*=%s*"
  local lower = block:lower()
  local start_at = lower:find(pattern, 1, false)
  if not start_at then
    return nil
  end
  local rest = block:sub(start_at)
  local braced = rest:match("=%s*%{(.-)%}")
  if braced then
    return braced:gsub("%s+", " "):match("^%s*(.-)%s*$")
  end
  local quoted = rest:match('=%s*"(.-)"')
  if quoted then
    return quoted:gsub("%s+", " "):match("^%s*(.-)%s*$")
  end
  return nil
end

local function truncate(text, max_len)
  if not text then
    return nil
  end
  max_len = max_len or 60
  if #text <= max_len then
    return text
  end
  return text:sub(1, max_len - 1) .. "…"
end

local function collect_labels_from_lines(lines, labels, seen)
  for _, line in ipairs(lines) do
    for label in line:gmatch("\\label%{([^}]+)%}") do
      if not seen[label] then
        seen[label] = true
        table.insert(labels, label)
      end
    end
  end
end

function M.collect_labels()
  local labels = {}
  local seen = {}

  collect_labels_from_lines(vim.api.nvim_buf_get_lines(0, 0, -1, false), labels, seen)

  local buf_path = vim.api.nvim_buf_get_name(0)
  local project_dir = nil
  if buf_path ~= "" then
    local dir = vim.fn.fnamemodify(buf_path, ":h")
    if vim.fn.fnamemodify(dir, ":t") == "subfile" then
      project_dir = vim.fn.fnamemodify(dir, ":h")
    else
      project_dir = dir
    end
  end

  if project_dir and vim.fn.isdirectory(project_dir .. "/subfile") == 1 then
    for _, path in ipairs(util.list_tex_files(project_dir .. "/subfile", true)) do
      if path ~= buf_path then
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok and type(lines) == "table" then
          collect_labels_from_lines(lines, labels, seen)
        end
      end
    end
    -- Also scan sibling .tex in project root (parent document)
    for _, path in ipairs(util.list_tex_files(project_dir, false)) do
      if path ~= buf_path then
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok and type(lines) == "table" then
          collect_labels_from_lines(lines, labels, seen)
        end
      end
    end
  end

  table.sort(labels)
  return labels
end

function M.collect_bib_entries()
  local bib_files = util.list_files_up_to_depth({ "bib" }, 4)
  local entries = {}

  for _, rel_path in ipairs(bib_files) do
    local ok, lines = pcall(vim.fn.readfile, rel_path)
    if ok and type(lines) == "table" then
      local i = 1
      while i <= #lines do
        local entry_type, key = lines[i]:match("^@([%w_]+)%s*{%s*([^,%s]+)")
        if entry_type and key and entry_type:lower() ~= "string" and entry_type:lower() ~= "comment" then
          local block_lines = { lines[i] }
          local depth = select(2, lines[i]:gsub("%{", "")) - select(2, lines[i]:gsub("%}", ""))
          local j = i
          while j < #lines and depth > 0 do
            j = j + 1
            table.insert(block_lines, lines[j])
            depth = depth + select(2, lines[j]:gsub("%{", "")) - select(2, lines[j]:gsub("%}", ""))
          end
          local block = table.concat(block_lines, "\n")
          local title = truncate(extract_field(block, "title"), 50)
          local author = truncate(extract_field(block, "author"), 40)
          local year = extract_field(block, "year") or extract_field(block, "date")
          if year then
            year = year:match("%d%d%d%d") or year
          end
          local parts = { string.format("%s [%s]", key, entry_type) }
          if author then
            table.insert(parts, author)
          end
          if year then
            table.insert(parts, year)
          end
          if title then
            table.insert(parts, title)
          end
          table.insert(parts, rel_path)
          table.insert(entries, {
            key = key,
            entry_type = entry_type,
            file = rel_path,
            title = title,
            author = author,
            year = year,
            label = table.concat(parts, " — "),
          })
          i = j + 1
        else
          i = i + 1
        end
      end
    end
  end

  table.sort(entries, function(a, b)
    return a.label < b.label
  end)
  return entries
end

function M.insert_reference_snippet()
  local labels = M.collect_labels()
  if #labels == 0 then
    vim.notify("No \\label{...} entries found in buffer or project subfiles", vim.log.levels.WARN)
    return
  end

  local ref_commands = {
    { label = "\\ref", value = "ref" },
    { label = "\\pageref", value = "pageref" },
    { label = "\\autoref", value = "autoref" },
    { label = "\\eqref", value = "eqref" },
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

local function pick_additional_keys(entries, selected, cite_choice)
  local remaining = {}
  local selected_set = {}
  for _, key in ipairs(selected) do
    selected_set[key] = true
  end
  for _, entry in ipairs(entries) do
    if not selected_set[entry.key] then
      table.insert(remaining, entry)
    end
  end

  local finish = { key = "__finish__", label = "Done — insert \\" .. cite_choice.value .. "{" .. table.concat(selected, ",") .. "}" }
  local choices = { finish }
  for _, entry in ipairs(remaining) do
    table.insert(choices, entry)
  end

  vim.ui.select(choices, {
    prompt = "Add another key (or Done)",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.key == "__finish__" then
      util.insert_inline_text_at_cursor("\\" .. cite_choice.value .. "{" .. table.concat(selected, ",") .. "}")
      return
    end
    table.insert(selected, choice.key)
    pick_additional_keys(entries, selected, cite_choice)
  end)
end

function M.insert_bib_key_snippet()
  local entries = M.collect_bib_entries()
  if #entries == 0 then
    vim.notify("No .bib files or BibTeX entries found under the current directory (depth <= 4)", vim.log.levels.WARN)
    return
  end

  local cite_commands = {
    { label = "\\citep", value = "citep" },
    { label = "\\citet", value = "citet" },
    { label = "\\cite", value = "cite" },
    { label = "\\parencite", value = "parencite" },
    { label = "\\textcite", value = "textcite" },
    { label = "\\autocite", value = "autocite" },
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
      prompt = "Select BibTeX entry",
      format_item = function(item)
        return item.label
      end,
    }, function(entry_choice)
      if not entry_choice then
        return
      end
      pick_additional_keys(entries, { entry_choice.key }, cite_choice)
    end)
  end)
end

local function project_tex_files()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local project_dir = vim.fn.getcwd()
  if buf_path ~= "" then
    local dir = vim.fn.fnamemodify(buf_path, ":h")
    if vim.fn.fnamemodify(dir, ":t") == "subfile" then
      project_dir = vim.fn.fnamemodify(dir, ":h")
    else
      project_dir = dir
    end
  end

  local files = util.list_tex_files(project_dir, false)
  local subfile_dir = project_dir .. "/subfile"
  if vim.fn.isdirectory(subfile_dir) == 1 then
    for _, path in ipairs(util.list_tex_files(subfile_dir, true)) do
      table.insert(files, path)
    end
  end
  return files
end

local function extract_cite_keys_from_text(text, keys, seen)
  for _, macro in ipairs(CITE_MACROS) do
    for _, pattern in ipairs({
      "\\" .. macro .. "%*%{([^}]+)%}",
      "\\" .. macro .. "%{([^}]+)%}",
    }) do
      for inner in text:gmatch(pattern) do
        for key in inner:gmatch("([^,%s]+)") do
          if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
          end
        end
      end
    end
  end
end

function M.build_cited_keys_report()
  local cited = {}
  local seen = {}
  for _, path in ipairs(project_tex_files()) do
    local ok, lines = pcall(vim.fn.readfile, path)
    if ok and type(lines) == "table" then
      extract_cite_keys_from_text(table.concat(lines, "\n"), cited, seen)
    end
  end
  table.sort(cited)

  local bib_entries = M.collect_bib_entries()
  local bib_keys = {}
  for _, entry in ipairs(bib_entries) do
    bib_keys[entry.key] = true
  end

  local used = {}
  local missing = {}
  for _, key in ipairs(cited) do
    if bib_keys[key] then
      table.insert(used, key)
    else
      table.insert(missing, key)
    end
  end

  local report = {
    "% latex-tools cited keys report (read-only)",
    "% Project .tex scanned; .bib is never modified.",
    "",
    string.format("%% Cited keys found: %d", #cited),
    string.format("%% Present in .bib: %d", #used),
    string.format("%% Missing from .bib: %d", #missing),
    "",
  }

  if #used > 0 then
    table.insert(report, "% --- present ---")
    for _, key in ipairs(used) do
      table.insert(report, "% " .. key)
    end
    table.insert(report, "")
  end

  if #missing > 0 then
    table.insert(report, "% --- missing from discovered .bib files ---")
    for _, key in ipairs(missing) do
      table.insert(report, "% " .. key)
    end
    table.insert(report, "")
  end

  if #cited == 0 then
    table.insert(report, "% No citation keys found in project .tex files.")
  end

  return report, #cited, #used, #missing
end

function M.report_cited_keys()
  local report, cited_n, used_n, missing_n = M.build_cited_keys_report()

  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  pcall(vim.api.nvim_buf_set_name, buf, "latex-tools-cited-keys-" .. tostring(vim.loop.hrtime()))
  pcall(function()
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "tex"
  end)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, report)

  vim.notify(
    string.format("Cited keys: %d total, %d in .bib, %d missing", cited_n, used_n, missing_n),
    vim.log.levels.INFO
  )
end

return M
