--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("jump")
	:description("Force a player's character to jump")
	:category("Players")
	:permission("players.jump")
	:arg(Types.players, "targets", "Player(s) to jump")
	:cooldown(1)
	:example("jump Player")
	:example("jump all")
	:run(function(ctx: any, args: { [string]: any })
		local count = 0
		for _, target in ipairs(args.targets) do
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Jump = true
				count += 1
			end
		end
		ctx:Success(string.format("Made %d player(s) jump", count))
	end)
