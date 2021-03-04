local class = require "util.30log"

local Face = class("Face", { })

function Face:init(key, path)
	self.key = key
	self.path = path or {}
end

function Face:__tostring()
	return string.format("Face #%d", self.key)
end

function Face:fullDebug(name)
	name = name or "Face"
	local path = {}
	for _, edge in ipairs(self.path) do
		table.insert(path, tostring(edge))
	end
	return string.format("%s f%d : { %s }", name, self.key, table.concat(path, " -> "))
end

function Face:getPathVertices()
	local path = self.path
	local vertices = {}
	if #path == 0 then return vertices end
	assert(#path > 1)
	local follow
			
	if self.path[1].tail == self.path[2].head then
		follow = "tail"
		table.insert(vertices, self.path[1].head)
	elseif self.path[1].head == self.path[2].tail then
		follow = "head"
		table.insert(vertices, self.path[1].tail)
	else
		assert(false)
	end
	
	for j, edge in ipairs(self.path) do
		table.insert(vertices, edge[follow])
	end
	
	return vertices
end

return Face