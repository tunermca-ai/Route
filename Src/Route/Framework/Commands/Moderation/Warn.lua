--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("warn")
	:description("Send a formal warning to a player")
	:category("Moderation")
	:permission("moderation.warn")
	:arg(Types.player, "target", "Player to warn")
	:arg(Types.string, "reason", "The warning message")
		:rest()
	:audit(true)
	:example("warn Player Please follow the rules")
	:run(function(ctx: any, args: { [string]: any })
		-- Delivered to the target through Route's own response channel,
		-- so it shows up in their Route output if they have it open.
		-- For a guaranteed-visible in-game popup, hook Audit's
		-- "CommandExecuted" sink (or wrap this run()) with your game's
		-- own notification UI - that's intentionally left to you.
		local remotes = ctx.Route.Network and ctx.Route.Network.Remotes
		if remotes then
			remotes.Response:FireClient(args.target, {
				Type = "Warn",
				Message = string.format("You have been warned: %s", args.reason),
			})
		end
		ctx:Success(string.format("Warned %s: %s", args.target.Name, args.reason))
	end)
