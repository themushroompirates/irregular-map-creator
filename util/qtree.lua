local class = require "util.30log"

local AABB = require "util.aabb2d"

local MAX_OBJECTS_PER_NODE = 8

local Node = class("Node", {
	bounds = nil,
	children = nil,
	objects = {}
})

function Node:init(bounds)
	self.bounds = bounds
end

function Node:getDepth()
	local depth = 0
	
	if self.children then
		for i, child in ipairs(self.children) do
			depth = math.max(depth, child:getDepth())
		end
	end
	
	return depth + 1
end

function Node:insert(object)
	-- We can only insert here if the bounds fit inside our bounds
	if not self.bounds:containsAABB(object.bounds) then
		return false
	end
	
	-- We only need to bother checking if it fits into one of the children if the height and width are small enough
	if 2*object.bounds.halfW < self.bounds.halfW and 2*object.bounds.halfH < self.bounds.halfH then
	
		if self.children == nil then
			-- This node has not been split yet
			if #self.objects < MAX_OBJECTS_PER_NODE then
				-- Don't bother splitting at this point...
				table.insert(self.objects, object)
				return self
			end
			-- We should try and split this node
			self:split()
		end
		
		-- At this point, this node must be split, and the object has not been inserted
		
		-- Check all 4 children
		for i, child in ipairs(self.children) do
			local ret = child:insert(object)
			if ret then
				return ret
			end
		end
	end
		
	-- If we got here, it doesn't fit into any of the children, so we can add it to the objects list
	table.insert(self.objects, object)
	return self
end

function Node:split()
	assert(self.children == nil, "Node already split")
	local NW, NE, SE, SW = self.bounds:getQuarters()
	self.children = {
		Node(NW), Node(NE), Node(SE), Node(SW)
	}
	for i = #self.objects, 1, -1 do
		for j = 1, 4 do
			if self.children[j]:insert(self.objects[i]) then
				-- Child has eaten the object; we can remove it
				table.remove(self.objects, i)
				-- Skip other children too
				break
			end
		end
	end
end

function Node:grow(x, y)
	local x0, y0 = self.bounds.centreX, self.bounds.centreY
	local hw, hh = self.bounds.halfW, self.bounds.halfH

	local child_index = 0
	if x < self.bounds.centreX then
		x0 = x0 - hw
		if y < self.bounds.centreY then
			y0 = y0 - hh
			child_index = 1
		else
			y0 = y0 + hh
			child_index = 4
		end
	else
		x0 = x0 + hw
		if y < self.bounds.centreY then
			y0 = y0 - hh
			child_index = 2
		else
			y0 = y0 + hh
			child_index = 4
		end
	end
	
	local parent = Node(AABB(x0, y0, hw*2, hh*2))
	
	--print("Growing " .. tostring(self.bounds) .. " with child index " .. child_index)
	--print("> " .. tostring(parent.bounds))
	
	parent:split()
	parent.children[child_index] = self
	
	if parent.bounds:containsPoint(x, y) then
		return parent
	else
		return parent:grow(x, y)
	end
end

function Node:queryPoint(x, y, results)
	if not self.bounds:containsPoint(x, y) then return results end
	
	-- Check our own objects
	for i, object in ipairs(self.objects) do
		if object.bounds:containsPoint(x, y) then
			table.insert(results, object.data)
		end
	end
	
	-- Check our children
	if self.children == nil then return results end
	
	for i, child in ipairs(self.children) do
		child:queryPoint(x, y, results)
	end
	
	return results
end

function Node:queryPointEx(x, y, results, callback)
	if not self.bounds:containsPoint(x, y) then return results end
	
	-- Check our own objects
	for i, object in ipairs(self.objects) do
		if object.bounds:containsPoint(x, y) then
			local valid, stop = callback(object.data)
			if valid then
				table.insert(results, object.data)
			end
			if stop == true then
				return results, true
			end
		end
	end
	
	-- Check our children
	if self.children == nil then return results end
	
	for i, child in ipairs(self.children) do
		local _, stop = child:queryPointEx(x, y, results, callback)
		if stop == true then return results, true end
	end
	
	return results
end

function Node:queryRect(bounds, results, callback)
	if not self.bounds:intersectsAABB(bounds) then return results end
	
	-- Check our own objects
	for i, object in ipairs(self.objects) do
		if object.bounds:intersectsAABB(bounds) then
			if callback == nil or callback(object.data) ~= false then
				table.insert(results, object.data)
			end
		end
	end
	
	-- Check our children
	if self.children == nil then return results end
	
	for i, child in ipairs(self.children) do
		child:queryRect(bounds, results, callback)
	end
	
	return results
end

function Node:debugDraw(transform, dataRenderer, depth, maxDepth)

	--love.graphics.setColor(0, 1-depth/maxDepth, 1)

	local x1, y1, x2, y2 = self.bounds:getCorners()
	x1, y1 = transform:transformPoint(x1, y1)
	x2, y2 = transform:transformPoint(x2, y2)
	love.graphics.rectangle("line", x1+depth, y1+depth, x2-x1-2*depth+1, y2-y1-2*depth+1)
	
	for i, object in ipairs(self.objects) do
		x1, y1, x2, y2 = object.bounds:getCorners()
		x1, y1 = transform:transformPoint(x1, y1)
		x2, y2 = transform:transformPoint(x2, y2)
		love.graphics.rectangle("line", x1, y1, x2-x1+1, y2-y1+1)
		love.graphics.line(x1, y1, x2, y2)
		love.graphics.line(x1, y2, x2, y1)
	end
	
	if self.children == nil then return end
	
	for i, child in ipairs(self.children) do
		child:debugDraw(transform, dataRenderer, depth + 3, maxDepth)
	end
end

function Node:debugText(indent, dataRenderer)
	local indentString = string.rep(" ", indent)
	
	print(string.format("%s*%s - %d objects, %s", indentString, self.bounds, #self.objects, (self.children and "SPLIT") or "NOT SPLIT"))
	if #self.objects > 0 then
		for i, object in ipairs(self.objects) do
			print(string.format("%s  ->Object[%d] : %s : %s", indentString, i, object.bounds, dataRenderer(object.data)))
		end
	end
	if self.children then
		for i, child in ipairs(self.children) do
			child:debugText(indent + 1, dataRenderer)
		end
	end
end

local QuadTree = class("QuadTree", {
	root = nil
})

function QuadTree:init(x1, y1, x2, y2)
	self.root = Node(AABB.fromCorners(x1, y1, x2, y2))
end

function QuadTree:insert(data, x1, y1, x2, y2)
	local bounds
	if y1 == nil then
		if class.isInstance(x1) then
			assert(x1:instanceOf(AABB))
			bounds = x1
		else
			x1, y1, x2, y2 = unpack(x1)
			bounds = AABB.fromCorners(x1, y1, x2, y2)
		end
	else
		bounds = AABB.fromCorners(x1, y1, x2, y2)
	end
	
	if not self.root.bounds:containsAABB(bounds) then
		local x1, y1, x2, y2 = bounds:getCorners()
		if not self.root.bounds:containsPoint(x1, y1) then
			self.root = self.root:grow(x1, y1)
		end
		if not self.root.bounds:containsPoint(x2, y2) then
			self.root = self.root:grow(x2, y2)
		end
	end
	
	return self.root:insert({data=data, bounds=bounds})
end

function QuadTree:queryPoint(x, y, results, callback)
	results = results or {}
	if callback then
		return self.root:queryPointEx(x, y, results, callback)
	else
		return self.root:queryPoint(x, y, results)
	end
end

function QuadTree:queryRect(x1, y1, x2, y2, results, callback)
	results = results or {}
	return self.root:queryRect(AABB.fromCorners(x1, y1, x2, y2), results, callback)
end

function QuadTree:debugDraw(transform, dataRenderer)
	local maxDepth = self.root:getDepth()
	self.root:debugDraw(transform, dataRenderer, 0, maxDepth)
end

function QuadTree:debugText(indent, dataRenderer)
	dataRenderer = dataRenderer or tostring
	self.root:debugText(0, dataRenderer)
end

return QuadTree