-- main module entry point
-- should handle configuration/setup, define the public API

---@class MyModule
local M = {}

---@param opts checkmate.Config?
M.setup = function(opts)
  local config = require("checkmate.config")

  config.setup(opts)

  -- Initialize the logger
  local log = require("checkmate.log")
  log.setup()

  log.debug(config.options)
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

  log.info("Checkmate plugin loaded successfully")
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
