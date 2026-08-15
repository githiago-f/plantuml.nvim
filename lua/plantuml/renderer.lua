local M = {}

local gen = {}
local render_dirs = {}

-- Map the `@startuml` blocks of the source buffer to the output filenames
-- PlantUML produces, in source order:
--   * unnamed diagram #1            -> <bufnr>.<ext>
--   * unnamed diagram #k (k > 1)    -> <bufnr>_%03d.<ext>
--   * named diagram `@startuml Foo` -> Foo.<ext>
-- Returns `paths, names` (parallel arrays). Named diagrams are thus reachable
-- through the preview instead of being dropped by a <bufnr> prefix filter.
-- Files PlantUML wrote under unexpected names (e.g. mangled diagram names)
-- are appended sorted by name so nothing is lost.
local function find_output_files(dir, bufnr, ext)
  local files = {}
  local names = {}
  local by_name = {}
  for _, name in ipairs(vim.fn.readdir(dir) or {}) do
    by_name[name] = dir .. "/" .. name
  end

  local unnamed = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local diagram = line:match("^%s*@startuml%s*(.*)$")
    if diagram then
      diagram = diagram:gsub("%s+$", "")
      local fname
      local label
      if diagram ~= "" then
        fname = diagram .. "." .. ext
        label = diagram
      else
        unnamed = unnamed + 1
        if unnamed == 1 then
          fname = tostring(bufnr) .. "." .. ext
        else
          fname = string.format("%s_%03d.%s", bufnr, unnamed - 1, ext)
        end
        label = string.format("diagram %d", unnamed)
      end
      local path = by_name[fname]
      if path then
        table.insert(files, path)
        table.insert(names, label)
        by_name[fname] = nil
      end
    end
  end

  local leftover = {}
  for name in pairs(by_name) do
    if name:match("%." .. ext .. "$") then
      table.insert(leftover, name)
    end
  end
  table.sort(leftover)
  for _, name in ipairs(leftover) do
    table.insert(files, by_name[name])
    table.insert(names, (name:gsub("%." .. ext .. "$", "")))
  end

  return files, names
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

        local output_files, names = find_output_files(
          render_dir,
          bufnr,
          config.output.format or "png"
        )
        if #output_files == 0 then
          vim.notify("plantuml.nvim: no output images found", vim.log.levels.WARN)
          return
        end

        if cb then cb(output_files, render_dir, names) end
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
    -- plantuml may create subdirectories for names containing '/' (it treats
    -- them as path separators), so remove recursively
    pcall(vim.fn.delete, dir, "rf")
  end
  render_dirs[bufnr] = nil
end

return M
