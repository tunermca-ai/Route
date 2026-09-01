--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local MuteStore = require(script.Parent.Parent.Parent.Moderation.MuteStore)

return Command.new("unmute")
	:description("Restore a player's chat")
	:category("Moderation")
	:permission("moderation.mute")
	:arg(Types.player, "target", "Player to unmute")
	:audit(true)
	:example("unmute Player")
	:run(function(ctx: any, args: { [string]: any })
		if MuteStore.Unmute(args.target.UserId) then
			ctx:Success(string.format("Unmuted %s", args.target.Name))
		else
			ctx:Warn(string.format("%s was not muted", args.target.Name))
		end
	end)
