--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("respawn")
	:description("Respawn a player's character")
	:category("Players")
	:permission("players.respawn")
	:arg(Types.player, "target", "Player to respawn")
	:cooldown(2)
	:example("respawn Player")
	:run(function(ctx: any, args: { [string]: any })
		args.target:LoadCharacter()
		ctx:Success(string.format("Respawned %s", args.target.Name))
	end)
