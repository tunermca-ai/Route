--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

return Command.new("lock")
	:description("Lock the server (blocks commands guarded by ServerUnlocked)")
	:category("Server")
	:permission("server.lock")
	:audit(true)
	:example("lock")
	:run(function(ctx: any)
		ctx.Route.Config:Set("Server.Locked", true)
		ctx:Success("Server locked.")
	end)
