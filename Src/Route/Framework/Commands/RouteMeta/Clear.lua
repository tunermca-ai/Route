--!strict
-- The first real :runClient() command - see Command:runClient in
-- Command/init.lua for the full explanation of what that means. This
-- command's implementation never runs on the server at all: it's cloned
-- straight into every player's own console (see UI/init.lua) and
-- Controller.client.lua calls it directly the moment "clear" is typed,
-- with zero CommandRemote:FireServer round-trip. That's also why it
-- requires Command from ReplicatedStorage.RouteRemotes.ClientCommand
-- instead of the usual script.Parent.Parent.Parent chain every other
-- command here uses - this module's code has to resolve that require
-- correctly both when Core.lua discovers it on the server (to register
-- it) and later, after being cloned, when Controller.client.lua requires
-- it fresh on the client to actually run it. RouteRemotes is the one
-- location both sides can already see.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Command = require(ReplicatedStorage:WaitForChild("RouteRemotes"):WaitForChild("ClientCommand"))

return Command.new("clear")
	:description("Clear this console's output log")
	:category("Debug")
	:aliases("cls")
	:example("clear")
	-- No :permission(), :guard(), or :cooldown() - none of those could
	-- ever be enforced for a command that never reaches the server, and
	-- Core.lua's discovery step rejects the combination outright if one
	-- is added here by mistake.
	:runClient(function(ctx: any, _argsText: string)
		ctx:ClearOutput()
	end)
