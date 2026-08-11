local M = {}

---@alias fileFormat "svg" | "png" | "utxt"
local defaults = {
  output = {
    format = "png",
    window_size = 70
  },
  cmd = {
    exec = "plantuml",
    debounce_ms = 2000,
    temp_dir = "/tmp/nvim-plantuml",
  }
}

---@type PumlOptions
M.options = vim.deepcopy(defaults)

--- @alias PumlOptions
--- | { output: { format: fileFormat, window_size: number }, cmd: { exec: string, debounce_ms: number, temp_dir: string } }

---@param opts PumlOptions | nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend(
    "force",
    M.options,
    opts or {}
  )
end

return M
