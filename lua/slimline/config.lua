local M = {}

M.defaults = {
	icons = true,
	mode = { enabled = true, labels = {} },
	recording = { icon = "REC" },
	encoding = { enabled = true },
	buffers = {
		enabled = true,
		position = "bottom",
		max_name_length = 15,
		min_width = 15,
		close_icon = "×",
		modified_icon = "*",
		exclude_filetypes = {},
		exclude_buftypes = {},
	},
	diagnostics = { enabled = true, error = "E!", warn = "W!" },
	git = { enabled = true, icon = "", max_length = 24 },
	cursor = { enabled = true, separator = " | ", progress = true },
	highlights = {},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(options)
	options = options or {}
	vim.validate({ options = { options, "table" } })
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options)
	if not (options.buffers and options.buffers.max_name_length ~= nil) then
		merged.buffers.max_name_length = merged.buffers.min_width
	end
	local function validate(value, default, path)
		for key, item in pairs(value) do
			local expected = default[key]
			assert(expected ~= nil, "Slimline: unknown option " .. path .. key)
			assert(type(item) == type(expected), "Slimline: invalid type for " .. path .. key)
			if type(item) == "table" and next(expected) then
				validate(item, expected, path .. key .. ".")
			end
		end
	end
	validate(merged, M.defaults, "")
	assert(merged.buffers.position == "top" or merged.buffers.position == "bottom",
		"Slimline: buffers.position must be 'top' or 'bottom'")
	for _, key in ipairs({ "max_name_length", "min_width" }) do
		local value = merged.buffers[key]
		assert(value >= 1 and value == math.floor(value), "Slimline: buffers." .. key .. " must be a positive integer")
	end
	local length = merged.git.max_length
	assert(length >= 1 and length == math.floor(length), "Slimline: git.max_length must be a positive integer")
	for _, key in ipairs({ "exclude_filetypes", "exclude_buftypes" }) do
		assert(vim.islist(merged.buffers[key]), "Slimline: buffers." .. key .. " must be a list")
		for _, value in ipairs(merged.buffers[key]) do
			assert(type(value) == "string", "Slimline: buffers." .. key .. " entries must be strings")
		end
	end
	for key, value in pairs(merged.mode.labels) do
		assert(
			type(key) == "string" and type(value) == "string",
			"Slimline: mode.labels must map mode codes to strings"
		)
	end
	for name, value in pairs(merged.highlights) do
		assert(
			type(name) == "string" and name:match("^Slimline") and type(value) == "table",
			"Slimline: highlights must map Slimline group names to highlight tables"
		)
	end
	M.options = merged
end

return M
