--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("kill")
	:description("Kill a player's character")
	:category("Players")
	:permission("players.kill")
	:arg(Types.players, "targets", "Player(s) to kill")
	:cooldown(1)
	:example("kill Player")
	:example("kill @others")
	:run(function(ctx: any, args: { [string]: any })
		local count = 0
		for _, target in ipairs(args.targets) do
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
				count += 1
			end
		end
		ctx:Success(string.format("Killed %d player(s)", count))
	end)
