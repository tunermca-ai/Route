--!strict
-- Route.Debug
-- Route's introspection and profiling surface. Everything here reads
-- from the same registries the rest of the framework uses - `/route
-- debug` can never lie about what's actually registered.

export type CommandProfile = {
	Command: string,
	Executions: number,
	Average: number,
	Minimum: number,
	Maximum: number,
	Failures: number,
}

type ProfileAccum = {
	Executions: number,
	TotalTime: number,
	Minimum: number,
	Maximum: number,
	Failures: number,
}

local Debug = {}
Debug.__index = Debug

function Debug.new(deps: {
	Registry: any,
	Types: any,
	Guards: any,
	Permissions: any,
	Config: any,
	StartedAt: number,
}): any
	local self = setmetatable({
		_deps = deps,
		_profiles = {} :: { [string]: ProfileAccum },
		_errors = {} :: { any },
		_maxErrors = 200,
	}, Debug)
	return self
end

function Debug:RecordExecution(commandName: string, duration: number, success: boolean)
	local ok, enabled = pcall(function()
		return self._deps.Config:Get("Debug.Profiling.Enabled")
	end)
	if ok and enabled == false then
		return
	end
	local accum = self._profiles[commandName]
	if not accum then
		accum = { Executions = 0, TotalTime = 0, Minimum = math.huge, Maximum = 0, Failures = 0 }
		self._profiles[commandName] = accum
	end
	accum.Executions += 1
	accum.TotalTime += duration
	accum.Minimum = math.min(accum.Minimum, duration)
	accum.Maximum = math.max(accum.Maximum, duration)
	if not success then
		accum.Failures += 1
	end
end

function Debug:GetProfile(commandName: string): CommandProfile?
	local accum = self._profiles[commandName:lower()] or self._profiles[commandName]
	if not accum then
		return nil
	end
	return {
		Command = commandName,
		Executions = accum.Executions,
		Average = accum.TotalTime / accum.Executions,
		Minimum = accum.Minimum,
		Maximum = accum.Maximum,
		Failures = accum.Failures,
	}
end

function Debug:GetAllProfiles(): { CommandProfile }
	local list = {}
	for name, accum in pairs(self._profiles) do
		table.insert(list, {
			Command = name,
			Executions = accum.Executions,
			Average = accum.TotalTime / accum.Executions,
			Minimum = accum.Minimum,
			Maximum = accum.Maximum,
			Failures = accum.Failures,
		})
	end
	table.sort(list, function(a, b)
		return a.Average > b.Average
	end)
	return list
end

function Debug:GetSlow(thresholdSeconds: number?): { CommandProfile }
	local threshold = thresholdSeconds or 0.01
	local list = {}
	for _, profile in ipairs(self:GetAllProfiles()) do
		if profile.Average >= threshold then
			table.insert(list, profile)
		end
	end
	return list
end

function Debug:LogError(routeError: any)
	table.insert(self._errors, {
		Error = routeError,
		Timestamp = os.time(),
	})
	while #self._errors > self._maxErrors do
		table.remove(self._errors, 1)
	end
end

function Debug:GetErrors(limit: number?): { any }
	local list = {}
	for i = #self._errors, 1, -1 do
		table.insert(list, self._errors[i])
		if limit and #list >= limit then
			break
		end
	end
	return list
end

function Debug:GetMemoryKB(): number
	return collectgarbage("count")
end

export type StatusReport = {
	Commands: number,
	Types: number,
	Guards: number,
	Permissions: number,
	Errors: number,
	UptimeSeconds: number,
	MemoryKB: number,
}

function Debug:Status(): StatusReport
	local deps = self._deps
	return {
		Commands = deps.Registry:Count(),
		Types = deps.Types:Count(),
		Guards = deps.Guards:Count(),
		Permissions = #deps.Permissions:GetKnownNodes(),
		Errors = #self._errors,
		UptimeSeconds = os.clock() - deps.StartedAt,
		MemoryKB = self:GetMemoryKB(),
	}
end

return Debug
