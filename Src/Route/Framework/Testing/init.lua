--!strict
-- Route.Testing
-- Server-side testing utilities. RunCommand skips the network layer and
-- raw-text parsing entirely - it calls a command's :run() directly with
-- already-typed Lua values, which is what you want for unit tests, but
-- still exercises Guards/Permission checks when asked to.

local Context = require(script.Parent.Command.Context)

export type RunOptions = {
	Player: Player?,
	EnforcePermissions: boolean?,
	EnforceGuards: boolean?,
}

export type RunResult = {
	Success: boolean,
	Error: string?,
	Responses: { any },
}

local Testing = {}
Testing.__index = Testing

function Testing.new(deps: { Registry: any, Route: any }): any
	local self = setmetatable({
		_deps = deps,
	}, Testing)
	return self
end

function Testing:RunCommand(name: string, args: { [string]: any }, opts: RunOptions?): RunResult
	local options: RunOptions = opts or {}
	local command = self._deps.Registry:Find(name)
	if not command then
		return { Success = false, Error = string.format('no command named "%s"', name), Responses = {} }
	end

	local player = options.Player
	if not player then
		local Players = game:GetService("Players")
		player = Players:GetPlayers()[1]
	end
	if not player then
		return {
			Success = false,
			Error = "Testing:RunCommand needs a real Player instance - pass opts.Player (Roblox has no fake Player).",
			Responses = {},
		}
	end

	local responses = {}
	local context = Context.new({
		Player = player :: Player,
		Command = command,
		Raw = "[Testing:RunCommand] " .. name,
		RequestId = "TEST-" .. tostring(math.random(100000, 999999)),
		Route = self._deps.Route,
		Sink = function(payload)
			table.insert(responses, payload)
		end,
	})
	context.Args = args

	if options.EnforcePermissions and command.Permission then
		if not context:HasPermission(command.Permission) then
			return { Success = false, Error = "permission denied: " .. command.Permission, Responses = responses }
		end
	end

	if options.EnforceGuards then
		for _, guard in ipairs(command.Guards) do
			local Guards = self._deps.Route.Guards
			local fn = if type(guard) == "function" then guard else Guards:Get(guard :: string)
			if fn then
				local ok, reason = fn(context)
				if not ok then
					return { Success = false, Error = reason or "guard failed", Responses = responses }
				end
			end
		end
	end

	if not command.RunFn then
		return { Success = false, Error = "command has no :run() implementation", Responses = responses }
	end

	local ok, err = pcall(command.RunFn, context, args)
	return { Success = ok, Error = if ok then nil else tostring(err), Responses = responses }
end

return Testing
