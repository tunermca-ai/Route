--!strict
-- Route.Network.RemoteSetup
-- Route ships as a single self-contained package under ServerScriptService,
-- so unlike a Rojo-authored ReplicatedStorage tree, the handful of remote
-- instances the client UI needs are created here at runtime and parented
-- into ReplicatedStorage. This module only ever runs on the server -
-- there is nothing for a client to require.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "RouteRemotes"

export type RouteRemotes = {
	-- Client -> Server: raw command text, e.g. "kick Nikilis exploiting"
	Command: RemoteEvent,
	-- Server -> Client: structured responses (see ResponseTypes.lua)
	Response: RemoteEvent,
	-- Client -> Server -> Client: autocomplete/suggestion requests
	Autocomplete: RemoteFunction,
	-- Client -> Server -> Client: non-sensitive bootstrap info (prefix, version)
	Bootstrap: RemoteFunction,
}

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- One-time clone of the Command builder module into RouteRemotes, so a
-- :runClient() command's own source module can require Command through
-- this same fixed, replicated path whether it's executing during normal
-- server-side discovery (see Core.lua, which calls Setup() before
-- discovery runs specifically so this exists in time) or, later, after
-- being cloned into a player's PlayerGui to actually run client-side (see
-- UI/init.lua and Controller.client.lua). Command/init.lua has zero
-- requires of its own, so the clone is fully self-contained - nothing
-- else needs to travel with it.
local function ensureClientCommand(folder: Folder)
	if folder:FindFirstChild("ClientCommand") then
		return
	end
	local commandModule = script.Parent.Parent:FindFirstChild("Command")
	if not commandModule then
		warn("[Route] Command module not found - :runClient() commands will not be able to require it.")
		return
	end
	local clone = commandModule:Clone()
	clone.Name = "ClientCommand"
	clone.Parent = folder
end

-- Idempotent: safe to call every time the server starts, even after a
-- hot reload, since it reuses any remotes left over from a previous run.
local function setup(): RouteRemotes
	local folder = getOrCreate(ReplicatedStorage, "Folder", FOLDER_NAME) :: Folder
	ensureClientCommand(folder)

	return {
		Command = getOrCreate(folder, "RemoteEvent", "Command") :: RemoteEvent,
		Response = getOrCreate(folder, "RemoteEvent", "Response") :: RemoteEvent,
		Autocomplete = getOrCreate(folder, "RemoteFunction", "Autocomplete") :: RemoteFunction,
		Bootstrap = getOrCreate(folder, "RemoteFunction", "Bootstrap") :: RemoteFunction,
	}
end

return { Setup = setup }
