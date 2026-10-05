--!strict
-- Pool de instancias con token de propiedad. El llamante recibe un token junto al
-- objeto y debe devolverlo al liberar; así una referencia retrasada (por ejemplo un
-- impacto pendiente) no puede devolver al pool un objeto que ya fue reciclado.
local Pool = {}
Pool.__index = Pool

export type Pooled = {
	Get: (self: Pool, transform: (Instance) -> ()) -> (Instance, any),
	Release: (self: Pool, instance: Instance, lease: any) -> boolean,
	Count: (self: Pool) -> number,
	Destroy: (self: Pool) -> (),
}

function Pool.new(template: Instance, prewarm: number?): Pool
	local self = setmetatable({
		_template = template,
		_available = {},
		_leases = {},
		_created = 0,
	}, Pool)

	for _ = 1, prewarm or 0 do
		local instance = template:Clone()
		instance.Parent = nil
		table.insert(self._available, instance)
		self._created += 1
	end

	return self
end

function Pool:Get(apply: (Instance) -> ()): (Instance, any)
	local instance = table.remove(self._available)
	if not instance then
		instance = self._template:Clone()
		self._created += 1
	end
	local lease = {}
	self._leases[instance] = lease
	apply(instance)
	return instance, lease
end

function Pool:Release(instance: Instance, lease: any): boolean
	if lease == nil or self._leases[instance] ~= lease then
		return false
	end
	self._leases[instance] = nil
	instance.Parent = nil
	table.insert(self._available, instance)
	return true
end

function Pool:Count(): number
	return #self._available
end

function Pool:Destroy()
	for _, instance in self._available do
		instance:Destroy()
	end
	table.clear(self._available)
	table.clear(self._leases)
end

return Pool
