--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("bring")
	:description("Teleport a player to you")
	:category("Players")
	:permission("players.teleport")
	:arg(Types.player, "target", "Player to bring")
	:cooldown(1)
	:example("bring Player")
	:run(function(ctx: any, args: { [string]: any })
		local myCharacter = ctx.Player.Character
		local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		local theirCharacter = args.target.Character
		local theirRoot = theirCharacter and theirCharacter:FindFirstChild("HumanoidRootPart")
		if not myRoot then
			ctx:Error("You don't have a character to bring them to.")
			return
		end
		if not theirRoot then
			ctx:Error(string.format("%s doesn't have a character right now.", args.target.Name))
			return
		end
		theirRoot.CFrame = myRoot.CFrame + Vector3.new(3, 0, 0)
		ctx:Success(string.format("Brought %s to you", args.target.Name))
	end)
