# Slimline

A small Neovim statusline combining a buffer list

<img width="749" height="29" alt="image" src="https://github.com/user-attachments/assets/52e83d6f-7c4e-4d95-8034-7d03e95dc941" />

## Features

- Global statusline with clickable buffers and close buttons.
- File icons, modified markers, and distinguishing paths for duplicate filenames.
- Git branch
- Diagnostics
- Cursor line and file progress.
- Encoding 
- Macro recording indicator

## Requirements

- Neovim 0.10 or newer.
- Git for branch information (optional).
- A Nerd Font for the Git icon and optional file icons.

Optional plugins:

- `nvim-tree/nvim-web-devicons` for file icons.

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
    max_name_length = 20,
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

Duplicate filenames retain their distinguishing paths even when longer than
`max_name_length`. Filters affect the buffer list only.

`cursor.separator` is shared by all right-side sections. Recording is shown only
while recording a macro; `recording.icon` customizes its label.

Highlight overrides use Neovim highlight attributes and are reapplied after
colorscheme changes:

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

With true color enabled, highlights use `g:terminal_color_0` through
`g:terminal_color_8`, falling back to `Normal` colors where undefined. Without
true color, highlights use ANSI palette indexes directly.

## Tests

From the repository root:

```sh
nvim --headless -u NONE -l tests/slimline.lua
```
