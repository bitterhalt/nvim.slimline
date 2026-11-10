# Changelog

## Unreleased

### Added

- Navigation API: `next_buffer()`, `prev_buffer()`, `prev_pin()` and `goto_buffer(n)`
  (negative `n` counts from the end). All respect `exclude_*` filters.
- `close_buffer(buf?)` and `buffers.keep_layout` (default `true`): windows showing
  the closed buffer switch to another buffer first, so splits survive.
- Middle-click closes a buffer.
- `buffers.persist_pins`: pins are stored in `g:SlimlinePins` and restored with
  sessions (`sessionoptions` needs `globals`).
- `search = { enabled = true }` shows `current/total` while `hlsearch` is active.
- `cursor.virtual_column` shows the screen column instead of the byte column.
- `mode.hide_showmode` (default `true`) turns off `showmode` so the mode is not
  shown twice.
- `:checkhealth slimline` and `:help slimline`.
- LuaLS annotations (`slimline.Config`) for completion in `opts`.
- GitHub Actions CI on Neovim 0.10, stable and nightly, plus StyLua.

### Changed

- Split the 600-line `init.lua` into `config`, `colors`, `buffers`, `render`, `git`,
  `util` and `health` modules.
- The buffer list is cached and rebuilt only when buffers change, instead of on
  every redraw. Diagnostics use `vim.diagnostic.count()`.
- Invalid options no longer abort startup: the error is shown and defaults are used.
- Click handlers live under one `_G.Slimline` table instead of four globals.
- Git: availability is checked once, the directory is verified before running git,
  the cache is bounded, redraws only happen when the label changes, and
  `GIT_OPTIONAL_LOCKS=0` is set. Also refreshes on `ShellCmdPost` and `FugitiveChanged`.
- A rendering error falls back to a plain statusline and is reported once, instead
  of Neovim resetting the option.

### Fixed

- `highlights.SlimlinePin` was silently overwritten by the default link.
- Many modes (`niI`, `vs`, `Rvc`, `Rx`, ...) were shown as `N` in Normal colors;
  unknown codes now fall back to their first character. The hit-enter prompt is
  labelled `P` instead of `R`.
- The buffer list did not redraw on buffer changes with `position = "bottom"`, and
  ignored `buflisted` changes.
- Compatibility with newer Neovim, which removed `BufModifiedSet` in favour of
  `OptionSet` (`modified`).
- `vim.validate` table form (deprecated in 0.11) is no longer used.
- `util.escape` could leak a second return value from `gsub`.
- Validation errors for `min_width` named `max_name_length` instead.
