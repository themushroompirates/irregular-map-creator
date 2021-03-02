local class = require "util.30log"

local MAX_SANITY = 999

local Graph = class("Graph", {
	vertices = {},
	edges = {},
	faces = {},
	
	-- Hit testing distance
	vertex_tolerance = 5,
	edge_tolerance = 3
})

local Vertex = class("Vertex", {})

function Vertex:init(x, y, key)
	self.x = x
	self.y = y
	self.key = key
end

function Vertex:getCoordinates()
	return self.x, self.y
end

function Vertex:__tostring()
	return string.format("Vertex(%d)", self.key)
end

local Edge = class("Edge", {})

function Edge:init(head, tail, key)
	assert(head ~= tail)
	self.head = head
	self.tail = tail
	self.key = key
end

function Edge:getCoordinates()
	local x1, y1 = self.head:getCoordinates()
	local x2, y2 = self.tail:getCoordinates()
	return x1, y1, x2, y2
end

function Edge:hitTest(x, y, tolerance)
	local x1, y1, x2, y2 = self:getCoordinates()
	local xMin, yMin = math.min(x1, x2), math.min(y1, y2)
	local xMax, yMax = x1+x2-xMin, y1+y2-yMin
	if x < xMin - tolerance or y < yMin - tolerance then return false end
	if x > xMax + tolerance or y > yMax + tolerance then return false end
	
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx*dx+dy*dy)
	
	-- We shouldn't allow edges with nonzero lengths
	assert(length > 0)
	
	-- Get the perpendicular normal vector to the edge
	dx, dy = -dy / length, dx / length
	
	-- Dot that with the vector from the head to the coords provided
	local dot = (x - x1)*dx + (y-y1)*dy
	
	if math.abs(dot) > tolerance then return false end
	
	local t = math.max(0, math.min(1, ((x-x1)*(x2-x1)+(y-y1)*(y2-y1))/(length*length)))
	
	return true, t
end

function Edge:__tostring()
	return string.format("Edge(%d-%d)", self.head.key, self.tail.key)
end

--

local function add_link(links, head, tail)
	if links[head] == nil then
		links[head] = { tail = true }
	else
		assert(not links[head][tail], string.format("An edge between %d and %d has already been added", head, tail))
		links[head][tail] = true
	end
end

function Graph:init(vertices, edges)
	if vertices == nil then return end
	
	for i, vertex in ipairs(vertices) do
		self.vertices[i] = Vertex(vertex.x, vertex.y, i)
	end
	local linked = {}
	
	for i, edge in ipairs(edges) do
		--local head, tail = unpack(edge)
		local head, tail = edge.head, edge.tail
		
		add_link(linked, head, tail)
		add_link(linked, tail, head)
		
		local edge_key = 2*i-1
		local twin_key = edge_key + 1
		
		self.edges[edge_key] = Edge(self.vertices[head], self.vertices[tail], edge_key)
		self.edges[twin_key] = Edge(self.vertices[tail], self.vertices[head], twin_key)
	end
end

local function angle(x1, y1, x2, y2, x3, y3)
	x1, y1 = x1 - x2, y1 - y2
	x3, y3 = x3 - x2, y3 - y2
	local dot = x1*x3 + y1*y3
	local det = x1*y3 - y1*x3
	local result = math.atan2(det, dot)
	if result < 0 then
		return math.deg(result) + 360
	else
		return math.deg(result)
	end
end

function Graph:angleVertices(A, B, C)
	return angle(
		A.x, A.y,
		B.x, B.y,
		C.x, C.y
	)
end

function Graph:findNextEdge(edge1)
	local best_angle, best_edge = -math.huge, nil
	
	for i, edge2 in ipairs(self.edges) do
		if edge2.head == edge1.tail then
			local tmp_angle = self:angleVertices(edge1.head, edge1.tail, edge2.tail)
			if math.abs(tmp_angle) > best_angle then
				best_angle = math.abs(tmp_angle)
				best_edge = edge2
			end
		end
	end
	
	return best_edge
end

function Graph:followEdges()
	local visited = {}
	
	local edges = self.edges
	
	for i, edge in ipairs(edges) do
		if not visited[i] then
			visited[i] = true
			
			local next_edge = self:findNextEdge(edge)
			if next_edge == nil then
				return
			end
			local next_key = next_edge.key
			edge.next = next_edge
			
			local current_key = next_key
			for sanity = 1, MAX_SANITY do
				visited[current_key] = true
				next_edge = self:findNextEdge(edges[current_key])
				if next_edge == nil then
					return
				end
				next_key = next_edge.key
				edges[current_key].next = next_edge
				current_key = next_key
				if current_key == i then
					break
				end
			end
		end
	end
end

function Graph:createFaces()
	local visited = {}
	
	self.faces = {}
	
	local edges = self.edges
	local faces = self.faces
	local vertices = self.vertices
	
	for i, edge in ipairs(edges) do
		if not visited[i] then
			visited[i] = true
			local signedArea = 0
			local path = {}
			local current_edge = edge
			repeat
				visited[current_edge.key] = true
				local x1, y1 = current_edge.head:getCoordinates()
				local x2, y2 = current_edge.tail:getCoordinates()
				table.insert(path, current_edge)
				signedArea = signedArea + (x1*y2 - x2*y1)
				current_edge = current_edge.next
			until current_edge == edge
			
			if signedArea > 0 then
				local face = { path = path, key = 1 + #faces }
				table.insert(faces, face)
				for _, tmp_edge in ipairs(path) do
					tmp_edge.face = face
				end
			end
		end
	end
	
end

function Graph:recalculate()
	self:followEdges()
	self:createFaces()
end

function Graph:checkPointVertices(x, y, tolerance)
	tolerance = tolerance or self.vertex_tolerance
	-- Quick and dirty
	for i, vertex in ipairs(self.vertices) do
		local dx, dy = vertex:getCoordinates()
		dx, dy = math.abs(dx-x), math.abs(dy-y)
		if dx < tolerance and dy < tolerance and dx*dx+dy*dy<tolerance*tolerance then
			return vertex
		end
	end
end

function Graph:checkPointEdges(x, y, tolerance)
	tolerance = tolerance or self.edge_tolerance
	-- Quick and dirty
	-- Only check odd edges (no need to check the twins)
	local edges = self.edges
	for i = 1, #edges, 2 do
		local hit, t = edges[i]:hitTest(x, y, tolerance)
		if hit then
			return edges[i], t
		end
	end
end

function Graph:checkPointFaces(x, y)
end

function Graph:checkPoint(x, y)
	local vertex = self:checkPointVertices(x, y)
	if vertex then
		return "vertex", vertex
	end
	local edge, t = self:checkPointEdges(x, y)
	if edge then
		return "edge", edge, t
	end
end

function Graph:checkSegment(x1, y1, x2, y2)

end

return Graph