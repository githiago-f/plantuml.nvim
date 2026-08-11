local M = {}

local state = { previews = {} }

local function config()
  return require("plantuml.config").options
end

local function has_image_nvim()
  local ok = pcall(require, "image")
  return ok
end

local function notify_missing_image()
  vim.notify(
    "plantuml.nvim: image.nvim is required for rendering. "
      .. "Install https://github.com/3rd/image.nvim",
    vim.log.levels.WARN
  )
end

local function notify_image_failed()
  vim.notify(
    "plantuml.nvim: failed to render image. Check image.nvim configuration.",
    vim.log.levels.ERROR
  )
end

local function clear_current_image(p)
  if not p.image then return end
  pcall(p.image.clear, p.image)
  p.image = nil
end

local function configure_scratch_buf(buf)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
end

local function create_vsplit(buf)
  vim.cmd("vsplit")
  local win = vim.api.nvim_get_current_win()
  configure_scratch_buf(buf)
  vim.api.nvim_win_set_buf(win, buf)
  vim.cmd(string.format("vertical resize %s", config().output.window_size))
  return win
end

local function create_scratch_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  configure_scratch_buf(buf)
  return buf
end

local function to_list(v)
  if type(v) == "table" then return v end
  return { v }
end

local function render_at(p, index)
  local img_path = p.paths[index]
  if not img_path then return end

  p.current = index

  if not has_image_nvim() then
    clear_current_image(p)
    notify_missing_image()
    return
  end

  local api = require("image")
  local new_image = api.from_file(img_path, {
    window = p.win,
    buffer = p.buf,
  })
  if not new_image then
    clear_current_image(p)
    notify_image_failed()
    return
  end

  clear_current_image(p)
  p.image = new_image
  p.image:render()
end

function M.open(source_bufnr, img_paths)
  if state.previews[source_bufnr] then
    return state.previews[source_bufnr]
  end

  img_paths = to_list(img_paths)
  local current_win = vim.api.nvim_get_current_win()

  if not has_image_nvim() then
    notify_missing_image()
    return nil
  end

  local buf = create_scratch_buf()
  local win = create_vsplit(buf)
  vim.api.nvim_set_current_win(current_win)

  local api = require("image")
  local image_obj = api.from_file(img_paths[1], {
    window = win,
    buffer = buf,
  })
  if not image_obj then
    notify_image_failed()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  image_obj:render()

  state.previews[source_bufnr] = {
    win = win,
    buf = buf,
    paths = img_paths,
    current = 1,
    image = image_obj,
  }
  return state.previews[source_bufnr]
end

function M.reload(source_bufnr, img_paths)
  local p = state.previews[source_bufnr]
  if not p then return M.open(source_bufnr, img_paths) end

  if not vim.api.nvim_win_is_valid(p.win) then
    M.close(source_bufnr)
    return M.open(source_bufnr, img_paths)
  end

  img_paths = to_list(img_paths)
  p.paths = img_paths
  p.current = 1
  render_at(p, 1)
end

function M.close(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p then return end

  clear_current_image(p)

  if vim.api.nvim_win_is_valid(p.win) then
    vim.api.nvim_win_close(p.win, true)
  end
  if vim.api.nvim_buf_is_valid(p.buf) then
    vim.api.nvim_buf_delete(p.buf, { force = true })
  end
  state.previews[source_bufnr] = nil
end

function M.next(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p or #p.paths < 2 then return end
  local next_idx = p.current + 1
  if next_idx > #p.paths then next_idx = 1 end
  render_at(p, next_idx)
end

function M.prev(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p or #p.paths < 2 then return end
  local prev_idx = p.current - 1
  if prev_idx < 1 then prev_idx = #p.paths end
  render_at(p, prev_idx)
end

function M.exists(bufnr)
  return state.previews[bufnr] ~= nil
end

function M.count(bufnr)
  local p = state.previews[bufnr]
  return p and #p.paths or 0
end

function M.current_index(bufnr)
  local p = state.previews[bufnr]
  return p and p.current or 0
end

return M
