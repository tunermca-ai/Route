--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("spin")
	:description("Make a player spin uncontrollably for a few seconds")
	:category("Fun")
	:permission("fun.spin")
	:arg(Types.player, "target", "Player to spin")
	:arg(Types.duration, "duration", "How long")
		:optional()
		:default(5)
	:cooldown(2)
	:example("spin Player")
	:example("spin Player 10s")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local spinForce = Instance.new("BodyAngularVelocity")
		spinForce.Name = "RouteSpin"
		spinForce.AngularVelocity = Vector3.new(0, 20, 0)
		spinForce.MaxTorque = Vector3.new(0, math.huge, 0)
		spinForce.Parent = root
		task.delay(args.duration, function()
			if spinForce and spinForce.Parent then
				spinForce:Destroy()
			end
		end)
		ctx:Success(string.format("Spinning %s for %ds", args.target.Name, args.duration))
	end)
