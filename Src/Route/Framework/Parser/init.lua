--!strict
-- Route.Parser
-- Turns raw text into tokens. Deliberately dumb: it knows nothing about
-- commands, types, or permissions - it only tokenizes. Everything after
-- this belongs to the Type system and the execution pipeline in Core.

export type ParseResult = {
	CommandToken: string?,
	ArgTokens: { string },
	Raw: string,
}

local Parser = {}

-- Splits on whitespace but keeps "double quoted substrings" and
-- 'single quoted substrings' intact as one token (quotes are stripped).
-- A trailing unclosed quote is treated as running to the end of input
-- rather than erroring, so partial/in-progress typing never crashes.
function Parser.Tokenize(raw: string): { string }
	local tokens: { string } = {}
	local i = 1
	local len = #raw

	while i <= len do
		-- skip whitespace
		while i <= len and raw:sub(i, i):match("%s") do
			i += 1
		end
		if i > len then
			break
		end

		local char = raw:sub(i, i)
		if char == '"' or char == "'" then
			local quote = char
			local start = i + 1
			local closeIndex = raw:find(quote, start, true)
			if closeIndex then
				table.insert(tokens, raw:sub(start, closeIndex - 1))
				i = closeIndex + 1
			else
				table.insert(tokens, raw:sub(start))
				i = len + 1
			end
		else
			local start = i
			while i <= len and not raw:sub(i, i):match("%s") do
				i += 1
			end
			table.insert(tokens, raw:sub(start, i - 1))
		end
	end

	return tokens
end

-- Strips a leading prefix (e.g. "/") if present. Route's primary entry
-- point is a dedicated command bar that needs no prefix, but this keeps
-- Parser usable from a chat-command integration too.
local function stripPrefix(raw: string, prefix: string): string
	if prefix ~= "" and raw:sub(1, #prefix) == prefix then
		return raw:sub(#prefix + 1)
	end
	return raw
end

function Parser.Parse(raw: string, prefix: string?): ParseResult
	local stripped = stripPrefix(raw, prefix or "")
	local tokens = Parser.Tokenize(stripped)
	local commandToken = table.remove(tokens, 1)
	return {
		CommandToken = commandToken,
		ArgTokens = tokens,
		Raw = raw,
	}
end

return Parser
