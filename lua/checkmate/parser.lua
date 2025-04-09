local M = {}

-- Setup Treesitter queries for todo items
M.setup = function()
  local todo_query = [[
; Capture task list markers with concealment
((task_list_marker_unchecked) @todo_marker_unchecked
  (#set! conceal "□"))

((task_list_marker_checked) @todo_marker_checked
  (#set! conceal "✔"))

; Capture the full list items containing task markers
((list_item
  (task_list_marker_unchecked)) @todo_item_unchecked)

((list_item
  (task_list_marker_checked)) @todo_item_checked)

; Capture paragraphs and other content inside task list items
((list_item
  (task_list_marker_unchecked)
  (paragraph) @todo_content_unchecked))

((list_item
  (task_list_marker_checked)
  (paragraph) @todo_content_checked))

; Capture block quotes and other nested blocks in task items
((block_quote) @todo_block
  (#has-ancestor? @todo_block todo_item_unchecked))

((block_quote) @todo_block
  (#has-ancestor? @todo_block todo_item_checked))

; Capture list markers for structure understanding
((list_marker_minus) @list_marker)
((list_marker_plus) @list_marker)
((list_marker_star) @list_marker)
]]

  -- Register the query for highlighting
  vim.treesitter.query.set("markdown", "highlights", todo_query)

  -- Register the query
  vim.treesitter.query.set("markdown", "todo_items", todo_query)

  -- Define highlight groups for todo syntax using Treesitter captures
  local highlights = {
    ["@todo_marker_unchecked"] = { fg = "#ff9500", bold = true }, -- Orange for unchecked
    ["@todo_marker_checked"] = { fg = "#00cc66", bold = true }, -- Green for checked
    ["@todo_content_unchecked"] = { fg = "#ffffff" }, -- White for unchecked content
    ["@todo_content_checked"] = { fg = "#aaaaaa", strikethrough = true }, -- Gray with strikethrough for checked
    ["@list_marker"] = { fg = "#eeeeee", blend = 50 },
    ["Conceal"] = { link = "@todo_marker_unchecked" }, -- Default link for Conceal
  }

  -- Apply highlight groups
  for group_name, group_settings in pairs(highlights) do
    vim.api.nvim_set_hl(0, group_name, group_settings)
  end
end

-- Function to get todo items from the current buffer using TS
M.get_todo_items = function(bufnr)
  local log = require("checkmate.log")
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local items = {}

  -- Return empty if TS not available
  if not pcall(require, "nvim-treesitter") then
    return items
  end

  -- Get parser for the buffer
  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    return items
  end

  -- Get syntax tree
  local tree = parser:parse()[1]
  if not tree then
    return items
  end

  -- Query for todo items
  local query = vim.treesitter.query.get("markdown", "todo_items")
  if not query then
    return items
  end

  -- Track nodes by their ID to build relationships
  local node_map = {}
  local todo_items = {}

  -- First pass: collect nodes and basic metadata
  for id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id]
    local node_id = tostring(node:id())

    -- Store basic node info
    if not node_map[node_id] then
      local start_row, start_col, end_row, end_col = node:range()
      node_map[node_id] = {
        node = node,
        type = name,
        range = { start_row, start_col, end_row, end_col },
        children = {},
      }
      -- log.debug("New node: " .. name .. " at " .. start_row .. ":" .. start_col, { module = "parser" })
    end

    -- Track relationships between nodes
    if name == "todo_item_unchecked" or name == "todo_item_checked" then
      table.insert(todo_items, node_id)
    elseif name:match("todo_content") then
      -- Find parent todo item
      local parent = node:parent()
      while parent do
        local parent_id = tostring(parent:id())
        if
          node_map[parent_id]
          and (node_map[parent_id].type == "todo_item_unchecked" or node_map[parent_id].type == "todo_item_checked")
        then
          table.insert(node_map[parent_id].children, node_id)
          break
        end
        parent = parent:parent()
      end
    end
  end

  -- Second pass: build final todo items
  local result = {}
  for _, item_id in ipairs(todo_items) do
    local item_data = node_map[item_id]
    if item_data then
      local start_row, start_col, end_row, end_col =
        item_data.range[1], item_data.range[2], item_data.range[3], item_data.range[4]

      -- Get text using a safer approach
      local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
      local text = table.concat(lines, "\n")

      -- Determine type (checked/unchecked)
      local item_type = item_data.type == "todo_item_checked" and "checked" or "unchecked"

      -- Extract content
      local content = M.extract_todo_content(bufnr, item_data, node_map)

      -- Build the todo item
      local todo_item = {
        type = item_type,
        range = {
          start = { row = start_row, col = start_col },
          ["end"] = { row = end_row, col = end_col },
        },
        text = text,
        raw_content = content,
        node_id = item_id,
      }

      table.insert(result, todo_item)
    end
  end

  return result
end

-- Extract content from todo item, handling nested structures
M.extract_todo_content = function(bufnr, item_data, node_map)
  local start_row, start_col, end_row, end_col =
    item_data.range[1], item_data.range[2], item_data.range[3], item_data.range[4]

  -- Get all lines in the item's range
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  if #lines == 0 then
    return ""
  end

  -- Process first line to remove markers
  local first_line = lines[1]
  -- Remove list marker and task marker
  first_line = first_line:gsub("^%s*[-+*]%s+%[[ xX]%]%s+", "")
  lines[1] = first_line

  return table.concat(lines, "\n")
end

-- Function to find a todo item at cursor position
M.get_todo_item_at_position = function(bufnr, row, col)
  local log = require("checkmate.log")
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- Note that nvim_win_get_cursor uses a 1-index for rows and 0-index for columns
  row = row or vim.api.nvim_win_get_cursor(0)[1] - 1
  col = col or vim.api.nvim_win_get_cursor(0)[2]

  log.debug(string.format("Looking for todo item at position [%d,%d]", row, col), { module = "parser" })

  -- Get parser for the buffer
  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    return nil
  end

  -- Get syntax tree
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

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
  end

  -- Check if this line contains a task list marker
  local marker_pattern = "^%s*[-+*]%s+%[[ xX]%]"
  if line_text:match(marker_pattern) then
    -- Find the position of the task marker
    local _, marker_end = line_text:find("^%s*[-+*]%s+%[[ xX]%]")

    -- If cursor is before the task marker, adjust column
    if marker_end and col < marker_end then
      col = marker_end
      log.debug(
        string.format("Adjusted column to %d to ensure we detect the todo on this line", col),
        { module = "parser" }
      )
    end
  end

  -- Find the smallest node at cursor position
  local root = tree:root()
  local node_at_cursor = root:named_descendant_for_range(row, col, row, col)

  if not node_at_cursor then
    log.debug("No node found at cursor position", { module = "parser" })
    return nil
  end

  log.debug("Node at cursor: " .. node_at_cursor:type(), { module = "parser" })

  -- Special case: if we're on a blank line (block_continuation), don't match
  if is_blank_line or node_at_cursor:type() == "block_continuation" then
    log.debug("Cursor is on a blank line, not matching any todo item", { module = "parser" })
    return nil
  end

  -- Walk up the tree to find a list_item that contains a task marker
  ---@type TSNode | nil
  local current_node = node_at_cursor
  while current_node do
    log.debug(current_node:type())
    -- Check if this is a list_item node
    if current_node:type() == "list_item" then
      -- Check if it has a task marker child
      local has_task_marker = false
      local is_checked = false
      local task_marker_node = nil

      for child_idx = 0, current_node:named_child_count() - 1 do
        local child = current_node:named_child(child_idx)
        if child and (child:type() == "task_list_marker_checked" or child:type() == "task_list_marker_unchecked") then
          has_task_marker = true
          is_checked = child:type() == "task_list_marker_checked"
          task_marker_node = child
          break
        end
      end

      if has_task_marker then
        -- Found a list item with a task marker
        local start_row, start_col, end_row, end_col = current_node:range()
        log.debug(
          string.format("Found todo list_item node at [%d,%d]-[%d,%d]", start_row, start_col, end_row, end_col),
          { module = "parser" }
        )

        -- Build and return the todo item
        return {
          type = is_checked and "checked" or "unchecked",
          range = {
            start = { row = start_row, col = start_col },
            ["end"] = { row = end_row, col = end_col },
          },
          node_id = tostring(current_node:id()),
          node = current_node,
          marker_node = task_marker_node,
        }
      end
    end

    -- Move up to parent
    current_node = current_node:parent()
  end

  log.debug("No todo list item found containing cursor position", { module = "parser" })
  return nil
end

return M
