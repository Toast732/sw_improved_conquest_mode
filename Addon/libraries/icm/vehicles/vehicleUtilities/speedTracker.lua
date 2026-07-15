--[[
	
Copyright 2025 Liam Matthews

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
	Tracks the speeds of vehicles, used to integrate the speed tracker into the vehicle system

	Able to support a set amount of resolutions, or a specified one.

	Code isn't the cleanest and is a bit confusing, as trying get good type and variable names is difficult due to the amount of optimisations being done for this.
]]

-- library name
VehicleSpeedTracker = {}

--[[


	Classes


]]

---@alias VehicleSpeedTrackerID integer the id of the speed tracker. Used to index the table of the speed data.

---@class VehicleSpeedTrackerData
---@field vehicle_id integer the id of the vehicle it is tracking the speed of
---@field tracker_id VehicleSpeedTrackerID the id of the speed tracker.
---@field update_rate VehicleSpeedTrackerUpdateRateResolution the update rate of this speed tracker.
---@field smoothing_amount integer the number of entries back it will store and average from for outputting the speed.
---@field speed number the speed of the vehicle in m/s.
---@field speed_history table<integer, number> the raw calculated speed history.
---@field last_vector Vector3 the previous position of the vehicle.
---@field last_updated_tick integer the last tick the speed was updated.

---@alias VehicleSpeedTrackerTickerData table<integer, VehicleSpeedTrackerID> indexed by their tick id, stores the tracker id for the vehicle.

---@alias VehicleSpeedTrackerTickers table<VEHICLE_SPEED_TRACKER_UPDATE_RATE, VehicleSpeedTrackerTickerData> indexed by the ticker update rate, stores the ticker data.

--[[


	Constants


]]

---@enum VehicleSpeedTrackerUpdateRateResolution
VEHICLE_SPEED_TRACKER_UPDATE_RATE = {
	PERFECT = 1, -- update speed every tick
	HIGH = 10, -- update speed every 10 ticks
	MEDIUM = time.second * 0.5, -- update speed every 500ms (30 ticks)
	LOW = time.second * 2, -- update speed every 2s (120 ticks)
	EXTREMELY_LOW = time.second*5 -- update speed every 5s (300 ticks)
}

--[[


	Variables


]]

g_savedata.libraries.vehicle_speed_tracker = {

	---@type VehicleSpeedTrackerTickers
	tickers = {}, -- Stores the data for the tickers, iterated through in onTick

	---@type table<VehicleSpeedTrackerID, VehicleSpeedTrackerData>
	trackers = {}, -- Stores the data for the vehicles, indexed by their tracker id.

	---@type VehicleSpeedTrackerID
	next_tracker_id = 1 -- The next id to assign.
}

--[[


	Functions


]]

--[[

	External Usage

]]

--- Used to setup a vehicle to have it's speed tracked.
---@param vehicle_id integer the vehicle_id of the vehicle to track.
---@param update_rate VehicleSpeedTrackerUpdateRateResolution the update rate resolution.
---@param smoothing_amount integer the number of ticks to smooth between.
---@return VehicleSpeedTrackerID|nil tracker_id the id of the tracker, nil on error.
---@return boolean is_success if it successfully created the speed tracker.
function VehicleSpeedTracker.track(vehicle_id, update_rate, smoothing_amount)

	-- Get the vehicle's current matrix
	local current_pos, is_success = server.getVehiclePos(vehicle_id)

	-- If it failed, return early.
	if not is_success then
		d.print(("(VehicleSpeedTracker.track) Failed to get position of vehicle %s, aborting creation of the speed tracker."):format(vehicle_id), true, 0)
		return -1, false
	end

	-- Get the tracker id
	local tracker_id = g_savedata.libraries.vehicle_speed_tracker.next_tracker_id

	-- Increment the next tracker id
	g_savedata.libraries.vehicle_speed_tracker.next_tracker_id = g_savedata.libraries.vehicle_speed_tracker.next_tracker_id + 1

	-- Create the tracker
	---@type VehicleSpeedTrackerData
	local tracker_data = {
		vehicle_id = vehicle_id, -- set the vehicle_id
		tracker_id = tracker_id, -- set the tracker id
		update_rate = update_rate, -- set the update rate
		speed = 0, -- default the speed to 0
		smoothing_amount = smoothing_amount, -- set the smoothing amount
		speed_history = {}, -- default the speed history to be an empty table
		last_vector = Vector3.fromMatrix(current_pos, true), -- set the last vector as the current vector
		last_updated_tick = g_savedata.tick_counter - 1 -- Set the last updated tick to the previous tick, to prevent the onTick loop potentially iterating this on this tick, resulting in a divide by 0 error.
	}

	-- Store it in the trackers table
	g_savedata.libraries.vehicle_speed_tracker.trackers[tracker_id] = tracker_data

	-- If the table for this update rate has not been made, create it.
	g_savedata.libraries.vehicle_speed_tracker.tickers[update_rate] = g_savedata.libraries.vehicle_speed_tracker.tickers[update_rate] or {}

	-- Insert this tracker_id into the table for this update rate.
	table.insert(g_savedata.libraries.vehicle_speed_tracker.tickers[update_rate], tracker_id)

	-- Return is_success as true, and return the tracker_id.
	return tracker_id, true
end

--[[

	Callbacks

]]

--- Called by onTick, ticks the vehicles to update their speeds.
---@param game_ticks integer the number of ticks since the last tick.
function VehicleSpeedTracker.onTick(game_ticks)

	-- Iterate through all of the update rates
	for update_rate, potential_tracker_ids_to_update in pairs(g_savedata.libraries.vehicle_speed_tracker.tickers) do

		-- Get the tick id of the current tick
		local tick_id = g_savedata.tick_counter % update_rate

		-- Go through all of the vehicles to update.
		for 
			ticker_index = tick_id + 1, -- Start at the ticker id + 1, as tick ids start at 0.
			#potential_tracker_ids_to_update, -- Go until we hit the number of trackers on this tick.
			update_rate -- Increment by the update rate.
		do
			-- Update the vehicle's speed
			VehicleSpeedTracker.update(potential_tracker_ids_to_update[ticker_index])
		end
	end
end

--[[

	Internal Usage

]]

--- Update the speed of a vehicle
---@param tracker_id VehicleSpeedTrackerID the id of the tracker to update.
function VehicleSpeedTracker.update(tracker_id)
	--*INFO: does not validate very much, as this will be called by onTick very frequently, so minimising performance impact is a priority.

	-- Get the tracker data.
	local tracker_data = g_savedata.libraries.vehicle_speed_tracker.trackers[tracker_id]

	-- Get the vehicle's current matrix
	local current_position, _ = server.getVehiclePos(tracker_data.vehicle_id)

	-- Get the current position as a vector
	local current_vector = Vector3.fromMatrix(current_position)

	-- Get the speed, from the last vector and time since it was last updated.
	local current_speed = Vector3.euclideanDistance(
		current_vector,
		tracker_data.last_vector
	) * time.second/(g_savedata.tick_counter - tracker_data.last_updated_tick)

	-- Add the speed to the speed history table
	table.insert(tracker_data.speed_history, 1, current_speed)

	-- Get the number of speed entries for this tracker.
	local speed_entries = #tracker_data.speed_history

	-- If theres more speed entires than the smoothing amount, remove the last one
	if speed_entries > tracker_data.smoothing_amount then
		table.remove(tracker_data.speed_history, speed_entries)

		-- Remove 1 from the number of entries
		speed_entries = speed_entries - 1
	end

	-- If theres still more, remove them all.
	if speed_entries > tracker_data.smoothing_amount then
		speed_entries = 0
		tracker_data.speed_history = {}
	end

	-- Define the total speed.
	local total_speed = 0

	-- Total up all of the speeds
	for speed_index = 1, speed_entries do
		total_speed = total_speed + tracker_data.speed_history[speed_index]
	end

	-- Set and calculate the average speed.
	tracker_data.speed = total_speed/speed_entries

	-- Set the previous vector.
	tracker_data.last_vector = current_vector

	-- Set the time the speed was last updated to this tick.
	tracker_data.last_updated_tick = g_savedata.tick_counter
end