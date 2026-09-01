--!strict
-- Route.Types.Builtin
-- Registers every type Route ships with. Called once from Types/init.lua
-- with the Types registry as `self`, so `self:Register(...)` works exactly
-- like it would for a developer's own custom type.
--
-- Naming follows Cmdr's own convention: lowercase, singular for one value
-- (Types.player, Types.string, Types.integer, ...), the same word with an
-- "s" for a comma-separated list of them (Types.players, Types.strings,
-- Types.integers, ...). A handful of names (permissionNode, role, command)
-- are Route-specific - command is also a Cmdr built-in, permissionNode and
-- role don't exist in Cmdr because Cmdr has no permission/role system to
-- reference.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local UNIT_SECONDS = {
	s = 1,
	sec = 1,
	secs = 1,
	second = 1,
	seconds = 1,
	m = 60,
	min = 60,
	mins = 60,
	minute = 60,
	minutes = 60,
	h = 3600,
	hr = 3600,
	hrs = 3600,
	hour = 3600,
	hours = 3600,
	d = 86400,
	day = 86400,
	days = 86400,
	w = 604800,
	week = 604800,
	weeks = 604800,
}

-- ===== Player selector resolution =====================================
-- Shared by Types.player and Types.players. Returns the resolved list and,
-- when nothing matched, a human-readable reason.

local function allPlayers(): { Player }
	return Players:GetPlayers()
end

local function resolveSelector(rawToken: string, context: any): ({ Player }?, string?)
	local token = rawToken
	if token:sub(1, 1) == "@" then
		token = token:sub(2)
	end
	local lower = token:lower()

	if lower == "me" or lower == "self" then
		return { context.Player }
	elseif lower == "all" then
		return allPlayers()
	elseif lower == "others" then
		local list = {}
		for _, plr in ipairs(allPlayers()) do
			if plr ~= context.Player then
				table.insert(list, plr)
			end
		end
		return list
	elseif lower == "random" then
		local list = allPlayers()
		if #list == 0 then
			return nil, "there are no players online"
		end
		return { list[math.random(1, #list)] }
	end

	local teamName = lower:match("^team:(.+)$")
	if teamName then
		local list = {}
		for _, plr in ipairs(allPlayers()) do
			local team = plr.Team
			if team and team.Name:lower() == teamName then
				table.insert(list, plr)
			end
		end
		if #list == 0 then
			return nil, string.format('no players on team "%s"', teamName)
		end
		return list
	end

	local userIdToken = lower:match("^userid:(%d+)$")
	if userIdToken then
		local ok, plr = pcall(Players.GetPlayerByUserId, Players, tonumber(userIdToken) :: number)
		if ok and plr then
			return { plr }
		end
		return nil, string.format('no online player with UserId "%s"', userIdToken)
	end

	-- Exact case-insensitive name match wins outright.
	for _, plr in ipairs(allPlayers()) do
		if plr.Name:lower() == lower or plr.DisplayName:lower() == lower then
			return { plr }
		end
	end

	-- Otherwise, prefix match against every online player.
	local matches = {}
	for _, plr in ipairs(allPlayers()) do
		if plr.Name:lower():find(lower, 1, true) == 1 then
			table.insert(matches, plr)
		end
	end
	if #matches > 0 then
		return matches
	end

	return nil, string.format('no player matching "%s"', rawToken)
end

local function playerSuggestions(partial: string): { any }
	local lower = partial:lower()
	local out = {}
	for _, keyword in ipairs({ "me", "all", "others", "random" }) do
		if keyword:find(lower, 1, true) == 1 then
			table.insert(out, { Value = keyword, Display = keyword, Description = "Player selector", Kind = "Player" })
		end
	end
	for _, plr in ipairs(allPlayers()) do
		if plr.Name:lower():find(lower, 1, true) == 1 then
			table.insert(out, { Value = plr.Name, Display = plr.Name, Description = "Online player", Kind = "Player" })
		end
	end
	return out
end

-- ===== Small shared helpers for the plural/list types =================

-- Splits on commas, trims each piece, drops empties. Used by every
-- Types.xxxs plural type to turn "a, b,c" into {"a","b","c"}.
local function splitList(raw: string): { string }
	local out = {}
	for _, token in ipairs(string.split(raw, ",")) do
		local trimmed = token:match("^%s*(.-)%s*$") or ""
		if trimmed ~= "" then
			table.insert(out, trimmed)
		end
	end
	return out
end

local function findTeam(nameOrPrefix: string): Team?
	local lower = nameOrPrefix:lower()
	for _, team in ipairs(Teams:GetTeams()) do
		if team.Name:lower() == lower then
			return team
		end
	end
	for _, team in ipairs(Teams:GetTeams()) do
		if team.Name:lower():find(lower, 1, true) == 1 then
			return team
		end
	end
	return nil
end

local BOOLEAN_WORDS: { [string]: boolean } = {
	["true"] = true,
	yes = true,
	["1"] = true,
	on = true,
	["false"] = false,
	no = false,
	["0"] = false,
	off = false,
}

return function(Types: any)
	Types:Register("string", {
		Parse = function(raw: string): (string?, string?)
			if raw == "" then
				return nil, "expected text"
			end
			return raw, nil
		end,
		Validate = function(value: string, argDef: any): (boolean, string?)
			if argDef.Min and #value < argDef.Min then
				return false, string.format("must be at least %d characters", argDef.Min)
			end
			if argDef.Max and #value > argDef.Max then
				return false, string.format("must be at most %d characters", argDef.Max)
			end
			return true, nil
		end,
	})

	Types:Register("strings", {
		Parse = function(raw: string): ({ string }?, string?)
			local list = splitList(raw)
			if #list == 0 then
				return nil, "expected a comma-separated list of text"
			end
			return list, nil
		end,
	})

	Types:Register("number", {
		Parse = function(raw: string): (number?, string?)
			local n = tonumber(raw)
			if not n then
				return nil, string.format('"%s" is not a number', raw)
			end
			return n, nil
		end,
		Validate = function(value: number, argDef: any): (boolean, string?)
			if argDef.Min and value < argDef.Min then
				return false, string.format("must be at least %s", tostring(argDef.Min))
			end
			if argDef.Max and value > argDef.Max then
				return false, string.format("must be at most %s", tostring(argDef.Max))
			end
			return true, nil
		end,
	})

	Types:Register("numbers", {
		Parse = function(raw: string): ({ number }?, string?)
			local out = {}
			for _, token in ipairs(splitList(raw)) do
				local n = tonumber(token)
				if not n then
					return nil, string.format('"%s" is not a number', token)
				end
				table.insert(out, n)
			end
			if #out == 0 then
				return nil, "expected a comma-separated list of numbers"
			end
			return out, nil
		end,
	})

	Types:Register("integer", {
		Parse = function(raw: string): (number?, string?)
			local n = tonumber(raw)
			if not n or n % 1 ~= 0 then
				return nil, string.format('"%s" is not a whole number', raw)
			end
			return n, nil
		end,
		Validate = function(value: number, argDef: any): (boolean, string?)
			if argDef.Min and value < argDef.Min then
				return false, string.format("must be at least %d", argDef.Min)
			end
			if argDef.Max and value > argDef.Max then
				return false, string.format("must be at most %d", argDef.Max)
			end
			return true, nil
		end,
	})

	Types:Register("integers", {
		Parse = function(raw: string): ({ number }?, string?)
			local out = {}
			for _, token in ipairs(splitList(raw)) do
				local n = tonumber(token)
				if not n or n % 1 ~= 0 then
					return nil, string.format('"%s" is not a whole number', token)
				end
				table.insert(out, n)
			end
			if #out == 0 then
				return nil, "expected a comma-separated list of whole numbers"
			end
			return out, nil
		end,
	})

	Types:Register("boolean", {
		Parse = function(raw: string): (boolean?, string?)
			local word = BOOLEAN_WORDS[raw:lower()]
			if word == nil then
				return nil, string.format('"%s" is not true/false', raw)
			end
			return word, nil
		end,
		Suggest = function(partial: string)
			local out = {}
			for _, word in ipairs({ "true", "false" }) do
				if word:find(partial:lower(), 1, true) == 1 then
					table.insert(out, { Value = word, Display = word, Kind = "Type" })
				end
			end
			return out
		end,
	})

	Types:Register("booleans", {
		Parse = function(raw: string): ({ boolean }?, string?)
			local out = {}
			for _, token in ipairs(splitList(raw)) do
				local word = BOOLEAN_WORDS[token:lower()]
				if word == nil then
					return nil, string.format('"%s" is not true/false', token)
				end
				table.insert(out, word)
			end
			if #out == 0 then
				return nil, "expected a comma-separated list of true/false values"
			end
			return out, nil
		end,
	})

	Types:Register("player", {
		Parse = function(raw: string, context: any)
			local matches, err = resolveSelector(raw, context)
			if not matches then
				return nil, err
			end
			if #matches > 1 then
				local names = {}
				for _, plr in ipairs(matches) do
					table.insert(names, plr.Name)
				end
				return nil, string.format(
					'"%s" matches multiple players (%s) - be more specific',
					raw,
					table.concat(names, ", ")
				)
			end
			return matches[1], nil
		end,
		Suggest = function(partial: string)
			return playerSuggestions(partial)
		end,
	})

	Types:Register("players", {
		Parse = function(raw: string, context: any): ({ Player }?, string?)
			local seen: { [number]: boolean } = {}
			local result: { Player } = {}
			for _, trimmed in ipairs(splitList(raw)) do
				local matches, err = resolveSelector(trimmed, context)
				if not matches then
					return nil, err
				end
				for _, plr in ipairs(matches) do
					if not seen[plr.UserId] then
						seen[plr.UserId] = true
						table.insert(result, plr)
					end
				end
			end
			if #result == 0 then
				return nil, "no players matched"
			end
			return result, nil
		end,
		Suggest = function(partial: string)
			local segments = string.split(partial, ",")
			local lastSegment = segments[#segments] or partial
			return playerSuggestions(lastSegment:match("^%s*(.-)$") or lastSegment)
		end,
	})

	Types:Register("playerId", {
		Parse = function(raw: string): (number?, string?)
			local n = tonumber(raw)
			if not n or n % 1 ~= 0 or n <= 0 then
				return nil, string.format('"%s" is not a valid UserId', raw)
			end
			return n, nil
		end,
		Describe = function()
			return "a UserId (works for offline players, unlike `player`)"
		end,
	})

	Types:Register("team", {
		Parse = function(raw: string): (Team?, string?)
			local team = findTeam(raw)
			if not team then
				return nil, string.format('no team named "%s"', raw)
			end
			return team, nil
		end,
		Suggest = function(partial: string)
			local out = {}
			local lower = partial:lower()
			for _, team in ipairs(Teams:GetTeams()) do
				if team.Name:lower():find(lower, 1, true) == 1 then
					table.insert(out, { Value = team.Name, Display = team.Name, Kind = "Type" })
				end
			end
			return out
		end,
	})

	Types:Register("teams", {
		Parse = function(raw: string): ({ Team }?, string?)
			local out = {}
			for _, token in ipairs(splitList(raw)) do
				local team = findTeam(token)
				if not team then
					return nil, string.format('no team named "%s"', token)
				end
				table.insert(out, team)
			end
			if #out == 0 then
				return nil, "expected a comma-separated list of teams"
			end
			return out, nil
		end,
		Suggest = function(partial: string)
			local segments = string.split(partial, ",")
			local lastSegment = (segments[#segments] or partial):match("^%s*(.-)$") or partial
			local out = {}
			local lower = lastSegment:lower()
			for _, team in ipairs(Teams:GetTeams()) do
				if team.Name:lower():find(lower, 1, true) == 1 then
					table.insert(out, { Value = team.Name, Display = team.Name, Kind = "Type" })
				end
			end
			return out
		end,
	})

	Types:Register("color3", {
		Parse = function(raw: string): (Color3?, string?)
			local r, g, b = raw:match("^%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*$")
			if not r then
				return nil, 'expected "R,G,B" (0-255 each), e.g. "255,0,0"'
			end
			return Color3.fromRGB(
				math.clamp(tonumber(r) :: number, 0, 255),
				math.clamp(tonumber(g) :: number, 0, 255),
				math.clamp(tonumber(b) :: number, 0, 255)
			), nil
		end,
		Describe = function()
			return '"R,G,B", 0-255 each - e.g. "255,0,0"'
		end,
	})

	Types:Register("hexColor3", {
		Parse = function(raw: string): (Color3?, string?)
			local hex = raw:gsub("^#", "")
			if not hex:match("^%x%x%x%x%x%x$") then
				return nil, string.format('"%s" is not a hex color - expected 6 hex digits, e.g. "#FF0000"', raw)
			end
			local ok, color = pcall(Color3.fromHex, "#" .. hex)
			if not ok then
				return nil, string.format('"%s" is not a valid hex color', raw)
			end
			return color, nil
		end,
		Describe = function()
			return "a hex color, e.g. #FF0000 or FF0000"
		end,
	})

	Types:Register("brickColor", {
		Parse = function(raw: string): (BrickColor?, string?)
			-- BrickColor.new() never errors on an unrecognized name - it
			-- silently falls back to a default color instead, so a typo'd
			-- name has to be caught by checking the result's .Name round-
			-- trips back to what was typed rather than trusting the call
			-- not to have thrown.
			local color = BrickColor.new(raw)
			if color.Name:lower() ~= raw:lower() then
				return nil, string.format('"%s" is not a recognized BrickColor name', raw)
			end
			return color, nil
		end,
		Describe = function()
			return 'a BrickColor name, e.g. "Really red" or "Bright blue"'
		end,
	})

	Types:Register("vector3", {
		Parse = function(raw: string): (Vector3?, string?)
			local x, y, z = raw:match("^%s*(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)%s*$")
			if not x then
				return nil, 'expected "X,Y,Z", e.g. "0,10,0"'
			end
			return Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number), nil
		end,
		Describe = function()
			return '"X,Y,Z" - e.g. "0,10,0"'
		end,
	})

	Types:Register("vector2", {
		Parse = function(raw: string): (Vector2?, string?)
			local x, y = raw:match("^%s*(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)%s*$")
			if not x then
				return nil, 'expected "X,Y", e.g. "0,10"'
			end
			return Vector2.new(tonumber(x) :: number, tonumber(y) :: number), nil
		end,
		Describe = function()
			return '"X,Y" - e.g. "0,10"'
		end,
	})

	Types:Register("url", {
		Parse = function(raw: string): (string?, string?)
			if not raw:match("^https?://%S+$") then
				return nil, string.format('"%s" doesn\'t look like a URL (expected it to start with http:// or https://)', raw)
			end
			return raw, nil
		end,
	})

	Types:Register("duration", {
		Parse = function(raw: string): (number?, string?)
			local trimmed = raw:match("^%s*(.-)%s*$") or raw
			local plain = tonumber(trimmed)
			if plain then
				return plain, nil
			end
			local total = 0
			local matchedAny = false
			for amount, unit in trimmed:gmatch("(%d+%.?%d*)(%a+)") do
				local unitText = unit :: string
				local seconds = UNIT_SECONDS[unitText:lower()]
				if not seconds then
					return nil, string.format('unknown duration unit "%s"', unitText)
				end
				total += tonumber(amount) :: number * seconds
				matchedAny = true
			end
			if not matchedAny then
				return nil, string.format('"%s" is not a valid duration (try "10s", "5m", "2h", "1d")', raw)
			end
			return total, nil
		end,
		Describe = function()
			return "duration, e.g. 30s, 10m, 2h, 1d"
		end,
	})

	-- "all" is just a friendlier spelling of the permission system's own
	-- full wildcard, "*" (see Permissions:_matches, which already treats a
	-- "*" pattern as matching every node) - accepted here so `perm give
	-- Player all` reads the way someone would actually type it.
	local function normalizePermissionNode(raw: string): (string?, string?)
		local lower = raw:lower()
		if lower == "all" then
			lower = "*"
		end
		if not lower:match("^[%a][%w]*(%.[%a][%w]*)*$") and lower ~= "*" then
			return nil, string.format('"%s" is not a valid permission node (expected e.g. "moderation.kick", or "all")', raw)
		end
		return lower, nil
	end

	local function permissionNodeSuggestions(partial: string, context: any): { any }
		local Route = context.Route
		if not Route or not Route.Permissions then
			return {}
		end
		local out = {}
		local lower = partial:lower()
		if lower == "" or ("all"):find(lower, 1, true) == 1 then
			table.insert(out, { Value = "all", Display = "all", Kind = "Permission" })
		end
		for _, node in ipairs(Route.Permissions:GetKnownNodes()) do
			if node:find(lower, 1, true) == 1 then
				table.insert(out, { Value = node, Display = node, Kind = "Permission" })
			end
		end
		return out
	end

	Types:Register("permissionNode", {
		Parse = function(raw: string): (string?, string?)
			return normalizePermissionNode(raw)
		end,
		Suggest = function(partial: string, context: any)
			return permissionNodeSuggestions(partial, context)
		end,
	})

	-- Comma-separated version of the above, the same way `players` sits
	-- alongside `player` - `perm give Player fun.explode,fun.spin` grants
	-- both in one call instead of needing the command run twice.
	Types:Register("permissionNodes", {
		Parse = function(raw: string): ({ string }?, string?)
			local nodes: { string } = {}
			local seen: { [string]: boolean } = {}
			for _, token in ipairs(splitList(raw)) do
				local node, err = normalizePermissionNode(token)
				if not node then
					return nil, err
				end
				if not seen[node] then
					seen[node] = true
					table.insert(nodes, node)
				end
			end
			if #nodes == 0 then
				return nil, "no permission nodes given"
			end
			return nodes, nil
		end,
		Suggest = function(partial: string, context: any)
			local segments = string.split(partial, ",")
			local lastSegment = segments[#segments] or partial
			return permissionNodeSuggestions(lastSegment:match("^%s*(.-)$") or lastSegment, context)
		end,
	})

	Types:Register("role", {
		Parse = function(raw: string, context: any): (any, string?)
			local Route = context.Route
			if not Route or not Route.Permissions then
				return nil, "permission system unavailable"
			end
			local role = Route.Permissions:GetRole(raw)
			if not role then
				return nil, string.format('no role named "%s"', raw)
			end
			return role, nil
		end,
		Suggest = function(partial: string, context: any)
			local Route = context.Route
			if not Route or not Route.Permissions then
				return {}
			end
			local out = {}
			local lower = partial:lower()
			for _, role in ipairs(Route.Permissions:ListRoles()) do
				if role.Name:lower():find(lower, 1, true) == 1 then
					table.insert(out, { Value = role.Name, Display = role.Name, Kind = "Role" })
				end
			end
			return out
		end,
	})

	Types:Register("command", {
		Parse = function(raw: string, context: any): (any, string?)
			local Route = context.Route
			if not Route or not Route.Commands then
				return nil, "command registry unavailable"
			end
			local command = Route.Commands:Find(raw)
			if not command then
				return nil, string.format('no command named "%s"', raw)
			end
			return command, nil
		end,
		Suggest = function(partial: string, context: any)
			local Route = context.Route
			if not Route or not Route.Commands then
				return {}
			end
			local out = {}
			for _, command in ipairs(Route.Commands:Search(partial)) do
				table.insert(out, {
					Value = command.Name,
					Display = command.Name,
					Description = command.Description,
					Kind = "Command",
				})
			end
			return out
		end,
	})

	-- Types.enum({...}) is a factory, not a fixed registration - each call
	-- produces a fresh, anonymous type tailored to that argument.
	Types.enum = function(values: { string }, opts: { CaseSensitive: boolean? }?)
		local caseSensitive = opts and opts.CaseSensitive or false
		local lookup: { [string]: string } = {}
		for _, value in ipairs(values) do
			lookup[if caseSensitive then value else value:lower()] = value
		end
		return {
			Name = "enum(" .. table.concat(values, "|") .. ")",
			Parse = function(raw: string): (string?, string?)
				local key = if caseSensitive then raw else raw:lower()
				local canonical = lookup[key]
				if not canonical then
					return nil, string.format('"%s" must be one of: %s', raw, table.concat(values, ", "))
				end
				return canonical, nil
			end,
			Suggest = function(partial: string)
				local out = {}
				local key = if caseSensitive then partial else partial:lower()
				for _, value in ipairs(values) do
					local compareValue = if caseSensitive then value else value:lower()
					if compareValue:find(key, 1, true) == 1 then
						table.insert(out, { Value = value, Display = value, Kind = "Enum" })
					end
				end
				return out
			end,
			Describe = function()
				return table.concat(values, "|")
			end,
		}
	end
end
