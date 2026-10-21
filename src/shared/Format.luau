--!strict
--[[
	Format : affichage des nombres en français (virgule décimale, suffixes K/M/B/T).
	Pur, utilisable par les deux HUD et testable avec Lune.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local function frenchDecimal(s: string): string
	return (string.gsub(s, "%.", ","))
end

local function trimZeros(s: string): string
	return (string.gsub(s, "%.?0+$", ""))
end

-- string.upper ne touche qu'à l'ASCII (« Première » → « PREMIèRE ») : on complète les lettres accentuées
local ACCENTS: { [string]: string } = {
	["à"] = "À",
	["â"] = "Â",
	["ä"] = "Ä",
	["á"] = "Á",
	["ç"] = "Ç",
	["é"] = "É",
	["è"] = "È",
	["ê"] = "Ê",
	["ë"] = "Ë",
	["î"] = "Î",
	["ï"] = "Ï",
	["í"] = "Í",
	["ô"] = "Ô",
	["ö"] = "Ö",
	["ó"] = "Ó",
	["ù"] = "Ù",
	["û"] = "Û",
	["ü"] = "Ü",
	["ú"] = "Ú",
	["ÿ"] = "Ÿ",
	["ñ"] = "Ñ",
	["œ"] = "Œ",
	["æ"] = "Æ",
}

function Format.upper(text: string): string
	return (string.gsub(string.upper(text), utf8.charpattern, ACCENTS))
end

function Format.number(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "—"
	end
	local abs = math.abs(n)
	if abs < 1000 then
		if abs < 100 then
			return frenchDecimal(trimZeros(string.format("%.1f", n)))
		end
		return string.format("%.0f", n)
	end
	local index = 1
	local scaled = n
	while math.abs(scaled) >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	return `{frenchDecimal(trimZeros(string.format("%.2f", scaled)))} {SUFFIXES[index]}`
end

return Format
