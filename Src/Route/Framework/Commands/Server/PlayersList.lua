--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

local Players = game:GetService("Players")

return Command.new("players")
	:description("List everyone currently online")
	:category("Server")
	:permission("server.info")
	:example("players")
	:run(function(ctx: any)
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(names, player.Name)
		end
		ctx:Reply(string.format("%d online: %s", #names, table.concat(names, ", ")))
	end)
