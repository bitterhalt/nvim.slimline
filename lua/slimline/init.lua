-- Slimline: one native statusline for mode, buffers and cursor.
-- Optional dependency: nvim-web-devicons.
local config = require("slimline.config")
local colors = require("slimline.colors")
local buffers = require("slimline.buffers")
local render = require("slimline.render")
local git = require("slimline.git")
local util = require("slimline.util")

local M = {}

local STATUSLINE = "%!v:lua.Slimline.statusline()"
local TABLINE = "%!v:lua.Slimline.tabline()"

local failed = false
-- 'showmode' value before Slimline disabled it; nil when Slimline has not touched it.
local saved_showmode

--- Wrap a renderer so an error never takes the whole statusline down. Neovim
--- resets the option when a `%!` expression throws, so fall back to a plain
--- string and report the problem once.
local function guarded(name, fallback)
	return function()
		local ok, result = pcall(render[name])
		if ok then
			return result
		end
		if not failed then
			failed = true
			vim.schedule(function()
				vim.notify("Slimline: " .. name .. " failed: " .. tostring(result), vim.log.levels.ERROR)
			end)
		end
		return fallback
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Show or hide the buffer list. Lasts until the next `setup()` or restart.
function M.toggle_buffers()
	local options = config.options.buffers
	options.enabled = not options.enabled
	if options.position == "top" then
		vim.o.showtabline = options.enabled and 2 or 0
	end
	buffers.invalidate()
	util.redraw()
end

--- Pin or unpin the current buffer.
function M.toggle_pin()
	buffers.toggle_pin()
end

--- Switch to the next pinned buffer, wrapping around.
function M.next_pin()
	buffers.cycle(1, true)
end

--- Switch to the previous pinned buffer, wrapping around.
function M.prev_pin()
	buffers.cycle(-1, true)
end

--- Switch to the next buffer in the list, wrapping around.
function M.next_buffer()
	buffers.cycle(1)
end

--- Switch to the previous buffer in the list, wrapping around.
function M.prev_buffer()
	buffers.cycle(-1)
end

--- Close a buffer without forcing unsaved changes.
---@param buf? integer Defaults to the current buffer
---@return boolean closed
function M.close_buffer(buf)
	return buffers.delete(buf)
end

--- Rebuild the buffer list and refresh Git information.
function M.refresh()
	buffers.invalidate()
	git.refresh()
	util.redraw()
end

M.statusline = guarded("statusline", " %f %m%=%l:%c ")
M.tabline = guarded("tabline", "")

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

local function create_autocmds()
	local group = vim.api.nvim_create_augroup("Slimline", { clear = true })
	local function on(events, callback, opts)
		vim.api.nvim_create_autocmd(events, vim.tbl_extend("force", { group = group, callback = callback }, opts or {}))
	end

	on("ColorScheme", function()
		colors.apply()
		vim.schedule(util.redraw)
	end)

	-- Anything that can change the buffer list. Some events (BufDelete) fire
	-- before the buffer is actually unlisted, so the cache is dropped again once
	-- the event has finished.
	--
	-- CursorHold is a self-healing net for changes that fire no event at all,
	-- such as a plugin setting 'modified' directly. It runs once per idle period.
	local function list_changed()
		buffers.invalidate()
		vim.schedule(function()
			buffers.invalidate()
			util.redraw()
		end)
	end
	local events = {
		"BufAdd",
		"BufDelete",
		"BufWipeout",
		"BufFilePost",
		"BufWritePost",
		"FileType",
		"VimEnter",
		"CursorHold",
	}
	-- Newer Neovim versions removed BufModifiedSet in favour of OptionSet.
	if vim.fn.exists("##BufModifiedSet") == 1 then
		events[#events + 1] = "BufModifiedSet"
	end
	on(events, list_changed)
	on("OptionSet", list_changed, { pattern = { "buflisted", "modified" } })
	on("SessionLoadPost", function()
		buffers.restore_pins()
		list_changed()
	end)
	on({ "BufDelete", "BufWipeout" }, function()
		vim.schedule(buffers.save_pins)
	end)

	-- The tabline is not redrawn automatically when the current buffer changes.
	on("BufEnter", function()
		if config.options.buffers.position == "top" then
			vim.schedule(util.redraw)
		end
	end)

	on({ "BufEnter", "BufFilePost", "DirChanged", "FocusGained", "TermLeave", "ShellCmdPost" }, git.refresh)
	on("User", git.refresh, { pattern = "FugitiveChanged" })

	on("DiagnosticChanged", function()
		vim.cmd("redrawstatus")
	end)

	-- RecordingLeave fires before reg_recording() has been cleared.
	on({ "RecordingEnter", "RecordingLeave" }, function()
		vim.schedule(function()
			vim.cmd("redrawstatus")
		end)
	end)

	if config.options.search.enabled then
		on("CmdlineLeave", function()
			vim.schedule(function()
				vim.cmd("redrawstatus")
			end)
		end)
	end
end

---@param options? slimline.Config
function M.setup(options)
	local ok, err = config.setup(options)
	if not ok then
		vim.notify(err .. "\nSlimline is using its default options.", vim.log.levels.ERROR)
	end
	failed = false
	buffers.invalidate()

	_G.Slimline = {
		statusline = M.statusline,
		tabline = M.tabline,
		click = buffers.on_click,
		close = buffers.on_close,
	}

	local opts = config.options
	vim.o.laststatus = 3
	local top = opts.buffers.position == "top"
	vim.o.showtabline = (top and opts.buffers.enabled) and 2 or 0
	if top then
		vim.o.tabline = TABLINE
	elseif vim.o.tabline == TABLINE then
		vim.o.tabline = ""
	end
	vim.o.statusline = STATUSLINE
	if opts.mode.enabled and opts.mode.hide_showmode then
		if saved_showmode == nil then
			saved_showmode = vim.o.showmode
		end
		vim.o.showmode = false
	elseif saved_showmode ~= nil then
		vim.o.showmode = saved_showmode
		saved_showmode = nil
	end

	create_autocmds()
	colors.apply()
	git.refresh()
	buffers.restore_pins()
end

return M
