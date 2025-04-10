local M = {}

M.list_item_markers = { "-", "+", "*" }
M.with_default_list_item_markers = require("checkmate.util").build_todo_pattern(M.list_item_markers)
M.getCheckedTodoPattern = function()
  return M.with_default_list_item_markers(require("checkmate.config").options.todo_markers.checked)
end
M.getUncheckedTodoPattern = function()
  return M.with_default_list_item_markers(require("checkmate.config").options.todo_markers.unchecked)
end
--- Given a line (string), returns the todo item type either "checked" or "unchecked"
--- Returns nil if no todo item was found on the line
---@param line any
---@return string|nil
M.getTodoItemType = function(line)
  local todo_type = nil
  if line:match(M.getUncheckedTodoPattern()) then
    todo_type = "unchecked"
  elseif line:match(M.getCheckedTodoPattern()) then
    todo_type = "checked"
  end
  return todo_type
end

-- Setup Treesitter queries for todo items
M.setup = function()
  local todo_query = [[
; Capture list items and their content for structure understanding
(list_item) @list_item
(paragraph) @paragraph

; Capture list markers for structure understanding
((list_marker_minus) @list_marker_minus)
((list_marker_plus) @list_marker_plus)
((list_marker_star) @list_marker_star)
]]

  local log = require("checkmate.log")
  log.debug("Checked pattern is: " .. M.getCheckedTodoPattern())
  log.debug("Unchecked pattern is: " .. M.getUncheckedTodoPattern())

  -- Register the query
  vim.treesitter.query.set("markdown", "todo_items", todo_query)

  -- Define highlight groups for Unicode todo markers
  local highlights = {
    CheckmateUnchecked = { fg = "#ff9500", bold = true }, -- Orange for unchecked
    CheckmateChecked = { fg = "#00cc66", bold = true }, -- Green for checked
    CheckmateUncheckedContent = { fg = "#ffffff" }, -- White for unchecked content
    CheckmateCheckedContent = { fg = "#aaaaaa", strikethrough = true }, -- Gray with strikethrough for checked
    CheckmateListMarker = { fg = "#eeeeee", blend = 50 },
  }

  -- Apply highlight groups
  for group_name, group_settings in pairs(highlights) do
    vim.api.nvim_set_hl(0, group_name, group_settings)
  end
end

-- Convert standard markdown 'task list marker' syntax to Unicode symbols
M.convert_markdown_to_unicode = function(bufnr)
  local log = require("checkmate.log")
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local modified = false

  local util = require("checkmate.util")
  local config = require("checkmate.config")

  local unchecked_pattern = util.build_markdown_checkbox_pattern(M.list_item_markers, "%[%s%]")
  local checked_pattern = util.build_markdown_checkbox_pattern(M.list_item_markers, "%[[xX]%]")
  local unchecked = config.options.todo_markers.unchecked
  local checked = config.options.todo_markers.checked

  -- Replace markdown syntax with Unicode
  for i, line in ipairs(lines) do
    -- Match the todo markers and replace them
    local new_line = line:gsub(unchecked_pattern, "%1" .. unchecked):gsub(checked_pattern, "%1" .. checked)

    if new_line ~= line then
      lines[i] = new_line
      modified = true
    end
  end

  -- Update buffer if changes were made
  if modified then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    log.debug("Converted markdown todo syntax to Unicode", { module = "parser" })
  end
end

-- Convert Unicode symbols back to standard markdown 'task list marker' syntax
M.convert_unicode_to_markdown = function(bufnr)
  local log = require("checkmate.log")
  local config = require("checkmate.config")
  local util = require("checkmate.util")
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local modified = false

  local unchecked = config.options.todo_markers.unchecked
  local checked = config.options.todo_markers.checked
  local unchecked_pattern = util.build_unicode_todo_pattern(M.list_item_markers, unchecked)
  local checked_pattern = util.build_unicode_todo_pattern(M.list_item_markers, checked)

  -- Replace Unicode with markdown syntax
  for i, line in ipairs(lines) do
    -- Match the Unicode markers and replace them
    local new_line = line:gsub(unchecked_pattern, "%1[ ]"):gsub(checked_pattern, "%1[x]")

    if new_line ~= line then
      lines[i] = new_line
      modified = true
    end
  end

  -- Update buffer if changes were made
  if modified then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    log.debug("Converted Unicode todo symbols to markdown syntax", { module = "parser" })
    return true
  end

  return false
end

-- Apply custom highlighting for Unicode todo markers
M.apply_highlighting = function(bufnr)
  local config = require("checkmate.config")
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Set up matches for the Unicode markers
  local list_markers_pattern = "[" .. table.concat(M.list_item_markers, "") .. "]"
  local unchecked = vim.fn.escape(config.options.todo_markers.unchecked, "/\\")
  local checked = vim.fn.escape(config.options.todo_markers.checked, "/\\")

  vim.cmd(
    string.format(
      [[
  syntax match CheckmateListMarker /\v^\s*%s/ contained
  syntax match CheckmateUnchecked /\v^\s*%s\s+%s/ contains=CheckmateListMarker
  syntax match CheckmateChecked /\v^\s*%s\s+%s/ contains=CheckmateListMarker
  syntax match CheckmateUncheckedContent /\v^\s*%s\s+%s\s+.*/ contains=CheckmateUnchecked
  syntax match CheckmateCheckedContent /\v^\s*%s\s+%s\s+.*/ contains=CheckmateChecked
]],
      list_markers_pattern,
      list_markers_pattern,
      unchecked,
      list_markers_pattern,
      checked,
      list_markers_pattern,
      unchecked,
      list_markers_pattern,
      checked
    )
  )
end

-- Function to find a todo item at cursor position
M.get_todo_item_at_position = function(bufnr, row, col)
  local log = require("checkmate.log")
  local util = require("checkmate.util")

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- Note that nvim_win_get_cursor uses a 1-index for rows and 0-index for columns
  -- Treesitter uses a 0 index, so we normalize to this
  row = row or vim.api.nvim_win_get_cursor(0)[1] - 1
  col = col or vim.api.nvim_win_get_cursor(0)[2]

  log.debug(string.format("Looking for todo item at position [%d,%d]", row, col), { module = "parser" })

  -- Get the current line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  local line_text = ""
  if #lines > 0 then
    line_text = lines[1]
  end

  -- Debug the line content
  log.debug("line_text is: '" .. line_text .. "'", { module = "parser" })
  local is_blank_line = line_text:match("^%s*$") ~= nil

  if is_blank_line then
    log.debug("Line is blank", { module = "parser" })
    return nil
  end

  local config = require("checkmate.config")
  local unchecked = config.options.todo_markers.unchecked
  local checked = config.options.todo_markers.checked
  local unchecked_pattern = M.with_default_list_item_markers(unchecked)
  local checked_pattern = M.with_default_list_item_markers(checked)

  -- Check for todo markers on current line and get marker position
  local todo_type = nil
  local marker_col = nil
  local marker_match = line_text:match(unchecked_pattern)

  if marker_match then
    todo_type = "unchecked"
    marker_col = line_text:find(unchecked, 1, true)
  else
    marker_match = line_text:match(checked_pattern)
    if marker_match then
      todo_type = "checked"
      marker_col = line_text:find(checked, 1, true)
    end
  end

  -- Use Treesitter to get node information
  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    log.debug("No parser available for markdown", { module = "parser" })
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    log.debug("Failed to parse buffer", { module = "parser" })
    return nil
  end

  local root = tree:root()
  local node_at_cursor

  -- If a todo marker was found, adjust the column to the marker position
  if marker_col and marker_col > 0 then
    log.debug(string.format("Found marker at column %d", marker_col), { module = "parser" })
    node_at_cursor = root:named_descendant_for_range(row, marker_col, row, marker_col)
  else
    -- Use current cursor position
    node_at_cursor = root:named_descendant_for_range(row, col, row, col)
  end

  if not node_at_cursor then
    log.debug("No node found at cursor position", { module = "parser" })
    return nil
  end

  -- Walk up the tree to find the list_item node
  ---@type TSNode | nil
  local current_node = node_at_cursor

  while current_node do
    log.debug("current_node: " .. current_node:type(), { module = "parser" })
    if current_node:type() == "list_item" then
      -- We found the list_item node
      local start_row, start_col, end_row, end_col = current_node:range()
      -- Read the line containing the list_item so we can get the todo marker and type
      local item_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""

      log.debug(
        string.format("Found list_item node at [%d,%d]-[%d,%d]", start_row, start_col, end_row, end_col),
        { module = "parser" }
      )

      -- Return the node info with todo type if available
      return {
        type = M.getTodoItemType(item_line), -- This will be nil if no todo marker was found
        range = {
          start = { row = start_row, col = start_col },
          ["end"] = { row = end_row, col = end_col },
        },
        node = current_node,
      }
    end
    current_node = current_node:parent()
  end

  -- If we found a todo marker but no list_item node, return fallback
  if todo_type then
    log.warn("Found todo marker but no list_item node, using fallback", { module = "parser" })
    return {
      type = todo_type,
      range = {
        start = { row = row, col = 0 },
        ["end"] = { row = row, col = #line_text },
      },
    }
  end

  log.debug("No todo item or list node found", { module = "parser" })
  return nil
end

return M
