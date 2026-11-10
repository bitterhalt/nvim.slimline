# Slimline

[![CI](https://github.com/bitterhalt/nvim.slimline/actions/workflows/ci.yml/badge.svg)](https://github.com/bitterhalt/nvim.slimline/actions/workflows/ci.yml)

A small Neovim statusline combining a buffer list

## Features

- Global statusline with tab styled buffer list
- File icons
- Git branch
- Diagnostics
- Cursor line
- File progress
- Pin buffers (optionally restored with sessions)
- Macro recording indicator
- Mouse support: click to switch, close button, middle-click to close
- Closing keeps your window layout
- Optional search count
- `:checkhealth slimline` and `:help slimline`

## Screenshots

Tabs combined with status line **(default)**

> <img width="854" height="27" alt="2026-11-02-00-26-29_screenshot" src="https://github.com/user-attachments/assets/c998b3e3-8c78-42d1-abb3-91207b3e12e9" />

Classical look with tabs at top

> <img width="829" height="309" alt="image" src="https://github.com/user-attachments/assets/d117a0e6-88d3-43dc-accb-5250e37b63c8" />

<details>
<summary>Requirements</summary>

- Neovim 0.10 or newer.
- Git for branch information (optional).
- A Nerd Font for the Git icon and optional file icons.

Optional plugins:

- `nvim-tree/nvim-web-devicons` for colored file icons.

Buffers close using Neovim's built-in deletion API without forcing unsaved changes.

</details>

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

## Configuration

Full lazy.nvim spec with default options and example keybindings. Use this
instead of the minimal installation spec above; omit options you do not need to change.

```lua
{
  "bitterhalt/nvim.slimline",
  main = "slimline",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- optional
  },
  keys = {
    {
      "<leader>bt",
      function() require("slimline").toggle_buffers() end,
      desc = "Toggle Slimline buffers",
    },
    {
      "<leader>bp",
      function() require("slimline").toggle_pin() end,
      desc = "Toggle buffer pin",
    },
    {
      "<leader>bn",
      function() require("slimline").next_pin() end,
      desc = "Next pinned buffer",
    },
    { "<S-l>", function() require("slimline").next_buffer() end, desc = "Next buffer" },
    { "<S-h>", function() require("slimline").prev_buffer() end, desc = "Previous buffer" },
    { "<leader>bd", function() require("slimline").close_buffer() end, desc = "Close buffer" },
  },
  opts = {
    icons = true,
    encoding = { enabled = true },
    search = { enabled = false }, -- show current/total while 'hlsearch' is active
    recording = { icon = "REC" },
    mode = {
      enabled = true,
      labels = {}, -- Neovim mode codes, e.g. { n = "NORMAL", i = "INSERT" }
      hide_showmode = true, -- set 'noshowmode' so the mode is not shown twice
    },
    buffers = {
      enabled = true,
      position = "bottom", -- "top" moves the buffer list to the tabline
      max_name_length = 15, -- follows min_width when omitted
      min_width = 15, -- fixed buffer slot width (columns)
      close_icon = "×", -- empty string hides the close button
      modified_icon = "*",
      keep_layout = true, -- switch windows to another buffer first when closing, so splits survive
      persist_pins = false, -- store pins in g:SlimlinePins for sessions (needs "globals" in sessionoptions)
      exclude_filetypes = {}, -- e.g. { "qf", "help" }
      exclude_buftypes = {}, -- e.g. { "terminal" }
    },
    diagnostics = {
      enabled = true,
      error = "\u{ebfb} ",
      warn = "\u{f071} ",
      colors = {}, -- e.g. { error = "#ff5555", warn = "#f1c40f" }
    },
    git = { enabled = true, icon = "", max_length = 24 },
    cursor = { enabled = true, separator = " | ", progress = true, virtual_column = false },
    highlights = {
      -- SlimlineActive = { bold = false },
      -- SlimlineGit = { fg = "#aabbcc" },
    },
  },
},
```

<details>
<summary>Setup and configuration behavior</summary>

- Setup enables the global statusline (`laststatus=3`). By default it hides the
  tabline (`showtabline=0`). Set `buffers.position = "top"` to put buffers in the
  tabline instead; mode, Git, diagnostics, and cursor info remain at the bottom.
  Other statusline/bufferline plugins can overwrite these settings.
- `showmode` is switched off while the mode indicator is shown, so the mode is
  not displayed twice. Set `mode.hide_showmode = false` to keep it.
- Invalid options do not abort startup: the problem is shown with `vim.notify`
  and the defaults are used. If rendering ever fails, Slimline falls back to a
  plain statusline and reports the error once.
- Run `:checkhealth slimline` to diagnose problems, and see `:help slimline`.
- Options are merged with defaults. Each `setup()` call starts from defaults,
  not the previous configuration.
- Component tables use `enabled = false` to hide their section. Recording has
  no toggle: it appears only while recording a macro.
- `require("slimline").toggle_buffers()` toggles the buffer list, including pins,
  without hiding the rest of the statusline. This lasts until the next `setup()`
  call or restart. For example:

  ```lua
  vim.keymap.set("n", "<leader>bt", function()
    require("slimline").toggle_buffers()
  end, { desc = "Toggle Slimline buffers" })
  ```

- `mode.labels` maps Neovim mode codes, not the displayed labels. See `:help mode()`.
- `cursor.separator` is shared by all right-side sections; hidden sections do
  not leave dangling separators.

</details>

<details>
<summary>Buffer layout, icons, and closing</summary>

- The list contains listed buffers, not Neovim tab pages.
- `buffers.min_width` sets a fixed slot width in display columns. Despite its
  name, slots do not stretch to fill free space. Very narrow windows can shrink
  a slot below this width.
- `max_name_length` follows `min_width` unless explicitly set. Icons, padding,
  and markers also occupy the slot, so the visible name may be shorter.
- Duplicate filenames include distinguishing paths; unnamed buffers receive
  buffer numbers when needed. Labels are truncated to fit their slots.
- Hidden-buffer counts appear on either side of the viewport. The current
  listed buffer stays in view when space permits.
- The active buffer is bold cyan, or bold white when it is the only entry.
  Inactive buffers are dimmed. Special/unlisted buffers do not select an entry.
- File icons use devicons colors. Unknown files have no placeholder icon.
  `icons = false` disables file icons, not the Git or pin symbols.
- Left-click a label to switch buffers. Close buttons appear only on unmodified,
  inactive buffers. Modified buffers show the modified marker, green when focused.
- Closing never forces unsaved changes. With `buffers.keep_layout` (default),
  windows showing the buffer are switched to another buffer first, so splits
  survive. With `keep_layout = false`, Neovim's plain deletion closes them.
- Middle-click a label to close it. Close buttons are clickable too.
- The list is cached and rebuilt only when buffers change, not on every redraw.
- Empty `close_icon` or `modified_icon` strings hide the respective marker.
- `exclude_filetypes` and `exclude_buftypes` filter only the list; they do not
  close buffers or disable diagnostics for the current buffer.

</details>

<details>
<summary>Git, diagnostics, encoding, and recording</summary>

- Git shows the current file's branch, or `@` plus a short commit hash for
  detached HEAD. Unnamed buffers use the working directory. It is hidden outside
  repositories and in special buffers.
- Git checks are asynchronous and cached, not run during statusline rendering.
  They refresh on buffer entry/name changes, directory changes, focus gain, and
  leaving terminal mode, shell commands, and the `FugitiveChanged` user event.
- Diagnostics show error and warning counts for the current buffer, hidden at
  zero. Hints and informational diagnostics are omitted. Slimline displays
  diagnostics supplied through Neovim; it does not configure an LSP or linter.
- Encoding uses the current buffer's `fileencoding`, falling back to Neovim's
  `encoding` when empty.
- Macro recording shows `REC @q` beside the mode while recording into register
  `q`. `recording.icon` changes the label; playback does not show this indicator.

</details>

<details>
<summary>Colors and highlight groups</summary>

Most highlights use `g:terminal_color_0` through `g:terminal_color_8` in true-color
mode, falling back to `Normal` colors when undefined. Without true color they
use terminal palette indexes. Transparent `Normal` backgrounds are preserved.

Diagnostics use ANSI red and yellow by default. Override them with
`diagnostics.colors` (`error` and `warn`); pins follow the error color. File icons
use devicons colors. Colors and configured highlight overrides are reapplied
after colorscheme changes.

The `highlights` table accepts Neovim highlight attributes (see `:help nvim_set_hl()`).
Overrides merge with each group's defaults; a `link` replaces the group's attributes.

| Group                  | Purpose                                                      |
| ---------------------- | ------------------------------------------------------------ |
| `SlimlineBase`         | Inactive buffers, filler, and separators                     |
| `SlimlineText`         | Encoding and cursor information                              |
| `SlimlineActive`       | Active buffer with multiple entries                          |
| `SlimlineSingle`       | Active buffer when there is only one entry                   |
| `SlimlineModified`     | Focused buffer's modified marker                             |
| `SlimlineClose`        | Close-button highlight (currently hidden on focused buffers) |
| `SlimlineError`        | Error diagnostics and linked pin color                       |
| `SlimlineWarning`      | Warning diagnostics                                          |
| `SlimlineGit`          | Git branch or commit                                         |
| `SlimlineRecording`    | Macro recording indicator                                    |
| `SlimlinePin`          | Pin symbol; links to `SlimlineError`                         |
| `SlimlineModeNormal`   | Normal mode                                                  |
| `SlimlineModeInsert`   | Insert mode                                                  |
| `SlimlineModeVisual`   | Visual and select modes                                      |
| `SlimlineModeReplace`  | Replace mode                                                 |
| `SlimlineModeCommand`  | Command mode                                                 |
| `SlimlineModeTerminal` | Terminal mode                                                |

`diagnostics.colors` is the simplest way to customize error, warning, and pin
colors. A `SlimlineError` highlight override also changes the pin, since the pin
links to it. `SlimlinePin` can also be overridden on its own through `highlights`. The link is restored by setup and colorscheme refreshes. File-icon
highlight groups are generated internally.

</details>

<details>
<summary>Lua API</summary>

All functions live in `require("slimline")`. No keybindings are installed.

| Function                | Purpose                                                          |
| ----------------------- | ---------------------------------------------------------------- |
| `setup(opts)`           | Enable Slimline                                                  |
| `toggle_buffers()`      | Show or hide the buffer list                                     |
| `toggle_pin()`          | Pin or unpin the current buffer                                  |
| `next_pin()`/`prev_pin()`       | Cycle through pinned buffers, wrapping                    |
| `next_buffer()`/`prev_buffer()` | Cycle through the list, wrapping; respects exclusions     |
| `goto_buffer(n)`        | Jump to the n-th entry (pinned first); `-1` is the last          |
| `close_buffer(buf?)`    | Close a buffer without forcing; honors `keep_layout`             |
| `refresh()`             | Rebuild the list and refresh Git                                 |

```lua
for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, function()
    require("slimline").goto_buffer(i)
  end, { desc = "Buffer " .. i })
end
```

</details>

<details>
<summary>Search count, search and cursor details</summary>

- `search.enabled = true` shows `current/total` while `hlsearch` is active
  (`>999` for very large counts).
- `cursor.virtual_column = true` shows the screen column, so a tab counts as
  its display width, instead of the byte column.

</details>

<details>
<summary>Pinning and keybindings</summary>

Pinned buffers stay in a separate left-hand area and show a red `` matching the
error color. Unpinned buffers scroll independently. If pins exceed the available
width, the pinned area shows its own overflow counts.
Pins are buffer-local and last for the current session unless
`buffers.persist_pins` is set: pinned paths are then stored in `g:SlimlinePins`
and restored by `:mksession` when `sessionoptions` contains `globals`. Filtering still
applies; cycling wraps through eligible pinned buffers, including ones hidden by
overflow. New pins sort with the other pinned buffers in buffer-number order.
Pinning does not protect a buffer from deletion. No keybindings are installed by default.

Example lazy.nvim bindings:

```lua
keys = {
  { "<leader>bp", function() require("slimline").toggle_pin() end, desc = "Toggle buffer pin" },
  { "<leader>bn", function() require("slimline").next_pin() end, desc = "Next pinned buffer" },
},
```

</details>

<details>
<summary>Development</summary>

Tests need no framework and run on Neovim 0.10 or newer:

```sh
nvim --headless -l tests/slimline.lua
```

Code style is enforced with [StyLua](https://github.com/JohnnyMorganz/StyLua)
(`stylua lua tests`). CI runs both on Neovim 0.10, stable and nightly.

Layout: `config` (options, validation), `colors` (highlight groups), `buffers`
(list cache, pins, navigation, closing), `render` (statusline and tabline),
`git` (async branch lookup), `health`, and `init` (public API and autocmds).
See [CHANGELOG.md](CHANGELOG.md).

</details>

<details>
<summary>License</summary>

[MIT](LICENSE), copyright 2026 bitterhalt.

</details>
