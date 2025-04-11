-- Config
---@class checkmate.Config.mod
local M = {}

-- Namespace for plugin-related state
M.ns = vim.api.nvim_create_namespace("checkmate")

---@class checkmate.LogSettings
--- Any messages above this level will be logged
---@field level (
---    | "trace"
---    | "debug"
---    | "info"
---    | "warn"
---    | "error"
---    | "fatal"
---    | vim.log.levels.DEBUG
---    | vim.log.levels.ERROR
---    | vim.log.levels.INFO
---    | vim.log.levels.TRACE
---    | vim.log.levels.WARN)?
--- Should print log output to a scratch buffer
--- Open with `:Checkmate debug_log`
---@field use_buffer boolean
--- Should print log output to a file
--- Open with `:Checkmate debug_file`
---@field use_file boolean
--- The default path on-disk where log files will be written to.
--- Defaults to `~/.local/share/nvim/checkmate/current.log` (Unix) or `C:\Users\USERNAME\AppData\Local\nvim-data\checkmate\current.log` (Windows)
---@field file_path string?

---@alias checkmate.Action "toggle" | "create"

---@class checkmate.TodoMarkers
---@field unchecked string Character used for unchecked items
---@field checked string Character used for checked items

---@class checkmate.StyleSettings
---@field list_marker table Highlight settings for list markers
---@field unchecked table Highlight settings for unchecked markers
---@field unchecked_content table Highlight settings for unchecked content (todo item text)
---@field checked table Highlight settings for checked markers
---@field checked_content table Highlight settings for checked content (todo item text)

-- Checkmate configuration
---@class checkmate.Config
---@field enabled boolean Whether the plugin is enabled
---@field notify boolean Whether to show notifications
---@field log checkmate.LogSettings Logging settings
---@field keys ( table<string, checkmate.Action>| false ) Keymappings (false to disable)
---@field todo_markers checkmate.TodoMarkers Characters for todo markers (checked and unchecked)
---@field default_list_marker "-" | "*" | "+" Default list item marker to be used when creating new Todo items
---@field style checkmate.StyleSettings Highlight settings

---@type checkmate.Config
local _DEFAULTS = {
  enabled = true,
  notify = true,
  log = {
    level = "info",
    use_buffer = false,
    use_file = false,
  },
  -- Default keymappings
  keys = {
    ["<leader>Tt"] = "toggle", -- Toggle todo item
    ["<leader>Tn"] = "create", -- Create todo item
  },
  default_list_marker = "-",
  todo_markers = {
    unchecked = "□",
    checked = "✔",
  },
  style = {
    list_marker = { fg = "#888888" },
    unchecked = { fg = "#ff9500", bold = true },
    unchecked_content = { fg = "#ffffff" },
    checked = { fg = "#00cc66", bold = true },
    checked_content = { fg = "#aaaaaa", strikethrough = true },
  },
}

-- Mark as not loaded initially
vim.g.loaded_checkmate = false

-- Combine all defaults
local defaults = vim.tbl_deep_extend("force", _DEFAULTS, {})

-- Runtime state
M._running = false

-- The active configuration
---@type checkmate.Config
---@diagnostic disable-next-line: missing-fields
M.options = {}

-- Validate user provided options
local function validate_options(opts)
  if opts == nil then
    return true
  end
  if type(opts) ~= "table" then
    error("Checkmate configuration must be a table")
    return false
  end

  return true
end

-- Initialize plugin if needed
function M.initialize_if_needed()
  if vim.g.loaded_checkmate then
    return
  end

  -- Merge defaults with any global user configuration
  M.options = vim.tbl_deep_extend("force", defaults, vim.g.checkmate_config or {})

  -- Mark as loaded
  vim.g.loaded_checkmate = true

  -- Auto-start if enabled
  if M.options.enabled then
    M.start()
  end
end

--- Setup function
---@param opts? checkmate.Config
function M.setup(opts)
  opts = opts or {}
  if not validate_options(opts) then
    return M.options
  end

  -- Initialize if this is the first call
  if not vim.g.loaded_checkmate then
    M.initialize_if_needed()
  end

  -- Update configuration with provided options
  M.options = vim.tbl_deep_extend("force", M.options, opts)

  M.start()

  return M.options
end

function M.is_loaded()
  return vim.g.loaded_checkmate
end
function M.is_running()
  return M._running
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

  require("checkmate.log").shutdown()

  -- Cleanup resources
  vim.api.nvim_del_augroup_by_name("checkmate")
end

-- Initialize on module load
M.initialize_if_needed()

return M
