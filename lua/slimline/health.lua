local M = {}

function M.check()
	local health = vim.health
	local config = require("slimline.config")
	local options = config.options

	health.start("slimline")

	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim " .. tostring(vim.version()))
	else
		health.error("Neovim 0.10 or newer is required", "Upgrade Neovim")
	end

	local ok, err = pcall(config.resolve, options)
	if ok then
		health.ok("Configuration is valid")
	else
		health.error("Configuration is invalid: " .. tostring(err))
	end

	if vim.o.statusline:find("Slimline", 1, true) then
		health.ok("Slimline owns 'statusline'")
	else
		health.warn(
			"'statusline' is not set by Slimline: " .. vim.inspect(vim.o.statusline),
			{ "Call require('slimline').setup()", "Another statusline plugin may have overwritten it" }
		)
	end
	if vim.o.laststatus == 3 then
		health.ok("Global statusline is enabled ('laststatus' = 3)")
	else
		health.warn("'laststatus' is " .. vim.o.laststatus .. ", Slimline expects 3")
	end
	if options.buffers.enabled and options.buffers.position == "top" then
		if vim.o.tabline:find("Slimline", 1, true) and vim.o.showtabline == 2 then
			health.ok("Buffer list is shown in the tabline")
		else
			health.warn("Buffer list is set to the top, but 'tabline' or 'showtabline' was changed by something else")
		end
	end
	if vim.o.termguicolors then
		health.ok("'termguicolors' is enabled")
	else
		health.info("'termguicolors' is off: terminal palette indexes are used for colors")
	end

	if options.git.enabled then
		if vim.fn.executable("git") == 1 then
			health.ok("git executable found")
		else
			health.warn("git is not executable; the branch will not be shown", "Install git or set git.enabled = false")
		end
	end

	if options.icons then
		if pcall(require, "nvim-web-devicons") then
			health.ok("nvim-web-devicons found (file icons enabled)")
		else
			health.info("nvim-web-devicons not found; buffers are shown without file icons")
		end
	end

	if options.buffers.persist_pins then
		if vim.o.sessionoptions:find("globals", 1, true) then
			health.ok("'sessionoptions' contains \"globals\": pins are stored in sessions")
		else
			health.warn(
				"buffers.persist_pins is on, but 'sessionoptions' lacks \"globals\"",
				"vim.opt.sessionoptions:append('globals')"
			)
		end
	end
end

return M
