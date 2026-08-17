local M = {}

function M.split_lines(content)
  local lines = vim.split(content, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines, #lines)
  end
  return lines
end

function M.insert_lines_at_cursor(lines)
  vim.api.nvim_put(lines, "l", true, true)
end

function M.insert_inline_text_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local insert_idx = col + 1
  local updated = line:sub(1, insert_idx) .. text .. line:sub(insert_idx + 1)
  vim.api.nvim_set_current_line(updated)
  vim.api.nvim_win_set_cursor(0, { row, insert_idx + #text })
end

function M.slugify(value)
  local slug = value:lower():gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  return slug ~= "" and slug or "item"
end

function M.escape_latex_text(value)
  local replacements = {
    ["\\"] = "\\textbackslash{}",
    ["&"] = "\\&",
    ["%"] = "\\%",
    ["$"] = "\\$",
    ["#"] = "\\#",
    ["_"] = "\\_",
    ["{"] = "\\{",
    ["}"] = "\\}",
  }

  return (value:gsub("[\\&%%$#_{}]", replacements))
end

function M.build_colspec(num_cols)
  if num_cols <= 4 then
    local width = 0.92 / num_cols
    local parts = {}
    for _ = 1, num_cols do
      table.insert(parts, string.format("p{%.2f\\linewidth}", width))
    end
    return table.concat(parts)
  end

  return string.rep("l", num_cols)
end

function M.list_files_depth_one(extensions)
  local cwd = vim.fn.getcwd()
  local seen = {}
  local paths = {}

  local function collect(pattern)
    local matches = vim.fn.glob(pattern, false, true)
    for _, path in ipairs(matches) do
      if vim.fn.filereadable(path) == 1 and not seen[path] then
        seen[path] = true
        table.insert(paths, vim.fn.fnamemodify(path, ":."))
      end
    end
  end

  for _, ext in ipairs(extensions) do
    collect(cwd .. "/*." .. ext)
    collect(cwd .. "/*/*." .. ext)
  end

  table.sort(paths)
  return paths
end

function M.parse_csv_line(line)
  local fields = {}
  local current = {}
  local i = 1
  local in_quotes = false

  while i <= #line do
    local ch = line:sub(i, i)
    if ch == '"' then
      local next_ch = line:sub(i + 1, i + 1)
      if in_quotes and next_ch == '"' then
        table.insert(current, '"')
        i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif ch == "," and not in_quotes then
      table.insert(fields, table.concat(current))
      current = {}
    else
      table.insert(current, ch)
    end
    i = i + 1
  end

  table.insert(fields, table.concat(current))
  return fields
end

function M.load_csv_rows(path)
  local lines = vim.fn.readfile(path)
  local rows = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(rows, M.parse_csv_line(line))
    end
  end
  return rows
end

function M.insert_template_lines(lines)
  local buf = vim.api.nvim_get_current_buf()
  local existing = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local is_empty = #existing == 1 and existing[1] == ""

  if is_empty then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
  end
end

return M