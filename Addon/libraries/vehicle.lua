-- required libraries
require("libraries.debugging")
require("libraries.squad")
require("libraries.string")
require("libraries.island")
require("libraries.spawningUtils")
require("libraries.tags")
require("libraries.players")
require("libraries.matrix")
require("libraries.spawnModifiers")
require("libraries.cargo")
require("libraries.objective")

-- library name
Vehicle = {}

-- shortened library name
v = Vehicle

---@param vehicle_object vehicle_object the vehicle you want to get the speed of
---@param ignore_terrain_type boolean if false or nil, it will include the terrain type in speed, otherwise it will return the offroad speed (only applicable to land vehicles)
---@param ignore_aggressiveness boolean if false or nil, it will include the aggressiveness in speed, otherwise it will return the normal speed (only applicable to land vehicles)
---@param terrain_type_override string \"road" to override speed as always on road, "offroad" to override speed as always offroad, "bridge" to override the speed always on a bridge (only applicable to land vehicles)
---@param aggressiveness_override string \"normal" to override the speed as always normal, "aggressive" to override the speed as always aggressive (only applicable to land vehicles)
---@return number speed the speed of the vehicle, 0 if not found
---@return boolean got_speed if the speed was found
function Vehicle.getSpeed(vehicle_object, ignore_terrain_type, ignore_aggressiveness, terrain_type_override, aggressiveness_override, ignore_convoy_modifier)
	if not vehicle_object then
		d.print("(Vehicle.getSpeed) vehicle_object is nil!", true, 1)
		return 0, false
	end

	local squad_index, squad = Squad.getSquad(vehicle_object.id)

	if not squad then
		d.print("(Vehicle.getSpeed) squad is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return 0, false
	end

	local speed = 0

	local ignore_me = false

	if squad.command == SQUAD.COMMAND.CARGO then
		-- return the slowest vehicle in the chain's speed
		for vehicle_index, _ in pairs(squad.vehicles) do
			if g_savedata.cargo_vehicles[vehicle_index] and g_savedata.cargo_vehicles[vehicle_index].route_status == 1 then
				speed = g_savedata.cargo_vehicles[vehicle_index].path_data.speed or 0
				if speed ~= 0 and not ignore_convoy_modifier then
					speed = speed + (vehicle_object.speed.convoy_modifier or 0)
					ignore_me = true
				end
			end
		end
	end

	if speed == 0 and not ignore_me then
		speed = vehicle_object.speed.speed

		if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
			-- land vehicle
			local terrain_type = v.getTerrainType(vehicle_object.transform)
			local aggressive = agressiveness_override or not ignore_aggressiveness and vehicle_object.is_aggressive or false
			if aggressive then
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.AGGRESSIVE
			else
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.NORMAL
			end

			speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND[string.upper(terrain_type)]
		end
	end

	return speed, true
end

---@param transform SWMatrix the transform of where you want to check
---@return string terrain_type the terrain type the transform is on
---@return boolean found_terrain_type if the terrain type was found
function Vehicle.getTerrainType(transform)
	local found_terrain_type = false
	local terrain_type = "offroad"
	
	if transform then
		-- prefer returning bridge, then road, then offroad
		if s.isInZone(transform, "land_ai_bridge") then
			terrain_type = "bridge"
		elseif s.isInZone(transform, "land_ai_road") then
			terrain_type = "road"
		end
	else
		d.print("(Vehicle.getTerrainType) vehicle_object is nil!", true, 1)
	end

	return terrain_type, found_terrain_type
end

---@param vehicle_id integer the id of the vehicle
---@return prefab prefab the prefab of the vehicle if it was created
---@return boolean was_created if the prefab was created
function Vehicle.createPrefab(vehicle_id)
	if not vehicle_id then
		d.print("(Vehicle.createPrefab) vehicle_id is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_id)

	if not got_vehicle_data then
		d.print("(Vehicle.createPrefab) failed to get vehicle data! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)

	if not vehicle_object then
		d.print("(Vehicle.createPrefab) failed to get vehicle_object! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	---@class prefab
	local prefab = {
		voxels = vehicle_data.voxels,
		mass = vehicle_data.mass,
		powertrain_types = v.getPowertrainTypes(vehicle_object),
		role = vehicle_object.role,
		vehicle_type = vehicle_object.vehicle_type,
		strategy = vehicle_object.strategy,
		fully_created = (vehicle_data.mass ~= 0) -- requires to be loaded
	}

	g_savedata.prefabs[string.removePrefix(vehicle_object.name)] = prefab

	return prefab, true
end

---@param vehicle_name string the name of the vehicle
---@return prefab prefab the prefab data of the vehicle
---@return got_prefab boolean if the prefab data was found
function Vehicle.getPrefab(vehicle_name)
	if not vehicle_name then
		d.print("(Vehicle.getPrefab) vehicle_name is nil!", true, 1)
		return nil, false
	end

	vehicle_name = string.removePrefix(vehicle_name)

	if not g_savedata.prefabs[vehicle_name] then
		return nil, false
	end

	return g_savedata.prefabs[vehicle_name], true
end

---@param vehicle_name string the vehicle's name that you want to purchase
---@param island_name string the island that this vehicle is being bought under
---@param fallback_type integer the type of fallback to do if it cannot be afforded, 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@param just_check boolean if you just want to check if the vehicle can be afforded, not actually buy it
---@return integer cost the cost of the vehicle
---@return boolean cost_existed if the cost has been calculated yet
---@return boolean was_purchased if the vehicle was purchased
---@return number stat_multiplier the amount to multiply the stats by 
function Vehicle.purchaseVehicle(vehicle_name, island_name, fallback_type, just_check)

	if not g_savedata.settings.CARGO_MODE then
		d.print("(Vehicle.purchaseVehicle) Cargo Mode is disabled!", true, 1)
		return 0, nil, true, 1
	end

	if not vehicle_name then
		d.print("(Vehicle.purchaseVehicle) vehicle_name is nil!", true, 1)
		return nil, nil, false, 0.1
	end

	if not island_name then
		d.print("(Vehicle.purchaseVehicle) island_name is nil!", true, 1)
		return nil, nil, false, 0.1
	end

	local island, found_island = is.getDataFromName(island_name)

	if not found_island then
		d.print("(Vehicle.purchaseVehicle) island not found! island_name: "..tostring(island_name), true, 1)
		return nil, nil, false, 0.1
	end

	vehicle_name = string.removePrefix(vehicle_name)

	fallback_type = fallback_type or 0

	if fallback_type == 1 then -- buy it for free
		return 0, nil, true, 1
	end

	local cost, cost_existed, got_cost = v.getCost(vehicle_name)

	if not got_cost then
		d.print("(Vehicle.purchaseVehicle) failed to get cost of vehicle "..tostring(vehicle_name), true, 1)
		return nil, nil, false, 0.1
	end

	if cost == 0 then
		return cost, cost_existed, true, 1
	end

	local prefab, got_prefab = v.getPrefab(vehicle_name)

	if not got_prefab then
		d.print("(Vehicle.purchaseVehicle) failed to get prefab of vehicle "..tostring(vehicle_name), true, 1)
		return nil, cost_existed, false, 0.1
	end

	local total_spent = 0

	for powertrain_type, is_used in pairs(prefab.powertrain_types) do
		if is_used then

			local resource_price = math.max(cost/RULES.LOGISTICS.COSTS.RESOURCE_VALUES[powertrain_type], island.cargo[powertrain_type])
			total_spent = total_spent + resource_price

			cost = resource_price - island.cargo[powertrain_type]

			if not just_check then
				island.cargo[powertrain_type] = island.cargo[powertrain_type] - resource_price
			end

			cost = cost * RULES.LOGISTICS.COSTS.RESOURCE_VALUES[powertrain_type]
		end

		if cost == 0 then
			break
		end
	end

	local stat_multiplier = 1
	if cost ~= 0 then
		if fallback_type == 2 then
			stat_multiplier = total_spent ~= cost and 0.5 or 1
		elseif fallback_type == 3 then
			stat_multiplier = math.max(total_spent/cost, 0.5)
		end
	end

	return total_spent, cost_existed, cost == 0, stat_multiplier
end

---@param vehicle_name string the vehicle's name you want to get the cost of
---@return cost cost the cost of the vehicle
---@return boolean cost_existed if the cost existed before hand
---@return boolean got_cost if the cost was calculated
function Vehicle.getCost(vehicle_name)
	
	--TODO: Rewrite to use vehicle_name instead of vehicle_object
	if not g_savedata.settings.CARGO_MODE then
		d.print("(Vehicle.getCost) Cargo Mode is disabled!", true, 0)
		return 0, false, false
	end

	if not vehicle_name then
		d.print("(Vehicle.getCost) vehicle_name is nil!", true, 1)
		return 0, nil, false
	end

	vehicle_name = string.removePrefix(vehicle_name)

	local prefab, got_prefab = v.getPrefab(vehicle_name)

	if not got_prefab then
		return 0, false, true
	end

	if not prefab.fully_created then
		-- pretend we can afford it for now, whenever its loaded then we check
		return 0, false, true
	end

	--* calculate cost

	local cost = math.floor((prefab.voxels^0.8*1.35+prefab.mass^0.75)/2)
	d.print("(Vehicle.getCost) name: "..tostring(vehicle_name).."\nmass: "..tostring(prefab.mass).."\nvoxels: "..tostring(prefab.voxels).."\ncost: "..tostring(cost), true, 0)

	cost = math.max(cost, 0) or 0

	return cost, cost_existed, true
end

---@param vehicle_object vehicle_object the vehicle_object of the vehicle you want to get the powertrain type of
---@return powertrain_types powertrain_types the powertrain type(s) of the vehicle
---@return boolean got_powertrain_type if the powertrain type was found
function Vehicle.getPowertrainTypes(vehicle_object)

	if not vehicle_object then
		d.print("(Vehicle.getPowertrainType) vehicle_object is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_object.id)

	if not got_vehicle_data then
		d.print("(Vehicle.getPowertrainType) failed to get vehicle data! name: "..tostring(vehicle_object.name).."\nid: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	local _, is_jet = s.getVehicleTank(vehicle_object.id, "Jet 1")

	local _, is_diesel = s.getVehicleTank(vehicle_object.id, "Diesel 1")

	---@class powertrain_types
	local powertrain_types = {
		jet_fuel = is_jet,
		diesel = is_diesel,
		oil = (not is_jet and not is_diesel)
	}

	return powertrain_types, true	
end

---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_object vehicle_object the vehicle's data if the the vehicle successfully spawned, otherwise its returns the error code
function Vehicle.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
	local plane_count = 0
	local heli_count = 0
	local army_count = 0
	local land_count = 0
	local boat_count = 0

	if not g_savedata.settings.CARGO_MODE or not purchase_type then
		-- buy the vehicle for free
		purchase_type = 1
	end
	
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET then army_count = army_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then plane_count = plane_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then heli_count = heli_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then land_count = land_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then boat_count = boat_count + 1 end
		end
	end

	if vehicle_type == "helicopter" then
		vehicle_type = "heli"
	end
	
	local selected_prefab = nil

	local spawnbox_index = nil -- turrets

	if vehicle_type == "turret" and specified_island then

		-----
		--* turret spawning
		-----

		local island = specified_island

		-- make sure theres turret spawns on this island
		if (#island.zones.turrets < 1) then
			return false, "theres no turret zones on this island!\nisland: "..island.name 
		end

		local turret_count = 0
		local unoccupied_zones = {}

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			else
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		-- d.print("turret count: "..turret_count, true, 0)

		-- pick a spawn point out of the list which is unoccupied
		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		-- make sure theres no players nearby this turret spawn
		local player_list = s.getPlayers()
		if not force_spawn and not pl.noneNearby(player_list, island.zones.turrets[spawnbox_index].transform, 2500, true) then -- makes sure players are not too close before spawning a turret
			return false, "players are too close to the turret spawn point!"
		end

		selected_prefab = sm.spawn(true, Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true), "turret")

		if not selected_prefab then
			return false, "was unable to get a turret prefab! turret_type of turret spawn zone: "..tostring(Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true))
		end

	elseif requested_prefab then
		-- *spawning specified vehicle
		selected_prefab = sm.spawn(true, requested_prefab, vehicle_type) 
	else
		-- *spawn random vehicle
		selected_prefab = sm.spawn(false, requested_prefab, vehicle_type)
	end

	if not selected_prefab then
		d.print("(Vehicle.spawn) Unable to spawn AI vehicle! (prefab not recieved)", true, 1)
		return false, "returned vehicle was nil, prefab "..(requested_prefab and "was" or "was not").." selected"
	end

	d.print("(Vehicle.spawn) selected vehicle: "..selected_prefab.location.data.name, true, 0)

	if not requested_prefab then
		if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") and boat_count >= g_savedata.settings.MAX_BOAT_AMOUNT then
			return false, "boat limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") and land_count >= g_savedata.settings.MAX_LAND_AMOUNT then
			return false, "land limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") and heli_count >= g_savedata.settings.MAX_HELI_AMOUNT then
			return false, "heli limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") and plane_count >= g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "plane limit reached"
		end
		if army_count > g_savedata.settings.MAX_BOAT_AMOUNT + g_savedata.settings.MAX_LAND_AMOUNT + g_savedata.settings.MAX_HELI_AMOUNT + g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "AI hit vehicle limit!"
		end
	end

	local player_list = s.getPlayers()

	local selected_spawn = 0
	local selected_spawn_transform = g_savedata.ai_base_island.transform

	-------
	-- get spawn location
	-------

	local min_player_dist = 2500

	d.print("(Vehicle.spawn) Getting island to spawn vehicle at...", true, 0)

	if not specified_island then
		-- if the vehicle we want to spawn is an attack vehicle, we want to spawn it as close to their objective as possible
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "attack" or Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			target, ally = Objective.getIslandToAttack()
			if not target then
				sm.train(PUNISH, attack, 5) -- we can no longer spawn attack vehicles
				sm.train(PUNISH, attack, 5)
				v.spawn(nil, nil, nil, nil, purchase_type)
				return false, "no islands to attack! cancelling spawning of attack vehicle"
			end
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) and (selected_spawn_transform == nil or m.xzDistance(target.transform, island.transform) < m.xzDistance(target.transform, selected_spawn_transform)) then
					selected_spawn_transform = island.transform
					selected_spawn = island_index
				end
			end
		-- (A) if the vehicle we want to spawn is a defensive vehicle, we want to spawn it on the island that has the least amount of defence
		-- (B) if theres multiple, pick the island we saw the player closest to
		-- (C) if none, then spawn it at the island which is closest to the player's island
		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "defend" then
			local lowest_defenders = nil
			local check_last_seen = false
			local islands_needing_checked = {}

			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) and (not lowest_defenders or island.defenders < lowest_defenders) then -- choose the island with the least amount of defence (A)
					lowest_defenders = island.defenders -- set the new lowest defender amount on an island
					selected_spawn_transform = island.transform
					selected_spawn = island_index
					check_last_seen = false -- say that we dont need to do a tie breaker
					islands_needing_checked = {}
				elseif lowest_defenders == island.defenders then -- if two islands have the same amount of defenders
					islands_needing_checked[selected_spawn] = selected_spawn_transform
					islands_needing_checked[island_index] = island.transform
					check_last_seen = true -- we need a tie breaker
				end
			end

			if check_last_seen then -- do a tie breaker (B)
				local closest_player_pos = nil
				for player_steam_id, player_transform in pairs(g_savedata.ai_knowledge.last_seen_positions) do
					for island_index, island_transform in pairs(islands_needing_checked) do
						local player_to_island_dist = m.xzDistance(player_transform, island_transform)
						if not closest_player_pos or player_to_island_dist < closest_player_pos then
							closest_player_pos = player_to_island_dist
							selected_spawn_transform = island_transform
							selected_spawn = island_index
						end
					end
				end

				if not closest_player_pos then -- if no players were seen this game, spawn closest to the closest player island (C)
					for island_index, island_transform in pairs(islands_needing_checked) do
						for player_island_index, player_island in pairs(g_savedata.islands) do
							if player_island.faction == ISLAND.FACTION.PLAYER then
								if m.xzDistance(selected_spawn_transform, island_transform) > m.xzDistance(player_island.transform, island_transform) then
									selected_spawn_transform = island_transform
									selected_spawn = island_index
								end
							end
						end
					end
				end
			end
		-- spawn it at a random ai island
		else
			local valid_islands = {}
			local valid_island_index = {}
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) then
					table.insert(valid_islands, island)
					table.insert(valid_island_index, island_index)
				end
			end
			if #valid_islands > 0 then
				random_island = math.random(1, #valid_islands)
				selected_spawn_transform = valid_islands[random_island].transform
				selected_spawn = valid_island_index[random_island]
			end
		end
	else
		-- if they specified the island they want it to spawn at
		if not force_spawn then
			-- if they did not force the vehicle to spawn
			if is.canSpawn(specified_island, selected_prefab) then
				selected_spawn_transform = specified_island.transform
				selected_spawn = specified_island.index
			end
		else
			--d.print("forcing vehicle to spawn at "..specified_island.index, true, 0)
			-- if they forced the vehicle to spawn
			selected_spawn_transform = specified_island.transform
			selected_spawn = specified_island.index
		end
	end

	-- try spawning at the ai's main base if it was unable to find a valid spawn
	if not g_savedata.islands[selected_spawn] and g_savedata.ai_base_island.index ~= selected_spawn then
		if force_spawn or pl.noneNearby(player_list, g_savedata.ai_base_island.transform, min_player_dist, true) then -- makes sure no player is within min_player_dist
			-- if it can spawn at the ai's main base, or the vehicle is being forcibly spawned and its not a land vehicle
			if Tags.has(g_savedata.ai_base_island.tags, "can_spawn="..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "")) or force_spawn and Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) ~= "wep_land" then
				selected_spawn_transform = g_savedata.ai_base_island.transform
				selected_spawn = g_savedata.ai_base_island.index
			end
		end
	end


	-- if it still was unable to find a island to spawn at
	if not g_savedata.islands[selected_spawn] and selected_spawn ~= g_savedata.ai_base_island.index then
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then -- make the scout spawn at the ai's main base
			selected_spawn_transform = g_savedata.ai_base_island.transform
		else
			d.print("(Vehicle.spawn) was unable to find island to spawn at!\nIsland Index: "..selected_spawn.."\nVehicle Type: "..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "").."\nVehicle Role: "..Tags.getValue(selected_prefab.vehicle.tags, "role", true), true, 1)
			return false, "was unable to find island to spawn at"
		end
	end

	local island = g_savedata.ai_base_island.index == selected_spawn and g_savedata.ai_base_island or g_savedata.islands[selected_spawn]

	d.print("(Vehicle.spawn) island: "..island.name, true, 0)

	local spawn_transform = selected_spawn_transform
	if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") then
		if not island then
			return false, "unable to find island to spawn sea vehicle at!"
		end
		if #island.zones.sea == 0 then
			d.print("(Vehicle.spawn) island has no sea spawn zones but says it can spawn sea vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no sea spawn zones"
		end

		spawn_transform = island.zones.sea[math.random(1, #island.zones.sea)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") then
		if #island.zones.land == 0 then
			d.print("(Vehicle.spawn) island has no land spawn zones but says it can spawn land vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no land spawn zones"
		end

		spawn_transform = island.zones.land[math.random(1, #island.zones.land)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_turret") then
		local turret_count = 0
		local unoccupied_zones = {}

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			elseif Tags.has(island.zones.turrets[turret_zone_index].tags, "turret_type="..Tags.getValue(selected_prefab.vehicle.tags, "role", true)) then
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		-- pick a spawn location out of the list which is unoccupied

		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		spawn_transform = island.zones.turrets[spawnbox_index].transform

	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") or Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") then
		spawn_transform = m.multiply(selected_spawn_transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + 400, math.random(-500, 500)))
	end

	-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if m.distance(spawn_transform, vehicle_object.transform) < (Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE + vehicle_object.spawning_transform.distance) then
				return false, "spawn location was too close to vehicle "..vehicle_id
			end
		end
	end

	d.print("(Vehicle.spawn) calculating cost of vehicle... (purchase type: "..tostring(purchase_type)..")", true, 0)
	-- check if we can afford the vehicle
	local cost, cost_existed, was_purchased, stats_multiplier = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), island.name, purchase_type, true)

	d.print("(Vehicle.spawn) cost: "..tostring(cost).." Purchase Type: "..purchase_type, true, 0)

	if not was_purchased then
		return false, "was unable to afford vehicle"
	end

	-- spawn objects
	local spawned_objects = {
		survivors = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.survivors, {}),
		fires = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.fires, {}),
		spawned_vehicle = su.spawnObject(spawn_transform, selected_prefab.location.location_index, selected_prefab.vehicle, 0, nil, {}),
	}

	d.print("(Vehicle.spawn) setting up enemy vehicle: "..selected_prefab.location.data.name, true, 0)

	if spawned_objects.spawned_vehicle ~= nil then
		local vehicle_survivors = {}
		for key, char in pairs(spawned_objects.survivors) do
			local c = s.getCharacterData(char.id)
			s.setCharacterData(char.id, c.hp, true, true)
			s.setAIState(char.id, 1)
			s.setAITargetVehicle(char.id, nil)
			table.insert(vehicle_survivors, char)
		end

		local home_x, home_y, home_z = m.position(spawn_transform)

		d.print("(Vehicle.spawn) setting vehicle data...", true, 0)
		--d.print("selected_spawn: "..selected_spawn, true, 0)

		---@class vehicle_object
		local vehicle_data = { 
			id = spawned_objects.spawned_vehicle.id,
			name = selected_prefab.location.data.name,
			home_island = g_savedata.islands[selected_spawn] or g_savedata.ai_base_island,
			survivors = vehicle_survivors, 
			path = { 
				[0] = {
					x = home_x, 
					y = home_y, 
					z = home_z
				} 
			},
			state = { 
				s = VEHICLE.STATE.HOLDING,
				timer = math.floor(math.fmod(spawned_objects.spawned_vehicle.id, 300 * stats_multiplier)),
				is_simulating = false,
				convoy = {
					status = CONVOY.MOVING,
					status_reason = "",
					time_changed = -1,
					ignore_wait = false,
					waiting_for = 0
				}
			},
			previous_squad = nil,
			ui_id = s.getMapID(),
			vehicle_type = spawned_objects.spawned_vehicle.vehicle_type,
			role = Tags.getValue(selected_prefab.vehicle.tags, "role", true) or "general",
			size = spawned_objects.spawned_vehicle.size or "small",
			holding_index = 1,
			holding_target = m.translation(home_x, home_y, home_z),
			spawnbox_index = spawnbox_index,
			costs = {
				buy_on_load = not cost_existed,
				purchase_type = purchase_type
			},
			vision = { 
				radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				base_radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				is_radar = Tags.has(selected_prefab.vehicle.tags, "radar"),
				is_sonar = Tags.has(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE
			},
			speed = {
				speed = Tags.getValue(selected_prefab.vehicle.tags, "speed") or 0 * stats_multiplier,
				convoy_modifier = 0
			},
			driving = {}, -- used for driving the vehicle itself, holds special data depending on the vehicle type
			capabilities = {
				gps_target = Tags.has(selected_prefab.vehicle.tags, "GPS_TARGET_POSITION"), -- if it needs to have gps coords sent for where the player is
				gps_missile = Tags.has(selected_prefab.vehicle.tags, "GPS_MISSILE"), -- used to press a button to fire the missiles
				target_mass = Tags.has(selected_prefab.vehicle.tags, "TARGET_MASS") -- sends mass of targeted vehicle mass to the creation
			},
			cargo = {
				capacity = Tags.getValue(selected_prefab.vehicle.tags, "cargo_per_type") or 0,
				current = {
					oil = 0,
					diesel = 0,
					jet_fuel = 0
				}
			},
			is_aggressive = false,
			is_killed = false,
			just_strafed = true, -- used for fighter jet strafing
			strategy = Tags.getValue(selected_prefab.vehicle.tags, "strategy", true) or "general",
			can_offroad = Tags.has(selected_prefab.vehicle.tags, "can_offroad"),
			is_resupply_on_load = false,
			transform = spawn_transform,
			transform_history = {},
			target_vehicle_id = nil,
			target_player_id = nil,
			current_damage = 0,
			health = (Tags.getValue(selected_prefab.vehicle.tags, "health", false) or 1) * stats_multiplier,
			damage_dealt = {},
			fire_id = nil,
			object_type = "vehicle"
		}

		d.print("(Vehicle.spawn) set vehicle data", true, 0)

		if #spawned_objects.fires > 0 then
			vehicle_data.fire_id = spawned_objects.fires[1].id
		end

		local squad = addToSquadron(vehicle_data)
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			setSquadCommand(squad, SQUAD.COMMAND.SCOUT)
		elseif Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) == "wep_turret" then
			setSquadCommand(squad, SQUAD.COMMAND.TURRET)

			-- set the zone it spawned at to say that a turret was spawned there
			if g_savedata.islands[selected_spawn] then -- set at their island
				g_savedata.islands[selected_spawn].zones.turrets[spawnbox_index].is_spawned = true
			else -- they spawned at their main base
				g_savedata.ai_base_island.zones.turrets[spawnbox_index].is_spawned = true
			end

		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "cargo" then
			setSquadCommand(squad, SQUAD.COMMAND.CARGO)
		end

		local prefab, got_prefab = v.getPrefab(selected_prefab.location.data.name)

		if not got_prefab then
			v.createPrefab(spawned_objects.spawned_vehicle.id)
		end

		if cost_existed then
			local cost, cost_existed, was_purchased = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), (g_savedata.islands[selected_spawn].name or g_savedata.ai_base_island.name), purchase_type)
			if not was_purchased then
				vehicle_data.costs.buy_on_load = true
			end
		end

		return true, vehicle_data
	end
	return false, "spawned_objects.spawned_vehicle was nil"
end

-- spawns a ai vehicle, if it fails then it tries again, the amount of times it retrys is how ever many was given
---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer the way you want to purchase the vehicle 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@param retry_count integer how many times to retry spawning the vehicle if it fails
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_data[] vehicle_data the vehicle's data if the the vehicle successfully spawned, otherwise its nil
function Vehicle.spawnRetry(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type, retry_count)
	local spawned = nil
	local vehicle_data = nil
	d.print("(Vehicle.spawnRetry) attempting to spawn vehicle...", true, 0)
	for i = 1, retry_count do
		spawned, vehicle_data = v.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
		if spawned then
			return spawned, vehicle_data
		else
			d.print("(Vehicle.spawnRetry) Spawning failed, retrying ("..retry_count-i.." attempts remaining)\nError: "..vehicle_data, true, 1)
		end
	end
	return spawned, vehicle_data
end

-- teleports a vehicle and all of the characters attached to the vehicle to avoid the characters being left behind
---@param vehicle_id integer the id of the vehicle which to teleport
---@param transform SWMatrix where to teleport the vehicle and characters to
---@return boolean is_success if it successfully teleported all of the vehicles and characters
function Vehicle.teleport(vehicle_id, transform)

	-- make sure vehicle_id is not nil
	if not vehicle_id then
		d.print("(Vehicle.teleport) vehicle_id is nil!", true, 1)
		return false
	end

	-- make sure transform is not nil
	if not transform then
		d.print("(Vehicle.teleport) transform is nil!", true, 1)
		return false
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	local none_failed = true

	-- set char pos
	for i, char in ipairs(vehicle_object.survivors) do
		local is_success = s.setObjectPos(char.id, transform)
		if not is_success then
			d.print("(Vehicle.teleport) failed to set character position! char.id: "..char.id, true, 1)
			none_failed = false
		end
	end

	-- set vehicle pos
	local is_success = s.setVehiclePos(vehicle_id, transform)

	if not is_success then
		d.print("(Vehicle.teleport) failed to set vehicle position! vehicle_id: "..vehicle_id, true, 1)
		none_failed = false
	end

	return none_failed
end

---@param vehicle_id integer the id of the vehicle you want to kill
---@param kill_instantly boolean if you want to kill the vehicle instantly, if not, it will despawn it when the vehicle is unloaded, or takes enough damage to explode
---@param force_kill boolean if you want to forcibly kill the vehicle, if so, it will go without explosions, and will not affect the spawn modifiers. Used for things like ?impwep dv
---@return boolean is_success if it was able to successfully kill the vehicle
function Vehicle.kill(vehicle_id, kill_instantly, force_kill)
	local debug_prefix = "(Vehicle.kill) "

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	if not squad then
		d.print(debug_prefix.."Failed to find the squad for vehicle "..tostring(vehicle_id), true, 1)
		return false
	end

	if not squad_index then
		d.print(debug_prefix.."Failed to get the squad_index for vehicle "..tostring(vehicle_id), true, 1)
		return false
	end

	if not vehicle_object then
		d.print(debug_prefix.."Failed to get the vehicle_object for vehicle "..tostring(vehicle_id), true, 1)
		return false
	end

	if vehicle_object.is_killed ~= true and not kill_instantly then
		d.print(debug_prefix.."Vehicle "..tostring(vehicle_id).." is already killed!", true, 1)
		return false
	end

	d.print(debug_prefix..vehicle_id.." from squad "..squad_index.." is out of action", true, 0)

	-- set the vehicle to say its been killed, and set its death_timer to 0.
	vehicle_object.is_killed = true
	vehicle_object.death_timer = 0

	-- clean the cargo vehicle if it is one
	Cargo.clean(vehicle_id)

	-- if it is a scout vehicle, we want to reset its scouting progress on whatever island it was on
	-- as it lost all of the data as it was killed.
	if vehicle_object.role == "scout" then
		local target_island, origin_island = Objective.getIslandToAttack(true)
		if target_island then

			-- reset the island's scouted %
			g_savedata.ai_knowledge.scout[target_island.name].scouted = 0

			-- say that we're no longer scouting the island
			target_island.is_scouting = false

			 -- saves that the scout vehicle just died, after 30 minutes it should spawn another scout plane
			g_savedata.ai_history.scout_death = g_savedata.tick_counter

			d.print(debug_prefix.."scout vehicle died! set to respawn in 30 minutes", true, 0)
		end
	end

	-- we dont want to force kill cargo vehicles unless we're forcing it.
	-- as we want to give time for the player to try to recover the cargo.
	if vehicle_object.role ~= SQUAD.COMMAND.CARGO or force_kill then
		-- change ai spawning modifiers
		if not force_kill and vehicle_object.role ~= SQUAD.COMMAND.SCOUT and vehicle_object.role ~= SQUAD.COMMAND.CARGO then -- if the vehicle was not forcefully despawned, and its not a scout or cargo vehicle

			local ai_damaged = vehicle_object.current_damage or 0
			local ai_damage_dealt = 1
			for vehicle_id, damage in pairs(vehicle_object.damage_dealt) do
				ai_damage_dealt = ai_damage_dealt + damage
			end

			local constructable_vehicle_id = sm.getConstructableVehicleID(vehicle_object.role, vehicle_object.vehicle_type, vehicle_object.strategy, sm.getVehicleListID(vehicle_object.name))

			d.print(debug_prefix.."ai damage taken: "..ai_damaged.." ai damage dealt: "..ai_damage_dealt, true, 0)
			if ai_damaged * 0.3333 < ai_damage_dealt then -- if the ai did more damage than the damage it took / 3
				local ai_reward_ratio = ai_damage_dealt//(ai_damaged * 0.3333)
				sm.train(
					REWARD, 
					vehicle_role, math.clamp(ai_reward_ratio, 1, 2),
					vehicle_object.vehicle_type, math.clamp(ai_reward_ratio, 1, 3), 
					vehicle_object.strategy, math.clamp(ai_reward_ratio, 1, 2), 
					constructable_vehicle_id, math.clamp(ai_reward_ratio, 1, 3)
				)
			else -- if the ai did less damage than the damage it took / 3
				local ai_punish_ratio = (ai_damaged * 0.3333)//ai_damage_dealt
				sm.train(
					PUNISH, 
					vehicle_role, math.clamp(ai_punish_ratio, 1, 2),
					vehicle_object.vehicle_type, math.clamp(ai_punish_ratio, 1, 3),
					vehicle_object.strategy, math.clamp(ai_punish_ratio, 1, 2),
					constructable_vehicle_id, math.clamp(ai_punish_ratio, 1, 3)
				)
			end
		end

		-- make it be killed instantly if its not loaded
		if not vehicle_object.state.is_simulating and not kill_instantly then
			kill_instantly = true
			d.print(debug_prefix.."set kill_instantly to true as the vehicle is not simulating", true, 0)
		end

		-- set it on fire if its not forcibly being killed and if its not being killed instantly
		if not kill_instantly and not force_kill then
			local fire_id = vehicle_object.fire_id
			if fire_id ~= nil then
				d.print(debug_prefix.."spawned explosion fire, vehicle will explode if it takes enough damage.", true, 0)
				s.setFireData(fire_id, true, true)
			end
		end

		-- despawn the vehicle
		s.despawnVehicle(vehicle_id, kill_instantly)

		-- despawn all of the enemy AI NPCs
		for _, survivor in pairs(vehicle_object.survivors) do
			s.despawnObject(survivor.id, kill_instantly)
		end

		-- despawn its vehicle fire if it had one
		if vehicle_object.fire_id ~= nil then
			s.despawnObject(vehicle_object.fire_id, kill_instantly)
		end

		if kill_instantly and not force_kill then

			local explosion_sizes = {
				small = 0.5,
				medium = 1,
				large = 2
			}

			s.spawnExplosion(vehicle_object.transform, explosion_sizes[vehicle_object.size])

			d.print(debug_prefix.."size "..explosion_sizes[vehicle_object.size].." explosion spawned", true, 0)
		end
	end

	return true
end