-- This library is for controlling or getting things about the Enemy AI.

-- required libraries
require("libraries.addon.script.debugging")

-- library name
AI = {}

--- @param vehicle_object vehicle_object the vehicle you want to set the state of
--- @param state string the state you want to set the vehicle to
--- @return boolean success if the state was set
function AI.setState(vehicle_object, state)
	if vehicle_object then
		if state ~= vehicle_object.state.s then
			if state == VEHICLE.STATE.HOLDING then
				vehicle_object.holding_target = vehicle_object.transform
			end
			vehicle_object.state.s = state
		end
	else
		d.print("(AI.setState) vehicle_object is nil!", true, 1)
	end
	return false
end

--# made for use with toggles in buttons (only use for toggle inputs to seats)
---@param vehicle_id integer the vehicle's id that has the seat you want to set
---@param seat_name string the name of the seat you want to set
---@param axis_ws number w/s axis
---@param axis_ad number a/d axis
---@param axis_ud number up down axis
---@param axis_lr number left right axis
---@param ... boolean buttons (1-7) (7 is trigger)
---@return boolean set_seat if the seat was set
function AI.setSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, ...)
	
	if not vehicle_id then
		d.print("(AI.setSeat) vehicle_id is nil!", true, 1)
		return false
	end

	if not seat_name then
		d.print("(AI.setSeat) seat_name is nil!", true, 1)
		return false
	end

	local button = table.pack(...)

	-- sets any nil values to 0 or false
	axis_ws = axis_ws or 0
	axis_ad = axis_ad or 0
	axis_ud = axis_ud or 0
	axis_lr = axis_lr or 0

	for i = 1, 7 do
		button[i] = button[i] or false
	end

	g_savedata.seat_states = g_savedata.seat_states or {}


	if not g_savedata.seat_states[vehicle_id] or not g_savedata.seat_states[vehicle_id][seat_name] then

		g_savedata.seat_states[vehicle_id] = g_savedata.seat_states[vehicle_id] or {}
		g_savedata.seat_states[vehicle_id][seat_name] = {}

		for i = 1, 7 do
			g_savedata.seat_states[vehicle_id][seat_name][i] = false
		end
	end

	for i = 1, 7 do
		if button[i] ~= g_savedata.seat_states[vehicle_id][seat_name][i] then
			g_savedata.seat_states[vehicle_id][seat_name][i] = button[i]
			button[i] = true
		else
			button[i] = false
		end
	end

	s.setVehicleSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, button[1], button[2], button[3], button[4], button[5], button[6], button[7])
	return true
end