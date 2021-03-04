local class = require "util.30log"

local abs = math.abs

local AABB = class("AABB", {
	centreX = nil,
	centreY = nil,
	halfW = nil,
	halfH = nil
})

function AABB:init(centreX, centreY, halfW, halfH)
	self.centreX = centreX
	self.centreY = centreY
	self.halfW = halfW
	self.halfH = halfH
end

function AABB.fromCorners(x1, y1, x2, y2)
	return AABB(
		(x1+x2)/2,
		(y1+y2)/2,
		abs(x2-x1)/2,
		abs(y2-y1)/2
	)
end

function AABB.union(one, two)
	assert(false, "Not implemented yet")
end

function AABB.intersection(one, two)
	assert(false, "Not implemented yet")
end

function AABB:__tostring()
	local x1, y1, x2, y2 = self:getCorners()
	return string.format("([%d,%d]-[%d,%d])", x1, y1, x2, y2)
end

function AABB:getCorners()
	return self.centreX - self.halfW, self.centreY - self.halfH, self.centreX + self.halfW, self.centreY + self.halfH
end

function AABB:containsPoint(x, y)
	return abs(x - self.centreX) <= self.halfW and abs(y - self.centreY) <= self.halfH
end

function AABB:intersectsAABB(other)
	return abs(other.centreX - self.centreX) <= (self.halfW + other.halfW) and abs(other.centreY - self.centreY) <= (self.halfH + other.halfH)
end

function AABB:containsAABB(other)
	local x1, y1, x2, y2 = other:getCorners()
	
	return self:containsPoint(x1, y1) and self:containsPoint(x2, y1) and self:containsPoint(x2, y2) and self:containsPoint(x1, y2)
end

function AABB:getQuarters()
	local x1, y1, x2, y2 = self:getCorners()
	local xC, yC = self.centreX, self.centreY
	local qw, qh = self.halfW/2, self.halfH/2
	
	--local NW, NE, SE, SW = AABB.fromCorners(x1, y1, xC, yC), AABB.fromCorners(xC, y1, x2, yC), AABB.fromCorners(xC, yC, x2, y2), AABB.fromCorners(x1, yC, xC, y2)
	local NW, NE, SE, SW = AABB(xC-qw,yC-qh,qw,qh), AABB(xC+qw,yC-qh,qw,qh), AABB(xC+qw,yC+qh,qw,qh), AABB(xC-qw,yC+qh,qw,qh)
	
	--print("Splitting AABB " .. tostring(self))
	--print(string.format("> NW = %s\n> NE = %s\n> SE = %s\n> SW = %s", NW, NE, SE, SW))
	
	return NW, NE, SE, SW
	
end

return AABB