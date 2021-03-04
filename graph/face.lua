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

local function is_left(x0, y0, x1, y1, x2, y2)
	return (x1-x0)*(y2-y0)-(x2-x0)*(y1-y0)
end

function Face:containsPoint(x, y)
	local wn = 0
	
	local vertices = self:getPathVertices()
	
	for i = 1, #vertices-1 do
		local x1, y1, x2, y2 = vertices[i].x, vertices[i].y, vertices[i+1].x, vertices[i+1].y

		if y1 <= y then
			if y2 > y then
				if is_left(x1, y1, x2, y2, x, y) > 0 then
					wn = wn + 1
				end
			end
		else
			if y2 <= y then
				if is_left(x1, y1, x2, y2, x, y) < 0 then
					wn = wn - 1
				end
			end
		end
	end
	
	--[[
	for i, edge in ipairs(self.path) do
		local x1, y1, x2, y2 = edge:getCoordinates()

		if y1 <= y then
			if y2 > y then
				if is_left(x1, y1, x2, y2, x, y) > 0 then
					wn = wn + 1
				end
			end
		else
			if y2 <= y then
				if is_left(x1, y1, x2, y2, x, y) < 0 then
					wn = wn + 1
				end
			end
		end
	end
	--]]
	
	return wn ~= 0
end

return Face