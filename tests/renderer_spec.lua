local config = require("plantuml.config")
local paths = require("plantuml.paths")
local renderer = require("plantuml.renderer")

local TMP = vim.fn.tempname() .. "-plantuml-tests"

local function setup_temp()
  vim.fn.mkdir(TMP, "p")
  config.setup({
    output = { format = "utxt", window_size = 40 },
    cmd = {
      exec = "plantuml",
      debounce_ms = 10,
      temp_dir = TMP,
    },
  })
end

local function cleanup_temp()
  renderer.cleanup(0)
  for _, name in ipairs(vim.fn.readdir(TMP) or {}) do
    pcall(os.remove, TMP .. "/" .. name)
  end
  pcall(vim.fn.delete, TMP, "d")
end

---@param lines string[]
---@return integer bufnr
local function make_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

---@param buf integer
---@return string[]|nil
---@return string[]|nil
local function render_sync(buf)
  local done = false
  local result, result_names
  renderer.render(buf, paths.build(buf), function(files, _, names)
    result = files
    result_names = names
    done = true
  end)
  vim.wait(15000, function() return done end)
  return result, result_names
end

describe("renderer", function()
  before_each(setup_temp)
  after_each(cleanup_temp)

  it("renders a single diagram to a .utxt file", function()
    local buf = make_buffer({
      "@startuml",
      "Alice -> Bob: hello",
      "@enduml",
    })
    local files = render_sync(buf)
    assert.truthy(files, "render callback never fired")
    assert.equals(1, #files)

    local content = table.concat(vim.fn.readfile(files[1]), "\n")
    assert.matches("Alice", content)
    assert.matches("Bob", content)
    assert.matches("hello", content)
  end)

  it("renders multiple diagrams into separate files", function()
    local buf = make_buffer({
      "@startuml",
      "Alice -> Bob: first",
      "@enduml",
      "",
      "@startuml",
      "Carol -> Dave: second",
      "@enduml",
    })
    local files = render_sync(buf)
    assert.truthy(files, "render callback never fired")
    assert.equals(2, #files)

    local first = table.concat(vim.fn.readfile(files[1]), "\n")
    local second = table.concat(vim.fn.readfile(files[2]), "\n")
    assert.matches("first", first)
    assert.matches("second", second)
  end)

  it("finds named diagrams in source order", function()
    local buf = make_buffer({
      "@startuml",
      "Alice -> Bob: first",
      "@enduml",
      "",
      "@startuml NamedFoo",
      "Bob -> Charlie",
      "@enduml",
      "",
      "@startuml",
      "Carol -> Dave: last",
      "@enduml",
    })
    local files, names = render_sync(buf)
    assert.truthy(files, "render callback never fired")
    assert.equals(3, #files)
    assert.same({ "diagram 1", "NamedFoo", "diagram 2" }, names)

    -- unnamed #1, then the named diagram, then unnamed #2 (source order)
    assert.matches("first", table.concat(vim.fn.readfile(files[1]), "\n"))
    assert.matches("NamedFoo", vim.fn.fnamemodify(files[2], ":t"))
    assert.matches("last", table.concat(vim.fn.readfile(files[3]), "\n"))
  end)

  it("does not mix output from different diagram counts", function()
    local buf = make_buffer({
      "@startuml",
      "Alice -> Bob: one",
      "@enduml",
      "",
      "@startuml",
      "Carol -> Dave: two",
      "@enduml",
    })
    local two = render_sync(buf)
    assert.equals(2, #two)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "@startuml",
      "Eve -> Frank: only",
      "@enduml",
    })
    local one = render_sync(buf)
    assert.equals(1, #one)
    assert.matches("only", table.concat(vim.fn.readfile(one[1]), "\n"))
  end)

  it("writes the source buffer into the temp dir", function()
    local buf = make_buffer({
      "@startuml",
      "Alice -> Bob",
      "@enduml",
    })
    local p = paths.build(buf)
    render_sync(buf)
    local src_lines = vim.fn.readfile(p.src)
    assert.matches("@startuml", table.concat(src_lines, "\n"))
  end)
end)
