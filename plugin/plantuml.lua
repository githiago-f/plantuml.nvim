if vim.g.loaded_plantuml then
  return
end
vim.g.loaded_plantuml = true

local commands = {
  PlantumlPreviewToggle    = { method = "toggle" },
  PlantumlPreviewOpen      = { method = "open" },
  PlantumlPreviewClose     = { method = "close" },
  PlantumlPreviewNext      = { method = "next_diagram" },
  PlantumlPreviewPrev      = { method = "prev_diagram" },
  PlantumlPreviewZoomIn    = { method = "zoom_in" },
  PlantumlPreviewZoomOut   = { method = "zoom_out" },
  PlantumlPreviewZoomReset = { method = "zoom_reset" },
  PlantumlPreviewPanUp     = { method = "pan_up" },
  PlantumlPreviewPanDown   = { method = "pan_down" },
  PlantumlPreviewPanLeft   = { method = "pan_left" },
  PlantumlPreviewPanRight  = { method = "pan_right" },
  PlantumlPreviewGoto      = {
    method = "goto_diagram",
    nargs = "?",
    complete = function(arglead)
      return require("plantuml").complete_diagram_names(arglead)
    end,
  },
}

for cmd_name, spec in pairs(commands) do
  local opts = {}
  if spec.nargs then opts.nargs = spec.nargs end
  if spec.complete then opts.complete = spec.complete end
  vim.api.nvim_create_user_command(cmd_name, function(info)
    require("plantuml")[spec.method](info.fargs and info.fargs[1] or nil)
  end, opts)
end