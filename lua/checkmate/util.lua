local M = {}

function M.debug_notify(msg)
  local config = require("checkmate.config")
  if config.options.log_level == "debug" then
    vim.notify(msg, vim.log.levels.DEBUG)
  end
end

--- Escapes special characters in a string for safe use in a Lua pattern character class.
--
-- Use this when dynamically constructing a pattern like `[%s]` or `[-+*]`,
-- since characters like `-`, `]`, `^`, and `%` have special meaning inside `[]`.
--
-- Example:
--   escape_for_char_class("-^]") → "%-%^%]"
--
-- @param s string: Input string to escape
-- @return string: Escaped string safe for use inside a Lua character class
local function escape_for_char_class(s)
  if not s or s == "" then
    return ""
  end
  return s:gsub("([%%%^%]%-])", "%%%1")
end

--- Escapes special characters in a string for safe use in a Lua pattern as a literal.
--
-- This allows literal matching of characters like `(`, `[`, `.`, etc.,
-- which otherwise have special meaning in Lua patterns.
--
-- Example:
--   escape_literal(".*[abc]") → "%.%*%[abc%]"
--
-- @param s string: Input string to escape
-- @return string: Escaped string safe for literal matching in Lua patterns
local function escape_literal(s)
  if not s or s == "" then
    return ""
  end
  return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

--- Builds a curried Lua pattern that matches the beginning of a todo-style line.
--
-- This is used for *recognition* (e.g., `line:match(...)`), not replacement.
-- Unlike `build_list_pattern`, it does not include a capture group and only matches
-- lines that start with the list item and a specific todo marker.
--
-- Use this when you want to check if a line *is* a todo item.
-- For replacements (e.g., converting `[x]` to `✔`), use `build_unicode_todo_pattern` or `build_list_pattern`.
--
-- Example:
--   local with_markers = build_todo_pattern("-+*")
--   local pattern = with_markers("✔")
--   -- Matches: "^%s*[-+*]%s+✔"
---@param list_item_markers string | table: Characters used for list items (e.g., "-+*")
---@return function: A function that accepts a todo marker and returns a Lua pattern string
function M.build_todo_pattern(list_item_markers)
  -- If list_item_markers is a table, convert to string
  if type(list_item_markers) == "table" then
    list_item_markers = table.concat(list_item_markers, "")
  end

  local escaped_markers = escape_for_char_class(list_item_markers)

  ---@param todo_marker string: Marker to use, e.g. ✔
  ---@return string: A Lua pattern such as "^%s*[-+*]%s+✔" that matches a todo item with the given marker
  local build_lua_pattern_with_marker = function(todo_marker)
    local escaped_todo = escape_literal(todo_marker)
    return "^%s*[" .. escaped_markers .. "]%s+" .. (escaped_todo or "")
  end
  return build_lua_pattern_with_marker
end

--- Builds a Lua pattern that matches:
--   - Leading whitespace
--   - A list item marker (e.g. "-", "+", "*")
--   - Spacing
--   - Followed by any right-side pattern (e.g. `[x]`, `✔`)
--
-- The leading part is captured so you can preserve it in replacements.
--
-- Example:
--   build_list_pattern({ "-", "+", "*" }, "%[[xX]%]") → (%s*[-+*]%s+)%[[xX]%]
--   build_list_pattern({ "-", "*"}, "✔")             → (%s*[-*]%s+)✔
--
---@param list_item_markers string | table<string>: List of marker characters
---@param right_pattern? string: A Lua pattern for what follows the marker (escaped if literal)
---@return string: A Lua pattern with a capture group
local function build_list_pattern(list_item_markers, right_pattern)
  -- Default value if nil
  if not list_item_markers then
    list_item_markers = { "-", "+", "*" }
  end

  local markers_string
  if type(list_item_markers) == "table" then
    if #list_item_markers == 0 then
      markers_string = "-+*" -- Default if empty table
    else
      markers_string = table.concat(list_item_markers, "")
    end
  elseif type(list_item_markers) == "string" then
    markers_string = list_item_markers
  else
    error("list_item_markers must be a table or string")
  end

  local escaped_markers = escape_for_char_class(markers_string)
  return "(%s*[" .. escaped_markers .. "]%s+)" .. (right_pattern or "")
end

--- Builds a pattern to match `- ` or `* ` depending on the list_item_markers
function M.build_empty_list_pattern(list_item_markers)
  return build_list_pattern(list_item_markers)
end

--- Builds a pattern to match a Unicode todo item like `- ✔`
function M.build_unicode_todo_pattern(list_item_markers, todo_marker)
  return build_list_pattern(list_item_markers, escape_literal(todo_marker))
end

--- Builds a pattern to match a Markdown checkbox like `- [x]`
---@param list_item_markers table List item markers to use, e.g. {"-", "*", "+"}
---@param checkbox_pattern string Must be a Lua pattern, e.g. "%[[xX]%]"
function M.build_markdown_checkbox_pattern(list_item_markers, checkbox_pattern)
  if not checkbox_pattern or checkbox_pattern == "" then
    error("checkbox_pattern cannot be nil or empty")
  end

  -- Basic validation that it looks like a Lua pattern
  if not checkbox_pattern:match("%%") then
    -- This is a common mistake - user might have passed a literal string
    vim.notify("Warning: checkbox_pattern doesn't appear to be a Lua pattern", vim.log.levels.WARN)
  end
  -- Do not escape checkbox_pattern: it's already a Lua pattern like "%[[xX]%]"
  return build_list_pattern(list_item_markers, checkbox_pattern)
end

return M
