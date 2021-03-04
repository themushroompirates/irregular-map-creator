local class = require "util.30log"
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

return Vertex