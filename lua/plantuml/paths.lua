local M = {}

function M.build(bufnr)
  local config = require("plantuml.config").options
  vim.fn.mkdir(config.cmd.temp_dir, "p")
  return {
    src = string.format("%s/%s.puml", config.cmd.temp_dir, bufnr),
  }
end

return M
