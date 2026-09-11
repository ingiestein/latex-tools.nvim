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
  return M.list_files_up_to_depth(extensions, 1)
end

--- List files with given extensions under cwd, relative paths, sorted.
--- @param extensions string[] e.g. { "bib", "png" }
--- @param max_depth integer|nil directory depth below cwd (0 = cwd only). Default 4.
function M.list_files_up_to_depth(extensions, max_depth)
  max_depth = max_depth or 4
  if max_depth < 0 then
    max_depth = 0
  end

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
    -- depth 0: cwd/*.ext
    collect(cwd .. "/*." .. ext)
    local prefix = cwd
    for depth = 1, max_depth do
      prefix = prefix .. "/*"
      collect(prefix .. "/*." .. ext)
    end
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

function M.relative_path(path, directory)
  local prefix = directory:gsub("/+$", "") .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return vim.fn.fnamemodify(path, ":t")
end

function M.list_tex_files(directory, recursive)
  if vim.fn.isdirectory(directory) ~= 1 then
    return {}
  end

  local patterns = recursive and { "*.tex", "**/*.tex" } or { "*.tex" }
  local seen = {}
  local files = {}

  for _, pattern in ipairs(patterns) do
    for _, path in ipairs(vim.fn.globpath(directory, pattern, false, true)) do
      if vim.fn.filereadable(path) == 1 and not seen[path] then
        seen[path] = true
        table.insert(files, path)
      end
    end
  end

  table.sort(files)
  return files
end

function M.sanitize_message(text, max_len)
  if type(text) ~= "string" or text == "" then
    return "Command failed"
  end

  local cleaned = text:gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  max_len = max_len or 500
  if #cleaned > max_len then
    return cleaned:sub(1, max_len) .. "..."
  end
  return cleaned
end

function M.valid_date(value)
  if type(value) ~= "string" then
    return false
  end

  local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if not year or not month or not day then
    return false
  end
  if month < 1 or month > 12 or day < 1 or day > 31 then
    return false
  end

  local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
    days_in_month[2] = 29
  end

  return day <= days_in_month[month]
end

function M.parse_template_metadata(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    return {}
  end

  local metadata = {}
  local limit = math.min(#lines, 20)
  for index = 1, limit do
    local value = lines[index]:match("^%%%s*latex%-tools:%s*(.+)%s*$")
    if value then
      local key, setting = value:match("^([^=]+)%s*=%s*(.+)$")
      if key and setting then
        metadata[key:match("^%s*(.-)%s*$")] = setting:match("^%s*(.-)%s*$")
      else
        metadata.type = value:match("^%s*(.-)%s*$")
      end
    end
  end

  return metadata
end

function M.parse_buffer_metadata(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(vim.api.nvim_buf_line_count(buf), 20), false)
  local metadata = {}

  for _, line in ipairs(lines) do
    local value = line:match("^%%%s*latex%-tools:%s*(.+)%s*$")
    if value then
      local key, setting = value:match("^([^=]+)%s*=%s*(.+)$")
      if key and setting then
        metadata[key:match("^%s*(.-)%s*$")] = setting:match("^%s*(.-)%s*$")
      else
        metadata.type = value:match("^%s*(.-)%s*$")
      end
    end
  end

  return metadata
end

function M.is_course_aware_buffer(buf)
  local metadata = M.parse_buffer_metadata(buf or 0)
  return metadata.type == "course-aware"
end

function M.get_saved_buffer_path(buf)
  buf = buf or 0
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  return path
end

function M.sanitize_filename(value)
  local name = value:gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("%.tex$", "")
  name = M.slugify(name)
  if name == "" then
    return nil
  end
  return name .. ".tex"
end

function M.is_course_aware_template(path)
  local metadata = M.parse_template_metadata(path)
  return metadata.type == "course-aware"
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