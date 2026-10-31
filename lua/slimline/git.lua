local M = {}
local cache = {}
local config = require("slimline.config")

function M.directory()
	if vim.bo.buftype ~= "" then
		return nil
	end
	local name = vim.api.nvim_buf_get_name(0)
	return name == "" and vim.fn.getcwd() or vim.fn.fnamemodify(name, ":h")
end

function M.label()
	if not config.options.git.enabled then
		return ""
	end
	local directory = M.directory()
	local entry = directory and cache[directory]
	return entry and entry.label or ""
end

function M.refresh()
	if not config.options.git.enabled then
		return
	end
	local directory = M.directory()
	if not directory or vim.fn.executable("git") ~= 1 then
		return
	end
	local entry = cache[directory] or { label = "" }
	cache[directory] = entry
	if entry.pending then
		return
	end
	entry.pending = true
	vim.system({ "git", "-C", directory, "symbolic-ref", "--quiet", "--short", "HEAD" }, { text = true }, function(result)
		local branch = result.code == 0 and vim.trim(result.stdout or "") or ""
		local function finish(label)
			vim.schedule(function()
				entry.label = label
				entry.pending = false
				vim.cmd("redrawstatus")
			end)
		end
		if result.code == 1 then
			vim.system({ "git", "-C", directory, "rev-parse", "--short", "HEAD" }, { text = true }, function(commit)
				finish(commit.code == 0 and ("@" .. vim.trim(commit.stdout or "")) or "")
			end)
		else
			finish(branch)
		end
	end)
end

return M
