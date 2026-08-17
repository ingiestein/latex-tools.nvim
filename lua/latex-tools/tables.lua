local util = require("latex-tools.util")

local M = {}

function M.insert_table_snippet()
  local caption = vim.fn.input("Table caption: ", "Comparison of methods and outcomes")
  if caption == "" then
    caption = "Table"
  end

  local cols_input = vim.fn.input("Number of columns: ", "3")
  local rows_input = vim.fn.input("Number of data rows: ", "3")

  local num_cols = tonumber(cols_input)
  local num_rows = tonumber(rows_input)
  if not num_cols or not num_rows or num_cols < 1 or num_rows < 1 then
    vim.notify("Table cancelled: invalid row or column count", vim.log.levels.ERROR)
    return
  end

  num_cols = math.floor(num_cols)
  num_rows = math.floor(num_rows)

  local headers = {}
  for i = 1, num_cols do
    local header = vim.fn.input(string.format("Header %d: ", i), "Column " .. i)
    if header == "" then
      header = "Column " .. i
    end
    table.insert(headers, header)
  end

  local label_default = "tab:" .. util.slugify(caption)
  local label = vim.fn.input("Table label: ", label_default)
  if label == "" then
    label = label_default
  end

  local lines = {
    "\\begin{table}[htbp]",
    "  \\centering",
    "  \\caption{" .. util.escape_latex_text(caption) .. "}",
    "  \\label{" .. label .. "}",
    "  \\begin{tabular}{" .. util.build_colspec(num_cols) .. "}",
    "    \\toprule",
    "    " .. table.concat(vim.tbl_map(util.escape_latex_text, headers), " & ") .. " \\\\",
    "    \\midrule",
  }

  for r = 1, num_rows do
    local values = {}
    for c = 1, num_cols do
      table.insert(values, string.format("Value %d.%d", r, c))
    end
    table.insert(lines, "    " .. table.concat(values, " & ") .. " \\\\")
  end

  table.insert(lines, "    \\bottomrule")
  table.insert(lines, "  \\end{tabular}")
  table.insert(lines, "\\end{table}")

  util.insert_lines_at_cursor(lines)
end

function M.insert_basic_table_snippet()
  util.insert_lines_at_cursor({
    "\\begin{table}[htbp]",
    "  \\centering",
    "  \\caption{Comparison of methods and outcomes.}",
    "  \\label{tab:comparison}",
    "  \\begin{tabular}{p{0.28\\linewidth}p{0.28\\linewidth}p{0.28\\linewidth}}",
    "    \\toprule",
    "    Column A & Column B & Column C \\\\",
    "    \\midrule",
    "    Value 1 & Value 2 & Value 3 \\\\",
    "    Value 4 & Value 5 & Value 6 \\\\",
    "    \\bottomrule",
    "  \\end{tabular}",
    "\\end{table}",
  })
end

function M.insert_table_from_csv()
  local csv_files = util.list_files_depth_one({ "csv" })
  if #csv_files == 0 then
    vim.notify("No CSV files found in current directory (depth <= 1)", vim.log.levels.WARN)
    return
  end

  vim.ui.select(csv_files, {
    prompt = "Select CSV file",
    format_item = function(item)
      return item
    end,
  }, function(csv_choice)
    if not csv_choice then
      return
    end

    local rows = util.load_csv_rows(csv_choice)
    if #rows == 0 then
      vim.notify("Selected CSV file is empty", vim.log.levels.WARN)
      return
    end

    local headers = rows[1]
    local data_rows = {}
    for i = 2, #rows do
      table.insert(data_rows, rows[i])
    end

    local caption_default = vim.fn.fnamemodify(csv_choice, ":t:r")
    local caption = vim.fn.input("Table caption: ", caption_default)
    if caption == "" then
      caption = caption_default
    end

    local label_default = "tab:" .. util.slugify(caption)
    local label = vim.fn.input("Table label: ", label_default)
    if label == "" then
      label = label_default
    end

    local lines = {
      "\\begin{table}[htbp]",
      "  \\centering",
      "  \\caption{" .. util.escape_latex_text(caption) .. "}",
      "  \\label{" .. label .. "}",
      "  \\begin{tabular}{" .. util.build_colspec(#headers) .. "}",
      "    \\toprule",
      "    " .. table.concat(vim.tbl_map(util.escape_latex_text, headers), " & ") .. " \\\\",
      "    \\midrule",
    }

    for _, row in ipairs(data_rows) do
      local normalized = {}
      for i = 1, #headers do
        normalized[i] = util.escape_latex_text(row[i] or "")
      end
      table.insert(lines, "    " .. table.concat(normalized, " & ") .. " \\\\")
    end

    table.insert(lines, "    \\bottomrule")
    table.insert(lines, "  \\end{tabular}")
    table.insert(lines, "\\end{table}")

    util.insert_lines_at_cursor(lines)
  end)
end

return M