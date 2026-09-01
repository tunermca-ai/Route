--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("size")
	:description("Scale a player's character")
	:category("Fun")
	:permission("fun.size")
	:arg(Types.player, "target", "Player to scale")
	:arg(Types.number, "scale", "Scale multiplier (1 = normal)")
		:min(0.1)
		:max(10)
	:cooldown(2)
	:example("size Player 2")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		for _, scaleName in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
			local scaleValue = humanoid:FindFirstChild(scaleName) :: NumberValue?
			if scaleValue then
				scaleValue.Value = args.scale
			end
		end
		ctx:Success(string.format("Scaled %s to %gx", args.target.Name, args.scale))
	end)
