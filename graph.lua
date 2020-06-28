--[[
	ultra-basic running graph
]]

local graph = {}
graph.mt = {__index = graph}

function graph:new(count, height)
	return setmetatable({
		samples = {},
		count = count,
		height = height,
	}, self.mt)
end

function graph:add(amount)
	table.insert(self.samples, amount)
	if #self.samples > self.count then
		table.remove(self.samples, 1)
	end
end

function graph:draw()
	love.graphics.push("all")
	--calc max
	local max = -math.huge
	for i, v in ipairs(self.samples) do
		max = math.max(max, v)
	end

	--(shorthand)
	local h = self.height
	--draw backing
	love.graphics.setColor(0.1, 0.1, 0.1, 1)
	love.graphics.rectangle("fill", 0, 0, self.count, h)
	--draw samples
	love.graphics.setColor(0.5, 0.5, 0.5, 1)
	for i, v in ipairs(self.samples) do
		local f = v / max
		love.graphics.rectangle(
			"fill",
			i, (1 - f) * h,
			1, f * h
		)
	end
	love.graphics.pop()
end

return graph