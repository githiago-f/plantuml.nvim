-- Exercises preview state logic with a stubbed `image` module so the specs
-- run headless without image.nvim or a terminal.
local config = require("plantuml.config")
local preview = require("plantuml.preview")
local renderer = require("plantuml.renderer")

local TMP = vim.fn.tempname() .. "-plantuml-preview"

local rendered = {}
local cleared = {}

local last_opts = {}

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

-- stub term size used by zoom_geometry
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

---@param lines string[]
---@return integer
local function make_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

local function first_image()
  return rendered[#rendered]
end

describe("preview", function()
  before_each(function()
    rendered = {}
    cleared = {}
    config.setup({
      output = { format = "utxt", window_size = 40 },
      cmd = {
        exec = "plantuml",
        temp_dir = TMP,
      },
      zoom = { step = 0.5, min = 0.25, max = 4 },
    })
    vim.fn.mkdir(TMP, "p")
    -- create fake output files
    vim.fn.writefile({ "diagram one" }, TMP .. "/11.utxt")
    vim.fn.writefile({ "diagram two" }, TMP .. "/11_001.utxt")
  end)

  after_each(function()
    preview.close(0)
    renderer.cleanup(0)
    for _, name in ipairs(vim.fn.readdir(TMP) or {}) do
      pcall(os.remove, TMP .. "/" .. name)
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

  it("zoom_in scales the image and leaves the pane alone", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local win = vim.api.nvim_get_current_win()
    local before = vim.api.nvim_win_get_width(win)
    local base = first_image().geometry.width

    preview.zoom_in(buf)

    assert.is_true(preview.current_zoom(buf) > 1)
    local img = first_image()
    assert.truthy(img.geometry)
    assert.is_true(img.geometry.width > base)
    assert.equals(before, vim.api.nvim_win_get_width(win))
  end)

  it("zoom_out shrinks the image", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local base = first_image().geometry.width

    preview.zoom_out(buf)
    preview.zoom_out(buf)

    assert.is_true(preview.current_zoom(buf) < 1)
    local img = first_image()
    assert.truthy(img.geometry)
    assert.is_true(img.geometry.width < base)
  end)

  it("zoom 1 fits the image inside the preview window", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local img = first_image()
    assert.truthy(img.geometry)
    -- image.nvim clamps to the window via max_width_window_percentage=100 by
    -- default, but our zoom path passes explicit geometry; make sure the fit
    -- geometry does not exceed the preview window (which is window_size wide).
    assert.is_true(
      img.geometry.width <= vim.api.nvim_win_get_width(last_opts.window),
      "zoom 1 should fit within the preview window width"
    )
    assert.is_true(
      img.geometry.height <= vim.api.nvim_win_get_height(last_opts.window),
      "zoom 1 should fit within the preview window height"
    )
  end)

  it("zoom_reset returns to zoom 1", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    local base = first_image().geometry.width

    preview.zoom_in(buf)
    preview.zoom_reset(buf)

    assert.equals(1, preview.current_zoom(buf))
    assert.equals(base, first_image().geometry.width)
  end)

  it("close cleans up the preview and clears the image", function()
    local buf = make_buffer({ "@startuml", "x", "@enduml" })
    preview.open(buf, { TMP .. "/11.utxt" })
    preview.close(buf)

    assert.is_false(preview.exists(buf))
    assert.matches("11.utxt", cleared[#cleared])
  end)
end)
