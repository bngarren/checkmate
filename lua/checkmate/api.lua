local M = {}
local Config = require("checkmate.config")
local util = require("checkmate.util")
local parser = require("checkmate.parser")

function M.setup(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  vim.opt_local.conceallevel = 2
  vim.opt_local.concealcursor = "nc" -- Conceal in normal and command mode, but not insert

  -- Enable Treesitter highlighting
  vim.cmd([[TSBufEnable highlight]])

  -- Apply keymappings from config
  local keys = Config.options.keys or {}

  for key, action in pairs(keys) do
    -- Skip if mapping is explicitly disabled with false
    if action == false then
      goto continue
    end

    local cmd
    local desc
    if action == "toggle" then
      cmd = "<cmd>Checkmate toggle<CR>"
      desc = "Toggle todo item"
    elseif action == "create" then
      cmd = "<cmd>Checkmate create<CR>"
      desc = "Create todo item"
    else
      vim.notify(string.format("Checkmate: unknown action '%s' for mapping '%s'", action, key), vim.log.levels.WARN)
      goto continue
    end

    vim.api.nvim_buf_set_keymap(bufnr, "n", key, cmd, {
      noremap = true,
      silent = true,
      desc = desc,
    })

    ::continue::
  end
end

-- Get the markers from config
local function get_markers()
  return Config.options.todo_markers
    or {
      unchecked = {
        primary = "□ ",
        alternate = "[ ] ",
      },
      checked = {
        primary = "✔ ",
        alternate = "[x] ",
      },
    }
end

-- Toggle the todo item under the cursor
function M.toggle_todo()
  local log = require("checkmate.log")
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]

  log.debug(string.format("Toggle called with cursor at row=%d, col=%d", row, col), { module = "api" })

  -- Get todo item at cursor
  local todo_item = parser.get_todo_item_at_position(bufnr, row)

  if not todo_item then
    log.debug("No todo item found at cursor position, aborting toggle", { module = "api" })
    vim.notify("No todo item found at cursor position", vim.log.levels.INFO)
    return
  end

  -- Log which item we're toggling
  log.debug(
    string.format(
      "Toggling todo item at line %d: %s",
      todo_item.range.start.row + 1,
      vim.api.nvim_buf_get_lines(bufnr, todo_item.range.start.row, todo_item.range.start.row + 1, false)[1]
    ),
    { module = "api" }
  )

  -- Find the task marker node within the list item
  local task_marker = nil
  if todo_item.node then
    for i = 0, todo_item.node:named_child_count() - 1 do
      local child = todo_item.node:named_child(i)
      if child and (child:type() == "task_list_marker_checked" or child:type() == "task_list_marker_unchecked") then
        task_marker = child
        break
      end
    end
  end

  if not task_marker then
    log.debug("Could not find task marker node", { module = "api" })
    return
  end

  -- Get the exact position of the task marker
  local start_row, start_col, end_row, end_col = task_marker:range()
  log.debug(
    string.format("Found task marker at [%d,%d]-[%d,%d]", start_row, start_col, end_row, end_col),
    { module = "api" }
  )

  -- Get the line with the task marker
  local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]

  -- Toggle between checked and unchecked state
  local new_line
  if todo_item.type == "unchecked" then
    -- Replace [ ] with [x]
    new_line = line:gsub("%[%s%]", "[x]", 1)
  else
    -- Replace [x] or [X] with [ ]
    new_line = line:gsub("%[[xX]%]", "[ ]", 1)
  end

  if new_line and new_line ~= line then
    vim.api.nvim_buf_set_lines(bufnr, start_row, start_row + 1, false, { new_line })
    log.debug("Successfully toggled todo item", { module = "api" })
  else
    log.debug("Failed to toggle todo item, no change made", { module = "api" })
  end

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(0, cursor)
end

-- Create a new todo item from the current line
function M.create_todo()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

  -- Check if line already has a task marker
  if line:match("%[[ xX]%]") then
    return
  end

  -- Extract indentation and list marker if present
  local indent = line:match("^(%s*)") or ""
  local has_list_marker = line:match("^%s*[-+*]%s")

  local new_line
  if has_list_marker then
    -- Convert existing list item to task list item
    new_line = line:gsub("^(%s*[-+*])%s+", "%1 [ ] ")
  else
    -- Create new task list item
    new_line = indent .. "- [ ] " .. line:gsub("^%s*", "")
  end

  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

  -- Place cursor after the checkbox
  local new_col = #indent + 6 -- "- [ ] " is 6 characters
  vim.api.nvim_win_set_cursor(0, { cursor[1], new_col })
end

return M
