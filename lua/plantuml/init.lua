local paths = require('plantuml.paths')
local renderer = require("plantuml.renderer")

local M = {}

local plantuml_filetypes = { ["puml"] = true, ["plantuml"] = true, ["pu"] = true }

function M.setup(opts)
  require("plantuml.config").setup(opts)
end

function M.open()
  local preview = require('plantuml.preview')
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft ~= "" and not plantuml_filetypes[ft] then
    vim.notify(
      "plantuml.nvim: not a PlantUML buffer (" .. ft .. ")",
      vim.log.levels.WARN
    )
    return
  end

  local p = paths.build(bufnr)

  renderer.render(bufnr, p, function(img_paths)
    if preview.exists(bufnr) then
      preview.reload(bufnr, img_paths)
    else
      if not preview.open(bufnr, img_paths) then
        require("plantuml.watcher").detach(bufnr)
        renderer.cleanup(bufnr)
      end
    end
  end)

  require("plantuml.watcher").attach(bufnr, p)
end

function M.close()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.watcher").detach(bufnr)
  require('plantuml.preview').close(bufnr)
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  if require("plantuml.preview").exists(bufnr) then
    M.close()
  else
    M.open()
  end
end

function M.next_diagram()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").next(bufnr)
end

function M.prev_diagram()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").prev(bufnr)
end

function M.zoom_in()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").zoom_in(bufnr)
end

function M.zoom_out()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").zoom_out(bufnr)
end

function M.zoom_reset()
  local bufnr = vim.api.nvim_get_current_buf()
  require("plantuml.preview").zoom_reset(bufnr)
end

return M
