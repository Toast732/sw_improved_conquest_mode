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

	Registers the commands ported over from the old commands file

]]


-- AI Reset command
Command.registerCommand(
	"reset",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				Squad.setCommand(squad, SQUAD.COMMAND.NONE)
				if squad.command == SQUAD.COMMAND.DEFEND then
					squad.command = SQUAD.COMMAND.NONE
				end
			end
		end
		g_is_air_ready = true
		g_is_boats_ready = false
		g_savedata.is_attack = false
		d.print("reset all squads", false, 0, peer_id)
	end,
	"admin",
	"this resets the ai's commands, this is helpful for testing and debugging mostly",
	"reset's the ai's commands",
	{""}
)

-- Speed command
Command.registerCommand(
	"speed",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("set speed multiplier from "..tostring(g_debug_speed_multiplier).." to "..tostring(arg[1]), false, 0, peer_id)
		g_debug_speed_multiplier = arg[1]
	end,
	"admin",
	"this allows you to change the multiplier of the ai's pseudo speed, with the arg being the amount to times it by",
	"lets you change ai's pseudo speed",
	{"5"},
	"(multiplier)"
)

-- vreset command
Command.registerCommand(
	"vreset",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
        if not arg[1] then
            d.print("Error: No vehicle group id provided!", false, 0, peer_id)
            return
        end
		local group_id = tonumber(arg[1])
        if not group_id then
            d.print("Error: Vehicle group id must be a number!", false, 0, peer_id)
            return
        end
		server.resetVehicleState(group_id)
	end,
	"admin",
	"this lets you reset an ai vehicle's state, such as holding, stationary, ect",
	"lets you reset an ai's state",
	{"655"},
	"(vehicle_id)"
)

-- Target command
Command.registerCommand(
	"target",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do
				for _, object_id in  pairs(vehicle_object.survivors) do
					s.setAITargetVehicle(object_id, arg[1])
				end
			end
		end
	end,
	"admin",
	"this lets you change what the ai is targeting, so they will attack it instead",
	"lets you change the ai's target",
	{"500"},
	"(vehicle_id)"
)

-- Vision reset command
Command.registerCommand(
	"visionreset",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("resetting all squad vision data", false, 0, peer_id)
		for _, squad in pairs(g_savedata.ai_army.squadrons) do
			squad.target_players = {}
			squad.target_vehicles = {}
		end
		d.print("reset all squad vision data", false, 0, peer_id)
	end,
	"admin",
	"resets the all squad vision data, this is helpful for testing and debugging",
	"resets the squad's vision data",
	{""}
)

-- Spawn vehicle command
Command.registerCommand(
	"spawnvehicle",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- if vehicle not specified, spawn random vehicle
		if not arg[1] then
			d.print("Spawning Random Enemy AI Vehicle", false, 0, peer_id)
			v.spawn()
			return
		end

		local valid_types = {
			land = true,
			plane = true,
			heli = true,
			helicopter = true,
			boat = true
		}

		local vehicle_id = sm.getVehicleListID(string.gsub(arg[1], "_", " "))

		if not vehicle_id and arg[1] ~= "scout" and arg[1] ~= "cargo" and not valid_types[string.lower(arg[1])] and not arg[1]:match("--count:") then
			d.print("Was unable to find a vehicle with the name \""..arg[1].."\", use '?impwep vl' to see all valid vehicle names", false, 1, peer_id)
			return
		end

		d.print("Spawning \""..arg[1].."\"", false, 0, peer_id)

		if arg[1] == "cargo" then -- they want to spawn a cargo vehicle
			v.spawn(arg[1])
		elseif arg[1] == "scout" then -- they want to spawn a scout
			local scout_exists = false

			-- check if theres already a scout that exists
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_index, vehicle in pairs(squad.vehicles) do
					if vehicle.role == "scout" then
						scout_exists = true
						break
					end
				end

				if scout_exists then
					break
				end
			end

			if scout_exists then -- if a scout vehicle already exists
				d.print("unable to spawn scout vehicle: theres already a scout vehicle!", false, 1, peer_id)
				return
			end

			-- spawn scout
			v.spawn(arg[1])

		else

			--[[
				look for "--count:" arg, if its there, take the number after :, and remove --count from arguments table
				if there is none, default to 1
			]]

			local spawn_count = 1
			local _, count_end = full_message:find("--count:")
			if count_end then
				local _, value_end = full_message:find("[^%d]", count_end + 1)

				-- this could happen if --count: is specified at the end of the string, so we want to deafult it to the length
				if not value_end then
					value_end = full_message:len() + 1
				end

				local value = full_message:sub(count_end + 1, value_end - 1)
				if not math.tointeger(value) then
					d.print(("count value has to be a number! given value: %s"):format(value), false, 1, peer_id)
					goto onCustomCommand_spawnVehicle_countInvalid
				end

				spawn_count = math.tointeger(value) or 1

				for arg_i = 1, arg.n do
					if arg[arg_i]:match("--count:"..value) then
						table.remove(arg, arg_i)
						arg.n = arg.n - 1
						break
					end
				end
			end

			::onCustomCommand_spawnVehicle_countInvalid::

			for _ = 1, spawn_count do
				local vehicle_data = nil
				local successfully_spawned = false

				if not arg[1] or not valid_types[string.lower(arg[1])] then
					-- they did not specify a type of vehicle to spawn
						successfully_spawned, vehicle_data = v.spawn(vehicle_id, nil, true)
				else
					-- they specified a type of vehicle to spawn
						successfully_spawned, vehicle_data = v.spawn(nil, string.lower(arg[1]), true)
				end
				if successfully_spawned and type(vehicle_data) == "table" then
					-- if the player didn't specify where to spawn it
					if arg[2] == nil then
						goto onCustomCommand_spawnVehicle_spawnNext
					end

					if arg[2] == "near" then -- the player selected to spawn it in a range
						arg[3] = tonumber(arg[3]) or 150
						arg[4] = tonumber(arg[4]) or 1900
						if arg[3] >= 150 then -- makes sure the min range is equal or greater than 150
							if arg[4] >= arg[3] then -- makes sure the max range is greater or equal to the min range
								if vehicle_data.vehicle_type == VEHICLE.TYPE.BOAT then
									local player_pos = s.getPlayerPos(peer_id)
									local new_location, found_new_location = s.getOceanTransform(player_pos, arg[3], arg[4])
									if found_new_location then
										-- teleport vehicle to new position
										v.teleport(vehicle_data.group_id, new_location)
										d.print("Spawned "..vehicle_data.name.." at x:"..new_location[13].." y:"..new_location[14].." z:"..new_location[15], false, 0, peer_id)
									else
										-- delete vehicle as it was unable to find a valid position
										v.kill(vehicle_data, true, true)
										d.print("unable to find a valid area to spawn the ship! Try increasing the radius!", false, 1, peer_id)
									end
								elseif vehicle_data.vehicle_type == VEHICLE.TYPE.LAND then
									--[[
									local possible_islands = {}
									for island_index, island in pairs(g_savedata.islands) do
										if island.faction ~= ISLAND.FACTION.PLAYER then
											if Tags.has(island.tags, "can_spawn=land") then
												for in pairs(island.zones.land)
											for g_savedata.islands[island_index]
											table.insert(possible_islands.)
										end
									end
									--]]
									d.print("Sorry! As of now you are unable to select a spawn zone for land vehicles! this functionality will be added soon!", false, 1, peer_id)
									v.kill(vehicle_data, true, true)
								else
									local player_pos = s.getPlayerPos(peer_id)
									vehicle_data.transform[13] = player_pos[13] + math.random(-math.random(arg[3], arg[4]), math.random(arg[3], arg[4])) -- x
									vehicle_data.transform[14] = vehicle_data.transform[14] * 1.5 -- y
									vehicle_data.transform[15] = player_pos[15] + math.random(-math.random(arg[3], arg[4]), math.random(arg[3], arg[4])) -- z
									v.teleport(vehicle_data.group_id, vehicle_data.transform)
									d.print("Spawned "..vehicle_data.name.." at x:"..vehicle_data.transform[13].." y:"..vehicle_data.transform[14].." z:"..vehicle_data.transform[15], false, 0, peer_id)
								end
							else
								d.print("your maximum range must be greater or equal to the minimum range!", false, 1, peer_id)
								v.kill(vehicle_data, true, true)
							end
						else
							d.print("the minimum range must be at least 150!", false, 1, peer_id)
							v.kill(vehicle_data, true, true)
						end
					else
						if tonumber(arg[2]) and tonumber(arg[2]) >= 0 or tonumber(arg[2]) and tonumber(arg[2]) <= 0 then -- the player selected specific coordinates
							if tonumber(arg[3]) and tonumber(arg[3]) >= 0 or tonumber(arg[3]) and tonumber(arg[3]) <= 0 then
								if vehicle_data.vehicle_type == VEHICLE.TYPE.BOAT then
									local new_pos = m.translation(arg[2], 0, arg[3])
									v.teleport(vehicle_data.group_id, new_pos)
									vehicle_data.transform = new_pos
									d.print("Spawned "..vehicle_data.name.." at x:"..arg[2].." y:0 z:"..arg[3], false, 0, peer_id)
								elseif vehicle_data.vehicle_type == VEHICLE.TYPE.LAND then
									d.print("sorry! but as of now you are unable to specify the coordinates of where to spawn a land vehicle!", false, 1, peer_id)
									v.kill(vehicle_data, true, true)
								else -- air vehicle
									local new_pos = m.translation(arg[2], CRUISE_HEIGHT * 1.5, arg[3])
									v.teleport(vehicle_data.group_id, new_pos)
									vehicle_data.transform = new_pos
									d.print("Spawned "..vehicle_data.name.." at x:"..arg[2].." y:"..(CRUISE_HEIGHT*1.5).." z:"..arg[3], false, 0, peer_id)
								end
							else
								d.print("invalid z coordinate: "..tostring(arg[3]), false, 1, peer_id)
								v.kill(vehicle_data, true, true)
							end
						else
							d.print("invalid x coordinate: "..tostring(arg[2]), false, 1, peer_id)
							v.kill(vehicle_data, true, true)
						end
					end
				else
					if type(vehicle_data) == "string" then
						d.print("Failed to spawn vehicle! Error:\n"..vehicle_data, false, 1, peer_id)
					else
						d.print("Failed to spawn vehicle!\n(no error code recieved)", false, 1, peer_id)
					end
				end
				::onCustomCommand_spawnVehicle_spawnNext::
			end
		end
	end,
	"admin",
	"this lets you spawn in a ai vehicle, if you dont specify one, it will spawn a random ai vehicle, and if you specify \"scout\", it will spawn a scout vehicle if it can spawn. specify x and y to spawn it at a certain location, or \"near\" and then a minimum distance and then a maximum distance",
	"lets you spawn in an ai vehicle",
	{"Eurofighter", "Eurofighter -500 500", "Eurofighter near 1000 5000", "heli"},
	"[vehicle_id|vehicle_type|\"scout\"] [x & y|\"near\" & min_range & max_range] "
)

-- Teleport vehicle command
Command.registerCommand(
	"teleport",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if not math.tointeger(arg[1]) then
			d.print("vehicle_id must be a integer!", false, 1, peer_id)
			return
		end
        
		if not tonumber(arg[2]) then
			d.print("x coordinate must be a number!", false, 1, peer_id)
			return
		end

		if not tonumber(arg[3]) then
			d.print("y coordinate must be a number!", false, 1, peer_id)
			return
		end

		if not tonumber(arg[4]) then
			d.print("z coordinate must be a number!", false, 1, peer_id)
			return
		end

		local new_transform = matrix.translation(tonumber(arg[2]) --[[@as number]], tonumber(arg[3]) --[[@as number]], tonumber(arg[4]) --[[@as number]])

		local is_success = v.teleport(math.tointeger(arg[1]) --[[@as number]], new_transform)

		if is_success then
			d.print(("Teleported vehicle %s to\nx: %0.1f\ny: %0.1f\nz: %0.1f"):format(arg[1], new_transform[13], new_transform[14], new_transform[15]), false, 0, peer_id)
		else
			d.print(("Failed to teleport vehicle %s!"):format(arg[1]), false, 1, peer_id)
		end
	end,
	"admin",
	"lets you teleport an ai vehicle by vehicle id, to the specified x, y and z",
	"lets you teleport an ai vehicle",
	{"50 100 10 -5000"},
	"(vehicle_id) (x) (y) (z)"
)

-- Vehicle list command
Command.registerCommand(
	"vehiclelist",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("Valid Vehicles:", false, 0, peer_id)
		for vehicle_index, vehicle_object in ipairs(g_savedata.vehicle_list) do
            typeValue = Tags.getValue(vehicle_object.vehicle.tags, "vehicle_type", true)
            if typeValue ~= nil then
			    d.print("\nName: \""..string.removePrefix(vehicle_object.location_data.name, true).."\"\nType: "..(string.gsub(typeValue, "wep_", ""):gsub("^%l", string.upper)), false, 0, peer_id)
            end
        end
	end,
	"admin",
	"prints a list of all of the AI vehicles in the addon, also shows their formatted name, which is used in commands",
	"prints a list of all vehicles",
	{""}
)

-- Debug command
Command.registerCommand(
	"debug",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if not arg[1] then
			d.print("You need to specify a type to debug! valid types are: \"all\" | \"chat\" | \"error\" | \"profiler\" | \"map\" | \"graph_node\" | \"driving\"", false, 1, peer_id)
			return
		end

        local executer_player_data = pl.dataByPID(peer_id)
        if not executer_player_data then
            d.print("ERROR: Unable to find your player data!", false, 1, peer_id)
            return
        end

		--* make the debug type arg friendly
		local selected_debug = string.friendly(arg[1])

		-- turn the specified debug type into its integer index
		local selected_debug_id = d.debugIDFromType(selected_debug)

		if not selected_debug_id then
			-- unknown debug type
			d.print(("Unknown debug type: %s valid types are: \"all\" | \"chat\" | \"error\" | \"profiler\" | \"map\" | \"graph_node\" | \"driving\""):format(tostring(arg[1])), false, 1, peer_id)
			return
		end

		-- if they specified a player, then toggle it for that specified player
		if arg[2] then
			local specified_peer_id = math.tointeger(arg[2])
            if not specified_peer_id then
                d.print("specified peer id must be a integer!", false, 1, peer_id)
                return
            end

			local specified_peer_name = pl.dataByPID(specified_peer_id).name

			local debug_output = d.setDebug(selected_debug_id, specified_peer_id)

			-- message to who the player changed it for
			d.print(("%s %s for you."):format(executer_player_data.name, debug_output), false, 0, specified_peer_id)

			-- message to who changed it for them
			d.print(("%s for %s."):format(debug_output, specified_peer_name), false, 0, peer_id)
			-- d.print("unknown peer id: "..specified_peer_id, false, 1, peer_id)
		else -- if they did not specify a player
			d.print(d.setDebug(selected_debug_id, peer_id), false, 0, peer_id)
		end
	end,
	"admin",
	"lets you toggle debug mode, also shows all the AI vehicles on the map with tons of info valid debug types: \"all\", \"chat\", \"profiler\" and \"map\"",
	"enables or disables debug mode",
	{"all", "map"},
	"(debug_type) [peer_id]"
)

-- spawnturret command
Command.registerCommand(
	"spawnturret",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local turrets_spawned = 0
		-- spawn at ai's main base
		local spawned, vehicle_data = v.spawn("turret", "turret", true, g_savedata.ai_base_island)
		if spawned then
			turrets_spawned = turrets_spawned + 1
		else
			d.print("Failed to spawn a turret on island "..g_savedata.ai_base_island.name.."\nError:\n"..vehicle_data, true, 1)
		end
		-- spawn at enemy ai islands
		for island_index, island in pairs(g_savedata.islands) do
			if island.faction == ISLAND.FACTION.AI then
				local spawned, vehicle_data = v.spawn("turret", "turret", true, island)
				if spawned then
					turrets_spawned = turrets_spawned + 1
				else
					d.print("Failed to spawn a turret on island "..island.name.."\nError:\n"..vehicle_data, true, 1)
				end
			end
		end
		d.print("spawned "..turrets_spawned.." turret"..(turrets_spawned ~= 1 and "s" or ""), false, 0, peer_id)
	end,
	"admin",
	"spawns a turret at every enemy AI island",
	"spawns a turret at every enemy AI island",
	{""}
)

-- aimod command
Command.registerCommand(
	"aimod",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if arg[1] then
			sm.debug(peer_id, arg[1], arg[2], arg[3], arg[4])
		else
			d.print("you need to specify which type to debug!", false, 1, peer_id)
		end
	end,
	"admin",
	"lets you see what an ai's role, type, strategy or vehicle's spawning modifier is",
	"lets you get an ai's spawning modifier",
	{"attack heli general 0"},
	"(role) [type] [strategy] [constructable_vehicle_id]"
)

--setmod command
Command.registerCommand(
	"setmod",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
        -- Input validation
		if not arg[1] then
            d.print("You need to specify wether to punish or reward!", false, 1, peer_id)
            return
        end
        if arg[1] ~= "punish" and arg[1] ~= "reward" then
            d.print("Unknown reinforcement type: "..arg[1].." valid reinforcement types: \"punish\" and \"reward\"", false, 1, peer_id)
            return
        end
        if not arg[2] then
            d.print("You need to specify which role to set!", false, 1, peer_id)
            return
        end
        if not (g_savedata.constructable_vehicles[arg[2]] and g_savedata.constructable_vehicles[arg[2]].mod) then
            d.print("Unknown role: "..arg[2], false, 1, peer_id)
            return
        end
        if tonumber(arg[3]) == nil then
            d.print("Incorrect syntax! "..arg[3].." has to be a number from 1-5!", false, 1, peer_id)
            return
        end

        -- Set the mod
        if arg[1] == "punish" then
			if ai_training.punishments[tonumber(arg[3])] then
				g_savedata.constructable_vehicles[arg[2]].mod = g_savedata.constructable_vehicles[arg[2]].mod + ai_training.punishments[tonumber(arg[3])]
				d.print("Successfully set role "..arg[2].." to modifier: "..g_savedata.constructable_vehicles[arg[2]].mod, false, 0, peer_id)
			else
				d.print("Incorrect syntax! "..arg[3].." has to be a number from 1-5!", false, 1, peer_id)
			end
		elseif arg[1] == "reward" then
			if ai_training.rewards[tonumber(arg[3])] then
				g_savedata.constructable_vehicles[arg[2]].mod = g_savedata.constructable_vehicles[arg[2]].mod + ai_training.rewards[tonumber(arg[3])]
				d.print("Successfully set role "..arg[2].." to modifier: "..g_savedata.constructable_vehicles[arg[2]].mod, false, 0, peer_id)
			else
				d.print("Incorrect syntax! "..arg[3].." has to be a number from 1-5!", false, 1, peer_id)
			end
		end
	end,
	"admin",
	"lets you change what the ai's role spawning modifier is, does not yet support type, strategy or constructable vehicle id",
	"lets you change an ai's spawning modifier",
	{"reward attack 4"},
	"(\"reward\"|\"punish\") (role) (modifier: 1-5)"
)

-- Delete vehicle command
Command.registerCommand(
	"deletevehicle",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if not arg[1] then
            d.print("Invalid syntax! You must either choose a vehicle id, or \"all\" to remove all enemy AI vehicles", false, 1, peer_id) 
            return
        end

        if arg[1] == "all" or arg[1] == "damaged" then
            local vehicle_counter = 0
            for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
                for vehicle_id, vehicle_object in pairs(squad.vehicles) do
                    if arg[1] ~= "damaged" or arg[1] == "damaged" and vehicle_object.current_damage > 0 then

                        -- refund the cargo to the island which was sending the cargo
                        Cargo.refund(vehicle_id)

                        v.kill(vehicle_object, true, true)
                        vehicle_counter = vehicle_counter + 1
                    end
                end
            end
            if vehicle_counter == 0 then
                d.print("There are no enemy AI vehicles to remove", false, 0, peer_id)
            elseif vehicle_counter == 1 then
                d.print("Removed "..vehicle_counter.." enemy AI vehicle", false, 0, peer_id)
            elseif vehicle_counter > 1 then
                d.print("Removed "..vehicle_counter.." enemy AI vehicles", false, 0, peer_id)
            end
        else
            local vehicle_id = math.tointeger(arg[1])
            if not vehicle_id then
                d.print("vehicle_id must be a integer!", false, 1, peer_id)
                return
            end
            local vehicle_object, _, _ = Squad.getVehicle(vehicle_id)

            if vehicle_object then

                -- refund the cargo to the island which was sending the cargo
                Cargo.refund(vehicle_id)

                v.kill(vehicle_object, true, true)
                d.print("Sucessfully deleted vehicle "..arg[1].." name: "..vehicle_object.name, false, 0, peer_id)
            else
                d.print("Unable to find vehicle with id "..arg[1]..", double check the ID!", false, 1, peer_id)
            end
        end
	end,
	"admin",
	"lets you delete an ai vehicle by vehicle id, or all by specifying \"all\", or all vehicles that have been damaged by specifying \"damaged\"",
	"lets you delete an ai vehicle",
	{"all"},
	"(vehicle_id|\"all\"|\"damaged\")"
)

-- Scout Island command
Command.registerCommand(
	"scoutintel",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Input validation
        if not arg[1] then
            d.print("Invalid syntax! you must specify the island and the scout level (0-100) to set it to!", false, 1, peer_id)
            return
        end
        if not arg[2] then
            d.print("Invalid syntax! you must specify the scout level to set it to (0-100)", false, 1, peer_id)
            return
        end
        local scout_level = tonumber(arg[2])
        if not scout_level then
            d.print("Arg 2 has to be a number! Unknown value: "..arg[2], false, 1, peer_id)
            return
        end
        local chosen_island = g_savedata.ai_knowledge.scout[string.gsub(arg[1], "_", " ")]
        if not chosen_island then
            d.print("Unknown island: "..string.gsub(arg[1], "_", " "), false, 1, peer_id)
            return
        end

        -- Set the new scout level
        chosen_island.scouted = (math.clamp(scout_level, 0, 100)/100) * scout_requirement

        -- Announce the change to the players
        local name = s.getPlayerName(peer_id)
        s.notify(-1, "(Improved Conquest Mode) Scout Level Changed", name.." set "..arg[2].."'s scout level to "..(g_savedata.ai_knowledge.scout[string.gsub(arg[1], "_", " ")].scouted/scout_requirement*100).."%", 1)
	end,
	"admin",
	"lets you set the ai's scout level on a specific island, from 0 to 100 for 0% scouted to 100% scouted",
	"lets you set the ai's scout level",
	{"North_Harbour 100"},
	"(island_name) (0-100)"
)

-- Setting command
Command.registerCommand(
	"setting",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
        local executer_player_data = pl.dataByPID(peer_id)
        if not executer_player_data then
            d.print("ERROR: Unable to find your player data!", false, 1, peer_id)
            return
        end

		if not arg[1] then
            -- we want to print a list of all settings they can change
            d.print("\nAll Improved Conquest Mode Settings", false, 0, peer_id)
            for setting_name, setting_value in pairs(g_savedata.settings) do
                d.print("-----\nSetting Name: "..setting_name.."\nSetting Type: "..type(setting_value), false, 0, peer_id)
            end
        elseif g_savedata.settings[arg[1]] ~= nil then -- makes sure the setting they selected exists
            if not arg[2] then
                -- print the current value of the setting they selected
                local current_value = g_savedata.settings[arg[1]]

                --? if this has a index in the rules for settings, if this is a number, and if the multiplier is not nil
                if RULES.SETTINGS[arg[1]] and tonumber(current_value) and RULES.SETTINGS[arg[1]].input_multiplier then
                    current_value = math.noNil(current_value / RULES.SETTINGS[arg[1]].input_multiplier)
                end

                d.print(arg[1].."'s current value: "..tostring(current_value), false, 0, peer_id)
            else
                -- change the value of the setting they selected
                if type(g_savedata.settings[arg[1]]) == "number" then
                    if tonumber(arg[2]) then

                        arg[2] = tonumber(arg[2])
                        
                        local input_multiplier = 1

                        if RULES.SETTINGS[arg[1]] then
                            --? if theres an input multiplier
                            if RULES.SETTINGS[arg[1]].input_multiplier then
                                input_multiplier = RULES.SETTINGS[arg[1]].input_multiplier
                                arg[2] = math.noNil(arg[2] * input_multiplier)
                            end
                            
                            --? if theres a set minimum, if this input is below the minimum and if the player did not yet acknowledge this
                            if RULES.SETTINGS[arg[1]].min and arg[2] <= RULES.SETTINGS[arg[1]].min.value and not executer_player_data.acknowledgements[arg[1]] then
                                
                                --* set that they've acknowledged this
                                if not executer_player_data.acknowledgements[arg[1]] then
                                    executer_player_data.acknowledgements[arg[1]] = {
                                        min = true,
                                        max = false
                                    }
                                else
                                    executer_player_data.acknowledgements[arg[1]].min = true
                                end

                                d.print("Warning: setting "..arg[1].." to or below "..RULES.SETTINGS[arg[1]].min.value.." can result in "..RULES.SETTINGS[arg[1]].min.message.." Re-enter the command to acknowledge this and proceed anyways.", false, 1, peer_id)
                                return
                            end

                            --? if theres a set maximum, if this input is above or equal to the maximum and if the player did not yet acknowledge this
                            if RULES.SETTINGS[arg[1]].max and arg[2] >= RULES.SETTINGS[arg[1]].max.value and not executer_player_data.acknowledgements[arg[1]] then
                                
                                --* set that they've acknowledged this
                                if not executer_player_data.acknowledgements[arg[1]] then
                                    executer_player_data.acknowledgements[arg[1]] = {
                                        min = false,
                                        max = true
                                    }
                                else
                                    executer_player_data.acknowledgements[arg[1]].max = true
                                end
                                d.print("Warning: setting a value to or above "..RULES.SETTINGS[arg[1]].max.value.." can result in "..RULES.SETTINGS[arg[1]].max.message.." Re-enter the command to acknowledge this and proceed anyways.", false, 1, peer_id)
                                return
                            end
                        end

                        d.print(s.getPlayerName(peer_id).." has changed the setting "..arg[1].." from "..math.noNil(g_savedata.settings[arg[1]]/input_multiplier).." to "..(arg[2]/input_multiplier), false, 0, -1)

                        ----
                        -- special things to do whenever settings are changed
                        ----


                        if arg[1] == "CAPTURE_TIME" and arg[2] ~= 0 and g_savedata.settings[arg[1]] ~= 0 then
                            -- if this is changing the capture timer, then re-adjust all of the capture timers for each island

                            for island_index, island in pairs(g_savedata.islands) do
                                island.capture_timer = island.capture_timer * (arg[2] / g_savedata.settings[arg[1]])
                            end
                        end

                        g_savedata.settings[arg[1]] = arg[2]
                    else
                        d.print(arg[2].." is not a valid value! it must be a number!", false, 1, peer_id)
                    end
                elseif g_savedata.settings[arg[1]] == true or g_savedata.settings[arg[1]] == false then
                    if arg[2] == "true" then
                        d.print(s.getPlayerName(peer_id).." has changed the setting "..arg[1].." from "..tostring(g_savedata.settings[arg[1]]).." to "..arg[2], false, 0, -1)
                        g_savedata.settings[arg[1]] = true
                    elseif arg[2] == "false" then
                        d.print(s.getPlayerName(peer_id).." has changed the setting "..arg[1].." from "..tostring(g_savedata.settings[arg[1]]).." to "..arg[2], false, 0, -1)
                        g_savedata.settings[arg[1]] = false

                        if arg[1] == "CARGO_MODE" and arg[2] == false then
                            -- if cargo mode was disabled, remove all active convoys
                            
                            for cargo_vehicle_id, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do

                                -- kill cargo vehicle
                                v.kill(cargo_vehicle.vehicle_data, true, true)

                                -- reset the squad's command
                                local squad_index, _ = Squad.getSquadFromGroup(cargo_vehicle.vehicle_data)
                                g_savedata.ai_army.squadrons[squad_index].command = SQUAD.COMMAND.NONE
                            end
                        end
                    else
                        d.print(arg[2].." is not a valid value! it must be either \"true\" or \"false\"!", false, 1, peer_id)
                    end
                else
                    d.print("g_savedata.settings."..arg[1].." is not a number or a boolean! please report this as a bug! Value of g_savedata.settings."..arg[1]..":"..g_savedata.settings[arg[1]], false, 1, peer_id)
                end
            end
        else 
            -- the setting they selected does not exist
            d.print(arg[1].." is not a valid setting! do \"?impwep setting\" to get a list of all settings!", false, 1, peer_id)
        end
	end,
	"admin",
	"if you do not input the setting name, it will show a list of all valid settings, if you input a setting name but not a value, it will tell you the setting's current value, if you enter both the setting name and the setting value, it will change that setting to that value",
	"lets you change or get a specific setting and can get a list of all settings",
	{"MAX_BOAT_AMOUNT 5", "MAX_BOAT_AMOUNT", ""},
	"[setting_name] [value]"
)

-- Ai Knowledge command
Command.registerCommand(
	"aiknowledge",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local vehicles = sm.getStats()

        if vehicles.best[1].mod == vehicles.worst[1].mod then
            d.print("the adaptive AI doesn't know anything about you! all vehicles currently have the same chance to spawn.", false, 0, peer_id)
        else
            d.print("Top 3 vehicles the ai thinks is effective against you:", false, 0, peer_id)
            for _, vehicle_data in ipairs(vehicles.best) do
                d.print(_..": "..vehicle_data.name.." ("..vehicle_data.mod..")", false, 0, peer_id)
            end
            d.print("Bottom 3 vehicles the ai thinks is effective against you:", false, 0, peer_id)
            for _, vehicle_data in ipairs(vehicles.worst) do
                d.print(_..": "..vehicle_data.name.." ("..vehicle_data.mod..")", false, 0, peer_id)
            end
        end
	end,
	"admin",
	"shows the 3 vehicles it thinks is good against you, and the 3 that it thinks is weak against you",
	"shows the 3 vehicles it thinks is good against you",
	{""}
)

-- addoninfo command
-- command for debugging things such as why the addon name is broken
Command.registerCommand(
	"addoninfo",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("---- addon info ----", false, 0, peer_id)

        -- get the addon name
        local addon_name = "Improved Conquest Mode (".. string.match(ADDON_VERSION, "(%d%.%d%.%d)")..(IS_DEVELOPMENT_VERSION and ".dev)" or ")")

        -- addon index
        local true_addon_index, true_is_success = s.getAddonIndex(addon_name)
        local addon_index, is_success = s.getAddonIndex()
        d.print("addon_index: "..tostring(addon_index).." | "..tostring(true_addon_index).."\nsuccessfully found addon_index: "..tostring(is_success).." | "..tostring(true_is_success), false, 0, peer_id)

        -- addon data
        local true_addon_data = s.getAddonData(true_addon_index)
        local addon_data = s.getAddonData(addon_index)
        d.print("file_store: "..tostring(addon_data.file_store).." | "..tostring(true_addon_data.file_store).."\nlocation_count: "..tostring(addon_data.location_count).." | "..tostring(true_addon_data.location_count).."\naddon_name: "..tostring(addon_data.name).." | "..tostring(true_addon_data.name).."\npath_id: "..tostring(addon_data.path_id).." | "..tostring(true_addon_data.path_id), false, 0, peer_id)
	end,
	"admin",
	"",
	"",
	{""}
)

-- Reset Prefabs command
Command.registerCommand(
	"resetprefabs",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		g_savedata.prefabs = {}
		d.print("reset all prefabs", false, 0, peer_id)
	end,
	"admin",
	"",
	"",
	{""}
)

-- Debug migration command
Command.registerCommand(
	"debugmigration",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("is migrated? "..tostring(g_savedata.info.version_history ~= nil), false, 0, peer_id)
	end,
	"admin",
	"",
	"",
	{""}
)

-- Airvehicleskamikaze command
Command.registerCommand(
	"airvehicleskamikaze",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		g_air_vehicles_kamikaze = not g_air_vehicles_kamikaze
		d.print(("g_air_vehicles_kamikaze set to %s"):format(tostring(g_air_vehicles_kamikaze)))
	end,
	"admin",
	"forces all air vehicles to have their target coordinates set to the target's position, when they have a target.",
	"kamikaze.",
	{""}
)

-- Get memory usuage command
Command.registerCommand(
	"getmemusage",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if not collectgarbage then
            d.print("The game does not have collectgarbage() injected, unable to get memory usage.", false, 1, peer_id)
        else
            d.print(("Lua is using %0.0fkb of memory."):format(collectgarbage("count")), false, 0, peer_id)
        end
	end,
	"admin",
	"returns how much memory the lua environment is using, this requires a modified version of sw which has the base lua functions injected.",
	"returns memory usage of this addon",
	{""}
)

-- Cause error command
Command.registerCommand(
	"causeerror",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local function_path = arg[1]
        if not function_path then
            d.print("You need to specify a function path!", false, 1, peer_id)
            return
        end

        local value_at_path, got_path = table.getValueAtPath(function_path)

        if not got_path then
            d.print(("failed to get path. returned value:\n%s"):format(string.fromTable(value_at_path)), false, 1, peer_id)
            return
        end

        if type(value_at_path) ~= "function" then
            d.print(("value at path is not a function! returned type: %s, returned value:\n%s"):format(type(value_at_path), string.fromTable(value_at_path)), false, 1, peer_id)
        end

        d.print(("Warning, %s set function %s to cause an error when its called."):format(s.getPlayerName(peer_id), function_path), false, 0, -1)

        local value_at_path = table.copy.deep(value_at_path)

        local value_was_set = table.setValueAtPath(function_path, function(...)
            return (function(...)
                local x = nil + nil
                return ...
            end)(value_at_path(...))
        end)

        if not value_was_set then
            d.print("Failed to set the function!", false, 1, peer_id)
            return
        end

        d.print(("successfully set the function %s to cause an error when its called."):format(function_path), false, 0, peer_id)
	end,
	"admin",
	"causes an error when the specified function is called. Useful for debugging the traceback debug, or trying to reproduce an error.",
	"causes an error when the specified function is called.",
	{"math.euclideanDistance"},
	"<function_name>"
)

-- print traceback command
Command.registerCommand(
	"printtraceback",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- swap to normal env to avoid a self reference loop
        local __ENV = _ENV_NORMAL
        __ENV._ENV_MODIFIED = _ENV
        _ENV = __ENV

        d.trace.print()

        -- swap back to modified environment
        _ENV = _ENV_MODIFIED
	end,
	"admin",
	"",
	"",
	{""}
)

-- Execute command
Command.registerCommand(
	"execute",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local location_string = arg[1]
        local value = arg[2]

        --local _, index_count = location_string:gsub("%.", ".")

        -- make sure its not a function call
        --if location_string:match("%(") then
            --[[if location_string:match("onCustomCommand") then
                d.print("Hey, I see what you're trying to do there...", false, 1, peer_id)
                goto onCustomCommand_execute_fail
            end]]
            --d.print("sorry, but the execute command does not yet support calling functions.", false, 1, peer_id)
            --goto onCustomCommand_execute_fail
        --end

        --[[local selected_variable = _ENV
        local built_path = ""
        local index_depth = 0
        for index, _ in location_string:gmatch("[%w_]+") do
            if type(selected_variable) == "table" then
                if index_depth == index_count and arg.n == 2 then
                    if value == "true" then
                        value = true
                    elseif value == "false" then
                        value = false
                    elseif arg.n == 2 and not value then
                        value = nil
                    elseif tonumber(value) then
                        value = tonumber(value)
                    else
                        value = value:gsub("\"", "")
                    end
                    selected_variable[index] = value
                    break
                end

                selected_variable = selected_variable[index]
            end

            index_depth = index_depth + 1
        end]]

        local value_at_path, is_success = table.getValueAtPath(location_string)

        if not is_success then
            d.print(("failed to get value at path %s"):format(location_string), false, 1, peer_id)
            goto onCustomCommand_execute_fail
        end


        if arg.n == 2 then

            local is_success = table.setValueAtPath(location_string, value)

            if not is_success then
                d.print(("failed to set the value at path %s to %s"):format(location_string, value), false, 1, peer_id)
                goto onCustomCommand_execute_fail
            end

            d.print(("set %s to %s"):format(location_string, value), false, 0, peer_id)
        else
            d.print(("value of %s: %s"):format(location_string, string.fromTable(value_at_path)), false, 0, peer_id)
        end

        ::onCustomCommand_execute_fail::
	end,
	"admin",
	"allows you to get or set global variables, and call global functions with specified arguments.",
	"allows you to get, set or call global variables.",
	{"g_savedata.debug.traceback.enabled", "g_savedata.debug.traceback.debug true", "sm.train(\"reward\",\"attack\",5)"},
	"(address)[(\"(\"function_args\")\") value]"
)

-- Ignite command
Command.registerCommand(
	"ignite",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local function igniteVehicle(vehicle_id)
            local vehicle_pos, got_pos = server.getVehiclePos(vehicle_id)
            if not got_pos then
                d.print(("%s is not a vehicle!"):format(vehicle_id), false, -1, peer_id)
                return
            end

            local is_loaded = server.getVehicleSimulating(vehicle_id)

            if not is_loaded then
                d.print(("%s is not loaded!"):format(vehicle_id), false, 1, peer_id)
                return
            end

            server.spawnFire(vehicle_pos, tonumber(arg[2]) or 1, 0, true, false, vehicle_id, 0)
        end
        if arg[1] == "all" then
            for _, squad in pairs(g_savedata.ai_army.squadrons) do
                for _, vehicle_object in pairs(squad.vehicles) do
                    if vehicle_object.state.is_simulating then
                        igniteVehicle(vehicle_object.group_id)
                    end
                end
            end
        elseif tonumber(arg[1]) then
            igniteVehicle(tonumber(arg[1]))
        else
            d.print(("Your specified argument %s is not a vehicle id or \"all\", do ?icm help ignite for help on how to use this command!"):format(arg[1]), false, 1, peer_id)
        end
	end,
	"admin",
	"allows you to ignite one or many ai vehicles by spawning a fire on them.",
	"allows you to ignite an ai vehicle",
	{"all", "102 10"},
	"(vehicle_id)|\"all\" [size]"
)

Command.registerCommand(
	"getgroupid",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local vehicle_id = tonumber(arg[1])
		if not vehicle_id then
			d.print("vehicle_id must be a integer!", false, 1, peer_id)
			return
		end
		local group_id = VehicleGroup.getGroupID(vehicle_id)

		d.print("vehicle "..vehicle_id.." has group id: "..group_id, false, 0, peer_id)
	end,
	"admin",
	"Converts a vehicle id to a group id. Used for debugging",
	"vehicle id -> group id for debugging",
	{"53"},
	"<vehicle_id>"
)