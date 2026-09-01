--!strict
-- Route.UI.Controller (LocalScript)
--
-- This is the ONE piece of Route that has to run on the client, and it
-- exists only because Roblox itself draws the line there: PlayerGui
-- content is only ever visible to the one client it belongs to, and
-- events like TextBox.FocusLost or UserInputService.InputBegan simply do
-- not fire on the server for any engine, framework, or design choice to
-- get around - there is no server-side API that can read a specific
-- player's live keystrokes or manage their TextBox focus.
--
-- Everything else about "no client" still holds: this script carries no
-- game logic, no permission checks, no validation, and no state that
-- matters. It reads text out of a box, forwards it to the server, and
-- paints back whatever the server decides to say - exactly the same
-- trust boundary Route's Network module already documents. It is not
-- authored or shipped anywhere in a client-side source tree; it lives as
-- an inert child of Route.UI inside ServerScriptService/Route/Framework
-- and only starts running the moment the server clones it out to a
-- specific player's PlayerGui (see UI/init.lua). There is no StarterGui,
-- no StarterPlayerScripts, and nothing under this game's client tree at
-- all - this file *is* the Framework, just running where it has to.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local screenGui = script.Parent :: ScreenGui
local dock = screenGui:WaitForChild("Dock") :: Frame
local header = dock:WaitForChild("Header") :: Frame
local clockLabel = header:WaitForChild("Clock") :: TextLabel
local roleTag = header:WaitForChild("RoleTag") :: TextLabel
local output = dock:WaitForChild("Output") :: ScrollingFrame
local lineTemplate = output:WaitForChild("LineTemplate") :: Frame
local inputRow = dock:WaitForChild("InputRow") :: Frame
local prompt = inputRow:WaitForChild("Prompt") :: TextLabel
local input = inputRow:WaitForChild("Input") :: TextBox
local focusRing = inputRow:WaitForChild("FocusRing") :: Frame
local overlay = inputRow:WaitForChild("Overlay") :: Frame

-- Prompt is AutomaticSize.X server-side (Build.lua) because its text
-- varies per theme - most themes render a fixed one-character arrow, but
-- Cmdr's real one is "Username@Cmdr$ ", whose width depends on the
-- player's own username and can't be known until it's actually rendered
-- here on the client. Once it is, slide Input (and the space it's
-- allotted) over to start right after it, instead of leaving Build.lua's
-- guess of "roughly arrow-sized" baked in for a much longer prompt.
local function reflowInputRow()
	local promptRight = prompt.Position.X.Offset + prompt.AbsoluteSize.X
	local gap = 6
	local leftEdge = promptRight + gap
	input.Position = UDim2.new(0, leftEdge, 0, 0)
	input.Size = UDim2.new(1, -(leftEdge + 14), 1, 0)
end
reflowInputRow()
prompt:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflowInputRow)
local hintFrame = overlay:WaitForChild("Hint") :: Frame
local hintSignatureLabel = hintFrame:WaitForChild("Signature") :: TextLabel
local hintDescriptionLabel = hintFrame:WaitForChild("Description") :: TextLabel
local suggestions = overlay:WaitForChild("Suggestions") :: ScrollingFrame
local itemTemplate = suggestions:WaitForChild("ItemTemplate") :: TextButton

-- Starts as the Midnight Console defaults (the fallback UI/Themes.lua
-- itself falls back to) so there's something sane to render with for the
-- one frame or so before Bootstrap resolves below. Mutated in place, not
-- replaced, once the real answer comes back - every earlier closure that
-- read COLORS.Whatever keeps working, since they all read through the
-- same table reference rather than capturing values up front.
local COLORS = {
	Accent = Color3.fromRGB(94, 124, 226),
	Success = Color3.fromRGB(94, 222, 156),
	Error = Color3.fromRGB(255, 99, 99),
	Warn = Color3.fromRGB(255, 179, 71),
	Info = Color3.fromRGB(146, 180, 244),
	Log = Color3.fromRGB(150, 153, 165),
}
local PANEL_TRANSPARENCY = 0.02 -- resting BackgroundTransparency for Hint/Suggestions (see Build.lua)

local function colorForType(responseType: string?): Color3
	if responseType == "Success" then
		return COLORS.Success
	elseif responseType == "Error" then
		return COLORS.Error
	elseif responseType == "Warn" then
		return COLORS.Warn
	elseif responseType == "Log" then
		return COLORS.Log
	end
	return COLORS.Info
end

local remotesFolder = ReplicatedStorage:WaitForChild("RouteRemotes")
local CommandRemote = remotesFolder:WaitForChild("Command") :: RemoteEvent
local ResponseRemote = remotesFolder:WaitForChild("Response") :: RemoteEvent
local AutocompleteRemote = remotesFolder:WaitForChild("Autocomplete") :: RemoteFunction
local BootstrapRemote = remotesFolder:WaitForChild("Bootstrap") :: RemoteFunction

-- ===== Tweens ================================================================
local OPEN_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local FADE_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LINE_FADE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fadeShow(frame: GuiObject)
	if not frame.Visible then
		frame.BackgroundTransparency = 1
		frame.Visible = true
	end
	TweenService:Create(frame, FADE_TWEEN_INFO, { BackgroundTransparency = PANEL_TRANSPARENCY }):Play()
end

local function fadeHide(frame: GuiObject)
	if not frame.Visible then
		return
	end
	local tween = TweenService:Create(frame, FADE_TWEEN_INFO, { BackgroundTransparency = 1 })
	tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed then
			frame.Visible = false
			frame.BackgroundTransparency = PANEL_TRANSPARENCY
		end
	end)
	tween:Play()
end

-- ===== Clock ================================================================
local function timeString(): string
	local text = os.date("%I:%M %p")
	return (text :: string):gsub("^0", "")
end

task.spawn(function()
	while screenGui.Parent do
		clockLabel.Text = timeString()
		task.wait(1)
	end
end)

-- ===== Bootstrap =============================================================
task.spawn(function()
	local ok, result = pcall(function()
		return BootstrapRemote:InvokeServer()
	end)
	if ok and type(result) == "table" then
		local roles = result.Roles
		if type(roles) == "table" and #roles > 0 then
			roleTag.Text = table.concat(roles, ", ")
		else
			roleTag.Text = "Player"
		end
		if type(result.ThemeColors) == "table" then
			for key, value in pairs(result.ThemeColors) do
				if typeof(value) == "Color3" then
					COLORS[key] = value
				end
			end
		end
	end
end)

-- ===== Output panel: collapsed/hidden when there's nothing logged yet, and
-- tweened open the moment a line lands - the log only takes up space once
-- there's something in it, the same "history panel" behavior Cmdr's own
-- console has, instead of always reserving a fixed empty block. ============
local OUTPUT_FULL_HEIGHT = output.Size.Y.Offset -- read once from Build.lua's own sizing, not duplicated by hand
local inputRowExpandedPosition = inputRow.Position
local inputRowCollapsedPosition = UDim2.new(
	inputRowExpandedPosition.X.Scale,
	inputRowExpandedPosition.X.Offset,
	inputRowExpandedPosition.Y.Scale,
	inputRowExpandedPosition.Y.Offset - OUTPUT_FULL_HEIGHT
)
local dockExpandedSize = dock.Size
local dockCollapsedSize = UDim2.new(
	dockExpandedSize.X.Scale,
	dockExpandedSize.X.Offset,
	dockExpandedSize.Y.Scale,
	dockExpandedSize.Y.Offset - OUTPUT_FULL_HEIGHT
)

local outputExpanded = false
-- Start collapsed to match reality (nothing's been logged yet). Applied
-- instantly, not tweened - the console isn't shown yet at this point in
-- script startup, so there's nothing to animate for anyone to see.
output.Size = UDim2.new(1, 0, 0, 0)
inputRow.Position = inputRowCollapsedPosition
dock.Size = dockCollapsedSize

local function setOutputExpanded(expanded: boolean)
	if expanded == outputExpanded then
		return
	end
	outputExpanded = expanded
	local info = if expanded then OPEN_TWEEN_INFO else CLOSE_TWEEN_INFO
	TweenService:Create(output, info, {
		Size = if expanded then UDim2.new(1, 0, 0, OUTPUT_FULL_HEIGHT) else UDim2.new(1, 0, 0, 0),
	}):Play()
	TweenService:Create(inputRow, info, {
		Position = if expanded then inputRowExpandedPosition else inputRowCollapsedPosition,
	}):Play()
	TweenService:Create(dock, info, {
		Size = if expanded then dockExpandedSize else dockCollapsedSize,
	}):Play()
end

-- ===== Output ================================================================
local function scrollToBottom()
	task.defer(function()
		output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y - output.AbsoluteSize.Y))
	end)
end

local function appendLine(responseType: string?, message: string?)
	setOutputExpanded(true)

	local line = lineTemplate:Clone()
	line.Name = "Line"
	line.Visible = true
	line.LayoutOrder = os.clock() * 1000 // 1

	local dot = line:FindFirstChild("Dot") :: Frame?
	local timeLabel = line:FindFirstChild("Time") :: TextLabel?
	local messageLabel = line:FindFirstChild("Message") :: TextLabel?

	-- Start invisible and tween in - a quick fade rather than lines just
	-- popping into the log.
	if dot then
		dot.BackgroundColor3 = colorForType(responseType)
		dot.BackgroundTransparency = 1
	end
	if timeLabel then
		timeLabel.Text = timeString()
		timeLabel.TextTransparency = 1
	end
	if messageLabel then
		messageLabel.Text = tostring(message or "")
		messageLabel.TextTransparency = 1
	end

	line.Parent = output

	if dot then
		TweenService:Create(dot, LINE_FADE_INFO, { BackgroundTransparency = 0 }):Play()
	end
	if timeLabel then
		TweenService:Create(timeLabel, LINE_FADE_INFO, { TextTransparency = 0 }):Play()
	end
	if messageLabel then
		TweenService:Create(messageLabel, LINE_FADE_INFO, { TextTransparency = 0 }):Play()
	end

	-- Cap scrollback so a long session can't grow the line count forever.
	local lines = output:GetChildren()
	local count = 0
	for _, child in ipairs(lines) do
		if child.Name == "Line" then
			count += 1
		end
	end
	if count > 200 then
		for _, child in ipairs(lines) do
			if child.Name == "Line" then
				child:Destroy()
				break
			end
		end
	end

	scrollToBottom()
end

local function clearOutput()
	for _, child in ipairs(output:GetChildren()) do
		if child.Name == "Line" then
			child:Destroy()
		end
	end
	setOutputExpanded(false)
end

ResponseRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	appendLine(payload.Type, payload.Message)
end)

-- ===== Visibility (F2) =======================================================
local visibleDockPosition = dock.Position
local hiddenDockPosition = UDim2.new(
	visibleDockPosition.X.Scale,
	visibleDockPosition.X.Offset,
	visibleDockPosition.Y.Scale,
	visibleDockPosition.Y.Offset - dockExpandedSize.Y.Offset -- fully clear of the screen above, using the FULL (output-expanded) height so it's always enough no matter how the output panel is currently sized
)

local isOpen = false
local dockTween: Tween? = nil

local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open

	if dockTween then
		dockTween:Cancel()
	end

	if open then
		screenGui.Enabled = true
		dock.Position = hiddenDockPosition
		local openTween = TweenService:Create(dock, OPEN_TWEEN_INFO, { Position = visibleDockPosition })
		dockTween = openTween
		openTween:Play()
		task.defer(function()
			input:CaptureFocus()
		end)
	else
		input:ReleaseFocus(false)
		local closeTween = TweenService:Create(dock, CLOSE_TWEEN_INFO, { Position = hiddenDockPosition })
		dockTween = closeTween
		closeTween.Completed:Connect(function(playbackState: Enum.PlaybackState)
			if playbackState == Enum.PlaybackState.Completed then
				screenGui.Enabled = false
				clearOutput() -- every close starts the next session with a clean log
			end
		end)
		closeTween:Play()
	end
end

UserInputService.InputBegan:Connect(function(gameInput, gameProcessed)
	if gameInput.KeyCode == Enum.KeyCode.F2 then
		setOpen(not isOpen)
	elseif gameInput.KeyCode == Enum.KeyCode.Escape and isOpen and not input:IsFocused() then
		setOpen(false)
	end
end)

-- Click outside to close, the same way Cmdr's own console does: a click or
-- tap that lands outside both the dock and its floating suggestions/hint
-- overlay dismisses the console, exactly as F2 or Escape would.
local function pointInside(guiObject: GuiObject, position: Vector2): boolean
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return position.X >= pos.X and position.X <= pos.X + size.X and position.Y >= pos.Y and position.Y <= pos.Y + size.Y
end

UserInputService.InputBegan:Connect(function(gameInput, gameProcessed)
	if not isOpen then
		return
	end
	if gameInput.UserInputType ~= Enum.UserInputType.MouseButton1 and gameInput.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local position = Vector2.new(gameInput.Position.X, gameInput.Position.Y)
	if pointInside(dock, position) or pointInside(overlay, position) then
		return
	end
	setOpen(false)
end)

-- ===== Drag (theme-dependent - only the "Floating Console" theme sets
-- this attribute) =============================================================
-- Standard Roblox drag-frame pattern: press on the header, track the
-- pointer's movement from wherever it started, offset the dock by the
-- same delta. Dragging is opt-in per theme (see UI/Themes.lua's
-- Draggable field, applied as this attribute in UI/Build.lua) rather than
-- always-on, because it only makes sense for a floating window - the
-- docked themes are meant to stay put.
if dock:GetAttribute("Draggable") then
	local dragging = false
	local dragStartInput = Vector2.zero
	local dragStartPosition = dock.Position

	header.InputBegan:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragStartInput = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
		dragStartPosition = dock.Position

		local endConnection: RBXScriptConnection
		endConnection = inputObject.Changed:Connect(function()
			if inputObject.UserInputState ~= Enum.UserInputState.End then
				return
			end
			dragging = false
			endConnection:Disconnect()
			-- The dragged-to spot becomes the new "open" position from here
			-- on, so closing (F2/Escape/click-outside) and reopening finds
			-- the console where it was left, instead of snapping back to
			-- wherever it first spawned.
			visibleDockPosition = dock.Position
			hiddenDockPosition = UDim2.new(
				visibleDockPosition.X.Scale,
				visibleDockPosition.X.Offset,
				visibleDockPosition.Y.Scale,
				visibleDockPosition.Y.Offset - dockExpandedSize.Y.Offset
			)
		end)
	end)

	UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if not dragging then
			return
		end
		if inputObject.UserInputType ~= Enum.UserInputType.MouseMovement and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local pointerPosition = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
		local delta = pointerPosition - dragStartInput
		dock.Position = UDim2.new(
			dragStartPosition.X.Scale,
			dragStartPosition.X.Offset + delta.X,
			dragStartPosition.Y.Scale,
			dragStartPosition.Y.Offset + delta.Y
		)
	end)
end

-- Focus ring: purely cosmetic, brightens the underline while typing.
input.Focused:Connect(function()
	TweenService:Create(focusRing, FADE_TWEEN_INFO, { BackgroundTransparency = 0.2 }):Play()
end)
input.FocusLost:Connect(function()
	TweenService:Create(focusRing, FADE_TWEEN_INFO, { BackgroundTransparency = 1 }):Play()
end)

-- ===== History (local, cosmetic only - never authoritative) =================
local history: { string } = {}
local historyIndex = 0

-- ===== Suggestions + usage hint ==============================================
local currentSuggestions: { any } = {}
local selectedSuggestion = 0

-- Completes only the token currently being typed (the last run of
-- non-whitespace characters), keeping everything before it untouched -
-- "givecoins Play" + selecting "Player1" has to become
-- "givecoins Player1 ", never just "Player1 " on its own. Also strips any
-- stray tab character defensively - see the Text-changed connection below
-- for why one can end up in here in the first place.
local function applySuggestionValue(value: string)
	local prefix = (input.Text:gsub("\t", ""):gsub("%S+$", ""))
	input.Text = prefix .. value .. " "
	input.CursorPosition = #input.Text + 1
end

local function hideHint()
	fadeHide(hintFrame)
end

local function showHint(hintInfo: any)
	if type(hintInfo) ~= "table" then
		hideHint()
		return
	end
	hintSignatureLabel.Text = tostring(hintInfo.Signature or "")
	hintDescriptionLabel.Text = tostring(hintInfo.Description or "")
	fadeShow(hintFrame)
end

-- ===== Client commands (Command:runClient) ===================================
-- A :runClient() command's whole implementation runs right here, in this
-- LocalScript, the instant it's typed - no CommandRemote:FireServer, no
-- server pipeline, no round trip at all. UI/init.lua already cloned every
-- such command's real source ModuleScript into this ScreenGui, in a
-- ClientCommands folder, right alongside this Controller (see `build` in
-- UI/init.lua) - require()'ing each one here re-runs that module fresh,
-- in this client's own script context, exactly the same
-- "require -> call the returned function -> get a Command" shape
-- Support.DiscoverFactories uses on the server, just done locally instead
-- of by Core's discovery pass. Because these commands register in the
-- same server-side registry as everything else (Core.lua's discovery
-- accepts a :runClient() command same as a :run() one), they show up in
-- autocomplete and the hint bar for free through the normal
-- AutocompleteRemote path below - nothing extra needed here for that.
local ClientCommandApi = {}
ClientCommandApi.__index = ClientCommandApi

function ClientCommandApi:Reply(message: string?)
	appendLine("Info", message)
end

function ClientCommandApi:Success(message: string?)
	appendLine("Success", message)
end

function ClientCommandApi:Warn(message: string?)
	appendLine("Warn", message)
end

function ClientCommandApi:Error(message: string?)
	appendLine("Error", message)
end

function ClientCommandApi:Log(message: string?)
	appendLine("Log", message)
end

-- The one method a server-side Context doesn't have - only makes sense
-- client-side, where "the output" is a real GUI this script owns outright.
function ClientCommandApi:ClearOutput()
	clearOutput()
end

local clientCtx = setmetatable({}, ClientCommandApi)

-- name/alias (lower) -> the built Command, so the submit handler below can
-- look one up in one step the same way Core.lua's registry does.
local clientCommands: { [string]: any } = {}

local clientCommandsFolder = screenGui:FindFirstChild("ClientCommands")
if clientCommandsFolder then
	for _, moduleScript in ipairs(clientCommandsFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local ok, moduleResult = pcall(require, moduleScript)
			if ok then
				-- Same two shapes Support.DiscoverFactories accepts
				-- server-side: the module can return a built Command
				-- directly, or a zero-argument function that returns one.
				local ok2, commandOrErr = if type(moduleResult) == "function"
					then pcall(moduleResult :: () -> any)
					else true, moduleResult
				if ok2 and type(commandOrErr) == "table" and type(commandOrErr.RunClientFn) == "function" then
					clientCommands[tostring(commandOrErr.Name):lower()] = commandOrErr
					for _, alias in ipairs(commandOrErr.Aliases or {}) do
						clientCommands[tostring(alias):lower()] = commandOrErr
					end
				else
					warn(string.format("[Route] client command module %s did not return a :runClient() command", moduleScript:GetFullName()))
				end
			else
				warn(string.format("[Route] failed to load client command %s: %s", moduleScript:GetFullName(), tostring(moduleResult)))
			end
		end
	end
end

local function clearSuggestions()
	currentSuggestions = {}
	selectedSuggestion = 0
	fadeHide(suggestions)
	for _, child in ipairs(suggestions:GetChildren()) do
		if child.Name == "Item" then
			child:Destroy()
		end
	end
	hideHint()
end

local function renderSuggestions()
	for _, child in ipairs(suggestions:GetChildren()) do
		if child.Name == "Item" then
			child:Destroy()
		end
	end
	for index, entry in ipairs(currentSuggestions) do
		local item = itemTemplate:Clone()
		item.Name = "Item"
		item.Visible = true
		item.LayoutOrder = index
		item.Text = tostring(entry.Display or entry.Value or "")
		item.TextColor3 = if index == selectedSuggestion then COLORS.Accent else Color3.fromRGB(232, 234, 240)
		item.MouseButton1Click:Connect(function()
			applySuggestionValue(tostring(entry.Value or ""))
			fadeHide(suggestions)
			input:CaptureFocus()
		end)
		item.Parent = suggestions
	end
	if #currentSuggestions > 0 then
		fadeShow(suggestions)
	else
		fadeHide(suggestions)
	end
end

local requestId = 0
input:GetPropertyChangedSignal("Text"):Connect(function()
	if input.Text:find("\t") then
		-- Roblox TextBoxes happily accept a literal Tab keypress as typed
		-- input; Tab is our autocomplete-fill key (see the InputBegan
		-- handler below), so strip any tab character before it can pollute
		-- the command being typed. Reassigning here re-fires this same
		-- connection with the clean text, so just bail out of this pass.
		input.Text = input.Text:gsub("\t", "")
		return
	end

	if input.Text ~= "" and input.Text:match("^%s+$") then
		-- Whitespace-only text is never a valid command. Something can
		-- leave exactly a lone space behind right after a command runs -
		-- treat it the same as empty so the placeholder ("Type a
		-- command...") shows immediately instead of needing an extra
		-- backspace first.
		input.Text = ""
		return
	end

	requestId += 1
	local myRequest = requestId
	local text = input.Text
	if text == "" then
		clearSuggestions()
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return AutocompleteRemote:InvokeServer(text)
		end)
		if myRequest ~= requestId then
			return -- superseded by a newer keystroke
		end
		if ok and type(result) == "table" then
			currentSuggestions = if type(result.Suggestions) == "table" then result.Suggestions else {}
			selectedSuggestion = 0
			renderSuggestions()
			showHint(result.Hint)
		else
			clearSuggestions()
		end
	end)
end)

-- ===== Submit / navigation ===================================================
input.FocusLost:Connect(function(enterPressed)
	if not enterPressed then
		return
	end
	local text = (input.Text:gsub("^%s*(.-)%s*$", "%1"))
	if text == "" then
		return
	end

	table.insert(history, text)
	historyIndex = #history + 1
	appendLine("Log", "\226\128\186 " .. text)
	clearSuggestions()

	local firstSpace = text:find("%s")
	local commandToken = (if firstSpace then text:sub(1, firstSpace - 1) else text):lower()
	local clientCommand = clientCommands[commandToken]
	if clientCommand then
		-- Whatever's left after the command name, exactly as typed - a
		-- client command gets the raw remainder, not parsed args, since
		-- there's no client-side Types system to parse it with.
		local argsText = if firstSpace then (text:sub(firstSpace + 1):gsub("^%s+", "")) else ""
		local ok, runErr = pcall(clientCommand.RunClientFn :: any, clientCtx, argsText)
		if not ok then
			appendLine("Error", "That command hit an internal error.")
			warn(string.format("[Route] client command '%s' errored: %s", tostring(clientCommand.Name), tostring(runErr)))
		end
	else
		CommandRemote:FireServer(text)
	end

	task.defer(function()
		input.Text = ""
		input:CaptureFocus()
	end)
end)

UserInputService.InputBegan:Connect(function(gameInput, gameProcessed)
	if not input:IsFocused() then
		return
	end
	if gameInput.KeyCode == Enum.KeyCode.Tab and #currentSuggestions > 0 then
		-- Cmdr-style autocomplete: Tab immediately writes the highlighted
		-- suggestion into the input (defaulting to the first one if
		-- nothing's highlighted yet), rather than just highlighting it and
		-- waiting for something else to commit it. Pressing Tab again
		-- cycles to the next match and re-fills with that one instead -
		-- the Text change this causes re-triggers autocomplete on its own
		-- (see the Text-changed connection above), so the suggestion list
		-- naturally moves on to the next argument once a full token is filled.
		selectedSuggestion = if selectedSuggestion <= 0
			then 1
			else (selectedSuggestion % #currentSuggestions) + 1
		local entry = currentSuggestions[selectedSuggestion]
		if entry then
			applySuggestionValue(tostring(entry.Value or ""))
		end
	elseif gameInput.KeyCode == Enum.KeyCode.Up then
		if #currentSuggestions > 0 then
			selectedSuggestion = if selectedSuggestion <= 1 then #currentSuggestions else selectedSuggestion - 1
			renderSuggestions()
		elseif #history > 0 then
			historyIndex = math.max(1, historyIndex - 1)
			input.Text = history[historyIndex] or ""
			input.CursorPosition = #input.Text + 1
		end
	elseif gameInput.KeyCode == Enum.KeyCode.Down then
		if #currentSuggestions > 0 then
			selectedSuggestion = (selectedSuggestion % #currentSuggestions) + 1
			renderSuggestions()
		elseif #history > 0 then
			historyIndex = math.min(#history + 1, historyIndex + 1)
			input.Text = history[historyIndex] or ""
			input.CursorPosition = #input.Text + 1
		end
	end
end)

if screenGui:GetAttribute("AutoOpen") then
	-- Set by UI/init.lua only right after a live theme switch (see
	-- UI:SetTheme) - opens immediately instead of waiting for F2, so
	-- switching themes doesn't look like the console just vanished.
	setOpen(true)
end
