-- lua/lilypond-forward-search/health.lua
local M = {}

M.check = function()
	vim.health.start("lilypond-forward-search")

	-- 1. Verificar que Zathura esté corriendo o instalado
	if vim.fn.executable("zathura") == 1 then
		vim.health.ok("zathura is installed")
	else
		vim.health.error("zathura is not installed", { "Install zathura to use forward search" })
	end

	-- 2. Verificar que Python 3 y PyMuPDF estén disponibles
	if vim.fn.executable("python3") == 1 then
		vim.health.ok("python3 is installed")
		local ok = vim.fn.system("python3 -c 'import pymupdf'")
		if vim.v.shell_error == 0 then
			vim.health.ok("PyMuPDF is importable")
		else
			vim.health.error("PyMuPDF not found", { "Install PyMuPDF (e.g., pip install pymupdf)" })
		end
	else
		vim.health.error("python3 is not installed")
	end

	-- 3. Verificar que el script extractor exista (usando la misma lógica de tu index.lua)
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
		.. "/../scripts/lilypond-forward-search.py"
	if vim.fn.filereadable(script_path) == 1 then
		vim.health.ok("Extractor script found")
	else
		vim.health.error("Extractor script not found at " .. script_path)
	end

	-- 4. Verificar si nvim-lilypond-suite está cargado
	if package.loaded["nvls"] then
		vim.health.ok("nvim-lilypond-suite is loaded")
	else
		vim.health.warn("nvim-lilypond-suite not loaded (dependency)")
	end
end

return M
