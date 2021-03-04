require "util.strict"

local Graph = require "graph.graph"

local face_colours = require "colours"

local main_fg = { .8, .9, .95 }
local main_bg = { 0.1, 0.1, 0.3 }

local bg = love.graphics.newImage("robin-hood-map.jpg")
local bg_opacity = 1.0

local VERTEX_SIZE = 12

local graph = Graph()
graph.vertex_tolerance = VERTEX_SIZE
graph.edge_tolerance = VERTEX_SIZE/2

local camera = love.math.newTransform()

local last_selected_vertex = nil
local has_moved_vertex = false
local vertex_old_x, vertex_old_y

function love.load()
	local vertices = {
		{ key = 1, x = 100*2, y = 100*2 },
		{ key = 2, x = 200*2, y = 100*2 },
		{ key = 3, x = 200*2, y = 200*2 },
		{ key = 3, x = 100*2, y = 200*2 },
	}
	local edges =  {
		{ 1, 2 },
		{ 2, 3 },
		{ 3, 4 },
		{ 4, 1 },
	}
	graph = Graph(vertices, edges)
	
	load_graph()
end

-- Camera handled
function draw_face(face)
	assert(face and face.path and #face.path > 1)
	local coords = {}
	
	local vertices = face:getPathVertices()
	for i, vertex in ipairs(vertices) do
		local x, y = camera:transformPoint(vertex:getCoordinates())
		coords[2*(i-1)+1] = x
		coords[2*(i-1)+2] = y
	end
	
	local ok, triangles = pcall(love.math.triangulate, coords)
	if not ok then
		love.graphics.setColor(1, 0, 0)
		love.graphics.line(coords)
		return
	end
	
	local colour = face_colours[face.key]
	love.graphics.setColor(colour[1], colour[2], colour[3], 0.75)
	for i, triangle in ipairs(triangles) do
		love.graphics.polygon("fill", triangle)
	end
end

local function perp(dx, dy)
	return -dy, dx
end

-- Camera handled
local function get_edge_coords(edge, offset)
	local x1, y1, x2, y2 = edge:getCoordinates()
	
	x1, y1 = camera:transformPoint(x1, y1)
	x2, y2 = camera:transformPoint(x2, y2)
	
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx*dx+dy*dy)
	dx, dy = dx / length, dy / length
	local qx, qy = perp(dx, dy)
	
	local r = VERTEX_SIZE + 2
	
	offset = offset or 0
	
	if offset ~= 0 then
		-- Offset amount
		local q = offset
		
		qx, qy = qx * q, qy * q
		
		x1, y1 = x1 + qx, y1 + qy
		x2, y2 = x2 + qx, y2 + qy

		-- Now adjust for the vertex radius
		local d = math.sqrt(r*r - q*q)
		
		x1, y1 = x1 + d * dx, y1 + d * dy
		x2, y2 = x2 - d * dx, y2 - d * dy
	else
		-- Adjust for vertex radius
		x1, y1 = x1 + r * dx, y1 + r * dy
		x2, y2 = x2 - r * dx, y2 - r * dy
	end
	
	return x1, y1, x2, y2
	
end

-- Camera unrelated
local function draw_arrow_head(x, y, dx, dy, head_length, head_width)
	head_length = head_length or 10
	head_width = head_width or 5
	local length = math.sqrt(dx*dx+dy*dy)
	dx, dy = dx/length, dy/length
	
	local qx, qy = perp(dx, dy)
	
	love.graphics.polygon("fill",
		x, y,
		x - dx*head_length + qx * head_width, y - dy * head_length + qy * head_width,
		x - dx*head_length - qx * head_width, y - dy * head_length - qy * head_width
	)
end

-- Camera unrelated
local function draw_arrow(x1, y1, x2, y2, head_length, head_width)
	love.graphics.line(x1, y1, x2, y2)
	draw_arrow_head(x2, y2, x2-x1, y2-y1, head_length, head_width)
end

-- Camera handled via get_edge_coords
function draw_linked_edge(edge1)
	local edge2 = edge1.next
	
	local x1, y1, x2, y2 = get_edge_coords(edge1, 10)
	local x3, y3, x4, y4 = get_edge_coords(edge2, 10)
	
	x1, y1 = (x1 + x2*2)/3, (y1+y2*2)/3
	x4, y4 = (x4 + x3*2)/3, (y4+y3*2)/3
	
	local bezier = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)
	
	love.graphics.line(bezier:render())
	
	local derivative = bezier:getDerivative()
	local dx, dy = derivative:evaluate(1.0)
	draw_arrow_head(x4, y4, dx, dy)
end

-- Camera handled via get_edge_coords
function draw_edge(edge, offset)
	local x1, y1, x2, y2 = get_edge_coords(edge, offset)
	
	draw_arrow(x1, y1, x2, y2)
end

-- Camera handled
function draw_selection()
	local mouseX, mouseY = camera:inverseTransformPoint(love.mouse.getPosition())
	
	local scale = camera:getMatrix()
	graph.vertex_tolerance = (VERTEX_SIZE  )/scale
	graph.edge_tolerance   = (VERTEX_SIZE/2)/scale
	
	local foo, bar, baz = graph:checkPoint(mouseX, mouseY)
	
	local target_x, target_y
	if foo == "vertex" then
		target_x, target_y = bar:getCoordinates()
	elseif foo == "edge" then
		target_x, target_y = bar:getCoordinatesOfPoint(baz)
	else
		target_x, target_y = mouseX, mouseY
	end
	
	local extra_info = ""
	
	love.graphics.setColor(1, 0, 0, .9)
	if last_selected_vertex == nil then
		-- Selecting / Creating vertex
		local x0, y0 = camera:transformPoint(target_x, target_y)
		love.graphics.circle("line", x0, y0, VERTEX_SIZE + 0)
		love.graphics.circle("line", x0, y0, VERTEX_SIZE + 2)
	else
		-- Trying to create edge
		local x, y = last_selected_vertex:getCoordinates()
		local x_screen, y_screen = camera:transformPoint(x, y)
		love.graphics.circle("line", x_screen, y_screen, VERTEX_SIZE + 0)
		love.graphics.circle("line", x_screen, y_screen, VERTEX_SIZE + 2)
		
		local target_x_screen, target_y_screen = camera:transformPoint(target_x, target_y)
		love.graphics.circle("line", target_x_screen, target_y_screen, VERTEX_SIZE + 0)
		love.graphics.circle("line", target_x_screen, target_y_screen, VERTEX_SIZE + 2)
		
		local collisions = graph:checkSegment(x, y, target_x, target_y)
		for i, collision in ipairs(collisions) do
			if collision.t > 0 and collision.t < 1 then
				local xC, yC = collision.edge:getCoordinatesOfPoint(collision.tEdge)
				xC, yC = camera:transformPoint(xC, yC)
				if collision.tEdge > 0 and collision.tEdge < 1 then
					-- Actual collision on an edge
					love.graphics.circle("line", xC, yC, VERTEX_SIZE + 0)
				else
					-- Endpoint
					love.graphics.circle("line", xC, yC, VERTEX_SIZE + 0)
					love.graphics.circle("line", xC, yC, VERTEX_SIZE + 2)
				end
			end
		end
		extra_info = string.format("Collisions : %d", #collisions)
		
		love.graphics.line(x_screen, y_screen, target_x_screen, target_y_screen)
	end
	
	love.graphics.setColor(main_fg)
	love.graphics.print(tostring(foo).."\t"..tostring(bar).."\t"..tostring(baz).."\t", 10, love.graphics.getHeight()-10-love.graphics.getFont():getHeight())
	love.graphics.print(extra_info, 10, love.graphics.getHeight()-30-love.graphics.getFont():getHeight())
end

-- Camera handled
function love.draw()
	love.graphics.clear(main_bg)
	
	local opacity = bg_opacity
	
	if love.keyboard.isDown("tab") then
		opacity = opacity * .5
	end
	
	love.graphics.push()
	love.graphics.applyTransform(camera)
	love.graphics.setColor(1, 1, 1, opacity)
	love.graphics.draw(bg)
	love.graphics.pop()
	
	
	if love.keyboard.isDown("tab") then
		love.graphics.setColor(1, 1, 1)
		-- Draw all edges
		-- Only want every other one so we skip the twins
		for i = 1, #graph.edges, 2 do
			local x1, y1, x2, y2 = graph.edges[i]:getCoordinates()
			
			x1, y1 = camera:transformPoint(x1, y1)
			x2, y2 = camera:transformPoint(x2, y2)
			
			love.graphics.line(x1, y1, x2, y2)
		end
	else
	
	-- Draw all faces
	for i, face in ipairs(graph.faces) do
		draw_face(face)
	end
	
	local scale = camera:getMatrix()
	local show_vertices = scale >= 1.0
	
	
	love.graphics.setColor(main_fg)
	love.graphics.setColor(1, 1, 1)
	-- Draw all edges
	-- Only want every other one so we skip the twins
	for i = 1, #graph.edges, 2 do
		local x1, y1, x2, y2
		if show_vertices then
			x1, y1, x2, y2 = get_edge_coords(graph.edges[i])
		else
			x1, y1, x2, y2 = graph.edges[i]:getCoordinates()
			x1, y1 = camera:transformPoint(x1, y1)
			x2, y2 = camera:transformPoint(x2, y2)
		end
		love.graphics.line(x1, y1, x2, y2)
	end
	
	-- Draw all vertices
	if show_vertices then
		local font = love.graphics.getFont()
		for i, vertex in ipairs(graph.vertices) do
			local x, y = camera:transformPoint(vertex:getCoordinates())
			local text = tostring(i)
			local tw, th = font:getWidth(text), font:getHeight()
			
			local r = math.max(tw, th) + 3
			r = VERTEX_SIZE
			
			love.graphics.setColor(main_bg[1], main_bg[2], main_bg[3], 0.75)
			love.graphics.circle("fill", x, y, r)
			love.graphics.setColor(main_fg)
			love.graphics.circle("line", x, y, r)
			love.graphics.print(text, x-tw/2, y-th/2)
		end
	else
		for i, vertex in ipairs(graph.vertices) do
			local x, y = camera:transformPoint(vertex:getCoordinates())
			
			love.graphics.setColor(main_fg)
			love.graphics.circle("fill", x, y, 3)
		end
	end
	
	--[[
	for i, edge in ipairs(edges) do
		love.graphics.setColor(face_colours[i])
		draw_edge(edge, 5)
	end
	--]]
	
	-- testing
	--[[
	for i, edge in ipairs(graph.edges) do
		if edge.next then
			love.graphics.setColor(face_colours[i])
			draw_linked_edge(edge, i%2==0, .35 + .1 * (i%2))
		end
	end
	--]]
	
	-- Draw edges/faces data
	--[[
	love.graphics.setColor(main_fg)
	for i, edge in ipairs(graph.edges) do
		local x = love.graphics.getWidth() - 200
		local y = 10 + (i-1)*20
		love.graphics.print(tostring(edge), love.graphics.getWidth() - 200, y)
		
		x = x + 100
		
		if edge.face == nil then
			love.graphics.print("(todo)", x, y)
		elseif edge.face == false then
			love.graphics.print("NONE", x, y)
		elseif edge.face == true then
			love.graphics.print("...", x, y)
		else
			love.graphics.setColor(face_colours[edge.face.key])
			love.graphics.rectangle("fill", x, y, 10, 10)
			love.graphics.setColor(main_fg)
			love.graphics.rectangle("line", x, y, 10, 10)
			love.graphics.print(tostring(edge.face.key), x + 15, y)
		end
	end
	--]]
	
	-- Draw temp stuff
	if not love.mouse.isDown(2) then
		draw_selection()
	end
	
	end
end

function love.mousepressed(x, y, button)
	if button == 2 then
		love.mouse.setGrabbed(true)
		love.mouse.setCursor(love.mouse.getSystemCursor("sizeall"))
		return
	end
	
	local scale = camera:getMatrix()
	graph.vertex_tolerance = (VERTEX_SIZE  )/scale
	graph.edge_tolerance   = (VERTEX_SIZE/2)/scale
	
	local mouseX, mouseY = camera:inverseTransformPoint(love.mouse.getPosition())
	local foo, bar, baz = graph:checkPoint(mouseX, mouseY)
	
	if last_selected_vertex == nil then
		-- "Create/select vertex" mode
		if foo == "vertex" then
			last_selected_vertex = bar
		elseif foo == "edge" then
			-- Split the edge
			--print("Splitting edge")
			last_selected_vertex = graph:splitEdge(bar, baz)
		else
			-- Clicked on either a face or nothing
			-- In either case, create a new vertex
			last_selected_vertex = graph:addVertex(mouseX, mouseY)
		end
		has_moved_vertex = false
		vertex_old_x, vertex_old_y = last_selected_vertex:getCoordinates()
	else
		-- "Edge" mode
		local tail = nil
		if foo == "vertex" then
			tail = bar
		elseif foo == "edge" then
			tail = graph:splitEdge(bar, baz)
		else
			tail = graph:addVertex(mouseX, mouseY)
		end
		
		if graph:getEdgeForVertices(last_selected_vertex, tail) == nil then
		
			Graph.debug_intersections = true
			local x1, y1 = last_selected_vertex:getCoordinates()
			local x2, y2 = tail:getCoordinates()
			local collisions = graph:checkSegment(x1, y1, x2, y2)
			
			local head = last_selected_vertex
			
			if #collisions > 0 then
				for i, collision in ipairs(collisions) do
					if collision.t > 0 and collision.t < 1 then
						print(string.format("Collision %d of %d : t = %.3f, edge = %s, edge_pos = %.3f", i, #collisions, collision.t, tostring(collision.edge), collision.tEdge))
						local new_vertex = graph:splitEdge(collision.edge, collision.tEdge)
						graph:addEdgeAndTwin(head, new_vertex)
						head = new_vertex
					end
				end
			end
			Graph.debug_intersections = nil
		
		
			graph:addEdgeAndTwin(head, tail)
			last_selected_vertex = nil
		else
			last_selected_vertex = nil
		end
		
		graph:recalculate()
	end
	
end

function love.mousereleased(x, y, button)
	if button == 2 then
		love.mouse.setGrabbed(false)
		love.mouse.setCursor()
	end
	
	if button == 1 then
		if last_selected_vertex and has_moved_vertex then
			last_selected_vertex = nil
		end
	end
end

function love.mousemoved(x, y, dx, dy)
	if love.mouse.isDown(2) then
		local scale = camera:getMatrix()
		camera:translate(dx / scale, dy / scale)
		return
	end
	
	if love.mouse.isDown(1) and last_selected_vertex ~= nil then
		if math.abs(dx) + math.abs(dy) > 0 then
			local scale = camera:getMatrix()
			
			local vertex_new_x, vertex_new_y = camera:inverseTransformPoint(x, y)
			--local vertex_new_x = last_selected_vertex.x + dx / scale
			--local vertex_new_y = last_selected_vertex.y + dy / scale
			
			local can_move = true
			--[[
			local collisions = graph:checkSegment(vertex_old_x, vertex_old_y, vertex_new_x, vertex_new_y)
			for i, collision in ipairs(collisions) do
				if collision.t > 0 and collision.t < 1 and collision.tEdge > 0 and collision.tEdge < 1 then
					can_move = false
					break
				end
			end
			--]]
			
			if can_move then
				last_selected_vertex.x = vertex_new_x
				last_selected_vertex.y = vertex_new_y
			else
			
			end
			
			has_moved_vertex = true
		end
	end
end

function love.wheelmoved(dx, dy)
	local scale = 1.5
	if dy < 0 then scale = 0.75 end
	
	local x, y = love.mouse.getPosition()
	x, y = camera:inverseTransformPoint(x, y)
	
	camera:translate(x, y)
	camera:scale(scale, scale)
	camera:translate(-x, -y)
end

function love.keypressed(key)
	if key == "home" then
		camera:reset()
	end
	
	if key == "escape" then
		if last_selected_vertex ~= nil then
			last_selected_vertex = nil
		end
	end
	
	if key == "s" then
		save_graph()
	end
	
	if key == "space" then
		--graph:recalculate()
		
		print(string.format("We have %d vertices, %d edges, %d faces", #graph.vertices, #graph.edges/2, #graph.faces))
		print(string.format("V-E+F = %d", #graph.vertices - #graph.edges/2 + #graph.faces))
		--graph:debugPaths()
	end
end

function save_graph()
	local data = graph:serialize()
	love.filesystem.write("test-map.txt", data)
end

function load_graph()
	local data = love.filesystem.read("test-map.txt")
	if data then
		print("Loading data...")
		graph:unserialize(data)
	else
		print("Failed to load data")
	end
end