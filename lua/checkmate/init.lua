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

  local config = require("checkmate.config")

  -- Initialize the logger
  local log = require("checkmate.log")
  log.setup()

  log.debug(config)
  -- Log setup information
  log.debug("Checkmate plugin initializing", { module = "setup" })

  -- Check if Treesitter is available
  if not pcall(require, "nvim-treesitter") then
    log.warn("nvim-treesitter not found. Some features may not work correctly.")
    vim.notify("Checkmate: nvim-treesitter not found. Some features may not work correctly.", vim.log.levels.WARN)
    return
  end

  -- Setup Treesitter
  require("checkmate.parser").setup()
  log.debug("Parser initialized", { module = "setup" })

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.todo",
    callback = function()
      vim.bo.filetype = "markdown"
      M.setup_buffer()

      -- Log that we've set up for this buffer
      log.debug("Activated for .todo file", { module = "autocmd" })
    end,
  })

  if not vim.g.checkmate_loaded then
    vim.g.checkmate_loaded = true
    log.info("Checkmate plugin loaded successfully")
  end
end

function M.setup_buffer()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only activate for markdown files that have .todo extension
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if vim.bo[bufnr].filetype ~= "markdown" or not filename:match("%.todo$") then
    return
  end

  require("checkmate.api").setup(bufnr)
end

return M
