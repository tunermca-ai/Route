--!strict
-- Route.Network.ResponseTypes
-- The tiny, fixed vocabulary the server uses when talking to the client
-- over Response/Autocomplete. Kept in one place so the client-side UI
-- script (which physically cannot require anything from ServerScriptService)
-- has a single, short, copy-pasteable source of truth to mirror.

export type ResponseType = "Success" | "Error" | "Warn" | "Info" | "Log"

local ResponseType = {
	Success = "Success" :: ResponseType,
	Error = "Error" :: ResponseType,
	Warn = "Warn" :: ResponseType,
	Info = "Info" :: ResponseType,
	Log = "Log" :: ResponseType,
}

export type SuggestionKind =
	"Command"
	| "Argument"
	| "Player"
	| "Enum"
	| "Permission"
	| "Role"
	| "Config"
	| "Type"

local SuggestionKind = {
	Command = "Command" :: SuggestionKind,
	Argument = "Argument" :: SuggestionKind,
	Player = "Player" :: SuggestionKind,
	Enum = "Enum" :: SuggestionKind,
	Permission = "Permission" :: SuggestionKind,
	Role = "Role" :: SuggestionKind,
	Config = "Config" :: SuggestionKind,
	Type = "Type" :: SuggestionKind,
}

return {
	ResponseType = ResponseType,
	SuggestionKind = SuggestionKind,
}
