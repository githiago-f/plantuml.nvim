local config = require("plantuml.config").options

local M = {}

M.window_width = config.output.window_size

---@alias preview
---| { win: number, buf: number, img: string  }
---
---@alias tstate
---| { previews: { [number]: preview } }
---
---@type tstate
local state = {
  previews = {} -- [source_bufnr] = { win, buf, path }
}

local function create_vsplit(img_buf)
  vim.cmd("vsplit")

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, img_buf)

  vim.bo[img_buf].modifiable = false
  vim.bo[img_buf].readonly = true
  vim.bo[img_buf].bufhidden = "hide"
  vim.bo[img_buf].buftype = 'nofile'
  vim.bo[img_buf].swapfile = false


  vim.cmd(string.format("vertical resize %s", M.window_width))

  return win
end

---@param source_bufnr number
---@param img_path string
---@return preview
function M.open(source_bufnr, img_path)
  if state.previews[source_bufnr] then
    return state.previews[source_bufnr]
  end

  -- load image buffer
  local img_buf = vim.fn.bufadd(img_path)
  vim.fn.bufload(img_buf)

  local current_win = vim.api.nvim_get_current_win()

  local win = create_vsplit(img_buf)

  -- return focus to source
  vim.api.nvim_set_current_win(current_win)

  state.previews[source_bufnr] = {
    win = win,
    buf = img_buf,
    path = img_path,
  }

  return state.previews[source_bufnr]
end

function M.reload(source_bufnr, img_path)
  local p = state.previews[source_bufnr]
  if not p then return M.open(source_bufnr, img_path) end

  p.img = img_path

  local win_width = vim.api.nvim_win_get_width(p.win)
  M.window_width = win_width

  if vim.api.nvim_buf_is_valid(p.buf) then
    vim.api.nvim_buf_delete(p.buf, { force = true })
  end

  local new_buf = vim.fn.bufadd(img_path)
  vim.fn.bufload(new_buf)

  if not vim.api.nvim_win_is_valid(p.win) then
    local current_window = vim.api.nvim_get_current_win()
    p.win = create_vsplit(new_buf)
    vim.api.nvim_set_current_win(current_window)
    return
  end

  vim.api.nvim_win_set_buf(p.win, new_buf)

  p.buf = new_buf
end

function M.close(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p then return end

  if vim.api.nvim_win_is_valid(p.win) then
    vim.api.nvim_win_close(p.win, true)
  end

  if vim.api.nvim_buf_is_valid(p.buf) then
    vim.api.nvim_buf_delete(p.buf, { force = true })
  end

  state.previews[source_bufnr] = nil
end

function M.exists(bufnr)
  return state.previews[bufnr] ~= nil
end

return M
