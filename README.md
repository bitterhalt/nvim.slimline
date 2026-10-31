# Slimline

A small Neovim statusline combining a buffer list with mode, Git branch,
diagnostics, and cursor position. Intended as a minimal replacement for
bufferline and lualine.

<img width="749" height="29" alt="image" src="https://github.com/user-attachments/assets/52e83d6f-7c4e-4d95-8034-7d03e95dc941" />

## Features

- Global statusline with clickable buffers and close buttons.
- Active buffer uses the editor background; inactive buffers are dimmed.
- File icons, modified markers, and distinguishing paths for duplicate filenames.
- Hidden-buffer counts and a width-aware buffer viewport.
- Mode indicator using terminal palette colors.
- Git branch or detached HEAD commit, checked asynchronously.
- Current-buffer errors (`E!`) and warnings (`W!`), hidden when zero.
- Cursor line, column, and file progress.
- Colors refreshed when the colorscheme changes; transparent backgrounds supported.

## Requirements

- Neovim 0.10 or newer.
- Git for branch information (optional).
- A Nerd Font for the Git icon and optional file icons.

Optional plugins:

- `nvim-tree/nvim-web-devicons` for file icons.
- `famiu/bufdelete.nvim` for closing buffers without disrupting window layout.
  Without it, Slimline uses Neovim's buffer deletion API. Neither path forces
  deletion of unsaved changes.

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
    "famiu/bufdelete.nvim", -- optional
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
There are no configuration options yet.

With true color enabled, highlights use `g:terminal_color_0` through
`g:terminal_color_8`, falling back to `Normal` colors where undefined. Without
true color, highlights use ANSI palette indexes directly.

## Tests

From the repository root:

```sh
nvim --headless -u NONE -l tests/slimline.lua
```
