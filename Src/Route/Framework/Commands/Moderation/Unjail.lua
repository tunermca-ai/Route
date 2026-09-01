--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local Restraint = require(script.Parent.Parent.Parent.Moderation.Restraint)

return Command.new("unjail")
	:description("Release a player from /jail and return them to where they were")
	:category("Moderation")
	:permission("moderation.jail")
	:arg(Types.player, "target", "Player to unjail")
	:audit(true)
	:example("unjail Player")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local ok, err = Restraint.Unjail(character, humanoid)
		if not ok then
			ctx:Warn(string.format("%s is %s.", args.target.Name, err or "not jailed"))
			return
		end
		ctx:Success(string.format("Unjailed %s", args.target.Name))
	end)
