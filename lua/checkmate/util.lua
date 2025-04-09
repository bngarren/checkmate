local M = {}

function M.debug_notify(msg)
  local config = require("checkmate.config")
  if config.options.log_level == "debug" then
    vim.notify(msg, vim.log.levels.DEBUG)
  end
end

return M
