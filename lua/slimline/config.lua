local M = {}

---@class slimline.ModeConfig
---@field enabled? boolean
---@field labels? table<string, string> Neovim mode code -> displayed label
---@field hide_showmode? boolean Set 'noshowmode' while the mode indicator is enabled

---@class slimline.BuffersConfig
---@field enabled? boolean
---@field position? "bottom"|"top"
---@field max_name_length? integer Follows `min_width` when omitted
---@field min_width? integer Fixed buffer slot width in columns
---@field close_icon? string Empty string hides the close button
---@field modified_icon? string Empty string hides the modified marker
---@field keep_layout? boolean Switch windows to another buffer before closing, so splits survive
---@field persist_pins? boolean Store pins in `g:SlimlinePins` so sessions can restore them
---@field exclude_filetypes? string[]
---@field exclude_buftypes? string[]

---@class slimline.DiagnosticsConfig
---@field enabled? boolean
---@field error? string
---@field warn? string
---@field colors? { error?: string, warn?: string }

---@class slimline.GitConfig
---@field enabled? boolean
---@field icon? string
---@field max_length? integer

---@class slimline.CursorConfig
---@field enabled? boolean
---@field separator? string Shared by every right-hand section
---@field progress? boolean
---@field virtual_column? boolean Show the screen column instead of the byte column

---@class slimline.Config
---@field icons? boolean
---@field mode? slimline.ModeConfig
---@field recording? { icon?: string }
---@field encoding? { enabled?: boolean }
---@field search? { enabled?: boolean } Show `current/total` while 'hlsearch' is active
---@field buffers? slimline.BuffersConfig
---@field diagnostics? slimline.DiagnosticsConfig
---@field git? slimline.GitConfig
---@field cursor? slimline.CursorConfig
---@field highlights? table<string, vim.api.keyset.highlight>

---@type slimline.Config
M.defaults = {
	icons = true,
	mode = { enabled = true, labels = {}, hide_showmode = true },
	recording = { icon = "REC" },
	encoding = { enabled = true },
	search = { enabled = false },
	buffers = {
		enabled = true,
		position = "bottom",
		max_name_length = 15,
		min_width = 15,
		close_icon = "×",
		modified_icon = "*",
		keep_layout = true,
		persist_pins = false,
		exclude_filetypes = {},
		exclude_buftypes = {},
	},
	diagnostics = { enabled = true, error = "E!", warn = "W!", colors = {} },
	git = { enabled = true, icon = "\u{e725}", max_length = 24 },
	cursor = { enabled = true, separator = " | ", progress = true, virtual_column = false },
	highlights = {},
}

---@type slimline.Config
M.options = vim.deepcopy(M.defaults)

local function fail(message)
	error("Slimline: " .. message, 0)
end

local function positive_integer(value)
	return type(value) == "number" and value >= 1 and value == math.floor(value)
end

local function check_types(value, default, path)
	for key, item in pairs(value) do
		local name = path .. tostring(key)
		local expected = default[key]
		if expected == nil then
			fail("unknown option " .. name)
		end
		if type(item) ~= type(expected) then
			local hint = ""
			if type(expected) == "table" and expected.enabled ~= nil then
				hint = " (use " .. name .. ".enabled = false to hide it)"
			end
			fail(("invalid type for %s: expected %s, got %s%s"):format(name, type(expected), type(item), hint))
		end
		if type(item) == "table" and next(expected) then
			check_types(item, expected, name .. ".")
		end
	end
end

--- Merge `options` into the defaults and validate the result.
--- Raises an error describing the first problem found.
---@param options? slimline.Config
---@return slimline.Config
function M.resolve(options)
	options = options or {}
	if type(options) ~= "table" then
		fail("setup() expects a table")
	end
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options)
	check_types(merged, M.defaults, "")

	if merged.buffers.position ~= "top" and merged.buffers.position ~= "bottom" then
		fail("buffers.position must be 'top' or 'bottom'")
	end
	-- min_width is validated before max_name_length, which follows it by default,
	-- so the error names the option the user actually set.
	if not positive_integer(merged.buffers.min_width) then
		fail("buffers.min_width must be a positive integer")
	end
	if not (options.buffers and options.buffers.max_name_length ~= nil) then
		merged.buffers.max_name_length = merged.buffers.min_width
	end
	if not positive_integer(merged.buffers.max_name_length) then
		fail("buffers.max_name_length must be a positive integer")
	end
	if not positive_integer(merged.git.max_length) then
		fail("git.max_length must be a positive integer")
	end
	for _, key in ipairs({ "exclude_filetypes", "exclude_buftypes" }) do
		if not vim.islist(merged.buffers[key]) then
			fail("buffers." .. key .. " must be a list")
		end
		for _, value in ipairs(merged.buffers[key]) do
			if type(value) ~= "string" then
				fail("buffers." .. key .. " entries must be strings")
			end
		end
	end
	for key, value in pairs(merged.mode.labels) do
		if type(key) ~= "string" or type(value) ~= "string" then
			fail("mode.labels must map mode codes to strings")
		end
	end
	for name, value in pairs(merged.highlights) do
		if type(name) ~= "string" or not name:match("^Slimline") or type(value) ~= "table" then
			fail("highlights must map Slimline group names to highlight tables")
		end
	end
	for key, value in pairs(merged.diagnostics.colors) do
		if key ~= "error" and key ~= "warn" then
			fail("diagnostics.colors must use 'error' or 'warn'")
		end
		if type(value) ~= "string" then
			fail("diagnostics.colors." .. key .. " must be a string")
		end
	end
	return merged
end

--- Apply user options. On invalid input the defaults are used instead of
--- aborting startup; the problem is returned so the caller can report it.
---@param options? slimline.Config
---@return boolean ok
---@return string? err
function M.setup(options)
	local ok, result = pcall(M.resolve, options)
	if not ok then
		M.options = vim.deepcopy(M.defaults)
		return false, tostring(result)
	end
	M.options = result
	return true
end

return M
