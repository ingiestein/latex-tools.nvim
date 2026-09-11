local util = require("latex-tools.util")

local M = {}

function M.insert_figure_snippet()
  local image_paths = util.list_files_up_to_depth({ "png", "jpg", "jpeg", "gif", "webp", "pdf", "svg" }, 4)
  if #image_paths == 0 then
    vim.notify("No image files found under the current directory (depth <= 4)", vim.log.levels.WARN)
    return
  end

  vim.ui.select(image_paths, {
    prompt = "Select figure image",
    format_item = function(item)
      return item
    end,
  }, function(path_choice)
    if not path_choice then
      return
    end

    local default_caption = vim.fn.fnamemodify(path_choice, ":t:r")
    local caption = vim.fn.input("Figure caption: ", default_caption)
    if caption == "" then
      caption = default_caption
    end

    local width = vim.fn.input("Image width: ", "0.85\\linewidth")
    if width == "" then
      width = "0.85\\linewidth"
    end

    local label = "fig:" .. util.slugify(vim.fn.fnamemodify(path_choice, ":t:r"))
    util.insert_lines_at_cursor({
      "\\begin{figure}[htbp]",
      "  \\centering",
      "  \\includegraphics[width=" .. width .. "]{" .. util.escape_latex_text(path_choice) .. "}",
      "  \\caption{" .. util.escape_latex_text(caption) .. "}",
      "  \\label{" .. label .. "}",
      "\\end{figure}",
    })
  end)
end

function M.insert_basic_figure_snippet()
  util.insert_lines_at_cursor({
    "\\begin{figure}[htbp]",
    "  \\centering",
    "  \\includegraphics[width=0.85\\linewidth]{figures/figure-file-name}",
    "  \\caption{Short, descriptive caption.}",
    "  \\label{fig:meaningful-label}",
    "\\end{figure}",
  })
end

return M
