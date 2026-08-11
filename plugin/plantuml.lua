if vim.g.loaded_plantuml then
  return
end
vim.g.loaded_plantuml = true

local commands = {
  PlantumlPreviewToggle = "toggle",
  PlantumlPreviewOpen   = "open",
  PlantumlPreviewClose  = "close",
  PlantumlPreviewNext   = "next_diagram",
  PlantumlPreviewPrev   = "prev_diagram",
  PlantumlPreviewZoomIn = "zoom_in",
  PlantumlPreviewZoomOut = "zoom_out",
  PlantumlPreviewZoomReset = "zoom_reset",
}

for cmd_name, method in pairs(commands) do
  vim.api.nvim_create_user_command(cmd_name, function()
    require("plantuml")[method]()
  end, {})
end
