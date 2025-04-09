local Config = require("checkmate.config")
local Api = require("checkmate.api")

---@class CheckmateCommand
---@field desc string Command description
---@field func fun() Function to execute

local M = {}

---@type table<string, CheckmateCommand>
M.commands = {}

--- Runs a command from available commands
---@param cmd string
function M.cmd(cmd)
  if M.commands[cmd] then
    M.commands[cmd].func()
  else
    -- Defaults to toggle command if no command is matched
    M.commands.toggle.func()
  end
end

function M.setup()
  M.commands = {
    toggle = {
      desc = "Toggle todo item between checked and unchecked",
      func = function()
        Api.toggle_todo()
      end,
    },
    create = {
      desc = "Create a new todo item from the current line",
      func = function()
        Api.create_todo()
      end,
    },
    debug_log = {
      desc = "Open the debug log",
      func = function()
        require("checkmate.log").open()
      end,
    },
    debug_file = {
      desc = "Open the debug log file",
      func = function()
        require("checkmate.log").open_file()
      end,
    },
    debug_clear = {
      desc = "Clear the debug log",
      func = function()
        require("checkmate.log").clear()
      end,
    },
  }
end

-- Build out the top level Checkmate command with completions for subcommands
vim.api.nvim_create_user_command("Checkmate", function(args)
  local cmd = vim.trim(args.args or "")
  M.cmd(cmd)
end, {
  nargs = 1, -- require 1 argument
  desc = "Checkmate - Todo list manager",
  complete = function(_, line)
    -- Check if we already have a complete subcommand
    -- If line contains a space after the subcommand, don't provide completions
    if line:match("^%s*Checkmate%s+%w+%s+") then
      return {}
    end
    local prefix = line:match("^%s*Checkmate%s+(%w*)") or ""
    return vim.tbl_filter(function(key)
      return key:find(prefix) == 1
    end, vim.tbl_keys(M.commands))
  end,
})

return M
