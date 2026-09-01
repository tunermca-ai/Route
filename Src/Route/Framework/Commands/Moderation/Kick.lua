--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("kick")
	:description("Remove a player from the server")
	:category("Moderation")
	:aliases("k", "boot")
	:permission("moderation.kick")
	:arg(Types.player, "target", "Player to kick")
	:arg(Types.string, "reason", "Reason shown to them")
		:optional()
		:rest()
	:cooldown(2)
	:audit(true)
	:example("kick Player")
	:example("kick Player Exploiting")
	:run(function(ctx: any, args: { [string]: any })
		local reason = args.reason or "You were kicked by a moderator"
		args.target:Kick(reason)
		ctx:Success(string.format("Kicked %s (%s)", args.target.Name, reason))
	end)
