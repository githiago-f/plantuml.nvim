local config = require('plantuml.config').options
local paths = require('plantuml.paths')

local M = {}

---@alias Callback  fun(path: string): nil
---@param cb Callback
function M.render(bufnr, cb)
  local p = paths.build(bufnr)

  vim.fn.writefile(
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    p.src
  )

  local format_flag = string.format("-t%s", config.output.format)

  vim.fn.jobstart({
    config.cmd.exec,
    format_flag,
    p.src,
    "-o",
    config.cmd.temp_dir
  }, {
    on_exit = function()
      if cb then
        vim.schedule(function()
          cb(p.img)
        end)
      end
    end
  })
end

return M
