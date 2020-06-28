--[[
	demo of garbage_geiger

	not intended for incorporation into other projects, but the code is open :)

	see readme.md or garbage_geiger.lua for usage details
]]

local geiger = require("garbage_geiger"):new()

local font_size = 32
love.graphics.setFont(love.graphics.newFont(font_size))

local alloc_amount = 0
local function _rate()
	return math.pow(10, alloc_amount)
end

local graph = require("graph"):new(love.graphics.getWidth(), 100)

local UPDATE_TIME = 0
local DRAW_TIME = 0

local g = {}
local state_change_chance = 0.001
local garbage_proportion = 0.9
local unconnected_rate = 0.8
local interconnection_max = 10

function love.update(dt)
	local start_time = love.timer.getTime()

	geiger:update(dt)

	if love.math.random() < state_change_chance then
		g = {}
	end

	local rate = _rate()
	for i = 1, rate do
		local idx = love.math.random(1, rate)
		--just some table, with some data in it since you wont create and forget about an empty table in normal code
		local node = {i}

		local is_garbage = love.math.random() < garbage_proportion
		if is_garbage then
			--dont persist, this was some random garbage allocation
		else
			--few inter-connections per node to simulate world references
			local connections = 
				love.math.random() < unconnected_rate
					and 0
					or love.math.random(1, interconnection_max)
			for _ = 1, connections do
				local c_idx = love.math.random(1, #g)
				table.insert(node, g[c_idx])
			end
			--persist
			g[idx] = node
		end
	end
	if #g > rate then
		local amount = love.math.random(1, math.min(#g - rate, #g * 0.01))
		for i = 1, amount do
			table.remove(g)
		end
	end

	graph:add(collectgarbage("count"))

	UPDATE_TIME = love.timer.getTime() - start_time
end

function love.draw()
	local start_time = love.timer.getTime()

	love.graphics.push()
	love.graphics.translate(0, 10)
	graph:draw()
	love.graphics.pop()

	for i, v in ipairs{
		("%4.1f ms/frame"):format((UPDATE_TIME + DRAW_TIME) * 1000),
		("%d fps"):format(love.timer.getFPS()),
		"",
		("%5.3f mb of lua memory"):format(collectgarbage("count") / 1024),
		("%d tables/frame"):format(_rate()),
		("%d tables active"):format(#g),
		"",
		"press left/right keys to change rate",

		-- todo: add these back if a ui to change the parameters is added
		--       otherwise they are just noise
		-- "",
		-- ("%2d%% garbage"):format(garbage_proportion * 100),
		-- ("%2d%% unconnected"):format(unconnected_rate * 100),
		-- ("up to %2d connections"):format(interconnection_max),
		-- ("%.1f%% chance of state change"):format(state_change_chance * 100),
	} do
		love.graphics.printf(
			v,
			0, 150 + (i - 1) * font_size,
			love.graphics.getWidth(),
			"center"
		)
	end

	DRAW_TIME = love.timer.getTime() - start_time
end

function love.keypressed(k)
	--restart/quit with ctrl+r/q
	if love.keyboard.isDown("lctrl") then
		if k == "r" then
			love.event.quit("restart")
		elseif k == "q" then
			love.event.quit()
		end
	end

	--tweak simulation parameters
	if k == "left" then
		alloc_amount = alloc_amount - 1
	end
	if k == "right" then
		alloc_amount = alloc_amount + 1
	end
	alloc_amount = math.max(0, math.min(alloc_amount, 5))

	--todo: ui or similar to change other quantities
end
