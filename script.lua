--[[

The following comment contains information from the Devs for setting up a vehicle to be used in the DLC Weapons script.
These guidelies only outline the technical changes needed for a vehicle to interface with the script and is not a guide on making a stable/optimized vehicle.

General AI Requirements (Documented in-game):
====================================

AI Seats require the correct AI type to be set on their properties.
All pilot hotkeys should use Push mode.

SEAT TYPE = Ship Pilot
	Hotkey 1 = Engine On
	Hotkey 2 = Engine Off
	Axis W = Throttle
	Axis D = Steering

SEAT TYPE = Helicopter Pilot
	Hotkey 1 = Engine On 
	Hotkey 2 = Engine Off
	Axis W = Pitch
	Axis D = Roll
	Axis Up = Collective
	Axis Right = Yaw
	Trigger = Shoot

SEAT TYPE = Plane Pilot
	Hotkey 1 = Engine On 
	Hotkey 2 = Engine Off
	Axis W = Pitch
	Axis D = Roll
	Axis Up = Throttle
	Axis Right = Yaw
	Trigger = Shoot

SEAT TYPE = Gunner
	Axis W = Pitch
	Axis D = Yaw
	Trigger = Shoot

SEAT TYPE = Designator
	Axis W = Pitch
	Axis D = Yaw
	Trigger = Designate

Script Specific Requirements:
====================================

Required 1x Push Button named "Resupply"
This should turn on when the vehicle should be regarded as out of ammo, it will go and resupply at the nearest ally island

Required Seat Name (1 per vehicle):
Pilot
Captain

Forward firing guns should be attached to the pilot's trigger hotkey.
Pilots in Gun-Run state with pull their trigger when locked onto their target.

Optional Seat Names (x per vehicle or turret):
Gunner 1
Gunner 2
..

Guns controlled by gunners should be named the same as their controlling seat, e.g. Gunner 1

Ammo / Belts / Guns that need direct reloading should be named:
Ammo 1
Ammo 2
..

Batteries should be named:
Battery 1
Battery 2

Fuel Tanks should be named:
Jet 1
Jet 2
Diesel 1
Diesel 2

Antennas and ropes should be removed where possible and physics should be simplified as much as possible to preserve performance with many vehicles.

Playlist Specific Tags/Requirements:
====================================

Required type tag:
type=dlc_weapons,type=wep_boat
type=dlc_weapons,type=wep_plane
type=dlc_weapons,type=wep_heli
type=dlc_weapons,type=wep_land
type=dlc_weapons,type=wep_turret

Optional tags:
radar
(Increases the vision range for the vehicle)
sonar
(Adds medium underwater vision range to the vehicle)

Characters should be placed as needed
]]

local MAX_SQUAD_SIZE = 3
local MIN_ATTACKING_SQUADS = 2
local MAX_ATTACKING_SQUADS = 3

local COMMAND_NONE = ""
local COMMAND_ATTACK = "attack"
local COMMAND_DEFEND = "defend"
local COMMAND_INVESTIGATE = "investigate"
local COMMAND_ENGAGE = "engage"
local COMMAND_PATROL = "patrol"
local COMMAND_STAGE = "stage"
local COMMAND_RESUPPLY = "resupply"
local COMMAND_TURRET = "turret"

local AI_TYPE_BOAT = "boat"
local AI_TYPE_LAND = "land"
local AI_TYPE_PLANE = "plane"
local AI_TYPE_HELI = "heli"
local AI_TYPE_TURRET = "turret"

local VEHICLE_STATE_PATHING = "pathing"
local VEHICLE_STATE_HOLDING = "holding"

local TARGET_VISIBILITY_VISIBLE = "visible"
local TARGET_VISIBILITY_INVESTIGATE = "investigate"

local AI_SPEED_PSEUDO_PLANE = 60
local AI_SPEED_PSEUDO_HELI = 40
local AI_SPEED_PSEUDO_BOAT = 10
local AI_SPEED_PSEUDO_LAND = 5

local RESUPPLY_SQUAD_INDEX = 1

local FACTION_NEUTRAL = "neutral"
local FACTION_AI = "ai"
local FACTION_PLAYER = "player"

local CAPTURE_RADIUS = 1500
local ISLAND_CAPTURE_AMOUNT_PER_SECOND = 60

local VISIBLE_DISTANCE = 1500
local WAYPOINT_CONSUME_DISTANCE = 100

-- plane ai tuning settings
local PLANE_DOG_FIGHT_HEIGHT = 100
local PLANE_STRAFE_LOCK_DISTANCE = 800

local PLANE_EXPLOSION_DEPTH = -4
local HELI_EXPLOSION_DEPTH = -4
local BOAT_EXPLOSION_DEPTH = -17

local DEFAULT_SPAWNING_DISTANCE = 10 -- the fallback option for how far a vehicle must be away from another in order to not collide, highly reccomended to set tag

local CRUISE_HEIGHT = 300
local built_locations = {}
local flag_prefab = nil
local is_dlc_weapons = false
local render_debug = false
local g_debug_speed_multiplier = 1

local land_spawn_zones = {}

local playerData = {
	isDebugging = {}
}

if render_debug then
	local adminID = 0
	playerData.isDebugging.adminID = true
end

local capture_speeds = {
	100,
	150,
	175
}

local g_holding_pattern = {
    {x=500, z=500},
    {x=500, z=-500},
    {x=-500, z=-500},
    {x=-500, z=500}
}

local g_patrol_route = {
	{ x=0, z=8000 },
	{ x=8000, z=0 },
	{ x=-0, z=-8000 },
	{ x=-8000, z=0 },
	{ x=0, z=8000}
}

local g_is_air_ready = true
local g_is_boats_ready = false
local g_count_squads = 0
local g_count_attack = 0
local g_count_patrol = 0
local g_tick_counter = 0

local g_debug_vehicle_id = "0"

g_savedata = {
	ai_base_island = nil,
	player_base_island = nil,
	controllable_islands = {},
    ai_army = { squadrons = { [RESUPPLY_SQUAD_INDEX] = { command = COMMAND_RESUPPLY, ai_type = "", vehicles = {}, target_island = nil }} },
	player_vehicles = {},
	debug_data = {},
	constructable_vehicles = {},
	constructable_turrets = {},
	terrain_scanner_prefab = {},
	terrain_scanner_links = {},
	is_attack = false,
}

--[[
        Functions
--]]

function wpDLCDebug(message, requiresDebugging, isError, toPlayer)
	local deb_err = server.getAddonData((server.getAddonIndex())).name..(isError and " Error:" or " Debug:")
	
	if type(message) == "table" then
		printTable(message, requiresDebugging, isError, toPlayer)
	elseif requiresDebugging == true then
		if toPlayer ~= -1 and toPlayer ~= nil then
			if playerData.isDebugging.toPlayer then
				server.announce(deb_err, message, toPlayer)
			end
		else
			for k, v in pairs(playerData.isDebugging) do
				if playerData.isDebugging[k] then
					server.announce(deb_err, message, k)
				end
			end
		end
	else
		server.announce(deb_err, message, toPlayer or "-1")
	end
end

function onCreate(is_world_create)
	if g_savedata.settings == nil then
		g_savedata.settings = {
			SINKING_MODE = not property.checkbox("Disable Sinking Mode (Sinking Mode disables sea and air vehicle health)", false),
			CONTESTED_MODE = not property.checkbox("Disable Point Contesting", false),
			AI_PRODUCTION_TIME_BASE = property.slider("AI Production Time (Mins)", 1, 20, 1, 10) * 60 * 60,
			ISLAND_COUNT = property.slider("Island Count - Total AI Max will be 3x this value", 7, 17, 1, 17),
			MAX_PLANE_SIZE = property.slider("AI Planes Max", 0, 8, 1, 2),
			MAX_HELI_SIZE = property.slider("AI Helis Max", 0, 8, 1, 5),
			AI_INITIAL_SPAWN_COUNT = property.slider("AI Initial Spawn Count", 0, 15, 1, 10),
			CAPTURE_TIME = property.slider("Capture Time (Mins)", 10, 600, 1, 300) * 60 * 60,
			ENEMY_HP = property.slider("AI HP Base - Medium and Large AI will have 2x and 4x this", 0, 2500, 1, 325),
		}
	end

    is_dlc_weapons = server.dlcWeapons()

    if is_dlc_weapons then

		server.announce("Loading Script: " .. server.getAddonData((server.getAddonIndex())).name, "Complete", 0)

        if is_world_create then

			turret_zones = server.getZones("turret")

			for land_spawn_index, land_spawn in pairs(server.getZones("land_spawn")) do
				table.insert(land_spawn_zones, land_spawn.transform)
			end

            for i in iterPlaylists() do
                for j in iterLocations(i) do
                    build_locations(i, j)
                end
            end

            for i = 1, #built_locations do
				buildPrefabs(i)
            end

			local start_island = server.getStartIsland()

			-- init player base
			local flag_zones = server.getZones("capture")
			for flagZone_index, flagZone in pairs(flag_zones) do

				local flag_tile = server.getTile(flagZone.transform)
				if flag_tile.name == start_island.name or (flag_tile.name == "data/tiles/island_43_multiplayer_base.xml" and g_savedata.player_base_island == nil) then
					g_savedata.player_base_island = {
						name = flagZone.name,
						transform = flagZone.transform, 
						faction = FACTION_PLAYER, 
						faction_prev = FACTION_PLAYER,
						is_contested = false,
						capture_timer = g_savedata.settings.CAPTURE_TIME, 
						capture_timer_prev = g_savedata.settings.CAPTURE_TIME,
						map_id = server.getMapID(),
						assigned_squad_index = -1,
						ai_capturing = 0,
						players_capturing = 0
					}
					flag_zones[flagZone_index] = nil
				end
			end

			-- calculate furthest flag from player
			local furthest_flagZone_index = nil
			local distance_to_player_max = 0
			for flagZone_index, flagZone in pairs(flag_zones) do
				local distance_to_player = matrix.distance(flagZone.transform, g_savedata.player_base_island.transform)
				if distance_to_player_max < distance_to_player then
					distance_to_player_max = distance_to_player
					furthest_flagZone_index = flagZone_index
				end
			end

			-- set up ai base as furthest from player
			local flagZone = flag_zones[furthest_flagZone_index]
			g_savedata.ai_base_island = {
				name = flagZone.name, 
				transform = flagZone.transform, 
				faction = FACTION_AI, 
				faction_prev = FACTION_AI,
				is_contested = false,
				capture_timer = 0,
				capture_timer_prev = 0,
				map_id = server.getMapID(), 
				assigned_squad_index = -1, 
				production_timer = 0,
				zones = {},
				ai_capturing = 0,
				players_capturing = 0
			}
			for _, turretZone in pairs(turret_zones) do
				if(matrix.distance(turretZone.transform, flagZone.transform) <= 1000) then
					table.insert(g_savedata.ai_base_island.zones, turretZone)
				end
			end
			flag_zones[furthest_flagZone_index] = nil

			-- set up remaining neutral islands
			for _, flagZone in pairs(flag_zones) do
				local flag = server.spawnAddonComponent(matrix.multiply(flagZone.transform, matrix.translation(0, -7.86, 0)), flag_prefab.playlist_index, flag_prefab.location_index, flag_prefab.object_index, 0)
				local new_island = {
					name = flagZone.name, 
					flag_vehicle = flag, 
					transform = flagZone.transform, 
					faction = FACTION_NEUTRAL, 
					faction_prev = FACTION_NEUTRAL,
					is_contested = false,
					capture_timer = g_savedata.settings.CAPTURE_TIME / 2,
					capture_timer_prev = g_savedata.settings.CAPTURE_TIME / 2,
					map_id = server.getMapID(), 
					assigned_squad_index = -1, 
					zones = {},
					ai_capturing = 0,
					players_capturing = 0
				}

				for _, turretZone in pairs(turret_zones) do
					if(matrix.distance(turretZone.transform, flagZone.transform) <= 1000) then
						table.insert(new_island.zones, turretZone)
					end
				end

				table.insert(g_savedata.controllable_islands, new_island)

				if(#g_savedata.controllable_islands >= g_savedata.settings.ISLAND_COUNT) then
					break
				end
			end

			-- game setup

			local t, a = getObjectiveIsland()

			t.capture_timer = 0 -- capture nearest ally
			t.faction = FACTION_AI

			for i = 1, g_savedata.settings.AI_INITIAL_SPAWN_COUNT do
				spawnAIVehicle() -- spawn initial ai
			end
		else
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					server.removeMapObject(0,vehicle_object.map_id)
				end
			end
		end
	end
end


function buildPrefabs(location_index)
    local location = built_locations[location_index]

	-- construct vehicle-character prefab list
	for key, vehicle in pairs(location.objects.vehicles) do

		local prefab_data = {location = location, vehicle = vehicle, survivors = {}, fires = {}}

		for key, char in  pairs(location.objects.survivors) do
			table.insert(prefab_data.survivors, char)
		end

		for key, fire in  pairs(location.objects.fires) do
			table.insert(prefab_data.fires, fire)
		end

		if hasTag(vehicle.tags, "type=wep_turret") then
			table.insert(g_savedata.constructable_turrets, prefab_data)
			if render_debug then server.announce("dlcw", "prefab turret") end
		elseif #prefab_data.survivors > 0 then
			table.insert(g_savedata.constructable_vehicles, prefab_data)
			if render_debug then server.announce("dlcw", "prefab vehicle") end
		end
	end
end

function spawnTurret(island)
	local selected_prefab = g_savedata.constructable_turrets[math.random(1, #g_savedata.constructable_turrets)]

	if (#island.zones < 1) then return end

	local spawnbox_index = math.random(1, #island.zones)
	if island.zones[spawnbox_index].is_spawned == true then
		return
	end
	island.zones[spawnbox_index].is_spawned = true
	local spawn_transform = island.zones[spawnbox_index].transform

	-- spawn objects
	local all_addon_components = {}
	local spawned_objects = {
		spawned_vehicle = spawnObject(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.vehicle, 0, nil, all_addon_components),
		survivors = spawnObjects(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.survivors, all_addon_components),
		fires = spawnObjects(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.fires, all_addon_components),
	}

	if spawned_objects.spawned_vehicle ~= nil then
		local vehicle_survivors = {}
		for key, char in  pairs(spawned_objects.survivors) do
			local c = server.getCharacterData(char.id)
			server.setCharacterData(char.id, c.hp, true, true)
			server.setAIState(char.id, 1)
			server.setAITargetVehicle(char.id, -1)
			table.insert(vehicle_survivors, char)
		end

		local home_x, home_y, home_z = matrix.position(spawn_transform)
		local vehicle_data = {
			id = spawned_objects.spawned_vehicle.id,
			survivors = vehicle_survivors,
			path = {
				[1] = {
					x = home_x,
					y = home_y,
					z = home_z
				}
			},
			state = {
				s = "stationary",
				timer = math.fmod(spawned_objects.spawned_vehicle.id, 300),
				is_simulating = false
			},
			map_id = server.getMapID(),
			ai_type = spawned_objects.spawned_vehicle.ai_type,
			size = spawned_objects.spawned_vehicle.size,
			holding_index = 1,
			vision = {
				radius = getTagValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				base_radius = getTagValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				is_radar = hasTag(selected_prefab.vehicle.tags, "radar"),
				is_sonar = hasTag(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = getTagValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE
			},
			transform = spawn_transform,
			target_player_id = -1,
			target_vehicle_id = -1,
			home_island = island.name,
			current_damage = 0,
			fire_id = nil,
			spawnbox_index = spawnbox_index,
		}

		if #spawned_objects.fires > 0 then
			vehicle_data.fire_id = spawned_objects.fires[1].id
		end
		
		local squad = addToSquadron(vehicle_data)
		setSquadCommand(squad, COMMAND_TURRET)

		if render_debug then server.announce("dlcw", "spawning island turret") end
	end
end

function spawnAIVehicle(nearPlayer, user_peer_id, type)
	local plane_count = 0
	local heli_count = 0
	local army_count = 0
	local land_count = 0
	
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.ai_type ~= AI_TYPE_TURRET then army_count = army_count + 1 end
			if vehicle_object.ai_type == AI_TYPE_PLANE then plane_count = plane_count + 1 end
			if vehicle_object.ai_type == AI_TYPE_HELI then heli_count = heli_count + 1 end
			if vehicle_object.ai_type == AI_TYPE_LAND then land_count = land_count + 1 end
		end
	end

	if army_count >= #g_savedata.controllable_islands * MAX_SQUAD_SIZE then return end

	local can_spawn = true
	local spawn_attempts = 0
	local selected_prefab = nil
	repeat
		selected_prefab = g_savedata.constructable_vehicles[math.random(1, #g_savedata.constructable_vehicles)]
		spawn_attempts = spawn_attempts + 1

		if hasTag(selected_prefab.vehicle.tags, "type=wep_plane") and plane_count >= g_savedata.settings.MAX_PLANE_SIZE then can_spawn = false end
		if hasTag(selected_prefab.vehicle.tags, "type=wep_heli") and heli_count >= g_savedata.settings.MAX_HELI_SIZE then can_spawn = false end

		if (spawn_attempts > 10) then return end -- Failed to spawn
	until (can_spawn)

	local spawn_transform = matrix.multiply(g_savedata.ai_base_island.transform, matrix.translation(math.random(-500, 500), CRUISE_HEIGHT + 200, math.random(-500, 500)))

	if hasTag(selected_prefab.vehicle.tags, "type=wep_boat") then
		if nearPlayer ~= true then
			local boat_spawn_transform, found_ocean = server.getOceanTransform(g_savedata.ai_base_island.transform, 500, 1500)
			if found_ocean == false then return end
			spawn_transform = matrix.multiply(boat_spawn_transform, matrix.translation(math.random(-500, 500), 0, math.random(-500, 500)))
		else
			local pMatrix, is_success = server.getPlayerPos(user_peer_id)
			if is_success ~= true then
				local name, is_success = server.getPlayerName(user_peer_id)
				if is_success ~= true then
					wpDLCDebug("failed to get the specified player's name, peer id: "..user_peer_id, true, true)
					wpDLCDebug("failed to get the specified player's matrix, peer id: "..user_peer_id.." returned matrix: "..pMatrix[13].. " y: "..pMatrix[14].." z: "..pMatrix[15], true, true)
				else
					wpDLCDebug("failed to get the specified player's matrix, peer name: "..name.." returned x: "..pMatrix[13].. " y: "..pMatrix[14].." z: "..pMatrix[15], true, true)
				end
				return false
			else
				wpDLCDebug("player's matrix, peer id: "..user_peer_id.." returned x: "..pMatrix[13].. " y: "..pMatrix[14].." z: "..pMatrix[15], true, false)
			end
			local boat_spawn_transform, found_ocean = server.getOceanTransform(pMatrix, 500, 6000)
			if found_ocean == false then return end
			spawn_transform = matrix.multiply(boat_spawn_transform, matrix.translation(math.random(-500, 500), 0, math.random(-500, 500)))
		end
	elseif hasTag(selected_prefab.vehicle.tags, "type=wep_land") then
		local land_spawn_locations = {}
		for island_index, island in pairs(g_savedata.controllable_islands) do
			if island.faction == FACTION_AI then
				wpDLCDebug("is owned by AI", true, false)
				for land_spawn_index, land_spawn in pairs(land_spawn_zones) do
					wpDLCDebug("Looping spawn", true, false)
					if matrix.distance(land_spawn, island.transform) <= 1000 then
						wpDLCDebug("is on island", true, false)
						table.insert(land_spawn_locations, land_spawn)
					end
				end
			end
		end
		if #land_spawn_locations > 0 then
			spawn_transform = land_spawn_locations[math.random(1, #land_spawn_locations)]
		else
			wpDLCDebug("No suitible spawn location found for land vehicle", true, false)
			return false
		end
	end

	-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if matrix.distance(spawn_transform, vehicle_object.transform) < (getTagValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE + vehicle_object.spawning_transform.distance) then
				wpDLCDebug("cancelling spawning vehicle, due to its proximity to vehicle "..vehicle_id, false, true)
				return false
			end
		end
	end

	-- spawn objects
	local all_addon_components = {}
	local spawned_objects = {
		spawned_vehicle = spawnObject(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.vehicle, 0, nil, all_addon_components),
		survivors = spawnObjects(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.survivors, all_addon_components),
		fires = spawnObjects(spawn_transform, selected_prefab.location.playlist_index, selected_prefab.location.location_index, selected_prefab.fires, all_addon_components),
	}
	local vehX, vehY, vehZ = matrix.position(spawn_transform)
	if selected_prefab.vehicle.display_name ~= nil then
		wpDLCDebug("spawned vehicle: "..selected_prefab.vehicle.display_name.." at X: "..vehX.." Y: "..vehY.." Z: "..vehZ, true, false)
	else
		wpDLCDebug("the selected vehicle is nil", true, true)
	end

	if render_debug then server.announce("dlcw", "spawning army vehicle: " .. selected_prefab.location.data.name .. " / " .. selected_prefab.location.playlist_index .. " / " .. selected_prefab.vehicle.display_name) end

	if spawned_objects.spawned_vehicle ~= nil then
		local vehicle_survivors = {}
		for key, char in  pairs(spawned_objects.survivors) do
			local c = server.getCharacterData(char.id)
			server.setCharacterData(char.id, c.hp, true, true)
			server.setAIState(char.id, 1)
			server.setAITargetVehicle(char.id, -1)
			table.insert(vehicle_survivors, char)
		end

		local home_x, home_y, home_z = matrix.position(spawn_transform)

		local vehicle_data = { 
			id = spawned_objects.spawned_vehicle.id, 
			survivors = vehicle_survivors, 
			path = { 
				[1] = {
					x = home_x, 
					y = CRUISE_HEIGHT + (spawned_objects.spawned_vehicle.id % 10 * 20), 
					z = home_z
				} 
			}, 
			state = { 
				s = VEHICLE_STATE_HOLDING, 
				timer = math.fmod(spawned_objects.spawned_vehicle.id, 300),
				is_simulating = false
			}, 
			map_id = server.getMapID(), 
			ai_type = spawned_objects.spawned_vehicle.ai_type, 
			size = spawned_objects.spawned_vehicle.size,
			holding_index = 1, 
			vision = { 
				radius = getTagValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				base_radius = getTagValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				is_radar = hasTag(selected_prefab.vehicle.tags, "radar"),
				is_sonar = hasTag(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = getTagValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE
			},
			is_resupply_on_load = false,
			transform = spawn_transform,
			target_vehicle_id = -1,
			target_player_id = -1,
			current_damage = 0,
			fire_id = nil,
		}

		if #spawned_objects.fires > 0 then
			vehicle_data.fire_id = spawned_objects.fires[1].id
		end

		addToSquadron(vehicle_data)
	end
end

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, arg1, arg2, arg3, arg4)
	if is_dlc_weapons then

		-- non admin commands

		-- admin commands
		if is_admin then
			if command == "?wep_reset" then
				for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						setSquadCommand(squad, COMMAND_NONE)
					end
				end
				g_is_air_ready = true
				g_is_boats_ready = false
				g_savedata.is_attack = false

			elseif command == "?wep_debug_vehicle" then
				g_debug_vehicle_id = arg1


			elseif command == "?wep_debug" then
				wpDLCDebug("?wep_debug has been disabled, use ?WDLCD instead, or ?enableWeaponsDLCDebug", false, true, user_peer_id)

				--[[--]]


			elseif command == "?wep_debug_speed" then
					g_debug_speed_multiplier = arg1


			elseif command == "?wep_vreset" then
					server.resetVehicleState(arg1)

			elseif command == "?target" then
				for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						for i, char in  pairs(vehicle_object.survivors) do
							server.setAITargetVehicle(char.id, arg1)
						end
					end
				end

			elseif command == "?spawnEnemyAI" or command == "?SEAI" then
				spawnAIVehicle(true, user_peer_id)

			elseif command == "?enableWeaponsDLCDebug" or command == "?WDLCD" then
				render_debug = not render_debug
				playerData.isDebugging.user_peer_id = not playerData.isDebugging.user_peer_id

				if playerData.isDebugging.user_peer_id ~= true then
					wpDLCDebug("Debugging Disabled", false, false, user_peer_id)
				else
					wpDLCDebug("Debugging Enabled", false, false, user_peer_id)
				end

				for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						server.removeMapObject(0,vehicle_object.map_id)
					end
				end
			
			elseif command == "?WDLCST" or command == "?WeaponsDLCSpawnTurret" then
				local turrets_spawned = 0
				for island_index, island in pairs(g_savedata.controllable_islands) do
					if island.faction == FACTION_AI then
						spawnTurret(island)
						turrets_spawned = turrets_spawned + 1
					end
				end
				wpDLCDebug("attempted to spawn "..turrets_spawned.." turrets", false, false, user_peer_id)

			elseif command == "?WDLCCP" or command == "?WeaponsDLCCapturePoint" then
				if arg1 and arg2 then
					local is_island = false
					for island_index, island in pairs(g_savedata.controllable_islands) do
						if island.name == string.gsub(arg1, "_", " ") then
							is_island = true
							if island.faction ~= arg2 then
								if arg2 == FACTION_AI or arg2 == FACTION_NEUTRAL or arg2 == FACTION_PLAYER then
									captureIsland(island, arg2, user_peer_id)
								else
									wpDLCDebug(arg2.." is not a valid faction! valid factions: | ai | neutral | player", false, true, user_peer_id)
								end
							else
								wpDLCDebug(island.name.." is already set to "..island.faction..".", false, true, user_peer_id)
							end
						end
					end
					if not is_island then
						wpDLCDebug(arg1.." is not a valid island! note: required to use \"_\" instead of \" \" in its name", false, true, user_peer_id)
					end
				else
					wpDLCDebug("Invalid Syntax! command usage: ?WDLCCP (island_name) (faction)", false, true, user_peer_id)
				end
			end
		else
			wpDLCDebug("You do not have permission to execute "..command..".", false, true, user_peer_id)
		end
	end
end

function captureIsland(island, override, peer_id)
	local faction_to_set = nil

	if override ~= nil then
		if island.capture_timer <= 0 and island.faction ~= FACTION_AI then -- Player Lost Island
			faction_to_set = FACTION_AI
		elseif island.capture_timer >= g_savedata.settings.CAPTURE_TIME and island.faction ~= FACTION_PLAYER then -- Player Captured Island
			faction_to_set = FACTION_PLAYER
		end
	end

	-- set it to the override, otherwise if its supposted to be capped then set it to the specified, otherwise set it to ignore
	faction_to_set = override or faction_to_set or "ignore"

	-- set it to ai
	if faction_to_set == FACTION_AI then
		island.capture_timer = 0
		island.faction = FACTION_AI
		g_savedata.is_attack = false

		if peer_id then
			name = server.getPlayerName(peer_id)
			server.notify(-1, "ISLAND CAPTURED", "The enemy has captured an island. (set manually by "..name.." via command)", 1)
		else
			server.notify(-1, "ISLAND CAPTURED", "The enemy has captured an island.", 3)
		end

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if (squad.command == COMMAND_ATTACK or squad.command == COMMAND_STAGE) and island.transform == squad.target_island.transform then
				setSquadCommand(squad, COMMAND_NONE) -- free squads from objective
			end
		end
	-- set it to player
	elseif faction_to_set == FACTION_PLAYER then
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
		island.faction = FACTION_PLAYER

		if peer_id then
			name = server.getPlayerName(peer_id)
			server.notify(-1, "ISLAND CAPTURED", "Successfully captured an island. (set manually by "..name.." via command)", 1)
		else
			server.notify(-1, "ISLAND CAPTURED", "Successfully captured an island.", 1)
		end

		-- update vehicles looking to resupply
		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index == RESUPPLY_SQUAD_INDEX then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					resetPath(vehicle_object)
				end
			end
		end
	-- set it to neutral
	elseif faction_to_set == FACTION_NEUTRAL then
		island.capture_timer = g_savedata.settings.CAPTURE_TIME/2
		island.faction = FACTION_NEUTRAL

		if peer_id then
			name = server.getPlayerName(peer_id)
			server.notify(-1, "ISLAND SET NEUTRAL", "Successfully set an island to neutral. (set manually by "..name.." via command)", 1)
		else
			server.notify(-1, "ISLAND SET NEUTRAL", "Successfully set an island to neutral.", 1)
		end

		-- update vehicles looking to resupply
		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index == RESUPPLY_SQUAD_INDEX then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					resetPath(vehicle_object)
				end
			end
		end
	elseif island.capture_timer > g_savedata.settings.CAPTURE_TIME then -- if its over 100% island capture
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
	elseif island.capture_timer < 0 then -- if its less than 0% island capture
		island.capture_timer = 0
	end
end


function onPlayerJoin(steam_id, name, peer_id)
	if is_dlc_weapons then
		for island_index, island in pairs(g_savedata.controllable_islands) do
			updatePeerIslandMapData(peer_id, island)
		end

		local ts_x, ts_y, ts_z = matrix.position(g_savedata.ai_base_island.transform)
		server.removeMapObject(peer_id, g_savedata.ai_base_island.map_id)
		server.addMapObject(peer_id, g_savedata.ai_base_island.map_id, 0, 10, ts_x, ts_z, 0, 0, 0, 0, g_savedata.ai_base_island.name.." ("..g_savedata.ai_base_island.faction..")", 1, "", 255, 0, 0, 255)

		local ts_x, ts_y, ts_z = matrix.position(g_savedata.player_base_island.transform)
		server.removeMapObject(peer_id, g_savedata.player_base_island.map_id)
		server.addMapObject(peer_id, g_savedata.player_base_island.map_id, 0, 10, ts_x, ts_z, 0, 0, 0, 0, g_savedata.player_base_island.name.." ("..g_savedata.player_base_island.faction..")", 1, "", 0, 255, 0, 255)
	end
end

function onVehicleDamaged(incoming_vehicle_id, amount, x, y, z, body_id)
	if is_dlc_weapons then
		vehicleData = server.getVehicleData(incoming_vehicle_id)
			local player_vehicle = g_savedata.player_vehicles[incoming_vehicle_id]

			if player_vehicle ~= nil then
				local damage_prev = player_vehicle.current_damage
				player_vehicle.current_damage = player_vehicle.current_damage + amount

				if damage_prev <= player_vehicle.damage_threshold and player_vehicle.current_damage > player_vehicle.damage_threshold then
					player_vehicle.death_pos = player_vehicle.transform
				end
			end

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_id == incoming_vehicle_id and body_id == 0 then
						if vehicle_object.current_damage == nil then vehicle_object.current_damage = 0 end
						local damage_prev = vehicle_object.current_damage
						vehicle_object.current_damage = vehicle_object.current_damage + amount

						local enemy_hp = g_savedata.settings.ENEMY_HP
						if g_savedata.settings.SINKING_MODE == false or g_savedata.settings.SINKING_MODE and hasTag(vehicleData.tags, "type=wep_land") or g_savedata.settings.SINKING_MODE and hasTag(vehicleData.tags, "type=wep_turret") then
							if vehicle_object.size == "large" then
								enemy_hp = enemy_hp * 4
							elseif vehicle_object.size == "medium" then
								enemy_hp = enemy_hp * 2
							end

							if damage_prev <= (enemy_hp * 2) and vehicle_object.current_damage > (enemy_hp * 2) then
								killVehicle(squad_index, vehicle_id, true)
							elseif damage_prev <= enemy_hp and vehicle_object.current_damage > enemy_hp then
								killVehicle(squad_index, vehicle_id, false)
							end
						end
					end
				end
			end
		end
	end
end

function onVehicleTeleport(vehicle_id, peer_id, x, y, z)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id].current_damage = 0
		end
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if is_dlc_weapons then
		if peer_id ~= -1 then
			-- player spawned vehicle
			g_savedata.player_vehicles[vehicle_id] = {
				current_damage = 0, 
				damage_threshold = 100, 
				death_pos = nil, 
				map_id = server.getMapID()
			}
		end
	end
end

function onVehicleDespawn(vehicle_id, peer_id)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id] = nil
		end
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for ai_vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_id == ai_vehicle_id then
				cleanVehicle(squad_index, vehicle_id)
			end
		end
	end
end

function cleanVehicle(squad_index, vehicle_id)

	local vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id]

	if render_debug then
		server.announce("dlcw", "cleaned vehicle: " .. vehicle_id)

		server.removeMapObject(0 ,vehicle_object.map_id)
		server.removeMapLine(0 ,vehicle_object.map_id)
		for i = 1, #vehicle_object.path - 1 do
			local waypoint = vehicle_object.path[i]
			server.removeMapLine(0, waypoint.ui_id)
		end
	end

	if vehicle_object.ai_type == AI_TYPE_TURRET and vehicle_object.spawnbox_index ~= nil then
		for island_index, island in pairs(g_savedata.controllable_islands) do		
			if island.name == vehicle_object.home_island then
				island.zones[vehicle_object.spawnbox_index].is_spawned = false
			end
		end
	end

	for _, survivor in pairs(vehicle_object.survivors) do
		server.despawnObject(survivor.id, true)
	end

	if vehicle_object.fire_id ~= nil then
		server.despawnObject(vehicle_object.fire_id, true)
	end

	g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id] = nil

	if squad_index ~= RESUPPLY_SQUAD_INDEX then
		if tableLength(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
			g_savedata.ai_army.squadrons[squad_index] = nil

			for island_index, island in pairs(g_savedata.controllable_islands) do
				if island.assigned_squad_index == squad_index then
					island.assigned_squad_index = -1
				end
			end
		end
	end
end

function onVehicleUnload(incoming_vehicle_id)
	if is_dlc_weapons then
		if render_debug then server.announce("dlcw", "onVehicleUnload: " .. incoming_vehicle_id) end

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do
				if incoming_vehicle_id == vehicle_id then
					if vehicle_object.is_killed == true then
						cleanVehicle(squad_index, vehicle_id)
					else
						if render_debug then server.announce("dlcw", "onVehicleUnload: set vehicle pseudo: " .. vehicle_id) end
						vehicle_object.state.is_simulating = false
					end
				end
			end
		end
	end
end

function setLandTarget(vehicle_id, vehicle_object)
	server.setVehicleKeypad(vehicle_id, "AI_WAYPOINT_LAND_X", vehicle_object.path[1].x)
	server.setVehicleKeypad(vehicle_id, "AI_WAYPOINT_LAND_Z", vehicle_object.path[1].z)
	--wpDLCDebug("x: "..vehicle_object.path[1].x.." z: "..vehicle_object.path[1].z, true, false)
end

function onVehicleLoad(incoming_vehicle_id)
	if is_dlc_weapons then
		if render_debug then server.announce("dlcw", "onVehicleLoad: " .. incoming_vehicle_id) end

		if g_savedata.player_vehicles[incoming_vehicle_id] ~= nil then
			local player_vehicle_data = server.getVehicleData(incoming_vehicle_id)
			g_savedata.player_vehicles[incoming_vehicle_id].damage_threshold = player_vehicle_data.voxels / 4
			g_savedata.player_vehicles[incoming_vehicle_id].transform = server.getVehiclePos(incoming_vehicle_id)
		end

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do
				if incoming_vehicle_id == vehicle_id then
					if render_debug then server.announce("dlcw", "onVehicleLoad: set vehicle simulating: " .. vehicle_id) end
					vehicle_object.state.is_simulating = true
					vehicle_object.transform = server.getVehiclePos(vehicle_id)

					if vehicle_object.is_resupply_on_load then
						vehicle_object.is_resupply_on_load = false
						reload(vehicle_id)
					end

					for i, char in pairs(vehicle_object.survivors) do
						if vehicle_object.ai_type == AI_TYPE_TURRET then
							--Gunners
							server.setCharacterSeated(char.id, vehicle_id, "Gunner ".. i)
							local c = server.getCharacterData(char.id)
							server.setCharacterData(char.id, c.hp, true, true)
						else
							if i == 1 then
								if vehicle_object.ai_type == AI_TYPE_BOAT or vehicle_object.ai_type == AI_TYPE_LAND then
									server.setCharacterSeated(char.id, vehicle_id, "Captain")
								else
									server.setCharacterSeated(char.id, vehicle_id, "Pilot")
								end
								local c = server.getCharacterData(char.id)
								server.setCharacterData(char.id, c.hp, true, true)
							else
								--Gunners
								server.setCharacterSeated(char.id, vehicle_id, "Gunner ".. (i - 1))
								local c = server.getCharacterData(char.id)
								server.setCharacterData(char.id, c.hp, true, true)
							end
						end
					end
					if vehicle_object.ai_type == AI_TYPE_LAND then
						if(#vehicle_object.path >= 1) then
							setLandTarget(vehicle_id, vehicle_object)
						end
						if g_savedata.terrain_scanner_links[vehicle_id] == nil then
							local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_object.transform)
							local get_terrain_matrix = matrix.translation(vehicle_x, 1000, vehicle_z)
							local terrain_object, success = server.spawnAddonComponent(get_terrain_matrix, g_savedata.terrain_scanner_prefab.playlist_index, g_savedata.terrain_scanner_prefab.location_index, g_savedata.terrain_scanner_prefab.object_index, 0)
							if success then
								server.setVehiclePos(vehicle_id, matrix.translation(vehicle_x, 0, vehicle_z))
								g_savedata.terrain_scanner_links[vehicle_id] = terrain_object.id
							else
								wpDLCDebug("Unable to spawn terrain height checker!", true, true)
							end
						elseif g_savedata.terrain_scanner_links[vehicle_id] == "Just Teleported" then
							g_savedata.terrain_scanner_links[vehicle_id] = nil
						end
					elseif vehicle_object.ai_type == AI_TYPE_BOAT then
						local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_object.transform)
						if vehicle_y > 10 and vehicle_object.current_damage ~= 0 then -- if its above y 10 and if it has taken any damage
							killVehicle(squad_index, vehicle_id, true, true) -- delete vehicle
						end
					end
					refuel(vehicle_id)
					return
				end
			end
		end
	end
end

function resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		server.removeMapID(0, v.ui_id)
	end

	vehicle_object.path = {}
end

function addPath(vehicle_object, target_dest)
	if(vehicle_object.ai_type == AI_TYPE_TURRET) then vehicle_object.state.s = "stationary" return end

	if(vehicle_object.ai_type == AI_TYPE_BOAT) then
		local dest_x, dest_y, dest_z = matrix.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		local path_list = server.pathfindOcean(path_start_pos, matrix.translation(dest_x, 0, dest_z))
		for path_index, path in pairs(path_list) do
			table.insert(vehicle_object.path, { x =  path.x + math.random(-50, 50), y = 0, z = path.z + math.random(-50, 50), ui_id = server.getMapID() })
		end
	elseif vehicle_object.ai_type == AI_TYPE_LAND then
		local dest_x, dest_y, dest_z = matrix.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		start_x, start_y, start_z = matrix.position(vehicle_object.transform)
 
		local path_list = server.pathfindOcean(path_start_pos, matrix.translation(dest_x, 1000, dest_z))
		for path_index, path in pairs(path_list) do
			table.insert(vehicle_object.path, { x =  path.x, y = path.y, z = path.z, ui_id = server.getMapID() })
		end
		setLandTarget(vehicle_id, vehicle_object)
	else
		local dest_x, dest_y, dest_z = matrix.position(target_dest)
		table.insert(vehicle_object.path, { x = dest_x, y = dest_y, z = dest_z, ui_id = server.getMapID() })
	end

	vehicle_object.state.s = VEHICLE_STATE_PATHING
end

function tickGamemode()
	if is_dlc_weapons then
		-- tick enemy base spawning
		g_savedata.ai_base_island.production_timer = g_savedata.ai_base_island.production_timer + 1
		if g_savedata.ai_base_island.production_timer > g_savedata.settings.AI_PRODUCTION_TIME_BASE then
			g_savedata.ai_base_island.production_timer = 0

			spawnTurret(g_savedata.ai_base_island)
			spawnAIVehicle()
		end

		for island_index, island in pairs(g_savedata.controllable_islands) do

			if island.ai_capturing == nil then
				island.ai_capturing = 0
				island.players_capturing = 0
			end

			-- spawn turrets at owned islands
			if island.faction == FACTION_AI and g_savedata.ai_base_island.production_timer == 1 then
				spawnTurret(island)
			end
			
			-- tick capture timers
			local tick_rate = 60
			if island.capture_timer >= 0 and island.capture_timer <= g_savedata.settings.CAPTURE_TIME then -- if the capture timers are within range of the min and max
				local playerList = server.getPlayers()
				
				-- does a check for how many enemy ai are capturing the island
				if island.capture_timer > 0 then
					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isTickID(vehicle_id, tick_rate) then
								if matrix.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS / 1.5 then
									island.ai_capturing = island.ai_capturing + 1
								elseif matrix.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS and island.faction == FACTION_AI then
									island.ai_capturing = island.ai_capturing + 1
								end
							end
						end
					end
				end

				-- does a check for how many players are capturing the island
				if g_savedata.settings.CAPTURE_TIME > island.capture_timer then -- if the % captured is not 100% or more
					for _, player in pairs(playerList) do
						if isTickID(player.id, tick_rate) then
							local player_transform = server.getPlayerPos(player.id)
							local flag_vehicle_transform = server.getVehiclePos(island.flag_vehicle.id)
							if matrix.distance(flag_vehicle_transform, player_transform) < 15 then -- if they are within 15 metres of the capture point
								island.players_capturing = island.players_capturing + 1
							elseif matrix.distance(flag_vehicle_transform, player_transform) < CAPTURE_RADIUS / 5 and island.faction == FACTION_PLAYER then -- if they are within CAPTURE_RADIUS / 5 metres of the capture point and if they own the point, this is their defending radius
								island.players_capturing = island.players_capturing + 1
							end
						end
					end
				end


				if isTickID(60, tick_rate) then
					if island.players_capturing > 0 and island.ai_capturing > 0 and g_savedata.settings.CONTESTED_MODE then -- if theres ai and players capping, and if contested mode is enabled
						if island.is_contested == false then -- notifies that an island is being contested
							server.notify(-1, "ISLAND CONTESTED", "An island is being contested!", 1)
							island.is_contested = true
							updatePeerIslandMapData(-1, island)
						end
					else
						island.is_contested = false
						if island.players_capturing > 0 then -- tick player progress if theres one or more players capping
							island.capture_timer = island.capture_timer + (ISLAND_CAPTURE_AMOUNT_PER_SECOND * capture_speeds[math.min(island.players_capturing, 3)] / 5) *  tick_rate / 60
						elseif island.ai_capturing > 0 then -- tick AI progress if theres one or more ai capping
							island.capture_timer = island.capture_timer - (ISLAND_CAPTURE_AMOUNT_PER_SECOND * capture_speeds[math.min(island.ai_capturing, 3)] / 20) * tick_rate / 60
						end
					end
					
					-- displays tooltip on vehicle
					local cap_percent = math.floor((island.capture_timer/g_savedata.settings.CAPTURE_TIME) * 100)
	
					if island.is_contested then -- if the point is contested (both teams trying to cap)
						server.setVehicleTooltip(island.flag_vehicle.id, "Contested: "..cap_percent.."%")
	
					elseif island.faction ~= FACTION_PLAYER then -- if the player doesn't own the point
	
						if island.ai_capturing == 0 and island.players_capturing == 0 then -- if nobody is capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Capture: "..cap_percent.."%")
	
						elseif island.ai_capturing == 0 then -- if players are capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Capturing: "..cap_percent.."%")
	
						else -- if ai is capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
	
						end
					else -- if the player does own the point
	
						if island.ai_capturing == 0 and island.players_capturing == 0 then -- if nobody is capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Captured: "..cap_percent.."%")
	
						elseif island.ai_capturing == 0 then -- if players are capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Re-Capturing: "..cap_percent.."%")
	
						else -- if ai is capping the point
							server.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
	
						end
					end

					-- resets amount capping
					island.ai_capturing = 0
					island.players_capturing = 0
				end
				captureIsland(island)
				--[[
				if island.capture_timer <= 0 and island.faction ~= FACTION_AI then -- Player Lost Island
					island.capture_timer = 0
					island.faction = FACTION_AI
					g_savedata.is_attack = false

					server.notify(-1, "ISLAND CAPTURED", "The enemy has captured an island.", 3)

					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						if (squad.command == COMMAND_ATTACK or squad.command == COMMAND_STAGE) and island.transform == squad.target_island.transform then
							setSquadCommand(squad, COMMAND_NONE) -- free squads from objective
						end
					end
				elseif island.capture_timer >= g_savedata.settings.CAPTURE_TIME and island.faction ~= FACTION_PLAYER then -- Player Captured Island
					island.capture_timer = g_savedata.settings.CAPTURE_TIME
					island.faction = FACTION_PLAYER

					server.notify(-1, "ISLAND CAPTURED", "Successfully captured an island.", 1)

					-- update vehicles looking to resupply
					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						if squad_index == RESUPPLY_SQUAD_INDEX then
							for vehicle_id, vehicle_object in pairs(squad.vehicles) do
								resetPath(vehicle_object)
							end
						end
					end
				elseif island.capture_timer > g_savedata.settings.CAPTURE_TIME then -- if its over 100% island capture
					island.capture_timer = g_savedata.settings.CAPTURE_TIME
				elseif island.capture_timer < 0 then -- if its less than 0% island capture
					island.capture_timer = 0
				end
				]]
			end
		end

		if render_debug then

			local ts_x, ts_y, ts_z = matrix.position(g_savedata.ai_base_island.transform)
			server.removeMapObject(0, g_savedata.ai_base_island.map_id)

			local plane_count = 0
			local heli_count = 0
			local army_count = 0
			local land_count = 0
		
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.ai_type ~= AI_TYPE_TURRET then army_count = army_count + 1 end
					if vehicle_object.ai_type == AI_TYPE_PLANE then plane_count = plane_count + 1 end
					if vehicle_object.ai_type == AI_TYPE_HELI then heli_count = heli_count + 1 end
					if vehicle_object.ai_type == AI_TYPE_LAND then land_count = land_count + 1 end
				end
			end

			local t, a = getObjectiveIsland()
			local debug_data = "Air_Staged: " .. tostring(g_is_air_ready) .. "\n"
			debug_data = debug_data .. "Sea_Staged: " .. tostring(g_is_boats_ready) .. "\n"
			debug_data = debug_data .. "Army_Count: " .. tostring(army_count) .. "\n"
			debug_data = debug_data .. "Land_Count: " .. tostring(land_count) .. "\n"
			debug_data = debug_data .. "Turret_Count: " .. tostring(turret_count) .. "\n"
			debug_data = debug_data .. "Squad Count: " .. tostring(g_count_squads) .. "\n"
			debug_data = debug_data .. "Attack Count: " .. tostring(g_count_attack) .. "\n"
			debug_data = debug_data .. "Patrol Count: " .. tostring(g_count_patrol) .. "\n"

			if t then
				debug_data = debug_data .. "Target: " .. t.name .. "\n"
			end
			if a then
				debug_data = debug_data .. " Ally: " .. a.name
			end
			server.addMapObject(0, g_savedata.ai_base_island.map_id, 0, 4, ts_x, ts_z, 0, 0, 0, 0, "Ai Base Island \n" .. g_savedata.ai_base_island.production_timer .. "/" .. g_savedata.settings.AI_PRODUCTION_TIME_BASE, 1, debug_data, 0, 0, 255, 255)

			local ts_x, ts_y, ts_z = matrix.position(g_savedata.player_base_island.transform)
			server.removeMapObject(0, g_savedata.player_base_island.map_id)
			server.addMapObject(0, g_savedata.player_base_island.map_id, 0, 4, ts_x, ts_z, 0, 0, 0, 0, "Player Base Island", 1, debug_data, 0, 0, 255, 255)
		end

		-- Render Island Info
		for island_index, island in pairs(g_savedata.controllable_islands) do
			if isTickID(island_index, 60) then
				if island.capture_timer ~= island.capture_timer_prev or island.faction ~= island.faction_prev then
					updatePeerIslandMapData(-1, island)
				end

				island.capture_timer_prev = island.capture_timer
				island.faction_prev = island.faction
			end
		end
	end
end

function updatePeerIslandMapData(peer_id, island)
	if is_dlc_weapons then
		local ts_x, ts_y, ts_z = matrix.position(island.transform)
		server.removeMapObject(peer_id, island.map_id)

		local cap_percent = math.floor((island.capture_timer/g_savedata.settings.CAPTURE_TIME) * 100)

		if island.is_contested then
			server.addMapObject(peer_id, island.map_id, 0, 9, ts_x, ts_z, 0, 0, 0, 0, island.name.." ("..island.faction..")".." CONTESTED", 1, cap_percent.."%", 255, 255, 0, 255)
		elseif island.faction == FACTION_AI then
			if render_debug then
			else
				server.addMapObject(peer_id, island.map_id, 0, 9, ts_x, ts_z, 0, 0, 0, 0, island.name.." ("..island.faction..")", 1, cap_percent.."%", 225, 0, 0, 255)
			end
		elseif island.faction == FACTION_PLAYER then
			server.addMapObject(peer_id, island.map_id, 0, 9, ts_x, ts_z, 0, 0, 0, 0, island.name.." ("..island.faction..")", 1, cap_percent.."%", 0, 225, 0, 255)
		else
			server.addMapObject(peer_id, island.map_id, 0, 9, ts_x, ts_z, 0, 0, 0, 0, island.name.." ("..island.faction..")", 1, cap_percent.."%", 75, 75, 75, 255)
		end
	end
end

function getSquadLeader(squad)
	for vehicle_id, vehicle_object in pairs(squad.vehicles) do
		return vehicle_id, vehicle_object
	end
	if render_debug then server.announce("dlcw", "warning: empty squad ".. squad.ai_type .." detected") end
	return nil
end

function getNearbySquad(transform, override_command)

	local closest_free_squad = nil
	local closest_free_squad_index = -1
	local closest_dist = 999999999

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad.command == COMMAND_NONE
		or squad.command == COMMAND_PATROL
		or override_command then

			local _, squad_leader = getSquadLeader(squad)
			local squad_vehicle_transform = squad_leader.transform
			local distance = matrix.distance(transform, squad_vehicle_transform)

			if distance < closest_dist then
				closest_free_squad = squad
				closest_free_squad_index = squad_index
				closest_dist = distance
			end
		end
	end

	return closest_free_squad, closest_free_squad_index
end

function tickAI()
	if is_dlc_weapons then

		-- allocate squads to islands
		for island_index, island in pairs(g_savedata.controllable_islands) do
			if isTickID(island_index, 60) then
				if island.faction == FACTION_AI then
					if island.assigned_squad_index == -1 then
						local squad, squad_index = getNearbySquad(island.transform)

						if squad ~= nil then
							setSquadCommandDefend(squad, island)
							island.assigned_squad_index = squad_index
						end
					end
				end
			end
		end

		-- allocate squads to engage or investigate based on vision
		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if isTickID(squad_index, 60) then			
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					local squad_vision = squadGetVisionData(squad)

					if squad.command ~= COMMAND_ENGAGE and squad_vision:is_engage() then
						setSquadCommandEngage(squad)
					elseif squad.command ~= COMMAND_INVESTIGATE and squad_vision:is_investigate() then
						if #squad_vision.investigate_players > 0 then
							local investigate_player = squad_vision:getBestInvestigatePlayer()
							setSquadCommandInvestigate(squad, investigate_player.obj.last_known_pos)
						elseif #squad_vision.investigate_vehicles > 0 then
							local investigate_vehicle = squad_vision:getBestInvestigateVehicle()
							setSquadCommandInvestigate(squad, investigate_vehicle.obj.last_known_pos)
						end
					end
				end
			end
		end

		if isTickID(0, 60) then
			g_count_squads = 0
			g_count_attack = 0
			g_count_patrol = 0

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					if squad.command ~= COMMAND_DEFEND and squad.ai_type ~= AI_TYPE_TURRET then
						g_count_squads = g_count_squads + 1
					end
		
					if squad.command == COMMAND_STAGE or squad.command == COMMAND_ATTACK then
						g_count_attack = g_count_attack + 1
					elseif squad.command == COMMAND_PATROL then
						g_count_patrol = g_count_patrol + 1
					end
				end
			end

			local objective_island, ally_island = getObjectiveIsland()

			if objective_island == nil then
				g_savedata.is_attack = false
			else
				if g_savedata.is_attack == false then
					local boats_ready = 0
					local boats_total = 0
					local air_ready = 0
					local air_total = 0
					local land_ready = 0
					local land_total = 0

					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						if squad.command == COMMAND_STAGE then
							local _, squad_leader = getSquadLeader(squad)
							local squad_leader_transform = squad_leader.transform

							if squad.ai_type == AI_TYPE_BOAT then
								boats_total = boats_total + 1

								local air_dist = matrix.distance(objective_island.transform, ally_island.transform)
								local dist = matrix.distance(squad_leader_transform, objective_island.transform)
								local air_sea_speed_factor = AI_SPEED_PSEUDO_BOAT/AI_SPEED_PSEUDO_PLANE

								if dist < air_dist * air_sea_speed_factor then
									boats_ready = boats_ready + 1
								end
							elseif squad.ai_type == AI_TYPE_LAND then
								land_total = land_total + 1

								local air_dist = matrix.distance(objective_island.transform, ally_island.transform)
								local dist = matrix.distance(squad_leader_transform, objective_island.transform)
								local air_sea_speed_factor = AI_SPEED_PSEUDO_LAND/AI_SPEED_PSEUDO_PLANE

								if dist < air_dist * air_sea_speed_factor then
									land_ready = land_ready + 1
								end
							else
								air_total = air_total + 1

								local dist = matrix.distance(squad_leader_transform, ally_island.transform)
								if dist < 2000 then
									air_ready = air_ready + 1
								end
							end
						end
					end
		
					g_is_air_ready = air_total == 0 or air_ready / air_total >= 0.5
					g_is_boats_ready = boats_total == 0 or boats_ready / boats_total >= 0.25
		
					local is_attack = (g_count_attack / g_count_squads) >= 0.25 and g_count_attack >= MIN_ATTACKING_SQUADS and g_is_boats_ready and g_is_air_ready
		
					if is_attack then
						g_savedata.is_attack = is_attack
		
						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == COMMAND_STAGE then
								setSquadCommandAttack(squad, objective_island)
							end
						end
					else
						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == COMMAND_NONE and (air_total + boats_total) < MAX_ATTACKING_SQUADS then
								if squad.ai_type == AI_TYPE_BOAT then -- send boats ahead since they are slow
									setSquadCommandStage(squad, objective_island)
								else
									setSquadCommandStage(squad, ally_island)
								end
							end
						end
					end
				else
					local is_disengage = (g_count_attack / g_count_squads) < 0.25
		
					if is_disengage then
						g_savedata.is_attack = false
		
						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == COMMAND_ATTACK then
								setSquadCommandStage(squad, ally_island)
							end
						end
					end
				end
			end

			-- assign squads to patrol
			local allied_islands = getAlliedIslands()

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.command == COMMAND_NONE then
					if #allied_islands > 0 then
						if (g_count_patrol / g_count_squads) < 0.5 then
							g_count_patrol = g_count_patrol + 1
							setSquadCommandPatrol(squad, allied_islands[math.random(1, #allied_islands)])
						end
					else
						setSquadCommandPatrol(squad, g_savedata.ai_base_island)
					end
				end
			end
		end
	end
end

function getAlliedIslands()
	local alliedIslandIndexes = {}
	for island_index, island in pairs(g_savedata.controllable_islands) do
		if island.faction == FACTION_AI then
			table.insert(alliedIslandIndexes, island)
		end
	end
	return alliedIslandIndexes
end

function getObjectiveIsland()
	local closest = nil
	local closest_ally = nil
	local closest_dist = 999999999
	local closest_ally_dist = 999999999

	for island_index, island in pairs(g_savedata.controllable_islands) do
		if island.faction ~= FACTION_AI then
			local distance = matrix.distance(g_savedata.ai_base_island.transform, island.transform)

			if distance < closest_dist then
				closest = island
				closest_dist = distance
			end
		end
	end

	if closest ~= nil then
		for island_index, island in pairs(g_savedata.controllable_islands) do
			if island.faction == FACTION_AI then
				local distance = matrix.distance(closest.transform, island.transform)

				if distance < closest_ally_dist then
					closest_ally = island
					closest_ally_dist = distance
				end
			end
		end
	end

	if closest_ally == nil then
		closest_ally = g_savedata.ai_base_island
	end

	return closest, closest_ally
end

function getResupplyIsland(ai_vehicle_transform)
	local closest = g_savedata.ai_base_island
	local closest_dist = matrix.distance(ai_vehicle_transform, g_savedata.ai_base_island.transform)

	for island_index, island in pairs(g_savedata.controllable_islands) do
		if island.faction == FACTION_AI then
			local distance = matrix.distance(ai_vehicle_transform, island.transform)

			if distance < closest_dist then
				closest = island
				closest_dist = distance
			end
		end
	end

	return closest
end

function addToSquadron(vehicle_object)
	local new_squad = nil

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad_index ~= RESUPPLY_SQUAD_INDEX then -- do not automatically add to resupply squadron
			if squad.ai_type == vehicle_object.ai_type then
				local _, squad_leader = getSquadLeader(squad)
				if squad.ai_type ~= AI_TYPE_TURRET or vehicle_object.home_island == squad_leader.home_island then
					if tableLength(squad.vehicles) < MAX_SQUAD_SIZE then
						squad.vehicles[vehicle_object.id] = vehicle_object
						new_squad = squad
						break
					end
				end
			end
		end
	end

	if new_squad == nil then
		new_squad = { 
			command = COMMAND_NONE, 
			ai_type = vehicle_object.ai_type, 
			vehicles = {}, 
			target_island = nil,
			target_players = {},
			target_vehicles = {},
			investigate_transform = nil,
		}

		new_squad.vehicles[vehicle_object.id] = vehicle_object
		table.insert(g_savedata.ai_army.squadrons, new_squad)
	end

	squadInitVehicleCommand(new_squad, vehicle_object)
	return new_squad
end

function killVehicle(squad_index, vehicle_id, instant, delete)

	local vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id]

	if vehicle_object.is_killed ~= true or instant then
		if render_debug then server.announce("dlcw", vehicle_id .. " from squad " .. squad_index .. " is out of action") end
		vehicle_object.is_killed = true
		vehicle_object.death_timer = 0

		--[[if instant then
			local explosion_size = 1.5
			if vehicle_object.size == "small" then
				explosion_size = 0.2
			elseif vehicle_object.size == "medium" then
				explosion_size = 0.6
			end

			if render_debug then server.announce("dlcw", "explosion spawned") end
			server.spawnExplosion(vehicle_object.transform, explosion_size)]]--
		if not instant and delete ~= true then
			local fire_id = vehicle_object.fire_id
			if fire_id ~= nil then
				if render_debug then server.announce("dlcw", "explosion fire enabled") end
				server.setFireData(fire_id, true, true)
			end
		end

		server.despawnVehicle(vehicle_id, instant)

		for _, survivor in pairs(vehicle_object.survivors) do
			server.despawnObject(survivor.id, instant)
		end

		if vehicle_object.fire_id ~= nil then
			server.despawnObject(vehicle_object.fire_id, instant)
		end

		if instant == true and delete ~= true then
			local explosion_size = 2
			if vehicle_object.size == "small" then
				explosion_size = 0.5
			elseif vehicle_object.size == "medium" then
				explosion_size = 1
			end

			if render_debug then server.announce("dlcw", "explosion spawned") end

			server.spawnExplosion(vehicle_object.transform, explosion_size)
		end
	end
end

function tickSquadrons()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, 60) then
			-- clean out-of-action vehicles
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do

				if vehicle_object.is_killed and vehicle_object.death_timer ~= nil then
					vehicle_object.death_timer = vehicle_object.death_timer + 1
					if vehicle_object.death_timer >= 300 then
						killVehicle(squad_index, vehicle_id, true)
					end
				end

				-- if pilot is incapacitated
				local c = server.getCharacterData(vehicle_object.survivors[1].id)
				if c ~= nil then
					if c.incapacitated or c.dead then
						killVehicle(squad_index, vehicle_id, false)
					end
				end
			end

			-- check if a vehicle needs resupply, removing from current squad and adding to the resupply squad
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if isVehicleNeedsResupply(vehicle_id) then
						if vehicle_object.ai_type == AI_TYPE_TURRET then
							reload(vehicle_id)
						else
							g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].vehicles[vehicle_id] = g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id]
							g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id] = nil

							if render_debug then server.announce("dlcw", vehicle_id .. " leaving squad " .. squad_index .. " to resupply") end

							if tableLength(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
								g_savedata.ai_army.squadrons[squad_index] = nil
	
								for island_index, island in pairs(g_savedata.controllable_islands) do
									if island.assigned_squad_index == squad_index then
										island.assigned_squad_index = -1
									end
								end
							end

							squadInitVehicleCommand(squad, vehicle_object)
						end
					end
					-- check if the vehicle simply needs to reload a machine gun
					local mg_info = isVehicleNeedsReloadMG(vehicle_id)
					if mg_info[1] and mg_info[2] ~= 0 then
						local i = 1
						local successed = false
						local ammoData = {}
						repeat
							local ammo, success = server.getVehicleWeapon(vehicle_id, "Ammo "..mg_info[2].." - "..i)
							if success then
								if ammo.ammo > 0 then
									successed = success
									ammoData[i] = ammo
								end
							end
							i = i + 1
						until (not success)
						if successed then
							server.setVehicleWeapon(vehicle_id, "Ammo "..mg_info[2].." - "..#ammoData, 0)
							server.setVehicleWeapon(vehicle_id, "Ammo "..mg_info[2], ammoData[#ammoData].capacity)
						end
					end
				end
			else
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if (vehicle_object.state.is_simulating and isVehicleNeedsResupply(vehicle_id) == false) or (vehicle_object.state.is_simulating == false and vehicle_object.is_resupply_on_load) then
	
						-- add to new squad
						g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].vehicles[vehicle_id] = nil
						addToSquadron(vehicle_object)

						if render_debug then server.announce("dlcw", vehicle_id .. " resupplied. joining squad") end
					end
				end
			end

			-- tick behaivour / exit conditions
			if squad.command == COMMAND_PATROL then
				local squad_leader_id, squad_leader = getSquadLeader(squad)
				if squad_leader ~= nil then
					if squad_leader.state.s ~= VEHICLE_STATE_PATHING then -- has finished patrol
						setSquadCommand(squad, COMMAND_NONE)
					end
				else
					if render_debug then server.announce("dlcw", "patrol squad missing leader") end
					setSquadCommand(squad, COMMAND_NONE)
				end
			elseif squad.command == COMMAND_STAGE then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.ai_type == AI_TYPE_BOAT and vehicle_object.state.s == VEHICLE_STATE_HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == COMMAND_ATTACK then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.ai_type == AI_TYPE_BOAT and vehicle_object.state.s == VEHICLE_STATE_HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == COMMAND_DEFEND then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.ai_type == AI_TYPE_BOAT and vehicle_object.state.s == VEHICLE_STATE_HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end

				if squad.target_island == nil then
					setSquadCommand(squad, COMMAND_NONE)
				elseif squad.target_island.faction ~= FACTION_AI then
					setSquadCommand(squad, COMMAND_NONE)
				end
			elseif squad.command == COMMAND_RESUPPLY then

				g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].target_island = nil
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if #vehicle_object.path == 0 then
						if render_debug then server.announce("dlcw", "resupply mission recalculating target island for: "..vehicle_id) end
						local ally_island = getResupplyIsland(vehicle_object.transform)
						resetPath(vehicle_object)
						addPath(vehicle_object, matrix.multiply(ally_island.transform, matrix.translation(math.random(-250, 250), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-250, 250))))
					end
					
					if matrix.distance(g_savedata.ai_base_island.transform, vehicle_object.transform) < CAPTURE_RADIUS then

						if vehicle_object.state.is_simulating then
							-- resupply ammo
							reload(vehicle_id)
						else
							server.resetVehicleState(vehicle_id)
							vehicle_object.is_resupply_on_load = true
						end
					end

					for island_index, island in pairs(g_savedata.controllable_islands) do
						if island.faction == FACTION_AI then
							if matrix.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS then

								if vehicle_object.state.is_simulating then
									-- resupply ammo
									reload(vehicle_id)
								else
									server.resetVehicleState(vehicle_id)
									vehicle_object.is_resupply_on_load = true
								end
							end
						end
					end
				end

			elseif squad.command == COMMAND_INVESTIGATE then
				-- head to search area

				if squad.investigate_transform then
					local is_all_vehicles_at_search_area = true

					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.state.s ~= VEHICLE_STATE_HOLDING then
							is_all_vehicles_at_search_area = false
						end
					end

					if is_all_vehicles_at_search_area then
						squad.investigate_transform = nil
					end
				else
					setSquadCommand(squad, COMMAND_NONE)
				end
			elseif squad.command == COMMAND_ENGAGE then
				local squad_vision = squadGetVisionData(squad)
				local player_counts = {}
				local vehicle_counts = {}
				local function incrementCount(t, index) t[index] = t[index] and t[index] + 1 or 1 end
				local function decrementCount(t, index) t[index] = t[index] and t[index] - 1 or 0 end
				local function getCount(t, index) return t[index] or 0 end

				local function retargetVehicle(vehicle_object, target_player_id, target_vehicle_id)
					-- decrement previous target count
					if vehicle_object.target_player_id ~= -1 then decrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id ~= -1 then decrementCount(vehicle_counts, vehicle_object.target_vehicle_id) end

					vehicle_object.target_player_id = target_player_id
					vehicle_object.target_vehicle_id = target_vehicle_id

					-- increment new target count
					if vehicle_object.target_player_id ~= -1 then incrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id ~= -1 then incrementCount(vehicle_counts, vehicle_object.target_vehicle_id) end
				end

				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- check existing target is still visible

					if vehicle_object.target_player_id ~= -1 and squad_vision:isPlayerVisible(vehicle_object.target_player_id) == false then
						vehicle_object.target_player_id = -1
					elseif vehicle_object.target_vehicle_id ~= -1 and squad_vision:isVehicleVisible(vehicle_object.target_vehicle_id) == false then
						vehicle_object.target_vehicle_id = -1
					end

					-- find targets if not targeting anything

					if vehicle_object.target_player_id == -1 and vehicle_object.target_vehicle_id == -1 then
						if #squad_vision.visible_players > 0 then
							vehicle_object.target_player_id = squad_vision:getBestTargetPlayerID()
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif #squad_vision.visible_vehicles > 0 then
							vehicle_object.target_vehicle_id = squad_vision:getBestTargetVehicleID()
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					else
						if vehicle_object.target_player_id ~= -1 then
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif vehicle_object.target_vehicle_id ~= -1 then
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					end
				end

				local squad_vehicle_count = #squad.vehicles
				local visible_target_count = #squad_vision.visible_players + #squad_vision.visible_vehicles
				local vehicles_per_target = math.max(math.floor(squad_vehicle_count / visible_target_count), 1)

				local function isRetarget(target_player_id, target_vehicle_id)
					return (target_player_id == -1 and target_vehicle_id == -1) 
						or (target_player_id ~= -1 and getCount(player_counts, target_player_id) > vehicles_per_target)
						or (target_vehicle_id ~= -1 and getCount(vehicle_counts, target_vehicle_id) > vehicles_per_target)
				end

				-- find vehicles to retarget to visible players

				for visible_player_id, visible_player in pairs(squad_vision.visible_players_map) do
					if getCount(player_counts, visible_player_id) < vehicles_per_target then
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isRetarget(vehicle_object.target_player_id, vehicle_object.target_vehicle_id) then
								retargetVehicle(vehicle_object, visible_player_id, -1)
								break
							end
						end
					end
				end

				-- find vehicles to retarget to visible vehicles

				for visible_vehicle_id, visible_vehicle in pairs(squad_vision.visible_vehicles_map) do
					if getCount(vehicle_counts, visible_vehicle_id) < vehicles_per_target then
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isRetarget(vehicle_object.target_player_id, vehicle_object.target_vehicle_id) then
								retargetVehicle(vehicle_object, -1, visible_vehicle_id)
								break
							end
						end
					end
				end

				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- update waypoint and target data

					if vehicle_object.target_player_id ~= -1 then
						local target_player_id = vehicle_object.target_player_id
						local target_player_data = squad_vision.visible_players_map[target_player_id]
						local target_player = target_player_data.obj
						local target_x, target_y, target_z = matrix.position(target_player.last_known_pos)
						local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_object.transform)

						if #vehicle_object.path <= 1 then
							resetPath(vehicle_object)
							if matrix.distance(target_player.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) > 700 then
								addPath(vehicle_object, matrix.multiply(target_player.last_known_pos, matrix.translation(target_player.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 25, 50), target_player.last_known_pos)))
								vehicle_object.is_strafing = true
							elseif matrix.distance(target_player.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) > 150 and vehicle_object.is_strafing ~= true then
								addPath(vehicle_object, matrix.multiply(target_player.last_known_pos, matrix.translation(target_player.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 75, 100), target_player.last_known_pos)))
							elseif matrix.distance(target_player.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) < 250 then
								addPath(vehicle_object, matrix.multiply(target_player.last_known_pos, matrix.translation(target_player.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 15, 25), target_player.last_known_pos)))
								vehicle_object.is_strafing = false
							else
								addPath(vehicle_object, matrix.multiply(target_player.last_known_pos, matrix.translation(target_player.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 25, 50), target_player.last_known_pos))) 
							end
						end

						for i, char in pairs(vehicle_object.survivors) do
							server.setAITargetCharacter(char.id, vehicle_object.target_player_id)

							if i ~= 1 or vehicle_object.ai_type == AI_TYPE_TURRET then
								server.setAIState(char.id, 1)
							end
						end
					elseif vehicle_object.target_vehicle_id ~= -1 then
						local target_vehicle = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj
						local target_x, target_y, target_z = matrix.position(target_vehicle.last_known_pos)
						local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_object.transform)

						
						if #vehicle_object.path <= 1 then
							resetPath(vehicle_object)
							if vehicle_object.type == AI_TYPE_PLANE then
								if matrix.distance(target_vehicle.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) > 700 then
									addPath(vehicle_object, matrix.multiply(target_vehicle.last_known_pos, matrix.translation(target_vehicle.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 25, 50), target_vehicle.last_known_pos)))
									vehicle_object.is_strafing = true
								elseif matrix.distance(target_vehicle.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) > 150 and vehicle_object.is_strafing ~= true then
									addPath(vehicle_object, matrix.multiply(target_vehicle.last_known_pos, matrix.translation(target_vehicle.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 75, 100), target_vehicle.last_known_pos)))
								elseif matrix.distance(target_vehicle.last_known_pos, vehicle_object.transform) - math.abs(target_y - vehicle_y) < 250 then
									addPath(vehicle_object, matrix.multiply(target_vehicle.last_known_pos, matrix.translation(target_vehicle.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 15, 25), target_vehicle.last_known_pos)))
									vehicle_object.is_strafing = false
								else
									addPath(vehicle_object, matrix.multiply(target_vehicle.last_known_pos, matrix.translation(target_vehicle.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 25, 50), target_vehicle.last_known_pos)))
								end
							else
								addPath(vehicle_object, matrix.multiply(target_vehicle.last_known_pos, matrix.translation(target_vehicle.last_known_pos, target_y + math.max(target_y + (vehicle_object.id % 5) + 25, 50), target_vehicle.last_known_pos)))
							end
						end
						for i, char in pairs(vehicle_object.survivors) do
							server.setAITargetVehicle(char.id, vehicle_object.target_vehicle_id)

							if i ~= 1 or vehicle_object.ai_type == AI_TYPE_TURRET then
								server.setAIState(char.id, 1)
							end
						end
					end
				end

				if squad_vision:is_engage() == false then
					setSquadCommand(squad, COMMAND_NONE)
				end
			end
		end
	end
end

function tickVisionRadius()

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 240) then
				local vehicle_transform = vehicle_object.transform
				local weather = server.getWeather(vehicle_transform)
				local clock = server.getTime()
				if vehicle_object.vision.is_radar then
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.2)) * (0.6 + (clock.daylight_factor * 0.2)) * (1 - (weather.rain * 0.2))
				else
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.6)) * (0.2 + (clock.daylight_factor * 0.6)) * (1 - (weather.rain * 0.6))
				end
			end
		end
	end
end

function tickVision()

	-- analyse player vehicles
	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id * 4, 240) then
			local player_vehicle_transform = player_vehicle.transform

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					-- reset target visibility state to investigate

					if squad.target_vehicles[player_vehicle_id] ~= nil then
						if player_vehicle.death_pos == nil then
							squad.target_vehicles[player_vehicle_id].state = TARGET_VISIBILITY_INVESTIGATE
						else
							squad.target_vehicles[player_vehicle_id] = nil
						end
					end

					-- check if target is visible to any vehicles
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						local vehicle_transform = vehicle_object.transform

						if vehicle_transform ~= nil and player_vehicle_transform ~= nil then
							local distance = matrix.distance(player_vehicle_transform, vehicle_transform)

							local local_vision_radius = vehicle_object.vision.radius

							-- radar and sonar adjustments
							if player_vehicle_transform[14] >= -1 and vehicle_object.vision.is_radar then
								local_vision_radius = local_vision_radius * 3
							end

							if player_vehicle_transform[14] < -1 and vehicle_object.vision.is_sonar == false then
								local_vision_radius = local_vision_radius * 0.4
							end
							
							if distance < local_vision_radius and player_vehicle.death_pos == nil then
								if squad.target_vehicles[player_vehicle_id] == nil then
									squad.target_vehicles[player_vehicle_id] = {
										state = TARGET_VISIBILITY_VISIBLE,
										last_known_pos = player_vehicle_transform,
									}
								else
									local target_vehicle = squad.target_vehicles[player_vehicle_id]
									target_vehicle.state = TARGET_VISIBILITY_VISIBLE
									target_vehicle.last_known_pos = player_vehicle_transform
								end

								break
							end
						end
					end
				end
			end

			if player_vehicle.death_pos ~= nil then
				if matrix.distance(player_vehicle.death_pos, player_vehicle_transform) > 500 then
					local player_vehicle_data = server.getVehicleData(player_vehicle_id)
					player_vehicle.death_pos = nil
					player_vehicle.damage_threshold = player_vehicle.damage_threshold + player_vehicle_data.voxels / 10
				end
			end

			if render_debug then
				local debug_data = ""

				debug_data = debug_data .. "\ndamage: " .. player_vehicle.current_damage
				debug_data = debug_data .. "\nthreshold: " .. player_vehicle.damage_threshold

				if recent_spotter ~= nil then debug_data = debug_data .. "\nspotter: " .. player_vehicle.recent_spotter end
				if last_known_pos ~= nil then debug_data = debug_data .. "last_known_pos: " end
				if death_pos ~= nil then debug_data = debug_data .. "death_pos: " end

				server.removeMapObject(0, player_vehicle.map_id)
				server.addMapObject(0, player_vehicle.map_id, 1, 4, 0, 150, 0, 150, player_vehicle_id, 0, "Tracked Vehicle: " .. player_vehicle_id, 1, debug_data, 0, 0, 255, 255)
			end
		end
	end

	-- analyse players
	local playerList = server.getPlayers()
	for player_id, player in pairs(playerList) do
		if isTickID(player_id * 4, 240) then
			if player.object_id then
				local player_transform = server.getPlayerPos(player.id)
				
				for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						-- reset target visibility state to investigate

						if squad.target_players[player.object_id] ~= nil then
							squad.target_players[player.object_id].state = TARGET_VISIBILITY_INVESTIGATE
						end

						-- check if target is visible to any vehicles

						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							local vehicle_transform = vehicle_object.transform
							local distance = matrix.distance(player_transform, vehicle_transform)

							if distance < VISIBLE_DISTANCE then
								if squad.target_players[player.object_id] == nil then
									squad.target_players[player.object_id] = {
										state = TARGET_VISIBILITY_VISIBLE,
										last_known_pos = player_transform,
									}
								else
									local target_player = squad.target_players[player.object_id]
									target_player.state = TARGET_VISIBILITY_VISIBLE
									target_player.last_known_pos = player_transform
								end
								
								break
							end
						end
					end
				end
			end
		end
	end
end

function tickVehicles()
	local vehicle_update_tickrate = 30

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, vehicle_update_tickrate) then

				local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_object.transform)
				if vehicle_y <= BOAT_EXPLOSION_DEPTH and g_savedata.settings.SINKING_MODE and vehicle_object.ai_type == AI_TYPE_BOAT or vehicle_y <= HELI_EXPLOSION_DEPTH and g_savedata.settings.SINKING_MODE and vehicle_object.ai_type == AI_TYPE_HELI or vehicle_y <= PLANE_EXPLOSION_DEPTH and g_savedata.settings.SINKING_MODE and vehicle_object.ai_type == AI_TYPE_PLANE then
					killVehicle(squad_index, vehicle_id, true);
				end
				local ai_target = nil
				if ai_state ~= 2 then ai_state = 1 end
				local ai_speed_pseudo = AI_SPEED_PSEUDO_BOAT * vehicle_update_tickrate / 60

				if(vehicle_object.ai_type ~= AI_TYPE_TURRET) then

					if vehicle_object.state.s == VEHICLE_STATE_PATHING then

						if vehicle_object.ai_type == AI_TYPE_PLANE then
							ai_speed_pseudo = AI_SPEED_PSEUDO_PLANE * vehicle_update_tickrate / 60
						elseif vehicle_object.ai_type == AI_TYPE_HELI then
							ai_speed_pseudo = AI_SPEED_PSEUDO_HELI * vehicle_update_tickrate / 60
						elseif vehicle_object.ai_type == AI_TYPE_LAND then
							ai_speed_pseudo = AI_SPEED_PSEUDO_LAND * vehicle_update_tickrate / 60
						else
							ai_speed_pseudo = AI_SPEED_PSEUDO_BOAT * vehicle_update_tickrate / 60
						end

						if #vehicle_object.path == 0 then
							vehicle_object.state.s = VEHICLE_STATE_HOLDING
						else
							if ai_state ~= 2 then ai_state = 1 end
							if vehicle_object.ai_type ~= AI_TYPE_LAND then 
								ai_target = matrix.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)
							else
								local veh_x, veh_y, veh_z = matrix.position(vehicle_object.transform)
								ai_target = matrix.translation(vehicle_object.path[1].x, veh_y, vehicle_object.path[1].z)
								setLandTarget(vehicle_id, vehicle_object)
							end
							if vehicle_object.ai_type == AI_TYPE_BOAT then ai_target[14] = 0 end
	
							local vehicle_pos = vehicle_object.transform
							local distance = matrix.distance(ai_target, vehicle_pos)
	
							if distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.ai_type == AI_TYPE_PLANE or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.ai_type == AI_TYPE_HELI or vehicle_object.ai_type == AI_TYPE_LAND and distance < 2 then
								if #vehicle_object.path > 1 then
									server.removeMapID(0, vehicle_object.path[1].ui_id)
									table.remove(vehicle_object.path, 1)
									if vehicle_object.ai_type == AI_TYPE_LAND then
										setLandTarget(vehicle_id, vehicle_object)
									end
								elseif vehicle_object.ai_type ~= AI_TYPE_LAND then
									-- if we have reached last waypoint start holding there
									if render_debug then server.announce("dlcw", "set plane " .. vehicle_id .. " to holding") end
									vehicle_object.state.s = VEHICLE_STATE_HOLDING
								end
							elseif vehicle_object.ai_type == AI_TYPE_BOAT and distance < WAYPOINT_CONSUME_DISTANCE then
								if #vehicle_object.path > 0 then
									server.removeMapID(0, vehicle_object.path[1].ui_id)
									table.remove(vehicle_object.path, 1)
								else
									-- if we have reached last waypoint start holding there
									if render_debug then server.announce("dlcw", "set boat " .. vehicle_id .. " to holding") end
									vehicle_object.state.s = VEHICLE_STATE_HOLDING
								end
							end
						end
						
						if squad.command == COMMAND_ENGAGE and vehicle_object.ai_type == AI_TYPE_PLANE then
							if ai_target then
								local tar_x, tar_y, tar_z matrix.position(ai_target)
								if matrix.distance(ai_target, vehicle_object.transform) < PLANE_STRAFE_LOCK_DISTANCE then
								elseif ai_state ~= 1 then -- if its low enough and if they aren't too close together
									ai_state = 1
								else
								end
							end
						end

						if squad.command == COMMAND_ENGAGE and vehicle_object.ai_type == AI_TYPE_HELI then
							ai_state = 3
						end

						refuel(vehicle_id)
					elseif vehicle_object.state.s == VEHICLE_STATE_HOLDING then

						ai_speed_pseudo = AI_SPEED_PSEUDO_PLANE * vehicle_update_tickrate / 60

						if vehicle_object.ai_type == AI_TYPE_BOAT then
							ai_state = 0
						else
							if #vehicle_object.path == 0 then
								addPath(vehicle_object, vehicle_object.transform)
							end

							ai_state = 1
							ai_target = matrix.translation(vehicle_object.path[1].x + g_holding_pattern[vehicle_object.holding_index].x, vehicle_object.path[1].y, vehicle_object.path[1].z + g_holding_pattern[vehicle_object.holding_index].z)

							local vehicle_pos = vehicle_object.transform
							local distance = matrix.distance(ai_target, vehicle_pos)

							if distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.ai_type ~= AI_TYPE_LAND or distance < 7 and vehicle_object.ai_type == AI_TYPE_LAND then
								vehicle_object.holding_index = 1 + ((vehicle_object.holding_index) % 4);
							end
						end
					end

					--set ai behaviour
					if ai_target ~= nil then
						if vehicle_object.state.is_simulating then
							server.setAITarget(vehicle_object.survivors[1].id, ai_target)
							server.setAIState(vehicle_object.survivors[1].id, ai_state)
						else
							local ts_x, ts_y, ts_z = matrix.position(ai_target)
							local vehicle_pos = vehicle_object.transform
							local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_pos)
							local movement_x = ts_x - vehicle_x
							local movement_y = ts_y - vehicle_y
							local movement_z = ts_z - vehicle_z
							local length_xz = math.sqrt((movement_x * movement_x) + (movement_z * movement_z))

							local function clamp(value, min, max)
								return math.min(max, math.max(min, value))
							end

							local speed_pseudo = ai_speed_pseudo * g_debug_speed_multiplier
							movement_x = clamp(movement_x * speed_pseudo / length_xz, -math.abs(movement_x), math.abs(movement_x))
							movement_y = math.min(speed_pseudo, math.max(movement_y, -speed_pseudo))
							movement_z = clamp(movement_z * speed_pseudo / length_xz, -math.abs(movement_z), math.abs(movement_z))

							local rotation_matrix = matrix.rotationToFaceXZ(movement_x, movement_z)
							local new_pos = matrix.multiply(matrix.translation(vehicle_x + movement_x, vehicle_y + movement_y, vehicle_z + movement_z), rotation_matrix)

							if server.getVehicleLocal(vehicle_id) == false then
								local _, new_transform = server.setVehiclePosSafe(vehicle_id, new_pos)

								for npc_index, npc_object in pairs(vehicle_object.survivors) do
									server.setObjectPos(npc_object.id, new_transform)
								end

								if vehicle_object.fire_id ~= nil then
									server.setObjectPos(vehicle_object.fire_id, new_transform)
								end
							end
						end
					end
				end

				if render_debug then
					local vehicle_pos = vehicle_object.transform
					local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_pos)

					local debug_data = vehicle_object.state.s .. "\n"
					debug_data = debug_data .. "Waypoints: " .. #vehicle_object.path .."\n\n"

					debug_data = debug_data .. "Squad: " .. squad_index .."\n"
					debug_data = debug_data .. "Comm: " .. squad.command .."\n"
					debug_data = debug_data .. "AI State: ".. ai_state .. "\n"
					if squad.target_island then debug_data = debug_data .. "\n" .. "ISLE: " .. squad.target_island.name .. "\n" end

					debug_data = debug_data .. "TP: " .. vehicle_object.target_player_id .."\n"
					debug_data = debug_data .. "TV: " .. vehicle_object.target_vehicle_id .."\n\n"

					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						local squad_vision = squadGetVisionData(squad)
						debug_data = debug_data .. "squad visible players: " .. #squad_vision.visible_players .."\n"
						debug_data = debug_data .. "squad visible vehicles: " .. #squad_vision.visible_vehicles .."\n"
						debug_data = debug_data .. "squad investigate players: " .. #squad_vision.investigate_players .."\n"
						debug_data = debug_data .. "squad investigate vehicles: " .. #squad_vision.investigate_vehicles .."\n\n"
					end

					local hp = g_savedata.settings.ENEMY_HP
					if vehicle_object.size == "large" then
						hp = hp * 4
					elseif vehicle_object.size == "medium" then
						hp = hp * 2
					end
					debug_data = debug_data .. "hp: " .. vehicle_object.current_damage .. " / " .. hp .. "\n"

					debug_data = debug_data .. "Pos: [" .. math.floor(vehicle_x) .. " ".. math.floor(vehicle_y) .. " ".. math.floor(vehicle_z) .. "]\n"
					if ai_target then
						local ts_x, ts_y, ts_z = matrix.position(ai_target)
						debug_data = debug_data .. "Dest: [" .. math.floor(ts_x) .. " ".. math.floor(ts_y) .. " ".. math.floor(ts_z) .. "]\n"

						local dist_to_dest = math.sqrt((ts_x - vehicle_x) ^ 2 + (ts_z - vehicle_z) ^ 2)
						debug_data = debug_data .. "Dist: " .. math.floor(dist_to_dest) .. "m\n"
					end

					if vehicle_object.state.is_simulating then
						debug_data = debug_data .. "\n\nSIMULATING\n"
						debug_data = debug_data .. "needs resupply: " .. tostring(isVehicleNeedsResupply(vehicle_id)) .. "\n"
					else
						debug_data = debug_data .. "\n\nPSEUDO\n"
						debug_data = debug_data .. "resupply on load: " .. tostring(vehicle_object.is_resupply_on_load) .. "\n"
					end

					local state_icons = {
						[COMMAND_ATTACK] = 18,
						[COMMAND_STAGE] = 2,
						[COMMAND_ENGAGE] = 5,
						[COMMAND_DEFEND] = 19,
						[COMMAND_PATROL] = 15,
						[COMMAND_TURRET] = 14,
						[COMMAND_RESUPPLY] = 11,
					}

					server.removeMapObject(0 ,vehicle_object.map_id)
					server.addMapObject(0, vehicle_object.map_id, 1, state_icons[squad.command] or 4, 0, 0, 0, 0, vehicle_id, 0, "AI " .. vehicle_object.ai_type .. " " .. vehicle_id, vehicle_object.vision.radius, debug_data, 0, 0, 255, 255)

					local is_render = tostring(vehicle_id) == g_debug_vehicle_id or g_debug_vehicle_id == tostring(0)

					if(#vehicle_object.path >= 1) then
						server.removeMapLine(0, vehicle_object.map_id)

						if is_render then
							server.addMapLine(0, vehicle_object.map_id, vehicle_pos, matrix.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), 0.5, 0, 0, 255, 255)
						end

						for i = 1, #vehicle_object.path - 1 do
							local waypoint = vehicle_object.path[i]
							local waypoint_next = vehicle_object.path[i + 1]

							local waypoint_pos = matrix.translation(waypoint.x, waypoint.y, waypoint.z)
							local waypoint_pos_next = matrix.translation(waypoint_next.x, waypoint_next.y, waypoint_next.z)

							server.removeMapLine(0, waypoint.ui_id)

							if is_render then
								server.addMapLine(0, waypoint.ui_id, waypoint_pos, waypoint_pos_next, 0.5, 0, 0, 255, 255)
							end
						end
					end
				end
			end
		end
	end
end

function tickUpdateVehicleData()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 30) then
				vehicle_object.transform = server.getVehiclePos(vehicle_id)
			end
		end
	end

	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then
			player_vehicle.transform = server.getVehiclePos(player_vehicle_id)
		end
	end
end

function tickTerrainScanners()
	printTable(g_savedata.terrain_scanner_links, true, false)
	for vehicle_id, terrain_scanner in pairs(g_savedata.terrain_scanner_links) do
		local vehicle_data = server.getVehicleData(vehicle_id)
		local terrain_scanner_data = server.getVehicleData(terrain_scanner)
		
		if hasTag(terrain_scanner_data.tags, "type=dlc_weapons_terrain_scanner") then
			wpDLCDebug("terrain scanner loading!", true, false)
			wpDLCDebug("ter id: "..terrain_scanner, true, false)
			wpDLCDebug("veh id: "..vehicle_id, true, false)
			dial_read_attempts = 0
			repeat
				dial_read_attempts = dial_read_attempts + 1
				terrain_height, success = server.getVehicleDial(terrain_scanner, "MEASURED_DISTANCE")
				if success and terrain_height.value ~= 0 then
					printTable(terrain_height, true, false)
					local new_terrain_height = (1000 - terrain_height.value) + 5
					local vehicle_x, vehicle_y, vehicle_z = matrix.position(vehicle_data.transform)
					local new_vehicle_matrix = matrix.translation(vehicle_x, new_terrain_height, vehicle_z)
					server.setVehiclePos(vehicle_id, new_vehicle_matrix)
					wpDLCDebug("set land vehicle to new y level!", true, false)
					g_savedata.terrain_scanner_links[vehicle_id] = "Just Teleported"
					server.despawnVehicle(terrain_scanner, true)
				else
					if success then
						wpDLCDebug("Unable to get terrain height checker's dial! "..dial_read_attempts.."x (read = 0)", true, true)
					else
						wpDLCDebug("Unable to get terrain height checker's dial! "..dial_read_attempts.."x (not success)", true, true)
					end
					
				end
				if dial_read_attempts >= 2 then return end
			until(success and terrain_height.value ~= 0)
		end
	end
end

function onTick(tick_time)
	g_tick_counter = g_tick_counter + 1

	if is_dlc_weapons then
		tickUpdateVehicleData()
		tickVisionRadius()
		tickVision()
		tickGamemode()
		tickAI()
		tickSquadrons()
		tickVehicles()
		if tableLength(g_savedata.terrain_scanner_links) > 0 then
			tickTerrainScanners()
		end
	end
end

function refuel(vehicle_id)
    server.setVehicleTank(vehicle_id, "Jet 1", 999, 2)
    server.setVehicleTank(vehicle_id, "Jet 2", 999, 2)
    server.setVehicleTank(vehicle_id, "Jet 3", 999, 2)
    server.setVehicleTank(vehicle_id, "Diesel 1", 999, 1)
    server.setVehicleTank(vehicle_id, "Diesel 2", 999, 1)
    server.setVehicleBattery(vehicle_id, "Battery 1", 1)
    server.setVehicleBattery(vehicle_id, "Battery 2", 1)
end

function reload(vehicle_id)
	if render_debug then server.announce("decw", "reloaded: " .. vehicle_id) end
	for i=1, 15 do
		server.setVehicleWeapon(vehicle_id, "Ammo "..i, 999)
	end
end

--[[
        Utility Functions
--]]

function build_locations(playlist_index, location_index)
    local location_data = server.getLocationData(playlist_index, location_index)

    local addon_components =
    {
        vehicles = {},
        survivors = {},
        objects = {},
		zones = {},
		fires = {},
    }

    local is_valid_location = false

    for object_index, object_data in iterObjects(playlist_index, location_index) do

        for tag_index, tag_object in pairs(object_data.tags) do

            if tag_object == "type=dlc_weapons" then
                is_valid_location = true
            end
			if tag_object == "type=dlc_weapons_terrain_scanner" then
				if object_data.type == "vehicle" then
					g_savedata.terrain_scanner_prefab = { playlist_index = playlist_index, location_index = location_index, object_index = object_index}
				end
			end
			if tag_object == "type=dlc_weapons_flag" then
				if object_data.type == "vehicle" then
					flag_prefab = { playlist_index = playlist_index, location_index = location_index, object_index = object_index}
				end
            end
        end

        if object_data.type == "vehicle" then
			table.insert(addon_components.vehicles, object_data)
        elseif object_data.type == "character" then
			table.insert(addon_components.survivors, object_data)
		elseif object_data.type == "fire" then
			table.insert(addon_components.fires, object_data)
        elseif object_data.type == "object" then
            table.insert(addon_components.objects, object_data)
		elseif object_data.type == "zone" then
			table.insert(addon_components.zones, object_data)
        end
    end

    if is_valid_location then
    	table.insert(built_locations, { playlist_index = playlist_index, location_index = location_index, data = location_data, objects = addon_components} )
    end
end

function spawnObjects(spawn_transform, playlist_index, location_index, object_descriptors, out_spawned_objects)
	local spawned_objects = {}

	for _, object in pairs(object_descriptors) do
		-- find parent vehicle id if set

		local parent_vehicle_id = 0
		if object.vehicle_parent_component_id > 0 then
			for spawned_object_id, spawned_object in pairs(out_spawned_objects) do
				if spawned_object.type == "vehicle" and spawned_object.component_id == object.vehicle_parent_component_id then
					parent_vehicle_id = spawned_object.id
				end
			end
		end

		spawnObject(spawn_transform, playlist_index, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end

function spawnObject(spawn_transform, playlist_index, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	local spawned_object_id = spawnObjectType(matrix.multiply(spawn_transform, object.transform), playlist_index, location_index, object, parent_vehicle_id)

	-- add object to spawned object tables

	if spawned_object_id ~= nil and spawned_object_id ~= 0 then

		local l_ai_type = AI_TYPE_HELI
		if hasTag(object.tags, "type=wep_plane") then
			l_ai_type = AI_TYPE_PLANE
		end
		if hasTag(object.tags, "type=wep_boat") then
			l_ai_type = AI_TYPE_BOAT
		end
		if hasTag(object.tags, "type=wep_land") then
			l_ai_type = AI_TYPE_LAND
		end
		if hasTag(object.tags, "type=wep_turret") then
			l_ai_type = AI_TYPE_TURRET
		end
		if hasTag(object.tags, "type=dlc_weapons_flag") then
			l_ai_type = "flag"
		end
		if hasTag(object.tags, "type=dlc_weapons_terrain_scanner") then
			wpDLCDebug("terrain scanner!", true, false)
			l_ai_type = "terrain_scanner"
		end

		local l_size = "small"
		for tag_index, tag_object in pairs(object.tags) do
			if string.find(tag_object, "size=") ~= nil then
				l_size = string.sub(tag_object, 6)
			end
		end

		local object_data = { name = object.display_name, type = object.type, id = spawned_object_id, component_id = object.id, ai_type = l_ai_type, size = l_size }

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
	end

	return nil
end

-- spawn an individual object descriptor from a playlist location
function spawnObjectType(spawn_transform, playlist_index, location_index, object_descriptor, parent_vehicle_id)
	local component = server.spawnAddonComponent(spawn_transform, playlist_index, location_index, object_descriptor.index, parent_vehicle_id)
	return component.id
end

--------------------------------------------------------------------------------
--
-- VEHICLE HELPERS
--
--------------------------------------------------------------------------------

function isVehicleNeedsResupply(vehicle_id)
	local button_data, success = server.getVehicleButton(vehicle_id, "Resupply")
	return success and button_data.on
end

function isVehicleNeedsReloadMG(vehicle_id)
	local needing_reload = false
	local mg_id = 0
	for i=1,6 do
		local needs_reload, is_success_button = server.getVehicleButton(vehicle_id, "RELOAD_MG"..i)
		if needs_reload ~= nil then
			if needs_reload.on and is_success_button then
				needing_reload = true
				mg_id = i
			end
		end
	end
	local returnings = {}
	returnings[1] = needing_reload
	returnings[2] = mg_id
	return returnings
end



--------------------------------------------------------------------------------
--
-- SQUAD HELPERS
--
--------------------------------------------------------------------------------

function resetSquadTarget(squad)
	squad.target_island = nil
end

function setSquadCommandPatrol(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, COMMAND_PATROL)
end

function setSquadCommandStage(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, COMMAND_STAGE)
end

function setSquadCommandAttack(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, COMMAND_ATTACK)
end

function setSquadCommandDefend(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, COMMAND_DEFEND)
end

function setSquadCommandEngage(squad)
	setSquadCommand(squad, COMMAND_ENGAGE)
end

function setSquadCommandInvestigate(squad, investigate_transform)
	squad.investigate_transform = investigate_transform
	setSquadCommand(squad, COMMAND_INVESTIGATE)
end

function setSquadCommand(squad, command)
	if squad.command ~= command then
		squad.command = command
	
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			squadInitVehicleCommand(squad, vehicle_object)
		end

		if squad.command == COMMAND_NONE then
			resetSquadTarget(squad)
		elseif squad.command == COMMAND_INVESTIGATE then
			squad.target_players = {}
			squad.target_vehicles = {}
		end

		return true
	end

	return false
end

function squadInitVehicleCommand(squad, vehicle_object)
	vehicle_object.target_vehicle_id = -1
	vehicle_object.target_player_id = -1

	if squad.command == COMMAND_PATROL then
		resetPath(vehicle_object)

		local patrol_route = g_patrol_route
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(patrol_route[1].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[1].z)))
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(patrol_route[2].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[2].z)))
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(patrol_route[3].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[3].z)))
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(patrol_route[4].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[4].z)))
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(patrol_route[5].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[5].z)))
	elseif squad.command == COMMAND_ATTACK then
		-- go to island, once island is captured the command will be cleared
		resetPath(vehicle_object)
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == COMMAND_STAGE then
		resetPath(vehicle_object)
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == COMMAND_DEFEND then
		-- go to island, remain there indefinitely
		resetPath(vehicle_object)
		addPath(vehicle_object, matrix.multiply(squad.target_island.transform, matrix.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == COMMAND_INVESTIGATE then
		-- go to investigate location
		resetPath(vehicle_object)
		addPath(vehicle_object, matrix.multiply(squad.investigate_transform, matrix.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == COMMAND_ENGAGE then
		resetPath(vehicle_object)
	elseif squad.command == COMMAND_NONE then
	elseif squad.command == COMMAND_TURRET then
		resetPath(vehicle_object)
	elseif squad.command == COMMAND_RESUPPLY then
		resetPath(vehicle_object)
	end
end

function squadGetVisionData(squad)
	local vision_data = {
		visible_players_map = {},
		visible_players = {},
		visible_vehicles_map = {},
		visible_vehicles = {},
		investigate_players = {},
		investigate_vehicles = {},

		isPlayerVisible = function(self, id)
			return self.visible_players_map[id] ~= nil
		end,

		isVehicleVisible = function(self, id)
			return self.visible_vehicles_map[id] ~= nil
		end,

		getBestTargetPlayerID = function(self)
			return self.visible_players[math.random(1, #self.visible_players)].id
		end,

		getBestTargetVehicleID = function(self)
			return self.visible_vehicles[math.random(1, #self.visible_vehicles)].id
		end,

		getBestInvestigatePlayer = function(self)
			return self.investigate_players[math.random(1, #self.investigate_players)]
		end,

		getBestInvestigateVehicle = function(self)
			return self.investigate_vehicles[math.random(1, #self.investigate_vehicles)]
		end,

		is_engage = function(self)
			return #self.visible_players > 0 or #self.visible_vehicles > 0
		end,

		is_investigate = function(self)
			return #self.investigate_players > 0 or #self.investigate_vehicles > 0
		end,
	}

	for object_id, player_object in pairs(squad.target_players) do
		local player_data = { id = object_id, obj = player_object }

		if player_object.state == TARGET_VISIBILITY_VISIBLE then
			vision_data.visible_players_map[object_id] = player_data
			table.insert(vision_data.visible_players, player_data)
		elseif player_object.state == TARGET_VISIBILITY_INVESTIGATE then
			table.insert(vision_data.investigate_players, player_data)
		end
	end

	for vehicle_id, vehicle_object in pairs(squad.target_vehicles) do
		local vehicle_data = { id = vehicle_id, obj = vehicle_object }

		if vehicle_object.state == TARGET_VISIBILITY_VISIBLE then
			vision_data.visible_vehicles_map[vehicle_id] = vehicle_data
			table.insert(vision_data.visible_vehicles, vehicle_data)
		elseif vehicle_object.state == TARGET_VISIBILITY_INVESTIGATE then
			table.insert(vision_data.investigate_vehicles, vehicle_data)
		end
	end

	return vision_data
end


--------------------------------------------------------------------------------
--
-- UTILITIES
--
--------------------------------------------------------------------------------

function isTickID(id, rate)
	return (g_tick_counter + id) % rate == 0
end

-- iterator function for iterating over all playlists, skipping any that return nil data
function iterPlaylists()
	local playlist_count = server.getAddonCount()
	local playlist_index = 0

	return function()
		local playlist_data = nil
		local index = playlist_count

		while playlist_data == nil and playlist_index < playlist_count do
			playlist_data = server.getAddonData(playlist_index)
			index = playlist_index
			playlist_index = playlist_index + 1
		end

		if playlist_data ~= nil then
			return index, playlist_data
		else
			return nil
		end
	end
end

-- iterator function for iterating over all locations in a playlist, skipping any that return nil data
function iterLocations(playlist_index)
	local playlist_data = server.getAddonData(playlist_index)
	local location_count = 0
	if playlist_data ~= nil then location_count = playlist_data.location_count end
	local location_index = 0

	return function()
		local location_data = nil
		local index = location_count

		while location_data == nil and location_index < location_count do
			location_data = server.getLocationData(playlist_index, location_index)
			index = location_index
			location_index = location_index + 1
		end

		if location_data ~= nil then
			return index, location_data
		else
			return nil
		end
	end
end

-- iterator function for iterating over all objects in a location, skipping any that return nil data
function iterObjects(playlist_index, location_index)
	local location_data = server.getLocationData(playlist_index, location_index)
	local object_count = 0
	if location_data ~= nil then object_count = location_data.component_count end
	local object_index = 0

	return function()
		local object_data = nil
		local index = object_count

		while object_data == nil and object_index < object_count do
			object_data = server.getLocationComponentData(playlist_index, location_index, object_index)
			object_data.index = object_index
			index = object_index
			object_index = object_index + 1
		end

		if object_data ~= nil then
			return index, object_data
		else
			return nil
		end
	end
end

function hasTag(tags, tag)
	if type(tags) == "table" then
		for k, v in pairs(tags) do
			if v == tag then
				return true
			end
		end
	else
		wpDLCDebug("hasTag() was expecting a table, but got a "..type(tags).." instead!", true, true)
	end
	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function getTagValue(tags, tag)
	if type(tags) == "table" then
		for k, v in pairs(tags) do
			if string.match(v, tag.."=") then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			end
		end
	else
		wpDLCDebug("getTagValue() was expecting a table, but got a "..type(tags).." instead!", true, true)
	end
	return nil
end

-- prints all in a table
function printTable(T, requiresDebugging, isError, toPlayer)
	for k, v in pairs(T) do
		if type(v) == "table" then
			wpDLCDebug("Table: "..k, requiresDebugging, isError, toPlayer)
			printTable(v, requiresDebugging, isError, toPlayer)
		else
			wpDLCDebug("k: "..k.." v: "..v, requiresDebugging, isError, toPlayer)
		end
	end
end

-- calculates the size of non-contiguous tables and tables that use non-integer keys
function tableLength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end