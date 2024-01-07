--[[
	
Copyright 2024 Liam Matthews

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

-- Library Version 0.0.1

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used to convert a vehicle's id into the group_id without requring to constantly use server.getVehicleData.
]]

-- library name
VehicleGroup = {}

--[[


	Classes


]]

--[[


	Variables


]]

--- Create the g_savedata for this library.
g_savedata = g_savedata or {}
g_savedata.libraries = g_savedata.libraries or {}
g_savedata.libraries.vehicle_group = {
	translations = {}, ---@type table<integer, integer> indexed by vehicle_id, stores the group_id.
	group_to_vehicles = {} ---@type table<integer, table<integer>> indexed by group_id, stores a table of group_ids.
}

--[[


	Functions


]]

---# Stores a group into the translations table <br>
---- Only to be used internally by vehicleGroup.lua, unless you want to make some further optimisations
---@param group_id integer the group_id to store in the translations table.
local function storeGroupID(group_id)

	-- get the vehicle ids associated with this group
	local vehicle_ids = server.getVehicleGroup(group_id)

	-- store all of the vehicle_ids stored in the group into the translations.
	for vehicle_group_index = 1, #vehicle_ids do
		g_savedata.libraries.vehicle_group.translations[vehicle_ids[vehicle_group_index]] = group_id
	end

	g_savedata.libraries.vehicle_group.group_to_vehicles = g_savedata.libraries.vehicle_group.group_to_vehicles or {}
	g_savedata.libraries.vehicle_group.group_to_vehicles[group_id] = vehicle_ids
end

---# Discovers the groupID for the specified vehicle_id and returns it, and also stores it in the translations table. <br>
---- Only to be used internally by vehicleGroup.lua, unless you want to make some further optimisations, as this function can return the id, but it will do so via server.getVehicleData, which nullifies the point of this script if you use this directly.
---@param vehicle_id integer the vehicle_id to find the group_id of.
---@return integer? group_id the group_id associated with the vehicle_id, returns nil if the vehicle_id doesn't have a vehicle associated.
local function findGroupID(vehicle_id)
	-- get the vehicle's data
	local vehicle_data = server.getVehicleData(vehicle_id)

	-- check if we got the data we needed.
	---@diagnostic disable-next-line: undefined-field
	if not vehicle_data or not vehicle_data.group_id then
		return nil
	end

	-- store the vehicles in the translations table
	---@diagnostic disable-next-line: undefined-field
	storeGroupID(vehicle_data.group_id)
	
	-- return the group_id
	---@diagnostic disable-next-line: undefined-field
	return vehicle_data.group_id
end

---@param vehicle_id integer the vehicle_id which you want to convert into group_id.
---@return integer? group_id the group_id associated with the vehicle_id, returns nil if the vehicle_id doesn't have a vehicle associated.
function VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the vehicle_id is a number.
	if type(vehicle_id) ~= "number" then
		return nil
	end

	-- Ensure the vehicle_id is an integer.
	if math.type(vehicle_id) ~= "integer" then
		return nil
	end

	-- get the stored group_id.
	local stored_group_id = g_savedata.libraries.vehicle_group.translations[vehicle_id]

	-- if theres already a stored translation for this vehicle, use that.
	if stored_group_id then
		return stored_group_id
	end

	-- theres not a translation stored for this vehicle yet, so find it and return it.
	return findGroupID(vehicle_id)
end

---# Returns the vehicle_id of the main vehicle in the group.
---@param group_id integer the group_id to get the main vehicle for
---@return integer? vehicle_id the vehicle_id of the main body in that group
function VehicleGroup.getMainVehicle(group_id)
	-- get the vehicles in the group
	local vehicle_ids, is_success = server.getVehicleGroup(group_id)

	if not is_success then
		return nil
	end

	if type(vehicle_ids) ~= "table" then
		return nil
	end

	return vehicle_ids[1]
end

--[[


	Callback Injections


]]

-- store into translation table when a group spawns.
---@diagnostic disable-next-line: undefined-global
local old_onGroupSpawn = onGroupSpawn ---@type function
function onGroupSpawn(group_id, peer_id, x, y, z, group_cost)
	storeGroupID(group_id)

	if old_onGroupSpawn then
		return old_onGroupSpawn(group_id, peer_id, x, y, z, group_cost)
	end
end

--[[
	

	Function Injections


]]

-- Fix server.getVehicleGroup, if it just returns the value, try to get the proper table.<br>
-- It would return junk whenever you gave it a vehjicle_id 
local old_getVehicleGroup = server.getVehicleGroup
function server.getVehicleGroup(group_id)
	local vehicle_ids = old_getVehicleGroup(group_id)

	-- didn't return junk
	if vehicle_ids ~= group_id then
		return vehicle_ids, true
	end

	g_savedata.libraries.vehicle_group.group_to_vehicles = g_savedata.libraries.vehicle_group.group_to_vehicles or {}

	-- returned junk, try to get valid output.
	local real_vehicle_ids = g_savedata.libraries.vehicle_group.group_to_vehicles[group_id]

	-- no valid input found, just return the returned data as a table.
	if not real_vehicle_ids then
		return {vehicle_ids}, false
	end

	-- return the real vehicle ids.
	return real_vehicle_ids, true
end