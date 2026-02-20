local M = {}

---@alias Callback  fun(path: string)
---@param p ImagePaths
---@param cb Callback
function M.render(bufnr, p, cb)
  local config = require('plantuml.config').options
  local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  vim.fn.writefile(buflines, p.src)

  local format_flag = string.format("-t%s", config.output.format or 'png')
  local args = {
    p.src,
    format_flag,
    "-o",
    config.cmd.temp_dir
  }

  local cmd = vim.split(config.cmd.exec, " ")
  table.move(args, 1, #args, #cmd + 1, cmd)

  vim.fn.jobstart(cmd, {
    on_exit = function()
      vim.schedule(function()
        if cb then cb(p.img) end
      end)
    end
  })
end

return M
