-- used for jets to automatically fire missiles

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("LifeBoatAPI")			  -- Type 'LifeBoatAPI.' and use intellisense to checkout the new LifeBoatAPI library functions; such as the LBVec vector maths library

tick_counter = 0

last_fired = 0

yaw = 0
pitch = 0

-- bool properties
requires_occupied = property.getBool("Requires Is Occupied?")

is_rotated = property.getBool("Radar Rotation")

-- number properties
time_between_missiles = property.getNumber("Time Between Missiles (s)")

min_mass = property.getNumber("Min Mass")
max_mass = property.getNumber("Max Mass")

min_y = property.getNumber("Min Y")
max_y = property.getNumber("Max Y")

min_distance = property.getNumber("Min Distance")
max_distance = property.getNumber("Max Distance")

fov_x = property.getNumber("Radar FOV X") * 0.75
fov_y = property.getNumber("Radar FOV Y") * 0.75

if is_rotated then
	local temp_fov_y = fov_y
	fov_y = fov_x
	fov_x = temp_fov_y
end

tau = math.pi*2

function getAngle(tx, tz, px, pz)
	return math.atan(tx - px, tz - pz)/tau
end

function getDist(px, pz, tx, tz)
	return math.sqrt((tx-px)^2+(tz-pz)^2)
end

function onTick()
	local tick_fired = false

	tick_counter = tick_counter + 1

	yaw = 0
	pitch = 0

	within_yaw = false
	within_pitch = false

	is_occupied = input.getBool(1)

	-- if the seat is occupied
	if not requires_occupied or requires_occupied and is_occupied then

		target_mass = input.getNumber(8)

		-- if its within the mass
		if max_mass == 0 and min_mass == 0 or max_mass == 0 and min_mass >= 0 and target_mass >= min_mass or target_mass >= min_mass and target_mass <= max_mass then

			-- if its within the y
				
			pos_x = input.getNumber(5)
			pos_z = input.getNumber(7)
		
			target_x = input.getNumber(1)
			target_z = input.getNumber(3)

			distance = getDist(pos_x, pos_z, target_x, target_z)

			-- if its within the min and max distance
			if distance >= min_distance and distance <= max_distance then

				pos_yaw = -input.getNumber(4)
				tar_yaw = getAngle(target_x, target_z, pos_x, pos_z)

				if math.abs(tar_yaw-pos_yaw) <= fov_x then -- if its within yaw threshold

					pos_y = input.getNumber(6)
					target_y = input.getNumber(2)

					if math.atan((target_y-pos_y)/distance)/tau - input.getNumber(9) <= fov_y then -- if its within pitch threshold
						if last_fired == 0 or tick_counter - last_fired >= time_between_missiles * 60 then
							output.setBool(1, true)
							tick_fired = true
						end
					end
				end
			end
		end
	end

	if not tick_fired then
		output.setBool(1, false)
	end
end

---@param x number the number to clamp
---@param min number the minimum value
---@param max number the maximum value
---@return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return max<x and max or min>x and min or x
end

function noNaN(x)
	return x ~= x and 0 or x
end

function wrap(x, min, max)
	return (x-min)/(max-min)%1*(max-min)+min
end