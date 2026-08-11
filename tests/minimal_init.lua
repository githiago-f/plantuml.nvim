-- Minimal init for plenary/busted tests. Used as `-u tests/minimal_init.lua`
-- so plugin modules load from this repo without touching the real config.
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:match("^@?(.*)$"), ":p:h:h")

vim.opt.runtimepath:append(repo)
vim.opt.swapfile = false
vim.opt.runtimepath:remove(vim.fn.stdpath("config"))
