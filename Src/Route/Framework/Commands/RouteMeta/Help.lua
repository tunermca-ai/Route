--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

return Command.new("help")
	:description("Show available commands, or details about one command or category")
	:category("Debug")
	:arg(Types.string, "query", "Command name or category")
		:optional()
	:example("help")
	:example("help kick")
	:example("help Moderation")
	:run(function(ctx: any, args: { [string]: any })
		local Route = ctx.Route

		if not args.query then
			-- Full table: every category as a bold header followed by the
			-- actual command names filed under it, Cmdr-style - not just
			-- category names and counts, which told you a category existed
			-- but nothing about what was in it.
			local categories = Route.Commands:GetCategories()
			local sections = {}
			for _, category in ipairs(categories) do
				local commands = Route.Commands:GetCategory(category)
				local names = {}
				for _, command in ipairs(commands) do
					if not command.Hidden then
						table.insert(names, command.Name)
					end
				end
				if #names > 0 then
					-- Bolded and accent-colored, matching the console's own
					-- highlight color (see UI/Build.lua's Accent / the hint
					-- bar in Suggestions/init.lua) - a real RichText table of
					-- categories, Cmdr-style, not a plain-text dump.
					table.insert(
						sections,
						string.format(
							'<font color="#5E7CE2"><b>%s</b></font> (%d)\n  %s',
							category,
							#names,
							table.concat(names, ", ")
						)
					)
				end
			end
			-- No literal "<" / ">" anywhere in this trailing line on purpose -
			-- mixed into the same RichText string as the <font>/<b> tags
			-- above, "help <category>" would do the exact same thing that
			-- broke the usage hint bar: an unrecognized tag drags the whole
			-- string down to showing every tag raw. See Suggestions/init.lua's
			-- escapeRichText comment for the full story.
			ctx:Reply(table.concat(sections, "\n\n") .. "\n\nUse `help category` or `help command` for details.")
			return
		end

		local command = Route.Commands:Find(args.query)
		if command then
			if command.Hidden and not ctx:HasPermission(command.Permission or "*") then
				ctx:Warn(string.format('No command named "%s"', args.query))
				return
			end
			local lines = {
				command.Name .. (#command.Aliases > 0 and (" (" .. table.concat(command.Aliases, ", ") .. ")") or ""),
				command.Description,
				"Usage: " .. command:GetUsage(),
			}
			if command.Permission then
				table.insert(lines, "Permission: " .. command.Permission)
			end
			if #command.Examples > 0 then
				table.insert(lines, "Examples:\n  " .. table.concat(command.Examples, "\n  "))
			end
			ctx:Reply(table.concat(lines, "\n"))
			return
		end

		local inCategory = Route.Commands:GetCategory(args.query)
		if #inCategory > 0 then
			local names = {}
			for _, cmd in ipairs(inCategory) do
				if not cmd.Hidden then
					table.insert(names, cmd.Name)
				end
			end
			ctx:Reply(string.format("%s: %s", args.query, table.concat(names, ", ")))
			return
		end

		ctx:Warn(string.format('No command or category named "%s"', args.query))
	end)
