--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("history")
	:description("Show recent command history, optionally filtered by player")
	:category("Debug")
	:aliases("route.history")
	:permission("debug.history")
	:arg(Types.player, "target", "Only show this player's history")
		:optional()
	:example("history")
	:example("history Player")
	:run(function(ctx: any, args: { [string]: any })
		local entries = ctx.Route.History:Get({
			UserId = args.target and args.target.UserId,
			Limit = 15,
		})
		if #entries == 0 then
			ctx:Reply("No history recorded yet.")
			return
		end
		local lines = {}
		for _, entry in ipairs(entries) do
			table.insert(lines, string.format(
				"[%s] %s ran %s (%s)",
				os.date("%H:%M:%S", entry.Timestamp),
				entry.Username,
				entry.Command,
				if entry.Success then "ok" else "failed"
			))
		end
		ctx:Reply(table.concat(lines, "\n"))
	end)
