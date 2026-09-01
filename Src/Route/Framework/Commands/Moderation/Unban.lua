--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local BanStore = require(script.Parent.Parent.Parent.Moderation.BanStore)

return Command.new("unban")
	:description("Lift a ban by UserId")
	:category("Moderation")
	:permission("moderation.ban")
	:arg(Types.playerId, "userId", "UserId to unban")
	:audit(true)
	:example("unban 123456789")
	:run(function(ctx: any, args: { [string]: any })
		if BanStore.Unban(args.userId) then
			ctx:Success(string.format("Unbanned UserId %d", args.userId))
		else
			ctx:Warn(string.format("UserId %d was not banned", args.userId))
		end
	end)
