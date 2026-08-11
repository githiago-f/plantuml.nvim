local M = {}

local gen = {}
local render_dirs = {}

local function find_output_files(dir, bufnr, ext)
  local files = {}
  local prefix = tostring(bufnr)
  for _, name in ipairs(vim.fn.readdir(dir) or {}) do
    if name == prefix .. "." .. ext
      or name:match("^" .. prefix .. "_%d+%." .. ext .. "$")
    then
      table.insert(files, dir .. "/" .. name)
    end
  end
  table.sort(files)
  return files
end

function M.render(bufnr, p, cb)
  local config = require('plantuml.config').options

  local exec_parts = vim.split(config.cmd.exec, " ")
  if vim.fn.executable(exec_parts[1]) == 0 then
    vim.notify(
      string.format("plantuml.nvim: '%s' not found on PATH", config.cmd.exec),
      vim.log.levels.ERROR
    )
    return
  end

  local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local write_ok = vim.fn.writefile(buflines, p.src)
  if write_ok ~= 0 then
    vim.notify(
      "plantuml.nvim: failed to write temporary source file",
      vim.log.levels.ERROR
    )
    return
  end

  -- Each render writes into its own directory. Old render dirs are left in
  -- place until the preview closes so that image.nvim objects still
  -- referencing their files never hit a missing file on re-render.
  local render_dir = string.format("%s/%d_%d", config.cmd.temp_dir, bufnr, vim.uv.hrtime())
  vim.fn.mkdir(render_dir, "p")
  render_dirs[bufnr] = render_dirs[bufnr] or {}
  table.insert(render_dirs[bufnr], render_dir)

  local current_gen = (gen[bufnr] or 0) + 1
  gen[bufnr] = current_gen

  local cmd_args = {
    p.src,
    "-nometadata",
    string.format("-t%s", config.output.format or "png"),
    "-o",
    render_dir,
  }
  table.move(cmd_args, 1, #cmd_args, #exec_parts + 1, exec_parts)

  vim.fn.jobstart(exec_parts, {
    on_stderr = function(_, data)
      if data and #data > 0 then
        local lines = vim.tbl_filter(function(line) return line ~= "" end, data)
        if #lines > 0 then
          vim.notify(
            "plantuml.nvim: " .. table.concat(lines, "\n"),
            vim.log.levels.WARN
          )
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- A newer render already started (or the preview was closed):
        -- drop this stale callback entirely.
        if gen[bufnr] ~= current_gen then return end

        if exit_code ~= 0 then
          vim.notify(
            string.format("plantuml.nvim: render failed with exit code %d", exit_code),
            vim.log.levels.ERROR
          )
          return
        end

        local output_files = find_output_files(
          render_dir,
          bufnr,
          config.output.format or "png"
        )
        if #output_files == 0 then
          vim.notify("plantuml.nvim: no output images found", vim.log.levels.WARN)
          return
        end

        if cb then cb(output_files, render_dir) end
      end)
    end
  })
end

-- Bump the render generation so in-flight callbacks for this bufnr are dropped.
function M.invalidate(bufnr)
  gen[bufnr] = (gen[bufnr] or 0) + 1
end

-- Remove every render directory created for this bufnr. Only safe to call
-- once the preview window is gone (image.nvim stops re-rendering then).
function M.cleanup(bufnr)
  for _, dir in ipairs(render_dirs[bufnr] or {}) do
    for _, name in ipairs(vim.fn.readdir(dir) or {}) do
      pcall(os.remove, dir .. "/" .. name)
    end
    pcall(vim.fn.delete, dir, "d")
  end
  render_dirs[bufnr] = nil
end

return M
