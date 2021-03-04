local class = require "util.30log"

local geometry2d = require "util.geometry2d"
local point_vs_segment = geometry2d.point_vs_segment
local segment_vs_segment = geometry2d.segment_vs_segment

local Edge = class("Edge", {})

function Edge:init(head, tail, key)
	assert(head ~= tail)
	self.head = head
	self.tail = tail
	self.key = key
end

function Edge:__tostring()
	return string.format("Edge #%d [%d-%d]", self.key, self.head.key, self.tail.key)
end

function Edge:fullDebug(name)
	name = name or "Edge"
	local face_key = "0"
	if self.face then face_key = self.face.key end
	return string.format("%s e%d : head = v%d, tail = v%d, face = f%d, next = e%d, prev = e%d", name, self.key, self.head.key, self.tail.key, face_key, self.next.key, self.prev.key)
end

function Edge:getCoordinates()
	local x1, y1 = self.head:getCoordinates()
	local x2, y2 = self.tail:getCoordinates()
	return x1, y1, x2, y2
end

function Edge:getCoordinatesOfPoint(t)
	assert(t > 0 and t < 1)
	local x1, y1, x2, y2 = self:getCoordinates()
	return x1 + (x2-x1)*t, y1 + (y2-y1)*t
end

function Edge:hitTest(x, y, tolerance)
	tolerance = tolerance or 0
	
	local x1, y1, x2, y2 = self:getCoordinates()
	
	return point_vs_segment(x, y, x1, y1, x2, y2, tolerance)
end

function Edge:checkSegment(x1, y1, x2, y2, tolerance)
	tolerance = tolerance or 0
	
	local x3, y3, x4, y4 = self:getCoordinates()
	
	local collide, tEdge, tSegment = segment_vs_segment(x1, y1, x2, y2, x3, y3, x4, y4, tolerance)
	
	if not collide or (tEdge <= 0 or tEdge >= 1) then
		return false
	end
	
	return collide, tEdge, tSegment
end

return Edge