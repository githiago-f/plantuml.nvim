local config = require("plantuml.config").options

local M = {}

function M.ensure_tmp()
  vim.fn.mkdir(config.temp_dir, "p")
end

function M.build(bufnr)
  M.ensure_tmp()

  local ext = config.output.format

  return {
    src = string.format(
      "%s/%s.puml",
      config.temp_dir,
      bufnr
    ),
    img = string.format(
      "%s/%s.%s",
      config.temp_dir,
      bufnr,
      ext
    )
  }
end

return M
