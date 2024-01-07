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
	Provides some functions that make them more safe, for example, if a function would normally return nil, a number or an incomplete table when it errors, instead
	of a table, it would instead return a table with the incomplete fields filled out as empty, used to keep code cleaner and less subject to errors without tons of
	validation.
]]

-- library name
safe_server = {}

--[[


	Classes


]]

--[[


	Variables


]]

--[[


	Functions


]]

---@param vehicle_id integer the vehicle_id to get the loaded data for.
---@return LOADED_VEHICLE_DATA loaded_vehicle_data the loaded vehicle data for the vehicle
---@return boolean is_success if it ran without error
function safe_server.getVehicleComponents(vehicle_id)
	-- call the normal function
	local loaded_vehicle_data, is_success = server.getVehicleComponents(vehicle_id)

	-- if the data it retuned is not a table, make it a table.
	if type(loaded_vehicle_data) ~= "table" then
		loaded_vehicle_data = {}
	end

	-- populate missing data
	loaded_vehicle_data.voxels = loaded_vehicle_data.voxels or nil
	loaded_vehicle_data.mass = loaded_vehicle_data.mass or nil
	loaded_vehicle_data.characters = loaded_vehicle_data.characters or {}
	loaded_vehicle_data.components = loaded_vehicle_data.components or {}

	return loaded_vehicle_data, is_success
end