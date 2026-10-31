-- Slimline: one native statusline for mode, buffers, filetype and cursor.
-- Optional dependency: nvim-web-devicons.
local M = {}

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

local function set_colors()
	local normal, comment, visual, status = group("Normal"), group("Comment"), group("Visual"), group("StatusLine")
	local bg = status.bg or normal.bg or 0x181818
	local fg = normal.fg or 0xdddddd
	local muted = comment.fg or fg
	vim.api.nvim_set_hl(0, "SlimlineBase", { bg = bg, fg = muted })
	vim.api.nvim_set_hl(0, "SlimlineText", { bg = bg, fg = fg })
	vim.api.nvim_set_hl(0, "SlimlineActive", { bg = visual.bg or fg, fg = visual.fg or bg, bold = true })
	vim.api.nvim_set_hl(0, "SlimlineMode", { bg = fg, fg = bg, bold = true })
end

local function escape(s)
	return tostring(s):gsub("%%", "%%%%")
end

local function width(s)
	return vim.fn.strdisplaywidth(s)
end

local function icon_for(name, ft)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end
	local icon = devicons.get_icon(name, nil, { default = true })
	if not icon and ft then
		icon = devicons.get_icon_by_filetype(ft, { default = true })
	end
	return icon and (icon .. " ") or ""
end

local function buffers()
	local result = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
			local path = vim.api.nvim_buf_get_name(buf)
			local name = path == "" and "[No Name]" or vim.fn.fnamemodify(path, ":t")
			if vim.fn.strchars(name) > 20 then
				name = vim.fn.strcharpart(name, 0, 17) .. "…"
			end
			local label = " "
				.. icon_for(name, vim.bo[buf].filetype)
				.. name
				.. (vim.bo[buf].modified and " *" or "")
				.. " "
			result[#result + 1] = { buf = buf, label = label, width = width(label) }
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

	-- For each possible start, choose the furthest end that fits.
	-- The list is small in normal use; this remains straightforward and predictable.
	for first = 1, active do
		for last = active, n do
			local used = prefix[last] - prefix[first - 1] + marker_width(first, last)
			if used <= space then
				local count = last - first + 1
				local distance = math.abs((first + last) / 2 - active)
				if count > best_count or (count == best_count and distance < best_distance) then
					best_first, best_last, best_count, best_distance = first, last, count, distance
				end
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

local function buffer_section(items, active, available)
	local first, last = visible_range(items, active, available)
	if not first then
		return ""
	end
	local parts = {}
	if first > 1 then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(" <" .. (first - 1) .. " ")
	end
	for i = first, last do
		local item = items[i]
		local style = (i == active) and "SlimlineActive" or "SlimlineBase"
		parts[#parts + 1] = "%#" .. style .. "#%" .. item.buf .. "@v:lua.SlimlineClick@" .. escape(item.label) .. "%T"
	end
	if last < #items then
		parts[#parts + 1] = "%#SlimlineBase#" .. escape(" " .. (#items - last) .. "> ")
	end
	return table.concat(parts)
end

function M.render()
	local current = vim.api.nvim_get_current_buf()
	local mode = modes[vim.api.nvim_get_mode().mode] or "N"
	local filetype = vim.bo[current].filetype
	if filetype == "" then
		filetype = "text"
	end
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(current), ":t")
	local ft_icon = icon_for(name, filetype)
	local line, col = vim.fn.line("."), vim.fn.col(".")
	local total = math.max(vim.fn.line("$"), 1)
	local progress = math.floor(100 * line / total)
	local right = " " .. ft_icon .. filetype .. "  │  " .. line .. ":" .. col .. "  │  " .. progress .. "% "
	local left = " " .. mode .. " "
	local items = buffers()
	local active = 1
	for i, item in ipairs(items) do
		if item.buf == current then
			active = i
			break
		end
	end
	-- Global statusline uses the editor's full width, not just the active split.
	local available = vim.o.columns - width(left) - width(right) - 2
	return "%#SlimlineMode#"
		.. escape(left)
		.. "%#SlimlineBase# "
		.. buffer_section(items, active, available)
		.. "%="
		.. "%#SlimlineText#"
		.. escape(right)
end

function M.setup()
	_G.SlimlineClick = M.click
	vim.opt.laststatus = 3
	vim.opt.showtabline = 0
	vim.opt.statusline = "%!v:lua.require'custom.slimline'.render()"
	local augroup = vim.api.nvim_create_augroup("Slimline", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = augroup, callback = set_colors })
	set_colors()
end

return M
