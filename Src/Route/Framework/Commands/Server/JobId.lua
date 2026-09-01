--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

return Command.new("jobid")
	:description("Show this server's JobId")
	:category("Server")
	:permission("server.info")
	:example("jobid")
	:run(function(ctx: any)
		ctx:Reply(game.JobId ~= "" and game.JobId or "(Studio - no JobId)")
	end)
