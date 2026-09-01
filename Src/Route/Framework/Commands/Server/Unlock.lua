--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

return Command.new("unlock")
	:description("Unlock the server")
	:category("Server")
	:permission("server.lock")
	:audit(true)
	:example("unlock")
	:run(function(ctx: any)
		ctx.Route.Config:Set("Server.Locked", false)
		ctx:Success("Server unlocked.")
	end)
