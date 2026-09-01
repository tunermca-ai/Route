--!strict
-- Route.Shared.Version
-- Single source of truth for the framework's semantic version.
-- Exposed on the client (harmless) so the UI can show "Route vX.Y.Z".

export type Version = {
	Major: number,
	Minor: number,
	Patch: number,
}

local Version: Version = {
	Major = 1,
	Minor = 0,
	Patch = 0,
}

local VersionString = string.format("%d.%d.%d", Version.Major, Version.Minor, Version.Patch)

return {
	Version = Version,
	VersionString = VersionString,
}
