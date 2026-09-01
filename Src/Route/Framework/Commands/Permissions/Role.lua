--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

local Players = game:GetService("Players")

local function findPlayer(name: string): Player?
	local lower = name:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower() == lower then
			return player
		end
	end
	return nil
end

return Command.new("role")
	:description("Create/delete roles and manage who has them")
	:category("Permissions")
	:permission("permissions.manage")
	:arg(Types.enum({ "give", "remove", "create", "delete", "permissions" }), "action")
	:arg(Types.string, "arg1", "Player name (give/remove) or role name (create/delete/permissions)")
	:arg(Types.string, "arg2", "Role name (give/remove) or comma-separated permissions (create)")
		:optional()
		:rest()
	:audit(true)
	:example("role create Moderator moderation.kick,moderation.warn")
	:example("role give Player Moderator")
	:example("role remove Player Moderator")
	:example("role delete Moderator")
	:example("role permissions Moderator")
	:run(function(ctx: any, args: { [string]: any })
		local Permissions = ctx.Route.Permissions

		if args.action == "create" then
			local perms = {}
			if args.arg2 then
				for _, node in ipairs(string.split(args.arg2, ",")) do
					local trimmed = node:match("^%s*(.-)%s*$")
					if trimmed ~= "" then
						table.insert(perms, trimmed)
					end
				end
			end
			local ok, err = Permissions:CreateRole(args.arg1, perms)
			if ok then
				ctx:Success(string.format("Created role %s with %d permission(s)", args.arg1, #perms))
			else
				ctx:Error(err or "failed to create role")
			end
			return
		end

		if args.action == "delete" then
			if Permissions:DeleteRole(args.arg1) then
				ctx:Success(string.format("Deleted role %s", args.arg1))
			else
				ctx:Error(string.format('No role named "%s"', args.arg1))
			end
			return
		end

		if args.action == "permissions" then
			local role = Permissions:GetRole(args.arg1)
			if not role then
				ctx:Error(string.format('No role named "%s"', args.arg1))
				return
			end
			local nodes = {}
			for node in pairs(role.Permissions) do
				table.insert(nodes, node)
			end
			table.sort(nodes)
			ctx:Reply(string.format(
				"%s: %s%s",
				role.Name,
				if #nodes > 0 then table.concat(nodes, ", ") else "(none)",
				if #role.Inherits > 0 then " | inherits: " .. table.concat(role.Inherits, ", ") else ""
			))
			return
		end

		-- give / remove need a real target player
		local target = findPlayer(args.arg1)
		if not target then
			ctx:Error(string.format('No online player named "%s"', args.arg1))
			return
		end
		if not args.arg2 then
			ctx:Error("Missing argument: role name")
			return
		end

		if args.action == "give" then
			local ok, err = Permissions:AddToRole(target, args.arg2)
			if ok then
				ctx:Success(string.format("Gave %s the %s role", target.Name, args.arg2))
				ctx.Route.Audit:Log({
					Action = "RoleChanged",
					Actor = ctx.Player,
					Metadata = { Description = string.format("gave %s to %s", args.arg2, target.Name) },
				})
			else
				ctx:Error(err or "failed to add to role")
			end
		else -- remove
			if Permissions:RemoveFromRole(target, args.arg2) then
				ctx:Success(string.format("Removed %s from %s", target.Name, args.arg2))
				ctx.Route.Audit:Log({
					Action = "RoleChanged",
					Actor = ctx.Player,
					Metadata = { Description = string.format("removed %s from %s", args.arg2, target.Name) },
				})
			else
				ctx:Error(string.format("%s didn't have that role", target.Name))
			end
		end
	end)
