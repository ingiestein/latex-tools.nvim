local state = require("latex-tools.state")

local M = {}

function M.run_tests()
  local paths = state.get_paths()
  local output = vim.fn.system({
    "nvim",
    "--headless",
    "-u",
    "NONE",
    "-l",
    paths.test_script_path,
  })

  local exit_code = vim.v.shell_error
  local level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
  local title = exit_code == 0 and "Template tests passed" or "Template tests failed"

  vim.notify(title, level)
  if output and output ~= "" then
    vim.notify(output, level)
  end
end

return M