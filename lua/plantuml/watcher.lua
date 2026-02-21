local config = require("plantuml.config").options
local renderer = require("plantuml.renderer")
local preview = require("plantuml.preview")

local M = {}

---@type { [number]: uv.uv_timer_t }
local timers = {}

---@param bufnr number
---@param fn fun()
local function debounce(bufnr, fn)
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
  end

  timers[bufnr] = vim.uv.new_timer()

  timers[bufnr]:start(
    config.cmd.debounce_ms,
    0,
    vim.schedule_wrap(fn)
  )
end

---@param bufnr number
---@param p ImagePaths
function M.attach(bufnr, p)
  vim.api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "BufWritePost" },
    {
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
end

return M
