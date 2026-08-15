-- Zoomed-in preview shows a window-sized crop of the source image ("viewport")
-- so the focused part can be panned instead of overflowing the pane.
-- Math lives here (pure, testable); the only side effect is the async
-- ImageMagick crop that produces the viewport file.

local M = {}

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

---@param src_w integer
---@param src_h integer
---@param win_w integer
---@param win_h integer
---@param cw number
---@param ch number
---@return number
local function fit_factor(src_w, src_h, win_w, win_h, cw, ch)
  local nat_w = src_w / cw
  local nat_h = src_h / ch
  return math.min(win_w / nat_w, win_h / nat_h)
end

-- Size (in source pixels) of the region the window shows at `zoom`.
-- zoom = 1 means the whole diagram fits the window; zoom > 1 shows a
-- window-sized crop magnified by `zoom`. Returns nil when the whole image
-- fits (no crop needed).
---@param src_w integer
---@param src_h integer
---@param win_w integer
---@param win_h integer
---@param cw number
---@param ch number
---@param zoom number
---@return { w: integer, h: integer } | nil
function M.region_size(src_w, src_h, win_w, win_h, cw, ch, zoom)
  if zoom <= 1 then return nil end
  local fit = fit_factor(src_w, src_h, win_w, win_h, cw, ch)
  local w = (win_w * cw) / (fit * zoom)
  local h = (win_h * ch) / (fit * zoom)
  if w >= src_w and h >= src_h then return nil end
  w = math.max(1, math.floor(math.min(w, src_w)))
  h = math.max(1, math.floor(math.min(h, src_h)))
  return { w = w, h = h }
end

-- Clamp a pan offset (source pixels) so the region stays inside the image.
---@param pan { x: number, y: number }
---@param src_w integer
---@param src_h integer
---@param size { w: integer, h: integer }
---@return { x: number, y: number }
function M.clamp_pan(pan, src_w, src_h, size)
  return {
    x = clamp(pan and pan.x or 0, 0, math.max(0, src_w - size.w)),
    y = clamp(pan and pan.y or 0, 0, math.max(0, src_h - size.h)),
  }
end

-- Full crop rect (origin + size) for the current zoom/pan. Nil when the whole
-- image fits.
---@param src_w integer
---@param src_h integer
---@param win_w integer
---@param win_h integer
---@param cw number
---@param ch number
---@param zoom number
---@param pan { x: number, y: number }
---@return { x: number, y: number, w: integer, h: integer } | nil
function M.region(src_w, src_h, win_w, win_h, cw, ch, zoom, pan)
  local size = M.region_size(src_w, src_h, win_w, win_h, cw, ch, zoom)
  if not size then return nil end
  local clamped = M.clamp_pan(pan, src_w, src_h, size)
  return {
    x = math.floor(clamped.x),
    y = math.floor(clamped.y),
    w = size.w,
    h = size.h,
  }
end

-- When the zoom changes, keep the point under the current viewport center in
-- place: compute the new pan so the center of the new region equals the center
-- of the old one (or the image center when zoomed out to fit).
---@param old_zoom number
---@param new_zoom number
---@param pan { x: number, y: number }
---@param src_w integer
---@param src_h integer
---@param win_w integer
---@param win_h integer
---@param cw number
---@param ch number
---@return { x: number, y: number }
function M.keep_center(old_zoom, new_zoom, pan, src_w, src_h, win_w, win_h, cw, ch)
  local old = M.region_size(src_w, src_h, win_w, win_h, cw, ch, old_zoom)
  local new = M.region_size(src_w, src_h, win_w, win_h, cw, ch, new_zoom)
  if not new then return { x = 0, y = 0 } end

  local cx, cy
  if old then
    cx = (pan and pan.x or 0) + old.w / 2
    cy = (pan and pan.y or 0) + old.h / 2
  else
    cx, cy = src_w / 2, src_h / 2
  end
  return M.clamp_pan({ x = cx - new.w / 2, y = cy - new.h / 2 }, src_w, src_h, new)
end

-- Terminal-cell geometry for rendering a cropped region inside the window.
-- Scales the region's pixels to fit the window while preserving its aspect
-- ratio. Since cells are taller than wide, the scale must be computed in
-- pixels and converted back to cells, or the image letterboxes too small.
---@param win_w integer
---@param win_h integer
---@param cw number
---@param ch number
---@param region { w: integer, h: integer }
---@return { width: integer, height: integer }
function M.display_geometry(win_w, win_h, cw, ch, region)
  local scale = math.min((win_w * cw) / region.w, (win_h * ch) / region.h)
  local width = math.max(1, math.floor(region.w * scale / cw))
  local height = math.max(1, math.floor(region.h * scale / ch))
  return { width = width, height = height }
end

---@param region { x: number, y: number, w: integer, h: integer }
---@return string "WxH+X+Y"
function M.crop_arg(region)
  return string.format("%dx%d+%d+%d", region.w, region.h, region.x, region.y)
end

-- Async ImageMagick crop of `src` to `out`. `cb(true)` on success. image.nvim
-- already requires ImageMagick for its default `magick_cli` processor, so we
-- reuse the same binaries.
---@param src string
---@param region { x: number, y: number, w: integer, h: integer }
---@param out string
---@param cb fun(ok: boolean)
function M.crop(src, region, out, cb)
  local magick = vim.fn.executable("magick") == 1 and "magick"
    or (vim.fn.executable("convert") == 1 and "convert")
  if not magick then
    cb(false)
    return
  end
  vim.system(
    { magick, src, "-crop", M.crop_arg(region), out },
    { text = true },
    function(result)
      cb(result.code == 0)
    end
  )
end

return M