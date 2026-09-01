--!strict
-- Route.Command
-- The chainable command builder. A Command instance IS the command
-- definition - there is no separate ":Build()" step. Every method
-- returns self so calls can be chained in any order, and argument
-- modifiers (:optional, :rest, :min, :max, :default) always apply to
-- the most recently added :arg().

export type CooldownSpec = number | { Global: number?, Player: number? }

export type ArgDef = {
	Type: any, -- Route.Types type definition (avoiding a require cycle)
	Name: string,
	Description: string,
	Optional: boolean,
	Rest: boolean,
	Min: number?,
	Max: number?,
	Default: any,
}

export type GuardFn = (context: any) -> (boolean, string?)
export type MiddlewareFn = (context: any, args: { [string]: any }, nextFn: () -> ()) -> ()
export type RunFn = (context: any, args: { [string]: any }) -> ()
export type ClientRunFn = (context: any, argsText: string) -> ()

export type Command = {
	Name: string,
	Description: string,
	Category: string,
	Aliases: { string },
	Permission: string?,
	Args: { ArgDef },
	Cooldown: CooldownSpec?,
	Guards: { GuardFn | string },
	Middleware: { MiddlewareFn },
	Audit: boolean,
	Hidden: boolean,
	Enabled: boolean,
	Examples: { string },
	Usage: string?,
	RunFn: RunFn?,
	-- See Command:runClient below - mutually exclusive with RunFn, and
	-- can never be combined with Permission/Guards/Cooldown (Core.lua's
	-- discovery step rejects a command that tries).
	RunClientFn: ClientRunFn?,

	description: (self: Command, text: string) -> Command,
	category: (self: Command, text: string) -> Command,
	aliases: (self: Command, ...string) -> Command,
	permission: (self: Command, node: string) -> Command,
	arg: (self: Command, argType: any, name: string, description: string?) -> Command,
	optional: (self: Command) -> Command,
	rest: (self: Command) -> Command,
	default: (self: Command, value: any) -> Command,
	min: (self: Command, n: number) -> Command,
	max: (self: Command, n: number) -> Command,
	cooldown: (self: Command, spec: CooldownSpec) -> Command,
	guard: (self: Command, guard: GuardFn | string) -> Command,
	middleware: (self: Command, fn: MiddlewareFn) -> Command,
	audit: (self: Command, enabled: boolean?) -> Command,
	hidden: (self: Command, isHidden: boolean?) -> Command,
	enabled: (self: Command, isEnabled: boolean?) -> Command,
	example: (self: Command, text: string) -> Command,
	usage: (self: Command, text: string) -> Command,
	run: (self: Command, fn: RunFn) -> Command,
	runClient: (self: Command, fn: ClientRunFn) -> Command,
	GetUsage: (self: Command) -> string,
}

local Command = {}
Command.__index = Command

function Command.new(name: string): Command
	local self = setmetatable({
		Name = name,
		Description = "",
		-- Every default command sets its own :category(...) explicitly
		-- (see Framework/Commands/**), so this default only ever applies
		-- to a command that skips it - category is genuinely optional,
		-- it just files you under this name instead of a real one.
		Category = "defadmin-wire",
		Aliases = {},
		Permission = nil,
		Args = {},
		Cooldown = nil,
		Guards = {},
		Middleware = {},
		Audit = true,
		Hidden = false,
		Enabled = true,
		Examples = {},
		Usage = nil,
		RunFn = nil,
		RunClientFn = nil,
		_lastArg = nil,
	}, Command)
	return (self :: any) :: Command
end

function Command:description(text: string): Command
	self.Description = text
	return self
end

function Command:category(text: string): Command
	self.Category = text
	return self
end

function Command:aliases(...: string): Command
	for _, alias in ipairs({ ... }) do
		table.insert(self.Aliases, alias)
	end
	return self
end

function Command:permission(node: string): Command
	self.Permission = node
	return self
end

function Command:arg(argType: any, name: string, description: string?): Command
	local def: ArgDef = {
		Type = argType,
		Name = name,
		Description = description or "",
		Optional = false,
		Rest = false,
		Min = nil,
		Max = nil,
		Default = nil,
	}
	table.insert(self.Args, def)
	;(self :: any)._lastArg = def
	return self
end

local function requireLastArg(self: any, method: string): ArgDef
	local lastArg = self._lastArg
	if not lastArg then
		error(string.format("Route.Command: :%s() called with no preceding :arg() on command '%s'", method, self.Name), 3)
	end
	return lastArg
end

function Command:optional(): Command
	requireLastArg(self, "optional").Optional = true
	return self
end

function Command:rest(): Command
	local lastArg = requireLastArg(self, "rest")
	lastArg.Rest = true
	return self
end

function Command:default(value: any): Command
	local lastArg = requireLastArg(self, "default")
	lastArg.Default = value
	lastArg.Optional = true
	return self
end

function Command:min(n: number): Command
	requireLastArg(self, "min").Min = n
	return self
end

function Command:max(n: number): Command
	requireLastArg(self, "max").Max = n
	return self
end

function Command:cooldown(spec: CooldownSpec): Command
	self.Cooldown = spec
	return self
end

function Command:guard(guard: GuardFn | string): Command
	table.insert(self.Guards, guard)
	return self
end

function Command:middleware(fn: MiddlewareFn): Command
	table.insert(self.Middleware, fn)
	return self
end

function Command:audit(enabled: boolean?): Command
	self.Audit = if enabled == nil then true else enabled
	return self
end

function Command:hidden(isHidden: boolean?): Command
	self.Hidden = if isHidden == nil then true else isHidden
	return self
end

function Command:enabled(isEnabled: boolean?): Command
	self.Enabled = if isEnabled == nil then true else isEnabled
	return self
end

function Command:example(text: string): Command
	table.insert(self.Examples, text)
	return self
end

function Command:usage(text: string): Command
	self.Usage = text
	return self
end

function Command:run(fn: RunFn): Command
	self.RunFn = fn
	return self
end

-- A :runClient() command never touches the server at all - no
-- CommandRemote:FireServer, no pipeline, no permission/guard/cooldown
-- check of any kind, because none of that ever runs anywhere the server
-- could see it happen. Route.UI clones this command's own source
-- ModuleScript into every player's console and Controller.client.lua
-- requires it fresh there, calling `fn` itself the moment someone types
-- the command - see Commands/RouteMeta/Clear.lua for the worked example.
-- A command defines :run() or :runClient(), never both, and a
-- :runClient() command can't carry :permission()/:guard()/:cooldown() -
-- Core.lua's discovery step rejects the combination outright, since none
-- of those could ever actually be enforced from here.
function Command:runClient(fn: ClientRunFn): Command
	self.RunClientFn = fn
	return self
end

-- Auto-generates "kick <target> [reason...]"-style usage when one
-- hasn't been explicitly provided via :usage().
function Command:GetUsage(): string
	if self.Usage then
		return self.Usage
	end
	local parts = { self.Name }
	for _, argDef in ipairs(self.Args) do
		local label = argDef.Name
		if argDef.Rest then
			label ..= "..."
		end
		if argDef.Optional then
			table.insert(parts, "[" .. label .. "]")
		else
			table.insert(parts, "<" .. label .. ">")
		end
	end
	return table.concat(parts, " ")
end

return Command
