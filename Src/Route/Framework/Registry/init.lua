--!strict
-- Route.Registry
-- The single source of truth for every registered command. Enforces
-- unique names/aliases, indexes by category, and provides the search
-- Route.Suggestions and the built-in help/debug commands rely on.

local Errors = require(script.Parent.Errors)

type RouteError = Errors.RouteError

export type CommandLike = {
	Name: string,
	Aliases: { string },
	Category: string,
	Hidden: boolean,
	Enabled: boolean,
	[any]: any,
}

export type Registry = {
	Register: (self: Registry, command: CommandLike) -> (boolean, RouteError?),
	Unregister: (self: Registry, name: string) -> boolean,
	Get: (self: Registry, name: string) -> CommandLike?,
	Find: (self: Registry, nameOrAlias: string) -> CommandLike?,
	GetAll: (self: Registry) -> { CommandLike },
	GetCategory: (self: Registry, category: string) -> { CommandLike },
	GetCategories: (self: Registry) -> { string },
	Search: (self: Registry, query: string) -> { CommandLike },
	SetEnabled: (self: Registry, name: string, enabled: boolean) -> boolean,
	Count: (self: Registry) -> number,
}

local Registry = {}
Registry.__index = Registry

function Registry.new(): Registry
	local self = setmetatable({
		_byName = {} :: { [string]: CommandLike },
		_byAlias = {} :: { [string]: string }, -- alias (lower) -> canonical name
		_byCategory = {} :: { [string]: { [string]: boolean } }, -- category -> set of names
		_order = {} :: { string }, -- registration order, for stable listing
	}, Registry)
	return (self :: any) :: Registry
end

local function validate(command: CommandLike): (boolean, string?)
	if type(command.Name) ~= "string" or #command.Name == 0 then
		return false, "command Name must be a non-empty string"
	end
	if command.Name:find("%s") then
		return false, "command Name must not contain whitespace"
	end
	if type(command.Aliases) ~= "table" then
		return false, "command Aliases must be a table"
	end
	return true, nil
end

function Registry:Register(command: CommandLike): (boolean, RouteError?)
	local ok, reason = validate(command)
	if not ok then
		return false, Errors.new("InvalidCommandDefinition", reason :: string, { Command = command.Name })
	end

	local key = command.Name:lower()
	if self._byName[key] then
		return false, Errors.new(
			"DuplicateCommand",
			string.format('A command named "%s" is already registered.', command.Name),
			{ Command = command.Name }
		)
	end
	if self._byAlias[key] then
		return false, Errors.new(
			"DuplicateAlias",
			string.format('"%s" is already registered as an alias of "%s".', command.Name, self._byAlias[key]),
			{ Command = command.Name }
		)
	end

	for _, alias in ipairs(command.Aliases) do
		local aliasKey = alias:lower()
		if self._byName[aliasKey] or self._byAlias[aliasKey] then
			return false, Errors.new(
				"DuplicateAlias",
				string.format('Alias "%s" for command "%s" collides with an existing command or alias.', alias, command.Name),
				{ Command = command.Name }
			)
		end
	end

	self._byName[key] = command :: any
	table.insert(self._order, key)
	for _, alias in ipairs(command.Aliases) do
		self._byAlias[alias:lower()] = key
	end

	local category = command.Category ~= "" and command.Category or "defadmin-wire"
	self._byCategory[category] = self._byCategory[category] or {}
	self._byCategory[category][key] = true

	return true
end

function Registry:Unregister(name: string): boolean
	local key = name:lower()
	local command = self._byName[key]
	if not command then
		return false
	end

	self._byName[key] = nil
	for i, orderedKey in ipairs(self._order) do
		if orderedKey == key then
			table.remove(self._order, i)
			break
		end
	end
	for _, alias in ipairs(command.Aliases) do
		self._byAlias[alias:lower()] = nil
	end
	local category = command.Category ~= "" and command.Category or "defadmin-wire"
	if self._byCategory[category] then
		self._byCategory[category][key] = nil
	end
	return true
end

function Registry:Get(name: string): CommandLike?
	return self._byName[name:lower()]
end

-- Resolves either a canonical command name or one of its aliases.
function Registry:Find(nameOrAlias: string): CommandLike?
	local key = nameOrAlias:lower()
	local direct = self._byName[key]
	if direct then
		return direct
	end
	local canonical = self._byAlias[key]
	if canonical then
		return self._byName[canonical]
	end
	return nil
end

function Registry:GetAll(): { CommandLike }
	local list = {}
	for _, key in ipairs(self._order) do
		table.insert(list, self._byName[key])
	end
	return list
end

function Registry:GetCategory(category: string): { CommandLike }
	local set = self._byCategory[category]
	if not set then
		return {}
	end
	local list = {}
	for _, key in ipairs(self._order) do
		if set[key] then
			table.insert(list, self._byName[key])
		end
	end
	return list
end

function Registry:GetCategories(): { string }
	local list = {}
	for category in pairs(self._byCategory) do
		table.insert(list, category)
	end
	table.sort(list)
	return list
end

-- Simple, fast substring search over name/aliases/description. Route.Suggestions
-- layers fuzzy scoring on top of this for the autocomplete engine.
function Registry:Search(query: string): { CommandLike }
	local needle = query:lower()
	if needle == "" then
		return self:GetAll()
	end
	local results = {}
	for _, key in ipairs(self._order) do
		local command = self._byName[key]
		local haystack = key
		if command.Description then
			haystack = haystack .. " " .. tostring(command.Description):lower()
		end
		if haystack:find(needle, 1, true) then
			table.insert(results, command)
		end
	end
	return results
end

function Registry:SetEnabled(name: string, enabled: boolean): boolean
	local command = self:Get(name)
	if not command then
		return false
	end
	command.Enabled = enabled
	return true
end

function Registry:Count(): number
	return #self._order
end

return Registry
