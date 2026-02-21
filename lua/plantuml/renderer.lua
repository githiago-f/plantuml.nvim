local M = {}

local function make_file_names(temp_dir, bufnr, ext)
  local file_dest = string.format("%d_%d.%s", bufnr, vim.uv.hrtime(), ext)
  local file_original = string.format("%s/%d.%s", temp_dir, bufnr, ext)
  local full_file_path = string.format("%s/%s", temp_dir, file_dest)

  return {
    file_original = file_original,
    full_file_path = full_file_path
  }
end

---@alias Callback  fun(path: string)
---@param p ImagePaths
---@param cb Callback
function M.render(bufnr, p, cb)
  local config = require('plantuml.config').options
  local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  vim.fn.writefile(buflines, p.src)

  local ext = config.output.format or 'png'

  local file_names = make_file_names(config.cmd.temp_dir, bufnr, ext)

  local format_flag = string.format("-t%s", ext)
  local args = {
    p.src,
    "-nometadata",
    format_flag,
    "-o",
    config.cmd.temp_dir
  }

  local cmd = vim.split(config.cmd.exec, " ")
  table.move(args, 1, #args, #cmd + 1, cmd)

  vim.fn.jobstart(cmd, {
    on_exit = function()
      vim.schedule(function()
        if p.img ~= nil then os.remove(p.img) end

        p.img = file_names.full_file_path
        os.rename(file_names.file_original, file_names.full_file_path)

        if cb then cb(file_names.full_file_path) end
      end)
    end
  })
end

return M
