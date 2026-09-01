--!strict
-- Route.Audit
-- Structured audit log for command executions and admin actions
-- (permission/role/config changes, etc.). Kept as an in-memory ring
-- buffer sized by Config: Audit.MaxEntries; wire a sink (Core does this
-- for Discord) to forward records elsewhere without Audit needing to
-- know Discord exists.

export type AuditRecord = {
	Action: string,
	Actor: Player?,
	UserId: number?,
	Username: string?,
	Command: string?,
	Arguments: { [string]: any }?,
	Success: boolean?,
	Error: string?,
	ExecutionTime: number?,
	Permission: string?,
	Metadata: { [string]: any }?,
	Timestamp: number,
}

local Audit = {}
Audit.__index = Audit

function Audit.new(config: any): any
	local self = setmetatable({
		_config = config,
		_records = {} :: { AuditRecord },
		_sinks = {} :: { (AuditRecord) -> () },
	}, Audit)
	return self
end

function Audit:AddSink(fn: (AuditRecord) -> ())
	table.insert(self._sinks, fn)
end

function Audit:Log(input: { [string]: any })
	local enabled = true
	local ok, value = pcall(function()
		return self._config:Get("Audit.Enabled")
	end)
	if ok and value == false then
		enabled = false
	end
	if not enabled then
		return
	end

	local actor = input.Actor :: Player?
	local record: AuditRecord = {
		Action = input.Action or "Unknown",
		Actor = actor,
		UserId = if actor then actor.UserId else input.UserId,
		Username = if actor then actor.Name else input.Username,
		Command = input.Command,
		Arguments = input.Arguments,
		Success = input.Success,
		Error = input.Error,
		ExecutionTime = input.ExecutionTime,
		Permission = input.Permission,
		Metadata = input.Metadata,
		Timestamp = os.time(),
	}

	table.insert(self._records, record)

	local maxEntries = 1000
	local okMax, value2 = pcall(function()
		return self._config:Get("Audit.MaxEntries")
	end)
	if okMax and type(value2) == "number" then
		maxEntries = value2
	end
	while #self._records > maxEntries do
		table.remove(self._records, 1)
	end

	for _, sink in ipairs(self._sinks) do
		task.spawn(sink, record)
	end
end

export type HistoryFilter = {
	UserId: number?,
	Command: string?,
	Action: string?,
	Limit: number?,
}

function Audit:GetHistory(filter: HistoryFilter?): { AuditRecord }
	local f: HistoryFilter = filter or {}
	local results = {}
	for i = #self._records, 1, -1 do
		local record = self._records[i]
		if (not f.UserId or record.UserId == f.UserId)
			and (not f.Command or record.Command == f.Command)
			and (not f.Action or record.Action == f.Action) then
			table.insert(results, record)
			if f.Limit and #results >= f.Limit then
				break
			end
		end
	end
	return results
end

function Audit:Count(): number
	return #self._records
end

return Audit
