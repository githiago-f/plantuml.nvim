if vim.g.loaded_plantuml then
  return
end
vim.g.loaded_plantuml = true

vim.api.nvim_create_user_command(
  "PlantumlPreviewToggle",
  function()
    require("plantuml-preview").toggle()
  end,
  {}
)

vim.api.nvim_create_user_command(
  "PlantumlPreviewOpen",
  function()
    require("plantuml-preview").open()
  end,
  {}
)

vim.api.nvim_create_user_command(
  "PlantumlPreviewClose",
  function()
    require("plantuml-preview").close()
  end,
  {}
)
