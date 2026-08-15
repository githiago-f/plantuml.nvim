-- Exercises preview state logic with a stubbed `image` module so the specs
-- run headless without image.nvim or a terminal. `plantuml.viewport` is also
-- stubbed so the ImageMagick crop never shells out; the crop math is real.
local config = require("plantuml.config")
local preview = require("plantuml.preview")
local renderer = require("plantuml.renderer")

local TMP = vim.fn.tempname() .. "-plantuml-preview"

local rendered = {}
local cleared = {}
local crops = {}

local last_opts = {}

local real_viewport = require("plantuml.viewport")
package.loaded["plantuml.viewport"] = nil
package.preload["plantuml.viewport"] = function()
  local stub = vim.deepcopy(real_viewport)
  stub.crop = function(src, region, out, cb)
    table.insert(crops, { src = src, region = region, out = out })
    vim.fn.writefile({}, out)
    cb(true)
  end
  return stub
end

package.preload["image"] = function()
  return {
    from_file = function(path, opts)
      last_opts = opts
      local img = {
        original_path = path,
        image_width = 100,
        image_height = 50,
        render = function(self, geometry)
          self.geometry = geometry
          table.insert(rendered, { path = path, geometry = geometry })
        end,
        clear = function(self)
          table.insert(cleared, path)
        end,
      }
      return img
    end,
  }
end

-- stub term size used by the viewport math
package.preload["image.utils.term"] = function()
  return {
    get_size = function()
      return {
        cell_width = 8,
        cell_height = 16,
      }
    end,
  }
end

local open_bufs = {}

---@param lines string[]
---@return integer
local function make_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  table.insert(open_bufs, buf)
  return buf
end

local function first_image()
  return rendered[#rendered]
end

local function wait_rendered(n)
  vim.wait(2000, function() return #rendered >= n end)
end

describe("preview", function()
  before_each(function()
    rendered = {}
    cleared = {}
    crops = {}
    open_bufs = {}
    config.setup({
      output = { format = "utxt", window_size = 40 },
      cmd = {
        exec = "plantuml",
        temp_dir = TMP,
      },
      zoom = { step = 0.5, min = 0.25, max = 4, pan_step = 2 },
    })
    vim.fn.mkdir(TMP, "p")
    -- create fake output files
    vim.fn.writefile({ "diagram one" }, TMP .. "/11.utxt")
    vim.fn.writefile({ "diagram two" }, TMP .. "/11_001.utxt")
  end)

  after_each(function()
    for _, buf in ipairs(open_bufs) do
      preview.close(buf)
    end
    preview.close(0)
    renderer.cleanup(0)
    for _, name in ipairs(vim.fn.readdir(TMP) or {}) do
      local path = TMP .. "/" .. name
      if vim.fn.isdirectory(path) == 1 then
        for _, inner in ipairs(vim.fn.readdir(path) or {}) do
          pcall(os.remove, path .. "/" .. inner)
        end
        pcall(vim.fn.delete, path, "d")
      else
        pcall(os.remove, path)
      end
    end
    pcall(vim.fn.delete, TMP, "d")
  end)

  it("opens a preview with the first diagram", function()
    local buf = make_buffer({ "@startuml", "Alice -> Bob", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt", TMP .. "/11_001.utxt" })
    assert.is_true(preview.exists(buf))
    assert.equals(2, preview.count(buf))
    assert.equals(1, preview.current_index(buf))
    assert.matches("11.utxt", first_image().path)
  end)

  it("cycles next/prev across diagrams", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt", TMP .. "/11_001.utxt" })

    preview.next(buf)
    assert.equals(2, preview.current_index(buf))
    assert.matches("11_001.utxt", first_image().path)

    preview.next(buf) -- wraps around
    assert.equals(1, preview.current_index(buf))
    assert.matches("11.utxt", first_image().path)

    preview.prev(buf)
    assert.equals(2, preview.current_index(buf))
  end)

  it("zoom_in crops a window-sized viewport and leaves the pane alone", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local win = vim.api.nvim_get_current_win()
    local before = vim.api.nvim_win_get_width(win)

    preview.zoom_in(buf)
    wait_rendered(2)

    assert.is_true(preview.current_zoom(buf) > 1)
    assert.equals(1, #crops)
    -- the crop is smaller than the 100px-wide source image
    assert.is_true(crops[1].region.w < 100)
    -- rendered geometry stays inside the preview window
    local img = first_image()
    assert.truthy(img.geometry)
    assert.is_true(img.geometry.width <= vim.api.nvim_win_get_width(win))
    assert.is_true(img.geometry.height <= vim.api.nvim_win_get_height(win))
    assert.equals(before, vim.api.nvim_win_get_width(win))
  end)

  it("zoom keeps the viewport center fixed", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })

    preview.zoom_in(buf) -- fit -> zoomed, centered on the image center
    wait_rendered(2)

    assert.equals(1, #crops)
    assert.is_true(crops[1].region.x > 0, "first crop should be horizontally centered")
    assert.is_true(crops[1].region.x < 100 - crops[1].region.w, "center crop should be in range")
  end)

  it("pan moves the viewport origin", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    preview.zoom_in(buf)
    wait_rendered(2)
    local before_x = crops[1].region.x

    preview.pan_right(buf)
    wait_rendered(3)

    assert.equals(2, #crops)
    assert.is_true(crops[2].region.x > before_x, "panning right moves the crop right")
  end)

  it("pan is a no-op at zoom 1", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })

    preview.pan_left(buf)
    preview.pan_down(buf)

    assert.equals(0, #crops)
  end)

  it("zoom_reset returns to the whole-image fit", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local base = first_image().geometry.width

    preview.zoom_in(buf)
    wait_rendered(2)
    preview.zoom_reset(buf)
    wait_rendered(3)

    assert.equals(1, preview.current_zoom(buf))
    assert.equals(base, first_image().geometry.width)
    assert.matches("11.utxt", first_image().path)
  end)

  it("zoom 1 fits the image inside the preview window", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local img = first_image()
    assert.truthy(img.geometry)
    assert.is_true(
      img.geometry.width <= vim.api.nvim_win_get_width(last_opts.window),
      "zoom 1 should fit within the preview window width"
    )
    assert.is_true(
      img.geometry.height <= vim.api.nvim_win_get_height(last_opts.window),
      "zoom 1 should fit within the preview window height"
    )
  end)

  it("goto_diagram jumps by index, exact name, and substring", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, {
      TMP .. "/11.utxt",
      TMP .. "/11_001.utxt",
      TMP .. "/11_002.utxt",
    }, { "First", "Second", "Third" })

    preview.goto_diagram(buf, 3)
    assert.equals(3, preview.current_index(buf))
    assert.equals("Third", preview.current_name(buf))

    preview.goto_diagram(buf, "second")
    assert.equals(2, preview.current_index(buf))

    preview.goto_diagram(buf, "thi")
    assert.equals(3, preview.current_index(buf))
  end)

  it("close cleans up the preview, clears the image, and removes viewport files", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    preview.zoom_in(buf)
    wait_rendered(2)
    assert.equals(1, #crops)

    local view_dir = vim.fn.fnamemodify(crops[1].out, ":h")
    assert.equals(1, vim.fn.isdirectory(view_dir))

    preview.close(buf)

    assert.is_false(preview.exists(buf))
    -- the image currently shown is the viewport crop; close must clear it
    assert.equals(crops[1].out, cleared[#cleared])
    assert.equals(0, vim.fn.isdirectory(view_dir))
  end)
end)