--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey
--- Remember to set your Author name etc. in the settings: CTRL+COMMA

require("_build._simulator_config") -- default simulator config, CTRL+CLICK it or F12 to goto this file and edit it. Its in a separate file just for convenience.
require("LifeBoatAPI")              -- Type 'LifeBoatAPI.' and use intellisense to checkout the new LifeBoatAPI library functions; such as the LBVec vector maths library

local last_steering_amount = 0
local is_reverse = false

local random_speed_range = property.getNumber("random_speed_range")

local agr_speeds = {
    [0] = {
        [0] = 0,
        [1] = 0
    },
    [1] = {
        [0] = math.random(property.getNumber("normal_road_speed") - random_speed_range, property.getNumber("normal_road_speed") + random_speed_range),
        [1] = math.random(property.getNumber("aggressive_road_speed") - random_speed_range, property.getNumber("aggressive_road_speed") + random_speed_range)
    },
    [2] = {
        [0] = math.random(property.getNumber("normal_offroad_speed") - random_speed_range, property.getNumber("normal_offroad_speed") + random_speed_range),
        [1] = math.random(property.getNumber("aggressive_offroad_speed") - random_speed_range, property.getNumber("aggressive_offroad_speed") + random_speed_range)
    },
    [3] = {
        [0] = math.random(property.getNumber("normal_bridge_speed") - random_speed_range, property.getNumber("normal_bridge_speed") + random_speed_range),
        [1] = math.random(property.getNumber("aggressive_bridge_speed") - random_speed_range, property.getNumber("aggressive_bridge_speed") + random_speed_range)
    }
}

function randomNum(x,y) --returns a number between x and y including decimals. credit: woe
    return math.random()*(y-x)+x
end

function getAngle(tx, tz, px, pz)
	return math.deg(math.atan(px - tx, pz - tz))
end

function getDist(px, pz, tx, tz)
	return math.sqrt((tx-px)^2+(tz-pz)^2)
end

function canMove(d, sf)
	if d > sf then
		return true
	else
		return false
	end
end

function ws(amount, is_car, angle_diff, dist)
    if not is_car then
	    output.setNumber(1, amount)
    else

        local aggressive_behaviour = property.getNumber("aggressive_behaviour")
        local agr = 1
        if aggressive_behaviour == 0 then
            agr = input.getNumber(13)
        elseif aggressive_behaviour == 1 then
            agr = 0
        end

        local dist_modifier = 1
        if dist < 100 and agr == 0 then
            dist_modifier = dist/100
        elseif dist < 50 then
           dist_modifier = dist/50 
        end

        local road_type = input.getNumber(14)
        if amount > 0 then
            local random_min_speed_range = property.getNumber("minimum_speed_random_range")
            local min_speed = property.getNumber("minimum_speed")+randomNum(-random_min_speed_range,-random_min_speed_range)
            if agr == 1 then
                min_speed = min_speed * 1.5
            end
            output.setNumber(1, math.max(agr_speeds[road_type][agr]/math.max(angle_diff/90, 1)*(dist_modifier), min_speed))
        else
            output.setNumber(1, 0)
        end
    end
end

local turning_rate_random_range = property.getNumber("turning_rate_random_range")
local turning_rate = property.getNumber("turning_rate")+randomNum(-turning_rate_random_range,-turning_rate_random_range)
function ad(amount, is_smooth)
    if not is_smooth then
	    output.setNumber(2, amount)
    else
        local new_steering_amount = last_steering_amount-math.max(math.min(last_steering_amount-amount, turning_rate), -turning_rate)
        output.setNumber(2, new_steering_amount)
        last_steering_amount = new_steering_amount
    end
end

function onTick()

    local drive_style = property.getNumber("steering_type")

    -- distance sensor safe distances
    local ds_safe_front = property.getNumber("front_dist_tolerance")
    local ds_safe_front_down = property.getNumber("front_down_dist_tolerance")
    local ds_safe_rear = property.getNumber("rear_dist_tolerance")
    local ds_safe_rear_down = property.getNumber("rear_down_dist_tolerance")

    local ds_safe_wall = property.getNumber("wall_safe_dist")
    local ds_safe_down = property.getNumber("ground_safe_dist")
        
    local tank_ts = property.getNumber("tank_turn_speed")

	local is_driver = input.getBool(1)
	
	local pos_x = input.getNumber(1)
	local pos_z = input.getNumber(2)
	
	local dest_x = input.getNumber(3)
	local dest_z = input.getNumber(4)

    local final_dest_x = input.getNumber(15)
    local final_dest_z = input.getNumber(16)
	
    -- compass
	local pos_angle = input.getNumber(5)*-360
	
	-- angle to get to destination
	local dest_angle = getAngle(pos_x, pos_z, dest_x, dest_z)
	
	-- the distance sensors
	local ds_front = input.getNumber(6)
	local ds_front_left = input.getNumber(7)
	local ds_front_right = input.getNumber(8)
	local ds_rear = input.getNumber(9)
	local ds_rear_left = input.getNumber(10)
	local ds_rear_right = input.getNumber(11)
	
	-- real distances
	local rds_front = ds_front - ds_safe_front
	local rds_front_left = ds_front_left - ds_safe_front_down
	local rds_front_right = ds_front_right - ds_safe_front_down
	local rds_rear = ds_rear - ds_safe_rear
	local rds_rear_left = ds_rear_left - ds_safe_rear_down
	local rds_rear_right = ds_rear_right - ds_safe_rear_down
	
	if dest_x ~= 0 or dest_z ~= 0 then
		dist = getDist(pos_x, pos_z, dest_x, dest_z)
        final_dist = getDist(pos_x, pos_z, final_dest_x, final_dest_z)
        output.setNumber(5, dist)
		if final_dist > 2 and is_driver then
            output.setBool(1, true)

            output.setNumber(3, pos_angle)
            
            local angleDiff = dest_angle-pos_angle

            output.setNumber(5, dest_angle)

            output.setNumber(6, angleDiff)
            if drive_style == 0 then -- car
                local steering_radius = property.getNumber("steering_max_angle")
                local current_speed = input.getNumber(12) 
                
                if angleDiff > 91 or angleDiff < -91 then -- turn by backing up
                    if not is_reverse then
                        output.setBool(2, true)
                        ws(0)
                        ad(0, true)
                        output.setBool(3, true)
                        if current_speed < 0.1 then
                            is_reverse = true
                            output.setBool(3, false)
                        end
                    else
                        output.setBool(3, false)
                        ad(-(angleDiff/90*steering_radius/57.2), true)
                        ws(1, true, angleDiff, final_dist)
                        output.setBool(2, true)
                        is_reverse = true
                    end
                    output.setNumber(7, 1)
                elseif canMove(rds_front, ds_safe_wall) then -- try moving forwards
                    if is_reverse then
                        output.setBool(2, false)
                        ws(0, true, angleDiff, final_dist)
                        ad(0, true)
                        output.setBool(3, true)
                        if current_speed < 0.1 then
                            is_reverse = false
                            output.setBool(3, false)
                        end
                    else
                        output.setBool(3, false)
                        ad((angleDiff/90*steering_radius/57.2), true)
                        ws(1, true, angleDiff, final_dist)
                        output.setBool(2, false)
                        is_reverse = false
                    end
                    output.setNumber(7, 2)
                elseif canMove(rds_rear, ds_safe_wall) then -- try moving backwards
                    if not is_reverse then
                        output.setBool(2, true)
                        ws(0)
                        ad(0, true)
                        output.setBool(3, true)
                        if current_speed < 0.1 then
                            is_reverse = true
                            output.setBool(3, false)
                        end
                    else
                        output.setBool(3, false)
                        ad(-(angleDiff/90*steering_radius/57.2), true)
                        ws(1, true, angleDiff, final_dist)
                        output.setBool(2, true)
                        is_reverse = true
                    end
                    output.setNumber(7, 3)
                else -- dont move
                    output.setBool(2, false)
                    output.setBool(1, false)
                    ws(0)
                    ad(0, true)
                    output.setNumber(7, 4)
                end
            elseif drive_style == 1 then
                local dist_multi = 1
                if dist < 50 then
                    dist_multi = math.max(dist/50, 0.7)
                end
                
                local angle_multi = 1
                if math.abs(angleDiff) < 50 then
                    angle_multi = math.max(math.abs(angleDiff)/50, 0.4)
                end
                
                output.setNumber(4, angle_multi)
            
                if angleDiff < 2 and angleDiff > -2 then -- go forwards
                    if canMove(rds_front, ds_safe_wall) then
                        ws(1*dist_multi)
                        ad(0)
                    end
                elseif angleDiff > 178 and angelDiff < 182 or angleDiff < -178 and angleDiff > -182 then -- backup
                    if canMove(rds_front, ds_safe_wall) then
                        ws(-1*dist_multi)
                        ad(0)
                    end
                elseif angleDiff < -2 and angleDiff >= -178 then
                    if canMove(ds_safe_down, rds_front_left) and canMove(ds_safe_down, rds_rear_right) then -- if it can turn left
                        ad(-tank_ts*angle_multi)
                        if angle_multi == 1 then
                            ws(0)
                        else
                            ws((0.08/angle_multi))
                        end
                    end
                else
                    if canMove(ds_safe_down, rds_front_right) and canMove(ds_safe_down, rds_rear_left) then -- if it can turn right
                        ad(tank_ts*angle_multi)
                        if angle_multi == 1 then
                            ws(0)
                        else
                            ws((0.08/angle_multi))
                        end
                    end
                end
            end
        else
            output.setNumber(7, 5)
            output.setBool(1, false)
        end
    end
end