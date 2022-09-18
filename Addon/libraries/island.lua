-- required libraries
require("libraries.debugging")
require("libraries.players")
require("libraries.tags")

-- library name
local Island = {}

-- shortened library name
local is = Island

local ISLAND = {
	FACTION = {
		NEUTRAL = "neutral",
		AI = "ai",
		PLAYER = "player"
	}
}

-- checks if this island can spawn the specified vehicle
---@param island ISLAND the island you want to check if AI can spawn there
---@param selected_prefab selected_prefab[] the selected_prefab you want to check with the island
---@return boolean can_spawn if the AI can spawn there
function Island.canSpawn(island, selected_prefab)

	-- if this island is owned by the AI
	if island.faction ~= ISLAND.FACTION.AI then
		return false
	end

	-- this island can spawn this specific vehicle
	if not Tags.has(island.tags, "can_spawn="..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "")) and not Tags.has(selected_prefab.vehicle.tags, "role=scout") then -- if it can spawn at the island
		return false
	end

	local player_list = s.getPlayers()

	-- theres no players within 2500m (cannot see the spawn point)
	if not pl.noneNearby(player_list, island.transform, 2500, true) then
		return false
	end

	return true
end

--# returns the island data from the provided flag vehicle id (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param vehicle_id integer the vehicle_id of the island's flag vehicle
---@return ISLAND island the island the flag vehicle belongs to
---@return boolean got_island if the island was gotten
function Island.getDataFromVehicleID(vehicle_id)
	if g_savedata.ai_base_island.flag_vehicle.id == vehicle_id then
		return g_savedata.ai_base_island, true
	elseif g_savedata.player_base_island.flag_vehicle.id == vehicle_id then
		return g_savedata.player_base_island, true
	else
		for island_index, island in pairs(g_savedata.islands) do
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
---@return island[] island the island data from the name
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