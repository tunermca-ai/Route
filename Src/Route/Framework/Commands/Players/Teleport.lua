--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("teleport")
	:description("Teleport one player to another")
	:category("Players")
	:aliases("tp")
	:permission("players.teleport")
	:arg(Types.player, "from", "Player to move")
	:arg(Types.player, "to", "Player to move them to")
	:cooldown(1)
	:example("teleport Player1 Player2")
	:run(function(ctx: any, args: { [string]: any })
		local fromCharacter = args.from.Character
		local fromRoot = fromCharacter and fromCharacter:FindFirstChild("HumanoidRootPart")
		local toCharacter = args.to.Character
		local toRoot = toCharacter and toCharacter:FindFirstChild("HumanoidRootPart")
		if not fromRoot or not toRoot then
			ctx:Error("Both players need an active character.")
			return
		end
		fromRoot.CFrame = toRoot.CFrame + Vector3.new(3, 0, 0)
		ctx:Success(string.format("Teleported %s to %s", args.from.Name, args.to.Name))
	end)
