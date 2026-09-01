--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("explode")
	:description("Spawn an explosion at a player")
	:category("Fun")
	:permission("fun.explode")
	:arg(Types.player, "target", "Player to explode at")
	:cooldown(2)
	:example("explode Player")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local explosion = Instance.new("Explosion")
		explosion.Position = (root :: BasePart).Position
		explosion.BlastRadius = 12
		explosion.BlastPressure = 500000
		explosion.Parent = workspace
		ctx:Success(string.format("Exploded at %s", args.target.Name))
	end)
