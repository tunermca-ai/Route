--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local MuteStore = require(script.Parent.Parent.Parent.Moderation.MuteStore)

return Command.new("mute")
	:description("Silence a player's chat")
	:category("Moderation")
	:permission("moderation.mute")
	:arg(Types.player, "target", "Player to mute")
	:arg(Types.string, "reason", "Reason")
		:optional()
		:rest()
	:audit(true)
	:example("mute Player Spamming")
	:run(function(ctx: any, args: { [string]: any })
		MuteStore.Mute(args.target.UserId, args.reason or "No reason given")
		ctx:Success(string.format("Muted %s", args.target.Name))
	end)
