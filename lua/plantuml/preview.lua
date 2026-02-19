local M = {}

local state = {
  previews = {} -- [source_bufnr] = { win, buf, path }
}

local function create_vsplit(img_buf)
  -- open split on the right
  vim.cmd("vsplit")

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, img_buf)

  -- preview ergonomics
  vim.bo[img_buf].modifiable = false
  vim.bo[img_buf].readonly = true
  vim.bo[img_buf].bufhidden = "wipe"
  vim.bo[img_buf].swapfile = false

  local width = require("plantuml.config").options.output.window_size or 40

  -- optional: fix width
  vim.cmd(string.format("vertical resize %s", width))

  return win
end

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

function M.reload(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p then return end

  if not vim.api.nvim_buf_is_valid(p.buf) then
    return
  end

  vim.cmd("checktime " .. p.buf)

  vim.api.nvim_buf_call(p.buf, function()
    vim.cmd("silent edit!")
  end)
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

return M
