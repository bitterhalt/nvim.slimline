local M = {}

--- Escape `%` so arbitrary text can be embedded in a statusline expression.
---@param text any
---@return string
function M.escape(text)
	return (tostring(text):gsub("%%", "%%%%"))
end

--- Display width of `text` in terminal cells.
---@param text string
---@return integer
function M.width(text)
	return vim.fn.strdisplaywidth(text)
end

--- Truncate `text` to `space` display cells, ending in an ellipsis when cut.
---@param text string
---@param space integer
---@return string
function M.truncate(text, space)
	if M.width(text) <= space then
		return text
	end
	if space <= 0 then
		return ""
	end
	local result = ""
	for char in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
		if M.width(result .. char .. "…") > space then
			break
		end
		result = result .. char
	end
	return result .. "…"
end

--- Redraw the statusline, and the tabline when buffers are shown there.
function M.redraw()
	pcall(vim.cmd, "redrawstatus")
	-- Tabline click-target storage is not initialized before VimEnter.
	if vim.v.vim_did_enter == 1 and require("slimline.config").options.buffers.position == "top" then
		pcall(vim.cmd, "redrawtabline")
	end
end

return M
