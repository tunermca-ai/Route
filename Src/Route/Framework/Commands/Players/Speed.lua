--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("speed")
	:description("Set a player's WalkSpeed")
	:category("Players")
	:permission("players.speed")
	:arg(Types.player, "target", "Player to modify")
	:arg(Types.number, "amount", "New WalkSpeed")
		:min(0)
		:max(500)
	:cooldown(1)
	:example("speed Player 50")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		humanoid.WalkSpeed = args.amount
		ctx:Success(string.format("Set %s's WalkSpeed to %d", args.target.Name, args.amount))
	end)
