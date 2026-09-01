--!strict
-- Route.History
-- Lightweight ring buffer of "who ran what, when, did it succeed" for
-- `/route history`. Deliberately thin - Route.Audit is the place for
-- full argument-level compliance logging; History exists for quick
-- in-game recall and intentionally does not retain raw arguments.

export type HistoryEntry = {
	UserId: number,
	Username: string,
	Command: string,
	Success: boolean,
	Timestamp: number,
}

local History = {}
History.__index = History

function History.new(config: any): any
	local self = setmetatable({
		_config = config,
		_entries = {} :: { HistoryEntry },
	}, History)
	return self
end

function History:Record(player: Player, commandName: string, success: boolean)
	table.insert(self._entries, {
		UserId = player.UserId,
		Username = player.Name,
		Command = commandName,
		Success = success,
		Timestamp = os.time(),
	})

	local maxEntries = 500
	local ok, value = pcall(function()
		return self._config:Get("History.MaxEntries")
	end)
	if ok and type(value) == "number" then
		maxEntries = value
	end
	while #self._entries > maxEntries do
		table.remove(self._entries, 1)
	end
end

export type HistoryQuery = {
	UserId: number?,
	Command: string?,
	Limit: number?,
}

function History:Get(query: HistoryQuery?): { HistoryEntry }
	local q: HistoryQuery = query or {}
	local results = {}
	for i = #self._entries, 1, -1 do
		local entry = self._entries[i]
		if (not q.UserId or entry.UserId == q.UserId)
			and (not q.Command or entry.Command:lower() == q.Command:lower()) then
			table.insert(results, entry)
			if q.Limit and #results >= q.Limit then
				break
			end
		end
	end
	return results
end

return History
