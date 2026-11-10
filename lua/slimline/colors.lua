local config = require("slimline.config")

local M = {}

---@type table<string, string>
local icon_groups = {}

--- Resolved attributes of a highlight group (links followed).
---@param name string
---@return table
function M.get(name)
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

local function diagnostic_color(custom, index, fallback)
	if type(custom) == "string" and custom ~= "" then
		return custom
	end
	return terminal_color(index, fallback)
end

local mode_colors = {
	Normal = 6,
	Insert = 2,
	Visual = 5,
	Replace = 1,
	Command = 3,
	Terminal = 4,
}

local mode_categories = {
	I = "Insert",
	V = "Visual",
	S = "Visual",
	R = "Replace",
	C = "Command",
	T = "Terminal",
	["!"] = "Terminal",
	M = "Command",
	P = "Command",
	["?"] = "Command",
}

--- Highlight group for a short mode code such as "N", "VL" or "R".
---@param code string
---@return string
function M.mode_group(code)
	return "SlimlineMode" .. (mode_categories[code:sub(1, 1)] or "Normal")
end

--- Define every Slimline group, then apply the user's overrides.
function M.apply()
	icon_groups = {}
	local normal = M.get("Normal")
	local bg = normal.bg or "NONE"
	local fg = terminal_color(7, normal.fg or "NONE")
	local muted = terminal_color(8, fg)
	local set = function(name, value)
		vim.api.nvim_set_hl(0, name, value)
	end

	set("SlimlineBase", { bg = bg, fg = muted, ctermfg = 8 })
	set("SlimlineText", { bg = bg, fg = fg, ctermfg = 7 })
	set("SlimlineActive", { bg = bg, fg = terminal_color(6, fg), ctermfg = 6, bold = true })
	set("SlimlineSingle", { bg = bg, fg = fg, ctermfg = 7, bold = true })
	set("SlimlineClose", { bg = bg, fg = fg, ctermfg = 7 })
	set("SlimlineModified", { bg = bg, fg = terminal_color(2, fg), ctermfg = 2, bold = true })
	local diagnostic_colors = config.options.diagnostics.colors
	set("SlimlineError", { bg = bg, fg = diagnostic_color(diagnostic_colors.error, 1, fg), ctermfg = 1 })
	set("SlimlineWarning", { bg = bg, fg = diagnostic_color(diagnostic_colors.warn, 3, fg), ctermfg = 3 })
	set("SlimlineGit", { bg = bg, fg = terminal_color(6, fg), ctermfg = 6 })
	set("SlimlineRecording", { bg = bg, fg = terminal_color(1, fg), ctermfg = 1, bold = true })
	for name, index in pairs(mode_colors) do
		set("SlimlineMode" .. name, {
			bg = terminal_color(index, fg),
			fg = terminal_color(0, normal.bg or "NONE"),
			ctermbg = index,
			ctermfg = 0,
			bold = true,
		})
	end

	-- The pin follows the error color by default. The link is created before the
	-- user's overrides so that `highlights.SlimlinePin` can replace it.
	set("SlimlinePin", { link = "SlimlineError" })

	-- Sorted so that dependent groups (SlimlinePin reads SlimlineError) resolve
	-- deterministically regardless of table iteration order.
	local names = vim.tbl_keys(config.options.highlights)
	table.sort(names)
	for _, name in ipairs(names) do
		local override = config.options.highlights[name]
		set(name, override.link and override or vim.tbl_extend("force", M.get(name), override))
	end
end

--- Highlight group that draws a devicons glyph on top of a buffer style.
--- Created lazily and cached until the next colorscheme change.
---@param source string devicons highlight group
---@param style string Slimline style group (active, single, base)
---@return string
function M.icon_group(source, style)
	local key = source .. style
	local name = icon_groups[key]
	if not name then
		local icon, base = M.get(source), M.get(style)
		name = "SlimlineIcon" .. key
		vim.api.nvim_set_hl(0, name, {
			fg = icon.fg or base.fg,
			ctermfg = icon.ctermfg or base.ctermfg,
			bg = base.bg or "NONE",
			bold = base.bold,
		})
		icon_groups[key] = name
	end
	return name
end

return M
