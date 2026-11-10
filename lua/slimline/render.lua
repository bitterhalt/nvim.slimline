local config = require("slimline.config")
local colors = require("slimline.colors")
local buffers = require("slimline.buffers")
local git = require("slimline.git")
local util = require("slimline.util")

local escape, width, truncate = util.escape, util.width, util.truncate

local M = {}

-- Short labels for `mode()` codes. Codes that are missing here fall back to
-- their first character, so e.g. "niI" resolves to "n" and "Rvc" to "R".
local modes = {
	n = "N",
	no = "N",
	nov = "N",
	noV = "N",
	["no\22"] = "N",
	i = "I",
	ic = "I",
	ix = "I",
	v = "V",
	V = "VL",
	["\22"] = "VB",
	s = "S",
	S = "SL",
	["\19"] = "SB",
	R = "R",
	Rc = "R",
	Rv = "R",
	c = "C",
	cv = "C",
	ce = "C",
	r = "P", -- hit-enter prompt
	rm = "M", -- more prompt
	["r?"] = "?", -- confirm query
	t = "T",
	["!"] = "!",
}

--- Short label for a Neovim mode code.
---@param raw string Value of `nvim_get_mode().mode`
---@return string
function M.mode_code(raw)
	return modes[raw] or modes[raw:sub(1, 1)] or "N"
end

---------------------------------------------------------------------------
-- Buffer entries
---------------------------------------------------------------------------

--- Render one entry into a fragment that is exactly `space` cells wide,
--- close button included. Optional parts are dropped, in order of least
--- importance, when the slot is too narrow.
local function entry(item, style, space)
	local options = config.options.buffers
	local focused = style == "SlimlineActive" or style == "SlimlineSingle"
	local close = (not focused and item.closable) and (options.close_icon .. " ") or ""
	local check = (focused and item.saved and options.saved_icon ~= "") and (options.saved_icon .. " ") or ""
	-- Keep a marker only when there is also room for a useful label.
	if space < width(close) + width(check) + 2 then
		close, check = "", ""
	end
	local label_space = space - width(close) - width(check)

	local lead, pin, icon, mod, trail =
		" ", item.pinned and (buffers.PIN_GLYPH .. "  ") or "", item.icon, item.modified, " "
	local function room()
		return label_space - width(lead) - width(pin) - width(icon) - width(mod) - width(trail)
	end
	if room() < 1 then
		mod = ""
	end
	if room() < 1 then
		icon = ""
	end
	if room() < 1 then
		pin = ""
	end
	if room() < 1 then
		trail = ""
	end
	if room() < 1 then
		lead = ""
	end
	local text = truncate(item.text, math.max(room(), 0))
	local padding = math.max(0, room() - width(text))

	local back = "%#" .. style .. "#"
	local parts = { back, "%", item.buf, "@v:lua.Slimline.click@", escape(lead) }
	if pin ~= "" then
		parts[#parts + 1] = "%#SlimlinePin#" .. escape(pin) .. back
	end
	if icon ~= "" then
		if item.icon_highlight then
			parts[#parts + 1] = "%#" .. colors.icon_group(item.icon_highlight, style) .. "#" .. escape(icon) .. back
		else
			parts[#parts + 1] = escape(icon)
		end
	end
	parts[#parts + 1] = escape(text)
	if mod ~= "" then
		parts[#parts + 1] = focused and ("%#SlimlineModified#" .. escape(mod) .. back) or escape(mod)
	end
	parts[#parts + 1] = escape(trail) .. string.rep(" ", padding)
	if check ~= "" then
		parts[#parts + 1] = "%#SlimlineSaved#" .. escape(check) .. back
	end
	parts[#parts + 1] = "%T"
	if close ~= "" then
		parts[#parts + 1] = ("%%#%s#%%%d@v:lua.Slimline.close@%s%%T"):format(
			focused and "SlimlineClose" or "SlimlineBase",
			item.buf,
			escape(close)
		)
	end
	return table.concat(parts)
end

-- Capacity depends on a stable slot width, never on individual filenames.
local function visible_range(items, active, space)
	local n = #items
	if n == 0 or space <= 0 then
		return nil
	end
	local minimum = config.options.buffers.min_width
	for count = math.min(n, math.max(1, math.floor(space / minimum))), 1, -1 do
		local first = math.max(1, math.min(active - math.floor((count - 1) / 2), n - count + 1))
		local last = first + count - 1
		local left = first > 1 and (" <" .. (first - 1) .. " ") or ""
		local right = last < n and (" " .. (n - last) .. "> ") or ""
		local available = space - width(left) - width(right)
		if available >= count * minimum or (count == 1 and available >= 1) then
			return first, last, available, left, right
		end
	end
end

local function viewport(items, active, available, selected, active_style)
	active_style = active_style or (#items == 1 and "SlimlineSingle" or "SlimlineActive")
	local first, last, space, left, right = visible_range(items, active, available)
	if not first then
		local item = items[active]
		if not item or available <= 0 then
			return ""
		end
		return entry(item, selected == active and active_style or "SlimlineBase", available)
	end
	local parts = {}
	if first > 1 then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(left)
	end
	local slot = math.min(config.options.buffers.min_width, space)
	for i = first, last do
		parts[#parts + 1] = entry(items[i], i == selected and active_style or "SlimlineBase", slot)
	end
	if last < #items then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(right)
	end
	return table.concat(parts)
end

--- Pinned entries get their own viewport on the left; the rest scroll apart.
local function section(items, active, available, selected)
	local pinned_count = 0
	for _, item in ipairs(items) do
		if not item.pinned then
			break
		end
		pinned_count = pinned_count + 1
	end
	if pinned_count == 0 or pinned_count == #items or available <= 0 then
		return viewport(items, active, available, selected)
	end
	local pinned, regular = {}, {}
	for i, item in ipairs(items) do
		local target = i <= pinned_count and pinned or regular
		target[#target + 1] = item
	end
	local slot = config.options.buffers.min_width
	-- Keep room for an ordinary slot and its overflow markers. If pins alone
	-- exceed the remaining space, their own viewport handles that overflow.
	local reserve = math.min(slot + 10, math.floor(available / 2))
	local pin_space = math.min(pinned_count * slot, available - reserve)
	local pin_selected = selected <= pinned_count and selected or 0
	local regular_selected = selected > pinned_count and selected - pinned_count or 0
	return viewport(pinned, math.max(1, pin_selected), pin_space, pin_selected, "SlimlineActive")
		.. viewport(regular, math.max(1, regular_selected), available - pin_space, regular_selected, "SlimlineActive")
end

---------------------------------------------------------------------------
-- Tabline
---------------------------------------------------------------------------

function M.tabline()
	if config.options.buffers.position ~= "top" or not config.options.buffers.enabled then
		return ""
	end
	local selected = buffers.current_index() or 0
	return "%#SlimlineBase# "
		.. section(buffers.list(), math.max(1, selected), vim.o.columns - 1, selected)
		.. "%#SlimlineBase#%="
end

---------------------------------------------------------------------------
-- Statusline
---------------------------------------------------------------------------

local function search_label()
	if vim.v.hlsearch ~= 1 then
		return ""
	end
	local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 20 })
	if not ok or type(result) ~= "table" or not result.total or result.total == 0 then
		return ""
	end
	local total = result.incomplete == 2 and (">" .. result.maxcount) or result.total
	return " " .. result.current .. "/" .. total
end

local function cursor_label(options, current)
	if not options.cursor.enabled then
		return ""
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = pos[1]
	local col = options.cursor.virtual_column and vim.fn.virtcol(".") or (pos[2] + 1)
	local text = " " .. line .. ":" .. col
	if options.cursor.progress then
		local total = math.max(vim.api.nvim_buf_line_count(current), 1)
		text = text .. options.cursor.separator .. math.floor(100 * line / total) .. "%"
	end
	return text .. " "
end

function M.statusline()
	local options = config.options
	local current = vim.api.nvim_get_current_buf()
	local raw_mode = vim.api.nvim_get_mode().mode
	local code = M.mode_code(raw_mode)
	local left = options.mode.enabled and (" " .. (options.mode.labels[raw_mode] or code) .. " ") or ""
	local register = vim.fn.reg_recording()
	local recording = register ~= "" and (" " .. options.recording.icon .. " @" .. register .. " ") or ""

	local encoding = ""
	if options.encoding.enabled then
		local fileencoding = vim.bo[current].fileencoding
		encoding = " " .. (fileencoding ~= "" and fileencoding or vim.o.encoding)
	end

	local branch = git.label()
	local git_label = ""
	if branch ~= "" then
		local icon = options.git.icon ~= "" and (options.git.icon .. " ") or ""
		git_label = " " .. icon .. truncate(branch, options.git.max_length)
	end

	local sections = {}
	local right_width = 0
	local function add(label, style)
		if label ~= "" then
			sections[#sections + 1] = "%#" .. style .. "#" .. escape(label)
			right_width = right_width + width(label)
		end
	end
	add(git_label, "SlimlineGit")
	if options.diagnostics.enabled then
		local counts = vim.diagnostic.count(current)
		local severity = vim.diagnostic.severity
		for _, spec in ipairs({
			{ severity.ERROR, options.diagnostics.error, "SlimlineError" },
			{ severity.WARN, options.diagnostics.warn, "SlimlineWarning" },
		}) do
			local count = counts[spec[1]] or 0
			if count > 0 then
				add(" " .. spec[2] .. " " .. count, spec[3])
			end
		end
	end
	if options.search.enabled then
		add(search_label(), "SlimlineText")
	end
	add(encoding, "SlimlineText")
	add(cursor_label(options, current), "SlimlineText")
	-- Labels already include leading padding; use one shared separator everywhere.
	local separator = options.cursor.separator:gsub("%s$", "")
	right_width = right_width + math.max(#sections - 1, 0) * width(separator)
	local right = table.concat(sections, "%#SlimlineBase#" .. escape(separator))

	local items = options.buffers.position == "bottom" and buffers.list() or {}
	-- Special/unlisted buffers have no selected entry in the buffer list. A zero
	-- index keeps every entry inactive while still anchoring a viewport.
	local active = buffers.current_index() or 0
	-- The global statusline uses the editor's full width, not just the active split.
	local available = vim.o.columns - width(left) - width(recording) - right_width - 2
	return "%#"
		.. colors.mode_group(code)
		.. "#"
		.. escape(left)
		.. "%#SlimlineRecording#"
		.. escape(recording)
		.. "%#SlimlineBase# "
		.. section(items, math.max(active, 1), available, active)
		.. "%#SlimlineBase#%="
		.. right
end

return M
