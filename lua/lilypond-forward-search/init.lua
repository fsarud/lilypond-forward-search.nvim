-- lua/lilypond-forward-search/init.lua
local M = {}

local defaults = {
	keymaps = {
		compile = "<F5>",
		index = "<F7>",
		select_pdf = "<F8>",
		forward_search = "<F9>",
		toggle_follow = "<F10>",
	},
	follow = {
		enabled = false,
		debounce_ms = 50,
	},
	margin = 5.0,
}

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})
	local LI = require("lilypond-forward-search.index")
	LI.set_margin(opts.margin)

	-- ---- Follow state ----
	local follow_enabled = opts.follow.enabled
	local last_line = -1
	local timer = nil

	local function follow_sync()
		if not follow_enabled then
			return
		end
		if not vim.b.nvls_active_pdf then
			return
		end
		local line = vim.fn.line(".")
		if line == last_line then
			return
		end
		if vim.fn.getline("."):match("^%s*$") then
			return
		end
		last_line = line
		LI.forward_search()
	end

	local function enable_follow()
		follow_enabled = true
		last_line = -1
		vim.api.nvim_create_autocmd("CursorMoved", {
			group = vim.api.nvim_create_augroup("LilypondFollow", { clear = true }),
			buffer = vim.api.nvim_get_current_buf(),
			callback = function()
				if timer then
					timer:stop()
				end
				timer = vim.uv.new_timer()
				timer:start(opts.follow.debounce_ms, 0, vim.schedule_wrap(follow_sync))
			end,
		})
	end

	local function disable_follow()
		follow_enabled = false
		vim.api.nvim_clear_autocmds({ group = "LilypondFollow" })
		if timer then
			timer:stop()
			timer = nil
		end
	end

	local function toggle_follow()
		if follow_enabled then
			disable_follow()
			vim.notify("LilyPond follow: OFF", vim.log.levels.INFO)
		else
			enable_follow()
			vim.notify("LilyPond follow: ON", vim.log.levels.INFO)
		end
	end

	if follow_enabled then
		enable_follow()
	end

	-- ---- Keymaps ----
	local km = opts.keymaps

	vim.keymap.set({ "n", "i" }, km.toggle_follow, toggle_follow, { desc = "Toggle LilyPond follow" })

	vim.keymap.set({ "n", "i" }, km.forward_search, function()
		LI.forward_search()
	end, { desc = "LilyPond: forward search → Zathura" })

	vim.keymap.set({ "n", "i" }, km.select_pdf, function()
		LI.select_pdf()
	end, { desc = "LilyPond: Choose PDF" })

	vim.keymap.set({ "n", "i" }, km.index, function()
		LI.regenerate_index()
	end, { desc = "LilyPond: regenerate active PDF index" })

	-- ---- F5 con % master: (buffer-local por filetype) ----
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "lilypond", "tex", "texinfo" },
		callback = function(ev)
			vim.schedule(function()
				vim.keymap.set({ "n", "i" }, km.compile, function()
					local master = nil
					local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false)
					for _, line in ipairs(lines) do
						local m = line:match("^%%%s*master:%s*(.+)$")
						if m then
							master = vim.trim(m)
							break
						end
					end
					if master then
						vim.notify("Compilling master: " .. master, vim.log.levels.INFO)
						local nvls_opts = require("nvls").get_nvls_options()
						nvls_opts.lilypond.options.main_file = master
					end
					vim.cmd("LilyCmp")
				end, { buffer = ev.buf, desc = "LilyPond: Compile (with % master: override)" })
			end)
		end,
	})
end

return M
