local M = {}
local Config = require("checkmate.config")
local util = require("checkmate.util")
local parser = require("checkmate.parser")

function M.setup(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Convert markdown to Unicode
  parser.convert_markdown_to_unicode(bufnr)

  -- Apply highlighting
  parser.apply_adv_highlighting(bufnr)

  -- Enable Treesitter highlighting
  vim.cmd([[TSBufEnable highlight]])

  -- Apply keymappings
  M.setup_keymaps(bufnr)

  -- Set up auto commands for this buffer
  M.setup_autocmds(bufnr)

  -- FIX: DEBUG ONLY
  vim.cmd("Checkmate debug_log")
end

function M.setup_keymaps(bufnr)
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

function M.setup_autocmds(bufnr)
  -- Set up auto-commands for saving and InsertLeave
  local augroup = vim.api.nvim_create_augroup("CheckmateTodoConversion_" .. bufnr, { clear = true })

  -- Before saving, convert Unicode back to markdown
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      local modified = parser.convert_unicode_to_markdown(bufnr)
      -- Store state to know if we need to convert back after save
      vim.b[bufnr].checkmate_was_modified = modified
    end,
  })

  -- After saving, convert markdown back to Unicode if we modified before saving
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      if vim.b[bufnr].checkmate_was_modified then
        parser.convert_markdown_to_unicode(bufnr)
        -- parser.apply_highlighting(bufnr)
        vim.b[bufnr].checkmate_was_modified = false
      end
    end,
  })

  -- When leaving insert mode, detect and convert any manually typed todo items
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      M.convert_manual_todo_items(bufnr)
    end,
  })

  -- Re-apply highlighting when text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      parser.apply_adv_highlighting(bufnr)
    end,
  })
end

-- Function to detect and convert manually typed todo items
function M.convert_manual_todo_items(bufnr)
  local log = require("checkmate.log")
  local config = require("checkmate.config")
  local util = require("checkmate.util")
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get current line
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor_pos[1] - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)

  if #lines == 0 then
    return
  end

  local line = lines[1]

  -- Check if this is a manually typed todo item with markdown syntax
  local modified = false
  local new_line = line

  -- Get the configured todo markers
  local unchecked_marker = config.options.todo_markers.unchecked
  local checked_marker = config.options.todo_markers.checked

  -- Build patterns for markdown checkboxes
  local md_unchecked_pattern = util.build_markdown_checkbox_pattern(parser.list_item_markers, "%[%s%]")
  local md_checked_pattern = util.build_markdown_checkbox_pattern(parser.list_item_markers, "%[[xX]%]")

  -- Convert markdown unchecked to Unicode
  if line:match(md_unchecked_pattern) then
    -- Use the pattern for capture and the config marker for replacement
    new_line = line:gsub(md_unchecked_pattern, "%1" .. unchecked_marker)
    modified = true
    log.debug("Converted manually typed unchecked todo item", { module = "api" })
  -- Convert markdown checked to Unicode
  elseif line:match(md_checked_pattern) then
    new_line = line:gsub(md_checked_pattern, "%1" .. checked_marker)
    modified = true
    log.debug("Converted manually typed checked todo item", { module = "api" })
  end

  if modified then
    vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr + 1, false, { new_line })
    -- Re-apply highlighting after conversion
    parser.apply_highlighting(bufnr)
  end
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

  -- Get the line with the todo marker
  local line_row = todo_item.range.start.row
  local line = vim.api.nvim_buf_get_lines(bufnr, line_row, line_row + 1, false)[1]

  -- Log which item we're toggling
  log.debug(
    string.format("Toggling todo item at line %d: %s", line_row, line) .. string.format(" from %s", todo_item.type),
    { module = "api" }
  )

  -- Toggle between checked and unchecked state
  local new_line

  if todo_item.type == "unchecked" then
    -- Replace □ with ✔
    local unchecked = util.build_unicode_todo_pattern(parser.list_item_markers, Config.options.todo_markers.unchecked)
    new_line = line:gsub(unchecked, "%1" .. Config.options.todo_markers.checked, 1)
  else
    -- Replace ✔ with □
    local checked = util.build_unicode_todo_pattern(parser.list_item_markers, Config.options.todo_markers.checked)
    new_line = line:gsub(checked, "%1" .. Config.options.todo_markers.unchecked, 1)
  end

  if new_line and new_line ~= line then
    vim.api.nvim_buf_set_lines(bufnr, line_row, line_row + 1, false, { new_line })
    log.debug("Successfully toggled todo item", { module = "api" })

    -- Re-apply highlighting after toggle
    parser.apply_highlighting(bufnr)
  else
    log.debug("Failed to toggle todo item, no change made", { module = "api" })
  end

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(0, cursor)
end

-- Create a new todo item from the current line
function M.create_todo()
  local config = require("checkmate.config")
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

  local todo_markers = config.options.todo_markers
  -- Check if line already has a task marker
  if line:match(todo_markers.unchecked) or line:match(todo_markers.checked) then
    return
  end

  -- Extract indentation and list marker if present
  local indent = line:match("^(%s*)") or ""
  local list_marker_pattern = parser.with_default_list_item_markers()
  local has_list_marker = line:match(list_marker_pattern)

  local new_line
  if has_list_marker then
    -- Convert existing list item to task list item with Unicode
    local list_marker_capture = util.build_empty_list_pattern(parser.list_item_markers)
    new_line = line:gsub("^" .. list_marker_capture, "%1" .. config.options.todo_markers.unchecked .. " ")
  else
    -- Create new task list item with Unicode
    new_line = indent .. "- " .. config.options.todo_markers.unchecked .. " " .. line:gsub("^%s*", "")
  end

  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

  -- Place cursor at end of line and enter insert mode
  vim.api.nvim_win_set_cursor(0, { cursor[1], #new_line })
  vim.cmd("startinsert!")
end

return M
