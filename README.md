# Slimline

A small Neovim statusline combining a buffer list

<img width="749" height="29" alt="image" src="https://github.com/user-attachments/assets/52e83d6f-7c4e-4d95-8034-7d03e95dc941" />

## Features

- Global statusline with tab styled buffer list
- File icons
- Git branch
- Diagnostics
- Cursor line
- File progress
- Pin buffers
- Macro recording indicator

## Requirements

- Neovim 0.10 or newer.
- Git for branch information (optional).
- A Nerd Font for the Git icon and optional file icons.

Optional plugins:

- `nvim-tree/nvim-web-devicons` for colored file icons.

Buffers close using Neovim's built-in deletion API without forcing unsaved changes.

## Installation

### lazy.nvim

```lua
{
  "bitterhalt/nvim.slimline",
  main = "slimline",
  lazy = false,
  opts = {},
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- optional
  },
},
```

### Other plugin managers

Add this repository to Neovim's runtime path with your plugin manager, then call:

```lua
require("slimline").setup()
```

Setup enables the global statusline (`laststatus=3`) and hides the tabline
(`showtabline=0`). Disable other statusline/bufferline plugins to avoid conflicts.

## Configuration

Defaults below; pass only what you want to change in lazy.nvim's `opts` or
`require("slimline").setup({...})`:

```lua
{
  icons = true,
  encoding = { enabled = true },
  recording = { icon = "REC" },
  mode = {
    enabled = true,
    labels = {}, -- Neovim mode codes, e.g. { n = "NORMAL", i = "INSERT" }
  },
  buffers = {
    enabled = true,
    max_name_length = 15, -- follows min_width when omitted
    min_width = 15, -- fixed buffer slot width (columns)
    close_icon = "×", -- empty string hides the close button
    modified_icon = "*",
    exclude_filetypes = {}, -- e.g. { "qf", "help" }
    exclude_buftypes = {}, -- e.g. { "terminal" }
  },
  diagnostics = { enabled = true, error = "E!", warn = "W!" },
  git = { enabled = true, icon = "", max_length = 24 },
  cursor = { enabled = true, separator = " | ", progress = true },
  highlights = {},
}
```

```lua
highlights = {
  SlimlineActive = { bold = false },
  SlimlineGit = { fg = "#aabbcc" },
}
```

Groups: `SlimlineBase`, `SlimlineText`, `SlimlineActive`, `SlimlineClose`,
`SlimlineModified`, `SlimlineError`,
`SlimlineWarning`, `SlimlineGit`, `SlimlineRecording`, `SlimlineSingle`,
and `SlimlineModeNormal`, `SlimlineModeInsert`,
`SlimlineModeVisual`, `SlimlineModeReplace`, `SlimlineModeCommand`,
`SlimlineModeTerminal`.

## Pinning

Pinned buffers stay in a separate left-hand area and show a red `` matching the
error color. Unpinned buffers scroll independently. If pins exceed the available
width, the pinned area shows its own overflow counts.
Pins are buffer-local and last for the current session. Filtering still
applies; cycling wraps through visible-list eligible pinned buffers.

Example lazy.nvim bindings:

```lua
keys = {
  { "<leader>bp", function() require("slimline").toggle_pin() end, desc = "Toggle buffer pin" },
  { "<leader>bn", function() require("slimline").next_pin() end, desc = "Next pinned buffer" },
},
```

## Tests

From the repository root:

```sh
nvim --headless -u NONE -l tests/slimline.lua
```
