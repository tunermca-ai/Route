--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

local Workspace = game:GetService("Workspace")

return Command.new("gravity")
	:description("Set workspace gravity")
	:category("Fun")
	:permission("fun.gravity")
	:arg(Types.number, "amount", "New gravity (Roblox default is 196.2)")
		:min(0)
		:max(2000)
	:audit(true)
	:example("gravity 50")
	:run(function(ctx: any, args: { [string]: any })
		Workspace.Gravity = args.amount
		ctx:Success(string.format("Gravity set to %g", args.amount))
	end)
