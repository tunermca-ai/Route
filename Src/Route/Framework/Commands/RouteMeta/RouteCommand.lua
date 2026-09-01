--!strict
-- The `route` meta-command: framework-level operations that don't belong
-- to any single subsystem's own command (perm/role own permission
-- management, config owns configuration, debug owns introspection - this
-- one covers info/pack/command/reload/discord).
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types, Guards = Route.Command, Route.Types, Route.Guards

local function splitFirst(text: string): (string, string?)
	local space = text:find("%s")
	if not space then
		return text, nil
	end
	return text:sub(1, space - 1), text:sub(space + 1)
end

return Command.new("route")
	:description("Route framework administration: info, packs, discord, reload")
	:category("Debug")
	:permission("route.admin")
	:guard(Guards.IsOwner)
	:arg(Types.enum({ "info", "pack", "command", "reload", "discord" }), "action")
	:arg(Types.string, "arg1", "")
		:optional()
	:arg(Types.string, "arg2", "")
		:optional()
		:rest()
	:example("route info")
	:example("route pack disable Fun")
	:example("route command disable fun.explode")
	:example("route discord webhook set https://discord.com/api/webhooks/...")
	:example("route discord events disable CommandExecuted")
	:example("route reload")
	:run(function(ctx: any, args: { [string]: any })
		local Route = ctx.Route

		if args.action == "info" then
			local status = Route.Debug:Status()
			ctx:Reply(string.format(
				"Route v%s | Commands: %d | Types: %d | Guards: %d | Permissions: %d | Uptime: %.0fs",
				Route.VersionString, status.Commands, status.Types, status.Guards, status.Permissions, status.UptimeSeconds
			))
			return
		end

		if args.action == "reload" then
			local result = Route.Reload()
			ctx:Success(string.format("Reload complete: %d command(s) loaded, %d error(s)", result.Loaded, #result.Errors))
			return
		end

		if args.action == "pack" then
			if not args.arg1 or not args.arg2 then
				ctx:Error("Usage: route pack <enable|disable> <category>")
				return
			end
			local enable = args.arg1 == "enable"
			local commands = Route.Commands:GetCategory(args.arg2)
			if #commands == 0 then
				ctx:Warn(string.format('No commands in category "%s"', args.arg2))
				return
			end
			for _, command in ipairs(commands) do
				Route.Commands:SetEnabled(command.Name, enable)
			end
			ctx:Success(string.format("%s %d command(s) in %s", if enable then "Enabled" else "Disabled", #commands, args.arg2))
			return
		end

		if args.action == "command" then
			if not args.arg1 or not args.arg2 then
				ctx:Error("Usage: route command <enable|disable|status> <commandName>")
				return
			end
			local command = Route.Commands:Get(args.arg2)
			if not command then
				ctx:Error(string.format('No command named "%s"', args.arg2))
				return
			end
			if args.arg1 == "status" then
				ctx:Reply(string.format("%s is %s", command.Name, if command.Enabled then "enabled" else "disabled"))
			else
				Route.Commands:SetEnabled(args.arg2, args.arg1 == "enable")
				ctx:Success(string.format("%s %s", if args.arg1 == "enable" then "Enabled" else "Disabled", args.arg2))
			end
			return
		end

		if args.action == "discord" then
			if not args.arg1 then
				local status = Route.Discord:Status()
				ctx:Reply(string.format("Discord: %s, webhook %s", if status.Enabled then "enabled" else "disabled", if status.Configured then "configured" else "not configured"))
				return
			end

			if args.arg1 == "webhook" then
				local subAction, value = splitFirst(args.arg2 or "")
				if subAction == "set" then
					if not value or value == "" then
						ctx:Error("Usage: route discord webhook set <url>")
						return
					end
					local ok, err = Route.Discord:SetWebhook(value)
					ctx:Reply(if ok then "Webhook configured." else ("Failed: " .. (err or "unknown error")))
				elseif subAction == "enable" then
					local ok, err = Route.Discord:Enable()
					ctx:Reply(if ok then "Discord webhook enabled." else ("Failed: " .. (err or "")))
				elseif subAction == "disable" then
					Route.Discord:Disable()
					ctx:Reply("Discord webhook disabled.")
				elseif subAction == "test" then
					local ok, err = Route.Discord:Test()
					ctx:Reply(if ok then "Test message sent." else ("Failed: " .. (err or "")))
				elseif subAction == "status" then
					local status = Route.Discord:Status()
					ctx:Reply(string.format("Enabled: %s | Configured: %s", tostring(status.Enabled), tostring(status.Configured)))
				elseif subAction == "clear" then
					Route.Discord:ClearWebhook()
					ctx:Reply("Webhook cleared.")
				else
					ctx:Error("Usage: route discord webhook <set|enable|disable|test|status|clear>")
				end
				return
			end

			if args.arg1 == "events" then
				local subAction, eventName = splitFirst(args.arg2 or "")
				if not eventName then
					ctx:Error("Usage: route discord events <enable|disable> <EventName>")
					return
				end
				local ok
				if subAction == "enable" then
					ok = Route.Discord:EnableEvent(eventName)
				elseif subAction == "disable" then
					ok = Route.Discord:DisableEvent(eventName)
				end
				if ok then
					ctx:Success(string.format("%s %s", subAction, eventName))
				else
					ctx:Error(string.format('Unknown event "%s". Known: %s', eventName, table.concat(Route.Discord:GetKnownEvents(), ", ")))
				end
				return
			end

			ctx:Error("Usage: route discord <webhook|events> ...")
		end
	end)
