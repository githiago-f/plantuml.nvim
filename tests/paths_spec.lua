local config = require("plantuml.config")
local paths = require("plantuml.paths")

describe("paths", function()
  before_each(function()
    config.setup({
      cmd = { temp_dir = "/tmp/nvim-plantuml-test" },
    })
  end)

  it("builds a source path under the temp dir keyed by bufnr", function()
    local p = paths.build(42)
    assert.equals("/tmp/nvim-plantuml-test/42.puml", p.src)
  end)

  it("creates the temp dir", function()
    paths.build(7)
    assert.equals(1, vim.fn.isdirectory("/tmp/nvim-plantuml-test"))
  end)
end)
