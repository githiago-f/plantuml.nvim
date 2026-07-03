if vim.g.loaded_plantuml then
  return
end
vim.g.loaded_plantuml = true

local commands = {
  toggle = "PlantumlPreviewToggle",
  open = "PlantumlPreviewOpen",
  close = "PlantumlPreviewClose",
  generate = "PlantumlGenerateWorkspace"
}

vim.api.nvim_create_user_command(
  commands.toggle,
  function()
    require("plantuml").toggle()
  end,
  {}
)

vim.api.nvim_create_user_command(
  commands.open,
  function()
    require("plantuml").open()
  end,
  {}
)

vim.api.nvim_create_user_command(
  commands.close,
  function()
    require("plantuml").close()
  end,
  {}
)
