--!strict
-- Route.Moderation.Restraint
-- Shared freeze/jail mechanics used by the freeze, unfreeze, jail, and
-- unjail commands. Lives outside Commands/ so Support.DiscoverFactories
-- (which only treats Commands/ modules as command factories) never
-- mistakes this for one - same pattern as BanStore/MuteStore.
--
-- All state is tracked as Attributes on the Character instance, not in a
-- table keyed by UserId: Attributes travel with the Character and are
-- gone the instant it's destroyed, so a fresh respawn can never be born
-- already frozen or jailed, and there is nothing here that needs its own
-- PlayerRemoving cleanup.
--
-- Freeze and Jail share one physical lock (zeroed WalkSpeed/JumpPower/
-- JumpHeight + an anchored HumanoidRootPart) so a player who is both
-- frozen and jailed at once only gets released once *both* are lifted -
-- releasing one while the other still holds would let them fall through
-- whatever the jail was containing them in.

local Restraint = {}

local function getRoot(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Applies the "can't move" mechanics. Only records the pre-restraint
-- WalkSpeed/JumpPower/JumpHeight/Anchored the first time (i.e. when
-- neither Frozen nor Jailed is already set) - calling this a second time
-- because e.g. /jail is applied on top of an existing /freeze must never
-- clobber the true original values with the zeros a first lock left in
-- place.
local function applyLock(character: Model, humanoid: Humanoid)
	if not (character:GetAttribute("RouteFrozen") or character:GetAttribute("RouteJailed")) then
		character:SetAttribute("RouteOriginalWalkSpeed", humanoid.WalkSpeed)
		character:SetAttribute("RouteOriginalJumpPower", humanoid.JumpPower)
		character:SetAttribute("RouteOriginalJumpHeight", humanoid.JumpHeight)
		local root = getRoot(character)
		character:SetAttribute("RouteOriginalAnchored", root ~= nil and root.Anchored)
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	local root = getRoot(character)
	if root then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

-- Reverses applyLock and clears every restraint attribute. Only called
-- once both RouteFrozen and RouteJailed are cleared.
local function releaseLock(character: Model, humanoid: Humanoid)
	local originalSpeed = character:GetAttribute("RouteOriginalWalkSpeed")
	local originalJumpPower = character:GetAttribute("RouteOriginalJumpPower")
	local originalJumpHeight = character:GetAttribute("RouteOriginalJumpHeight")
	local originalAnchored = character:GetAttribute("RouteOriginalAnchored")
	humanoid.WalkSpeed = if type(originalSpeed) == "number" then originalSpeed else 16
	humanoid.JumpPower = if type(originalJumpPower) == "number" then originalJumpPower else 50
	humanoid.JumpHeight = if type(originalJumpHeight) == "number" then originalJumpHeight else 7.2
	local root = getRoot(character)
	if root then
		root.Anchored = originalAnchored == true
	end
	character:SetAttribute("RouteOriginalWalkSpeed", nil)
	character:SetAttribute("RouteOriginalJumpPower", nil)
	character:SetAttribute("RouteOriginalJumpHeight", nil)
	character:SetAttribute("RouteOriginalAnchored", nil)
end

function Restraint.IsFrozen(character: Model): boolean
	return character:GetAttribute("RouteFrozen") == true
end

function Restraint.IsJailed(character: Model): boolean
	return character:GetAttribute("RouteJailed") == true
end

function Restraint.Freeze(character: Model, humanoid: Humanoid): (boolean, string?)
	if Restraint.IsFrozen(character) then
		return false, "already frozen"
	end
	applyLock(character, humanoid)
	character:SetAttribute("RouteFrozen", true)
	return true, nil
end

function Restraint.Unfreeze(character: Model, humanoid: Humanoid): (boolean, string?)
	if not Restraint.IsFrozen(character) then
		return false, "not frozen"
	end
	character:SetAttribute("RouteFrozen", nil)
	if not Restraint.IsJailed(character) then
		releaseLock(character, humanoid)
	end
	return true, nil
end

-- jailCFrame: where to teleport the player. Their pre-jail CFrame is
-- remembered (as an Attribute, so it survives with the character) and
-- restored by Unjail.
function Restraint.Jail(character: Model, humanoid: Humanoid, jailCFrame: CFrame): (boolean, string?)
	if Restraint.IsJailed(character) then
		return false, "already jailed"
	end
	local root = getRoot(character)
	if not root then
		return false, "character has no HumanoidRootPart"
	end
	if not Restraint.IsFrozen(character) then
		applyLock(character, humanoid)
	end
	character:SetAttribute("RouteJailReturnCFrame", root.CFrame)
	character:SetAttribute("RouteJailed", true)
	root.Anchored = false
	root.CFrame = jailCFrame
	root.Anchored = true
	return true, nil
end

function Restraint.Unjail(character: Model, humanoid: Humanoid): (boolean, string?)
	if not Restraint.IsJailed(character) then
		return false, "not jailed"
	end
	local returnCFrame = character:GetAttribute("RouteJailReturnCFrame")
	character:SetAttribute("RouteJailed", nil)
	character:SetAttribute("RouteJailReturnCFrame", nil)
	if not Restraint.IsFrozen(character) then
		releaseLock(character, humanoid)
	end
	local root = getRoot(character)
	if root and typeof(returnCFrame) == "CFrame" then
		local wasAnchored = root.Anchored
		root.Anchored = false
		root.CFrame = returnCFrame
		root.Anchored = wasAnchored
	end
	return true, nil
end

return Restraint
