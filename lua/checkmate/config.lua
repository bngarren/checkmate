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
---@field log_to_buffer boolean Whether to log to a buffer
---@field log_to_file boolean Whether to log to a file
---@field keys table<string, string|false> Keymappings (false to disable)
M.defaults = {
  opt = "Hello!",
  enabled = true,
  notify = true,
  log_level = "info",
  log_to_buffer = false,
  log_to_file = false,
  -- Default keymappings
  keys = {
    ["<leader>Tt"] = "toggle", -- Toggle todo item
    ["<leader>Tn"] = "create", -- Create todo item
  },
  todo_markers = {
    unchecked = {
      primary = "□ ",
      alternate = "[ ] ",
    },
    checked = {
      primary = "✔ ",
      alternate = "[x] ",
    },
  },
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
