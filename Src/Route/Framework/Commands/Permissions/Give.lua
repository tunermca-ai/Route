--!strict
-- A short, single-purpose alternative to `role give <player> <role>` for
-- the common case: hand a player a role and nothing else. `role` still
-- covers create/delete/give/remove/permissions if that's ever needed;
-- `give` is just the fast path for "make this player an Admin."
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("give")
	:description("Give a player a role - Owner, Admin, or any custom role")
	:category("Permissions")
	:permission("permissions.manage")
	:arg(Types.player, "target", "Player to grant the role to")
	:arg(Types.role, "role", "Role to grant, e.g. Admin")
	:audit(true)
	:example("give Player Admin")
	:example("give Player Tester")
	:run(function(ctx: any, args: { [string]: any })
		local Permissions = ctx.Route.Permissions
		local ok, err = Permissions:AddToRole(args.target, args.role.Name)
		if ok then
			ctx:Success(string.format("Gave %s the %s role", args.target.Name, args.role.Name))
			ctx.Route.Audit:Log({
				Action = "RoleChanged",
				Actor = ctx.Player,
				Metadata = { Description = string.format("gave %s to %s", args.role.Name, args.target.Name) },
			})
		else
			ctx:Error(err or "failed to give role")
		end
	end)
