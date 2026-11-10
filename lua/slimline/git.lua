local config = require("slimline.config")

local M = {}

local MAX_ENTRIES = 64

---@class slimline.GitEntry
---@field label string
---@field pending? boolean

---@type table<string, slimline.GitEntry>
local cache = {}
local count = 0
local available

local function git_available()
	if available == nil then
		available = vim.fn.executable("git") == 1
	end
	return available
end

--- Directory used to look up the repository for the current buffer, or nil for
--- special buffers.
---@return string?
function M.directory()
	if vim.bo.buftype ~= "" then
		return nil
	end
	local name = vim.api.nvim_buf_get_name(0)
	return name == "" and vim.fn.getcwd() or vim.fs.dirname(name)
end

--- Cached label for the current buffer. Never runs git itself.
---@return string
function M.label()
	if not config.options.git.enabled then
		return ""
	end
	local directory = M.directory()
	local entry = directory and cache[directory]
	return entry and entry.label or ""
end

local function entry_for(directory)
	local entry = cache[directory]
	if not entry then
		-- Bound the cache so long sessions do not accumulate directories forever.
		if count >= MAX_ENTRIES then
			cache, count = {}, 0
		end
		entry = { label = "" }
		cache[directory] = entry
		count = count + 1
	end
	return entry
end

local function run(args, callback)
	local ok = pcall(vim.system, args, { text = true, env = { GIT_OPTIONAL_LOCKS = "0" } }, callback)
	return ok
end

--- Look up the branch for the current buffer asynchronously and redraw once
--- the label changes.
function M.refresh()
	if not config.options.git.enabled or not git_available() then
		return
	end
	local directory = M.directory()
	local stat = directory and vim.uv.fs_stat(directory)
	if not stat or stat.type ~= "directory" then
		return
	end
	local entry = entry_for(directory)
	if entry.pending then
		return
	end
	entry.pending = true

	local function finish(label)
		vim.schedule(function()
			entry.pending = false
			if entry.label ~= label then
				entry.label = label
				pcall(vim.cmd, "redrawstatus")
			end
		end)
	end

	local started = run({ "git", "-C", directory, "symbolic-ref", "--quiet", "--short", "HEAD" }, function(result)
		if result.code == 0 then
			return finish(vim.trim(result.stdout or ""))
		end
		if result.code ~= 1 then
			return finish("") -- not a repository
		end
		-- Exit code 1 means HEAD is detached: show the short commit hash instead.
		local queued = run({ "git", "-C", directory, "rev-parse", "--short", "HEAD" }, function(commit)
			finish(commit.code == 0 and ("@" .. vim.trim(commit.stdout or "")) or "")
		end)
		if not queued then
			finish("")
		end
	end)
	if not started then
		entry.pending = false
	end
end

return M
