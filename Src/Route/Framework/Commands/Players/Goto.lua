--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("goto")
	:description("Teleport yourself to a player")
	:category("Players")
	:permission("players.teleport")
	:arg(Types.player, "target", "Player to teleport to")
	:cooldown(1)
	:example("goto Player")
	:run(function(ctx: any, args: { [string]: any })
		local myCharacter = ctx.Player.Character
		local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		local theirCharacter = args.target.Character
		local theirRoot = theirCharacter and theirCharacter:FindFirstChild("HumanoidRootPart")
		if not myRoot then
			ctx:Error("You don't have a character right now.")
			return
		end
		if not theirRoot then
			ctx:Error(string.format("%s doesn't have a character right now.", args.target.Name))
			return
		end
		myRoot.CFrame = theirRoot.CFrame + Vector3.new(3, 0, 0)
		ctx:Success(string.format("Teleported to %s", args.target.Name))
	end)
