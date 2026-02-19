local M = {}

function M.setup(...)
  require("plantuml.config").setup(...)
end

function M.open()
  local bufnr = vim.api.nvim_get_current_buf()
  local p = require("plantuml.paths").build(bufnr)

  require("plantuml.renderer").render(bufnr, function(img)
    require("plantuml.preview").open(bufnr, img)
  end)

  require("plantuml.watcher").attach(bufnr)
end

function M.close()
  require("plantuml.preview").close(
    vim.api.nvim_get_current_buf()
  )
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").close(bufnr)
  M.open()
end

return M
