-- main module entry point
-- should handle configuration/setup, define the public API

---@class MyModule
local M = {}

-- Get config module
local Config = require("checkmate.config")

---@param opts CheckmateConfig?
M.setup = function(opts)
  -- Validate options
  if opts ~= nil and type(opts) ~= "table" then
    error("Setup options must be a table")
  end

  Config.setup(opts)

  -- Register filetype detection
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.todo",
    callback = function()
      vim.bo.filetype = "todo"
      M.setup_buffer()

      -- Log that we've set up for this buffer
      vim.notify("Checkmate activated for todo file", vim.log.levels.INFO)
    end,
  })

  if not vim.g.checkmate_loaded then
    vim.g.checkmate_loaded = true
  end
end

function M.setup_buffer()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only activate for todo files
  if vim.bo[bufnr].filetype ~= "todo" then
    return
  end

  -- Load todo functionality
  require("checkmate.todo").setup_buffer(bufnr)
end

return M
