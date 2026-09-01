--!strict
-- Route.UI.Themes
-- Named color/layout presets that UI/Build.lua builds the console from.
-- Purely data - Build.lua interprets every theme the same way regardless
-- of which one is picked, so adding a fifth theme later is just adding
-- another entry here, no changes needed anywhere else.
--
-- Each theme has an `Id` (a single lowercase word - what players actually
-- type to the `theme` command and what Tab-completion fills in) and a
-- `Name` (the pretty, spaced display form shown in listings). The two are
-- kept separate on purpose: Route's own command parser tokenizes on
-- whitespace, so "theme Midnight Console" would be read as two arguments,
-- not one - see Commands/RouteMeta/Theme.lua for how the two are used.

export type ThemeColors = {
	Dock: Color3,
	Header: Color3,
	Divider: Color3,
	Accent: Color3,
	Text: Color3,
	SubText: Color3,
	Timestamp: Color3,
	Success: Color3,
	Error: Color3,
	Warn: Color3,
	Info: Color3,
	Log: Color3,
}

export type Theme = {
	Id: string,
	Name: string,
	Colors: ThemeColors,
	Font: Enum.Font, -- body text: labels, descriptions
	MonoFont: Enum.Font, -- input, prompt, timestamps - anything meant to read as a terminal
	CornerRadius: number,
	BackgroundTransparency: number,
	DockStyle: "TopLeftDock" | "FloatingCentered",
	ShowHeader: boolean, -- false hides the wordmark/role/clock bar entirely - Cmdr's own console has no such header, just a bar
	Draggable: boolean, -- true lets the player drag the console by its header anywhere on screen (see UI/Controller.client.lua) - only makes sense alongside ShowHeader = true, since the header is the drag handle
	-- Overrides Build.lua's default fixed DOCK_WIDTH when set - a plain
	-- Scale/Offset pair so a theme can be a fraction of the screen's width
	-- (Cmdr's real bar is wide, not a fixed 640px tab) instead of a fixed
	-- pixel width. Nil for every theme except "cmdr" below.
	Width: { Scale: number, Offset: number }?,
	-- A string.format template with exactly one %s for the player's own
	-- username, replacing the generic arrow prompt with a real
	-- shell-style one - Cmdr's actual console shows "Username@Cmdr$ ", not
	-- an arrow. Nil for every theme except "cmdr" below, which keeps the
	-- plain arrow for everyone else exactly as it already was.
	PromptFormat: string?,
}

local Themes = {}

local list: { Theme } = {
	{
		Id = "cmdr",
		Name = "Cmdr",
		-- Cmdr's own real look isn't just dark-and-square - it's a wide,
		-- thin, translucent bar, with no visible "panel" of its own: no
		-- header bar, no second-toned footer strip under the output, no
		-- opaque card background. Header is set equal to Dock (below) so
		-- the input row and the hint/suggestion popups read as the same
		-- continuous surface instead of a two-tone panel-with-a-footer,
		-- and BackgroundTransparency is a real translucency instead of 0,
		-- so it reads as an overlay sitting on top of the game rather
		-- than a solid card. Docked top-left like every other non-
		-- floating theme (see Width below for why it's still much wider
		-- than the others despite sharing their DockStyle).
		Colors = {
			Dock = Color3.fromRGB(12, 12, 12),
			Header = Color3.fromRGB(12, 12, 12),
			Divider = Color3.fromRGB(40, 40, 40),
			-- Cmdr's real accent is the gold/amber of its own
			-- "Username@Cmdr$" prompt, not white - see PromptFormat below.
			Accent = Color3.fromRGB(230, 190, 90),
			Text = Color3.fromRGB(240, 240, 240),
			SubText = Color3.fromRGB(160, 160, 160),
			Timestamp = Color3.fromRGB(120, 120, 120),
			Success = Color3.fromRGB(120, 220, 120),
			Error = Color3.fromRGB(230, 90, 90),
			Warn = Color3.fromRGB(230, 190, 90),
			Info = Color3.fromRGB(200, 200, 200),
			Log = Color3.fromRGB(150, 150, 150),
		},
		Font = Enum.Font.Gotham,
		MonoFont = Enum.Font.Code,
		CornerRadius = 0,
		-- Genuinely translucent, not a solid card - the game should show
		-- through it, same as Cmdr's own console does.
		BackgroundTransparency = 0.35,
		DockStyle = "TopLeftDock",
		-- Cmdr's real console has no wordmark/role/clock bar at all - just
		-- an input line with output above it. Dropping the header is what
		-- actually makes this theme read as Cmdr, not just its colors.
		ShowHeader = false,
		Draggable = false,
		-- Wider than the fixed DOCK_WIDTH every other TopLeftDock theme
		-- uses (see Width's own doc comment above) - Cmdr's real bar
		-- spans a lot more of the screen than a small corner tab.
		Width = { Scale = 0.5, Offset = 0 },
		PromptFormat = "%s@Cmdr$ ",
	},
	{
		Id = "midnight",
		Name = "Midnight Console",
		-- Route's own default look - Noah's blue palette (Glaucous accent,
		-- Baby Blue Ice for Info) on a deep near-black panel.
		Colors = {
			Dock = Color3.fromRGB(16, 17, 22),
			Header = Color3.fromRGB(27, 29, 39), -- a touch lighter than Dock so the input row reads as its own band, not just more flat black
			Divider = Color3.fromRGB(48, 45, 62),
			Accent = Color3.fromRGB(94, 124, 226),
			Text = Color3.fromRGB(232, 234, 240),
			SubText = Color3.fromRGB(138, 141, 156),
			Timestamp = Color3.fromRGB(104, 107, 122),
			Success = Color3.fromRGB(94, 222, 156),
			Error = Color3.fromRGB(255, 99, 99),
			Warn = Color3.fromRGB(255, 179, 71),
			Info = Color3.fromRGB(146, 180, 244),
			Log = Color3.fromRGB(150, 153, 165),
		},
		Font = Enum.Font.Gotham,
		MonoFont = Enum.Font.Code,
		CornerRadius = 18,
		BackgroundTransparency = 0.03,
		DockStyle = "TopLeftDock",
		ShowHeader = false, -- Noah: top bar (wordmark/role/clock/F2 hint) removed - Cmdr proves
		                    -- this is a fully supported path, not a hack (see Build.lua)
		Draggable = false,
	},
	{
		Id = "terminal",
		Name = "Clean Terminal",
		-- Flat, high-contrast, fully monospace - reads like an actual
		-- terminal emulator rather than a game HUD panel: square corners,
		-- no translucency, a single green-on-black accent instead of a
		-- decorative brand color.
		Colors = {
			Dock = Color3.fromRGB(8, 8, 8),
			Header = Color3.fromRGB(8, 8, 8),
			Divider = Color3.fromRGB(38, 38, 38),
			Accent = Color3.fromRGB(80, 250, 123),
			Text = Color3.fromRGB(220, 220, 220),
			SubText = Color3.fromRGB(130, 130, 130),
			Timestamp = Color3.fromRGB(90, 90, 90),
			Success = Color3.fromRGB(80, 250, 123),
			Error = Color3.fromRGB(255, 85, 85),
			Warn = Color3.fromRGB(241, 250, 140),
			Info = Color3.fromRGB(139, 233, 253),
			Log = Color3.fromRGB(150, 150, 150),
		},
		Font = Enum.Font.Code,
		MonoFont = Enum.Font.Code,
		CornerRadius = 0,
		BackgroundTransparency = 0,
		DockStyle = "TopLeftDock",
		ShowHeader = false, -- Noah: top bar removed here too, see "midnight" above
		Draggable = false,
	},
	{
		Id = "floating",
		Name = "Floating Console",
		-- The console's original look, before it moved to a top-left dock:
		-- a centered floating window with all four corners rounded, rather
		-- than a tab permanently attached to the screen edge.
		Colors = {
			Dock = Color3.fromRGB(18, 19, 24),
			Header = Color3.fromRGB(23, 24, 30),
			Divider = Color3.fromRGB(50, 47, 64),
			Accent = Color3.fromRGB(94, 124, 226),
			Text = Color3.fromRGB(232, 234, 240),
			SubText = Color3.fromRGB(138, 141, 156),
			Timestamp = Color3.fromRGB(104, 107, 122),
			Success = Color3.fromRGB(94, 222, 156),
			Error = Color3.fromRGB(255, 99, 99),
			Warn = Color3.fromRGB(255, 179, 71),
			Info = Color3.fromRGB(146, 180, 244),
			Log = Color3.fromRGB(150, 153, 165),
		},
		Font = Enum.Font.Gotham,
		MonoFont = Enum.Font.Code,
		CornerRadius = 12,
		BackgroundTransparency = 0.03,
		DockStyle = "FloatingCentered",
		-- Noah: top bar removed. It doubled as this theme's drag handle, so
		-- Draggable comes off with it - nothing left to grab it by. Give the
		-- dock a fixed centered position instead if you want it movable again.
		ShowHeader = false,
		Draggable = false,
	},
}

Themes.List = list

Themes.ById = {} :: { [string]: Theme }
Themes.Ids = {} :: { string }
Themes.Names = {} :: { string }
for _, theme in ipairs(list) do
	Themes.ById[theme.Id] = theme
	table.insert(Themes.Ids, theme.Id)
	table.insert(Themes.Names, theme.Name)
end

Themes.Default = Themes.ById.midnight

return Themes
