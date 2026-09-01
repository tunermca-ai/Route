--!strict
-- Route.Core
-- The lifecycle (Start) and the execution pipeline every raw command
-- string goes through:
--   Input -> Parse -> Resolve -> Parse Args -> Validate -> Permission ->
--   Guards -> Cooldown -> Execute -> Audit -> Respond
-- This module is the only place that chains those stages together, so
-- Route.Network and Route.Testing both call into it rather than each
-- re-implementing the pipeline.

local Registry = require(script.Parent.Registry)
local Parser = require(script.Parent.Parser)
local Types = require(script.Parent.Types)
local Guards = require(script.Parent.Guards)
local Permissions = require(script.Parent.Permissions)
local Config = require(script.Parent.Config)
local Cooldowns = require(script.Parent.Cooldowns)
local Audit = require(script.Parent.Audit)
local Discord = require(script.Parent.Discord)
local Debug = require(script.Parent.Debug)
local History = require(script.Parent.History)
local Suggestions = require(script.Parent.Suggestions)
local Testing = require(script.Parent.Testing)
local Support = require(script.Parent.Support)
local Errors = require(script.Parent.Errors)
local Context = require(script.Parent.Command.Context)
local Network = require(script.Parent.Network)
local RemoteSetup = require(script.Parent.Network.RemoteSetup)
local Levenshtein = require(script.Levenshtein)
local VersionInfo = require(script.Parent.Version)
local UI = require(script.Parent.UI)
local Signal = require(script.Parent.Signal)

export type StartOptions = {
	-- Each of these accepts a single folder, or an array of folders (e.g.
	-- { Framework.Commands, ServerScriptService.CustomRoute }) so a game's
	-- own custom commands/types/guards can live in their own folder,
	-- entirely separate from the ones the package ships with.
	Commands: (Instance | { Instance })?,
	Types: (Instance | { Instance })?,
	Guards: (Instance | { Instance })?,
	Prefix: string?,
	Permissions: {
		Enabled: boolean?,
		-- Studio (Edit or Play-test) always bypasses every permission
		-- check by default - there's no player-facing server to protect
		-- there. A published, live server always enforces normally no
		-- matter what this is set to. Set false to force real checks even
		-- in Studio (e.g. to test what a non-privileged player would see).
		BypassInStudio: boolean?,
		Owners: { number }?, -- these UserIds get the built-in "Owner" role ("*" - everything)
		Admins: { number }?, -- these UserIds get the built-in "Admin" role ("*" - everything)
		-- Custom roles beyond Owner/Admin (both of which always exist with
		-- full access, whether or not this table defines anything). Each
		-- value is either `true` (shorthand for "*", full access - the
		-- same as Owner/Admin) or an explicit list of permission nodes:
		--   Roles = {
		--       Testers = { "players.speed", "players.teleport" },
		--       EventHost = true,
		--   }
		-- Grant them the same way as Owner/Admin: `give <player> <RoleName>`
		-- (a shorter, single-purpose alternative to `role give`).
		Roles: { [string]: boolean | { string } }?,
		-- Auto-grant a role by Roblox group rank, re-checked every time a
		-- player joins (their rank can change between sessions):
		--   Groups = {
		--       { GroupId = 1234567, MinRank = 200, Role = "Admin" },
		--       { GroupId = 1234567, MinRank = 100, Role = "Tester" },
		--   }
		-- `Role` must already exist - Owner/Admin always do; anything else
		-- has to also be listed under `Roles` above (or created some other
		-- way) or the grant is silently a no-op.
		Groups: { { GroupId: number, MinRank: number, Role: string } }?,
	}?,
	Audit: { Enabled: boolean? }?,
	Debug: { Enabled: boolean? }?,
	Discord: { Enabled: boolean?, Webhook: string? }?,
	Diagnostics: { Print: boolean? }?,
	-- The server-owned console UI (see Framework/UI). Cloned per player on
	-- join, from a template that lives inside the Framework itself - there
	-- is no StarterGui/StarterPlayerScripts tree shipped with Route.
	UI: UI.UIOptions?,
}

local function generateRequestId(): string
	return string.format("ROUTE-%06X", math.random(0, 0xFFFFFF))
end

-- Finds the closest registered command name within an edit-distance of 3,
-- for "Unknown command 'kik'. Did you mean: kick?" suggestions.
local function findDidYouMean(registry: any, token: string): string?
	local best: string? = nil
	local bestDistance = 4
	for _, command in ipairs(registry:GetAll()) do
		local d = Levenshtein.Distance(token:lower(), command.Name:lower())
		if d < bestDistance then
			bestDistance = d
			best = command.Name
		end
	end
	return best
end

local Core = {}

function Core.Start(options: StartOptions?): any
	local startClock = os.clock()
	local opts: StartOptions = options or {}

	-- ===== Build subsystems ==============================================
	local config = Config.new()
	Config.RegisterDefaults(config)
	if opts.Prefix then
		config:Set("Prefix", opts.Prefix)
	end
	if opts.Audit and opts.Audit.Enabled ~= nil then
		config:Set("Audit.Enabled", opts.Audit.Enabled)
	end
	if opts.Debug and opts.Debug.Enabled ~= nil then
		config:Set("Debug.Enabled", opts.Debug.Enabled)
	end
	if opts.Permissions and opts.Permissions.Enabled ~= nil then
		config:Set("Permissions.Enabled", opts.Permissions.Enabled)
	end
	if opts.Permissions and opts.Permissions.BypassInStudio ~= nil then
		config:Set("Permissions.BypassInStudio", opts.Permissions.BypassInStudio)
	end
	if opts.Discord and opts.Discord.Enabled ~= nil then
		config:Set("Discord.Enabled", opts.Discord.Enabled)
	end

	local registry = Registry.new()
	local cooldowns = Cooldowns.new()
	local audit = Audit.new(config)
	local discord = Discord.new(config)
	local history = History.new(config)
	local permissions = Permissions.new(config, audit)
	local debugModule = Debug.new({
		Registry = registry,
		Types = Types,
		Guards = Guards,
		Permissions = permissions,
		Config = config,
		StartedAt = startClock,
	})
	local suggestions = Suggestions.new({ Registry = registry })

	-- ===== Events ===========================================================
	-- Route.On/Route.Once - discord.js-style event hooks (`client.on(...)`)
	-- for anything a game built on top of Route wants to react to, without
	-- reaching into Route's own internals to do it. Signals are created
	-- lazily by name, so any string works as an event name, not just the
	-- ones Route fires itself - a game can use this as its own general-
	-- purpose event bus too.
	--
	-- Route fires two kinds of events on its own:
	--   1. Every Audit record (see Framework/Audit), re-broadcast under
	--      its own `Action` name - "CommandExecuted", "PermissionChanged",
	--      "RoleChanged", whatever a sink would have seen. This mirrors
	--      Audit's own rules: full command-execution details only fire for
	--      commands built with `:audit(true)`, but permission-denied and
	--      guard-failure records always fire regardless, same as Audit
	--      always logs those.
	--   2. A handful of UI/lifecycle events that aren't audit-worthy on
	--      their own, e.g. "ThemeChanged" (see Framework/UI/init.lua).
	local eventSignals: { [string]: any } = {}
	local function signalFor(eventName: string): any
		local signal = eventSignals[eventName]
		if not signal then
			signal = Signal.new()
			eventSignals[eventName] = signal
		end
		return signal
	end
	local function emit(eventName: string, ...: any)
		signalFor(eventName):Fire(...)
	end

	-- Route is assembled incrementally; subsystems constructed above only
	-- read from it later (inside Parse/Suggest/guard calls), never at
	-- construction time, so it's safe to hand out the same table before
	-- every field is filled in.
	local Route: any = {
		Version = VersionInfo.Version,
		VersionString = VersionInfo.VersionString,
		Config = config,
		Commands = registry,
		Registry = registry,
		Types = Types,
		Guards = Guards,
		Permissions = permissions,
		Cooldowns = cooldowns,
		Audit = audit,
		Discord = discord,
		Debug = debugModule,
		History = history,
		Suggestions = suggestions,
	}

	--- Subscribes `fn` to every future firing of `eventName`. Returns a
	--- Signal.Connection - call `:Disconnect()` on it to unsubscribe.
	--- See the "Events" comment above for which event names Route fires
	--- on its own; any other name works too; nothing fires it until
	--- something calls `Route.On`'s counterpart-in-spirit, `emit`,
	--- internally, or a game does the same via its own signal.
	function Route.On(eventName: string, fn: (...any) -> ()): any
		return signalFor(eventName):Connect(fn)
	end

	--- Same as Route.On, but `fn` only runs for the next firing of
	--- `eventName`, then disconnects itself automatically.
	function Route.Once(eventName: string, fn: (...any) -> ()): any
		return signalFor(eventName):Once(fn)
	end

	if opts.Discord and opts.Discord.Webhook then
		discord:SetWebhook(opts.Discord.Webhook)
	end
	if opts.Discord and opts.Discord.Enabled then
		discord:Enable()
	end

	-- Re-broadcasts every Audit record as a Route event named after its
	-- own Action - see Route.On's doc comment above for the full story.
	audit:AddSink(function(record)
		if record.Action then
			emit(record.Action, record)
		end
	end)

	audit:AddSink(function(record)
		if record.Success == false then
			discord:Send("Error", {
				Title = "Command failed",
				Description = record.Error,
				Command = record.Command,
				User = record.Username,
			})
		elseif record.Action == "CommandExecuted" then
			discord:Send("CommandExecuted", {
				Title = "Command executed",
				Command = record.Command,
				User = record.Username,
			})
		elseif record.Action == "PermissionChanged" or record.Action == "RoleChanged" then
			discord:Send(record.Action, {
				Title = record.Action,
				Description = record.Metadata and record.Metadata.Description,
				User = record.Username,
			})
		elseif record.Action == "ConfigurationChanged" then
			discord:Send("ConfigurationChanged", {
				Title = "Configuration changed",
				Description = record.Metadata and record.Metadata.Description,
				User = record.Username,
			})
		elseif record.Action == "PlayerKicked" or record.Action == "PlayerBanned" or record.Action == "ServerShutdown" then
			discord:Send(record.Action, {
				Title = record.Action,
				Description = record.Metadata and record.Metadata.Description,
				User = record.Username,
			})
		end
	end)

	-- ===== Roles: Owner and Admin always exist with full access ("*"),
	-- whether or not anyone is ever granted them - so `route give Nikilis
	-- Admin` or `role give Nikilis Admin` works immediately, with nothing
	-- to set up first. Owners/Admins below is just a convenience auto-grant
	-- by UserId at boot, not what makes the roles exist.
	permissions:CreateRole("Owner", { "*" })
	permissions:CreateRole("Admin", { "*" })

	-- Custom roles (StartOptions.Permissions.Roles) - unlike Owner/Admin,
	-- these start with nothing: `true` is shorthand for "*" (full access,
	-- same as Owner/Admin), anything else is taken as an explicit list of
	-- permission nodes.
	if opts.Permissions and opts.Permissions.Roles then
		for roleName, spec in pairs(opts.Permissions.Roles) do
			local nodes = if spec == true then { "*" } elseif type(spec) == "table" then spec else {}
			permissions:CreateRole(roleName, nodes)
		end
	end

	local Players = game:GetService("Players")
	local function autoGrantByUserId(userIds: { number }?, roleName: string)
		if not userIds then
			return
		end
		local function grantIfMatch(player: Player)
			for _, id in ipairs(userIds) do
				if player.UserId == id then
					permissions:AddToRole(player, roleName)
					print(string.format("[Route] Granted role %q to %s (UserId %d)", roleName, player.Name, id))
				end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			grantIfMatch(player)
		end
		Players.PlayerAdded:Connect(grantIfMatch)
	end

	-- Re-checked on every join (not cached/persisted) since a player's
	-- group rank can change between sessions - GetRankInGroupAsync is a
	-- live network lookup, not something Route snapshots once and forgets.
	-- Each check runs in its own thread so a slow/failed lookup for one
	-- entry or one player never delays Route.Start() or blocks another.
	--
	-- Roblox's own docs flag GetRankInGroupAsync as deprecated in favor of
	-- GroupService:GetRolesInGroupAsync, but as of this writing that
	-- replacement is itself broken/disabled for many games (see Roblox
	-- DevForum reports) - GetRankInGroupAsync is the one that actually
	-- works today. Worth revisiting once Roblox's own migration is done.
	local function autoGrantByGroup(entries: { { GroupId: number, MinRank: number, Role: string } }?)
		if not entries then
			return
		end
		local function grantIfQualified(player: Player)
			for _, entry in ipairs(entries) do
				task.spawn(function()
					local ok, rank = pcall(function()
						return player:GetRankInGroupAsync(entry.GroupId)
					end)
					if ok and rank >= entry.MinRank then
						permissions:AddToRole(player, entry.Role)
						print(string.format(
							"[Route] Granted role %q to %s (group %d rank %d >= %d)",
							entry.Role,
							player.Name,
							entry.GroupId,
							rank,
							entry.MinRank
						))
					end
				end)
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			grantIfQualified(player)
		end
		Players.PlayerAdded:Connect(grantIfQualified)
	end

	if opts.Permissions then
		autoGrantByUserId(opts.Permissions.Owners, "Owner")
		autoGrantByUserId(opts.Permissions.Admins, "Admin")
		autoGrantByGroup(opts.Permissions.Groups)
	end

	-- Force RouteRemotes - and its one-time ClientCommand clone - to exist
	-- before discovery runs below. A :runClient() command module requires
	-- Command through that replicated path (see Network/RemoteSetup.lua),
	-- and that require happens the instant Support.DiscoverFactories
	-- requires the module, same as any other command - it can't wait for
	-- Network.Start() further down to create it. Network.Start() calls
	-- RemoteSetup.Setup() again itself; getOrCreate makes that a no-op.
	RemoteSetup.Setup()

	-- Every command whose :runClient() was called instead of (or as well
	-- as - though Core rejects that combination below) :run(), keyed by
	-- lowercased command name. UI.Start() clones each of these source
	-- ModuleScripts into every player's own console so Controller.client.lua
	-- can require and run them straight from the client, with zero server
	-- round-trip.
	local clientCommandModules: { [string]: ModuleScript } = {}

	-- ===== Discovery =======================================================
	local discoveryErrors: { any } = {}
	local function onError(err: any)
		table.insert(discoveryErrors, err)
		warn(string.format("[Route] failed to load %s: %s", err.Instance:GetFullName(), err.Message))
	end

	local typeCount = Support.DiscoverFactories(opts.Types, function(result: any): (boolean, string?)
		if type(result) ~= "table" or type(result.Name) ~= "string" then
			return false, "type module must return a table with a Name field"
		end
		local ok, err = pcall(function()
			Types:Register(result.Name, result)
		end)
		if not ok then
			return false, tostring(err)
		end
		return true, nil
	end, onError)

	local guardCount = Support.DiscoverFactories(opts.Guards, function(result: any): (boolean, string?)
		if type(result) ~= "table" or type(result.Name) ~= "string" or type(result.Fn) ~= "function" then
			return false, "guard module must return { Name = string, Fn = function }"
		end
		local ok, err = pcall(function()
			Guards:Register(result.Name, result.Fn)
		end)
		if not ok then
			return false, tostring(err)
		end
		return true, nil
	end, onError)

	local function registerCommandFactory(command: any, moduleScript: ModuleScript): (boolean, string?)
		if command.RunClientFn then
			if command.RunFn then
				return false, "a command can't define both :run() and :runClient() - pick one"
			end
			if command.Permission or #command.Guards > 0 or command.Cooldown then
				return false,
					":runClient() commands never reach the server, so :permission()/:guard()/:cooldown() on "
						.. "one would be misleading - none of them could ever actually be enforced"
			end
		elseif not command.RunFn then
			return false, "a command must define :run() or :runClient()"
		end

		local ok, err = registry:Register(command)
		if ok and command.Permission then
			permissions:DeclareNode(command.Permission, command.Description)
		end
		if ok and command.RunClientFn then
			clientCommandModules[tostring(command.Name):lower()] = moduleScript
		end
		return ok, if err then err:ToString() else nil
	end

	local commandCount = Support.DiscoverFactories(opts.Commands, registerCommandFactory, onError)

	-- ===== Player lifecycle ================================================
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		permissions:LoadPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns:ClearPlayer(player)
	end)

	-- ===== Execution pipeline ==============================================
	local function executeRaw(player: Player, raw: string, sink: (any) -> ())
		local requestId = generateRequestId()
		local prefix = config:Get("Prefix") :: string
		local parsed = Parser.Parse(raw, prefix)

		if not parsed.CommandToken or parsed.CommandToken == "" then
			sink({ Type = "Error", Message = "Type a command." })
			return { Success = false, RequestId = requestId }
		end

		local command = registry:Find(parsed.CommandToken)
		if not command then
			local suggestion = findDidYouMean(registry, parsed.CommandToken)
			local message = string.format('Unknown command "%s".', parsed.CommandToken)
			if suggestion then
				message ..= string.format(" Did you mean: %s?", suggestion)
			end
			sink({ Type = "Error", Message = message })
			debugModule:LogError(Errors.new("UnknownCommand", message, { RequestId = requestId }))
			return { Success = false, RequestId = requestId }
		end

		if not command.Enabled then
			sink({ Type = "Error", Message = string.format('"%s" is currently disabled.', command.Name) })
			return { Success = false, Command = command.Name, RequestId = requestId }
		end

		-- A :runClient() command has no RunFn at all - it's meant to never
		-- get here in the first place (see Controller.client.lua, which
		-- intercepts it before ever firing CommandRemote). The only way
		-- this branch runs is a modified client firing the remote directly,
		-- so there's nothing more specific to tell them.
		if not command.RunFn then
			sink({ Type = "Error", Message = string.format('"%s" only runs on the client and can\'t be executed from here.', command.Name) })
			return { Success = false, Command = command.Name, RequestId = requestId }
		end

		local context = Context.new({
			Player = player,
			Command = command,
			Raw = raw,
			RequestId = requestId,
			Route = Route,
			Sink = sink,
		})

		-- ---- Argument parsing / validation --------------------------------
		local args: { [string]: any } = {}
		local tokenIndex = 1
		local argTokens = parsed.ArgTokens
		for _, argDef in ipairs(command.Args) do
			local rawToken: string?
			if argDef.Rest then
				local rest = {}
				for i = tokenIndex, #argTokens do
					table.insert(rest, argTokens[i])
				end
				tokenIndex = #argTokens + 1
				rawToken = if #rest > 0 then table.concat(rest, " ") else nil
			else
				rawToken = argTokens[tokenIndex]
				tokenIndex += 1
			end

			if rawToken == nil or rawToken == "" then
				if argDef.Default ~= nil then
					args[argDef.Name] = argDef.Default
				elseif argDef.Optional then
					args[argDef.Name] = nil
				else
					sink({
						Type = "Error",
						Message = string.format(
							"Missing argument: %s\nUsage: %s",
							argDef.Name,
							command:GetUsage()
						),
					})
					return { Success = false, Command = command.Name, RequestId = requestId }
				end
			else
				local value, parseErr = argDef.Type.Parse(rawToken, context)
				if value == nil then
					sink({
						Type = "Error",
						Message = string.format("%s: %s", argDef.Name, parseErr or "invalid value"),
					})
					debugModule:LogError(Errors.new("InvalidType", parseErr or "invalid value", {
						Command = command.Name,
						Argument = argDef.Name,
						RequestId = requestId,
					}))
					return { Success = false, Command = command.Name, RequestId = requestId }
				end
				if argDef.Type.Validate then
					local ok, validateErr = argDef.Type.Validate(value, argDef, context)
					if not ok then
						sink({ Type = "Error", Message = string.format("%s: %s", argDef.Name, validateErr or "invalid value") })
						return { Success = false, Command = command.Name, RequestId = requestId }
					end
				end
				if argDef.Type.Transform then
					value = argDef.Type.Transform(value, context)
				end
				args[argDef.Name] = value
			end
		end
		context.Args = args

		-- ---- Permission ----------------------------------------------------
		if command.Permission and config:Get("Permissions.Enabled") ~= false then
			if not permissions:Has(player, command.Permission) then
				sink({ Type = "Error", Message = string.format("You don't have permission to use \"%s\".", command.Name) })
				audit:Log({
					Action = "CommandExecuted",
					Actor = player,
					Command = command.Name,
					Success = false,
					Error = "PermissionDenied",
					Permission = command.Permission,
				})
				history:Record(player, command.Name, false)
				return { Success = false, Command = command.Name, RequestId = requestId }
			end
		end

		-- ---- Guards ----------------------------------------------------------
		for _, guard in ipairs(command.Guards) do
			local fn, resolveErr = Guards:Resolve(guard)
			if not fn then
				sink({ Type = "Error", Message = "Internal error: " .. (resolveErr or "bad guard") })
				return { Success = false, Command = command.Name, RequestId = requestId }
			end
			local ok, reason = fn(context)
			if not ok then
				sink({ Type = "Error", Message = reason or "You can't do that right now." })
				audit:Log({ Action = "CommandExecuted", Actor = player, Command = command.Name, Success = false, Error = "GuardFailed" })
				history:Record(player, command.Name, false)
				return { Success = false, Command = command.Name, RequestId = requestId }
			end
		end

		-- ---- Cooldown ----------------------------------------------------------
		local cooldownOk, remaining = cooldowns:Check(command.Name, player, command.Cooldown)
		if not cooldownOk then
			sink({ Type = "Warn", Message = string.format("On cooldown - try again in %.1fs.", remaining) })
			return { Success = false, Command = command.Name, RequestId = requestId }
		end

		-- ---- Execute ----------------------------------------------------------
		local execStart = os.clock()
		local ok, runErr = pcall(command.RunFn :: any, context, args)
		local duration = os.clock() - execStart

		debugModule:RecordExecution(command.Name, duration, ok)
		cooldowns:Commit(command.Name, player, command.Cooldown)

		if not ok then
			sink({ Type = "Error", Message = "That command hit an internal error." })
			debugModule:LogError(Errors.new("ExecutionError", tostring(runErr), {
				Command = command.Name,
				RequestId = requestId,
			}))
		end

		if command.Audit then
			audit:Log({
				Action = "CommandExecuted",
				Actor = player,
				Command = command.Name,
				Arguments = args,
				Success = ok,
				Error = if ok then nil else tostring(runErr),
				ExecutionTime = duration,
				Permission = command.Permission,
			})
		end
		history:Record(player, command.Name, ok)

		return { Success = ok, Command = command.Name, RequestId = requestId }
	end

	Route.Execute = executeRaw

	local testing = Testing.new({ Registry = registry, Route = Route })
	Route.Testing = testing

	-- Re-runs command discovery against the same Commands folder. Existing
	-- registrations are left alone (Support/Registry report duplicates
	-- rather than silently overwriting), so a failed reload can never
	-- corrupt what was already working.
	Route.Reload = function(): { Loaded: number, Errors: { any } }
		local reloadErrors: { any } = {}
		local loaded = Support.DiscoverFactories(opts.Commands, registerCommandFactory, function(err: any)
			table.insert(reloadErrors, err)
		end)
		return { Loaded = loaded, Errors = reloadErrors }
	end

	local network = Network.Start({
		Config = config,
		Cooldowns = cooldowns,
		Suggestions = suggestions,
		Execute = executeRaw,
		Route = Route,
		VersionString = VersionInfo.VersionString,
	})
	Route.Network = network

	-- ===== UI ==============================================================
	-- Server-owned: builds and hands a console to every player itself, from
	-- a template that lives inside the Framework (see UI/init.lua). Opt out
	-- entirely with StartOptions.UI = { Enabled = false } for a headless
	-- setup (e.g. a game driving commands some other way). Set a game-wide
	-- default look with StartOptions.UI.Theme (one of Framework/UI/Themes.lua's
	-- Ids - "cmdr", "midnight", "terminal", "floating") - players can still
	-- switch their own console's theme live with the `theme` command.
	Route.UI = UI.Start(opts.UI, emit, clientCommandModules)

	-- ===== Startup diagnostics =============================================
	local elapsed = os.clock() - startClock
	local shouldPrint = not (opts.Diagnostics and opts.Diagnostics.Print == false)
	if shouldPrint then
		-- One line, not a banner: welcome, version, how many commands loaded.
		-- Anything that failed to load already got its own warn() above (see
		-- Support.DiscoverFactories's error callback) - no need to repeat that
		-- here too.
		print(string.format(
			"[Route] Welcome! v%s ready in %.3fs - %d command(s) loaded.",
			VersionInfo.VersionString,
			elapsed,
			registry:Count()
		))
	end

	return Route
end

return Core
