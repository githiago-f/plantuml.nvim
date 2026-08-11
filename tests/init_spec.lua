-- Verifies the public API and that user commands map to the right methods.
local init = require("plantuml")

local methods = {
  "open",
  "close",
  "toggle",
  "next_diagram",
  "prev_diagram",
  "zoom_in",
  "zoom_out",
  "zoom_reset",
}

describe("plantuml public API", function()
  it("exposes all expected methods", function()
    for _, m in ipairs(methods) do
      assert.is_function(init[m], "missing method: " .. m)
    end
  end)

  it("setup passes opts through to config", function()
    require("plantuml.config").setup({})
    init.setup({
      output = { format = "svg" },
    })
    assert.equals("svg", require("plantuml.config").options.output.format)
  end)
end)

describe("user commands", function()
  it("registers preview commands", function()
    for _, cmd in ipairs({
      "PlantumlPreviewToggle",
      "PlantumlPreviewOpen",
      "PlantumlPreviewClose",
      "PlantumlPreviewNext",
      "PlantumlPreviewPrev",
      "PlantumlPreviewZoomIn",
      "PlantumlPreviewZoomOut",
      "PlantumlPreviewZoomReset",
    }) do
      local ok = pcall(vim.api.nvim_get_commands, {})
      assert.truthy(ok)
      local found = vim.api.nvim_get_commands({})[cmd] ~= nil
      assert.is_true(found, "missing command: " .. cmd)
    end
  end)
end)
