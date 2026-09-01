--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

local Players = game:GetService("Players")

return Command.new("serverinfo")
	:description("Show information about this server")
	:category("Server")
	:aliases("placeinfo")
	:permission("server.info")
	:example("serverinfo")
	:run(function(ctx: any)
		ctx:Reply(string.format(
			"PlaceId: %d | JobId: %s | Players: %d/%d",
			game.PlaceId,
			game.JobId ~= "" and game.JobId or "(Studio)",
			#Players:GetPlayers(),
			Players.MaxPlayers
		))
	end)
