-- Run with:  nvim --headless -l tests/slimline.lua
-- No test framework is required; the exit code is non-zero on any failure.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)

local slimline = require("slimline")
local config = require("slimline.config")
local buffers = require("slimline.buffers")
local colors = require("slimline.colors")
local render = require("slimline.render")
local git = require("slimline.git")
local util = require("slimline.util")

---------------------------------------------------------------------------
-- Tiny harness
---------------------------------------------------------------------------

local passed, failed = 0, 0

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		print("  ok    " .. name)
	else
		failed = failed + 1
		print("  FAIL  " .. name .. "\n" .. tostring(err) .. "\n")
	end
end

local function eq(actual, expected, message)
	if not vim.deep_equal(actual, expected) then
		error(
			("%s\n  expected: %s\n  actual:   %s"):format(
				message or "values differ",
				vim.inspect(expected),
				vim.inspect(actual)
			),
			2
		)
	end
end

local function ok(value, message)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

local function matches(text, pattern, message)
	if not text:find(pattern, 1, true) then
		error(("%s\n  expected to find: %s\n  in: %s"):format(message or "pattern missing", pattern, text), 2)
	end
end

local function absent(text, pattern, message)
	if text:find(pattern, 1, true) then
		error(("%s\n  did not expect: %s\n  in: %s"):format(message or "unexpected pattern", pattern, text), 2)
	end
end

local function throws(fn, pattern)
	local success, err = pcall(fn)
	ok(not success, "expected an error")
	matches(tostring(err), pattern, "wrong error message")
end

---------------------------------------------------------------------------
-- Fixtures
---------------------------------------------------------------------------

local notices = {}
vim.notify = function(message, level)
	notices[#notices + 1] = { message = message, level = level }
end

local function flush()
	vim.wait(30)
end

--- Reset editor state and call setup() with git disabled unless overridden.
local function fresh(options)
	notices = {}
	vim.g.SlimlinePins = nil
	vim.cmd("silent! only")
	local blank = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(blank)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= blank then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	slimline.setup(vim.tbl_deep_extend("force", { git = { enabled = false } }, options or {}))
	flush()
end

--- Create listed buffers with the given names; the first becomes current.
local function open(paths)
	local blank = vim.api.nvim_get_current_buf()
	local bufs = {}
	for _, path in ipairs(paths) do
		local buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, path)
		bufs[#bufs + 1] = buf
	end
	vim.api.nvim_set_current_buf(bufs[1])
	if vim.api.nvim_buf_get_name(blank) == "" then
		pcall(vim.api.nvim_buf_delete, blank, { force = true })
	end
	flush()
	return bufs
end

local function names()
	return vim.tbl_map(function(item)
		return item.text
	end, buffers.list())
end

local function statusline_text(opts)
	return vim.api.nvim_eval_statusline(slimline.statusline(), opts or {}).str
end

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

print("config")

test("defaults resolve and max_name_length follows min_width", function()
	local resolved = config.resolve()
	eq(resolved.buffers.max_name_length, resolved.buffers.min_width)
	eq(config.resolve({ buffers = { min_width = 20 } }).buffers.max_name_length, 20)
	eq(config.resolve({ buffers = { min_width = 20, max_name_length = 8 } }).buffers.max_name_length, 8)
end)

test("invalid options raise descriptive errors", function()
	throws(function()
		config.resolve("nope")
	end, "expects a table")
	throws(function()
		config.resolve({ bogus = 1 })
	end, "unknown option bogus")
	throws(function()
		config.resolve({ git = { nope = 1 } })
	end, "unknown option git.nope")
	throws(function()
		config.resolve({ git = false })
	end, "git.enabled = false")
	throws(function()
		config.resolve({ buffers = { position = "left" } })
	end, "position")
	throws(function()
		config.resolve({ buffers = { min_width = 0 } })
	end, "min_width")
	throws(function()
		config.resolve({ buffers = { min_width = 1.5 } })
	end, "min_width")
	throws(function()
		config.resolve({ git = { max_length = 0 } })
	end, "git.max_length")
	throws(function()
		config.resolve({ buffers = { exclude_filetypes = { 1 } } })
	end, "exclude_filetypes")
	throws(function()
		config.resolve({ buffers = { exclude_buftypes = { a = "b" } } })
	end, "exclude_buftypes")
	throws(function()
		config.resolve({ mode = { labels = { n = 1 } } })
	end, "mode.labels")
	throws(function()
		config.resolve({ highlights = { Other = {} } })
	end, "highlights")
	throws(function()
		config.resolve({ diagnostics = { colors = { info = "#fff" } } })
	end, "diagnostics.colors")
end)

test("setup falls back to defaults instead of throwing", function()
	local success, err = config.setup({ bogus = 1 })
	eq(success, false)
	matches(err, "unknown option bogus")
	eq(config.options, config.defaults)
	slimline.setup({ bogus = 1 })
	ok(#notices > 0 and notices[#notices].level == vim.log.levels.ERROR, "an error should be reported")
	matches(notices[#notices].message, "default options")
end)

---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------

print("colors")

test("pin follows the error group by default", function()
	fresh()
	eq(vim.api.nvim_get_hl(0, { name = "SlimlinePin", link = true }).link, "SlimlineError")
end)

test("highlights.SlimlinePin overrides the pin link", function()
	fresh({ highlights = { SlimlinePin = { fg = "#123456" } } })
	eq(vim.api.nvim_get_hl(0, { name = "SlimlinePin", link = false }).fg, 0x123456)
end)

test("diagnostics.colors reach the error group", function()
	fresh({ diagnostics = { colors = { error = "#ff5555" } } })
	eq(vim.api.nvim_get_hl(0, { name = "SlimlineError" }).fg, 0xff5555)
end)

test("SlimlineSaved defaults to the text color and can be overridden", function()
	fresh()
	eq(vim.api.nvim_get_hl(0, { name = "SlimlineSaved" }).fg, vim.api.nvim_get_hl(0, { name = "SlimlineText" }).fg)
	fresh({ highlights = { SlimlineSaved = { fg = "#123456" } } })
	eq(vim.api.nvim_get_hl(0, { name = "SlimlineSaved" }).fg, 0x123456)
end)

test("colorscheme refresh restores the pin link", function()
	fresh()
	vim.api.nvim_set_hl(0, "SlimlinePin", { fg = "#000001" })
	vim.api.nvim_exec_autocmds("ColorScheme", {})
	eq(vim.api.nvim_get_hl(0, { name = "SlimlinePin", link = true }).link, "SlimlineError")
end)

test("devicons are not bold, even on the active buffer", function()
	fresh()
	local group = colors.icon_group("DevIconLua", "SlimlineActive")
	ok(not vim.api.nvim_get_hl(0, { name = group }).bold, "icons should not be bold")
	ok(vim.api.nvim_get_hl(0, { name = "SlimlineActive" }).bold, "active text stays bold")
end)

test("mode groups map to categories", function()
	eq(colors.mode_group("N"), "SlimlineModeNormal")
	eq(colors.mode_group("VL"), "SlimlineModeVisual")
	eq(colors.mode_group("SB"), "SlimlineModeVisual")
	eq(colors.mode_group("R"), "SlimlineModeReplace")
	eq(colors.mode_group("P"), "SlimlineModeCommand")
	eq(colors.mode_group("T"), "SlimlineModeTerminal")
end)

---------------------------------------------------------------------------
-- Modes
---------------------------------------------------------------------------

print("modes")

test("mode codes fall back to their first character", function()
	eq(render.mode_code("n"), "N")
	eq(render.mode_code("niI"), "N")
	eq(render.mode_code("nt"), "N")
	eq(render.mode_code("vs"), "V")
	eq(render.mode_code("Vs"), "VL")
	eq(render.mode_code("\22s"), "VB")
	eq(render.mode_code("Rvc"), "R")
	eq(render.mode_code("Rx"), "R")
	eq(render.mode_code("no\22"), "N")
	eq(render.mode_code("r"), "P")
	eq(render.mode_code("unknown"), "N")
end)

test("mode.labels override by raw mode code", function()
	fresh({ mode = { labels = { n = "NORMAL" } } })
	matches(statusline_text(), " NORMAL ")
end)

test("setup hides 'showmode' and restores it when disabled", function()
	-- Clear state left by earlier tests before checking restoration.
	fresh({ mode = { hide_showmode = false } })
	vim.o.showmode = true
	fresh()
	eq(vim.o.showmode, false)
	fresh({ mode = { hide_showmode = false } })
	eq(vim.o.showmode, true)

	vim.o.showmode = true
	fresh()
	eq(vim.o.showmode, false)
	fresh({ mode = { enabled = false } })
	eq(vim.o.showmode, true)

	-- Do not force 'showmode' on when the user already had it off.
	vim.o.showmode = false
	fresh()
	eq(vim.o.showmode, false)
	fresh({ mode = { hide_showmode = false } })
	eq(vim.o.showmode, false)
	vim.o.showmode = true
end)

---------------------------------------------------------------------------
-- Buffer list
---------------------------------------------------------------------------

print("buffers")

test("lists buffers in number order and caches the result", function()
	fresh()
	open({ "/proj/b.lua", "/proj/a.lua" })
	eq(names(), { "b.lua", "a.lua" })
	ok(buffers.list() == buffers.list(), "list() should return the cached table")
end)

test("duplicate names show distinguishing paths", function()
	fresh()
	open({ "/proj/x/init.lua", "/proj/y/init.lua" })
	local list = names()
	matches(list[1], "x/init.lua")
	matches(list[2], "y/init.lua")
end)

test("unnamed buffers are numbered when more than one exists", function()
	fresh()
	local extra = vim.api.nvim_create_buf(true, false)
	flush()
	local list = names()
	eq(#list, 2)
	matches(list[2], "[No Name] " .. extra)
end)

test("long names are truncated to max_name_length", function()
	fresh({ buffers = { max_name_length = 10 } })
	open({ "/proj/averyveryverylongfilename.lua" })
	local name = names()[1]
	ok(util.width(name) <= 10, "name should fit: " .. name)
	matches(name, "…")
end)

test("exclude_filetypes and exclude_buftypes filter the list", function()
	fresh({ buffers = { exclude_filetypes = { "help" }, exclude_buftypes = { "nofile" } } })
	local bufs = open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	vim.bo[bufs[2]].filetype = "help"
	vim.bo[bufs[3]].buftype = "nofile"
	buffers.invalidate()
	eq(names(), { "a.lua" })
end)

test("the cache follows add, delete, modified and buflisted changes", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	eq(names(), { "a.lua", "b.lua" })

	local added = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(added, "/proj/c.lua")
	flush()
	eq(names(), { "a.lua", "b.lua", "c.lua" }, "BufAdd")

	-- Neovim defers its modified-state events to the main loop, which `nvim -l`
	-- never reaches (and newer versions replaced BufModifiedSet with OptionSet),
	-- so trigger the event by hand to test the plumbing.
	vim.bo[bufs[2]].modified = true
	vim.api.nvim_exec_autocmds("OptionSet", { pattern = "modified" })
	flush()
	eq(buffers.list()[2].modified, " *", "OptionSet modified")
	eq(buffers.list()[2].closable, false)
	vim.bo[bufs[2]].modified = false
	vim.api.nvim_exec_autocmds("CursorHold", {})
	flush()
	eq(buffers.list()[2].modified, "", "CursorHold self-heals changes that fire no event")

	vim.bo[added].buflisted = false
	flush()
	eq(names(), { "a.lua", "b.lua" }, "buflisted")

	vim.api.nvim_buf_delete(bufs[2], { force = true })
	flush()
	eq(names(), { "a.lua" }, "BufDelete")
end)

test("modified and close markers can be hidden", function()
	fresh({ buffers = { modified_icon = "", close_icon = "" } })
	local bufs = open({ "/proj/a.lua" })
	vim.bo[bufs[1]].modified = true
	flush()
	eq(buffers.list()[1].modified, "")
	eq(buffers.list()[1].closable, false)
end)

test("files without a devicon use the placeholder icon", function()
	local original = package.loaded["nvim-web-devicons"]
	package.loaded["nvim-web-devicons"] = {
		get_icon = function(name)
			if name:match("%.lua$") then
				return "", "DevIconLua"
			end
		end,
		get_icon_by_filetype = function()
			return nil
		end,
	}
	fresh()
	open({ "/proj/a.lua", "/proj/b.unknownext" })
	local list = buffers.list()
	eq(list[1].icon, "  ", "a devicon still wins")
	eq(list[2].icon, "󰈔  ")

	fresh({ icons = false })
	open({ "/proj/a.unknownext" })
	eq(buffers.list()[1].icon, "", "icons = false hides the placeholder")

	fresh({ buffers = { placeholder_icon = "" } })
	open({ "/proj/a.unknownext" })
	eq(buffers.list()[1].icon, "", "an empty placeholder is hidden")

	package.loaded["nvim-web-devicons"] = original
end)

test("the placeholder also appears without nvim-web-devicons", function()
	local loaded = package.loaded["nvim-web-devicons"]
	local preload = package.preload["nvim-web-devicons"]
	package.loaded["nvim-web-devicons"] = nil
	package.preload["nvim-web-devicons"] = function()
		error("not installed")
	end
	fresh()
	open({ "/proj/a.unknownext" })
	eq(buffers.list()[1].icon, "󰈔  ")
	package.loaded["nvim-web-devicons"] = loaded
	package.preload["nvim-web-devicons"] = preload
end)

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

print("render")

test("statusline shows mode, buffers, encoding and cursor", function()
	fresh()
	open({ "/proj/a.lua", "/proj/b.lua" })
	local text = statusline_text()
	matches(text, " N ")
	matches(text, "a.lua")
	matches(text, "b.lua")
	matches(text, "utf-8")
	matches(text, "1:1 | 100%")
end)

test("the focused unmodified buffer shows a check mark", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	matches(statusline_text(), "󰄬")
	matches(slimline.statusline(), "%#SlimlineSaved#")
	vim.bo[bufs[1]].modified = true
	vim.api.nvim_exec_autocmds("OptionSet", { pattern = "modified" })
	flush()
	absent(statusline_text(), "󰄬", "modified buffers show no check mark")

	fresh({ buffers = { saved_icon = "" } })
	open({ "/proj/a.lua", "/proj/b.lua" })
	absent(statusline_text(), "󰄬", "an empty saved_icon hides the check mark")
end)

test("percent signs in names are escaped", function()
	fresh()
	open({ "/proj/100%.txt" })
	matches(slimline.statusline(), "100%%.txt")
	matches(statusline_text(), "100%.txt")
end)

test("components can be disabled", function()
	fresh({ mode = { enabled = false }, encoding = { enabled = false }, cursor = { enabled = false } })
	open({ "/proj/a.lua" })
	local text = statusline_text()
	absent(text, "utf-8")
	absent(text, "1:1")
	absent(text, " N ")
end)

test("macro recording indicator appears only while recording", function()
	fresh()
	absent(statusline_text(), "REC")
	vim.cmd("normal! qq")
	matches(statusline_text(), "REC @q")
	vim.cmd("normal! q")
	absent(statusline_text(), "REC")
end)

test("virtual_column shows the screen column", function()
	fresh()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "\tx" })
	vim.api.nvim_win_set_cursor(0, { 1, 1 })
	matches(statusline_text(), "1:2")
	fresh({ cursor = { virtual_column = true } })
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "\tx" })
	vim.api.nvim_win_set_cursor(0, { 1, 1 })
	matches(statusline_text(), "1:9")
end)

test("search count appears only when enabled and hlsearch is active", function()
	fresh({ search = { enabled = true } })
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo foo foo" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.fn.setreg("/", "foo")
	vim.v.hlsearch = 0
	absent(statusline_text(), "1/3")
	vim.v.hlsearch = 1
	matches(statusline_text(), " 1/3")
	fresh()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo foo foo" })
	vim.fn.setreg("/", "foo")
	vim.v.hlsearch = 1
	absent(statusline_text(), "1/3", "disabled by default")
end)

test("diagnostics show error and warning counts", function()
	fresh({ diagnostics = { error = "E", warn = "W" } })
	local buf = open({ "/proj/a.lua" })[1]
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
	local ns = vim.api.nvim_create_namespace("slimline-test")
	local S = vim.diagnostic.severity
	vim.diagnostic.set(ns, buf, {
		{ lnum = 0, col = 0, message = "e1", severity = S.ERROR },
		{ lnum = 1, col = 0, message = "e2", severity = S.ERROR },
		{ lnum = 2, col = 0, message = "w", severity = S.WARN },
		{ lnum = 2, col = 0, message = "h", severity = S.HINT },
	})
	local text = statusline_text()
	matches(text, "E 2")
	matches(text, "W 1")
	vim.diagnostic.reset(ns, buf)
	absent(statusline_text(), "E 2")
end)

test("narrow windows keep the statusline within the editor width", function()
	fresh()
	local paths = {}
	for i = 1, 12 do
		paths[i] = ("/proj/file%02d.lua"):format(i)
	end
	open(paths)
	local original = vim.o.columns
	vim.o.columns = 60
	if vim.o.columns == 60 then
		local result = vim.api.nvim_eval_statusline(slimline.statusline(), { maxwidth = 60 })
		ok(result.width <= 60, "width " .. result.width .. " exceeds 60")
		matches(result.str, ">")
	end
	vim.o.columns = original
end)

test("errors in a renderer fall back to a plain statusline and report once", function()
	fresh()
	local original = render.statusline
	render.statusline = function()
		error("boom")
	end
	local fallback = slimline.statusline()
	slimline.statusline()
	render.statusline = original
	flush()
	matches(fallback, "%f")
	eq(#notices, 1, "failure should be reported once")
	matches(notices[1].message, "boom")
	matches(slimline.statusline(), "%#SlimlineBase#", "rendering recovers")
end)

---------------------------------------------------------------------------
-- Tabline and toggling
---------------------------------------------------------------------------

print("tabline")

test("position = top moves the list to the tabline", function()
	fresh({ buffers = { position = "top" } })
	open({ "/proj/a.lua", "/proj/b.lua" })
	eq(vim.o.showtabline, 2)
	eq(vim.o.tabline, "%!v:lua.Slimline.tabline()")
	local tabline = vim.api.nvim_eval_statusline(slimline.tabline(), {}).str
	matches(tabline, "a.lua")
	matches(tabline, "b.lua")
	absent(statusline_text(), "a.lua")
	matches(statusline_text(), " N ")
end)

test("switching back to bottom clears the tabline", function()
	fresh({ buffers = { position = "top" } })
	slimline.setup({ git = { enabled = false } })
	eq(vim.o.showtabline, 0)
	eq(vim.o.tabline, "")
end)

test("toggle_buffers hides and restores the list", function()
	fresh()
	open({ "/proj/a.lua" })
	matches(statusline_text(), "a.lua")
	slimline.toggle_buffers()
	absent(statusline_text(), "a.lua")
	matches(statusline_text(), " N ")
	slimline.toggle_buffers()
	matches(statusline_text(), "a.lua")
end)

test("toggle_buffers also drives showtabline when on top", function()
	fresh({ buffers = { position = "top" } })
	slimline.toggle_buffers()
	eq(vim.o.showtabline, 0)
	slimline.toggle_buffers()
	eq(vim.o.showtabline, 2)
end)

---------------------------------------------------------------------------
-- Pins and navigation
---------------------------------------------------------------------------

print("pins and navigation")

local function current_name()
	return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
end

test("pinning moves a buffer to the front and shows the pin glyph", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	vim.api.nvim_set_current_buf(bufs[3])
	slimline.toggle_pin()
	eq(names(), { "c.lua", "a.lua", "b.lua" })
	matches(statusline_text(), buffers.PIN_GLYPH)
	slimline.toggle_pin()
	eq(names(), { "a.lua", "b.lua", "c.lua" })
	absent(statusline_text(), buffers.PIN_GLYPH)
end)

test("toggle_pin explains itself for buffers outside the list", function()
	fresh({ buffers = { exclude_filetypes = { "help" } } })
	vim.bo.filetype = "help"
	buffers.invalidate()
	slimline.toggle_pin()
	ok(#notices == 1 and notices[1].message:find("not in the buffer list", 1, true))
	eq(vim.b.slimline_pinned, nil)
end)

test("next_pin and prev_pin wrap through pinned buffers only", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	vim.api.nvim_set_current_buf(bufs[1])
	slimline.toggle_pin()
	vim.api.nvim_set_current_buf(bufs[3])
	slimline.toggle_pin()
	vim.api.nvim_set_current_buf(bufs[2])
	slimline.next_pin()
	eq(current_name(), "a.lua", "from an unpinned buffer, next goes to the first pin")
	slimline.next_pin()
	eq(current_name(), "c.lua")
	slimline.next_pin()
	eq(current_name(), "a.lua", "wraps")
	slimline.prev_pin()
	eq(current_name(), "c.lua", "prev wraps backwards")
end)

test("next_buffer and prev_buffer follow the list order", function()
	fresh()
	open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	slimline.next_buffer()
	eq(current_name(), "b.lua")
	slimline.next_buffer()
	slimline.next_buffer()
	eq(current_name(), "a.lua", "wraps forwards")
	slimline.prev_buffer()
	eq(current_name(), "c.lua", "wraps backwards")
end)

test("navigation respects exclusion filters", function()
	fresh({ buffers = { exclude_filetypes = { "help" } } })
	local bufs = open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	vim.bo[bufs[2]].filetype = "help"
	buffers.invalidate()
	slimline.next_buffer()
	eq(current_name(), "c.lua")
end)

test("pins are only persisted when persist_pins is enabled", function()
	fresh()
	open({ "/proj/a.lua" })
	slimline.toggle_pin()
	eq(vim.g.SlimlinePins, nil)

	fresh({ buffers = { persist_pins = true } })
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	slimline.toggle_pin()
	eq(vim.json.decode(vim.g.SlimlinePins), { "/proj/a.lua" })

	vim.b[bufs[1]].slimline_pinned = nil
	buffers.invalidate()
	eq(buffers.list()[1].pinned, false)
	buffers.restore_pins()
	eq(buffers.list()[1].pinned, true, "restore_pins re-pins by path")
end)

test("persisted pins survive :mksession", function()
	fresh({ buffers = { persist_pins = true } })
	open({ "/proj/a.lua" })
	slimline.toggle_pin()
	local file = vim.fn.tempname()
	local saved = vim.o.sessionoptions
	vim.o.sessionoptions = "globals"
	vim.cmd("mksession! " .. vim.fn.fnameescape(file))
	vim.o.sessionoptions = saved
	local contents = table.concat(vim.fn.readfile(file), "\n")
	matches(contents, "SlimlinePins")
	vim.fn.delete(file)
end)

---------------------------------------------------------------------------
-- Closing and mouse handlers
---------------------------------------------------------------------------

print("closing")

test("keep_layout switches windows to another buffer instead of closing them", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, bufs[2])
	eq(#vim.api.nvim_list_wins(), 2)
	ok(slimline.close_buffer(bufs[2]))
	eq(#vim.api.nvim_list_wins(), 2, "layout should survive")
	eq(vim.fn.buflisted(bufs[2]), 0)
	eq(current_name(), "a.lua")
end)

test("keep_layout = false uses plain deletion", function()
	fresh({ buffers = { keep_layout = false } })
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, bufs[2])
	ok(slimline.close_buffer(bufs[2]))
	eq(#vim.api.nvim_list_wins(), 1, "Neovim closes the window")
end)

test("closing the last buffer leaves an empty one", function()
	fresh()
	local bufs = open({ "/proj/a.lua" })
	ok(slimline.close_buffer(bufs[1]))
	eq(#vim.api.nvim_list_wins(), 1)
	eq(vim.api.nvim_buf_get_name(0), "")
end)

test("modified buffers are not closed and the user is told why", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua" })
	vim.bo[bufs[2]].modified = true
	eq(slimline.close_buffer(bufs[2]), false)
	eq(vim.fn.buflisted(bufs[2]), 1)
	eq(#notices, 1)
	eq(notices[1].level, vim.log.levels.WARN)
	vim.bo[bufs[2]].modified = false
end)

test("mouse handlers: left switches, middle closes, right does nothing", function()
	fresh()
	local bufs = open({ "/proj/a.lua", "/proj/b.lua", "/proj/c.lua" })
	buffers.on_click(bufs[2], 1, "l", "")
	eq(current_name(), "b.lua")
	buffers.on_click(bufs[3], 1, "r", "")
	eq(current_name(), "b.lua")
	buffers.on_click(bufs[3], 1, "m", "")
	eq(vim.fn.buflisted(bufs[3]), 0)
	buffers.on_close(bufs[1], 1, "r", "")
	eq(vim.fn.buflisted(bufs[1]), 1)
	buffers.on_close(bufs[1], 1, "l", "")
	eq(vim.fn.buflisted(bufs[1]), 0)
	buffers.on_click(99999, 1, "l", "") -- invalid buffers are ignored
end)

test("the click targets are reachable through the Slimline global", function()
	fresh()
	eq(type(_G.Slimline.click), "function")
	eq(type(_G.Slimline.close), "function")
	matches(slimline.statusline(), "@v:lua.Slimline.click@")
end)

---------------------------------------------------------------------------
-- Git
---------------------------------------------------------------------------

print("git")

local function sh(cmd, cwd)
	local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
	ok(result.code == 0, table.concat(cmd, " ") .. ": " .. (result.stderr or ""))
end

if vim.fn.executable("git") == 1 then
	local function wait_for(predicate)
		return vim.wait(3000, predicate, 20)
	end

	test("shows the branch, @commit when detached, nothing outside a repo", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		fresh({ git = { enabled = true } })
		local buf = open({ dir .. "/file.txt" })[1]
		vim.api.nvim_set_current_buf(buf)

		git.refresh()
		flush()
		eq(git.label(), "", "not a repository yet")

		sh({ "git", "init", "-q" }, dir)
		sh({ "git", "symbolic-ref", "HEAD", "refs/heads/trunk" }, dir)
		git.refresh()
		ok(
			wait_for(function()
				return git.label() == "trunk"
			end),
			"branch: " .. git.label()
		)
		matches(statusline_text(), "trunk")

		sh({ "git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "x" }, dir)
		sh({ "git", "checkout", "-q", "--detach" }, dir)
		git.refresh()
		ok(
			wait_for(function()
				return git.label():sub(1, 1) == "@"
			end),
			"detached: " .. git.label()
		)
		ok(#git.label() > 1)

		vim.fn.delete(dir, "rf")
	end)

	test("long branch names are truncated and disabling git hides the label", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		sh({ "git", "init", "-q" }, dir)
		sh({ "git", "symbolic-ref", "HEAD", "refs/heads/a-really-quite-long-branch-name-here" }, dir)
		fresh({ git = { enabled = true, max_length = 10 } })
		open({ dir .. "/file.txt" })
		git.refresh()
		ok(wait_for(function()
			return git.label() ~= ""
		end))
		matches(statusline_text(), "a-really-…")
		slimline.setup({ git = { enabled = false } })
		eq(git.label(), "")
		vim.fn.delete(dir, "rf")
	end)

	test("special buffers and missing directories are ignored", function()
		fresh({ git = { enabled = true } })
		vim.bo.buftype = "nofile"
		eq(git.directory(), nil)
		git.refresh() -- must not raise
		vim.bo.buftype = ""
		open({ "/definitely/not/a/real/dir/file.txt" })
		git.refresh()
		flush()
		eq(git.label(), "")
	end)
else
	print("  skip  git tests (git not installed)")
end

---------------------------------------------------------------------------
-- Health and utilities
---------------------------------------------------------------------------

print("health and util")

test(":checkhealth slimline runs without errors", function()
	fresh()
	vim.cmd("checkhealth slimline")
	-- Newer Neovim versions render :checkhealth asynchronously.
	local function read()
		return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	end
	vim.wait(3000, function()
		return read():find("Configuration is valid", 1, true) ~= nil
	end, 20)
	local text = read()
	matches(text, "Configuration is valid")
	absent(text, "Failed to run healthcheck")
	absent(text, "ERROR")
	vim.cmd("silent! bwipeout!")
end)

test("util.truncate and util.escape", function()
	eq(util.truncate("short", 10), "short")
	eq(util.truncate("abcdefghij", 5), "abcd…")
	eq(util.truncate("anything", 0), "")
	eq(util.truncate("日本語のファイル", 7), "日本語…")
	eq(util.escape("100%"), "100%%")
	eq(select("#", util.escape("x%")), 1, "escape returns a single value")
end)

---------------------------------------------------------------------------

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
