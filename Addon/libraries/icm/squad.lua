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

---@class squadron
---@field index integer the index of this squadron
---@field command SQUAD_COMMAND the squadron's command
---@field vehicle_type VEHICLE_TYPE the vehicle type this squadron is made up of
---@field role string the role this squadron has
---@field vehicles table<integer, vehicle_object> the vehicles in this squadron
---@field target_island ISLAND? the island this squadron is targetting
---@field target_vehicles table<integer, TargetVehicle>|nil the vehicles this squadron is targetting
---@field target_players table<integer, TargetPlayer>|nil the players this squadron is targetting
---@field investigate_transform SWMatrix|nil the transform this squadron is investigating *(only set when command is INVESTIGATE)*

--[[


	Functions         


]]

---------------------------
--- Squad Lookups
---------------------------

--- given a group_id, returns the squad index its from and the squad's data. returns nil if not in a squad
--- @param group_id integer the id of the group you want to get the squad ID of
--- @return integer|nil squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
--- @return squadron|nil squad the info of the squad, if not found, then returns nil
function Squad.getSquadFromGroup(group_id)
	local squad_index = g_savedata.ai_army.squad_vehicles[group_id]
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

--- given a squad index, returns the squad's data. returns nil if not found
--- @param squad_index integer the index of the squad you want to get
--- @return squadron? squad the info of the squad, if not found, then returns nil
function Squad.getSquadFromIndex(squad_index)
	return g_savedata.ai_army.squadrons[squad_index]
end

---
---	@param group_id integer the group's id
---	@return vehicle_object? vehicle_object the vehicle object, nil if not found
---	@return integer? squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---	@return squadron? squad the info of the squad, if not found, then returns nil
function Squad.getVehicle(group_id) -- input a group's id, and it will return the vehicle_object, the squad index its from and the squad's data

	local vehicle_object = nil
	local squad_index = nil
	local squad = nil

	if not group_id then -- makes sure vehicle id was provided
		d.print("(Squad.getVehicle) group_id is nil!", true, 1)
		return vehicle_object, squad_index, squad
	else
		squad_index, squad = Squad.getSquadFromGroup(group_id)
	end

	if not squad_index or not squad then -- if we were not able to get a squad index then return nil
		return vehicle_object, squad_index, squad
	end

	vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[group_id]

	if not vehicle_object then
		d.print("(Squad.getVehicle) failed to get vehicle_object for group with id "..tostring(group_id).." and in a squad with the id of "..tostring(squad_index).." and with the vehicle_type of "..tostring(squad.vehicle_type), true, 1)
	end

	return vehicle_object, squad_index, squad
end

---------------------------
--- Squad Management
---------------------------

--- Creates a new squad based off a vehicle_object. **The vehicle will not be automatically added to the squad**, you must manually add it using `Squad.addVehicle`
--- @param squad_index integer? the squad's index which you want to create it under, if not specified it will use the next available index
--- @param vehicle_object vehicle_object the vehicle object which is adding to the squad
--- @return integer squad_index the index of the squad
--- @return boolean squad_created if the squad was successfully created
function Squad.create(squad_index, vehicle_object)

	local squad_index = squad_index or #g_savedata.ai_army.squadrons + 1

	if not vehicle_object then
		d.print("(Squad.create) vehicle_object is nil!", true, 1)
		return squad_index, false
	end

	if g_savedata.ai_army.squadrons[squad_index] then
		d.print("(Squad.create) Squadron "..tostring(squad_index).." already exists!", true, 1)
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

--- Returns the first vehicle in the squad returned by pairs to use as the leader of the squad
--- @param squad squadron
--- @return vehicle_object? vehicle_object nil if the squad is empty
function Squad.getLeader(squad)
	if not squad then
		d.print("(Squad.getLeader) squad is nil!", true, 1)
		return nil
	end

	for _, vehicle_object in pairs(squad.vehicles) do
		return vehicle_object
	end

	-- Squad is empty
	-- Do not try to "fix" by disbanding here, as this can get called while in the processing of creating a squad
	return nil
end

--- Adds a vehicle to the specified squad.
--- @param squad squadron the squad to add the vehicle to
--- @param vehicle_object vehicle_object the vehicle to add to the squad
--- @param force boolean? if you want to force the vehicle into the squad, bypassing the limits defined in `Squad.canJoinSquad`
--- @return boolean success if the addition was successful
function Squad.addVehicle(squad, vehicle_object, force)
	if not squad then
		d.print("(Squad.addVehicle) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.addVehicle) vehicle_object is nil!", true, 1)
		return false
	end
	
	-- Check if the vehicle can join the squad
	if not force and not Squad.canJoinSquad(squad, vehicle_object) then
		return false
	end

	-- Add the vehicle to the squad
	squad.vehicles[vehicle_object.group_id] = vehicle_object
	g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = squad.index

	-- Init the vehicle with the squads current command
	squadInitVehicleCommand(squad, vehicle_object)

	d.print("(Squad.addVehicle) Added vehicle "..tostring(vehicle_object.group_id).." ("..vehicle_object.vehicle_type..") to squad "..tostring(squad.index), true, 0)

	return true
end

--- Removes a vehicle from the specified squad. If this is the last vehicle in the squad, the squad will be automatically disbanded
--- @param squad squadron the squad to remove the vehicle from
--- @param vehicle_object vehicle_object the vehicle to remove from the squad
--- @param is_disbanding boolean? if the vehicle is being removed because the squad is being disbanded. This is used internally to prevent extra disband calls when disbanding
--- @return boolean success if the removal was successful
function Squad.removeVehicle(squad, vehicle_object, is_disbanding)
	if not squad then
		d.print("(Squad.removeVehicle) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.removeVehicle) vehicle_object is nil!", true, 1)
		return false
	end
	if not squad.vehicles or not squad.vehicles[vehicle_object.group_id] then
		d.print("(Squad.removeVehicle) vehicle "..tostring(vehicle_object.group_id).." is not in the specified squad!", true, 1)
		return false
	end

	squad.vehicles[vehicle_object.group_id] = nil

	if g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] == squad.index then
		-- Need to check because this might have already been overwritten if the vehicle is being transferred
		g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = nil
	end

	--? If:
	--? 1. The squad is now empty
	--? 2. The squad is not the resupply squad
	--? Then disband the squad
	if table.length(squad.vehicles) == 0 and squad.index ~= RESUPPLY_SQUAD_INDEX  and not is_disbanding then
		Squad.disband(squad.index, "squad empty")
	end

	d.print("(Squad.removeVehicle) Removed vehicle "..tostring(vehicle_object.group_id).." ("..vehicle_object.vehicle_type..") from squad "..tostring(squad.index), true, 0)
	return true
end

--- Safely disbands/deletes the specified squad
--- @param squad_index integer the squad you want to disband.
--- @param reason string? the reason for disbanding the squad. Doesn't affect the disbanding process at all, just used for debugging
--- @return boolean success if the disband was successful
function Squad.disband(squad_index, reason)
	-- Input Validation
	if type(squad_index) ~= "number" then
		d.print("(Squad.disband) squad_index expected number, got "..type(squad_index), true, 1)
		return false
	end
	if squad_index < 0 or squad_index == RESUPPLY_SQUAD_INDEX then
		d.print("(Squad.disband) squad_index out of bounds: "..tostring(squad_index), true, 1)
		return false
	end

	-- Get the squad to disband
	local squad = Squad.getSquadFromIndex(squad_index)
	if not squad then
		d.print("(Squad.disband) squad with index "..tostring(squad_index).." does not exist!", true, 1)
		return false
	end

	-- Remove all vehicles still inside the squad
	for _, vehicle_object in pairs(squad.vehicles) do
		Squad.removeVehicle(squad, vehicle_object, true)
	end

	-- Delete the squad from the squadrons table
	g_savedata.ai_army.squadrons[squad_index] = nil

	-- Remove all references to this squad from islands
	for island_index, island in pairs(g_savedata.islands) do
		if island.assigned_squad_index == squad_index then
			island.assigned_squad_index = -1
		end
	end

	d.print("(Squad.disband) Disbanded squad "..tostring(squad_index).." for reason: "..(reason or "Unknown"), true, 0)
	return true
end


--- Sets the command for a given squad if its allowed.<br>
--- The third parameter is optional and is used for setting extra variables required by the command. See the overloads at the bottom of the documentation for more information.<br>
--- ### Restrictions which will result in a failure:
--- - Attempting to set a squad to the same command it already has
--- - Attempting to change a scout squad to any command other than defend
--- - Attempting to change a cargo squad *(cargo vehicles are locked as cargo)*
--- @param squad squadron
--- @param command SQUAD_COMMAND
--- @vararg nil
--- @return boolean success if the command was successfully set. If false, then either the parameters are invalid or theres a restriction blocking it
--- @overload fun(squad:squadron, command:"attack"|"stage"|"defend"|"patrol", target_island: ISLAND):boolean
--- @overload fun(squad:squadron, command:"investigate", investigate_transform: SWMatrix):boolean
function Squad.setCommand(squad, command, ...)
	-- Input validation
	if not squad then
		d.print("(Squad.setCommand) squad is nil!", true, 1)
		return false
	end
	if not command then
		d.print("(Squad.setCommand) command is nil!", true, 1)
		return false
	end

	local old_command = squad.command
	if old_command == command then
		return false
	end

	-- Scouts can only be changed to defend
	if old_command == SQUAD.COMMAND.SCOUT and command ~= SQUAD.COMMAND.DEFEND then
		return false
	end

	-- Once in cargo mode, you can never leave it
	if old_command == SQUAD.COMMAND.CARGO then
		return false
	end

	-- The squad is able to be set to the new command
	-- Before setting the new command, first check for extra parameters for the command
	-- Check if theres anything in ...
	local extra_params = {...}
	if #extra_params > 0 then
		-- Decide what to do based on the command
		local COMMAND_PARAM_MAP = {
			[SQUAD.COMMAND.ATTACK] = "target_island",
			[SQUAD.COMMAND.STAGE] = "target_island",
			[SQUAD.COMMAND.DEFEND] = "target_island",
			[SQUAD.COMMAND.PATROL] = "target_island",
			[SQUAD.COMMAND.INVESTIGATE] = "investigate_transform"
		}
		if COMMAND_PARAM_MAP[command] then
			squad[COMMAND_PARAM_MAP[command]] = extra_params[1]
		else
			d.print("(Squad.setCommand) Unhandled extra parameter for command "..tostring(command), true, 1)
		end
	end

	-- Change the squad's command
	squad.command = command

	-- Reinit the squad's vehicles with the new command
	for _, vehicle_object in pairs(squad.vehicles) do
		squadInitVehicleCommand(squad, vehicle_object)
	end

	-- Squad value cleanup ported from the original setSquadronCommand function
	if command == SQUAD.COMMAND.NONE then
		squad.target_island = nil
	elseif command == SQUAD.COMMAND.INVESTIGATE then
		squad.target_players = {}
		squad.target_vehicles = {}
	end
	return true
end

--- Returns whether or not the squad can access a given island
--- @param squad squadron the squad to check
--- @param island ISLAND the island to check
--- @return boolean can_access whether or not the squad can access the island
--- @return boolean is_success whether or not the function executed successfully
function Squad.canAccessIsland(squad, island)
	-- Input validation
	if not squad then
		d.print("(Squad.canAccessIsland) squad is nil!", true, 1)
		return false, false
	end
	if not island then
		d.print("(Squad.canAccessIsland) island is nil!", true, 1)
		return false, false
	end

	if squad.vehicle_type == VEHICLE.TYPE.LAND then
		-- Land vehicles can only access islands they have land access to
		local squad_leader = Squad.getLeader(squad)
		if squad_leader then
			local island_land_access = Tags.getValue(island.tags, "land_access", true)
			local leader_land_access = Tags.getValue(squad_leader.home_island.tags, "land_access", true)
			if island_land_access ~= leader_land_access then
				return false, true
			end
		end
	elseif squad.vehicle_type == VEHICLE.TYPE.BOAT then
		-- Boat vehicles cant get to islands with no_access=boat tags
		if Tags.has(island.tags, "no_access=boat") then
			d.print("(Squad.canAccessIsland) Boat vehicle squad "..tostring(squad.index).." cannot access island "..island.name.." due to no_access=boat tag", true, 0)
			return false, true
		end
	end

	return true, true
end

--- Returns a full list of **AI controlled** islands that the squad can reach 
--- @param squad squadron
--- @param faction FACTION? the faction you want to filter by. If not specified, it will return all islands
function Squad.getReachableIslands(squad, faction)
	-- Input validation
	if not squad then
		d.print("(Squad.getReachableIslands) squad is nil!", true, 1)
		return {}
	end

	local reachable_islands = {}
	for _, island in pairs(g_savedata.islands) do
		if not faction or island.faction == faction then
			local can_access, success = Squad.canAccessIsland(squad, island)
			if success and can_access then
				table.insert(reachable_islands, island)
			end
		end
	end
	return reachable_islands
end

--- @param squad squadron
function Squad.getRandomReachableIsland(squad)
	local reachable_islands = Squad.getReachableIslands(squad, ISLAND.FACTION.AI)
	if #reachable_islands == 0 then
		return nil
	end
	return reachable_islands[math.random(1, #reachable_islands)]
end

---------------------------
--- Vehicle Helpers
---------------------------

--- Checks if a vehicle can join the specified squad
--- @param squad squadron the squad to check
--- @param vehicle_object vehicle_object the vehicle to check
function Squad.canJoinSquad(squad, vehicle_object)
	-- Input validation
	if not squad then
		d.print("(Squad.canJoinSquad) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.canJoinSquad) vehicle_object is nil!", true, 1)
		return false
	end
	
	-- Must be of the same vehicle type
	if squad.vehicle_type ~= vehicle_object.vehicle_type then
		return false
	end
	
	-- Must be of the same role
	if squad.role ~= vehicle_object.role then
		return false
	end
	
	-- Land vehicles must be able be access eachother (ie, a vehicle in arid cant join a squad in sawyer)
	if squad.vehicle_type == VEHICLE.TYPE.LAND then
		-- Get the squad leader, if there is no squad leader then skip this check
		local squad_leader = Squad.getLeader(squad)
		if squad_leader then
			-- Get the land mass that the squad leader is on
			local leader_land_access = Tags.getValue(squad_leader.home_island.tags, "land_access", true)
			local vehicle_land_access = Tags.getValue(vehicle_object.home_island.tags, "land_access", true)
			if leader_land_access ~= vehicle_land_access then
				return false
			end
		end
	end
	
	-- Non scout vehicles cannot join scout squads
	if vehicle_object.role ~= "scout" and squad.role == "scout" then
		return false
	end

	-- Non cargo vehicles cannot join cargo squads
	if vehicle_object.role ~= "cargo" and squad.role == "cargo" then
		return false
	end

	-- Squad can not be full
	if table.length(squad.vehicles) >= MAX_SQUAD_SIZE then
		return false
	end
	return true
end

--- Moves a vehicle from its current squad to another squad
--- @param vehicle_object vehicle_object the vehicle to transfer
--- @param new_squad_index integer the index of the squad to transfer the vehicle to
--- @param force boolean? if you want to force the vehicle over to the squad, bypassing any limits
--- @return boolean success if the transfer was successful
function Squad.transferToSquad(vehicle_object, new_squad_index, force)
	-- Input validation
	if not vehicle_object then
		d.print("(Squad.transferToSquad) vehicle_object is nil!", true, 1)
		return false
	end
	if not new_squad_index then
		d.print("(Squad.transferToSquad) new_squad_index is nil!", true, 1)
		return false
	end

	-- Get its old squad
	local old_squad_index, old_squad = Squad.getSquadFromGroup(vehicle_object.group_id)
	if old_squad_index and old_squad then
		vehicle_object.previous_squad = old_squad_index
	else
		d.print("(Squad.transferToSquad) Warning: Could not get old squad", true, 0)
	end
	
	-- Check if the new squad exists
	local new_squad = Squad.getSquadFromIndex(new_squad_index)
	if not new_squad then
		-- Create the squad if it doesn't already exist
		new_squad_index = Squad.create(new_squad_index, vehicle_object)
		new_squad = Squad.getSquadFromIndex(new_squad_index)
		if not new_squad then
			d.print("(Squad.transferToSquad) failed to create new squad with index "..tostring(new_squad_index), true, 1)
			return false
		end
	end

	-- Add to the new squad
	local added = Squad.addVehicle(new_squad, vehicle_object, force)
	if added and old_squad ~= nil then
		-- Remove from the old squad if it was in one
		if not Squad.removeVehicle(old_squad, vehicle_object) then
			--! Something went wrong, to prevent it from being in multiple squads, remove it form the new one
			d.print("(Squad.transferToSquad) failed to remove vehicle from old squad "..tostring(old_squad_index).."! This should never happen!", true, 1)
			if not Squad.removeVehicle(new_squad, vehicle_object) then
				d.print("(Squad.transferToSquad) Failed to undo changes, possible vehicle duplication inside squads", true, 0)
			end
			return false
		end
	elseif not added then
		d.print("(Squad.transferToSquad) failed to add vehicle to new squad "..tostring(new_squad_index).."!", true, 1)
		return false
	end

	d.print("(Squad.transferToSquad) Transferred "..vehicle_object.name.."("..vehicle_object.group_id..") from squadron "..tostring(old_squad_index).." to "..new_squad_index, true, 0)
	return true
end

--- Returns the best squad for a vehicle to join.
--- The squad must be able to accept the vehicle, and it will only take the smallest squads into consideration.
--- After getting the smallest squads, it will return the closest one to the vehicle.
--- @param vehicle_object vehicle_object the vehicle you want to find a squad for
--- @return squadron? squad the best squad for the vehicle to join, nil if no valid squads were found
function Squad.getBestSquadForVehicle(vehicle_object)
	-- Gets the squads which can be joined and is the smallest in the world
	local canidates = {}
	local smallest_size = math.huge
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		if Squad.canJoinSquad(squad, vehicle_object) then
			if #squad.vehicles < smallest_size then
				smallest_size = #squad.vehicles
				canidates = {}
			end
			table.insert(canidates, squad)
		end
	end

	if #canidates <= 0 then
		return nil
	end

	-- Sort by distance to the vehicle
	local vehicle_transform = vehicle_object.transform
	table.sort(canidates, function(a, b)
		local a_leader = Squad.getLeader(a)
		local b_leader = Squad.getLeader(b)
		if not a_leader then return false end -- Force it to the end if invalid for some reason
		if not b_leader then return true end -- Force it to the end if invalid for some reason
		local a_distance = matrix.xzDistance(vehicle_transform, a_leader.transform)
		local b_distance = matrix.xzDistance(vehicle_transform, b_leader.transform)
		return a_distance < b_distance
	end)

	-- Return the closest canidate
	return canidates[1]
end