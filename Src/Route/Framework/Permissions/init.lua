--!strict
-- Route.Permissions
-- Permission nodes ("moderation.kick") + roles with inheritance. Grants
-- and role membership live in memory and are mirrored to DataStore only
-- when persistence is explicitly enabled (Config: Permissions.Persistence.Enabled),
-- so Route works out of the box in Studio without any datastore access.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Role = {
	Name: string,
	Permissions: { [string]: boolean },
	Inherits: { string },
}

type PlayerOrId = Player | number

local Permissions = {}
Permissions.__index = Permissions

function Permissions.new(config: any, audit: any?): any
	local self = setmetatable({
		_grants = {} :: { [number]: { [string]: boolean } },
		_roles = {} :: { [string]: Role },
		_memberships = {} :: { [number]: { [string]: boolean } },
		_knownNodes = {} :: { [string]: string? }, -- node -> description
		_config = config,
		_audit = audit,
		_store = nil :: DataStore?,
		-- Computed once - this can't change mid-session, and IsStudio() is
		-- one of the few Roblox APIs where the actual "am I in Studio"
		-- answer matters for a security-relevant decision (see :Has()).
		_isStudio = RunService:IsStudio(),
	}, Permissions)
	return self
end

-- Studio (both Edit and Play-test) always has a real, private developer at
-- the keyboard - there's no player-facing server to protect there, so by
-- default every permission check passes automatically. A published, live
-- server (RunService:IsStudio() == false) always enforces normally
-- regardless of this setting - only Studio can ever be bypassed.
function Permissions:_bypassInStudio(): boolean
	if not self._isStudio then
		return false
	end
	local ok, value = pcall(function()
		return self._config:Get("Permissions.BypassInStudio")
	end)
	if not ok then
		return true -- fail open to the documented default (see Config's RegisterDefaults)
	end
	return value ~= false
end

local function resolveUserId(target: PlayerOrId): number
	if typeof(target) == "Instance" then
		return (target :: Player).UserId
	end
	return target :: number
end

local function nodeMatches(pattern: string, node: string): boolean
	if pattern == "*" or pattern == node then
		return true
	end
	if pattern:sub(-1) == "*" then
		local prefix = pattern:sub(1, -2)
		return node:sub(1, #prefix) == prefix
	end
	return false
end

function Permissions:_getStore(): DataStore?
	if self._store then
		return self._store
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("Route_Permissions_v1")
	end)
	if ok then
		self._store = store
		return store
	end
	return nil
end

function Permissions:_persistenceEnabled(): boolean
	local ok, enabled = pcall(function()
		return self._config:Get("Permissions.Persistence.Enabled")
	end)
	return ok and enabled == true
end

function Permissions:_save(userId: number)
	if not self:_persistenceEnabled() then
		return
	end
	local store = self:_getStore()
	if not store then
		return
	end
	local grants = self._grants[userId] or {}
	local roles = self._memberships[userId] or {}
	task.spawn(function()
		pcall(function()
			store:SetAsync(tostring(userId), {
				Grants = grants,
				Roles = roles,
			})
		end)
	end)
end

function Permissions:LoadPlayer(player: Player)
	if not self:_persistenceEnabled() then
		return
	end
	local store = self:_getStore()
	if not store then
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok and type(data) == "table" then
		self._grants[player.UserId] = data.Grants or {}
		self._memberships[player.UserId] = data.Roles or {}
	end
end

-- ===== Direct grants ====================================================

function Permissions:Grant(target: PlayerOrId, node: string)
	local userId = resolveUserId(target)
	self._grants[userId] = self._grants[userId] or {}
	self._grants[userId][node] = true
	self:DeclareNode(node)
	self:_save(userId)
end

function Permissions:Revoke(target: PlayerOrId, node: string)
	local userId = resolveUserId(target)
	if self._grants[userId] then
		self._grants[userId][node] = nil
	end
	self:_save(userId)
end

local function roleHasPermission(self: any, roleKey: string, node: string, visited: { [string]: boolean }): boolean
	if visited[roleKey] then
		return false
	end
	visited[roleKey] = true
	local role = self._roles[roleKey]
	if not role then
		return false
	end
	for pattern in pairs(role.Permissions) do
		if nodeMatches(pattern, node) then
			return true
		end
	end
	for _, parentKey in ipairs(role.Inherits) do
		if roleHasPermission(self, parentKey:lower(), node, visited) then
			return true
		end
	end
	return false
end

function Permissions:Has(target: PlayerOrId, node: string): boolean
	if self:_bypassInStudio() then
		return true
	end

	local userId = resolveUserId(target)

	local grants = self._grants[userId]
	if grants then
		for pattern in pairs(grants) do
			if nodeMatches(pattern, node) then
				return true
			end
		end
	end

	local memberships = self._memberships[userId]
	if memberships then
		for roleKey in pairs(memberships) do
			if roleHasPermission(self, roleKey, node, {}) then
				return true
			end
		end
	end

	return false
end

-- ===== Roles =============================================================

function Permissions:CreateRole(name: string, permissions: { string }?, opts: { Inherits: { string }? }?): (boolean, string?)
	local key = name:lower()
	if self._roles[key] then
		return false, string.format('role "%s" already exists', name)
	end
	local permSet = {}
	for _, node in ipairs(permissions or {}) do
		permSet[node] = true
		self:DeclareNode(node)
	end
	local inherits = {}
	for _, parent in ipairs((opts and opts.Inherits) or {}) do
		table.insert(inherits, parent:lower())
	end
	self._roles[key] = { Name = name, Permissions = permSet, Inherits = inherits }
	return true, nil
end

function Permissions:DeleteRole(name: string): boolean
	local key = name:lower()
	if not self._roles[key] then
		return false
	end
	self._roles[key] = nil
	for _, memberships in pairs(self._memberships) do
		memberships[key] = nil
	end
	return true
end

function Permissions:GetRole(name: string): Role?
	return self._roles[name:lower()]
end

function Permissions:ListRoles(): { Role }
	local list = {}
	for _, role in pairs(self._roles) do
		table.insert(list, role)
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

function Permissions:AddPermissionToRole(roleName: string, node: string): boolean
	local role = self:GetRole(roleName)
	if not role then
		return false
	end
	role.Permissions[node] = true
	self:DeclareNode(node)
	return true
end

function Permissions:RemovePermissionFromRole(roleName: string, node: string): boolean
	local role = self:GetRole(roleName)
	if not role then
		return false
	end
	role.Permissions[node] = nil
	return true
end

function Permissions:AddToRole(target: PlayerOrId, roleName: string): (boolean, string?)
	local role = self:GetRole(roleName)
	if not role then
		return false, string.format('no role named "%s"', roleName)
	end
	local userId = resolveUserId(target)
	self._memberships[userId] = self._memberships[userId] or {}
	self._memberships[userId][roleName:lower()] = true
	self:_save(userId)
	return true, nil
end

function Permissions:RemoveFromRole(target: PlayerOrId, roleName: string): boolean
	local userId = resolveUserId(target)
	local memberships = self._memberships[userId]
	if not memberships then
		return false
	end
	memberships[roleName:lower()] = nil
	self:_save(userId)
	return true
end

function Permissions:GetRoles(target: PlayerOrId): { string }
	local userId = resolveUserId(target)
	local memberships = self._memberships[userId]
	local list = {}
	if memberships then
		for roleKey in pairs(memberships) do
			local role = self._roles[roleKey]
			table.insert(list, if role then role.Name else roleKey)
		end
	end
	table.sort(list)
	return list
end

-- ===== Introspection ======================================================

function Permissions:DeclareNode(node: string, description: string?)
	if self._knownNodes[node] == nil then
		self._knownNodes[node] = description
	end
end

function Permissions:GetKnownNodes(): { string }
	local list = {}
	for node in pairs(self._knownNodes) do
		table.insert(list, node)
	end
	table.sort(list)
	return list
end

return Permissions
