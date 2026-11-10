# AGENTS.md

Guidance for AI coding agents (and humans) working on **nvim.slimline**: a small Neovim
plugin that combines a global statusline with a tab-styled buffer list. Pure Lua, no
runtime dependencies. `nvim-web-devicons` is optional.

## Commands

```sh
# Run the full test suite (no framework needed; non-zero exit on failure)
nvim --headless -l tests/slimline.lua

# Format / check formatting (StyLua 2.x, config in .stylua.toml)
stylua lua tests
stylua --check lua tests

# Validate the help file (should print no errors)
nvim --headless -u NONE -c "helptags doc" -c "qa"
```

Before finishing any change: tests pass, `stylua --check` is clean. CI runs both on
Neovim 0.10.4, stable and nightly, so avoid APIs newer than **0.10**.

## Layout

```
lua/slimline/
  init.lua     Public API, setup(), autocmds, render guards
  config.lua   Defaults, LuaLS types, validation (resolve/setup)
  colors.lua   Highlight groups, mode groups, devicons highlight cache
  buffers.lua  Cached buffer list, pins, navigation, closing, mouse handlers
  render.lua   Statusline + tabline strings, viewport/overflow logic
  git.lua      Async branch lookup with cache
  health.lua   :checkhealth slimline
  util.lua     escape, width, truncate, redraw
doc/slimline.txt   :help slimline
tests/slimline.lua Test suite
README.md
```

Dependency direction (no cycles): `init` -> `render` -> `buffers`/`git`/`colors` ->
`config`/`util`. `util.redraw` requires `config` lazily inside the function for this
reason. Keep it that way.

## Architecture notes

- **Entry points:** `setup()` sets `statusline` to `%!v:lua.Slimline.statusline()` and,
  with `buffers.position = "top"`, `tabline` to `%!v:lua.Slimline.tabline()`. Click
  handlers are `%@v:lua.Slimline.click@` and `...close@`. The dotted `v:lua` form was
  verified to work for mouse clicks on a real UI.
- **Render guard:** `init.lua` wraps `render.statusline/tabline` in `pcall`. If a `%!`
  expression throws, Neovim resets the option, so the guard returns a plain fallback and
  notifies once. The guard looks up `render[name]` at call time on purpose (tests patch it).
- **Buffer list cache:** `buffers.list()` returns a cached table that **must not be
  mutated**. It is rebuilt after `buffers.invalidate()`. Invalidation is event-driven from
  `init.lua` (`list_changed`), and also scheduled once more because `BufDelete` fires
  before the buffer is unlisted. `CursorHold` is an intentional self-heal for changes that
  fire no event (e.g. a plugin setting `'modified'` directly). Anything that changes what
  an item shows must either invalidate the cache or be computed at render time.
- **Items vs. render:** items hold data (`text`, `icon`, `modified`, `saved`, `closable`,
  `pinned`). `render.entry()` composes the label per slot width and drops optional parts
  (modified marker, icon, pin, padding) when narrow. Highlights are applied there, never by
  re-parsing strings.
- **Config:** `config.resolve()` merges and validates and raises `"Slimline: ..."` errors
  (via `error(msg, 0)`). `config.setup()` catches them, falls back to defaults and returns
  `false, err`. New options need: a default in `M.defaults`, a LuaLS `@field`, validation
  if not a plain boolean/string, README + `doc/slimline.txt` entries, and a test.
  Unknown keys are rejected, so forgetting the default breaks user configs.
- **Colors:** `colors.apply()` defines groups, creates the `SlimlinePin` -> `SlimlineError`
  link **before** applying user `highlights`, then applies overrides in sorted order. Don't
  reorder: this was a real bug (the link used to overwrite user overrides).
- **Git:** never runs git during rendering; `git.label()` only reads the cache.
  `git.refresh()` is async, bounded, only redraws when the label changes, and sets
  `GIT_OPTIONAL_LOCKS=0`.
- **Pins:** buffer variable `vim.b[buf].slimline_pinned` (`true` or `nil`). With
  `persist_pins`, paths are stored as JSON in `g:SlimlinePins` (uppercase name so
  `:mksession` saves it when `sessionoptions` has `globals`).
- **Closing:** `buffers.delete()` honors `buffers.keep_layout` (switch windows showing the
  buffer to another buffer first). It never forces; failures become a `WARN` notification.

## Gotchas learned the hard way

- **`BufModifiedSet` was removed in newer Neovim.** Use `OptionSet` with pattern
  `"modified"`; register `BufModifiedSet` only if `vim.fn.exists("##BufModifiedSet") == 1`.
  Never hard-code events that may not exist.
- **Modified-state events are deferred to the main loop.** They never fire under
  `nvim -l`, and setting `vim.bo.modified` directly fires nothing. Tests trigger them with
  `nvim_exec_autocmds`.
- **Nerd Font glyphs are stored as literal UTF-8 characters.** Copy them from existing
  code or a known source instead of retyping; `\u{...}` escapes render as text in README
  and help files.
- **Escape `%` in anything placed in a statusline string** with `util.escape`, which
  returns exactly one value. Use `util.width`/`util.truncate` for display widths (CJK, icons).
- **`:checkhealth` renders asynchronously on newer Neovim**; wait for its output in tests.
- **`vim.fn.getcompletion("", "event")`** is a quick way to check which events a Neovim
  version supports.
- Under `/bin/sh` (dash), brace expansion like `mkdir {a,b}` does not work.

## Testing conventions

- `tests/slimline.lua` is a dependency-free harness (`test`, `eq`, `ok`, `matches`,
  `absent`, `throws`). Each test starts with `fresh(opts)` (resets buffers/windows, calls
  `setup` with git disabled) and creates buffers with `open({ paths })`.
- `vim.notify` is stubbed; assert on the `notices` list.
- Git tests create a temp repo and are skipped when `git` is missing.
- For UI-dependent behavior (mouse clicks, what is actually drawn), `nvim -l` is not
  enough: attach a UI (`nvim --embed` via pynvim, `ui_attach`, `nvim_input_mouse`,
  `screenstring`). This is how click handling was verified.
- Add a regression test with every bug fix.

## Style

- Tabs, 120 columns, double quotes (`.stylua.toml`). Run StyLua; don't hand-format.
- LuaLS annotations on public functions and config types. Prefer small modules with a
  narrow responsibility over growing `init.lua`.
- No new global state besides `_G.Slimline` (statusline/click entry points).
- Public API lives in `init.lua`; keep it a thin layer over `buffers`/`git`.
- Don't add runtime dependencies. Optional integrations must be guarded with `pcall`.
- Keep `README.md` and `doc/slimline.txt` in sync with behavior changes.

## Ideas not yet done

- Reordering buffers (move left/right).
- A buffer picker mode (jump by letter).
- Per-buffer diagnostic indicators.
- Git diff stats (e.g. from `vim.b.gitsigns_status_dict`).
- Watching `.git/HEAD` for branch changes made outside Neovim.
