--!strict
--- Route.Signal
--- A minimal, dependency-free event emitter - the same shape as a
--- BindableEvent (`:Connect`, `:Once`, `:Fire`), without the Instance
--- overhead of actually creating one. Powers `Route.On`/`Route.Once` (see
--- Core/init.lua) - Route's own discord.js-style event hooks - but has no
--- dependency on Route itself, so it's just as usable for a game's own
--- one-off signals.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Handler = { fn: (...any) -> () }

export type Signal = typeof(setmetatable(
	{} :: { _handlers: { Handler } },
	{} :: { __index: typeof(Signal) }
))

--- Creates a new, empty Signal with no subscribers yet.
function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

--- Subscribes `fn` to every future `:Fire(...)` call on this Signal, in
--- the order it fires. Returns a Connection - call `:Disconnect()` on it
--- to unsubscribe `fn` later.
function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local handler: Handler = { fn = fn }
	table.insert(self._handlers, handler)

	local connection = {} :: Connection
	connection.Connected = true
	connection.Disconnect = function(_self: Connection)
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

--- Subscribes `fn` for exactly the next `:Fire(...)` call, then
--- disconnects itself automatically - never runs a second time.
function Signal.Once(self: Signal, fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

--- Calls every currently-connected handler with the given arguments.
--- Each handler runs in its own thread (`task.spawn`), so one handler
--- throwing or yielding never breaks Route's own pipeline or blocks
--- another handler - the same isolation `BindableEvent:Fire()` gives you.
--- Snapshots the handler list first, so a handler that connects or
--- disconnects another handler mid-fire can't skip or double-call one
--- that was already in this particular Fire's list.
function Signal.Fire(self: Signal, ...: any)
	local handlers = table.clone(self._handlers)
	for _, handler in ipairs(handlers) do
		task.spawn(handler.fn, ...)
	end
end

--- Disconnects every current subscriber at once.
function Signal.DisconnectAll(self: Signal)
	table.clear(self._handlers)
end

return Signal
