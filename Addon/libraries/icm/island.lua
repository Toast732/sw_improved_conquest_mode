-- required libraries
require("libraries.addon.script.debugging")
require("libraries.addon.script.players")
require("libraries.addon.components.tags")

-- library name
Island = {}

-- shortened library name
is = Island

-- checks if this island can spawn the specified vehicle
---@param island ISLAND the island you want to check if AI can spawn there
---@param selected_prefab PREFAB_DATA the selected_prefab you want to check with the island
---@return boolean can_spawn if the AI can spawn there
function Island.canSpawn(island, selected_prefab)

	-- if this island is owned by the AI
	if island.faction ~= ISLAND.FACTION.AI then
		return false
	end

	-- if this vehicle is a turret
	if Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) == "wep_turret" then
		local has_spawn = false
		local total_spawned = 0

		-- check if this island even has any turret zones
		if not #island.zones.turrets then
			return false
		end

		for turret_zone_index = 1, #island.zones.turrets do
			if not island.zones.turrets[turret_zone_index].is_spawned then
				if not has_spawn and Tags.has(island.zones.turrets[turret_zone_index].tags, "turret_type="..Tags.getValue(selected_prefab.vehicle.tags, "role", true)) then
					has_spawn = true
				end
			else
				total_spawned = total_spawned + 1

				-- already max amount of turrets
				if total_spawned >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false
				end

				-- check if this island already has all of the turret spawns filled
				if total_spawned >= #island.zones.turrets then
					return false
				end
			end
		end

		-- if no valid turret spawn was found
		if not has_spawn then
			return false
		end
	else
		-- this island can spawn this specific vehicle
		if not Tags.has(island.tags, "can_spawn="..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "")) and not Tags.has(selected_prefab.vehicle.tags, "role=scout") then -- if it can spawn at the island
			return false
		end
	end

	-- theres no players within 2500m (cannot see the spawn point)
	if not pl.noneNearby(s.getPlayers(), island.transform, 2500, true) then
		return false
	end

	return true
end

--# returns the island data from the provided flag vehicle id (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param vehicle_id integer the vehicle_id of the island's flag vehicle
---@return ISLAND|AI_ISLAND|PLAYER_ISLAND|nil island the island the flag vehicle belongs to
---@return boolean got_island if the island was gotten
function Island.getDataFromVehicleID(vehicle_id)
	if g_savedata.ai_base_island.flag_vehicle.id == vehicle_id then
		return g_savedata.ai_base_island, true
	elseif g_savedata.player_base_island.flag_vehicle.id == vehicle_id then
		return g_savedata.player_base_island, true
	else
		for _, island in pairs(g_savedata.islands) do
			if island.flag_vehicle.id == vehicle_id then
				return island, true
			end
		end
	end

	return nil, false
end

--# returns the island data from the provided island index (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param island_index integer the island index you want to get
---@return ISLAND island the island data from the index
---@return boolean island_found returns true if the island was found
function Island.getDataFromIndex(island_index)
	if not island_index then -- if the island_index wasn't specified
		d.print("(Island.getDataFromIndex) island_index was never inputted!", true, 1)
		return nil, false
	end

	if g_savedata.islands[island_index] then
		-- if its a normal island
		return g_savedata.islands[island_index], true
	elseif island_index == g_savedata.ai_base_island.index then
		-- if its the ai's main base
		return g_savedata.ai_base_island, true
	elseif island_index == g_savedata.player_base_island.index then
		-- if its the player's main base
		return g_savedata.player_base_island, true 
	end

	d.print("(Island.getDataFromIndex) island was not found! inputted island_index: "..tostring(island_index), true, 1)

	return nil, false
end

--# returns the island data from the provided island name (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param island_name string the island name you want to get
---@return ISLAND island the island data from the name
---@return boolean island_found returns true if the island was found
function Island.getDataFromName(island_name) -- function that gets the island by its name, it doesnt care about capitalisation and will replace underscores with spaces automatically
	if island_name then
		island_name = string.friendly(island_name)
		if island_name == string.friendly(g_savedata.ai_base_island.name) then
			-- if its the ai's main base
			return g_savedata.ai_base_island, true
		elseif island_name == string.friendly(g_savedata.player_base_island.name) then
			-- if its the player's main base
			return g_savedata.player_base_island, true
		else
			-- check all other islands
			for _, island in pairs(g_savedata.islands) do
				if island_name == string.friendly(island.name) then
					return island, true
				end
			end
		end
	else
		return nil, false
	end
	return nil, false
end