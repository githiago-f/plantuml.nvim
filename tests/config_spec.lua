local config = require("plantuml.config")

describe("config", function()
  before_each(function()
    config.setup({})
  end)

  it("has sane defaults", function()
    assert.equals("png", config.options.output.format)
    assert.equals(70, config.options.output.window_size)
    assert.equals("plantuml", config.options.cmd.exec)
    assert.equals(2000, config.options.cmd.debounce_ms)
    assert.equals("/tmp/nvim-plantuml", config.options.cmd.temp_dir)
    assert.equals(0.25, config.options.zoom.step)
    assert.equals(0.25, config.options.zoom.min)
    assert.equals(4, config.options.zoom.max)
  end)

  it("deep-merges user options over defaults", function()
    config.setup({
      output = { format = "utxt" },
      cmd = { debounce_ms = 500 },
      zoom = { min = 0.1 },
    })
    assert.equals("utxt", config.options.output.format)
    assert.equals(70, config.options.output.window_size) -- untouched
    assert.equals(500, config.options.cmd.debounce_ms)
    assert.equals("plantuml", config.options.cmd.exec) -- untouched
    assert.equals(0.1, config.options.zoom.min)
    assert.equals(0.25, config.options.zoom.step) -- untouched
    assert.equals(4, config.options.zoom.max) -- untouched
  end)

  it("accumulates across setup calls without dropping previous keys", function()
    config.setup({ output = { format = "svg" } })
    config.setup({ cmd = { debounce_ms = 100 } })
    assert.equals("svg", config.options.output.format)
    assert.equals(100, config.options.cmd.debounce_ms)
    assert.equals("plantuml", config.options.cmd.exec)
  end)
end)
