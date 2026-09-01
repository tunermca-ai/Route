--!strict
-- Route.Moderation.BanStore
-- Small persisted ban list shared by the Ban/Unban commands. Lives
-- outside Commands/ (Route's discovery only walks the Commands folder
-- looking for command factories, so a helper module has to sit beside
-- it, not inside it). Best-effort DataStore persistence: works without
-- any datastore access too, it just won't survive a server restart then.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_KEY = "BannedUsers"

local BanStore = {}
local _bans: { [number]: { Reason: string, By: number, At: number } } = {}
local _loaded = false

local function getStore(): DataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("Route_Bans_v1")
	end)
	return if ok then store else nil
end

local function load()
	if _loaded then
		return
	end
	_loaded = true
	local store = getStore()
	if not store then
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync(STORE_KEY)
	end)
	if ok and type(data) == "table" then
		for userIdStr, info in pairs(data) do
			local userId = tonumber(userIdStr)
			if userId then
				_bans[userId] = info
			end
		end
	end
end

local function save()
	local store = getStore()
	if not store then
		return
	end
	local serializable = {}
	for userId, info in pairs(_bans) do
		serializable[tostring(userId)] = info
	end
	task.spawn(function()
		pcall(function()
			store:SetAsync(STORE_KEY, serializable)
		end)
	end)
end

load()

function BanStore.Ban(userId: number, reason: string, byUserId: number)
	_bans[userId] = { Reason = reason, By = byUserId, At = os.time() }
	save()
end

function BanStore.Unban(userId: number): boolean
	if not _bans[userId] then
		return false
	end
	_bans[userId] = nil
	save()
	return true
end

function BanStore.IsBanned(userId: number): (boolean, string?)
	local info = _bans[userId]
	if not info then
		return false, nil
	end
	return true, info.Reason
end

function BanStore.List(): { [number]: { Reason: string, By: number, At: number } }
	return _bans
end

Players.PlayerAdded:Connect(function(player: Player)
	local banned, reason = BanStore.IsBanned(player.UserId)
	if banned then
		player:Kick(string.format("You are banned.\nReason: %s", reason or "No reason given"))
	end
end)

return BanStore
