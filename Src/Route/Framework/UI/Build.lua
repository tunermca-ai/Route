--!strict
-- Route.UI.Build
-- Builds the entire console GUI tree from scratch, server-side, on demand
-- for one player at a time (see UI/init.lua). Nothing in this module runs
-- on a client and nothing here is a template sitting in StarterGui - the
-- Instance tree only comes into existence the moment a player is handed
-- their own copy.
--
-- Everything visual - colors, fonts, corner rounding, and whether the
-- console docks at the top-left or floats centered on screen - comes from
-- a Theme (see UI/Themes.lua), passed in by the caller. Build.Create()
-- itself has no opinion on any of that; it only knows how to assemble the
-- tree given whatever theme it's handed.

local Themes = require(script.Parent.Themes)

local DOCK_WIDTH = 640
local HEADER_HEIGHT = 34
local OUTPUT_HEIGHT = 210
local INPUT_HEIGHT = 46

type Props = { [string]: any }

local function new(className: string, props: Props?, children: { Instance }?): Instance
	local inst = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	return inst
end

local Build = {}

-- Returns the fully assembled ScreenGui, unparented. The caller (UI/init.lua)
-- is responsible for cloning the inert Controller LocalScript into it and
-- parenting the whole thing into a specific player's PlayerGui.
function Build.Create(theme: Themes.Theme?, playerName: string?): ScreenGui
	local t: Themes.Theme = theme or Themes.Default
	local COLORS = t.Colors

	-- "TopLeftDock" used to keep a flush-top tab look by pushing the whole
	-- dock up so its rounded top corners sat behind Roblox's own topbar and
	-- never showed - but that trick only reads cleanly when something
	-- opaque (the header) covers the sliver of curve it exposes right at
	-- the screen edge. Now that every theme hides its header, there's
	-- nothing left to cover that sliver, so headerless themes skip the
	-- push entirely and just sit a few pixels below the topbar instead -
	-- all four corners round the same way, nothing peeking out above them.
	-- "FloatingCentered" (Floating Console) never pushed at all - it shows
	-- all four rounded corners, sitting centered on screen instead.
	local isFloating = t.DockStyle == "FloatingCentered"
	local topHidden = if isFloating or not t.ShowHeader then 0 else t.CornerRadius
	local topGap = if isFloating or t.ShowHeader then 0 else 8 -- breathing room under the topbar once nothing's pushed up to hide behind it

	local corner = new("UICorner", { CornerRadius = UDim.new(0, t.CornerRadius) })

	-- A hairline border in the theme's own accent color - the console used
	-- to read its edge off the header sitting flush against the screen
	-- top; without one, a plain fill has nothing to separate it from
	-- whatever's behind it (Draw War's sky is bright blue), so this gives
	-- it a defined edge instead of looking like a flat cutout.
	local stroke = new("UIStroke", {
		Color = COLORS.Accent,
		Transparency = 0.6,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local wordmark = new("TextLabel", {
		Name = "Wordmark",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, 120, 1, 0),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Accent,
		Text = "R O U T E",
	})

	local roleTag = new("TextLabel", {
		Name = "RoleTag",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 140, 0, 0),
		Size = UDim2.new(0, 160, 1, 0),
		Font = t.Font,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})

	local clock = new("TextLabel", {
		Name = "Clock",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -140, 0, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Font = t.MonoFont,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = COLORS.SubText,
		Text = "--:--",
	})

	local hotkeyHint = new("TextLabel", {
		Name = "HotkeyHint",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -56, 0, 0),
		Size = UDim2.new(0, 40, 1, 0),
		Font = t.Font,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = COLORS.SubText,
		Text = "F2",
	})

	-- Themes with ShowHeader = false (Cmdr) still get a real Header
	-- instance - just invisible and left out of the layout math below -
	-- rather than omitting it outright. Controller.client.lua always does
	-- `dock:WaitForChild("Header")` with no timeout; if the instance
	-- didn't exist at all for this theme, that call would hang forever
	-- and the whole script would never get past its first few lines.
	local header = new("Frame", {
		Name = "Header",
		Visible = t.ShowHeader,
		Active = true, -- lets it catch InputBegan for dragging (Draggable themes only - harmless otherwise)
		BackgroundColor3 = COLORS.Header,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, topHidden),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
	}, { wordmark, roleTag, clock, hotkeyHint })

	local divider = new("Frame", {
		Name = "Divider",
		Visible = t.ShowHeader,
		BackgroundColor3 = COLORS.Divider,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, topHidden + HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, 1),
	})

	-- How much vertical space the header block actually reserves in the
	-- stack below - zero when this theme hides it, so the output panel
	-- starts right where the header would have been instead of leaving a
	-- gap for an invisible bar.
	local headerBlockHeight = if t.ShowHeader then HEADER_HEIGHT + 1 else 0

	-- ---- Output -------------------------------------------------------
	local dot = new("Frame", {
		Name = "Dot",
		BackgroundColor3 = COLORS.Info,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 6),
		Size = UDim2.new(0, 6, 0, 6),
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local timeLabel = new("TextLabel", {
		Name = "Time",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, 58, 0, 16),
		Font = t.MonoFont,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Timestamp,
		Text = "--:--",
	})

	local messageLabel = new("TextLabel", {
		Name = "Message",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 78, 0, 0),
		Size = UDim2.new(1, -90, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = t.Font,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.Text,
		RichText = true,
		Text = "",
	})

	local lineTemplate = new("Frame", {
		Name = "LineTemplate",
		Visible = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { dot, timeLabel, messageLabel })

	local outputLayout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})

	local outputPadding = new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	})

	local output = new("ScrollingFrame", {
		Name = "Output",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, topHidden + headerBlockHeight),
		Size = UDim2.new(1, 0, 0, OUTPUT_HEIGHT),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COLORS.Accent,
		ScrollBarImageTransparency = 0.5,
	}, { outputLayout, outputPadding, lineTemplate })

	-- ---- Input row -------------------------------------------------------
	-- Themes without a PromptFormat keep the plain arrow this always was.
	-- Cmdr's does not - its real console shows "Username@Cmdr$ ", not an
	-- arrow, which is as recognizably "Cmdr" as the missing header is.
	-- AutomaticSize lets this size itself to whatever that text actually
	-- renders as (a username's length isn't known at build time) -
	-- Controller.client.lua reflows the input box to start right after it
	-- once it's actually rendered client-side (see reflowInputRow there).
	local promptText = if t.PromptFormat then string.format(t.PromptFormat, playerName or "Player") else "\226\128\186"
	local prompt = new("TextLabel", {
		Name = "Prompt",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0, 18, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = t.MonoFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Accent,
		Text = promptText,
	})

	local input = new("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -46, 1, 0),
		Font = t.MonoFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Text,
		PlaceholderColor3 = COLORS.SubText,
		PlaceholderText = "Type a command\226\128\166",
		Text = "",
		ClearTextOnFocus = false,
	})

	local focusRing = new("Frame", {
		Name = "FocusRing",
		BackgroundColor3 = COLORS.Accent,
		BackgroundTransparency = 1, -- Controller animates this on Focused/FocusLost
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
	})

	local inputRow = new("Frame", {
		Name = "InputRow",
		BackgroundColor3 = COLORS.Header,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, topHidden + headerBlockHeight + OUTPUT_HEIGHT),
		Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
	}, { prompt, input, focusRing })

	-- ---- Hint bar (Cmdr-style: the resolved command's signature, with
	-- whichever argument is currently being typed picked out in the accent
	-- color, plus its description) and the suggestions dropdown - both
	-- float below the input row inside one auto-sizing Overlay, stacked
	-- with a UIListLayout, so neither reserves space when hidden and
	-- either can show without the other. -----------------------------------
	local hintSignature = new("TextLabel", {
		Name = "Signature",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = t.MonoFont,
		TextSize = 13,
		RichText = true, -- server-built from command/argument names only, never player input
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Text,
		Text = "",
	})

	local hintDescription = new("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = t.Font,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.SubText,
		Text = "",
	})

	local hint = new("Frame", {
		Name = "Hint",
		Visible = false,
		LayoutOrder = 1,
		BackgroundColor3 = COLORS.Header,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, math.min(10, t.CornerRadius + 4)) }),
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		hintSignature,
		hintDescription,
	})

	local itemTemplate = new("TextButton", {
		Name = "ItemTemplate",
		Visible = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Font = t.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Text,
		AutoButtonColor = false,
		Text = "",
	}, { new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

	local suggestionsLayout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local suggestions = new("ScrollingFrame", {
		Name = "Suggestions",
		Visible = false,
		LayoutOrder = 2,
		BackgroundColor3 = COLORS.Header,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ZIndex = 5,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, math.min(10, t.CornerRadius + 4)) }),
		suggestionsLayout,
		itemTemplate,
	})

	local overlay = new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
	}, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		hint,
		suggestions,
	})
	overlay.Parent = inputRow

	local dockWidth = if t.Width then UDim.new(t.Width.Scale, t.Width.Offset) else UDim.new(0, DOCK_WIDTH)
	local dockSize = UDim2.new(dockWidth.Scale, dockWidth.Offset, 0, topHidden + headerBlockHeight + OUTPUT_HEIGHT + INPUT_HEIGHT)
	local dockAnchor, dockPosition
	if t.DockStyle == "FloatingCentered" then
		-- Floating Console: centered, a little above true vertical center
		-- so it doesn't sit right on top of the middle of the screen.
		dockAnchor = Vector2.new(0.5, 0.5)
		dockPosition = UDim2.new(0.5, 0, 0.4, 0)
	else
		-- Every other theme docks flush at the top-left, tucked just under
		-- Roblox's own topbar icon cluster (see the ScreenGui's
		-- IgnoreGuiInset below). Cmdr uses this same corner too - just
		-- wider (see Theme.Width) - not a top-center bar.
		dockAnchor = Vector2.new(0, 0)
		dockPosition = UDim2.new(0, 12, 0, topGap - topHidden)
	end

	local dock = new("Frame", {
		Name = "Dock",
		AnchorPoint = dockAnchor,
		Position = dockPosition,
		Size = dockSize,
		BackgroundColor3 = COLORS.Dock,
		BackgroundTransparency = t.BackgroundTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, { corner, stroke, header, divider, output, inputRow })
	dock:SetAttribute("Draggable", t.Draggable)

	local screenGui = new("ScreenGui", {
		Name = "RouteUI",
		Enabled = false, -- Controller toggles this on (F2 / server-driven show)
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- respects Roblox's own topbar safe area in every theme
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	}, { dock }) :: ScreenGui

	return screenGui
end

return Build
