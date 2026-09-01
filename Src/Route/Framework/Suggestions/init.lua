--!strict
-- Route.Suggestions
-- Server-side autocomplete engine. The client only renders whatever this
-- returns - it never decides what a valid next token looks like. Also
-- resolves the Cmdr-style usage hint (command signature + description)
-- shown above the console's suggestion dropdown once a typed command name
-- resolves to something real - see UI/Controller.client.lua.

local Parser = require(script.Parent.Parser)
local Themes = require(script.Parent.UI.Themes)

export type SuggestionEntry = {
	Value: string,
	Display: string,
	Description: string?,
	Kind: string,
}

-- `Signature` is RichText markup (bold + the console's accent color around
-- the argument currently being typed) - safe to hand straight to a
-- RichText-enabled TextLabel as-is, because it's built entirely from
-- developer-authored command/argument names, never anything a player typed.
export type HintInfo = {
	Name: string,
	Signature: string,
	Description: string,
}

local Suggestions = {}
Suggestions.__index = Suggestions

function Suggestions.new(deps: { Registry: any }): any
	local self = setmetatable({
		_deps = deps,
	}, Suggestions)
	return self
end

local function commandSuggestions(registry: any, query: string): { SuggestionEntry }
	local out = {}
	for _, command in ipairs(registry:Search(query)) do
		if not command.Hidden and command.Enabled then
			table.insert(out, {
				Value = command.Name,
				Display = command.Name,
				Description = command.Description,
				Kind = "Command",
			})
		end
	end
	return out
end

-- The Signature is a RichText string, but <required>/[optional] are
-- Cmdr-style usage syntax, not RichText tags - left unescaped, that stray
-- "<" is exactly what tripped up "spin <target>": Roblox can't parse it as
-- a tag, so it gives up on the WHOLE string and shows every tag in it
-- (including the legitimate <font>/<b> below) as raw text. Escaping the
-- literal <, >, and & first keeps the usage brackets visible as plain
-- text while leaving room to wrap the current argument in real markup.
local function escapeRichText(text: string): string
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

local function toHex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- Resolves whichever theme the given player's own console is currently
-- using (see UI/Themes.lua) so the highlight below always matches what
-- they're actually looking at, rather than one hardcoded color that only
-- happened to match the default theme.
local function accentHexFor(context: any): string
	local route = context and context.Route
	local player = context and context.Player
	if route and route.UI and player then
		local ok, theme = pcall(function()
			return route.UI:GetTheme(player)
		end)
		if ok and theme then
			return toHex(theme.Colors.Accent)
		end
	end
	return toHex(Themes.Default.Colors.Accent)
end

-- Same shape as Command:GetUsage() (<required> / [optional] / name... for
-- a rest arg), except the argument currently being typed is wrapped in
-- RichText so the client can visually distinguish it, matching Cmdr's own
-- "highlight the current parameter" usage bar.
local function buildSignature(command: any, currentArgIndex: number, accentHex: string): string
	local parts = { command.Name }
	for i, argDef in ipairs(command.Args) do
		local label = argDef.Name
		if argDef.Rest then
			label ..= "..."
		end
		label = if argDef.Optional then "[" .. label .. "]" else "<" .. label .. ">"
		label = escapeRichText(label)
		if i == currentArgIndex then
			label = '<font color="' .. accentHex .. '"><b>' .. label .. "</b></font>"
		end
		table.insert(parts, label)
	end
	return table.concat(parts, " ")
end

-- `context` must at least have .Player and .Route set; Suggestions adds
-- nothing else authoritative, it only routes to the right Type.Suggest.
function Suggestions:Get(context: any, input: string): ({ SuggestionEntry }, HintInfo?)
	if input == "" or not input:find("%s") then
		return commandSuggestions(self._deps.Registry, input), nil
	end

	local hasTrailingSpace = input:match("%s$") ~= nil
	local firstSpace = input:find("%s")
	if not firstSpace then
		return {}, nil
	end
	local commandToken = input:sub(1, firstSpace - 1)
	local rest = input:sub(firstSpace + 1)

	local command = self._deps.Registry:Find(commandToken)
	if not command then
		return {}, nil
	end

	local tokens = Parser.Tokenize(rest)
	local argIndex: number
	local partial: string
	if hasTrailingSpace or #tokens == 0 then
		argIndex = #tokens + 1
		partial = ""
	else
		argIndex = #tokens
		partial = tokens[#tokens]
	end

	local hint: HintInfo = {
		Name = command.Name,
		Signature = buildSignature(command, argIndex, accentHexFor(context)),
		Description = command.Description,
	}

	local argDef = command.Args[argIndex]
	if not argDef then
		local lastArg = command.Args[#command.Args]
		if lastArg and lastArg.Rest then
			argDef = lastArg
		end
	end
	if not argDef or not argDef.Type or not argDef.Type.Suggest then
		return {}, hint
	end

	local ok, result = pcall(argDef.Type.Suggest, partial, context)
	if not ok or type(result) ~= "table" then
		return {}, hint
	end
	return result, hint
end

return Suggestions
