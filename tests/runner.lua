-- Runs the plenary.busted specs under tests/ in headless nvim.
-- Usage: ./tests/run.sh [spec_file...]
local args = {}
for _, a in ipairs(arg or {}) do
  if a ~= "-l" and a ~= "tests/runner.lua" then
    table.insert(args, a)
  end
end

local files = #args > 0 and args or vim.fn.glob("tests/*_spec.lua", false, true)

local function find_plenary()
  local from_env = os.getenv("PLENARY_PATH")
  if from_env and from_env ~= "" and vim.fn.isdirectory(from_env) == 1 then
    return from_env
  end
  local from_pack = vim.fn.stdpath("data") .. "/site/pack/core/opt/plenary.nvim"
  if vim.fn.isdirectory(from_pack) == 1 then return from_pack end
  return nil
end

local plenary = find_plenary()

if #files == 0 then
  print("No spec files found.")
  return vim.cmd "2cq"
end

if not plenary then
  print("plenary.nvim not found. Set PLENARY_PATH or install it at")
  print(vim.fn.stdpath("data") .. "/site/pack/core/opt/plenary.nvim")
  return vim.cmd "2cq"
end

vim.opt.runtimepath:append(plenary)

for _, file in ipairs(files) do
  require("plenary.busted").run(vim.fn.fnamemodify(file, ":p"))
end
