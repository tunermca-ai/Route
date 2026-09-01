--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types, Guards = Route.Command, Route.Types, Route.Guards

local Players = game:GetService("Players")

return Command.new("shutdown")
	:description("Kick every player, closing the server")
	:category("Server")
	:permission("server.shutdown")
	:guard(Guards.IsOwner)
	:arg(Types.string, "reason", "Shown to everyone as they're kicked")
		:optional()
		:rest()
	:audit(true)
	:example("shutdown Restarting for an update")
	:run(function(ctx: any, args: { [string]: any })
		local reason = args.reason or "The server is shutting down."
		for _, player in ipairs(Players:GetPlayers()) do
			player:Kick(reason)
		end
	end)
