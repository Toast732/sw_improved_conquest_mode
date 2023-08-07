--[[


	Library Setup


]]

-- required libraries
-- (none)

-- library name
-- (not applicable)

-- shortened library name
-- (not applicable)

--[[


	Variables
   

]]

-- pre-calculated pi*2
math.tau = math.pi*2
-- pre-calculated pi*0.5
math.half_pi = math.pi*0.5

--[[


	Classes


]]

--[[


	Functions         


]]


--- @param x number the number to check if is whole
--- @return boolean is_whole returns true if x is whole, false if not, nil if x is nil
function math.isWhole(x) -- returns wether x is a whole number or not
	return math.type(x) == "integer"
end

--- if a number is nil, it sets it to 0
--- @param x number the number to check if is nil
--- @return number x the number, or 0 if it was nil
function math.noNil(x)
	return x ~= x and 0 or x
end

--- @param x number the number to clamp
--- @param min number the minimum value
--- @param max number the maximum value
--- @return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return math.noNil(max<x and max or min>x and min or x)
end

--- @param min number the min number
--- @param max number the max number
function math.randomDecimals(min, max)
	return math.random()*(max-min)+min
end

--- Returns a number which is consistant if the params are all consistant
--- @param use_decimals boolean true for if you want decimals, false for whole numbers
--- @param seed number the seed for the random number generator
--- @param min number the min number
--- @param max number the max number
--- @return number seeded_number the random seeded number
function math.seededRandom(use_decimals, seed, min, max)
	local seed = seed or 1
	local min = min or 0
	local max = max or 1

	local seeded_number = 0

	-- generate a random seed
	math.randomseed(seed)

	-- generate a random number with decimals
	if use_decimals then
		seeded_number = math.randomDecimals(min, max)
	else -- generate a whole number
		seeded_number = math.random(math.floor(min), math.ceil(max))
	end

	-- make the random numbers no longer consistant with the seed
	math.randomseed(g_savedata.tick_counter)
	
	-- return the seeded number
	return seeded_number
end

---@param x number the number to wrap
---@param min number the minimum number to wrap around
---@param max number the maximum number to wrap around
---@return number x x wrapped between min and max
function math.wrap(x, min, max) -- wraps x around min and max
	return (x - min) % (max - min) + min
end

---@param t table a table of which you want a winner to be picked from, the index of the elements must be the name of the element, and the value must be a modifier (num) which when larger will increase the chances of it being chosen
---@return string win_name the name of the element which was picked at random
function math.randChance(t)
	local total_mod = 0
	for k, v in pairs(t) do
		total_mod = total_mod + v
	end
	local win_name = ""
	local win_val = 0
	for k, v in pairs(t) do
		local chance = math.randomDecimals(0, v / total_mod)
		-- d.print("chance: "..chance.." chance to beat: "..win_val.." k: "..k, true, 0)
		if chance > win_val then
			win_val = chance
			win_name = k
		end
	end
	return win_name
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude for 2D distance, include for 3D distance)
---@param y2 number? y coordinate of position 2 (exclude for 2D distance, include for 3D distance)
---@return number distance the euclidean distance between position 1 and position 2
function math.euclideanDistance(...)
	local c = table.pack(...)

	local rx = c[1] - c[2]
	local rz = c[3] - c[4]

	if c.n == 4 then
		-- 2D distance
		return math.sqrt(rx*rx+rz*rz)
	end

	-- 3D distance
	local ry = c[5] - c[6]
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude to just get yaw, include to get yaw and pitch)
---@param y2 number? y coordinate of position 2 (exclude to just get yaw, include to get yaw and pitch)
---@return number yaw the yaw needed to face position 2 from position 1
---@return number pitch the pitch needed to face position 2 from position 1, will return 0 if y not specified.
function math.angleToFace(...)
	local c = table.pack(...)

	-- relative x coordinate
	local rx = c[1] - c[2]
	-- relative z coordinate
	local rz = c[3] - c[4]

	local yaw = math.atan(rz, rx) - math.half_pi

	if c.n == 4 then
		return yaw, 0
	end

	-- relative y
	local ry = c[5] - c[6]

	local pitch = -math.atan(ry, math.sqrt(rx * rx + rz * rz))

	return yaw, pitch
end

--- XOR function.
---@param ... any
---@return boolean
function math.xor(...)
	-- packed table of ..., dont have to use table.pack to respect nils, as nil will just be 0 anyways.
	local t = {...}

	-- the true count
	local tc = 0

	-- for each one that is true, add 1 to true count
	for i = 1, #t do
		if t[i] then tc = tc + 1 end
	end

	-- xor can be summarized down to if the number of true inputs modulo 2 is equal to 1, so do that.
	return tc%2==1
end