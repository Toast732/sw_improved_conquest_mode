-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("LifeBoatAPI")

local min_y = property.getNumber("Min Y")

local min_dist = property.getNumber("Min Distance")
local max_dist = property.getNumber("Max Distance")

local seconds_between_missiles = property.getNumber("Fire Rate (s)")

local ticks_between_missiles = seconds_between_missiles * 60

local cooldown = 0

function onTick()

	output.setBool(1, false)

	if cooldown > 0 then
		cooldown = math.max(0, cooldown - 1)
		return
	end

	-- check if NPC is seated
	if not input.getBool(1) then
		return
	end
	
	if input.getNumber(2) < min_y then -- target Y
		return
	end

	-- only check distances if its specified
	if min_dist ~= 0 or max_dist ~= 0 then
		local tX = input.getNumber(1) -- target X
		local tZ = input.getNumber(3) -- target Z

		local pX = input.getNumber(4) -- position X
		local pZ = input.getNumber(5) -- position Z

		local rX = tX - pX -- relative X
		local rZ = tZ - pZ -- relative Z

		local d = math.sqrt(rX*rX + rZ*rZ) -- distance in 2d space

		if max_dist ~= 0 and d > max_dist then
			return
		end

		if min_dist ~= 0 and d < min_dist then
			return
		end
	end

	-- fire missile
	output.setBool(1, true)

	-- set timer
	cooldown = ticks_between_missiles
end