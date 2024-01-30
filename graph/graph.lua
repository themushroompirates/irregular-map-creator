local class = require "util.30log"
local serpent = require "util.serpent"

local geometry2d = require "util.geometry2d"
local angle = geometry2d.angle

local QuadTree = require "util.qtree"

local Vertex = require "graph.vertex"
local Edge = require "graph.edge"
local Face = require "graph.face"

local MAX_SANITY = 999

local Graph = class("Graph", {
	vertices = {},
	edges = {},
	faces = {},
	
	edgeQ = nil,
	vertexQ = nil,
	faceQ = nil,
	
	-- Hit testing distance
	vertex_tolerance = 12,
	edge_tolerance = 3
})

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
		local head, tail = unpack(edge)
		
		add_link(linked, head, tail)
		add_link(linked, tail, head)
		
		local edge_key = 2*i-1
		local twin_key = edge_key + 1
		
		self.edges[edge_key] = Edge(self.vertices[head], self.vertices[tail], edge_key)
		self.edges[twin_key] = Edge(self.vertices[tail], self.vertices[head], twin_key)
	end
	
	self:recalculate()
	self:initEdgeQ()
	self:initVertexQ()
	self:initFaceQ()
end

function Graph:getExtent()
	-- Get min and max of all vertices
	local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge
	for i, vertex in ipairs(self.vertices) do
		local x, y = vertex:getCoordinates()
		xMin = math.min(x, xMin)
		yMin = math.min(y, yMin)
		xMax = math.max(x, xMax)
		yMax = math.max(y, yMax)
	end
	
	return xMin, xMax, yMin, yMax
end

function Graph:initEdgeQ()
	-- Get min and max of all vertices
	local xMin, xMax, yMin, yMax = self:getExtent()

	self.edgeQ = QuadTree(xMin, yMin, xMax, yMax)
	
	for i = 1, #self.edges, 2 do
		self:addEdgeToQ(self.edges[i])
	end
end

function Graph:addEdgeToQ(edge)
	local x1, y1, x2, y2 = edge:getCoordinates()
	self.edgeQ:insert(edge, x1, y1, x2, y2)
end

function Graph:initVertexQ()
	-- Get min and max of all vertices
	local xMin, xMax, yMin, yMax = self:getExtent()

	self.vertexQ = QuadTree(xMin, yMin, xMax, yMax)
	
	for i, edge in ipairs(self.edges) do
		self:addToVertexQ(edge)
	end
end

function Graph:addToVertexQ(vertex)
	local x, y = vertex:getCoordinates()
	
	--print(string.format("Adding vertex to Q, x=%d, y=%d, tolerance = %.1f", x, y, self.vertex_tolerance))
	
	self.vertexQ:insert(vertex, x - self.vertex_tolerance, y - self.vertex_tolerance, x + self.vertex_tolerance, y + self.vertex_tolerance)
end

function Graph:initFaceQ()
	-- Get min and max of all vertices
	local xMin, xMax, yMin, yMax = self:getExtent()

	self.faceQ = QuadTree(xMin, yMin, xMax, yMax)
	
	for i, face in ipairs(self.faces) do
		self:addToFaceQ(face)
	end
end

function Graph:addToFaceQ(face)
	local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge
	for i, edge in pairs(face.path) do
		local x, y = edge.head:getCoordinates()
		xMin = math.min(x, xMin)
		yMin = math.min(y, yMin)
		xMax = math.max(x, xMax)
		yMax = math.max(y, yMax)
	end
	self.faceQ:insert(face, xMin, yMin, xMax, yMax)
end

function Graph:serialize()
	local points = {}
	local segs = {}
	
	for i, vertex in ipairs(self.vertices) do
		table.insert(points, { x = vertex.x, y = vertex.y })
	end
	
	for i = 1, #self.edges, 2 do
		local edge = self.edges[i]
		table.insert(segs, { edge.head.key, edge.tail.key })
	end
	
	-- Just for kicks...
	return serpent.dump({vertices=points,edges=segs})
end

function Graph:unserialize(chonk)
	local ok, data = serpent.load(chonk)
	if ok then
		self:init(data.vertices, data.edges)
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

	local edges = self.edges

	-- Clear existing 'next' pointers
	for i, edge in ipairs(edges) do
		edge.next = nil
	end
	
	local visited = {}
	
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
	
	self:backlinkEdges()
end

function Graph:backlinkEdges()
	local edges = self.edges
	for i, edge in ipairs(edges) do
		local next_edge = edge.next
		assert(next_edge)
		next_edge.prev = edge
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
				local face = Face(1 + #faces, path)
				--local face = { path = path, key = 1 + #faces }
				table.insert(faces, face)
				for _, tmp_edge in ipairs(path) do
					tmp_edge.face = face
				end
			end
		end
	end
	
end

function Graph:findFaceNeighbours()
	for i, face in ipairs(self.faces) do
		local neighbourLUT = {}
		for j, edge in ipairs(self.edges) do
			local twin = self:getEdgeTwin(edge)
			
			if edge.face == face then
				if twin.face then
					neighbourLUT[twin.face] = true
				end
			elseif twin.face == face then
				if edge.face then
					neighbourLUT[edge.face] = true
				end
			end
		end
		local neighbours = {}
		for k, _ in pairs(neighbourLUT) do
			table.insert(neighbours, k)
		end
		face.neighbours = neighbours
	end
end

function Graph:debugEdges()
	print("---- EDGES ----")
	print("Edge\tPrev\tNext")
	print("----\t----\t----")
	for i, edge in ipairs(self.edges) do
		print(tostring(edge) .. "\t" .. tostring(edge.prev) .. "\t" .. tostring(edge.next))
	end
	print("---------------")
end

function Graph:debugFaces()
	print("----- Faces -----")
	for i, face in ipairs(self.faces) do
		local text = tostring(face)
		local path = {}
		if #face.path > 0 then
			assert(#face.path > 1)
			
			local follow
			
			if face.path[1].tail == face.path[2].head then
				follow = "tail"
				table.insert(path, string.format("v%d", face.path[1].head.key))
			elseif face.path[1].head == face.path[2].tail then
				follow = "head"
				table.insert(path, string.format("v%d", face.path[1].tail.key))
			else
				assert(false)
			end
			
			for j, edge in ipairs(face.path) do
				table.insert(path, string.format("v%d", edge[follow].key))
				
			end
		end
		print(tostring(face) .. ":\t" .. table.concat(path, " -> "))
	end
end

function Graph:debugPaths()
	print("----- Paths -----")
	local visited = {}
	for i, head in ipairs(self.edges) do
		if not visited[head] then
			
			local next_edge = head
			local path = {}
			
			table.insert(path, string.format("v%d", head.head.key))
				
			repeat
				visited[next_edge] = true
				table.insert(path, string.format("v%d", next_edge.tail.key))
				next_edge = next_edge.next
			until next_edge == nil or next_edge == head
			
			print(table.concat(path, " -> "))
		end
	end
end

function Graph:recalculate()
	self:followEdges()
	self:createFaces()
	self:findFaceNeighbours()
	
	--self:debugFaces()
	--self:debugPaths()
end

function Graph:addVertex(x, y)
	local key = 1 + #self.vertices
	
	self.vertices[key] = Vertex(x, y, key)
	
	self:addToVertexQ(self.vertices[key])
	
	return self.vertices[key]
end

function Graph:getEdgeTwin(edge)
	local index = edge.key
	
	--[[
	-- We want this to happen:
	if index % 2 == 1 then
		return self.edges[index + 1]
	else
		return self.edges[index - 1]
	end
	
	consider the quantity q = ( 2 * (index % 2) - 1 )
	(index % 2) == 1   =>   q =  1
	(index % 2) == 0   =>   q = -1
	
	--]]
	
	return self.edges[ index + 2 * (index % 2) - 1 ]
	
end

function Graph:addEdgeAndTwin(head, tail)
	local new_edge_index = 1 + #self.edges
	local new_twin_index = 2 + #self.edges
	
	local new_edge = Edge(head, tail, new_edge_index)
	local new_twin = Edge(tail, head, new_twin_index)
	
	self.edges[new_edge_index] = new_edge
	self.edges[new_twin_index] = new_twin
	
	-- Update qtree
	self:addEdgeToQ(new_edge)
	
	return new_edge, new_twin
end

function Graph:splitEdge(edge, t)
	local x, y = edge:getCoordinatesOfPoint(t)
	local twin = self:getEdgeTwin(edge)
	
	local new_vertex = self:addVertex(x, y)
	
	local new_edge, new_twin = self:addEdgeAndTwin(new_vertex, edge.tail)

	-- Set the faces
	new_edge.face = edge.face
	new_twin.face = twin.face
	
	-- Update the split edge to point to the new vertex
	edge.tail = new_vertex
	twin.head = new_vertex
	
	-- Update edge pointers
	-- WAS : (edge.prev) => (edge) => (edge.next)
	-- NOW : (edge.prev) => (edge) => (new)       => (edge.next)
	new_edge.next = edge.next
	new_edge.prev = edge
	
	edge.next.prev = new_edge
	edge.next = new_edge
	
	-- Update twin pointers
	-- WAS : (twin.prev) => (twin) => (twin.next)
	-- NOW : (twin.prev) => (new)  => (twin)      => (twin.next)
	twin.prev.next = new_twin
	new_twin.next = twin
	twin.next.prev = twin
	new_twin.prev = twin.prev
	twin.prev = new_twin
	
	-- Need to update the faces' paths
	if edge.face then
		local path = edge.face.path
		-- The new edge gets added AFTER the current edge
		for i = 1, #path do
			if path[i] == edge then
				table.insert(path, i+1, new_edge)
				break
			end
		end
	end
	if twin.face then
		--assert(twin.face ~= edge.face)
		local path = twin.face.path
		-- The new twin gets added BEFORE the current twin
		for i = 1, #path do
			if path[i] == twin then
				table.insert(path, i, new_twin)
				break
			end
		end
	end
	
	return new_vertex
end

function Graph:getEdgeForVertices(head, tail)
	local edges = self.edges
	for i, edge in ipairs(edges) do
		if edge.head == head and edge.tail == tail then
			return edge
		end
	end
end

function Graph:checkPointVertices(x, y, tolerance)
	tolerance = tolerance or self.vertex_tolerance
	
	local vertices = self.vertexQ:queryRect(x-tolerance, y-tolerance, x+tolerance, y+tolerance)
	
	self.vertices_queried = 0
	self.vertices_considered = #vertices
	
	for i, vertex in ipairs(vertices) do
		self.vertices_queried = self.vertices_queried + 1
		
		local dx, dy = vertex:getCoordinates()
		dx, dy = math.abs(dx-x), math.abs(dy-y)
		if dx < tolerance and dy < tolerance and dx*dx+dy*dy<tolerance*tolerance then
			return vertex
		end
	end
end

function Graph:checkPointEdges(x, y, tolerance)
	tolerance = tolerance or self.edge_tolerance
	
	local edges = self.edgeQ:queryRect(x-tolerance, y-tolerance, x+tolerance, y+tolerance)
	
	self.edges_queried = 0
	self.edges_considered = #edges
	
	for i, edge in ipairs(edges) do
		self.edges_queried = self.edges_queried + 1
		local hit, t = edge:hitTest(x, y, tolerance)
		if hit then
			return edge, t
		end
	end
end

function Graph:checkPointFaces(x, y)
	local faces = self.faceQ:queryPoint(x, y)
	
	self.faces_queried = 0
	self.faces_considered = #faces
	
	for i, face in ipairs(faces) do
		self.faces_queried = self.faces_queried + 1
		if face:containsPoint(x, y) then
			return face
		end
	end
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
	local face = self:checkPointFaces(x, y)
	if face then
		return "face", face
	end
end

function Graph:checkSegment(x1, y1, x2, y2)
	-- Keep it simple for now
	local collisions = {}
	
	for i = 1, #self.edges, 2 do
		local edge = self.edges[i]
		local collide, tEdge, tSegment = edge:checkSegment(x1, y1, x2, y2)
		if collide then
			table.insert(collisions, { t = tSegment, edge = edge, tEdge = tEdge })
		end
	end
	
	table.sort(collisions, function(one, two) return one.t < two.t end)
	
	return collisions
end

return Graph