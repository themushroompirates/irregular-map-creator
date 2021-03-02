require "util.strict"

local Graph = require "graph.graph"

local face_colours = require "colours"

local main_fg = { .8, .9, .95 }
local main_bg = { 0.1, 0.1, 0.3 }

local VERTEX_SIZE = 12

local graph = Graph()

function love.load()
	local vertices = {
		{ key = 1, x = 100, y = 100 },
		{ key = 2, x = 200, y = 100 },
		{ key = 3, x = 150, y = 200 },
		{ key = 4, x = 250, y = 250 },
		{ key = 5, x = 350, y = 100 },
		{ key = 6, x = 250, y = 150 },
		{ key = 7, x = 200, y = 200 },
		{ key = 8, x = 250, y = 250 }
	}
	local edges =  {
		{ head = 1, tail = 3 },
		{ head = 3, tail = 2 },
		{ head = 2, tail = 1 },
		{ head = 3, tail = 4 },
		{ head = 2, tail = 4 },
		--{ head = 2, tail = 6 },
		{ head = 6, tail = 4 },
		
		{ head = 5, tail = 6 },
		{ head = 5, tail = 2 },
		{ head = 7, tail = 8 }
	}
	graph = Graph(vertices, edges)
end

function love.keypressed(key)
	graph:recalculate()
end

function draw_face(face)
	assert(face and face.path and #face.path > 1)
	local coords = {}
	
	for i, edge in ipairs(face.path) do
		local x, y = edge.head:getCoordinates()
		coords[2*(i-1)+1] = x
		coords[2*(i-1)+2] = y
	end
	
	local triangles = love.math.triangulate(coords)
	
	local colour = face_colours[face.key]
	love.graphics.setColor(colour[1], colour[2], colour[3], 0.5)
	for i, triangle in ipairs(triangles) do
		love.graphics.polygon("fill", triangle)
	end
end

local function perp(dx, dy)
	return -dy, dx
end

local function get_edge_coords(edge, offset)
	local x1, y1, x2, y2 = edge:getCoordinates()
	
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx*dx+dy*dy)
	dx, dy = dx / length, dy / length
	local qx, qy = perp(dx, dy)
	
	local r = VERTEX_SIZE + 2
	
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

local function draw_arrow(x1, y1, x2, y2, head_length, head_width)
	love.graphics.line(x1, y1, x2, y2)
	draw_arrow_head(x2, y2, x2-x1, y2-y1, head_length, head_width)
end

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

function draw_edge(edge, offset)
	local x1, y1, x2, y2 = get_edge_coords(edge, offset)
	
	draw_arrow(x1, y1, x2, y2)
end

function love.draw()
	love.graphics.clear(main_bg)
	-- Draw all faces
	for i, face in ipairs(graph.faces) do
		draw_face(face)
	end
	love.graphics.setColor(main_fg)
	-- Draw all edges
	-- Only want every other one so we skip the twins
	for i = 1, #graph.edges, 2 do
		local x1, y1, x2, y2 = graph.edges[i]:getCoordinates()
		love.graphics.line(x1, y1, x2, y2)
	end
	
	-- Draw all vertices
	local font = love.graphics.getFont()
	for i, vertex in ipairs(graph.vertices) do
		local x, y = vertex:getCoordinates()
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
	
	--[[
	for i, edge in ipairs(edges) do
		love.graphics.setColor(face_colours[i])
		draw_edge(edge, 5)
	end
	--]]
	
	-- testing
	--draw_linked_edge(edges[1], edges[7])
	for i, edge in ipairs(graph.edges) do
		if edge.next then
			love.graphics.setColor(face_colours[i])
			draw_linked_edge(edge, i%2==0, .35 + .1 * (i%2))
		end
	end
	
	-- Draw edges/faces data
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
	
	-- Draw temp stuff
	love.graphics.setColor(main_fg)
	local foo, bar, baz = graph:checkPoint(love.mouse.getPosition())
	love.graphics.print(tostring(foo).."\t"..tostring(bar).."\t"..tostring(baz).."\t", 10, love.graphics.getHeight()-10-love.graphics.getFont():getHeight())
end