--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("perm")
	:description("Grant, revoke, or check one or more permission nodes on a player")
	:category("Permissions")
	:aliases("permission")
	:permission("permissions.manage")
	:arg(Types.enum({ "give", "remove", "check" }), "action")
	:arg(Types.player, "target", "Player")
	:arg(Types.permissionNodes, "nodes", 'Permission node(s) - comma-separate for several, e.g. moderation.kick,fun.explode, or "all" for every node')
	:audit(true)
	:example("perm give Player moderation.kick")
	:example("perm give Player fun.explode,fun.spin,fun.gravity")
	:example("perm give Player all")
	:example("perm remove Player moderation.kick")
	:example("perm check Player moderation.kick")
	:run(function(ctx: any, args: { [string]: any })
		local Permissions = ctx.Route.Permissions
		local nodes = args.nodes :: { string }
		local nodeList = table.concat(nodes, ", ")

		if args.action == "give" then
			for _, node in ipairs(nodes) do
				Permissions:Grant(args.target, node)
			end
			ctx:Success(string.format("Granted %s to %s", nodeList, args.target.Name))
			ctx.Route.Audit:Log({
				Action = "PermissionChanged",
				Actor = ctx.Player,
				Metadata = { Description = string.format("granted %s to %s", nodeList, args.target.Name) },
			})
		elseif args.action == "remove" then
			for _, node in ipairs(nodes) do
				Permissions:Revoke(args.target, node)
			end
			ctx:Success(string.format("Revoked %s from %s", nodeList, args.target.Name))
			ctx.Route.Audit:Log({
				Action = "PermissionChanged",
				Actor = ctx.Player,
				Metadata = { Description = string.format("revoked %s from %s", nodeList, args.target.Name) },
			})
		else -- check
			local lines = {}
			for _, node in ipairs(nodes) do
				local has = Permissions:Has(args.target, node)
				table.insert(lines, string.format("%s %s %s", args.target.Name, if has then "HAS" else "does NOT have", node))
			end
			ctx:Reply(table.concat(lines, "\n"))
		end
	end)
