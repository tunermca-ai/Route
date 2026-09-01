--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local Restraint = require(script.Parent.Parent.Parent.Moderation.Restraint)

return Command.new("unfreeze")
	:description("Release a player from /freeze")
	:category("Moderation")
	:permission("moderation.freeze")
	:arg(Types.player, "target", "Player to unfreeze")
	:audit(true)
	:example("unfreeze Player")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local ok, err = Restraint.Unfreeze(character, humanoid)
		if not ok then
			ctx:Warn(string.format("%s is %s.", args.target.Name, err or "not frozen"))
			return
		end
		ctx:Success(string.format("Unfroze %s", args.target.Name))
	end)
