--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local Restraint = require(script.Parent.Parent.Parent.Moderation.Restraint)

return Command.new("jail")
	:description("Teleport and lock a player at the configured jail position")
	:category("Moderation")
	:permission("moderation.jail")
	:arg(Types.player, "target", "Player to jail")
	:arg(Types.string, "reason", "Reason")
		:optional()
		:rest()
	:audit(true)
	:example("jail Player")
	:example("jail Player Griefing while a report is reviewed")
	:run(function(ctx: any, args: { [string]: any })
		local character = args.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			ctx:Error(string.format("%s doesn't have an active character.", args.target.Name))
			return
		end
		local Config = ctx.Route.Config
		local jailPosition = Vector3.new(
			Config:Get("Moderation.JailPosition.X") :: number,
			Config:Get("Moderation.JailPosition.Y") :: number,
			Config:Get("Moderation.JailPosition.Z") :: number
		)
		local ok, err = Restraint.Jail(character, humanoid, CFrame.new(jailPosition))
		if not ok then
			ctx:Warn(string.format("%s is %s.", args.target.Name, err or "already jailed"))
			return
		end
		ctx:Success(string.format("Jailed %s%s", args.target.Name, if args.reason then " (" .. args.reason .. ")" else ""))
	end)
