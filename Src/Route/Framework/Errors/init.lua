--!strict
-- Route.Errors
-- Structured error objects used throughout the framework instead of raw
-- error() strings. Every RouteError carries a stable code, a category,
-- a severity, and enough context (command/argument/request id) to debug
-- a production incident from chat output alone.

export type Severity = "Info" | "Warning" | "Error" | "Fatal"

export type RouteErrorProps = {
	Code: string,
	Name: string,
	Message: string,
	Category: string,
	Severity: Severity,
	Command: string?,
	Argument: string?,
	Source: string?,
	RequestId: string?,
	Traceback: string?,
}

export type RouteError = RouteErrorProps & {
	ToString: (self: RouteError) -> string,
	ToDisplay: (self: RouteError) -> string,
}

local RouteError = {}
RouteError.__index = RouteError

function RouteError.new(props: RouteErrorProps): RouteError
	local self = setmetatable(table.clone(props) :: any, RouteError)
	return (self :: any) :: RouteError
end

function RouteError:ToString(): string
	return string.format("[ROUTE:%s] %s: %s", self.Code, self.Name, self.Message)
end

-- Multi-line human display, matching the framework's documented error format.
function RouteError:ToDisplay(): string
	local lines = { string.format("[ROUTE:%s]", self.Code), self.Name, self.Message }
	if self.Argument then
		table.insert(lines, "Argument: " .. self.Argument)
	end
	if self.Command then
		table.insert(lines, "Command: " .. self.Command)
	end
	if self.RequestId then
		table.insert(lines, "Request: " .. self.RequestId)
	end
	return table.concat(lines, "\n")
end

-- Stable catalogue of error codes. Keep numbers assigned once and never
-- reused, so a code in an old log always means the same thing.
export type ErrorCode = {
	Code: string,
	Name: string,
	Category: string,
	Severity: Severity,
}

local Codes: { [string]: ErrorCode } = {
	UnknownCommand = { Code = "E100", Name = "UnknownCommand", Category = "Parse", Severity = "Warning" },
	EmptyInput = { Code = "E101", Name = "EmptyInput", Category = "Parse", Severity = "Info" },
	MissingArgument = { Code = "E102", Name = "MissingArgument", Category = "Validation", Severity = "Warning" },
	InvalidType = { Code = "E103", Name = "InvalidType", Category = "Validation", Severity = "Warning" },
	PlayerNotFound = { Code = "E104", Name = "PlayerNotFound", Category = "Validation", Severity = "Warning" },
	AmbiguousPlayer = { Code = "E105", Name = "AmbiguousPlayer", Category = "Validation", Severity = "Warning" },
	ConstraintFailed = { Code = "E106", Name = "ConstraintFailed", Category = "Validation", Severity = "Warning" },
	PermissionDenied = { Code = "E107", Name = "PermissionDenied", Category = "Security", Severity = "Warning" },
	GuardFailed = { Code = "E108", Name = "GuardFailed", Category = "Security", Severity = "Warning" },
	CooldownActive = { Code = "E109", Name = "CooldownActive", Category = "RateLimit", Severity = "Info" },
	RateLimited = { Code = "E110", Name = "RateLimited", Category = "RateLimit", Severity = "Warning" },
	CommandDisabled = { Code = "E111", Name = "CommandDisabled", Category = "Registry", Severity = "Warning" },
	DuplicateCommand = { Code = "E112", Name = "DuplicateCommand", Category = "Registry", Severity = "Error" },
	DuplicateAlias = { Code = "E113", Name = "DuplicateAlias", Category = "Registry", Severity = "Error" },
	InvalidCommandDefinition = { Code = "E114", Name = "InvalidCommandDefinition", Category = "Registry", Severity = "Error" },
	InvalidConfig = { Code = "E115", Name = "InvalidConfig", Category = "Config", Severity = "Warning" },
	UnknownConfigKey = { Code = "E116", Name = "UnknownConfigKey", Category = "Config", Severity = "Warning" },
	ExecutionError = { Code = "E117", Name = "ExecutionError", Category = "Execution", Severity = "Error" },
	ModuleLoadFailed = { Code = "E118", Name = "ModuleLoadFailed", Category = "Discovery", Severity = "Error" },
	InvalidTypeDefinition = { Code = "E119", Name = "InvalidTypeDefinition", Category = "Types", Severity = "Error" },
	UnknownType = { Code = "E120", Name = "UnknownType", Category = "Types", Severity = "Error" },
	Internal = { Code = "E199", Name = "InternalError", Category = "Internal", Severity = "Fatal" },
}

local Errors = {}
Errors.RouteError = RouteError
Errors.Codes = Codes

-- Build a RouteError from a catalogue entry, filling in call-specific context.
function Errors.new(
	codeName: string,
	message: string,
	context: { Command: string?, Argument: string?, Source: string?, RequestId: string?, Traceback: string? }?
): RouteError
	local entry = Codes[codeName] or Codes.Internal
	local ctx: { Command: string?, Argument: string?, Source: string?, RequestId: string?, Traceback: string? } = context or {}
	return RouteError.new({
		Code = entry.Code,
		Name = entry.Name,
		Message = message,
		Category = entry.Category,
		Severity = entry.Severity,
		Command = ctx.Command,
		Argument = ctx.Argument,
		Source = ctx.Source,
		RequestId = ctx.RequestId,
		Traceback = ctx.Traceback,
	})
end

function Errors.isRouteError(value: any): boolean
	return type(value) == "table" and getmetatable(value) == RouteError
end

return Errors
