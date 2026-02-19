local M = {}

local state = {
  previews = {}
}

local function create_float(buf)
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.8)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = "rounded",
  })
end

function M.open(bufnr, img_path)
  if state.previews[bufnr] then
    return state.previews[bufnr]
  end

  local img_buf = vim.fn.bufadd(img_path)
  vim.fn.bufload(img_buf)

  vim.bo[img_buf].modifiable = false
  vim.bo[img_buf].bufhidden = "wipe"

  create_float(img_buf)

  state.previews[bufnr] = {
    buf = img_buf,
    path = img_path,
  }

  return state.previews[bufnr]
end

function M.reload(bufnr)
  local p = state.previews[bufnr]
  if not p then return end

  vim.api.nvim_buf_call(p.buf, function()
    vim.cmd("edit!")
  end)
end

function M.close(bufnr)
  local p = state.previews[bufnr]
  if not p then return end

  vim.api.nvim_buf_delete(p.buf, { force = true })
  state.previews[bufnr] = nil
end

return M
