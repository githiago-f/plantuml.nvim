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
  },
  zoom = {
    step = 0.25,
    min = 0.25,
    max = 4,
    pan_step = 2,
  }
}

---@type PumlOptions
M.options = vim.deepcopy(defaults)

--- @alias PumlOptions
--- | { output: { format: fileFormat, window_size: number }, cmd: { exec: string, debounce_ms: number, temp_dir: string }, zoom: { step: number, min: number, max: number, pan_step: number } }

---@param opts PumlOptions | nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend(
    "force",
    M.options,
    opts or {}
  )
end

return M
