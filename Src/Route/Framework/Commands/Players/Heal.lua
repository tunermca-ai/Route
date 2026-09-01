--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("heal")
	:description("Heal a player to full health")
	:category("Players")
	:permission("players.heal")
	:arg(Types.player, "target", "Player to heal")
	:cooldown(1)
	:example("heal Player")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		humanoid.Health = humanoid.MaxHealth
		ctx:Success(string.format("Healed %s", args.target.Name))
	end)
