--!strict
-- Route.Network
-- The only module allowed to touch remotes. It trusts nothing the client
-- sends except raw text - the calling player always comes from the
-- RemoteEvent's own `player` argument (never from the payload), every
-- request is rate-limited independently of any per-command cooldown,
-- and all real work is delegated straight back to Core's pipeline.

local RemoteSetup = require(script.RemoteSetup)

export type NetworkDeps = {
	Config: any,
	Cooldowns: any,
	Suggestions: any,
	Execute: (player: Player, raw: string, sink: (any) -> ()) -> any,
	Route: any,
	VersionString: string,
}

local Network = {}

local MAX_RAW_LENGTH = 500
local MAX_AUTOCOMPLETE_LENGTH = 200

function Network.Start(deps: NetworkDeps): any
	local remotes = RemoteSetup.Setup()

	remotes.Command.OnServerEvent:Connect(function(player: Player, raw: any)
		if typeof(raw) ~= "string" then
			return
		end
		if #raw == 0 or #raw > MAX_RAW_LENGTH then
			return
		end

		local maxPerMinute = deps.Config:Get("RateLimit.MaxPerMinute") :: number
		if not deps.Cooldowns:CheckRateLimit(player, maxPerMinute, "command") then
			remotes.Response:FireClient(player, {
				Type = "Warn",
				Message = "You're sending commands too quickly - slow down.",
			})
			return
		end

		deps.Execute(player, raw, function(payload: any)
			remotes.Response:FireClient(player, payload)
		end)
	end)

	remotes.Autocomplete.OnServerInvoke = function(player: Player, input: any): any
		-- { Suggestions = { SuggestionEntry, ... }, Hint = HintInfo? } - see
		-- Suggestions/init.lua. Hint is only present once the command name
		-- typed so far resolves to something real.
		if typeof(input) ~= "string" then
			return { Suggestions = {} }
		end
		if #input > MAX_AUTOCOMPLETE_LENGTH then
			return { Suggestions = {} }
		end

		local maxPerMinute = deps.Config:Get("RateLimit.AutocompletePerMinute") :: number
		if not deps.Cooldowns:CheckRateLimit(player, maxPerMinute, "autocomplete") then
			return { Suggestions = {} }
		end

		local context = { Player = player, Route = deps.Route }
		local ok, suggestionList, hint = pcall(function()
			return deps.Suggestions:Get(context, input)
		end)
		if not ok then
			return { Suggestions = {} }
		end
		return { Suggestions = suggestionList, Hint = hint }
	end

	remotes.Bootstrap.OnServerInvoke = function(player: Player): any
		-- Deliberately limited to things about the requesting player
		-- themselves - their own role names, not permission internals, not
		-- anyone else's roles, no webhook state, nothing the client
		-- couldn't be trusted to see about itself.
		local roles = {}
		local ok = pcall(function()
			roles = deps.Route.Permissions:GetRoles(player)
		end)
		if not ok then
			roles = {}
		end

		-- Static per-theme colors (Dock, Header, Accent, ...) are already
		-- baked into the GUI instances by UI/Build.lua at construction
		-- time. This is only for the colors Controller.client.lua decides
		-- at runtime instead - which color a response line's dot gets, the
		-- focus ring, the selected-suggestion highlight - which need to
		-- match the SAME theme without duplicating its values by hand.
		local themeColors = nil
		local okTheme = pcall(function()
			themeColors = deps.Route.UI:GetTheme(player).Colors
		end)
		if not okTheme then
			themeColors = nil
		end

		return {
			Prefix = deps.Config:Get("Prefix"),
			Version = deps.VersionString,
			Roles = roles,
			ThemeColors = themeColors,
		}
	end

	return {
		Remotes = remotes,
	}
end

return Network
