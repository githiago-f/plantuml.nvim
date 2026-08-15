local M = {}

local state = { previews = {} }

local viewport = nil
local function vp()
  if not viewport then
    viewport = require("plantuml.viewport")
  end
  return viewport
end

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

-- terminal cell size in pixels; nil when unavailable (e.g. headless).
local function cell_size()
  local ok, term = pcall(require, "image.utils.term")
  if not ok then return nil end
  local size = term.get_size()
  return size
end

-- Geometry (in terminal cells) that fits the whole diagram inside the preview
-- window at the current zoom (zoom <= 1 path: fit, shrink, never overflow).
local function fit_geometry(p, cell)
  local win_w = vim.api.nvim_win_get_width(p.win)
  local win_h = vim.api.nvim_win_get_height(p.win)
  local nat_w = p.nat.w / cell.cell_width
  local nat_h = p.nat.h / cell.cell_height
  local fit = math.min(win_w / nat_w, win_h / nat_h)
  local width = math.floor(nat_w * fit * (p.zoom or 1))
  local height = math.floor(nat_h * fit * (p.zoom or 1))
  if width < 1 then width = 1 end
  if height < 1 then height = 1 end
  return { width = width, height = height }
end

-- Reuse the current image object when it already shows `path`, otherwise
-- replace it with a fresh one from `path`.
local function ensure_image(p, path)
  if p.image and p.image.original_path == path then
    return p.image
  end
  if not has_image_nvim() then
    clear_current_image(p)
    notify_missing_image()
    return nil
  end
  clear_current_image(p)
  local img = require("image").from_file(path, {
    window = p.win,
    buffer = p.buf,
  })
  if not img then
    notify_image_failed()
    return nil
  end
  p.image = img
  return img
end

local function render_from(p, path, geometry)
  local img = ensure_image(p, path)
  if not img then return end
  img.ignore_global_max_size = true
  img:render(geometry)
end

-- Cropped viewport files live in their own directory per preview and are only
-- deleted on close (image.nvim re-identifies files it still references).
local function crop_dir(p)
  if p.view_dir then return p.view_dir end
  p.view_dir = string.format(
    "%s/%d_view_%d",
    config().cmd.temp_dir,
    p.source,
    vim.uv.hrtime()
  )
  vim.fn.mkdir(p.view_dir, "p")
  return p.view_dir
end

local function cleanup_view_dir(p)
  if not p.view_dir then return end
  for _, name in ipairs(vim.fn.readdir(p.view_dir) or {}) do
    pcall(os.remove, p.view_dir .. "/" .. name)
  end
  pcall(vim.fn.delete, p.view_dir, "d")
  p.view_dir = nil
end

-- Async-crop the region under the viewport and render it at window size.
local function render_cropped(p, region)
  p.view_gen = p.view_gen + 1
  local gen = p.view_gen
  local out = string.format(
    "%s/view_%d_%d_%d_%d_%d.png",
    crop_dir(p),
    gen,
    region.x,
    region.y,
    region.w,
    region.h
  )
  vp().crop(p.src, region, out, function(ok)
    vim.schedule(function()
      if not p or p.view_gen ~= gen then return end
      if not vim.api.nvim_win_is_valid(p.win) then return end
      if not ok then
        vim.notify(
          "plantuml.nvim: failed to crop zoomed region (ImageMagick required)",
          vim.log.levels.WARN
        )
        return
      end
      local cell = cell_size()
      if not cell then return end
      render_from(p, out, vp().display_geometry(
        vim.api.nvim_win_get_width(p.win),
        vim.api.nvim_win_get_height(p.win),
        cell.cell_width,
        cell.cell_height,
        region
      ))
    end)
  end)
end

-- Region (in source pixels) the preview window currently shows; nil when the
-- whole diagram fits (zoom <= 1).
local function current_region(p)
  if not p.image or not p.nat then return nil end
  local cell = cell_size()
  if not cell or not cell.cell_width or not cell.cell_height then return nil end
  if not vim.api.nvim_win_is_valid(p.win) then return nil end
  return vp().region(
    p.nat.w,
    p.nat.h,
    vim.api.nvim_win_get_width(p.win),
    vim.api.nvim_win_get_height(p.win),
    cell.cell_width,
    cell.cell_height,
    p.zoom or 1,
    p.pan
  )
end

-- Re-render: crop (zoom > 1) or fit the whole image (zoom <= 1).
local function refresh_view(p)
  if not vim.api.nvim_win_is_valid(p.win) then return end
  if not p.image or not p.nat then return end

  local cell = cell_size()
  if not cell or not cell.cell_width or not cell.cell_height then
    -- Cannot compute the viewport (e.g. headless); fall back to plain render.
    p.image.ignore_global_max_size = true
    p.image:render()
    return
  end

  local region = current_region(p)
  if region then
    render_cropped(p, region)
  else
    render_from(p, p.src, fit_geometry(p, cell))
  end
end

-- Keep the point under the current viewport center fixed while zooming.
local function keep_center_pan(p, old_zoom, new_zoom)
  local cell = cell_size()
  if not p.nat or not cell then return p.pan end
  return vp().keep_center(
    old_zoom,
    new_zoom,
    p.pan,
    p.nat.w,
    p.nat.h,
    vim.api.nvim_win_get_width(p.win),
    vim.api.nvim_win_get_height(p.win),
    cell.cell_width,
    cell.cell_height
  )
end

local function update_statusline(p)
  if not p.win or not vim.api.nvim_win_is_valid(p.win) then return end
  local name = (p.names and p.names[p.current]) or ""
  local total = p.paths and #p.paths or 0
  local zoom = p.zoom or 1
  local hint = zoom > 1 and "  <drag or Pan*> to move" or ""
  vim.wo[p.win].statusline = string.format(
    "PlantUML [%d/%d] %s (%.2fx)%s",
    p.current,
    total,
    name,
    zoom,
    hint
  )
end

local function pan_by(p, dx, dy)
  local region = current_region(p)
  if not region then return end
  local win_w = vim.api.nvim_win_get_width(p.win)
  local win_h = vim.api.nvim_win_get_height(p.win)
  p.pan.x = p.pan.x + dx * (region.w / win_w)
  p.pan.y = p.pan.y + dy * (region.h / win_h)
  refresh_view(p)
  update_statusline(p)
end

-- --- Mouse drag -------------------------------------------------------------

local function stop_drag(p)
  if p.drag then
    if p.drag.timer then
      p.drag.timer:stop()
      p.drag.timer:close()
    end
    p.drag = nil
  end
end

local function drag_poll(p)
  if not p.drag then return end
  if not vim.api.nvim_win_is_valid(p.win) then
    stop_drag(p)
    return
  end
  local region = current_region(p)
  if not region then
    stop_drag(p)
    return
  end
  local pos = vim.fn.getmousepos()
  local win_w = vim.api.nvim_win_get_width(p.win)
  local win_h = vim.api.nvim_win_get_height(p.win)
  p.pan.x = p.drag.start_pan.x - (pos.col - p.drag.col) * (region.w / win_w)
  p.pan.y = p.drag.start_pan.y - (pos.row - p.drag.row) * (region.h / win_h)
  refresh_view(p)
end

local function drag_start(p, pos)
  if not current_region(p) then return end
  stop_drag(p)
  p.drag = {
    start_pan = { x = p.pan.x, y = p.pan.y },
    col = pos.col,
    row = pos.row,
    timer = vim.uv.new_timer(),
  }
  p.drag.timer:start(30, 30, vim.schedule_wrap(function()
    drag_poll(p)
  end))
end

local function setup_drag(p)
  vim.keymap.set("n", "<LeftMouse>", function()
    if not p.image then return end
    drag_start(p, vim.fn.getmousepos())
  end, { buffer = p.buf, silent = true })

  vim.keymap.set("n", "<LeftRelease>", function()
    stop_drag(p)
  end, { buffer = p.buf, silent = true })
end

-- ---------------------------------------------------------------------------

local function render_at(p, index)
  local img_path = p.paths[index]
  if not img_path then return end

  p.current = index
  update_statusline(p)

  if not has_image_nvim() then
    clear_current_image(p)
    notify_missing_image()
    return
  end

  local new_image = require("image").from_file(img_path, {
    window = p.win,
    buffer = p.buf,
  })
  if not new_image then
    clear_current_image(p)
    notify_image_failed()
    return
  end

  p.src = img_path
  p.nat = { w = new_image.image_width, h = new_image.image_height }
  p.pan = { x = 0, y = 0 }

  clear_current_image(p)
  p.image = new_image
  refresh_view(p)
end

function M.open(source_bufnr, img_paths, names)
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

  local p = {
    source = source_bufnr,
    win = win,
    buf = buf,
    paths = img_paths,
    names = names or {},
    current = 1,
    image = nil,
    zoom = 1,
    pan = { x = 0, y = 0 },
    view_gen = 0,
    view_dir = nil,
    nat = nil,
    src = nil,
    drag = nil,
  }

  setup_drag(p)
  render_at(p, 1)

  if not p.image then
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  state.previews[source_bufnr] = p
  return p
end

function M.reload(source_bufnr, img_paths, names)
  local p = state.previews[source_bufnr]
  if not p then return M.open(source_bufnr, img_paths, names) end

  if not vim.api.nvim_win_is_valid(p.win) then
    M.close(source_bufnr)
    return M.open(source_bufnr, img_paths, names)
  end

  p.paths = to_list(img_paths)
  p.names = names or {}
  render_at(p, 1)
end

function M.close(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p then return end

  stop_drag(p)
  p.view_gen = p.view_gen + 1
  clear_current_image(p)

  if vim.api.nvim_win_is_valid(p.win) then
    vim.api.nvim_win_close(p.win, true)
  end
  if vim.api.nvim_buf_is_valid(p.buf) then
    vim.api.nvim_buf_delete(p.buf, { force = true })
  end
  state.previews[source_bufnr] = nil

  cleanup_view_dir(p)

  -- The window is gone, so image.nvim will no longer re-render these paths.
  local renderer = require("plantuml.renderer")
  renderer.invalidate(source_bufnr)
  renderer.cleanup(source_bufnr)
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

local function clamp_zoom(p)
  local zoom = config().zoom
  p.zoom = math.max(zoom.min, math.min(p.zoom, zoom.max))
end

function M.zoom_in(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p or not p.image then return end
  local old = p.zoom
  p.zoom = p.zoom + config().zoom.step
  clamp_zoom(p)
  if p.zoom ~= old then
    p.pan = keep_center_pan(p, old, p.zoom)
  end
  refresh_view(p)
  update_statusline(p)
end

function M.zoom_out(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p or not p.image then return end
  local old = p.zoom
  p.zoom = p.zoom - config().zoom.step
  clamp_zoom(p)
  if p.zoom ~= old then
    p.pan = keep_center_pan(p, old, p.zoom)
  end
  refresh_view(p)
  update_statusline(p)
end

function M.zoom_reset(source_bufnr)
  local p = state.previews[source_bufnr]
  if not p or not p.image then return end
  p.zoom = 1
  p.pan = { x = 0, y = 0 }
  refresh_view(p)
  update_statusline(p)
end

function M.pan_left(source_bufnr)
  local p = state.previews[source_bufnr]
  if p then pan_by(p, -config().zoom.pan_step, 0) end
end

function M.pan_right(source_bufnr)
  local p = state.previews[source_bufnr]
  if p then pan_by(p, config().zoom.pan_step, 0) end
end

function M.pan_up(source_bufnr)
  local p = state.previews[source_bufnr]
  if p then pan_by(p, 0, -config().zoom.pan_step) end
end

function M.pan_down(source_bufnr)
  local p = state.previews[source_bufnr]
  if p then pan_by(p, 0, config().zoom.pan_step) end
end

-- Jump to a diagram by index (1-based) or by name (case-insensitive exact,
-- then substring).
function M.goto_diagram(source_bufnr, query)
  local p = state.previews[source_bufnr]
  if not p or not query or query == "" then return end

  local idx = tonumber(query)
  if idx then
    if idx >= 1 and idx <= #p.paths then render_at(p, idx) end
    return
  end

  local lower = query:lower()
  for i, name in ipairs(p.names or {}) do
    if name and name:lower() == lower then
      render_at(p, i)
      return
    end
  end
  for i, name in ipairs(p.names or {}) do
    if name and name:lower():find(lower, 1, true) then
      render_at(p, i)
      return
    end
  end
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

function M.current_zoom(bufnr)
  local p = state.previews[bufnr]
  return p and p.zoom or 1
end

function M.current_name(bufnr)
  local p = state.previews[bufnr]
  if not p or not p.names then return nil end
  return p.names[p.current]
end

function M.current_name_of(bufnr, index)
  local p = state.previews[bufnr]
  if not p or not p.names then return nil end
  return p.names[index]
end

return M