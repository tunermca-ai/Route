--!strict
-- Route
-- Package entry point. From your own server-side bootstrap script:
--
--   local ServerScriptService = game:GetService("ServerScriptService")
--   local Route = require(ServerScriptService.Route.Route)
--
--   Route.Start({
--       Commands = {                          -- required: skipping this loads zero
--           Route.DefaultCommands,            -- commands. Every prebuilt command
--           ServerScriptService.CustomRoute.Commands, -- (kick/ban/...) lives in the
--       },                                    -- first folder; your own game's
--                                              -- commands go in the second, in any
--                                              -- folder you like, under any name - see
--                                              -- "Default vs. custom commands" in
--                                              -- README.md.
--       -- Types/Guards are optional and omitted here on purpose - a one-off custom
--       -- type/guard needs no registration at all (Types.enum(...), an inline
--       -- :guard(fn) on the command itself), and a reusable one is a single
--       -- Route.Types:Register(...)/Route.Guards:Register(...) call from anywhere.
--       -- Both options still accept a folder too, if you'd rather keep many of
--       -- them as separate auto-discovered files - see README.md's "Custom types
--       -- and guards, without a folder".
--   })
--
-- See README.md at the repo root for the full option list (Permissions,
-- Discord, Audit, Debug, Prefix, Client) and usage examples.
--
-- Route.Command / Route.Types / Route.Guards / Route.DefaultCommands are
-- available on this table immediately, before Start() is ever called -
-- see the comment further down for why. That's the whole entry point a
-- command file needs:
--
--   local Route = require(ServerScriptService.Route.Route)
--   local Command, Types = Route.Command, Route.Types
--
--   return Command.new("mycommand")
--       :description("...")
--       :run(function(ctx, args) ... end)
--
-- Every other public field (Commands, Permissions, Config, Debug, Audit,
-- Discord, Network, Testing, Suggestions, History, Cooldowns, UI) is
-- populated on this same table once Start() returns, so anywhere else
-- that also does `require(...Route.Route)` gets the same live instance
-- back - Luau caches ModuleScript requires per-script.
--
-- Route.On(eventName, fn) / Route.Once(eventName, fn) - discord.js-style
-- event hooks, also populated by Start(). "CommandExecuted",
-- "PermissionChanged", and "RoleChanged" fire under the same rules as
-- Route's own Audit sinks; "ThemeChanged" fires from the `theme` command
-- or any other UI:SetTheme call. See Core/init.lua's "Events" comment for
-- the full story.

local Core = require(script.Parent.Framework.Core)
local VersionInfo = require(script.Parent.Framework.Version)

export type StartOptions = Core.StartOptions

local Route = {}
Route.Version = VersionInfo.Version
Route.VersionString = VersionInfo.VersionString
Route._started = false

-- Command/Types/Guards are plain, self-contained modules - Types and
-- Guards self-register their built-ins the moment they're required, and
-- Command.new() needs nothing but itself - so all three are exposed here
-- immediately, not copied over from Start()'s result the way everything
-- else below is. That's deliberate, not just convenient: every command
-- module gets required and run during Start()'s own discovery step,
-- which happens *inside* Core.Start() - long before it returns and this
-- table would otherwise get its Types/Guards/etc. filled in - so a
-- command reading Route.Command or Route.Types has to find them already
-- there regardless of whether Start() has even been called yet.
--
-- Route.DefaultCommands is the same idea, for a different reason: it's
-- just script.Parent.Framework.Commands, a plain Instance reference, not
-- a Registry or anything else that could only exist post-Start() - so
-- it's exposed here too, both for consistency and because it removes the
-- one easy mix-up this table otherwise invites: Route.Commands (the
-- live Registry, plural, only valid after Start()) versus "the folder of
-- default command modules to hand to Start() in the first place". If
-- your bootstrap script ever passes Route.Commands as a Commands=
-- option, that's the bug this field exists to make impossible - it reads
-- as nil at the point Start() is actually called, silently loading zero
-- default commands. Use Route.DefaultCommands for that instead.
--
-- This is what makes one require read like discord.js's
-- `const { Client, EmbedBuilder } = require("discord.js")`:
--
--   local Route = require(ServerScriptService.Route.Route)
--   local Command, Types = Route.Command, Route.Types
--
-- Luau has no `local { Command, Types } = require(...)` destructuring -
-- that's not valid syntax here - so the two-locals-in-one-line form
-- above is the closest equivalent. It's still one require either way,

Route.Command = require(script.Parent.Framework.Command)
Route.Types = require(script.Parent.Framework.Types)
Route.Guards = require(script.Parent.Framework.Guards)
Route.DefaultCommands = script.Parent.Framework.Commands

function Route.Start(options: StartOptions?)
	if Route._started then
		warn("[Route] Start() was already called once on this server - ignoring the second call.")
		return Route
	end

	local instance = Core.Start(options)
	for key, value in pairs(instance) do
		(Route :: any)[key] = value
	end
	Route._started = true

	return Route
end

return Route
