local M = {}

function M.ensure_tmp()
  vim.fn.mkdir(require("plantuml.config").options.cmd.temp_dir, "p")
end

---@alias ImagePaths
---| { img: string, src: string }
---@return ImagePaths
function M.build(bufnr)
  M.ensure_tmp()
  local config = require("plantuml.config").options

  local ext = config.output.format

  return {
    src = string.format(
      "%s/%s.puml",
      config.cmd.temp_dir,
      bufnr
    ),
    img = string.format(
      "%s/%s.%s",
      config.cmd.temp_dir,
      bufnr,
      ext
    )
  }
end

return M
