--!strict
-- Route.Moderation.MuteStore
-- In-memory mute list (does not persist across server restarts) wired
-- into TextChatService so a mute actually silences chat, not just
-- tracks a flag no other system reads.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local MuteStore = {}
local _muted: { [number]: string } = {} -- userId -> reason

function MuteStore.Mute(userId: number, reason: string)
	_muted[userId] = reason
end

function MuteStore.Unmute(userId: number): boolean
	if not _muted[userId] then
		return false
	end
	_muted[userId] = nil
	return true
end

function MuteStore.IsMuted(userId: number): (boolean, string?)
	local reason = _muted[userId]
	if reason == nil then
		return false, nil
	end
	return true, reason
end

local ok = pcall(function()
	local generalChannel = TextChatService:WaitForChild("TextChannels", 5):WaitForChild("RBXGeneral", 5)
	generalChannel.ShouldDeliverCallback = function(_message: TextChatMessage, textSource: TextSource?)
		if not textSource then
			return true
		end
		return not _muted[textSource.UserId]
	end
end)
if not ok then
	warn("[Route] MuteStore couldn't hook TextChatService.RBXGeneral - /mute won't silence chat on this place's chat setup.")
end

Players.PlayerRemoving:Connect(function(player: Player)
	_muted[player.UserId] = nil
end)

return MuteStore
