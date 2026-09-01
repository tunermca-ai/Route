--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("sit")
	:description("Force a player's character to sit")
	:category("Players")
	:permission("players.sit")
	:arg(Types.players, "targets", "Player(s) to sit")
	:cooldown(1)
	:example("sit Player")
	:run(function(ctx: any, args: { [string]: any })
		local count = 0
		for _, target in ipairs(args.targets) do
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Sit = true
				count += 1
			end
		end
		ctx:Success(string.format("Sat %d player(s) down", count))
	end)
