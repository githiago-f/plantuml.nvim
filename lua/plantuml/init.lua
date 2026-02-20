local paths = require('plantuml.paths')
local renderer = require("plantuml.renderer")

local M = {}

function M.setup(...)
  require("plantuml.config").setup(...)
end

function M.open()
  local preview = require('plantuml.preview')
  local bufnr = vim.api.nvim_get_current_buf()
  local p = paths.build(bufnr)

  renderer.render(bufnr, p, function(img)
    if preview.exists(bufnr) then
      preview.reload(bufnr)
    else
      preview.open(bufnr, img)
    end
  end)

  require("plantuml.watcher").attach(bufnr, p)
end

function M.close()
  require('plantuml.preview').close(vim.api.nvim_get_current_buf())
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  require('plantuml.preview').close(bufnr)
  M.open()
end

return M
