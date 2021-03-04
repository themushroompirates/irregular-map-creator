local geometry2d = {}

local min, max, sqrt, abs, atan2 = math.min, math.max, math.sqrt, math.abs, math.atan2
local TWO_PI = math.pi * 2

local function segment_bounds(x1, y1, x2, y2)
	local xMin, yMin = min(x1, x2), min(y1, y2)
	local xMax, yMax = x1+x2-xMin, y1+y2-yMin
	return xMin, yMin, xMax, yMax
end

local function point_vs_segment(x, y, x1, y1, x2, y2, tolerance)
	local xMin, yMin, xMax, yMax = segment_bounds(x1, y1, x2, y2)
	if x < xMin - tolerance or y < yMin - tolerance then return false end
	if x > xMax + tolerance or y > yMax + tolerance then return false end
	
	local dx, dy = x2 - x1, y2 - y1
	local length = sqrt(dx*dx+dy*dy)
	
	-- We shouldn't allow edges with nonzero lengths
	assert(length > 0)
	
	-- Get the perpendicular normal vector to the edge
	dx, dy = -dy / length, dx / length
	
	-- Dot that with the vector from the head to the coords provided
	local dot = (x - x1)*dx + (y-y1)*dy
	
	if abs(dot) > tolerance then return false end
	
	local t = max(0, min(1, ((x-x1)*(x2-x1)+(y-y1)*(y2-y1))/(length*length)))
	
	return true, t
end

local function segment_vs_segment(x1, y1, x2, y2, x3, y3, x4, y4, tolerance)
	local xMinA, yMinA, xMaxA, yMaxA = segment_bounds(x1, y1, x2, y2)
	local xMinB, yMinB, xMaxB, yMaxB = segment_bounds(x3, y3, x4, y4)
	
	--if xMaxA < xMinB - tolerance or yMaxA < yMinB - tolerance then return false end
	--if xMinA > xMaxB + tolerance or yMinA > yMaxB + tolerance then return false end
	
	local dxA, dyA = x2-x1, y2-y1
	local dxB, dyB = x4-x3, y4-y3
	
	local det = dxB*dyA-dyB*dxA
	
	if det == 0 then
		-- Segments are parallel
		return false
	end

    local tA =  (dxA * (y3 - y1) + dyA * (x1 - x3)) / det
    local tB = -(dxB * (y1 - y3) + dyB * (x3 - x1)) / det
	
	if tA >= 0 and tA <= 1 and tB >= 0 and tB <= 1 then
		return true, tA, tB
	end
	
	return false
end

local function angle(x1, y1, x2, y2, x3, y3)
	x1, y1 = x1 - x2, y1 - y2
	x3, y3 = x3 - x2, y3 - y2
	local dot = x1*x3 + y1*y3
	local det = x1*y3 - y1*x3
	local result = atan2(det, dot)
	if result < 0 then
		return result + TWO_PI
	else
		return result
	end
end

return {
	segment_bounds = segment_bounds,
	point_vs_segment = point_vs_segment,
	segment_vs_segment = segment_vs_segment,
	angle = angle
}