--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("unsit")
	:description("Stand a player's character back up")
	:category("Players")
	:permission("players.sit")
	:arg(Types.players, "targets", "Player(s) to stand up")
	:cooldown(1)
	:example("unsit Player")
	:run(function(ctx: any, args: { [string]: any })
		local count = 0
		for _, target in ipairs(args.targets) do
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Sit = false
				count += 1
			end
		end
		ctx:Success(string.format("Stood %d player(s) up", count))
	end)
