--!strict
-- Route.Discord
-- Discord webhook integration via HttpService. The webhook URL is kept
-- in a module-local field that no public method ever returns - Status()
-- reports whether one is configured, never what it is, and command
-- output must never print it either.

local HttpService = game:GetService("HttpService")

local KNOWN_EVENTS = {
	"CommandExecuted",
	"PermissionChanged",
	"RoleChanged",
	"PlayerKicked",
	"PlayerBanned",
	"ServerShutdown",
	"Error",
	"Warning",
	"ConfigurationChanged",
}

local COLORS: { [string]: number } = {
	CommandExecuted = 0x5865F2,
	PermissionChanged = 0xF5A623,
	RoleChanged = 0xF5A623,
	PlayerKicked = 0xED4245,
	PlayerBanned = 0x992D22,
	ServerShutdown = 0x992D22,
	Error = 0xED4245,
	Warning = 0xFAA61A,
	ConfigurationChanged = 0x3BA55D,
}

local Discord = {}
Discord.__index = Discord

function Discord.new(config: any): any
	local self = setmetatable({
		_config = config,
		_webhookUrl = nil :: string?,
		_enabled = false,
		_eventFilter = {} :: { [string]: boolean },
	}, Discord)
	for _, event in ipairs(KNOWN_EVENTS) do
		self._eventFilter[event] = true
	end
	return self
end

function Discord:SetWebhook(url: string): (boolean, string?)
	if type(url) ~= "string" or not url:match("^https?://") then
		return false, "webhook must be a valid http(s) URL"
	end
	self._webhookUrl = url
	return true, nil
end

function Discord:ClearWebhook()
	self._webhookUrl = nil
	self._enabled = false
end

function Discord:Enable(): (boolean, string?)
	if not self._webhookUrl then
		return false, "no webhook configured - use `/route discord webhook set <url>` first"
	end
	self._enabled = true
	return true, nil
end

function Discord:Disable()
	self._enabled = false
end

function Discord:IsConfigured(): boolean
	return self._webhookUrl ~= nil
end

function Discord:IsEnabled(): boolean
	return self._enabled
end

function Discord:EnableEvent(event: string): boolean
	if self._eventFilter[event] == nil then
		return false
	end
	self._eventFilter[event] = true
	return true
end

function Discord:DisableEvent(event: string): boolean
	if self._eventFilter[event] == nil then
		return false
	end
	self._eventFilter[event] = false
	return true
end

function Discord:GetKnownEvents(): { string }
	return KNOWN_EVENTS
end

-- Safe to display: never includes the URL itself.
function Discord:Status(): { Enabled: boolean, Configured: boolean, Events: { [string]: boolean } }
	return {
		Enabled = self._enabled,
		Configured = self._webhookUrl ~= nil,
		Events = table.clone(self._eventFilter),
	}
end

local function buildEmbed(eventName: string, payload: { [string]: any }): { [string]: any }
	local fields = {}
	for key, value in pairs(payload) do
		if key ~= "Title" and key ~= "Description" then
			table.insert(fields, { name = key, value = tostring(value), inline = true })
		end
	end
	return {
		title = payload.Title or eventName,
		description = payload.Description,
		color = COLORS[eventName] or 0x5865F2,
		fields = fields,
		timestamp = DateTime.now():ToIsoDate(),
	}
end

function Discord:Send(eventName: string, payload: { [string]: any })
	if not self._enabled or not self._webhookUrl then
		return
	end
	if self._eventFilter[eventName] == false then
		return
	end
	local url = self._webhookUrl
	local body = HttpService:JSONEncode({ embeds = { buildEmbed(eventName, payload) } })
	task.spawn(function()
		pcall(function()
			HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
		end)
	end)
end

-- Bypasses the event filter (but not Enabled/Configured) so `/route
-- discord webhook test` always produces visible output when it's meant to.
function Discord:Test(): (boolean, string?)
	if not self._webhookUrl then
		return false, "no webhook configured"
	end
	local url = self._webhookUrl
	local body = HttpService:JSONEncode({
		embeds = { buildEmbed("Test", { Title = "Route test message", Description = "If you can see this, the webhook works." }) },
	})
	local ok, err = pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

return Discord
