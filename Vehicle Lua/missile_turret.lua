-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("LifeBoatAPI")			  -- Type 'LifeBoatAPI.' and use intellisense to checkout the new LifeBoatAPI library functions; such as the LBVec vector maths library

created = false
tick_counter = 0

last_fired_missile = 0

missiles_fired = 0

yaw = 0
pitch = 0

-- bool properties
debug_mode = property.getBool("Enable Debug")
invert_horizontal = property.getBool("Invert Horizontal Rotation")
invert_vertical = property.getBool("Invert Vertical Rotation")
smart_mode = property.getBool("Aim Mode")
requires_occupied = property.getBool("Requires Is Occupied?")

-- number properties
horizontal_type = property.getNumber("Horizontal Pivot Type")
vertical_type = property.getNumber("Vertical Pivot Type")
angle_units = property.getNumber("Angle Units")

horizontal_max = property.getNumber("Horizontal Max Angle")
horizontal_min = property.getNumber("Horizontal Min Angle")
vertical_max = property.getNumber("Vertical Max Angle")
vertical_min = property.getNumber("Vertical Min Angle")

total_missiles = property.getNumber("Missile Count")
time_between_missiles = property.getNumber("Time Between Missiles (s)")

min_mass = property.getNumber("Min Mass")
max_mass = property.getNumber("Max Mass")

min_y = property.getNumber("Min Y")
max_y = property.getNumber("Max Y")

yaw_threshold = property.getNumber("Yaw Threshold")
pitch_threshold = property.getNumber("Pitch Threshold")

min_distance = property.getNumber("Min Distance")
max_distance = property.getNumber("Max Distance")

tau = math.pi*2

horizontal_modifier = 4
vertical_modifier = 4
yaw_modifier = 1
pitch_modifier = 1

function getAngle(tx, tz, px, pz)
	return math.atan(tx - px, tz - pz)/tau
end

function getDist(px, pz, tx, tz)
	return math.sqrt((tx-px)^2+(tz-pz)^2)
end

function onCreate()
	-- converts all measurements to turns
	multiplier = 1
	if angle_units == 1 then -- radians
		multiplier = tau
	elseif angle_units == 2 then -- gradians
		multiplier = 400
	elseif angle_units == 3 then -- degrees
		multiplier = 360
	end

	if horizontal_type >= 2 then
		horizontal_modifier = 1
	end

	if vertical_type >= 2 then
		vertical_modifier = 1
	end

	yaw_modifier = horizontal_modifier
	if invert_horizontal then
		yaw_modifier = -horizontal_modifier
	end

	pitch_modifier = vertical_modifier
	if invert_vertical then
		pitch_modifier = -vertical_modifier
	end

	horizontal_max = noNaN(horizontal_max/multiplier/horizontal_modifier)
	horizontal_min = noNaN(horizontal_min/multiplier/horizontal_modifier)
	vertical_max = noNaN(vertical_max/multiplier/vertical_modifier)
	vertical_min = noNaN(vertical_min/multiplier/vertical_modifier)

	yaw_threshold = noNaN(yaw_threshold/multiplier)
	pitch_threshold = noNaN(pitch_threshold/multiplier)
end

function onTick()
	-- when the script is first started
	if not created then
		onCreate()
		created = true
	end

	tick_counter = tick_counter + 1

	yaw = 0
	pitch = 0

	-- if we still have missiles to fire
	if missiles_fired < total_missiles then

		is_occupied = input.getBool(1)

		-- if the seat is occupied
			-- if the seat is occupied
		if not requires_occupied or requires_occupied and is_occupied then

			target_mass = input.getNumber(10)

			-- if its within the mass
			if max_mass == 0 and min_mass == 0 or max_mass == 0 and min_mass >= 0 and target_mass >= min_mass or target_mass >= min_mass and target_mass <= max_mass then

				target_y = input.getNumber(2)

				-- if its within the y
				if target_y >= min_y and target_y <= max_y then
					
					pos_x = input.getNumber(7)
					pos_z = input.getNumber(9)
				
					target_x = input.getNumber(1)
					target_z = input.getNumber(3)

					distance = getDist(pos_x, pos_z, target_x, target_z)

					-- if its within the min and max distance
					if distance >= min_distance and distance <= max_distance + 300 then

						pos_y = input.getNumber(8)
	
						pos_rot = -input.getNumber(4)
	
						horizontal_rot = input.getNumber(5)
						vertical_rot = input.getNumber(6)
	
						tar_rot = pos_rot - getAngle(target_x, target_z, pos_x, pos_z)
	
						yaw = noNaN(math.clamp(tar_rot, horizontal_min, horizontal_max)*yaw_modifier)
						
						-- robotic
						if horizontal_type <= 1 then
							yaw = noNaN(wrap(yaw, -1, 1))
						end
	
						-- horizontal
						if horizontal_type >= 2 then
							-- velocity
							yaw = noNaN(((yaw-horizontal_rot)%1+1.5)%1-0.5)
						end
	
						pitch = noNaN(math.clamp(math.atan((target_y-pos_y)/distance)/tau, vertical_min, vertical_max)*pitch_modifier)
	
						-- vertical
						if vertical_type >= 2 then
							-- velocity
							pitch = noNaN(((pitch-vertical_rot*vertical_modifier)%1+1.5)%1-0.5)
						end

						if horizontal_type <= 1 and math.abs(horizontal_rot*horizontal_modifier - yaw) <= yaw_threshold or horizontal_type >= 2 and math.abs(yaw) <= yaw_threshold then -- if its within yaw threshold
							if vertical_type <= 1 and math.abs(vertical_rot*pitch_modifier - pitch) <= pitch_threshold or vertical_type >= 2 and math.abs(pitch) <= pitch_threshold then -- if its within pitch threshold
								if last_fired_missile == 0 or tick_counter - last_fired_missile >= time_between_missiles * 60 then
									if distance < max_distance then
										missiles_fired = missiles_fired + 1
										output.setBool(missiles_fired, true)
										last_fired_missile = tick_counter
									end
								end
							end
						end
					end
				end
			end
		end
	end
	output.setNumber(1, yaw)
	output.setNumber(2, pitch)
end

function onDraw()
	if debug_mode then
		if horizontal_rot then
			if horizontal_type <= 1 and math.abs(horizontal_rot*horizontal_modifier - yaw) <= yaw_threshold or horizontal_type >= 2 and math.abs(yaw) <= yaw_threshold then
				screen.drawText(0, 0, "VALID yaw thrsh: "..("%.3f"):format(yaw_threshold).."\nyaw from tar: "..("%.3f"):format(horizontal_type <= 1 and math.abs(horizontal_rot*horizontal_modifier - yaw) or horizontal_type >= 2 and math.abs(yaw)))
			else
				screen.drawText(0, 0, "INVALID yaw thrsh: "..("%.3f"):format(yaw_threshold).."\nyaw from tar: "..("%.3f"):format(horizontal_type <= 1 and math.abs(horizontal_rot*horizontal_modifier - yaw) or horizontal_type >= 2 and math.abs(yaw)))
			end
		else
			screen.drawText(0, 0, "horizontal_rot doesnt exist")
		end
		if vertical_rot then
			if vertical_type <= 1 and math.abs(vertical_rot*vertical_modifier - pitch) <= pitch_threshold or vertical_type >= 2 and math.abs(pitch) <= pitch_threshold then
				screen.drawText(0, 20, "VALID pitch thrsh: "..("%.3f"):format(pitch_threshold).."\npitch from tar: "..("%.3f"):format(vertical_type <= 1 and math.abs(vertical_rot*vertical_modifier - pitch) or vertical_type >= 2 and math.abs(pitch)))
			else
				screen.drawText(0, 20, "INVALID pitch thrsh: "..("%.3f"):format(pitch_threshold).."\npitch from tar: "..("%.3f"):format(vertical_type <= 1 and math.abs(vertical_rot*vertical_modifier - pitch) or vertical_type >= 2 and math.abs(pitch)))
			end
		else
			screen.drawText(0, 20, "vertical_rot doesnt exist")
		end
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