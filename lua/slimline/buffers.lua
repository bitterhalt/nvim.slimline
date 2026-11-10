local config = require("slimline.config")
local util = require("slimline.util")

local M = {}

M.PIN_GLYPH = "\u{f435}"

---@class slimline.Item
---@field buf integer
---@field pinned boolean
---@field text string Display name (already truncated unless it is a path)
---@field modified string Modified marker including its leading space, or ""
---@field closable boolean Whether an inactive entry may show a close button
---@field icon string Glyph followed by padding, or ""
---@field icon_highlight? string devicons highlight group

---@type slimline.Item[]?
local cache

--- Drop the cached list. The next `list()` call rebuilds it.
function M.invalidate()
	cache = nil
end

local function is_pinned(buf)
	return vim.b[buf].slimline_pinned == true
end

local function icon_for(devicons, name, filetype)
	if not devicons then
		return "", nil
	end
	local icon, highlight = devicons.get_icon(name, nil, { default = false })
	if not icon and filetype ~= "" then
		icon, highlight = devicons.get_icon_by_filetype(filetype, { default = false })
	end
	return icon and (icon .. "  ") or "", highlight
end

---@return slimline.Item[]
local function build()
	local result = {}
	local options = config.options.buffers
	if not options.enabled then
		return result
	end
	local devicons
	if config.options.icons then
		local ok, module = pcall(require, "nvim-web-devicons")
		devicons = ok and module or nil
	end
	local function included(buf)
		return vim.api.nvim_buf_is_valid(buf)
			and vim.bo[buf].buflisted
			and not vim.tbl_contains(options.exclude_filetypes, vim.bo[buf].filetype)
			and not vim.tbl_contains(options.exclude_buftypes, vim.bo[buf].buftype)
	end
	local counts = {}
	local listed = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if included(buf) then
			listed[#listed + 1] = buf
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
			counts[name] = (counts[name] or 0) + 1
		end
	end
	for _, buf in ipairs(listed) do
		local path = vim.api.nvim_buf_get_name(buf)
		local name = path == "" and "[No Name]" or vim.fn.fnamemodify(path, ":t")
		local icon, icon_highlight = icon_for(devicons, name, vim.bo[buf].filetype)
		local text
		if path ~= "" and counts[name] > 1 then
			-- Keep the filename and its distinguishing parent path intact.
			text = vim.fn.fnamemodify(path, ":~:.")
		elseif path == "" and counts[""] > 1 then
			text = name .. " " .. buf
		else
			text = util.truncate(name, options.max_name_length)
		end
		local modified = vim.bo[buf].modified and options.modified_icon ~= "" and (" " .. options.modified_icon) or ""
		result[#result + 1] = {
			buf = buf,
			pinned = is_pinned(buf),
			text = text,
			modified = modified,
			closable = not vim.bo[buf].modified and options.close_icon ~= "",
			icon = icon,
			icon_highlight = icon_highlight,
		}
	end
	table.sort(result, function(a, b)
		if a.pinned ~= b.pinned then
			return a.pinned
		end
		return a.buf < b.buf
	end)
	return result
end

--- Buffers shown by Slimline: pinned first, then by buffer number.
--- The result is cached and must not be modified.
---@return slimline.Item[]
function M.list()
	if not cache then
		cache = build()
	end
	return cache
end

---@param items slimline.Item[]
---@param buf integer
---@return integer? index
local function index_of(items, buf)
	for i, item in ipairs(items) do
		if item.buf == buf then
			return i
		end
	end
end

--- Index of the current buffer in `list()`, or nil for special/unlisted buffers.
---@return integer?
function M.current_index()
	return index_of(M.list(), vim.api.nvim_get_current_buf())
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Slimline" })
end

local function refresh()
	M.invalidate()
	util.redraw()
end

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------

--- Write pinned file paths to `g:SlimlinePins`. Because the name starts with an
--- uppercase letter, `:mksession` stores it when 'sessionoptions' has "globals".
function M.save_pins()
	if not config.options.buffers.persist_pins then
		return
	end
	local paths = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and is_pinned(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				paths[#paths + 1] = name
			end
		end
	end
	vim.g.SlimlinePins = vim.json.encode(paths)
end

--- Re-pin buffers whose paths are stored in `g:SlimlinePins`.
function M.restore_pins()
	if not config.options.buffers.persist_pins or type(vim.g.SlimlinePins) ~= "string" then
		return
	end
	local ok, paths = pcall(vim.json.decode, vim.g.SlimlinePins)
	if not ok or type(paths) ~= "table" then
		return
	end
	local stored = {}
	for _, path in ipairs(paths) do
		stored[path] = true
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and stored[vim.api.nvim_buf_get_name(buf)] then
			vim.b[buf].slimline_pinned = true
		end
	end
	refresh()
end

function M.toggle_pin()
	local current = vim.api.nvim_get_current_buf()
	if not M.current_index() then
		notify("The current buffer is not in the buffer list")
		return
	end
	vim.b[current].slimline_pinned = (not is_pinned(current)) or nil
	M.save_pins()
	refresh()
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------

--- Move through the buffer list, wrapping at the ends.
---@param delta integer 1 for next, -1 for previous
---@param pinned_only? boolean Cycle through pinned buffers only
function M.cycle(delta, pinned_only)
	local pool = {}
	for _, item in ipairs(M.list()) do
		if not pinned_only or item.pinned then
			pool[#pool + 1] = item
		end
	end
	if #pool == 0 then
		return
	end
	local index = index_of(pool, vim.api.nvim_get_current_buf())
	local target
	if index then
		target = (index - 1 + delta) % #pool + 1
	else
		target = delta > 0 and 1 or #pool
	end
	vim.api.nvim_set_current_buf(pool[target].buf)
end

---------------------------------------------------------------------------
-- Closing
---------------------------------------------------------------------------

--- Pick the buffer a window should show once `buf` is gone.
local function replacement(buf)
	local alternate = vim.fn.bufnr("#")
	if alternate > 0 and alternate ~= buf and vim.api.nvim_buf_is_valid(alternate) and vim.bo[alternate].buflisted then
		return alternate
	end
	local items = M.list()
	local index = index_of(items, buf)
	local neighbour = index and (items[index + 1] or items[index - 1])
	return neighbour and neighbour.buf
end

local function delete_keeping_layout(buf)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_call(win, function()
			local target = replacement(buf)
			if target then
				vim.api.nvim_win_set_buf(win, target)
			else
				vim.cmd("enew")
			end
		end)
	end
	vim.api.nvim_buf_delete(buf, { force = false })
end

--- Delete a buffer without forcing unsaved changes.
--- With `buffers.keep_layout`, windows showing it are switched to another
--- buffer first, so splits survive.
---@param buf? integer Defaults to the current buffer
---@return boolean closed
function M.delete(buf)
	if buf == nil or buf == 0 then
		buf = vim.api.nvim_get_current_buf()
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	local keep = config.options.buffers.keep_layout and not vim.bo[buf].modified
	local ok, err = pcall(keep and delete_keeping_layout or vim.api.nvim_buf_delete, buf, { force = false })
	if not ok then
		notify(tostring(err), vim.log.levels.WARN)
	end
	return ok
end

---------------------------------------------------------------------------
-- Mouse handlers (called from the statusline/tabline via v:lua)
---------------------------------------------------------------------------

function M.on_click(buf, _, button, _)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if button == "l" then
		local ok, err = pcall(vim.api.nvim_set_current_buf, buf)
		if not ok then
			notify(tostring(err), vim.log.levels.WARN)
		end
	elseif button == "m" then
		M.delete(buf)
	end
end

function M.on_close(buf, _, button, _)
	if button == "l" then
		M.delete(buf)
	end
end

return M
