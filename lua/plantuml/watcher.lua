local renderer = require("plantuml.renderer")
local preview = require("plantuml.preview")

local M = {}
local timers = {}
local augroup_prefix = "plantuml_watcher_"

local function config()
  return require("plantuml.config").options
end

local function cleanup_timer(bufnr)
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
    timers[bufnr] = nil
  end
end

local function debounce(bufnr, fn)
  cleanup_timer(bufnr)
  timers[bufnr] = vim.uv.new_timer()
  timers[bufnr]:start(config().cmd.debounce_ms, 0, vim.schedule_wrap(fn))
end

function M.attach(bufnr, p)
  local augroup = augroup_prefix .. bufnr
  vim.api.nvim_create_augroup(augroup, { clear = true })

  vim.api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "BufWritePost" },
    {
      group = augroup,
      buffer = bufnr,
      callback = function()
        debounce(bufnr, function()
          renderer.render(bufnr, p, function(img)
            preview.reload(bufnr, img)
          end)
        end)
      end,
    }
  )

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      cleanup_timer(bufnr)
      preview.close(bufnr)
    end,
  })
end

function M.detach(bufnr)
  cleanup_timer(bufnr)
  pcall(vim.api.nvim_del_augroup_by_name, augroup_prefix .. bufnr)
end

return M
