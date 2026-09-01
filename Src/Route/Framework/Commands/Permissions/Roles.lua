--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command = Route.Command

return Command.new("roles")
	:description("List every role that exists")
	:category("Permissions")
	:permission("permissions.manage")
	:example("roles")
	:run(function(ctx: any)
		local roles = ctx.Route.Permissions:ListRoles()
		if #roles == 0 then
			ctx:Reply("No roles have been created yet.")
			return
		end
		local lines = {}
		for _, role in ipairs(roles) do
			local count = 0
			for _ in pairs(role.Permissions) do
				count += 1
			end
			table.insert(lines, string.format("%s (%d permission(s))", role.Name, count))
		end
		ctx:Reply(table.concat(lines, "\n"))
	end)
