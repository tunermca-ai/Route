--!strict
-- Route.Core.Levenshtein
-- Tiny edit-distance helper used to power "did you mean: kick?" style
-- suggestions when a command name doesn't resolve.

local function distance(a: string, b: string): number
	local lenA, lenB = #a, #b
	if lenA == 0 then
		return lenB
	end
	if lenB == 0 then
		return lenA
	end

	local previousRow = table.create(lenB + 1, 0)
	for j = 0, lenB do
		previousRow[j + 1] = j
	end

	for i = 1, lenA do
		local currentRow = table.create(lenB + 1, 0)
		currentRow[1] = i
		for j = 1, lenB do
			local cost = if a:sub(i, i) == b:sub(j, j) then 0 else 1
			currentRow[j + 1] = math.min(
				previousRow[j + 1] + 1, -- deletion
				currentRow[j] + 1, -- insertion
				previousRow[j] + cost -- substitution
			)
		end
		previousRow = currentRow
	end

	return previousRow[lenB + 1]
end

return { Distance = distance }
