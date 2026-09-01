--!strict
-- Route.Command.Context
-- The object every command's :run(context, args) receives. Built fresh
-- for each execution by Core (real requests) or Testing (mocked runs) -
-- both funnel output through the same small set of methods so a command
-- never needs to know whether it's being played live or unit tested.

export type ResponsePayload = {
	Type: string, -- "Success" | "Error" | "Warn" | "Info" | "Log"
	Message: string,
	Metadata: { [string]: any }?,
}

export type ContextOptions = {
	Player: Player,
	Command: any,
	Raw: string,
	RequestId: string,
	Route: any,
	Sink: (ResponsePayload) -> (),
}

export type Context = {
	Player: Player,
	Command: any,
	Args: { [string]: any },
	Raw: string,
	RequestId: string,
	StartTime: number,
	Metadata: { [string]: any },
	Route: any,

	Reply: (self: Context, message: string, metadata: { [string]: any }?) -> (),
	Success: (self: Context, message: string, metadata: { [string]: any }?) -> (),
	Warn: (self: Context, message: string, metadata: { [string]: any }?) -> (),
	Error: (self: Context, message: string, metadata: { [string]: any }?) -> (),
	Log: (self: Context, message: string) -> (),
	HasPermission: (self: Context, node: string) -> boolean,
}

local Context = {}
Context.__index = Context

function Context.new(opts: ContextOptions): Context
	local self = setmetatable({
		Player = opts.Player,
		Command = opts.Command,
		Args = {},
		Raw = opts.Raw,
		RequestId = opts.RequestId,
		StartTime = os.clock(),
		Metadata = {},
		Route = opts.Route,
		_sink = opts.Sink,
	}, Context)
	return (self :: any) :: Context
end

function Context:Reply(message: string, metadata: { [string]: any }?)
	self._sink({ Type = "Info", Message = message, Metadata = metadata })
end

function Context:Success(message: string, metadata: { [string]: any }?)
	self._sink({ Type = "Success", Message = message, Metadata = metadata })
end

function Context:Warn(message: string, metadata: { [string]: any }?)
	self._sink({ Type = "Warn", Message = message, Metadata = metadata })
end

function Context:Error(message: string, metadata: { [string]: any }?)
	self._sink({ Type = "Error", Message = message, Metadata = metadata })
end

function Context:Log(message: string)
	self._sink({ Type = "Log", Message = message })
end

function Context:HasPermission(node: string): boolean
	if not self.Route or not self.Route.Permissions then
		return false
	end
	return self.Route.Permissions:Has(self.Player, node)
end

return Context
