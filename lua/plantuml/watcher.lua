local config = require("plantuml.config").options
local renderer = require("plantuml.renderer")
local preview = require("plantuml.preview")

local M = {}

local timers = {}

local function debounce(bufnr, fn)
  if timers[bufnr] then
    timers[bufnr]:stop()
  end

  timers[bufnr] = vim.loop.new_timer()

  timers[bufnr]:start(
    config.cmd.debounce_ms,
    0,
    vim.schedule_wrap(fn)
  )
end

function M.attach(bufnr)
  vim.api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "BufWritePost" },
    {
      buffer = bufnr,
      callback = function()
        debounce(bufnr, function()
          renderer.render(bufnr, function(img)
            preview.reload(bufnr)
          end)
        end)
      end,
    }
  )
end

return M
