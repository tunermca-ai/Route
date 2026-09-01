--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("damage")
	:description("Deal damage to a player's character")
	:category("Players")
	:permission("players.damage")
	:arg(Types.players, "targets", "Player(s) to damage")
	:arg(Types.number, "amount", "Damage to deal")
		:min(0)
		:max(1000)
	:cooldown(1)
	:example("damage Player 25")
	:example("damage @others 10")
	:run(function(ctx: any, args: { [string]: any })
		local count = 0
		for _, target in ipairs(args.targets) do
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- TakeDamage (rather than setting .Health directly) respects
				-- the same rules a normal hit would, e.g. a spawn ForceField.
				humanoid:TakeDamage(args.amount)
				count += 1
			end
		end
		ctx:Success(string.format("Damaged %d player(s) for %g", count, args.amount))
	end)
