<div align="center">

# checkmate.nvim

### A simple Todo plugin

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

<img alt="Checkmate Mate" height="220" src="./assets/checkmate-logo.png" />
</div>

Inspired by the [Todo+](https://github.com/fabiospampinato/vscode-todo-plus) VS Code extension (credit to @[fabiospampinato](https://github.com/fabiospampinato))

- Stored as plain text/Markdown format
- Custom symbols
- Custom colors

# ☑️ Installation

- install using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "bngarren/checkmate.nvim",
    opts = {
        -- your configuration here
        -- or leave empty to use defaults
    },

    }
}
```

# ☑️ Usage

#### 1. Open a `.todo` file or create a new one

As of now, the plugin is only activated when a buffer with `.todo` extension is opened.

#### 2. Create todo items!

- Use mapped keys or commands

or

- Create them manually using typical Markdown format:

```md
- [ ] Unchecked todo
- [x] Checked todo
```
These will automatically convert when you leave insert mode!

# ☑️ Commands

:Checkmate toggle
: Toggle the todo item under the cursor

    ```vimdoc
    :Checkmate toggle
    ```

:Checkmate create
: Convert the current line to a todo item

# ☑️ Config

enabled
: Default: true

notify
: Whether to use notifications

    Default: true

## log

level
: Any messages above this level will be logged
"debug" | "trace" | "info" | "warn" | "error" | "fatal"

Default: "info"

use_buffer

