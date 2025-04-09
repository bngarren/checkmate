-- A structured logging module for Checkmate
local Config = require("checkmate.config")

local M = {}

-- Log levels
M.levels = {
  TRACE = 1,
  DEBUG = 2,
  INFO = 3,
  WARN = 4,
  ERROR = 5,
  OFF = 6,
}

-- Maps string level names to numeric values
local level_map = {
  trace = M.levels.TRACE,
  debug = M.levels.DEBUG,
  info = M.levels.INFO,
  warn = M.levels.WARN,
  error = M.levels.ERROR,
  off = M.levels.OFF,
}

-- Log buffer management
local log_buffer = nil
local log_window = nil
local log_file = nil

-- Determine the plugin root directory and create log path
local function get_log_file_path()
  -- Get the directory of the current file (log.lua)
  local info = debug.getinfo(1, "S")

  -- Determine OS separator
  local os_sep = vim.fn.has("win32") == 1 and "\\" or "/"

  -- Extract source path and convert to absolute path
  local source = string.sub(info.source, 2) -- Remove the '@' prefix

  -- Get plugin root directory (parent of parent of current file)
  local plugin_dir = vim.fn.fnamemodify(source, ":h:h:p")

  -- Create logs directory if it doesn't exist
  local logs_dir = plugin_dir .. os_sep .. "logs"
  if vim.fn.isdirectory(logs_dir) == 0 then
    vim.fn.mkdir(logs_dir, "p")
  end

  -- Create log file path with timestamp
  local timestamp = os.date("%Y%m%d")
  local log_path = logs_dir .. os_sep .. "checkmate_" .. timestamp .. ".log"

  return log_path
end

-- Initializes the log buffer if it doesn't exist
local function ensure_log_buffer()
  if log_buffer and vim.api.nvim_buf_is_valid(log_buffer) then
    return log_buffer
  end

  log_buffer = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = log_buffer })
  vim.api.nvim_set_option_value("filetype", "log", { buf = log_buffer })
  vim.api.nvim_buf_set_name(log_buffer, "Checkmate Debug Log")
  return log_buffer
end

-- Formats a log entry
local function format_log(level, msg, opts)
  opts = opts or {}

  local parts = {
    os.date("%Y-%m-%d %H:%M:%S"),
    string.format("[%5s]", level),
  }

  -- Add module/source information if provided
  if opts.module then
    table.insert(parts, string.format("[%s]", opts.module))
  end

  -- Handle message based on type
  if type(msg) == "table" then
    -- Convert table to a single-line string representation by removing newlines
    -- from vim.inspect output and condensing multiple spaces
    local inspected = vim.inspect(msg)
    inspected = inspected:gsub("\n", " "):gsub("%s+", " ")
    table.insert(parts, inspected)
  else
    -- For non-table values, just add the string representation
    table.insert(parts, tostring(msg))
  end
  return table.concat(parts, " ")
end

-- Main logging function (internal)
local function log(level, level_name, msg, opts)
  -- Get current config options (in case they've changed)
  local options = Config.options
  local current_level = level_map[options.log_level] or M.levels.INFO

  -- Skip if current level is higher than this message's level
  if level < current_level then
    return
  end

  -- Format the log entry
  local formatted = format_log(level_name, msg, opts)

  -- Output to the log buffer
  if options.log_to_buffer then
    local bufnr = ensure_log_buffer()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Append to buffer
    table.insert(lines, formatted)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- Auto-scroll if log window is open
    if log_window and vim.api.nvim_win_is_valid(log_window) then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(log_window, { line_count, 0 })
    end
  end

  -- Output to file
  if options.log_to_file and log_file then
    log_file:write(formatted .. "\n")
    log_file:flush()
  end

  -- Show notifications for warnings and errors if enabled
  if level >= M.levels.WARN and options.notify then
    local notify_level = level == M.levels.WARN and vim.log.levels.WARN or vim.log.levels.ERROR
    vim.notify("Checkmate: " .. msg, notify_level)
  end
end

-- Public logging API
function M.trace(msg, opts)
  log(M.levels.TRACE, "TRACE", msg, opts)
end

function M.debug(msg, opts)
  log(M.levels.DEBUG, "DEBUG", msg, opts)
end

function M.info(msg, opts)
  log(M.levels.INFO, "INFO", msg, opts)
end

function M.warn(msg, opts)
  log(M.levels.WARN, "WARN", msg, opts)
end

function M.error(msg, opts)
  log(M.levels.ERROR, "ERROR", msg, opts)
end

-- Opens the log buffer in a split window
function M.open()
  local bufnr = ensure_log_buffer()

  -- Create a new split window if not already open
  if not log_window or not vim.api.nvim_win_is_valid(log_window) then
    vim.cmd("vsplit")
    log_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(log_window, bufnr)
    vim.api.nvim_set_option_value("wrap", false, { win = log_window })

    -- Scroll to the bottom
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_win_set_cursor(log_window, { line_count, 0 })
  end
end

-- Opens the log file in a new buffer
function M.open_file()
  if log_file then
    vim.cmd("edit " .. get_log_file_path())
  else
    vim.notify("No log file is currently active", vim.log.levels.WARN)
  end
end

-- Closes the log window if open
function M.close()
  if log_window and vim.api.nvim_win_is_valid(log_window) then
    vim.api.nvim_win_close(log_window, true)
    log_window = nil
  end
end

-- Clears the log buffer
function M.clear()
  if log_buffer and vim.api.nvim_buf_is_valid(log_buffer) then
    vim.api.nvim_buf_set_lines(log_buffer, 0, -1, false, {})
  end
end

-- Setup the logger
function M.setup()
  -- Start file logging if configured
  if Config.options.log_to_file then
    local log_file_path = get_log_file_path()
    local ok, file = pcall(io.open, log_file_path, "a")

    if ok then
      log_file = file
      M.info("Log file opened: " .. log_file_path, { module = "logger" })
    else
      M.error("Failed to open log file: " .. log_file_path, { module = "logger" })
    end
  end

  M.info("Checkmate logger initialized", { module = "logger" })
end

-- Clean up when plugin is unloaded
function M.shutdown()
  if log_file then
    log_file:close()
    log_file = nil
  end
end

return M
