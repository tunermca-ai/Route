--!strict
-- Switches (or reports) which of Route.UI.Themes the running player's own
-- console is using. Entirely cosmetic - never touches permissions, so no
-- :permission() node is declared, same as `help`.
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types
local Themes = require(script.Parent.Parent.Parent.UI.Themes)

return Command.new("theme")
	:description("Switch (or check) which console theme you're using")
	:category("Debug")
	:arg(Types.enum(Themes.Ids), "id", "cmdr, midnight, terminal, or floating")
		:optional()
	:example("theme")
	:example("theme cmdr")
	:example("theme floating")
	:run(function(ctx: any, args: { [string]: any })
		local UI = ctx.Route.UI
		if not UI then
			ctx:Error("The console UI isn't running on this server (headless mode?).")
			return
		end

		if not args.id then
			local current = UI:GetTheme(ctx.Player)
			local lines = {}
			for _, theme in ipairs(UI:ListThemes()) do
				local label = string.format("%s (%s)", theme.Name, theme.Id)
				if theme.Id == current.Id then
					label = "<b>" .. label .. "</b> - current"
				end
				table.insert(lines, label)
			end
			ctx:Reply(table.concat(lines, "\n") .. "\n\nUse `theme id` to switch, e.g. `theme cmdr`.")
			return
		end

		local themeId = args.id :: string
		-- Sent before the switch below, not after: SetTheme destroys
		-- and rebuilds this player's whole console, including the
		-- Controller LocalScript that's mid-way through handling this
		-- very command - a Success sent afterward would be talking to
		-- an instance that no longer exists by the time it arrives.
		ctx:Success(string.format('Switching to the "%s" theme...', Themes.ById[themeId].Name))
		local ok, err = UI:SetTheme(ctx.Player, themeId)
		if not ok then
			warn(string.format("[Route] theme switch failed for %s: %s", ctx.Player.Name, tostring(err)))
		end
	end)
