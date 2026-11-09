-- Run from the repository root: nvim --headless -u NONE -l tests/slimline.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local slimline = require("slimline")
require("slimline.config").setup({ buffers = { min_width = 40 } })
vim.o.columns = 160
local first = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(first, "/tmp/slimline-one/shared.lua")
local second = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(second, "/tmp/slimline-two/shared.lua")
local rendered = slimline.render()
assert(rendered:find("slimline-one/", 1, true), rendered)
assert(rendered:find("slimline-two/", 1, true), rendered)

local special = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(special)
assert(not slimline.render():find("%#SlimlineActive#", 1, true))

vim.api.nvim_set_current_buf(second)
vim.o.columns = 30
rendered = slimline.render()
assert(rendered:find("%#SlimlineActive#%" .. second .. "@", 1, true), rendered)
local evaluated = vim.api.nvim_eval_statusline(rendered, { maxwidth = 30 })
assert(evaluated.width <= 30, evaluated.str)

vim.o.columns = 160
package.loaded["nvim-web-devicons"] = {
	get_icon = function(_, _, opts)
		return opts.default and "D" or nil
	end,
	get_icon_by_filetype = function(ft)
		return ft == "lua" and "L" or nil, "DevIconLua"
	end,
}
vim.bo[second].filetype = "lua"
vim.api.nvim_set_hl(0, "DevIconLua", { fg = "#51a0cf" })
assert(slimline.render():find("L ", 1, true))
assert(vim.api.nvim_get_hl(0, { name = "SlimlineIconDevIconLuaSlimlineActive" }).fg == 0x51a0cf)
assert(not slimline.render():find("D  ", 1, true))
vim.g.terminal_color_6 = "#12abcd"
vim.g.terminal_color_8 = "#667788"
slimline.setup()
slimline.setup()
assert(vim.o.statusline == "%!v:lua.SlimlineRender()")
assert(type(_G.SlimlineRender()) == "string")
assert(slimline.render():find("@v:lua.SlimlineClose@× ", 1, true))
assert(vim.api.nvim_get_hl(0, { name = "SlimlineModeNormal" }).bg == 0x12abcd)
assert(vim.api.nvim_get_hl(0, { name = "SlimlineBase" }).fg == 0x667788)
assert(vim.api.nvim_get_hl(0, { name = "SlimlineError" }).fg == 0xcc241d)
assert(vim.api.nvim_get_hl(0, { name = "SlimlineWarning" }).fg == 0xd79921)
assert(vim.api.nvim_get_hl(0, { name = "SlimlineModeNormal" }).ctermbg == 6)
vim.api.nvim_set_hl(0, "Normal", { fg = 0xffffff, bg = 0x123456 })
vim.cmd("doautocmd ColorScheme")
assert(vim.api.nvim_get_hl(0, { name = "SlimlineActive" }).bg == 0x123456)
vim.api.nvim_set_hl(0, "Normal", { fg = 0xffffff })
vim.cmd("doautocmd ColorScheme")
assert(vim.api.nvim_get_hl(0, { name = "SlimlineActive" }).bg == nil)

local disposable = vim.api.nvim_create_buf(true, false)
slimline.close(disposable, 1, "r", "")
assert(vim.api.nvim_buf_is_valid(disposable))
slimline.close(disposable, 1, "l", "")
assert(not vim.api.nvim_buf_is_valid(disposable))
local namespace = vim.api.nvim_create_namespace("SlimlineTest")
vim.diagnostic.set(namespace, second, {
	{ lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
	{ lnum = 0, col = 0, message = "warning", severity = vim.diagnostic.severity.WARN },
	{ lnum = 0, col = 0, message = "hint", severity = vim.diagnostic.severity.HINT },
})
rendered = slimline.render()
assert(rendered:find("%#SlimlineError# E! 1", 1, true), rendered)
assert(rendered:find("%#SlimlineWarning# W! 1", 1, true), rendered)
vim.diagnostic.reset(namespace, second)
assert(not slimline.render():find("%#SlimlineError#", 1, true))
assert(not slimline.render():find("%#SlimlineWarning#", 1, true))
-- Let setup's asynchronous lookup finish before replacing the Git runner.
vim.wait(1000, function()
	return false
end, 10)
local system = vim.system
local detached = false
vim.system = function(command, _, callback)
	if command[4] == "symbolic-ref" then
		callback({ code = detached and 1 or 0, stdout = detached and "" or "feature/test\n" })
	else
		callback({ code = 0, stdout = "abc1234\n" })
	end
end
vim.cmd("doautocmd FocusGained")
assert(vim.wait(1000, function()
	return slimline.render():find(" feature/test", 1, true) ~= nil
end))
detached = true
vim.cmd("doautocmd FocusGained")
assert(vim.wait(1000, function()
	return slimline.render():find(" @abc1234", 1, true) ~= nil
end))
vim.system = system
vim.bo[second].modified = true
assert(not slimline.render():find("%" .. second .. "@v:lua.SlimlineClose@", 1, true))
assert(slimline.render():find("%#SlimlineModified# *", 1, true))
vim.bo[second].modified = false
assert(not slimline.render():find("%" .. second .. "@v:lua.SlimlineClose@", 1, true))
assert(slimline.render():find("%" .. first .. "@v:lua.SlimlineClose@", 1, true))
slimline.setup({
	icons = false,
	mode = { labels = { n = "NORMAL" } },
	buffers = { close_icon = "x%", modified_icon = "+", exclude_filetypes = { "lua" } },
	git = { enabled = false },
	cursor = { separator = " / ", progress = false },
	highlights = { SlimlineActive = { fg = "#abcdef", bold = false } },
})
rendered = slimline.render()
assert(rendered:find(" NORMAL ", 1, true), rendered)
assert(not rendered:find("%#SlimlineActive#", 1, true), rendered)
assert(not rendered:find("", 1, true), rendered)
assert(rendered:find("@v:lua.SlimlineClick@ shared.lua ", 1, true), rendered)
assert(rendered:find("@v:lua.SlimlineClose@x%% ", 1, true), rendered)
assert(vim.api.nvim_get_hl(0, { name = "SlimlineActive" }).fg == 0xabcdef)
vim.cmd("doautocmd ColorScheme")
assert(vim.api.nvim_get_hl(0, { name = "SlimlineActive" }).fg == 0xabcdef)
vim.diagnostic.set(namespace, second, {
	{ lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
})
slimline.setup({ diagnostics = { error = "ERR%" }, git = { enabled = false }, cursor = { separator = " / " } })
rendered = slimline.render()
assert(rendered:find("ERR%% 1", 1, true), rendered)
assert(rendered:find(" / ", 1, true), rendered)
assert(rendered:find("@v:lua.SlimlineClose@× ", 1, true), rendered)
slimline.setup({
	mode = { enabled = false }, buffers = { enabled = false },
	encoding = { enabled = false },
	diagnostics = { enabled = false }, git = { enabled = false }, cursor = { enabled = false },
})
assert(vim.api.nvim_eval_statusline(slimline.render(), {}).str:match("^%s*$"))
assert(not pcall(slimline.setup, { buffers = { max_name_length = 0 } }))
assert(not pcall(slimline.setup, { git = false }))
assert(not pcall(slimline.setup, { unknown = true }))
slimline.setup({ git = { enabled = false } })
vim.bo[second].fileencoding = "latin1"
assert(slimline.render():find(" latin1", 1, true))
vim.bo[second].fileencoding = ""
assert(slimline.render():find(" " .. vim.o.encoding, 1, true))
local displayed = vim.api.nvim_eval_statusline(slimline.render(), {}).str
assert(displayed:find("E! 1 | " .. vim.o.encoding .. " | ", 1, true), displayed)
local reg_recording = vim.fn.reg_recording
vim.fn.reg_recording = function()
	return "q"
end
assert(slimline.render():find("%#SlimlineRecording# REC @q ", 1, true))
slimline.setup({ recording = { icon = "●" }, encoding = { enabled = false }, git = { enabled = false } })
assert(slimline.render():find("● @q", 1, true))
assert(not slimline.render():find("utf-8", 1, true))
vim.fn.reg_recording = reg_recording
slimline.setup({ git = { enabled = false }, encoding = { enabled = false }, diagnostics = { enabled = false } })
for i = 1, 8 do
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(buf, "/tmp/slimline-slot-" .. i .. ".lua")
end
local function visible_count()
	local _, count = slimline.render():gsub("@v:lua.SlimlineClick@", "")
	return count
end
local before = visible_count()
vim.api.nvim_buf_set_name(second, "/tmp/a-very-long-name-that-should-not-change-the-viewport.lua")
vim.bo[second].modified = true
assert(visible_count() == before)
displayed = vim.api.nvim_eval_statusline(slimline.render(), { maxwidth = vim.o.columns })
assert(displayed.width == vim.o.columns, displayed.str)
local name_position = assert(displayed.str:find("a-very", 1, true))
vim.o.columns = 130
local resized = vim.api.nvim_eval_statusline(slimline.render(), { maxwidth = 130 })
assert(resized.str:find("a-very", 1, true) == name_position, resized.str)
assert(resized.width == 130)
assert(not pcall(slimline.setup, { buffers = { min_width = 0 } }))
local config = require("slimline.config")
config.setup({ buffers = { min_width = 22 } })
assert(config.options.buffers.max_name_length == 22)
config.setup({ buffers = { min_width = 22, max_name_length = 10 } })
assert(config.options.buffers.max_name_length == 10)
config.setup()
assert(config.options.buffers.min_width == 15 and config.options.buffers.max_name_length == 15)
slimline.setup({ git = { enabled = false }, buffers = { min_width = 40 } })
vim.api.nvim_set_current_buf(second)
slimline.toggle_pin()
assert(vim.b[second].slimline_pinned)
rendered = slimline.render()
assert(rendered:find("%" .. second .. "@v:lua.SlimlineClick@", 1, true)
	< rendered:find("%" .. first .. "@v:lua.SlimlineClick@", 1, true))
assert(rendered:find("%#SlimlinePin#  ", 1, true))
assert(vim.api.nvim_get_hl(0, { name = "SlimlinePin", link = false }).fg
	== vim.api.nvim_get_hl(0, { name = "SlimlineError", link = false }).fg)
vim.api.nvim_set_current_buf(first)
slimline.toggle_pin()
slimline.next_pin()
assert(vim.api.nvim_get_current_buf() == second)
slimline.next_pin()
assert(vim.api.nvim_get_current_buf() == first)
slimline.toggle_pin()
slimline.next_pin()
assert(vim.api.nvim_get_current_buf() == second)
slimline.toggle_pin()
slimline.next_pin()
assert(vim.api.nvim_get_current_buf() == second)
slimline.setup({ git = { enabled = false } })
vim.api.nvim_set_current_buf(first)
slimline.toggle_pin()
vim.api.nvim_set_current_buf(second)
slimline.toggle_pin()
local all = vim.api.nvim_list_bufs()
local last
for _, buf in ipairs(all) do
	if vim.bo[buf].buflisted then
		last = buf
	end
end
vim.api.nvim_set_current_buf(last)
rendered = slimline.render()
local first_position = assert(rendered:find("%" .. first .. "@v:lua.SlimlineClick@", 1, true))
local second_position = assert(rendered:find("%" .. second .. "@v:lua.SlimlineClick@", 1, true))
local current_position = assert(rendered:find("%" .. last .. "@v:lua.SlimlineClick@", 1, true), rendered)
assert(first_position < second_position and second_position < current_position, rendered)
assert(vim.api.nvim_eval_statusline(rendered, { maxwidth = vim.o.columns }).width <= vim.o.columns)
local before_toggle = slimline.render()
slimline.toggle_buffers()
assert(not slimline.render():find("@v:lua.SlimlineClick@", 1, true))
assert(slimline.render():find("utf-8", 1, true))
slimline.toggle_buffers()
assert(slimline.render() == before_toggle)
-- Restore the headless startup width before enabling Neovim's tabline UI.
vim.o.columns = 80
slimline.setup({ git = { enabled = false }, buffers = { position = "top" } })
assert(vim.o.showtabline == 2)
assert(vim.o.tabline == "%!v:lua.SlimlineTabline()")
assert(not slimline.render():find("@v:lua.SlimlineClick@", 1, true))
assert(slimline.render_tabline():find("@v:lua.SlimlineClick@", 1, true))
assert(slimline.render_tabline():find("%#SlimlinePin#", 1, true))
assert(vim.api.nvim_eval_statusline(slimline.render_tabline(), { maxwidth = vim.o.columns }).width <= vim.o.columns)
slimline.toggle_buffers()
assert(vim.o.showtabline == 0 and slimline.render_tabline() == "")
slimline.toggle_buffers()
assert(vim.o.showtabline == 2)
slimline.setup({ git = { enabled = false } })
assert(vim.o.showtabline == 0 and vim.o.tabline == "")
assert(slimline.render():find("@v:lua.SlimlineClick@", 1, true))
assert(not pcall(slimline.setup, { buffers = { position = "left" } }))
print("Slimline regression tests passed")
vim.cmd("qa!")
