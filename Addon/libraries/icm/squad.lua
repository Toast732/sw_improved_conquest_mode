--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

-- library name
Squad = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

---@class SQUAD
---@field command string the command the squad is following.
---@field vehicle_type string the vehicle_type this squad is composed of.
---@field role string the role of this squad.
---@field vehicles table<integer, vehicle_object> the vehicles in this squad.
---@field target_island ISLAND the island they're targetting.


--[[


	Functions         


]]

---@param vehicle_id integer the id of the vehicle you want to get the squad ID of
---@return integer|nil squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---@return SQUAD|nil squad the info of the squad, if not found, then returns nil
function Squad.getSquad(vehicle_id) -- input a vehicle's id, and it will return the squad index its from and the squad's data
	local squad_index = g_savedata.ai_army.squad_vehicles[vehicle_id]
	if squad_index then
		local squad = g_savedata.ai_army.squadrons[squad_index]
		if squad then
			return squad_index, squad
		else
			return squad_index, nil
		end
	else
		return nil, nil
	end
end

---@param vehicle_id integer the vehicle's id
---@return vehicle_object? vehicle_object the vehicle object, nil if not found
---@return integer? squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---@return SQUAD? squad the info of the squad, if not found, then returns nil
function Squad.getVehicle(vehicle_id) -- input a vehicle's id, and it will return the vehicle_object, the squad index its from and the squad's data

	local vehicle_object = nil
	local squad_index = nil
	local squad = nil

	if not vehicle_id then -- makes sure vehicle id was provided
		d.print("(Squad.getVehicle) vehicle_id is nil!", true, 1)
		return vehicle_object, squad_index, squad
	else
		squad_index, squad = Squad.getSquad(vehicle_id)
	end

	if not squad_index or not squad then -- if we were not able to get a squad index then return nil
		return vehicle_object, squad_index, squad
	end

	vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id]

	if not vehicle_object then
		d.print("(Squad.getVehicle) failed to get vehicle_object for vehicle with id "..tostring(vehicle_id).." and in a squad with the id of "..tostring(squad_index).." and with the vehicle_type of "..tostring(squad.vehicle_type), true, 1)
	end

	return vehicle_object, squad_index, squad
end

---@param squad_index integer the squad's index which you want to create it under, if not specified it will use the next available index
---@param vehicle_object vehicle_object the vehicle object which is adding to the squad
---@return integer squad_index the index of the squad
---@return boolean squad_created if the squad was successfully created
function Squad.createSquadron(squad_index, vehicle_object)

	local squad_index = squad_index or #g_savedata.ai_army.squadrons + 1

	if not vehicle_object then
		d.print("(Squad.createSquadron) vehicle_object is nil!", true, 1)
		return squad_index, false
	end

	if g_savedata.ai_army.squadrons[squad_index] then
		d.print("(Squad.createSquadron) Squadron "..tostring(squad_index).." already exists!", true, 1)
		return squad_index, false
	end

	g_savedata.ai_army.squadrons[squad_index] = { 
		command = SQUAD.COMMAND.NONE,
		index = squad_index,
		vehicle_type = vehicle_object.vehicle_type,
		role = vehicle_object.role,
		vehicles = {},
		target_island = nil,
		target_players = {},
		target_vehicles = {},
		investigate_transform = nil
	}

	return squad_index, true
end