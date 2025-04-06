---@class CustomModule
local M = {}

function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
end

return M
