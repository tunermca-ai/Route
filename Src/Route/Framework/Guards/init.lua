--!strict
-- Route.Guards
-- Named, reusable pre-execution checks. Guards run after the permission
-- check and before cooldown/rate-limit, in the order they were attached
-- to the command. A guard returns (true) to allow, or (false, reason)
-- to block execution with a human-readable reason.

export type GuardContext = any -- Route.Command.Context, avoiding a require cycle
export type GuardFn = (context: GuardContext) -> (boolean, string?)

local Guards = {}
Guards._registry = {} :: { [string]: GuardFn }

function Guards:Register(name: string, fn: GuardFn)
	if type(fn) ~= "function" then
		error(string.format("Route.Guards:Register('%s') requires a function", name), 2)
	end
	Guards._registry[name] = fn
	;(Guards :: any)[name] = fn -- also exposed as Guards.<Name> to match Command:guard(Guards.IsOwner) usage
end

function Guards:Get(name: string): GuardFn?
	return Guards._registry[name]
end

function Guards:GetAll(): { [string]: GuardFn }
	return Guards._registry
end

function Guards:Count(): number
	local n = 0
	for _ in pairs(Guards._registry) do
		n += 1
	end
	return n
end

-- Resolves either a guard function or the name of a registered guard,
-- as accepted by Command:guard(). Used by Core's execution pipeline.
function Guards:Resolve(guard: GuardFn | string): (GuardFn?, string?)
	if type(guard) == "function" then
		return guard, nil
	end
	local fn = Guards._registry[guard]
	if not fn then
		return nil, string.format('no guard registered named "%s"', guard)
	end
	return fn, nil
end

-- ===== Built-in guards ===================================================

Guards:Register("IsOwner", function(context: GuardContext)
	local player: Player = context.Player
	if player.UserId == game.CreatorId then
		return true, nil
	end
	local Route = context.Route
	if Route and Route.Permissions and Route.Permissions:Has(player, "*") then
		return true, nil
	end
	return false, "this command is restricted to the game owner"
end)

Guards:Register("ServerUnlocked", function(context: GuardContext)
	local Route = context.Route
	if Route and Route.Config and Route.Config:Get("Server.Locked") then
		return false, "the server is currently locked"
	end
	return true, nil
end)

Guards:Register("InStudio", function()
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		return true, nil
	end
	return false, "this command only runs in Studio"
end)

return Guards
