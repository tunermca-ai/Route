<p align="center">
  <img src="assets/logo.png" alt="Route" width="380">
</p>

[![Version](https://img.shields.io/badge/version-1.0.0-eab454)](https://github.com/tunermca-ai/Route.lua/releases) [![Luau](https://img.shields.io/badge/luau-strict-2a2d34)](https://luau.org) [![Rojo](https://img.shields.io/badge/rojo-ready-2a2d34)](https://rojo.space) [![Wally](https://img.shields.io/badge/wally-tunermca--ai%2Froute-2a2d34)](https://wally.run)

A server-authoritative admin command framework for Roblox.

**[Documentation →](https://tunermca-ai.github.io/Route.lua.github.io/)** — [Installation](https://tunermca-ai.github.io/Route.lua.github.io/#/install) · [Quick start](https://tunermca-ai.github.io/Route.lua.github.io/#/quickstart) · [Commands](https://tunermca-ai.github.io/Route.lua.github.io/#/commands) · [Examples](https://tunermca-ai.github.io/Route.lua.github.io/#/examples) · [Security model](https://tunermca-ai.github.io/Route.lua.github.io/#/security)

```
route> give Nikilis Owner
→ Nikilis now has role "Owner" (full access)
route> givecoins @all 100
✓ Gave 100 coin(s) to 8 player(s)
```

Not a Cmdr fork or reskin — a separate implementation of the same idea, with its own architecture from the ground up. If you've used a console like it before, the shape will feel familiar.

## Why Route

Every admin console eventually gets exploited through the one thing it trusted the client to say. Route is built so that never happens:

- **Server-authoritative, always.** A fixed pipeline — parse → resolve → validate → permission → guards → cooldown → rate limit → execute → audit → respond — runs the same way every time, entirely server-side. The client only ever sends raw text.
- **Typed arguments out of the box.** 24 built-in types — players, durations, colors, permission nodes, and more — parse and validate before your command ever sees them. Register your own in one line.
- **Wildcard permissions.** Dot-path nodes like `moderation.kick`, checked with wildcards (`moderation.*`, `*`). `Owner` and `Admin` exist automatically; everything past that is yours to define.
- **Extensible without ceremony.** Types and guards are just registries — call `Route.Types:Register(...)` or `Route.Guards:Register(...)` from anywhere. No project structure to learn first.
- **A console, included.** A polished command console ships with the package and appears for every player automatically — four themes, autocomplete, command history — with nothing to build in Studio.
- **Audit logging and a Discord relay.** Every execution can be logged and optionally relayed to a webhook, filterable per event type.

## Installation

**Wally**

```toml
[dependencies]
Route = "tunermca-ai/route@1.0.0"
```

**Manual / Rojo**

Drop the `Src/Route` folder from this repo into `ServerScriptService` as `Route`. That's the entire install — nothing else needs to be authored anywhere else in your place.

Full walkthrough: [Installation →](https://tunermca-ai.github.io/Route.lua.github.io/#/install)

## Quick start

```lua
-- ServerScriptService/ServerScript.server.lua
local ServerScriptService = game:GetService("ServerScriptService")
local Route = require(ServerScriptService.Route.Route)

Route.Start({
	Commands = { Route.DefaultCommands },   -- required — see the docs for adding your own
	Permissions = {
		Owners = { 123456789 },               -- your UserId(s) — always get full access
	},
})
```

That's enough to boot every built-in command, type, and guard, plus a console every player can open with F2. Add your own commands the same way the built-ins are written — one require, then chain off the builder:

```lua
local Command, Types = Route.Command, Route.Types

return Command.new("givecoins")
	:description("Give coins to a player")
	:category("Economy")
	:permission("custom.givecoins")
	:arg(Types.players, "targets", "Player(s) to give coins to")
	:arg(Types.integer, "amount", "How many coins")
	:run(function(ctx, args)
		-- ...
	end)
```

See [Quick start →](https://tunermca-ai.github.io/Route.lua.github.io/#/quickstart) for the full option list, [Writing a command →](https://tunermca-ai.github.io/Route.lua.github.io/#/writing) for the details, and [Examples →](https://tunermca-ai.github.io/Route.lua.github.io/#/examples) for four complete, explained commands covering durations, guards, custom types, and enums.

## What's included

| Category | Commands |
| --- | --- |
| Moderation | `ban` `unban` `kick` `mute` `unmute` `warn` `freeze` `unfreeze` `jail` `unjail` |
| Players | `kill` `heal` `damage` `respawn` `speed` `teleport` `bring` `goto` `jump` `sit` `unsit` |
| Server | `lock` `unlock` `shutdown` `serverinfo` `jobid` `playerslist` |
| Permissions | `give` `perm` `role` |
| Configuration | `config` |
| Debug | `debug` `route` |
| Fun | `explode` `fling` `gravity` `size` `spin` |
| Route meta | `help` `history` `theme` `clear` |

Full list with descriptions: [Commands included →](https://tunermca-ai.github.io/Route.lua.github.io/#/commands)

## Console themes

Every player gets a console with F2, autocomplete, command history, and a live usage hint — pick a look with `Route.Start({ UI = { Theme = "..." } })`, or let players switch their own with `/theme`:

| Theme | Look |
| --- | --- |
| `midnight` | Route's default — blue accent on a deep near-black panel |
| `cmdr` | A gold, shell-style prompt built to match Cmdr's console |
| `terminal` | Monospace, high-contrast, green-on-black |
| `floating` | A centered floating window |

More on themes and the console: [Client console →](https://tunermca-ai.github.io/Route.lua.github.io/#/console)

## Permissions

```
route> give Nikilis Admin
route> role create Tester players.speed,players.teleport
route> give Nikilis Tester
```

`Owner` and `Admin` always exist with full access — nothing to set up first. Nodes are dot-path strings checked with wildcard matching, and custom roles start with nothing until you grant them permissions. Studio bypasses every check by default so you can test freely.

Full guide: [Permissions & roles →](https://tunermca-ai.github.io/Route.lua.github.io/#/permissions)

## Changelog

See [Changelog →](https://tunermca-ai.github.io/Route.lua.github.io/#/changelog) for the full version history.

## License

[MIT](LICENSE)

## Credits

Route's type-naming convention and a few console UX touches follow [Cmdr](https://github.com/evaera/Cmdr)'s lead — Route is a from-scratch implementation with its own pipeline and permission model, not a fork.
