-- Slimline: one native statusline for mode, buffers and cursor.
-- Optional dependency: nvim-web-devicons.
local M = {}
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
	local normal = group("Normal")
	local bg = normal.bg or "NONE"
	local fg = terminal_color(7, normal.fg or "NONE")
	local muted = terminal_color(8, fg)
	vim.api.nvim_set_hl(0, "SlimlineBase", { bg = bg, fg = muted, ctermfg = 8 })
	vim.api.nvim_set_hl(0, "SlimlineText", { bg = bg, fg = fg, ctermfg = 7 })
	vim.api.nvim_set_hl(0, "SlimlineActive", { bg = bg, fg = fg, ctermfg = 7, bold = true })
	vim.api.nvim_set_hl(0, "SlimlineError", { bg = bg, fg = terminal_color(1, fg), ctermfg = 1 })
	vim.api.nvim_set_hl(0, "SlimlineWarning", { bg = bg, fg = terminal_color(3, fg), ctermfg = 3 })
	vim.api.nvim_set_hl(0, "SlimlineGit", { bg = bg, fg = terminal_color(6, fg), ctermfg = 6 })
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
	local icon = devicons.get_icon(name, nil, { default = false })
	if not icon and ft and ft ~= "" then
		icon = devicons.get_icon_by_filetype(ft, { default = true })
	end
	if not icon then
		icon = devicons.get_icon(name, nil, { default = true })
	end
	return icon and (icon .. " ") or ""
end

local function buffers()
	local result = {}
	local options = config.options.buffers
	if not options.enabled then
		return result
	end
	local function included(buf)
		return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
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
			local icon = icon_for(name, vim.bo[buf].filetype)
			if path ~= "" and counts[name] > 1 then
				-- Keep the filename and its distinguishing parent path intact.
				name = vim.fn.fnamemodify(path, ":~:.")
			elseif path == "" and counts[""] > 1 then
				name = name .. " " .. buf
			else
				name = truncate(name, options.max_name_length)
			end
			local modified = vim.bo[buf].modified and options.modified_icon ~= "" and (" " .. options.modified_icon) or ""
			local label = " " .. icon .. name .. modified .. " "
			local close = options.close_icon ~= "" and (options.close_icon .. " ") or ""
			result[#result + 1] = { buf = buf, label = label, width = width(label .. close) }
		end
	end
	return result
end

-- Find the largest contiguous buffer viewport that contains the current buffer.
-- Reserve width for the number of hidden buffers on either side.
local function visible_range(items, active, space)
	local n = #items
	if n == 0 or space <= 0 then
		return nil
	end

	local prefix = { [0] = 0 }
	for i = 1, n do
		prefix[i] = prefix[i - 1] + items[i].width
	end

	local function marker_width(first, last)
		local w = 0
		if first > 1 then
			w = w + width(" <" .. (first - 1) .. " ")
		end
		if last < n then
			w = w + width(" " .. (n - last) .. "> ")
		end
		return w
	end

	local best_first, best_last, best_count = nil, nil, 0
	local best_distance = math.huge

	-- Moving the start right can only free space, so the end never moves back.
	local last = active - 1
	for first = 1, active do
		while last < n do
			local candidate = last + 1
			local used = prefix[candidate] - prefix[first - 1] + marker_width(first, candidate)
			if used > space then
				break
			end
			last = candidate
		end
		if last >= active then
			local count = last - first + 1
			local distance = math.abs((first + last) / 2 - active)
			if count > best_count or (count == best_count and distance < best_distance) then
				best_first, best_last, best_count, best_distance = first, last, count, distance
			end
		end
	end

	return best_first, best_last
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
	local available, bufdelete = pcall(require, "bufdelete")
	local ok, err
	if available then
		ok, err = pcall(bufdelete.bufdelete, buf, false)
	else
		ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = false })
	end
	if not ok then
		vim.notify(tostring(err), vim.log.levels.WARN, { title = "Slimline" })
	end
end

local function buffer_label(item, style, available)
	local icon = config.options.buffers.close_icon
	local close = icon ~= "" and (icon .. " ") or ""
	local label = item.label
	if available then
		-- Keep a close target when there is also room for a useful label.
		if available < width(close) + 2 then
			close = ""
		end
		label = truncate(label, available - width(close))
	end
	local result = "%#" .. style .. "#%" .. item.buf .. "@v:lua.SlimlineClick@" .. escape(label) .. "%T"
	if close ~= "" then
		result = result .. "%" .. item.buf .. "@v:lua.SlimlineClose@" .. escape(close) .. "%T"
	end
	return result
end

local function buffer_section(items, active, available, selected)
	local first, last = visible_range(items, active, available)
	if not first then
		local item = items[active]
		if not item or available <= 0 then
			return ""
		end
		local style = selected == active and "SlimlineActive" or "SlimlineBase"
		return buffer_label(item, style, available)
	end
	local parts = {}
	if first > 1 then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(" <" .. (first - 1) .. " ")
	end
	for i = first, last do
		local item = items[i]
		local style = (i == selected) and "SlimlineActive" or "SlimlineBase"
		parts[#parts + 1] = buffer_label(item, style)
	end
	if last < #items then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(" " .. (#items - last) .. "> ")
	end
	return table.concat(parts)
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
	local right = options.cursor.enabled and (" " .. line .. ":" .. col
		.. (options.cursor.progress and (options.cursor.separator .. progress .. "%") or "") .. " ") or ""
	local left = options.mode.enabled and (" " .. mode_label .. " ") or ""
	local branch = git.label()
	local git_label = branch ~= "" and (" " .. (options.git.icon ~= "" and (options.git.icon .. " ") or "")
		.. truncate(branch, options.git.max_length)) or ""
	local diagnostics = {}
	local diagnostic_width = 0
	for _, entry in ipairs({
		{ severity = vim.diagnostic.severity.ERROR, symbol = options.diagnostics.error, style = "SlimlineError" },
		{ severity = vim.diagnostic.severity.WARN, symbol = options.diagnostics.warn, style = "SlimlineWarning" },
	}) do
		local count = options.diagnostics.enabled and #vim.diagnostic.get(current, { severity = entry.severity }) or 0
		if count > 0 then
			local label = " " .. entry.symbol .. " " .. count
			diagnostics[#diagnostics + 1] = "%#" .. entry.style .. "#" .. escape(label)
			diagnostic_width = diagnostic_width + width(label)
		end
	end
	local items = buffers()
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
	local available = vim.o.columns - width(left) - width(right) - width(git_label) - diagnostic_width - 2
	return "%#"
		.. mode_style(mode)
		.. "#"
		.. escape(left)
		.. "%#SlimlineBase# "
		.. buffer_section(items, anchor, available, active)
		.. "%="
		.. "%#SlimlineGit#"
		.. escape(git_label)
		.. table.concat(diagnostics)
		.. "%#SlimlineText#"
		.. escape(right)
end

function M.setup(options)
	config.setup(options)
	_G.SlimlineClick = M.click
	_G.SlimlineClose = M.close
	_G.SlimlineRender = M.render
	vim.opt.laststatus = 3
	vim.opt.showtabline = 0
	vim.opt.statusline = "%!v:lua.SlimlineRender()"
	local augroup = vim.api.nvim_create_augroup("Slimline", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = augroup, callback = set_colors })
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
	set_colors()
	git.refresh()
end

return M
