--[[
	
Copyright 2023 Liam Matthews

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

require("libraries.addon.script.debugging")
require("libraries.addon.commands.flags")

VehicleFires = {}

---@class potentialAIFireDebugData
---@field ui_id integer the ui_id for the popup
---@field closest_damage number the damage that occured which was closest to this potential fire.

---@class potentialAIFire
---@field object_id integer the fire's object_id
---@field spawned_at integer the tick the fire was spawned on, uses the normal tick counter
---@field transform SWMatrix the matrix of the fire
---@field last_updated_transform integer the tick the transform of the fire was last updated on, this is so we don't have to constantly get the fire's position if it couldn't have even changed.
---@field is_lit boolean if the fire is lit
---@field debug_data potentialAIFireDebugData? The debug data for this potential fire, only set it the flag ai_vehicle_fire_debug is enabled

---@class AIFire
---@field object_id integer the fire's object_id
---@field parent_vehicle_id integer the vehicle_id the fire is attached to
---@field spawned_at integer the tick the fire was spawned on
---@field despawn_timer_multiplier number the despawn timer multiplier, ranges from 0.5 to 1.
---@field voxel_pos SWVoxelPos the voxel position of the fire.

---@class AIVehicleWithFire
---@field fire_count integer the number of fires on this vehicle
---@field fires table<integer, AIFire> the fires attached to this vehicle

g_savedata.libraries.vehicle_fires = {
	potential_ai_fires = {}, ---@type table<integer, potentialAIFire>
	--ai_fires = {}, ---@type table<integer, AIFire>
	ai_vehicles_with_fires = {} ---@type table<integer, AIVehicleWithFire>
}

-- how many seconds until it assumes the fire is not on an AI vehicle.
local potential_fire_timeout = time.second*10

---# Removes an AI fire.
---@param ai_fire_data AIFire the ai fire to remove
function VehicleFires.removeAIFire(ai_fire_data)

	-- despawn the fire
	server.despawnObject(ai_fire_data.object_id, true)

	local g_vehicle_fires = g_savedata.libraries.vehicle_fires

	-- find and remove it from ai_fires
	--[[for ai_fire_index = 1, #g_vehicle_fires.ai_fires do
		if g_vehicle_fires.ai_fires[ai_fire_index].object_id == ai_fire_data.object_id then
			table.remove(g_vehicle_fires.ai_fires, ai_fire_index)
			break
		end
	end]]

	-- remove it from ai_vehicles_with_fires
	local ai_vehicle_with_fire = g_vehicle_fires.ai_vehicles_with_fires[ai_fire_data.parent_vehicle_id]

	-- if this is the last fire, just remove the vehicle
	if ai_vehicle_with_fire.fire_count == 1 then
		-- cannot just set ai_vehicle_with_fire directly, as thats aliased.
		g_vehicle_fires.ai_vehicles_with_fires[ai_fire_data.parent_vehicle_id] = nil
		return
	end

	-- find and remove this fire from the vehicle's fire list
	for ai_vehicle_fire_index = 1, ai_vehicle_with_fire.fire_count do
		if ai_vehicle_with_fire.fires[ai_vehicle_fire_index].object_id == ai_fire_data.object_id then
			-- remove this fire
			table.remove(ai_vehicle_with_fire.fires, ai_vehicle_fire_index)
			break
		end
	end

	-- remove this fire from the count
	ai_vehicle_with_fire.fire_count = ai_vehicle_with_fire.fire_count - 1
end

function VehicleFires.tickFires()
	-- start from top and go down, as we will be removing fires along the way.
	for potential_fire_index = #g_savedata.libraries.vehicle_fires.potential_ai_fires, 1, -1 do
		local potential_fire_data = g_savedata.libraries.vehicle_fires.potential_ai_fires[potential_fire_index]

		if g_savedata.flags.ai_vehicle_fire_debug then
			potential_fire_data.debug_data = potential_fire_data.debug_data or {
				ui_id = server.getMapID(),
				closest_damage = 999
			}
			
			potential_fire_data.transform, _ = server.getObjectPos(potential_fire_data.object_id)

			potential_fire_data.is_lit, _ = server.getFireData(potential_fire_data.object_id)

			-- draw it's popup
			server.setPopup(
				-1,
				potential_fire_data.debug_data.ui_id,
				"Potential Fire "..potential_fire_index,
				true,
				("Closest Damage: %0.3fm\nIs Lit: %s"):format(potential_fire_data.debug_data.closest_damage, potential_fire_data.is_lit), 
				potential_fire_data.transform[13],
				potential_fire_data.transform[14],
				potential_fire_data.transform[15],
				0,
				0,
				0
			)
		end

		-- if this fire is not lit, then bump its spawned at timer.
		local is_lit, is_success = server.getFireData(potential_fire_data.object_id)

		potential_fire_data.is_lit = is_lit

		if not is_lit then
			potential_fire_data.spawned_at = g_savedata.tick_counter
			goto next_fire
		end

		-- check if the fire has lasted too long
		if g_savedata.tick_counter - potential_fire_data.spawned_at >= potential_fire_timeout then

			-- remove it from the map if its got debug data
			if potential_fire_data.debug_data then
				server.removeMapID(-1, potential_fire_data.debug_data.ui_id)
			end
			-- its lasted too long, remove it.
			table.remove(g_savedata.libraries.vehicle_fires.potential_ai_fires, potential_fire_index)
		end

		::next_fire::
	end
end

function VehicleFires.tickVehicles()
	-- get the flags, this is to save a little bit of performance by not needing to index the table constantly
	local g_savedata_flags = g_savedata.flags

	local ai_vehicle_fire_limit = g_savedata_flags.ai_vehicle_fire_limit
	local ai_vehicle_fire_despawn_timer = g_savedata_flags.ai_vehicle_fire_despawn_timer
	local killed_ai_vehicle_fire_despawn_timer = g_savedata_flags.killed_ai_vehicle_fire_despawn_timer
	local vehicle_fire_tickrate = g_savedata_flags.ai_vehicle_fire_tick_rate

	local g_vehicle_fires = g_savedata.libraries.vehicle_fires

	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		for _, vehicle_object in pairs(squad.vehicles) do
			if not isTickID(vehicle_object.id, vehicle_fire_tickrate) then
				goto next_vehicle
			end

			local vehicle_fire_data = g_vehicle_fires.ai_vehicles_with_fires[vehicle_object.id]

			-- if this vehicle doesn't have any data with this.
			if not vehicle_fire_data then
				goto next_vehicle
			end

			--[[
				
				tick the fire limit

			]]

			-- check if its enabled
			if ai_vehicle_fire_limit ~= -1 then

				-- the number of fires to remove from the vehicle, this is how many fires the vehicle has thats over the limit.
				local fires_to_remove = vehicle_fire_data.fire_count - ai_vehicle_fire_limit

				-- if theres no fires to remove, then we dont have to remove any fires from this vehicle
				if fires_to_remove < 1 then
					goto skip_tick_fire_limit
				end

				--[[
					remove the fires until we no longer are over the limit, 
					by removing the fire with index 1, we are removing the oldest fire on the vehicle.
				]]
				for _ = 1, fires_to_remove do
					VehicleFires.removeAIFire(vehicle_fire_data.fires[1])
				end
			end

			::skip_tick_fire_limit::

			--[[
				
				tick the fire despawn timer

			]]

			-- if the vehicle is killed, use the despawn timer for killed vehicles, otherwise just use the normal one.
			local fire_despawn_timer = vehicle_object.is_killed and killed_ai_vehicle_fire_despawn_timer or ai_vehicle_fire_despawn_timer

			-- skip if disabled
			if fire_despawn_timer == -1 then
				goto next_vehicle
			end

			-- check if the fires are over the despawn timer
			for fire_index = 1, vehicle_fire_data.fire_count do
				local ai_fire_data = vehicle_fire_data.fires[fire_index]

				-- if this fire hit it's despawn timer
				if g_savedata.tick_counter - ai_fire_data.spawned_at >= fire_despawn_timer * ai_fire_data.despawn_timer_multiplier then
					-- despawn it, as it's hit it's despawn timer
					d.print(("Removing fire %s from vehicle id %s as its reached its despawn timer."):format(ai_fire_data.object_id, vehicle_object.id), true, 0)

					VehicleFires.removeAIFire(ai_fire_data)
				end
			end

			::next_vehicle::
		end
	end
end

function VehicleFires.tick(game_ticks)
	VehicleFires.tickFires()
	VehicleFires.tickVehicles()
end

function VehicleFires.onFireSpawn(object_id, object_data)
	-- add this fire to the potential fires table

	local fire_pos, got_pos = server.getObjectPos(object_id)

	if not got_pos then
		d.print("(VehicleFires.onFireSpawn) Failed to get the position for the fire "..object_id, true, 1)
	end

	table.insert(g_savedata.libraries.vehicle_fires.potential_ai_fires, {
		object_id = object_id,
		spawned_at = g_savedata.tick_counter,
		transform = fire_pos,
		last_updated_transform = g_savedata.tick_counter,
		debug_data = g_savedata.flags.ai_vehicle_fire_debug and {
			ui_id = server.getMapID(),
			closest_damage = 999
		} or nil
	})
end

local fire_damage_link_distance = 10
function VehicleFires.onAIVehicleDamaged(vehicle_id, voxel_pos, damage_amount)
	for potential_fire_index = 1, #g_savedata.libraries.vehicle_fires.potential_ai_fires do

		local potential_fire_data = g_savedata.libraries.vehicle_fires.potential_ai_fires[potential_fire_index]

		-- if this fire is not lit, skip it
		if not potential_fire_data.is_lit then
			goto next_fire
		end

		-- if the transform of this fire has not been updated this tick, then update it
		if g_savedata.tick_counter - potential_fire_data.last_updated_transform ~= 0 then

			-- update the transform
			local fire_pos, got_pos = server.getObjectPos(potential_fire_data.object_id)

			if not got_pos then
				d.print("(VehicleFires.onAIVehicleDamaged) Failed to get the position for the fire "..potential_fire_data.object_id, true, 1)
				goto next_fire
			end

			potential_fire_data.transform = fire_pos

			-- set the time the transform was last updated
			potential_fire_data.last_updated_transform = g_savedata.tick_counter
		end

		local damage_pos, _ = server.getVehiclePos(vehicle_id, voxel_pos.x, voxel_pos.y, voxel_pos.z)

		local damage_distance = matrix.distance(damage_pos, potential_fire_data.transform)

		-- if the fire debug is enabled.
		if g_savedata.flags.ai_vehicle_fire_debug then
			-- ensure that the debug data exists, to avoid an error.
			if potential_fire_data.debug_data then
				potential_fire_data.debug_data.closest_damage = math.min(
					potential_fire_data.debug_data.closest_damage,
					damage_distance
				)
			else
				potential_fire_data.debug_data = {
					closest_damage = damage_distance,
					ui_id = server.getMapID()
				}
			end
		end

		-- check if the damage was close enough to this fire
		if damage_distance <= fire_damage_link_distance then
			-- this fire is (maybe) on this vehicle, link it to it and remove it from the potential ai fires table

			local ai_fire_data = {
				object_id = potential_fire_data.object_id,
				parent_vehicle_id = vehicle_id,
				spawned_at = potential_fire_data.spawned_at,
				despawn_timer_multiplier = math.randomDecimals(0.5, 1),
				voxel_pos = voxel_pos
			}

			--table.insert(g_savedata.libraries.vehicle_fires.ai_fires, ai_fire_data)

			-- add this as a vehicle that has a fire
			local vehicle_fire_data = g_savedata.libraries.vehicle_fires.ai_vehicles_with_fires[vehicle_id]

			-- if this vehicle has not had a fire yet, create the data for it
			if not vehicle_fire_data then
				vehicle_fire_data = {
					fire_count = 0,
					fires = {}
				}
			end

			-- add this fire to it's fires list
			vehicle_fire_data.fire_count = vehicle_fire_data.fire_count + 1
			table.insert(vehicle_fire_data.fires, ai_fire_data)

			-- save it, as the variable is not aliased.
			g_savedata.libraries.vehicle_fires.ai_vehicles_with_fires[vehicle_id] = vehicle_fire_data

			-- remove it from the potential ai fires table
			table.remove(g_savedata.libraries.vehicle_fires.potential_ai_fires, potential_fire_index)

			-- we dont need to continue checking for more, so break
			break
		end

		::next_fire::
	end
end

function VehicleFires.onAIVehicleDespawn(vehicle_id)
	local vehicle_fire_data = g_savedata.libraries.vehicle_fires.ai_vehicles_with_fires[vehicle_id]

	-- skip if this vehicle has no fire data
	if not vehicle_fire_data then
		return
	end

	-- this vehicle had fire data, remove all of them.
	for _ = 1, vehicle_fire_data.fire_count do
		VehicleFires.removeAIFire(vehicle_fire_data.fires[1])
	end
end

--[[


Flag Registers


]]

--[[
Boolean Flags
]]

--[[
	ai_vehicle_fire_debug flag,
	Controls whether if the ai vehicle fire debug is shown or not, shows stuff like where the fires are, and where the damage is taking place.
]]
Flag.registerBooleanFlag(
	"ai_vehicle_fire_debug",
	false,
	{
		"fire",
		"vehicle",
		"ai",
		"debug",
		"medium performance impact"
	},
	"admin",
	"admin",
	function(value) -- remove all of the popups from the screen relating to the potential ai fires
		-- we don't need to do any code if it was enabled.
		if not value then return end

		-- remove all of the potential ai fire popups.
		for potential_fire_index = 1, #g_savedata.libraries.vehicle_fires.potential_ai_fires do
			local potential_fire_data = g_savedata.libraries.vehicle_fires.potential_ai_fires[potential_fire_index]

			if potential_fire_data.debug_data then

				-- remove everything drawn with this ui_id
				server.removeMapID(-1, potential_fire_data.debug_data.ui_id)

				-- remove the debug data
				potential_fire_data.debug_data = nil
			end
		end
	end,
	"Controls whether if the ai vehicle fire debug is shown or not, shows stuff like where the fires are, and where the damage is taking place."
)

--[[
Number Flags
]]

--[[
	ai_vehicle_fire_limit flag,
	Controls the maximum number of fires that can be on an AI vehicle, set to -1 to disable.
]]
Flag.registerNumberFlag(
	"ai_vehicle_fire_limit",
	5,
	{
		"fire",
		"vehicle",
		"ai",
		"heavy positive performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls the maximum number of fires that can be on an AI vehicle, set to -1 to disable.",
	-1,
	nil
)

--[[
	ai_vehicle_fire_despawn_timer flag,
	Controls how long a fire will last on an ai vehicle, in seconds, set to -1 to never despawn the fire.
]]
Flag.registerNumberFlag(
	"ai_vehicle_fire_despawn_timer",
	120,
	{
		"fire",
		"vehicle",
		"ai",
		"heavy positive performance impact"
	},
	"admin",
	"admin",
	nil,
	"Controls how long a fire will last on an ai vehicle, in seconds, set to -1 to never despawn the fire.",
	-1,
	nil
)

--[[
	killed_ai_vehicle_fire_despawn_timer flag,
	Controls how long a fire will last on a killed ai vehicle, in seconds, set to -1 to never despawn the fire.
]]
Flag.registerNumberFlag(
	"killed_ai_vehicle_fire_despawn_timer",
	10,
	{
		"fire",
		"vehicle",
		"ai",
		"heavy positive performance impact"
	},
	"admin",
	"admin",
	nil,
	"Controls how long a fire will last on a killed ai vehicle, in seconds, set to -1 to never despawn the fire.",
	-1,
	nil
)


--[[
	ai_vehicle_fire_tick_rate flag,
	Controls over how many ticks are the ai vehicles spread out across for ticking, also works as an update rate.
]]
Flag.registerNumberFlag(
	"ai_vehicle_fire_tick_rate",
	240,
	{
		"fire",
		"vehicle",
		"ai",
		"low positive performance impact",
		"tick"
	},
	"admin",
	"admin",
	nil,
	"Controls over how many ticks are the ai vehicles spread out across for ticking, also works as an update rate.",
	0,
	nil
)