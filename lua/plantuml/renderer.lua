local M = {}

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

local function cleanup_previous_outputs(dir, bufnr)
  local prefix = tostring(bufnr)
  for _, name in ipairs(vim.fn.readdir(dir) or {}) do
    if name ~= prefix .. ".puml" and name:match("^" .. prefix .. "[_.]") then
      pcall(os.remove, dir .. "/" .. name)
    end
  end
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

  cleanup_previous_outputs(config.cmd.temp_dir, bufnr)

  local cmd_args = {
    p.src,
    "-nometadata",
    string.format("-t%s", config.output.format or "png"),
    "-o",
    config.cmd.temp_dir,
  }
  table.move(cmd_args, 1, #cmd_args, #exec_parts + 1, exec_parts)

  vim.fn.jobstart(exec_parts, {
    on_stderr = function(_, data)
      if data and #data > 0 then
        vim.notify(
          "plantuml.nvim: " .. table.concat(data, "\n"),
          vim.log.levels.WARN
        )
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify(
            string.format("plantuml.nvim: render failed with exit code %d", exit_code),
            vim.log.levels.ERROR
          )
          return
        end

        local output_files = find_output_files(
          config.cmd.temp_dir,
          bufnr,
          config.output.format or "png"
        )
        if #output_files == 0 then
          vim.notify("plantuml.nvim: no output images found", vim.log.levels.WARN)
          return
        end

        if cb then cb(output_files) end
      end)
    end
  })
end

return M
