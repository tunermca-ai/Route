--!strict
-- Route.UI
-- The console's entire client-facing surface lives here, inside the
-- Framework, and nowhere else - there is no StarterGui or
-- StarterPlayerScripts tree for it. Route.Start() calls UI.Start(), which
-- builds a fresh GUI (see Build.lua) for every player who joins and clones
-- the one inert Controller LocalScript straight into it before handing the
-- whole thing to that player's PlayerGui. Nothing is pre-placed anywhere a
-- Studio Explorer or a Rojo sync of StarterGui could find it beforehand.
--
-- Also owns per-player theme selection (see Themes.lua) - which theme a
-- given player is using is UI state, not permission/role state, so it
-- lives here rather than in Permissions.

local Players = game:GetService("Players")
local Build = require(script.Build)
local Themes = require(script.Themes)

export type UIOptions = {
	Enabled: boolean?,
	Theme: string?, -- default theme Id for anyone who hasn't picked their own; falls back to Themes.Default if unrecognized
}

local UI = {}

-- Returns an object with GetTheme/GetThemeName/ListThemeNames/SetTheme, or
-- nil if the UI was disabled (StartOptions.UI = { Enabled = false }) or
-- its Controller template is missing. Core/init.lua assigns whatever this
-- returns to Route.UI.
--
-- `emit`, if given, is Core.lua's own Route.On event broadcaster - passed
-- through rather than required directly so this module has no dependency
-- on Core/Signal at all when nobody's listening for UI events. Currently
-- only used to fire "ThemeChanged" from SetTheme below.
--
-- `clientCommandModules`, if given, is Core.lua's { commandName ->
-- ModuleScript } map of every :runClient() command's own source module
-- (see Command:runClient and Core.lua's registerCommandFactory). Each one
-- gets cloned into every player's console below, right alongside the
-- Controller LocalScript - see the "ClientCommands" folder in `build`.
function UI.Start(options: UIOptions?, emit: ((string, ...any) -> ())?, clientCommandModules: { [string]: ModuleScript }?): any
	if options and options.Enabled == false then
		return nil
	end

	local controllerTemplate = script:FindFirstChild("Controller")
	if not controllerTemplate then
		warn("[Route] UI.Controller template is missing - the console will not be given to players.")
		return nil
	end

	local defaultThemeId = (options and options.Theme) or Themes.Default.Id
	if not Themes.ById[defaultThemeId] then
		warn(string.format('[Route] UI: unknown default theme "%s", falling back to "%s"', defaultThemeId, Themes.Default.Id))
		defaultThemeId = Themes.Default.Id
	end

	-- Which theme each player is currently using - in-memory only, purely
	-- cosmetic, resets on rejoin/server restart same as everything else
	-- Route doesn't persist to a DataStore.
	local playerThemeIds: { [Player]: string } = {}

	local function themeFor(player: Player): Themes.Theme
		return Themes.ById[playerThemeIds[player] or defaultThemeId] or Themes.Default
	end

	-- `autoOpen` is only true for a live theme switch (see SetTheme below) -
	-- a fresh join should still open with a quiet F2 press, not pop the
	-- console open unasked the moment someone loads in.
	local function build(player: Player, autoOpen: boolean): boolean
		local playerGui = player:WaitForChild("PlayerGui", 30)
		if not playerGui or not playerGui:IsA("PlayerGui") then
			return false
		end

		local existing = playerGui:FindFirstChild("RouteUI")
		if existing then
			-- Rebuilding (a fresh join, or a live theme switch) always
			-- starts from a clean slate - the old Controller LocalScript
			-- and every connection it made go with the old instance.
			existing:Destroy()
		end

		local screenGui = Build.Create(themeFor(player), player.Name)
		if autoOpen then
			-- Read by Controller.client.lua at startup - opens itself
			-- immediately instead of waiting for F2, so switching themes
			-- doesn't look like the console just vanished.
			screenGui:SetAttribute("AutoOpen", true)
		end

		-- Every :runClient() command's real source ModuleScript gets
		-- cloned in here too. That's the only way its code can end up
		-- somewhere this player's client can actually require() it -
		-- ServerScriptService (where the original lives) never replicates
		-- to clients at all, cloned or not, so this is the one instance
		-- of it a client will ever see. Controller.client.lua requires
		-- every child of this folder fresh, right when it starts up.
		if clientCommandModules and next(clientCommandModules) then
			local clientCommandsFolder = Instance.new("Folder")
			clientCommandsFolder.Name = "ClientCommands"
			for _, moduleScript in pairs(clientCommandModules) do
				local clone = moduleScript:Clone()
				clone.Parent = clientCommandsFolder
			end
			clientCommandsFolder.Parent = screenGui
		end

		-- The Controller LocalScript sits inert (never runs) as long as
		-- it's a child of this ModuleScript inside ServerScriptService.
		-- Cloning it out and enabling it only happens here, per player,
		-- only because a console UI genuinely needs client code to read
		-- that player's own keystrokes - if Route is ever run headless
		-- (no UI), UI.Start() simply isn't called and nothing client-side
		-- is ever created for anyone.
		local controller = controllerTemplate:Clone() :: LocalScript
		controller.Enabled = true
		controller.Parent = screenGui
		screenGui.Parent = playerGui
		return true
	end

	local function attach(player: Player)
		local ok, err = pcall(build, player, false)
		if not ok then
			warn(string.format("[Route] failed to set up the console for %s: %s", player.Name, tostring(err)))
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(attach, player)
	end
	Players.PlayerAdded:Connect(attach)
	Players.PlayerRemoving:Connect(function(player)
		playerThemeIds[player] = nil
	end)

	local self = {}

	function self:GetTheme(player: Player): Themes.Theme
		return themeFor(player)
	end

	function self:GetThemeName(player: Player): string
		return themeFor(player).Name
	end

	function self:ListThemes(): { Themes.Theme }
		return Themes.List
	end

	-- Switches the given player's console to a different theme, right now
	-- - destroys and rebuilds their RouteUI on the spot (see `build`
	-- above), so it takes effect immediately, no rejoin required. `id`
	-- must be one of Themes.Ids (e.g. "cmdr", "midnight") - see
	-- Commands/RouteMeta/Theme.lua, the only caller that matters here,
	-- for how a player's typed theme name gets turned into one of those.
	function self:SetTheme(player: Player, id: string): (boolean, string?)
		local theme = Themes.ById[id]
		if not theme then
			return false, string.format('no theme named "%s" - try one of: %s', id, table.concat(Themes.Ids, ", "))
		end
		playerThemeIds[player] = theme.Id
		local ok, err = pcall(build, player, true)
		if not ok then
			return false, tostring(err)
		end
		if emit then
			emit("ThemeChanged", player, theme.Id)
		end
		return true, nil
	end

	return self
end

return UI
