local M = {}

local defaults = {
  keymaps = {
    enable = true,
    prefix = "\\t",
  },
  commands = {
    enable = true,
  },
  paths = {
    template_dir = nil,
    yaml_path = nil,
    tex_template_path = nil,
    custom_snippets_dir = nil,
    python_script_path = nil,
    test_script_path = nil,
  },
  python_cmd = nil,
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

function M.get()
  return M.options
end

return M