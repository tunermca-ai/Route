--!strict
-- Route.Config
-- Typed, watchable runtime configuration. Every key must be Register()'d
-- with a type (built-ins are registered below) before it can be Set() -
-- Route never accepts an arbitrary string into a config value. Keys use
-- dotted paths ("Audit.Enabled") purely as a naming convention; storage
-- itself is a flat map, which keeps Get/Set/Watch trivial and fast.

export type ConfigType = "boolean" | "number" | "string" | "enum"

export type ConfigSchema = {
	Type: ConfigType,
	Default: any,
	Description: string?,
	Values: { string }?, -- for Type == "enum"
	Validate: ((value: any) -> (boolean, string?))?,
}

local Config = {}
Config.__index = Config

function Config.new(): any
	local self = setmetatable({
		_schema = {} :: { [string]: ConfigSchema },
		_values = {} :: { [string]: any },
		_watchers = {} :: { [string]: { (any, any) -> () } },
	}, Config)
	return self
end

function Config:Register(path: string, schema: ConfigSchema)
	self._schema[path] = schema
	if self._values[path] == nil then
		self._values[path] = schema.Default
	end
end

local function typeCheck(schema: ConfigSchema, value: any): (boolean, string?)
	if schema.Type == "boolean" and type(value) ~= "boolean" then
		return false, "expected a boolean"
	elseif schema.Type == "number" and type(value) ~= "number" then
		return false, "expected a number"
	elseif schema.Type == "string" and type(value) ~= "string" then
		return false, "expected a string"
	elseif schema.Type == "enum" then
		local values = schema.Values or {}
		local found = false
		for _, allowed in ipairs(values) do
			if allowed == value then
				found = true
				break
			end
		end
		if not found then
			return false, "expected one of: " .. table.concat(values, ", ")
		end
	end
	if schema.Validate then
		local ok, err = schema.Validate(value)
		if not ok then
			return false, err
		end
	end
	return true, nil
end

function Config:Get(path: string): any
	return self._values[path]
end

function Config:Set(path: string, value: any): (boolean, string?)
	local schema = self._schema[path]
	if not schema then
		return false, string.format('unknown config key "%s" - register it with Config:Register() first', path)
	end
	local ok, err = typeCheck(schema, value)
	if not ok then
		return false, err
	end
	local old = self._values[path]
	self._values[path] = value
	if old ~= value then
		for _, cb in ipairs(self._watchers[path] or {}) do
			task.spawn(cb, value, old)
		end
	end
	return true, nil
end

function Config:Reset(path: string): (boolean, string?)
	local schema = self._schema[path]
	if not schema then
		return false, string.format('unknown config key "%s"', path)
	end
	return self:Set(path, schema.Default)
end

-- Returns a disconnect function, matching Roblox's RBXScriptConnection idiom.
function Config:Watch(path: string, callback: (newValue: any, oldValue: any) -> ()): () -> ()
	self._watchers[path] = self._watchers[path] or {}
	table.insert(self._watchers[path], callback)
	local watchers = self._watchers[path]
	local entry = callback
	return function()
		for i, cb in ipairs(watchers) do
			if cb == entry then
				table.remove(watchers, i)
				break
			end
		end
	end
end

function Config:GetSchema(path: string): ConfigSchema?
	return self._schema[path]
end

function Config:GetAllPaths(): { string }
	local paths = {}
	for path in pairs(self._schema) do
		table.insert(paths, path)
	end
	table.sort(paths)
	return paths
end

-- ===== Built-in schema ===================================================

local function registerDefaults(config: any)
	config:Register("Prefix", { Type = "string", Default = "", Description = "Optional prefix stripped before parsing (chat-command integrations only)." })
	config:Register("Audit.Enabled", { Type = "boolean", Default = true, Description = "Whether command executions and admin actions are audit-logged." })
	config:Register("Audit.MaxEntries", { Type = "number", Default = 1000, Description = "How many audit records to retain in memory." })
	config:Register("Debug.Enabled", { Type = "boolean", Default = true, Description = "Enables /route debug introspection." })
	config:Register("Debug.Profiling.Enabled", { Type = "boolean", Default = true, Description = "Whether command execution time is recorded." })
	config:Register("Permissions.Enabled", { Type = "boolean", Default = true, Description = "Master switch for the permission system." })
	config:Register("Permissions.Persistence.Enabled", { Type = "boolean", Default = false, Description = "Persist grants/roles to DataStore." })
	config:Register("Permissions.BypassInStudio", { Type = "boolean", Default = true, Description = "Skip permission checks entirely while running in Studio (edit or Play-test) - a published live server always enforces them regardless of this setting." })
	config:Register("Discord.Enabled", { Type = "boolean", Default = false, Description = "Master switch for the Discord webhook integration." })
	config:Register("Server.Locked", { Type = "boolean", Default = false, Description = "When true, the ServerUnlocked guard blocks the commands using it." })
	config:Register("RateLimit.MaxPerMinute", { Type = "number", Default = 60, Description = "Max raw command submissions per player per minute.", Validate = function(v: number): (boolean, string?)
		if v <= 0 then
			return false, "must be greater than 0"
		end
		return true, nil
	end })
	config:Register("RateLimit.AutocompletePerMinute", { Type = "number", Default = 240, Description = "Max autocomplete requests per player per minute (separate bucket from command sends).", Validate = function(v: number): (boolean, string?)
		if v <= 0 then
			return false, "must be greater than 0"
		end
		return true, nil
	end })
	config:Register("History.MaxEntries", { Type = "number", Default = 500, Description = "How many command-history records to retain in memory." })
	config:Register("Moderation.JailPosition.X", { Type = "number", Default = 0, Description = "Where /jail teleports players (X). Suspended high in the void by default - point this at a real jail cell if you build one." })
	config:Register("Moderation.JailPosition.Y", { Type = "number", Default = 1000, Description = "Where /jail teleports players (Y)." })
	config:Register("Moderation.JailPosition.Z", { Type = "number", Default = 0, Description = "Where /jail teleports players (Z)." })
end

registerDefaults(Config.new()) -- no-op call kept only to type-check registerDefaults at module load; real instance is created in Core.

return {
	new = Config.new,
	RegisterDefaults = registerDefaults,
}
