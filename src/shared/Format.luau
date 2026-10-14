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
