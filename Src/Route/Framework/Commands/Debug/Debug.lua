--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

local function formatErrors(entries: { any }): string
	if #entries == 0 then
		return "No errors recorded."
	end
	local lines = {}
	for _, entry in ipairs(entries) do
		local err = entry.Error
		table.insert(lines, err:ToString())
	end
	return table.concat(lines, "\n")
end

return Command.new("debug")
	:description("Introspect Route: status, commands, types, performance, errors")
	:category("Debug")
	:aliases("route.debug")
	:permission("debug.view")
	:arg(Types.enum({
		"status", "commands", "types", "permissions", "performance",
		"memory", "errors", "logs", "profile", "slow",
	}), "action")
	:arg(Types.string, "target", "Command name, for `profile`")
		:optional()
	:example("debug status")
	:example("debug profile kick")
	:example("debug slow")
	:run(function(ctx: any, args: { [string]: any })
		local Route = ctx.Route
		local Debug = Route.Debug

		if args.action == "status" then
			local status = Debug:Status()
			ctx:Reply(string.format(
				"Commands: %d | Types: %d | Guards: %d | Permissions: %d\nErrors: %d | Uptime: %.0fs | Memory: %.0f KB",
				status.Commands, status.Types, status.Guards, status.Permissions,
				status.Errors, status.UptimeSeconds, status.MemoryKB
			))
		elseif args.action == "commands" then
			local names = {}
			for _, command in ipairs(Route.Commands:GetAll()) do
				table.insert(names, command.Name .. (command.Enabled and "" or " (disabled)"))
			end
			ctx:Reply(string.format("%d commands: %s", #names, table.concat(names, ", ")))
		elseif args.action == "types" then
			local names = {}
			for _, def in ipairs(Route.Types:GetAll()) do
				table.insert(names, def.Name)
			end
			ctx:Reply(string.format("%d types: %s", #names, table.concat(names, ", ")))
		elseif args.action == "permissions" then
			ctx:Reply(string.format("%d known nodes: %s", #Route.Permissions:GetKnownNodes(), table.concat(Route.Permissions:GetKnownNodes(), ", ")))
		elseif args.action == "performance" then
			local lines = {}
			for _, profile in ipairs(Debug:GetAllProfiles()) do
				table.insert(lines, string.format(
					"%s: %d exec, avg %.4fs, max %.4fs, %d failure(s)",
					profile.Command, profile.Executions, profile.Average, profile.Maximum, profile.Failures
				))
			end
			ctx:Reply(if #lines > 0 then table.concat(lines, "\n") else "No commands have been profiled yet.")
		elseif args.action == "memory" then
			ctx:Reply(string.format("Lua heap: %.0f KB", Debug:GetMemoryKB()))
		elseif args.action == "errors" or args.action == "logs" then
			ctx:Reply(formatErrors(Debug:GetErrors(10)))
		elseif args.action == "profile" then
			if not args.target then
				ctx:Error("Usage: debug profile <command>")
				return
			end
			local profile = Debug:GetProfile(args.target)
			if not profile then
				ctx:Warn(string.format('No profiling data for "%s" yet.', args.target))
				return
			end
			ctx:Reply(string.format(
				"Command: %s\nExecutions: %d\nAverage: %.4fs\nMinimum: %.4fs\nMaximum: %.4fs\nFailures: %d",
				profile.Command, profile.Executions, profile.Average, profile.Minimum, profile.Maximum, profile.Failures
			))
		elseif args.action == "slow" then
			local slow = Debug:GetSlow()
			if #slow == 0 then
				ctx:Reply("Nothing looks slow.")
				return
			end
			local lines = {}
			for _, profile in ipairs(slow) do
				table.insert(lines, string.format("%s: avg %.4fs", profile.Command, profile.Average))
			end
			ctx:Reply(table.concat(lines, "\n"))
		end
	end)
