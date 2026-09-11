local state = require("latex-tools.state")
local util = require("latex-tools.util")

local M = {}

local LISTINGS_INPUT = "latex-tools-code"
local MINTED_INPUT = "latex-tools-code-minted"

local function parse_code_input_line(line)
  local indent, comment, name = line:match("^(%s*)(%%*)%s*\\input%s*{%s*(latex%-tools%-code%-minted)%s*}%s*$")
  if name then
    return {
      indent = indent or "",
      commented = comment ~= nil and comment:find("%%") ~= nil,
      kind = "minted",
      name = MINTED_INPUT,
    }
  end

  indent, comment, name = line:match("^(%s*)(%%*)%s*\\input%s*{%s*(latex%-tools%-code)%s*}%s*$")
  if name then
    return {
      indent = indent or "",
      commented = comment ~= nil and comment:find("%%") ~= nil,
      kind = "listings",
      name = LISTINGS_INPUT,
    }
  end

  return nil
end

--- Switch the active \\input companion in a saved course-aware parent buffer.
--- @param opts table|nil { minted?: boolean } minted=true enables minted; false restores listings
function M.use_minted_companion(opts)
  local options = opts or {}
  local use_minted = options.minted == true
  local target = use_minted and MINTED_INPUT or LISTINGS_INPUT

  local buf = vim.api.nvim_get_current_buf()
  local parent_path = util.get_saved_buffer_path(buf)
  if not parent_path then
    vim.notify(
      "Save this buffer first so the code companion \\input line can be updated.",
      vim.log.levels.ERROR
    )
    return nil
  end

  state.ensure_project_companions(parent_path)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local changed = false
  local found_active = false

  for index, line in ipairs(lines) do
    local parsed = parse_code_input_line(line)
    if parsed and not parsed.commented then
      found_active = true
      local replacement = parsed.indent .. "\\input{" .. target .. "}"
      if lines[index] ~= replacement then
        lines[index] = replacement
        changed = true
      end
    end
  end

  if not found_active then
    vim.notify(
      "No active \\input{latex-tools-code} or \\input{latex-tools-code-minted} line found in this buffer.",
      vim.log.levels.WARN
    )
    return nil
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  if use_minted then
    vim.notify(
      "Using minted fences (\\input{"
        .. MINTED_INPUT
        .. "}). Compile with -shell-escape; pygmentize must be on PATH.",
      vim.log.levels.INFO
    )
  else
    vim.notify("Using portable listings fences (\\input{" .. LISTINGS_INPUT .. "}).", vim.log.levels.INFO)
  end

  return target
end

M.parse_code_input_line = parse_code_input_line

return M
