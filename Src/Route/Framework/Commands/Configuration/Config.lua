--!strict
local Route = require(script.Parent.Parent.Parent.Parent.Route)
local Command, Types = Route.Command, Route.Types

local function coerce(rawValue: string, schemaType: string, ctx: any): (any, string?)
	if schemaType == "boolean" then
		return Types.boolean.Parse(rawValue, ctx)
	elseif schemaType == "number" then
		local n = tonumber(rawValue)
		if not n then
			return nil, string.format('"%s" is not a number', rawValue)
		end
		return n
	else
		return rawValue
	end
end

return Command.new("config")
	:description("Read or change Route's runtime configuration")
	:category("Configuration")
	:aliases("route.config")
	:permission("server.config")
	:arg(Types.enum({ "get", "set", "reset" }), "action")
	:arg(Types.string, "key", "Config key, e.g. Audit.Enabled")
		:optional()
	:arg(Types.string, "value", "New value (for `set`)")
		:optional()
		:rest()
	:audit(true)
	:example("config get")
	:example("config get Audit.Enabled")
	:example("config set Audit.Enabled true")
	:example("config reset Audit.Enabled")
	:run(function(ctx: any, args: { [string]: any })
		local Config = ctx.Route.Config

		if args.action == "get" then
			if not args.key then
				local lines = {}
				for _, path in ipairs(Config:GetAllPaths()) do
					table.insert(lines, string.format("%s = %s", path, tostring(Config:Get(path))))
				end
				ctx:Reply(table.concat(lines, "\n"))
				return
			end
			local schema = Config:GetSchema(args.key)
			if not schema then
				ctx:Error(string.format('Unknown config key "%s"', args.key))
				return
			end
			ctx:Reply(string.format("%s = %s\n%s", args.key, tostring(Config:Get(args.key)), schema.Description or ""))
			return
		end

		if not args.key then
			ctx:Error("Missing argument: key")
			return
		end

		if args.action == "reset" then
			local ok, err = Config:Reset(args.key)
			if ok then
				ctx:Success(string.format("Reset %s to %s", args.key, tostring(Config:Get(args.key))))
			else
				ctx:Error(err or "failed to reset")
			end
			return
		end

		-- action == "set"
		if not args.value then
			ctx:Error("Missing argument: value")
			return
		end
		local schema = Config:GetSchema(args.key)
		if not schema then
			ctx:Error(string.format('Unknown config key "%s"', args.key))
			return
		end
		local coerced, coerceErr = coerce(args.value, schema.Type, ctx)
		if coerced == nil and coerceErr then
			ctx:Error(coerceErr)
			return
		end
		local ok, err = Config:Set(args.key, coerced)
		if ok then
			ctx:Success(string.format("Set %s = %s", args.key, tostring(coerced)))
		else
			ctx:Error(err or "failed to set")
		end
	end)
