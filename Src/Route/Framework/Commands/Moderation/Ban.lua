--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local BanStore = require(script.Parent.Parent.Parent.Moderation.BanStore)

return Command.new("ban")
	:description("Ban a player, kicking them now and blocking future joins")
	:category("Moderation")
	:permission("moderation.ban")
	:arg(Types.player, "target", "Player to ban")
	:arg(Types.string, "reason", "Reason recorded and shown to them")
		:optional()
		:rest()
	:audit(true)
	:example("ban Player Exploiting")
	:run(function(ctx: any, args: { [string]: any })
		local reason = args.reason or "No reason given"
		BanStore.Ban(args.target.UserId, reason, ctx.Player.UserId)
		args.target:Kick(string.format("You have been banned.\nReason: %s", reason))
		ctx:Success(string.format("Banned %s (%s)", args.target.Name, reason))
	end)
