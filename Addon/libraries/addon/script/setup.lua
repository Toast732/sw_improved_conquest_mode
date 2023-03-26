--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.components.addonLocationUtils")
require("libraries.addon.components.tags")
require("libraries.addon.components.spawningUtils")

require("libraries.addon.script.debugging")

require("libraries.utils.tables")

-- library name
Setup = {}

-- shortened library name
sup = Setup

--[[


	Classes


]]

---@class SPAWN_ZONES
---@field turrets table<number, SWZone> the turret spawn zones
---@field land table<number, SWZone> the land vehicle spawn zones
---@field sea table<number, SWZone> the sea vehicle spawn zones

---@class PREFAB_DATA
---@field addon_index integer, Addon index the vehicle is from
---@field location_index integer, Location index the vehicle is in
---@field location_data SWLocationData, the data of the mission location which the vehicle is in
---@field vehicle SpawnableComponentData the data of the vehicle
---@field fires table<number, SpawnableComponentData> a table of the fires which are parented to the vehicle, containing the data of the fires

--[[


	Functions         


]]

--# sets up and returns the spawn zones, used for spawning certain vehicles at, such as boats, turrets and land vehicles
---@return SPAWN_ZONES spawn_zones the table of spawn zones
function Setup.spawnZones()

	local spawn_zones = {
		turrets = s.getZones("turret"),
		land = s.getZones("land_spawn"),
		sea = s.getZones("boat_spawn")
	}

	-- remove any NSO or non_NSO exlcusive zones

	-----
	--* filter NSO and non NSO exclusive islands
	-----

	-- go through all zone types
	for zone_type, zones in pairs(spawn_zones) do
		-- go through all of the zones for this zone type, backwards
		for zone_index = #zones, 1, -1 do
			zone = zones[zone_index]
			if not g_savedata.info.mods.NSO and Tags.has(zone.tags, "NSO") or g_savedata.info.mods.NSO and Tags.has(zone.tags, "not_NSO") then
				table.remove(zones, zone_index)
			end
		end
	end

	return spawn_zones
end

--# returns the tile's name which the zone is on
---@param zone SWZone the zone to get the tile name of
---@return string tile_name the name of the tile which the zone is on
---@return boolean is_success if it successfully got the name of the tile
function Setup.getZoneTileName(zone)
	local tile_data, is_success = server.getTile(zone.transform)
	if not is_success then
		d.print("(sup.getZoneTileName) failed to get the location of zone at: "..tostring(zone.transform[13])..", "..tostring(zone.transform[14])..", "..tostring(zone.transform[15]), true, 1)
		return nil, false
	end

	return tile_data.name, true
end

--# sorts the zones in a table, indexed by the tile name which the zone is on
---@param spawn_zones SPAWN_ZONES the zones to sort, gotten via sup.spawnZones
---@return table tile_zones sorted table of spawn zones
function Setup.sortSpawnZones(spawn_zones)

	local tile_zones = {}

	for zone_type, zones in pairs(spawn_zones) do

		for zone_index, zone in ipairs(zones) do

			local tile_name, is_success = Setup.getZoneTileName(zone)

			if not is_success then
				d.print("(sup.sortSpawnZones) Failed to get name of zone!", true, 1)
				goto sup_sortSpawnZones_continueZone
			end

			table.tabulate(tile_zones, tile_name, zone_type)

			table.insert(tile_zones[tile_name][zone_type], zone)

			::sup_sortSpawnZones_continueZone::
		end
	end

	return tile_zones
end

--# setups the vehicle prefabs
function Setup.createVehiclePrefabs()

	-- reset vehicle list
	g_savedata.vehicle_list = {}

	-- remove all existing vehicle data in constructable_vehicles
	for role, vehicles_with_role in pairs(g_savedata.constructable_vehicles) do
		if type(vehicles_with_role) == "table" then
			for vehicle_type, vehicles_with_type in pairs(vehicles_with_role) do
				if type(vehicles_with_type) == "table" then
					for strategy, vehicles_with_strategy in pairs(vehicles_with_type) do
						if type(vehicles_with_strategy) == "table" then
							for i = 1, #vehicles_with_type do
								vehicles_with_type[i].prefab_data = nil
							end
						end
					end
				end
			end
		end
	end

	local before_processing_vehicle_pack_API_configs = s.getTimeMillisec()

	local vehicle_pack_API_configs = {}

	local ai_vehicle_configs = alu.getMissionComponents(nil, nil, "ICM | CONFIG", "AI_VEHICLES_CONFIG")

	if ai_vehicle_configs then
		for _, component_data in ipairs(ai_vehicle_configs) do
			local tabled_config = table.fromString(component_data.tags_full)
			if tabled_config then
				vehicle_pack_API_configs[component_data.addon_index] = vehicle_pack_API_configs[component_data.addon_index] or {}
				table.insert(vehicle_pack_API_configs[component_data.addon_index], tabled_config)
			end
		end
	end
	d.print(("Processed Vehicle Pack API Configs (took %0.2fs, for %0.0f configs)"):format((s.getTimeMillisec() - before_processing_vehicle_pack_API_configs)*0.001, #ai_vehicle_configs), true, 0)


	--# checks if this vehicle is within the configs, returns false if its fine, returns true if its violating a config.
	local function vehicleViolatesConfigs(addon_index, addon_data, location_data)
		for config_addon_index, configs in pairs(vehicle_pack_API_configs) do
			if config_addon_index ~= addon_index then
				for _, config_data in ipairs(configs) do
					for target_addon_name, vehicles_to_remove in pairs(config_data) do
						if addon_data.name:match(target_addon_name) then
							for _, vehicle_name in ipairs(vehicles_to_remove) do
								if location_data.name:match(vehicle_name) then
									d.print(("Removed Vehicle \"%s\" from AI's arsenal, due to a Vehicle Pack API Config from the addon \"%s\""):format(location_data.name, s.getAddonData(config_addon_index).name), false, 0)
									return true
								end
							end
						end
					end
				end
			end
		end

		return false
	end

	-- iterate through all addons
	for addon_index = 0, s.getAddonCount() - 1 do
		local addon_data = s.getAddonData(addon_index)

		if not addon_data.location_count or addon_data.location_count <= 0 then
			goto createVehiclePrefabs_continue_addon
		end

		-- iterate through all locations in this addon
		for location_index = 0, addon_data.location_count - 1 do
			local location_data = s.getLocationData(addon_index, location_index)

			if location_data.env_mod then
				goto createVehiclePrefabs_continue_location
			end

			-- iterate through all components in this location
			for component_index = 0, location_data.component_count - 1 do

				local component_data, is_success = s.getLocationComponentData(addon_index, location_index, component_index)

				if not is_success then
					goto createVehiclePrefabs_continue_component
				end

				-- check if this is the flag
				if not flag_prefab and Tags.has(component_data.tags, "type=dlc_weapons_flag") and component_data.type == "vehicle" then
					flag_prefab = { 
						addon_index = addon_index,
						location_index = location_index,
						component_index = component_index
					}

					goto createVehiclePrefabs_continue_component
				end

				-- if this component is not an enemy AI vehicle
				if not Tags.has(component_data.tags, "type=dlc_weapons") then
					goto createVehiclePrefabs_continue_component
				end

				-- if this vehicle violates one of the configs
				if vehicleViolatesConfigs(addon_index, addon_data, location_data) then
					break
				end

				-- there is an enemy AI vehicle here

				component_data = su.populateComponentData(component_index, component_data)

				---@type PREFAB_DATA
				local prefab_data = {
					addon_index = addon_index, -- addon index the vehicle is from
					location_index = location_index, -- the location index the vehicle is in
					location_data = location_data, -- the data of the location
					vehicle = component_data, -- the vehicle itself
					fires = {} -- the fires attached to this vehicle
				}

				-- add any fires that are attached to this vehicle
				for valid_component_index = 0, location_data.component_count - 1 do
					local valid_component_data, is_success = s.getLocationComponentData(addon_index, location_index, valid_component_index)

					if is_success then
						-- if this is a fire, and its parented to this vehicle, then add it to the prefab
						if valid_component_data.type == "fire" and valid_component_data.vehicle_parent_component_id == prefab_data.vehicle.id then
							table.insert(prefab_data.fires, su.populateComponentData(valid_component_index, valid_component_data))
						end
					end
				end

				-- get the role of the vehicle
				local role = Tags.getValue(component_data.tags, "role", true) or "general"
				-- get the type of the vehicle
				local vehicle_type = string.gsub(Tags.getValue(component_data.tags, "vehicle_type", true) --[[@as string]], "wep_", "") or "unknown"
				-- get the strategy of the vehicle
				local strategy = Tags.getValue(component_data.tags, "strategy", true) or "general"

				-- fill out the constructable_vehicles table with the vehicle's role, vehicle type and strategy
				table.tabulate(g_savedata.constructable_vehicles, role, vehicle_type, strategy)

				local vehicle_list_data = prefab_data
				vehicle_list_data.role = role
				vehicle_list_data.vehicle_type = vehicle_type
				vehicle_list_data.strategy = strategy

				-- add vehicle list data to the vehicle list
				g_savedata.vehicle_list[#g_savedata.vehicle_list + 1] = vehicle_list_data

				--[[ 
					check if this vehicle exists within the constructable vehicles already
					if it does, then just update it's prefab data
					otherwise, create a new one
				]]
				for i = math.min(1, #g_savedata.constructable_vehicles[role][vehicle_type][strategy]), #g_savedata.constructable_vehicles[role][vehicle_type][strategy] do
					local constructable_vehicle_data = g_savedata.constructable_vehicles[role][vehicle_type][strategy][i]

					if constructable_vehicle_data and constructable_vehicle_data.name == location_data.name then
						-- this vehicle already exists

						-- update prefab data
						constructable_vehicle_data.prefab_data = prefab_data

						-- update id
						constructable_vehicle_data.id = #g_savedata.vehicle_list

						-- break, as we found a match.
						break
					elseif i == #g_savedata.constructable_vehicles[role][vehicle_type][strategy] then
						-- this vehicle does not exist
						table.insert(g_savedata.constructable_vehicles[role][vehicle_type][strategy], {
							prefab_data = prefab_data,
							name = location_data.name,
							mod = 1,
							id = #g_savedata.vehicle_list
						})
					end
				end
				d.print(("set id: %i | # of vehicles w same role, type and strategy: %s | name: %s | from addon with index: %i"):format(#g_savedata.vehicle_list, #g_savedata.constructable_vehicles[role][vehicle_type][strategy], location_data.name, addon_index), true, 0)
				::createVehiclePrefabs_continue_component::
			end
			::createVehiclePrefabs_continue_location::
		end

		::createVehiclePrefabs_continue_addon::
	end
end