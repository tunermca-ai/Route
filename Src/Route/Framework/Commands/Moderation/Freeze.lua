--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local Restraint = require(script.Parent.Parent.Parent.Moderation.Restraint)

return Command.new("freeze")
	:description("Lock a player in place - zero WalkSpeed/JumpPower, anchored")
	:category("Moderation")
	:permission("moderation.freeze")
	:arg(Types.player, "target", "Player to freeze")
	:arg(Types.string, "reason", "Reason")
		:optional()
		:rest()
	:audit(true)
	:example("freeze Player")
	:example("freeze Player AFK during a report")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local ok, err = Restraint.Freeze(character, humanoid)
		if not ok then
			ctx:Warn(string.format("%s is %s.", args.target.Name, err or "already frozen"))
			return
		end
		ctx:Success(string.format("Froze %s%s", args.target.Name, if args.reason then " (" .. args.reason .. ")" else ""))
	end)
