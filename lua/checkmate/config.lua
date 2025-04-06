-- Config
-- stores the state of the plugin (configuration + runtime state of plugin)
local M = {}

-- Namespace for plugin-related state
M.ns = vim.api.nvim_create_namespace("checkmate")

-- Default configuration with documentation using LuaLS annotations
---@class CheckmateConfig
---@field opt string Your main option
---@field enabled boolean Whether the plugin is enabled
---@field notify boolean Whether to show notifications
---@field log_level "trace"|"debug"|"info"|"warn"|"error" Log level
M.defaults = {
  opt = "Hello!",
  enabled = true,
  notify = true,
  log_level = "info",
}

-- Runtime state
M._loaded = false
M._running = false

function M.is_loaded()
  return M._loaded
end
function M.is_running()
  return M._running
end

-- Runtime configuration (will be populated in setup)
---@type CheckmateConfig
---@diagnostic disable-next-line: missing-fields
M.options = {}

--- Setup function
---@param opts? CheckmateConfig
function M.setup(opts)
  -- Handle options
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  M._loaded = true

  -- Log configuration when debugging
  if M.options.log_level == "debug" then
    vim.notify("Checkmate config: " .. vim.inspect(M.options), vim.log.levels.DEBUG)
  end

  -- Auto-start if enabled
  if M.options.enabled then
    M.start()
  end
end

function M.start()
  if M._running then
    return
  end
  M._running = true

  if M.options.log_level == "debug" then
    vim.notify("Checkmate started", vim.log.levels.DEBUG)
  end

  -- Setup autocmds, initialize state, etc.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("checkmate", { clear = true }),
    callback = function()
      M.stop()
    end,
  })
end

function M.stop()
  if not M._running then
    return
  end
  M._running = false

  -- Cleanup resources
  vim.api.nvim_del_augroup_by_name("checkmate")
end

return M
