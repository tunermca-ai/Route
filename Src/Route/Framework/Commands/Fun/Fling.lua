--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("fling")
	:description("Launch a player into the air")
	:category("Fun")
	:permission("fun.fling")
	:arg(Types.player, "target", "Player to fling")
	:arg(Types.number, "power", "Launch strength")
		:optional()
		:default(150)
		:min(10)
		:max(1000)
	:cooldown(2)
	:example("fling Player")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * args.power,
			args.power,
			(math.random() - 0.5) * args.power
		)
		ctx:Success(string.format("Flung %s", args.target.Name))
	end)
