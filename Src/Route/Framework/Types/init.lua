--!strict
-- Route.Types
-- The type registry. Built-in types live in Types/Builtin.lua and are
-- merged onto this table so callers can do `Types.player`, `Types.string`,
-- etc. Developers extend the system the same way the built-ins are
-- defined - by calling Types:Register(name, definition).

export type SuggestionEntry = {
	Value: string,
	Display: string,
	Description: string?,
	Kind: string?,
}

export type TypeContext = {
	Player: Player,
	Route: any, -- the public Route API table (Permissions/Config/Commands/...)
	Command: any,
	Raw: string,
	RequestId: string,
}

export type TypeDefinition = {
	Name: string,
	Parse: (raw: string, context: TypeContext) -> (any, string?),
	Validate: ((value: any, argDef: any, context: TypeContext) -> (boolean, string?))?,
	Suggest: ((partial: string, context: TypeContext) -> { SuggestionEntry })?,
	Transform: ((value: any, context: TypeContext) -> any)?,
	Describe: ((argDef: any) -> string)?,
}

local Types = {}
Types._registry = {} :: { [string]: TypeDefinition }

function Types:Register(name: string, def: { [string]: any }): TypeDefinition
	if type(def.Parse) ~= "function" then
		error(string.format("Route.Types:Register('%s') requires a Parse function", name), 2)
	end
	local typeDef = table.clone(def) :: TypeDefinition
	;(typeDef :: any).Name = name
	Types._registry[name] = typeDef
	;(Types :: any)[name] = typeDef
	return typeDef
end

function Types:Get(name: string): TypeDefinition?
	return Types._registry[name]
end

function Types:GetAll(): { TypeDefinition }
	local list = {}
	for _, def in pairs(Types._registry) do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

function Types:Count(): number
	local n = 0
	for _ in pairs(Types._registry) do
		n += 1
	end
	return n
end

-- Populates Types.player, Types.string, Types.enum(...), etc.
require(script.Builtin)(Types)

return Types
