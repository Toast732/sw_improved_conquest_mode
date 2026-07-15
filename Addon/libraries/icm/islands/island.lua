--[[


	Library Setup


]]
require("libraries.addon.script.debugging")
require("libraries.addon.script.players")
require("libraries.addon.components.tags")

-- library name
Island = {}

-- shortened library name
is = Island

--[[


	Classes


]]

---@class IslandZones
---@field turrets table
---@field land table
---@field sea table

---@class IslandCargo
---@field oil number
---@field jet_fuel number
---@field diesel number

---@class ISLAND
---@field name string
---@field index integer 
---@field flag_vehicle SWAddonComponentSpawned The flag vehicle spawned on the island
---@field transform SWMatrix The transform of the islands zone
---@field tags table<number, string>
---@field faction FACTION
---@field is_contested boolean
---@field capture_timer number
---@field ui_id SWUI_ID
---@field assigned_squad_index integer
---@field zones IslandZones
---@field payroll_multiplier number
---@field ai_capturing integer
---@field players_capturing integer
---@field defenders integer
---@field is_scouting boolean
---@field last_defended number
---@field cargo IslandCargo
---@field cargo_transfer IslandCargo
---@field object_type "island"
---@field production_timer number?

---@class AI_ISLAND: ISLAND
---@field production_timer number

---@class PLAYER_ISLAND: ISLAND

--[[


	Constants


]]

ISLAND_SETUP_MAIN_PRIORITY = 1 --TODO: Implement with binder

--[[


	Variables


]]

--[[


	Functions


]]

--- Creates a island class
---	@param island_data SWZone
---	@param island_index integer
---	@param faction FACTION
---	@param flag SWAddonComponentSpawned
---	@param capture_timer number
---	@param cargo_data table
---	@param production_timer number?
---	@return ISLAND island
function Island.createIslandData(island_data, island_index, faction, flag, capture_timer, cargo_data, production_timer)
	local island = {
		name = island_data.name,
		index = island_index,
		flag_vehicle = flag,
		transform = island_data.transform,
		tags = island_data.tags,
		faction = faction,
		is_contested = false,
		capture_timer = capture_timer,
		ui_id = server.getMapID() --[[@as SWUI_ID]],
		assigned_squad_index = -1,
		zones = {
			turrets = {},
			land = {},
			sea = {}
		},
		payroll_multiplier = Tags.getValue(island_data.tags, "payroll_multiplier", false) or 1,
		ai_capturing = 0,
		players_capturing = 0,
		defenders = 0,
		is_scouting = false,
		last_defended = 0,
		cargo = {
			oil = cargo_data.oil,
			jet_fuel = cargo_data.jet_fuel,
			diesel = cargo_data.diesel
		},
		cargo_transfer = {
			oil = 0,
			jet_fuel = 0,
			diesel = 0
		},
		object_type = "island"
	}

	if production_timer ~= nil then
		island.production_timer = production_timer
	end

	return island
end

---Checks if this island can spawn the specified vehicle
---@param island ISLAND the island you want to check if AI can spawn there
---@param selected_prefab PREFAB_DATA the selected_prefab you want to check with the island
---@return boolean can_spawn if the AI can spawn there
function Island.canSpawnPrefab(island, selected_prefab)
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
		local vehicle_type = Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) or ""
		if not Tags.has(island.tags, "can_spawn="..string.gsub(vehicle_type, "wep_", "")) and not Tags.has(selected_prefab.vehicle.tags, "role=scout") then
			return false
		end
	end

	-- theres no players within 2500m (cannot see the spawn point)
	if not pl.noneNearby(s.getPlayers(), island.transform, 2500, true) then
		return false
	end

	return true
end

---Returns the island data from the provided flag vehicle id (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param group_id integer the group_id of the island's flag vehicle
---@return ISLAND? island the island the flag vehicle belongs to
---@return boolean got_island if the island was gotten
function Island.getDataFromGroupID(group_id)
	local island = IslandRegistry.getByGroupID(group_id)
	if island then
		return island, true
	end

	return nil, false
end

---returns the island data from the provided island index (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param island_index integer the island index you want to get
---@return ISLAND? island the island data from the index
---@return boolean island_found returns true if the island was found
function Island.getDataFromIndex(island_index)
	if not island_index then -- if the island_index wasn't specified
		d.print("(Island.getDataFromIndex) island_index was never inputted!", true, 1)
		return nil, false
	end

	local island = IslandRegistry.getByIndex(island_index)
	if island then
		return island, true
	end

	d.print("(Island.getDataFromIndex) island was not found! inputted island_index: "..tostring(island_index), true, 1)

	return nil, false
end

---returns the island data from the provided island name (warning: if you modify the returned data, it will not apply anywhere else, and will be local to that area.)
---@param island_name string the island name you want to get
---@return ISLAND? island the island data from the name
---@return boolean island_found returns true if the island was found
function Island.getDataFromName(island_name) -- function that gets the island by its name, it doesnt care about capitalisation and will replace underscores with spaces automatically
	if island_name then
		local island_name = string.friendly(island_name) or ""
		local island = IslandRegistry.getByName(island_name)
		if island then
			return island, true
		end
	end
	return nil, false
end

-- capturepoint command
Command.registerCommand(
	"capturepoint",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if arg[1] and arg[2] then
			local island, island_found = Island.getDataFromName(string.gsub(arg[1], "_", " "))
			if island_found and island then
				if island.faction ~= arg[2] then
					if arg[2] == ISLAND.FACTION.AI or arg[2] == ISLAND.FACTION.NEUTRAL or arg[2] == ISLAND.FACTION.PLAYER then
						captureIsland(island, arg[2], peer_id)
					else
						d.print(arg[2].." is not a valid faction! valid factions: | ai | neutral | player", false, 1, peer_id)
					end
				else
					d.print(island.name.." is already set to "..island.faction..".", false, 1, peer_id)
				end
			else
				d.print(arg[1].." is not a valid island! Did you replace spaces with _?", false, 1, peer_id)
			end
		else
			d.print("Invalid Syntax! command usage: ?impwep cp (island_name) (faction)", false, 1, peer_id)
		end
	end,
	"admin",
	"allows you to change who owns a specific island",
	"allows you to change who owns a point",
	{"North_Harbour ai"},
	"(island_name) (\"ai\"|\"neutral\"|\"player\")"
)