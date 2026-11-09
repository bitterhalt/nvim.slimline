-- Slimline: one native statusline for mode, buffers and cursor.
-- Optional dependency: nvim-web-devicons.
local M = {}
local icon_highlights = {}
local config = require("slimline.config")
local git = require("slimline.git")

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
	r = "R",
	rm = "M",
	["r?"] = "?",
	t = "T",
	["!"] = "!",
}

local function group(name)
	local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	return ok and value or {}
end

local function terminal_color(index, fallback)
	local color = vim.g["terminal_color_" .. index]
	if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
		return color
	end
	return fallback
end

local function set_colors()
	icon_highlights = {}
	local normal = group("Normal")
	local bg = normal.bg or "NONE"
	local fg = terminal_color(7, normal.fg or "NONE")
	local muted = terminal_color(8, fg)
	vim.api.nvim_set_hl(0, "SlimlineBase", { bg = bg, fg = muted, ctermfg = 8 })
	vim.api.nvim_set_hl(0, "SlimlineText", { bg = bg, fg = fg, ctermfg = 7 })
	vim.api.nvim_set_hl(0, "SlimlineActive", {
		bg = bg,
		fg = terminal_color(6, fg),
		ctermfg = 6,
		bold = true,
	})
	vim.api.nvim_set_hl(0, "SlimlineSingle", { bg = bg, fg = fg, ctermfg = 7, bold = true })
	vim.api.nvim_set_hl(0, "SlimlineClose", { bg = bg, fg = fg, ctermfg = 7 })
	vim.api.nvim_set_hl(0, "SlimlineModified", { bg = bg, fg = terminal_color(2, fg), ctermfg = 2, bold = true })
	vim.api.nvim_set_hl(0, "SlimlineError", { bg = bg, fg = "#cc241d", ctermfg = 196 })
	vim.api.nvim_set_hl(0, "SlimlineWarning", { bg = bg, fg = "#d79921", ctermfg = 220 })
	vim.api.nvim_set_hl(0, "SlimlineGit", { bg = bg, fg = terminal_color(6, fg), ctermfg = 6 })
	vim.api.nvim_set_hl(0, "SlimlineRecording", { bg = bg, fg = terminal_color(1, fg), ctermfg = 1, bold = true })
	local colors = {
		Normal = 6,
		Insert = 2,
		Visual = 5,
		Replace = 1,
		Command = 3,
		Terminal = 4,
	}
	for name, index in pairs(colors) do
		vim.api.nvim_set_hl(0, "SlimlineMode" .. name, {
			bg = terminal_color(index, fg),
			fg = terminal_color(0, normal.bg or "NONE"),
			ctermbg = index,
			ctermfg = 0,
			bold = true,
		})
	end
	for name, override in pairs(config.options.highlights) do
		local value = override.link and override or vim.tbl_extend("force", group(name), override)
		vim.api.nvim_set_hl(0, name, value)
	end
	vim.api.nvim_set_hl(0, "SlimlinePin", { link = "SlimlineError" })
end

local function mode_style(mode)
	local first = mode:sub(1, 1)
	local category = ({
		I = "Insert",
		V = "Visual",
		S = "Visual",
		R = "Replace",
		C = "Command",
		T = "Terminal",
		["!"] = "Terminal",
		M = "Command",
		["?"] = "Command",
	})[first]
	return "SlimlineMode" .. (category or "Normal")
end

local function escape(s)
	return tostring(s):gsub("%%", "%%%%")
end

local function width(s)
	return vim.fn.strdisplaywidth(s)
end

local function truncate(text, space)
	if width(text) <= space then
		return text
	end
	if space <= 0 then
		return ""
	end
	local result = ""
	for char in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
		if width(result .. char .. "…") > space then
			break
		end
		result = result .. char
	end
	return result .. "…"
end

local function icon_for(name, ft)
	if not config.options.icons then
		return ""
	end
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end
	local icon, highlight = devicons.get_icon(name, nil, { default = false })
	if not icon and ft and ft ~= "" then
		icon, highlight = devicons.get_icon_by_filetype(ft, { default = false })
	end
	return icon and (icon .. "  ") or "", highlight
end

local function buffers()
	local result = {}
	local options = config.options.buffers
	if not options.enabled then
		return result
	end
	local function included(buf)
		return vim.api.nvim_buf_is_valid(buf)
			and vim.bo[buf].buflisted
			and not vim.tbl_contains(options.exclude_filetypes, vim.bo[buf].filetype)
			and not vim.tbl_contains(options.exclude_buftypes, vim.bo[buf].buftype)
	end
	local counts = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if included(buf) then
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
			counts[name] = (counts[name] or 0) + 1
		end
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if included(buf) then
			local path = vim.api.nvim_buf_get_name(buf)
			local name = path == "" and "[No Name]" or vim.fn.fnamemodify(path, ":t")
			local icon, icon_highlight = icon_for(name, vim.bo[buf].filetype)
			if path ~= "" and counts[name] > 1 then
				-- Keep the filename and its distinguishing parent path intact.
				name = vim.fn.fnamemodify(path, ":~:.")
			elseif path == "" and counts[""] > 1 then
				name = name .. " " .. buf
			else
				name = truncate(name, options.max_name_length)
			end
			local modified = vim.bo[buf].modified and options.modified_icon ~= "" and (" " .. options.modified_icon)
				or ""
			local pin = vim.b[buf].slimline_pinned and "  " or ""
			local label = " " .. pin .. icon .. name .. modified .. " "
			local close = buf ~= vim.api.nvim_get_current_buf()
					and not vim.bo[buf].modified
					and options.close_icon ~= ""
					and (options.close_icon .. " ")
				or ""
			result[#result + 1] = {
				buf = buf,
				label = label,
				name = " " .. pin .. icon .. name,
				pin = pin,
				modified = modified,
				close = close,
				icon = icon,
				icon_highlight = icon_highlight,
			}
		end
	end
	table.sort(result, function(a, b)
		if (a.pin ~= "") ~= (b.pin ~= "") then
			return a.pin ~= ""
		end
		return a.buf < b.buf
	end)
	return result
end

local function redraw_tabline()
	-- Tabline click-target storage is not initialized before VimEnter.
	if vim.v.vim_did_enter == 1 then
		vim.cmd("redrawtabline")
	end
end

function M.toggle_buffers()
	config.options.buffers.enabled = not config.options.buffers.enabled
	if config.options.buffers.position == "top" then
		vim.o.showtabline = config.options.buffers.enabled and 2 or 0
	end
	vim.cmd("redrawstatus")
	redraw_tabline()
end

function M.toggle_pin()
	local current = vim.api.nvim_get_current_buf()
	for _, item in ipairs(buffers()) do
		if item.buf == current then
			vim.b[current].slimline_pinned = not vim.b[current].slimline_pinned
			vim.cmd("redrawstatus")
			redraw_tabline()
			return
		end
	end
end

function M.next_pin()
	local pinned = {}
	local current = vim.api.nvim_get_current_buf()
	local index = 0
	for _, item in ipairs(buffers()) do
		if item.pin ~= "" then
			pinned[#pinned + 1] = item.buf
			if item.buf == current then
				index = #pinned
			end
		end
	end
	if #pinned > 0 then
		vim.api.nvim_set_current_buf(pinned[index % #pinned + 1])
	end
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

function M.click(buf, _, button, _)
	if button == "l" and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_set_current_buf(buf)
	end
end

function M.close(buf, _, button, _)
	if button ~= "l" or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = false })
	if not ok then
		vim.notify(tostring(err), vim.log.levels.WARN, { title = "Slimline" })
	end
end

local function colored_name(text, item, style)
	local result = ""
	local prefix = " " .. item.pin
	local pinned = item.pin ~= "" and text:sub(1, #prefix) == prefix
	if pinned then
		result = "%#SlimlinePin#" .. escape(prefix) .. "%#" .. style .. "#"
		text = text:sub(#prefix + 1)
	end
	prefix = (pinned and "" or " ") .. item.icon
	if item.icon == "" or not item.icon_highlight or text:sub(1, #prefix) ~= prefix then
		return result .. escape(text)
	end
	local key = item.icon_highlight .. style
	local highlight = icon_highlights[key]
	if not highlight then
		local source, base = group(item.icon_highlight), group(style)
		highlight = "SlimlineIcon" .. key
		vim.api.nvim_set_hl(0, highlight, {
			fg = source.fg or base.fg,
			ctermfg = source.ctermfg or base.ctermfg,
			bg = base.bg or "NONE",
			bold = base.bold,
		})
		icon_highlights[key] = highlight
	end
	return result .. (pinned and "" or " ") .. "%#" .. highlight .. "#" .. escape(item.icon) .. "%#" .. style .. "#" .. escape(text:sub(#prefix + 1))
end

local function buffer_label(item, style, available)
	local close = item.close
	local label = item.label
	local focused = style == "SlimlineActive" or style == "SlimlineSingle"
	local modified = item.modified
	local name = item.name
	if available then
		-- Keep a close target when there is also room for a useful label.
		if available < width(close) + 2 then
			close = ""
		end
		if modified ~= "" and available - width(close) > width(modified) + 1 then
			name = truncate(name, available - width(close) - width(modified) - 1)
			label = name .. modified .. " "
		else
			local budget = available - width(close)
			label = budget > 1 and (truncate(item.name, budget - 1) .. " ") or truncate(label, budget)
			modified = ""
		end
	end
	local text = colored_name(label, item, style)
	if focused and modified ~= "" then
		text = colored_name(name, item, style) .. "%#SlimlineModified#" .. escape(modified) .. "%#" .. style .. "# "
	end
	if available then
		text = text .. string.rep(" ", math.max(0, available - width(label) - width(close)))
	end
	local result = "%#" .. style .. "#%" .. item.buf .. "@v:lua.SlimlineClick@" .. text .. "%T"
	if close ~= "" then
		result = result
			.. "%#"
			.. (focused and "SlimlineClose" or "SlimlineBase")
			.. "#%"
			.. item.buf
			.. "@v:lua.SlimlineClose@"
			.. escape(close)
			.. "%T"
	end
	return result
end

local function buffer_viewport(items, active, available, selected, active_style)
	active_style = active_style or (#items == 1 and "SlimlineSingle" or "SlimlineActive")
	local first, last, space, left, right = visible_range(items, active, available)
	if not first then
		local item = items[active]
		if not item or available <= 0 then
			return ""
		end
		local style = selected == active and active_style or "SlimlineBase"
		return buffer_label(item, style, available)
	end
	local parts = {}
	if first > 1 then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(left)
	end
	local slot = math.min(config.options.buffers.min_width, space)
	for i = first, last do
		local item = items[i]
		local style = (i == selected) and active_style or "SlimlineBase"
		parts[#parts + 1] = buffer_label(item, style, slot)
	end
	if last < #items then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(right)
	end
	return table.concat(parts)
end

local function buffer_section(items, active, available, selected)
	local pinned_count = 0
	for _, item in ipairs(items) do
		if item.pin == "" then
			break
		end
		pinned_count = pinned_count + 1
	end
	if pinned_count == 0 or pinned_count == #items or available <= 0 then
		return buffer_viewport(items, active, available, selected)
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
	return buffer_viewport(pinned, math.max(1, pin_selected), pin_space, pin_selected, "SlimlineActive")
		.. buffer_viewport(regular, math.max(1, regular_selected), available - pin_space,
			regular_selected, "SlimlineActive")
end

function M.render_tabline()
	if config.options.buffers.position ~= "top" or not config.options.buffers.enabled then
		return ""
	end
	local items = buffers()
	local selected = 0
	local current = vim.api.nvim_get_current_buf()
	for i, item in ipairs(items) do
		if item.buf == current then
			selected = i
			break
		end
	end
	return "%#SlimlineBase# " .. buffer_section(items, math.max(1, selected), vim.o.columns - 1, selected)
		.. "%#SlimlineBase#%="
end

function M.render()
	local options = config.options
	local current = vim.api.nvim_get_current_buf()
	local raw_mode = vim.api.nvim_get_mode().mode
	local mode = modes[raw_mode] or "N"
	local mode_label = options.mode.labels[raw_mode] or mode
	local line, col = vim.fn.line("."), vim.fn.col(".")
	local total = math.max(vim.fn.line("$"), 1)
	local progress = math.floor(100 * line / total)
	local right = options.cursor.enabled
			and (" " .. line .. ":" .. col .. (options.cursor.progress and (options.cursor.separator .. progress .. "%") or "") .. " ")
		or ""
	local left = options.mode.enabled and (" " .. mode_label .. " ") or ""
	local register = vim.fn.reg_recording()
	local recording = register ~= "" and (" " .. options.recording.icon .. " @" .. register .. " ") or ""
	local encoding = options.encoding.enabled
			and (" " .. (vim.bo[current].fileencoding ~= "" and vim.bo[current].fileencoding or vim.o.encoding))
		or ""
	local branch = git.label()
	local git_label = branch ~= ""
			and (" " .. (options.git.icon ~= "" and (options.git.icon .. " ") or "") .. truncate(
				branch,
				options.git.max_length
			))
		or ""
	local sections = {}
	local right_width = 0
	local function section(label, style)
		if label ~= "" then
			sections[#sections + 1] = "%#" .. style .. "#" .. escape(label)
			right_width = right_width + width(label)
		end
	end
	section(git_label, "SlimlineGit")
	for _, entry in ipairs({
		{ severity = vim.diagnostic.severity.ERROR, symbol = options.diagnostics.error, style = "SlimlineError" },
		{ severity = vim.diagnostic.severity.WARN, symbol = options.diagnostics.warn, style = "SlimlineWarning" },
	}) do
		local count = options.diagnostics.enabled and #vim.diagnostic.get(current, { severity = entry.severity }) or 0
		if count > 0 then
			local label = " " .. entry.symbol .. " " .. count
			section(label, entry.style)
		end
	end
	section(encoding, "SlimlineText")
	section(right, "SlimlineText")
	-- Labels already include leading padding; use one shared separator everywhere.
	local separator = options.cursor.separator:gsub("%s$", "")
	right_width = right_width + math.max(#sections - 1, 0) * width(separator)
	local right_section = table.concat(sections, "%#SlimlineBase#" .. escape(separator))
	local items = options.buffers.position == "bottom" and buffers() or {}
	local active
	for i, item in ipairs(items) do
		if item.buf == current then
			active = i
			break
		end
	end
	-- Special/unlisted buffers have no selected entry in the buffer list.
	local anchor = active or 1
	if not active then
		-- A zero index keeps all listed entries inactive while retaining a viewport.
		active = 0
	end
	-- Global statusline uses the editor's full width, not just the active split.
	local available = vim.o.columns - width(left) - width(recording) - right_width - 2
	return "%#"
		.. mode_style(mode)
		.. "#"
		.. escape(left)
		.. "%#SlimlineRecording#"
		.. escape(recording)
		.. "%#SlimlineBase# "
		.. buffer_section(items, anchor, available, active)
		.. "%#SlimlineBase#%="
		.. right_section
end

function M.setup(options)
	config.setup(options)
	_G.SlimlineClick = M.click
	_G.SlimlineClose = M.close
	_G.SlimlineRender = M.render
	_G.SlimlineTabline = M.render_tabline
	vim.opt.laststatus = 3
	local top = config.options.buffers.position == "top"
	vim.opt.showtabline = top and config.options.buffers.enabled and 2 or 0
	if top then
		vim.opt.tabline = "%!v:lua.SlimlineTabline()"
	elseif vim.o.tabline == "%!v:lua.SlimlineTabline()" then
		vim.opt.tabline = ""
	end
	vim.opt.statusline = "%!v:lua.SlimlineRender()"
	local augroup = vim.api.nvim_create_augroup("Slimline", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = augroup, callback = set_colors })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete", "BufModifiedSet", "BufFilePost", "FileType" }, {
		group = augroup,
		callback = function()
			if config.options.buffers.position == "top" then
				vim.schedule(function()
					redraw_tabline()
				end)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "DirChanged", "FocusGained", "TermLeave" }, {
		group = augroup,
		callback = git.refresh,
	})
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = augroup,
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})
	vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
		group = augroup,
		callback = function()
			-- RecordingLeave fires before reg_recording() has been cleared.
			vim.schedule(function()
				vim.cmd("redrawstatus")
			end)
		end,
	})
	set_colors()
	git.refresh()
end

return M
