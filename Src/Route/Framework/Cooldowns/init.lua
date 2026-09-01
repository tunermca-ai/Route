--!strict
-- Route.Cooldowns
-- Per-command cooldowns (Command:cooldown(...)) plus a general-purpose,
-- bucketed rate limiter Route.Network uses to stop the raw command and
-- autocomplete remotes from being spammed, independent of any single
-- command's own cooldown. Buckets keep "typing triggers autocomplete
-- constantly" from eating into the budget for actual command sends.

export type CooldownSpec = number | { Global: number?, Player: number? }

local Cooldowns = {}
Cooldowns.__index = Cooldowns

function Cooldowns.new(): any
	local self = setmetatable({
		_playerLast = {} :: { [string]: number },
		_globalLast = {} :: { [string]: number },
		_rateWindows = {} :: { [string]: { number } }, -- "userId::bucket" -> recent call timestamps
	}, Cooldowns)
	return self
end

local function splitSpec(spec: CooldownSpec): (number?, number?)
	if type(spec) == "number" then
		return spec, nil
	end
	return spec.Player, spec.Global
end

-- Returns (true) if the command may run, or (false, secondsRemaining).
function Cooldowns:Check(commandName: string, player: Player, spec: CooldownSpec?): (boolean, number?)
	if not spec then
		return true, nil
	end
	local playerSeconds, globalSeconds = splitSpec(spec)
	local now = os.clock()

	if globalSeconds then
		local last = self._globalLast[commandName]
		if last and (now - last) < globalSeconds then
			return false, globalSeconds - (now - last)
		end
	end

	if playerSeconds then
		local key = commandName .. "::" .. tostring(player.UserId)
		local last = self._playerLast[key]
		if last and (now - last) < playerSeconds then
			return false, playerSeconds - (now - last)
		end
	end

	return true, nil
end

-- Call after a command successfully executes to start its cooldown.
function Cooldowns:Commit(commandName: string, player: Player, spec: CooldownSpec?)
	if not spec then
		return
	end
	local playerSeconds, globalSeconds = splitSpec(spec)
	local now = os.clock()
	if globalSeconds then
		self._globalLast[commandName] = now
	end
	if playerSeconds then
		self._playerLast[commandName .. "::" .. tostring(player.UserId)] = now
	end
end

-- Sliding-window rate limit, independent per bucket (e.g. "command" vs
-- "autocomplete") so high-frequency autocomplete traffic can't starve a
-- player's ability to actually submit commands. Returns true if the call
-- is allowed (and records it), false if over budget for that bucket.
function Cooldowns:CheckRateLimit(player: Player, maxPerMinute: number, bucket: string?): boolean
	local key = tostring(player.UserId) .. "::" .. (bucket or "default")
	local now = os.clock()
	local window = self._rateWindows[key]
	if not window then
		window = {}
		self._rateWindows[key] = window
	end

	local cutoff = now - 60
	local writeIndex = 1
	for _, timestamp in ipairs(window) do
		if timestamp >= cutoff then
			window[writeIndex] = timestamp
			writeIndex += 1
		end
	end
	for i = #window, writeIndex, -1 do
		window[i] = nil
	end

	if #window >= maxPerMinute then
		return false
	end
	table.insert(window, now)
	return true
end

function Cooldowns:ClearPlayer(player: Player)
	local userIdPrefix = tostring(player.UserId) .. "::"
	for key in pairs(self._rateWindows) do
		if key:sub(1, #userIdPrefix) == userIdPrefix then
			self._rateWindows[key] = nil
		end
	end
end

return Cooldowns
