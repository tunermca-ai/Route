--!strict
-- Route.Support
-- Folder discovery / module loading. A broken module here must never
-- take the whole framework down with it - every step is pcall-isolated
-- and reported back through `onError` instead of propagating.

export type DiscoveryError = {
	Instance: Instance,
	Message: string,
}

local Support = {}

local function walk(root: Instance, into: { ModuleScript })
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(into, child)
		elseif child:IsA("Folder") then
			walk(child, into)
		end
	end
end

-- Recursively finds every ModuleScript under `folder`, requires it, and
-- hands whatever it returns to `handle`. A module can return the thing
-- itself directly - a built Command (Command.new(...):...:run(...)), a
-- { Name = ..., Parse = ... } type definition, a { Name = ..., Fn = ... }
-- guard - or a zero-argument function that builds and returns one; both
-- forms are handled the same way from here. The function form is only
-- there for when a module wants to defer construction (or do other work)
-- until discovery actually calls it - most command files don't need
-- that, and can just `return Command.new(...):...` straight off the
-- bottom of the file. Any failure at any step is caught and reported via
-- `onError` rather than raised.
--
-- `folder` accepts a single Instance (the common case: one Commands
-- folder) or an array of Instances - e.g. Commands = { Framework.Commands,
-- ServerScriptService.CustomRoute } - so a game's own custom commands can
-- live in a folder of their own, entirely separate from the ones the
-- package ships with, without needing to be copied or moved into
-- Framework/Commands to be discovered.
function Support.DiscoverFactories(
	folder: (Instance | { Instance })?,
	handle: (result: any, moduleScript: ModuleScript) -> (boolean, string?),
	onError: (err: DiscoveryError) -> ()
): number
	if not folder then
		return 0
	end

	local roots: { Instance }
	if typeof(folder) == "table" then
		roots = folder :: { Instance }
	else
		roots = { folder :: Instance }
	end

	local modules: { ModuleScript } = {}
	for _, root in ipairs(roots) do
		walk(root, modules)
	end

	local successCount = 0
	for _, moduleScript in ipairs(modules) do
		local ok, moduleResult = pcall(require, moduleScript)
		if not ok then
			onError({ Instance = moduleScript, Message = tostring(moduleResult) })
		else
			local ok2, resultOrErr = if type(moduleResult) == "function"
				then pcall(moduleResult :: () -> any)
				else true, moduleResult
			if not ok2 then
				onError({ Instance = moduleScript, Message = tostring(resultOrErr) })
			else
				local ok3, err3 = handle(resultOrErr, moduleScript)
				if not ok3 then
					onError({ Instance = moduleScript, Message = err3 or "registration failed" })
				else
					successCount += 1
				end
			end
		end
	end

	return successCount
end

return Support
