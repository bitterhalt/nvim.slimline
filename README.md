# Slimline

A small Neovim statusline combining a buffer list

## Features

- Global statusline with tab styled buffer list
- File icons
- Git branch
- Diagnostics
- Cursor line
- File progress
- Pin buffers
- Macro recording indicator

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
  },
  opts = {
    icons = true,
    encoding = { enabled = true },
    recording = { icon = "REC" },
    mode = {
      enabled = true,
      labels = {}, -- Neovim mode codes, e.g. { n = "NORMAL", i = "INSERT" }
    },
    buffers = {
      enabled = true,
      position = "bottom", -- "top" moves the buffer list to the tabline
      max_name_length = 15, -- follows min_width when omitted
      min_width = 15, -- fixed buffer slot width (columns)
      close_icon = "×", -- empty string hides the close button
      modified_icon = "*",
      exclude_filetypes = {}, -- e.g. { "qf", "help" }
      exclude_buftypes = {}, -- e.g. { "terminal" }
    },
    diagnostics = {
      enabled = true,
      error = "E!",
      warn = "W!",
      colors = {}, -- e.g. { error = "#ff5555", warn = "#f1c40f" }
    },
    git = { enabled = true, icon = "", max_length = 24 },
    cursor = { enabled = true, separator = " | ", progress = true },
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
- Closing uses Neovim's native deletion API without forcing unsaved changes;
  deleting a buffer displayed in a split can affect the window layout.
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
  leaving terminal mode.
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
links to it. The link is restored by setup and colorscheme refreshes. File-icon
highlight groups are generated internally.

</details>

<details>
<summary>Pinning and keybindings</summary>

Pinned buffers stay in a separate left-hand area and show a red `` matching the
error color. Unpinned buffers scroll independently. If pins exceed the available
width, the pinned area shows its own overflow counts.
Pins are buffer-local and last for the current session. Filtering still
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
<summary>License</summary>

[MIT](LICENSE), copyright 2026 bitterhalt.

</details>
