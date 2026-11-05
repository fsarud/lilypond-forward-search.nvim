local M = {}

local cache = {} -- pdf_path -> { mtime = int, data = table }

local margin = 5.0

function M.set_margin(m)
	margin = m
end

-- 1. Carga el JSON, cachea por mtime
function M.load_index(json_path)
	local stat = vim.loop.fs_stat(json_path)
	if not stat then
		return nil
	end
	local mtime = stat.mtime.sec
	local c = cache[json_path]
	if c and c.mtime == mtime then
		return c.data
	end
	local f = io.open(json_path, "r")
	if not f then
		return nil
	end
	local raw = f:read("*a")
	f:close()
	local data = vim.json.decode(raw)
	cache[json_path] = { mtime = mtime, data = data }
	return data
end

-- 2. Busca (line, col) en el índice de un archivo fuente
function M.lookup(index, src_path, line, col)
	local entries = index.sources[src_path]
	if not entries or #entries == 0 then
		return nil
	end

	-- búsqueda binaria: mayor entry con (line, col) <= cursor
	local lo, hi, best = 1, #entries, nil
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local e = entries[mid]
		if e.line < line or (e.line == line and e.col <= col) then
			best = e
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	-- si el cursor está antes del primer entry, usar el primero
	if not best then
		best = entries[1]
	end
	return best
end

-- 3. Encuentra el destino D-Bus de la instancia que tiene abierto pdf_path
local function find_dest(pdf_path)
	local h = io.popen(
		"dbus-send --session --dest=org.freedesktop.DBus --type=method_call "
			.. "--print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null"
	)
	if not h then
		return nil
	end
	local out = h:read("*a")
	h:close()

	for dest in out:gmatch('"(org%.pwmt%.zathura%.PID%-%d+)"') do
		local h2 = io.popen(
			(
				"gdbus call --session --dest %s --object-path /org/pwmt/zathura "
				.. "--method org.freedesktop.DBus.Properties.Get org.pwmt.zathura filename 2>/dev/null"
			):format(dest)
		)
		if h2 then
			local fn = h2:read("*a")
			h2:close()
			-- gdbus devuelve algo tipo: (<'/ruta/al.pdf'>,)
			local path = fn:match("'([^']+)'")
			if path and vim.fn.fnamemodify(path, ":p") == vim.fn.fnamemodify(pdf_path, ":p") then
				return dest
			end
		end
	end
	return nil
end

-- 4. Manda el highlight por D-Bus
function M.goto_rect(pdf_path, page, rect)
	-- rect = {x0, y0, x1, y1} tal como lo devuelve PyMuPDF
	local dest = find_dest(pdf_path)
	if not dest then
		vim.notify("zathura doesn't opened " .. pdf_path, vim.log.levels.WARN)
		return false
	end
	local x0, y0, x1, y1 = rect[1], rect[2], rect[3], rect[4]
	x0, y0, x1, y1 = x0 - margin, y0 - margin, x1 + margin, y1 + margin --agrega márgenes para visibilidad
	-- Zathura espera (x1, x2, y1, y2) = (min_x, max_x, min_y, max_y)
	local spec = ("[(%.4f, %.4f, %.4f, %.4f)]"):format(x0, x1, y0, y1)
	local cmd = (
		"gdbus call --session --dest %s --object-path /org/pwmt/zathura "
		.. "--method org.pwmt.zathura.HighlightRects %d '%s' '[]'"
	):format(dest, page, spec)
	vim.fn.system(cmd)
	return true
end

-- Deriva rutas por convención desde el path del .ly
function M.paths_for(ly_path)
	local base = ly_path:gsub("%.ly$", "")
	return {
		json = base .. ".json",
		pdf = base .. ".pdf",
	}
end

function M.forward_search()
	local buf = vim.api.nvim_buf_get_name(0)
	if buf == "" or not buf:match("%.ly$") then
		vim.notify("Not a .ly buffer", vim.log.levels.WARN)
		return
	end

	local master = M.find_master(buf)
	local paths = M.paths_for(master)

	-- Usar el PDF activo si existe, si no el derivado del master
	local pdf = vim.b.nvls_active_pdf or paths.pdf
	-- El JSON acompaña al PDF activo
	local json = pdf:gsub("%.pdf$", ".json")

	local idx = M.load_index(json)
	if not idx then
		vim.notify("No index in " .. json, vim.log.levels.WARN)
		return
	end

	local pos = vim.api.nvim_win_get_cursor(0)
	local entry = M.lookup(idx, buf, pos[1], pos[2])
	if not entry then
		vim.notify("No entry for " .. pos[1] .. ":" .. pos[2], vim.log.levels.WARN)
		return
	end

	M.goto_rect(pdf, entry.page, entry.rect)
end
-- -- Forward search desde el buffer actual
-- function M.forward_search()
-- 	local ly_path = vim.api.nvim_buf_get_name(0)
-- 	if ly_path == "" or not ly_path:match("%.ly$") then
-- 		vim.notify("No es un buffer .ly", vim.log.levels.WARN)
-- 		return
-- 	end
--
-- 	local paths = M.paths_for(ly_path)
-- 	local idx = M.load_index(paths.json)
-- 	if not idx then
-- 		vim.notify("No hay índice en " .. paths.json, vim.log.levels.WARN)
-- 		return
-- 	end
--
-- 	local pos = vim.api.nvim_win_get_cursor(0)
-- 	local entry = M.lookup(idx, ly_path, pos[1], pos[2])
-- 	if not entry then
-- 		vim.notify("Sin entrada para " .. pos[1] .. ":" .. pos[2], vim.log.levels.WARN)
-- 		return
-- 	end
--
-- 	M.goto_rect(paths.pdf, entry.page, entry.rect)
-- end
--
-- Encuentra el archivo master para un buffer dado
function M.find_master(buf_path)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, 10, false)
	for _, line in ipairs(lines) do
		local m = line:match("^%%%s*master:%s*(.+)$")
		if m then
			local rel = vim.trim(m)
			local dir = vim.fn.fnamemodify(buf_path, ":h")
			return vim.fn.fnamemodify(dir .. "/" .. rel, ":p")
		end
	end
	-- Sin comentario: el buffer ES el master
	return buf_path
end

local function open_in_zathura(pdf_path)
	local job_id = vim.fn.jobstart({ "zathura", pdf_path }, { detach = true })
	if job_id <= 0 then
		vim.notify("Zathura is not running (job_id=" .. job_id .. ")", vim.log.levels.ERROR)
	end
end

function M.select_pdf()
	local buf = vim.api.nvim_buf_get_name(0)
	if buf == "" or not buf:match("%.ly$") then
		vim.notify("Not a .ly buffer", vim.log.levels.WARN)
		return
	end
	local master = M.find_master(buf)
	local pdfs = M.find_pdfs(master)
	if #pdfs == 0 then
		vim.notify("No compiled PDF", vim.log.levels.WARN)
		return
	end
	if #pdfs == 1 then
		vim.b.nvls_active_pdf = pdfs[1]
		vim.notify("Active PDF: " .. vim.fn.fnamemodify(pdfs[1], ":t"), vim.log.levels.INFO)
		open_in_zathura(pdfs[1])
		return
	end
	vim.ui.select(pdfs, {
		prompt = "Choose PDF:",
		format_item = function(item)
			return vim.fn.fnamemodify(item, ":t")
		end,
	}, function(choice)
		if choice then
			vim.b.nvls_active_pdf = choice
			vim.notify("Active PDF: " .. vim.fn.fnamemodify(choice, ":t"), vim.log.levels.INFO)
			open_in_zathura(choice)
		end
	end)
end

function M.find_pdfs(master_path)
	local dir = vim.fn.fnamemodify(master_path, ":h")
	local base = vim.fn.fnamemodify(master_path, ":t:r") -- nombre sin .ly
	local pattern = dir .. "/" .. base .. "*.pdf"
	local files = vim.fn.glob(pattern, false, true)
	table.sort(files)
	return files
end

function M.regenerate_index()
	local buf = vim.api.nvim_buf_get_name(0)
	if buf == "" or not buf:match("%.ly$") then
		vim.notify("Not a .ly buffer", vim.log.levels.WARN)
		return
	end
	local master = M.find_master(buf)
	local paths = M.paths_for(master)
	local pdf = vim.b.nvls_active_pdf or paths.pdf
	if vim.fn.filereadable(pdf) == 0 then
		vim.notify("Nonexistent PDF: " .. pdf, vim.log.levels.ERROR)
		return
	end
	local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
		.. "/scripts/lilypond-forward-search.py"
	if vim.fn.filereadable(script) == 0 then
		vim.notify("Can't find " .. script, vim.log.levels.ERROR)
		return
	end
	local json = pdf:gsub("%.pdf$", ".json")
	vim.fn.jobstart({ "python3", script, pdf, json }, {
		on_exit = function(_, code)
			if code == 0 then
				vim.notify("Index rebuilt: " .. vim.fn.fnamemodify(json, ":t"), vim.log.levels.INFO)
			else
				vim.notify("Extractor failed (code " .. code .. ")", vim.log.levels.ERROR)
			end
		end,
	})
end

return M
