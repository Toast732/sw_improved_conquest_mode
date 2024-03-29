-- required libraries
require("libraries.addon.script.debugging")
require("libraries.utils.math")
require("libraries.utils.string")

-- library name
SpawnModifiers = {}

-- shortened library name
sm = SpawnModifiers

--[[


	Constants


]]

-- The smallest value the spawn modifier can be.
MIN_MODIFIER_VALUE = 0.1

-- The largest value the spawn modifier can be.
MAX_MODIFIER_VALUE = 1.5

--[[


	Variables


]]

local default_mods = {
	attack = 0.55,
	general = 1,
	defend = 0.2,
	roaming = 0.1,
	stealth = 0.05
}

function SpawnModifiers.create() -- populates the constructable vehicles with their spawning modifiers
	for role, role_data in pairs(g_savedata.constructable_vehicles) do
		if type(role_data) == "table" and role ~= "varient" then
			for veh_type, veh_data in pairs(g_savedata.constructable_vehicles[role]) do
				if type(veh_data) == "table" then
					for strat, strat_data in pairs(veh_data) do
						if type(strat_data) == "table" then
							g_savedata.constructable_vehicles[role][veh_type][strat].mod = 1
							for vehicle_id, v in pairs(strat_data) do
								if type(v) == "table" then
									g_savedata.constructable_vehicles[role][veh_type][strat][vehicle_id].mod = 1
									d.print("setup "..g_savedata.constructable_vehicles[role][veh_type][strat][vehicle_id].name.." for adaptive AI", true, 0)
								end
							end
						end
					end
					g_savedata.constructable_vehicles[role][veh_type].mod = 1
				end
			end
			g_savedata.constructable_vehicles[role].mod = default_mods[role] or 1
		end
	end
end

---@param is_specified boolean? true to specify what vehicle to spawn, false for random
---@param vehicle_list_id string|integer? vehicle to spawn if is_specified is true, integer to specify exact vehicle, string to specify the role of the vehicle you want
---@param vehicle_type string? the type of vehicle you want to spawn, such as boat, helicopter, plane or land
---@return PREFAB_DATA|nil prefab_data the vehicle's prefab data
function SpawnModifiers.spawn(is_specified, vehicle_list_id, vehicle_type)
	local sel_role = nil
	local sel_veh_type = nil
	local sel_strat = nil
	local sel_vehicle = nil
	if is_specified == true and type(vehicle_list_id) == "number" and g_savedata.constructable_vehicles then
		sel_role = g_savedata.vehicle_list[vehicle_list_id].role
		sel_veh_type = g_savedata.vehicle_list[vehicle_list_id].vehicle_type
		sel_strat = g_savedata.vehicle_list[vehicle_list_id].strategy
		for vehicle_id, _ in pairs(g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat]) do
			if not sel_vehicle and vehicle_id ~= "mod" and vehicle_list_id == g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat][vehicle_id].id then
				sel_vehicle = vehicle_id
			end
		end
		if not sel_vehicle then
			return
		end
	elseif is_specified == false and g_savedata.constructable_vehicles or type(vehicle_list_id) == "string" and g_savedata.constructable_vehicles then
		local role_chances = {}
		local veh_type_chances = {}
		local strat_chances = {}
		local vehicle_chances = {}
		if not vehicle_list_id then
			for role, v in pairs(g_savedata.constructable_vehicles) do
				if type(v) == "table" then
					if role == "attack" or role == "general" or role == "defend" or role == "roaming" then
						role_chances[role] = g_savedata.constructable_vehicles[role].mod
					end
				end
			end
			sel_role = math.randChance(role_chances)
		else
			sel_role = vehicle_list_id
		end
		--d.print("selected role: "..tostring(sel_role), true, 0)
		if not vehicle_type then
			if g_savedata.constructable_vehicles[sel_role] then
				for veh_type, v in pairs(g_savedata.constructable_vehicles[sel_role]) do
					if type(v) == "table" then
						veh_type_chances[veh_type] = g_savedata.constructable_vehicles[sel_role][veh_type].mod
					end
				end
				sel_veh_type = math.randChance(veh_type_chances)
			else
				d.print("There are no vehicles with the role \""..sel_role.."\"", true, 1)
				return
			end
		else -- then use the vehicle type which was selected
			if g_savedata.constructable_vehicles[sel_role] and g_savedata.constructable_vehicles[sel_role][vehicle_type] then -- makes sure it actually exists
				sel_veh_type = vehicle_type
			else
				d.print("There are no vehicles with the role \""..sel_role.."\" and with the type \""..vehicle_type.."\"", true, 1)
				return
			end
		end
		--d.print("selected vehicle type: "..tostring(sel_veh_type), true, 0)

		for strat, v in pairs(g_savedata.constructable_vehicles[sel_role][sel_veh_type]) do
			if type(v) == "table" then
				strat_chances[strat] = g_savedata.constructable_vehicles[sel_role][sel_veh_type][strat].mod
			end
		end
		sel_strat = math.randChance(strat_chances)
		--d.print("selected strategy: "..tostring(sel_strat), true, 0)
		if g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat] then
			for vehicle, v in pairs(g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat]) do
				if type(v) == "table" then
					vehicle_chances[vehicle] = g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat][vehicle].mod
				end
			end
		else
			d.print("There are no vehicles with the role \""..sel_role.."\", with the type \""..sel_veh_type.."\" and with the strat \""..sel_strat.."\"", true, 1)
			return
		end
		sel_vehicle = math.randChance(vehicle_chances)
		--d.print("selected vehicle: "..tostring(sel_vehicle), true, 0)
	else
		if g_savedata.constructable_vehicles then
			d.print("unknown arguments for choosing which ai vehicle to spawn.", true, 1)
		else
			d.print("g_savedata.constructable_vehicles is nil! This may be directly after a full reload, if so, ignore this error", true, 1)
		end
		return
	end
	return g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat][sel_vehicle]
end

---@param role string the role of the vehicle, such as attack, general or defend
---@param vehicle_type string the vehicle type, such as boat, plane, heli, land or turret
---@param strategy string the strategy of the vehicle, such as strafe, bombing or general
---@param vehicle_list_id integer the index of the vehicle in the vehicle list
---@return integer|nil constructable_vehicle_id the index of the vehicle in the constructable vehicle list, returns nil if not found
function SpawnModifiers.getConstructableVehicleID(role, vehicle_type, strategy, vehicle_list_id)
	local constructable_vehicle_id = nil
	if g_savedata.constructable_vehicles[role] and g_savedata.constructable_vehicles[role][vehicle_type] and g_savedata.constructable_vehicles[role][vehicle_type][strategy] then
		for vehicle_id, _ in pairs(g_savedata.constructable_vehicles[role][vehicle_type][strategy]) do
			if not constructable_vehicle_id and vehicle_id ~= "mod" and vehicle_list_id == g_savedata.constructable_vehicles[role][vehicle_type][strategy][vehicle_id].id then
				constructable_vehicle_id = vehicle_id
			end
		end
	else
		d.print("(sm.getContstructableVehicleID) Failed to get constructable vehicle id, role: "..tostring(role)..", type: "..tostring(vehicle_type)..", strategy: "..tostring(strategy)..", vehicle_list_id: "..tostring(vehicle_list_id), true, 1)
	end
	return constructable_vehicle_id -- returns the constructable_vehicle_id, if not found then it returns nil
end

---@param vehicle_name string the name of the vehicle
---@return integer|nil vehicle_list_id the vehicle list id from the vehicle's name, returns nil if not found
function SpawnModifiers.getVehicleListID(vehicle_name)

	if not vehicle_name then
		d.print("(SpawnModifiers.getVehicleListID) vehicle_name is nil!", true, 1)
		return nil
	end

	vehicle_name = string.removePrefix(vehicle_name)

	for vehicle_id, vehicle_object in pairs(g_savedata.vehicle_list) do
		if string.removePrefix(vehicle_object.location_data.name) == vehicle_name then
			return vehicle_id
		end
	end
	return nil
end

---@param reinforcement_type string \"punish\" to make it less likely to spawn, \"reward\" to make it more likely to spawn
---@param role_name string the role of the vehicle, such as attack, general or defend
---@param role_reinforcement integer how much to reinforce the role of the vehicle, 1-5
---@param type string? the vehicle type, such as boat, plane, heli, land or turret
---@param type_reinforcement integer? how much to reinforce the type of the vehicle, 1-5
---@param strategy_name string? strategy of the vehicle, such as strafe, bombing or general
---@param strategy_reinforcement integer? how much to reinforce the strategy of the vehicle, 1-5
---@param constructable_vehicle_id integer? the index of the vehicle in the constructable vehicle list
---@param vehicle_reinforcement integer? how much to reinforce the vehicle, 1-5
function SpawnModifiers.train(reinforcement_type, role_name, role_reinforcement, type_name, type_reinforcement, strategy_name, strategy_reinforcement, constructable_vehicle_id, vehicle_reinforcement)
	-- Check if the role exists
	if not g_savedata.constructable_vehicles[role_name] then
		-- Print an error message.
		d.print(("(SpawnModifiers.train) Requested to train vehicles with role %s, but theres no table for it in the g_savedata.constructable_vehicles table!"):format(role_name), true, 1)
		-- If not, return.
		return
	end

	-- Get the role data
	local role_data = g_savedata.constructable_vehicles[role_name]

	-- Check if the modifier value for this role exists.
	if not role_data.mod then
		-- Print a warning message.
		d.print(("(SpawnModifiers.train) Requested to train vehicles with role %s, but theres no modifier for it! This shouldn't be happening, but it's been added now to avoid an error."):format(role_name), true, 0)
		
		-- Create the modifier value for this role
		role_data.mod = 1
	end

	-- Get the feedback depending on if this is punishment or reward.
	local feedback_data = reinforcement_type == REWARD and ai_training.rewards or ai_training.punishments

	-- Get the feedback type string
	local feedback_type = reinforcement_type == REWARD and "Rewarded" or "Punished"

	--[[
		Vehicle Role
	]]

	-- If role_name or role_reinforcement was not specified, return early.
	if not role_name or not role_reinforcement then
		return
	end

	-- Apply the feedback to the role modifier
	role_data.mod = math.clamp(role_data.mod + feedback_data[role_reinforcement], MIN_MODIFIER_VALUE, MAX_MODIFIER_VALUE)

	-- Print
	d.print(("%s Role: %s | Amount %s: %s"):format(feedback_type, role_name, feedback_type, feedback_data[role_reinforcement]), true, 0)

	--[[
		Vehicle Type
	]]

	-- If type_name or type_reinforcement was not specified, return early.
	if not type_name or not type_reinforcement then
		return
	end

	-- Get the type data
	local type_data = role_data[type_name]

	-- Apply the feedback to the type modifier
	type_data.mod = math.clamp(type_data.mod + feedback_data[type_reinforcement], MIN_MODIFIER_VALUE, MAX_MODIFIER_VALUE)
	
	-- Print
	d.print(("%s Type: %s | Amount %s: %s"):format(feedback_type, type_name, feedback_type, feedback_data[type_reinforcement]), true, 0)

	--[[
		Vehicle Strategy
	]]

	-- If strategy_name or strategy_reinforcement was not specified, return early.
	if not strategy_name or not strategy_reinforcement then
		return
	end

	-- Get the strategy data
	local strategy_data = type_data[strategy_name]

	-- Apply the feedback to the strategy modifier
	strategy_data.mod = math.clamp(strategy_data.mod + feedback_data[strategy_reinforcement], MIN_MODIFIER_VALUE, MAX_MODIFIER_VALUE)
	
	-- Print
	d.print(("%s Strategy: %s | Amount %s: %s"):format(feedback_type, strategy_name, feedback_type, feedback_data[strategy_reinforcement]), true, 0)

	--[[
		Vehicle
	]]

	-- If constructable_vehicle_id or vehicle_reinforcement was not specified, return early.
	if not constructable_vehicle_id or not vehicle_reinforcement then
		return
	end

	-- Get the vehicle_modifier data
	local vehicle_modifier_data = strategy_data[constructable_vehicle_id]

	-- Apply the feedback to the vehicle modifier
	vehicle_modifier_data.mod = math.clamp(vehicle_modifier_data.mod + feedback_data[vehicle_reinforcement], MIN_MODIFIER_VALUE, MAX_MODIFIER_VALUE)
	
	-- Print
	d.print(("%s Vehicle: %s | Amount %s: %s"):format(feedback_type, constructable_vehicle_id, feedback_type, feedback_data[vehicle_reinforcement]), true, 0)
	
	-- if reinforcement_type == PUNISH then
	-- 	if role_name and role_reinforcement then
	-- 		d.print("punished role:"..role_name.." | amount punished: "..ai_training.punishments[role_reinforcement], true, 0)
	-- 		g_savedata.constructable_vehicles[role_name].mod = math.max(g_savedata.constructable_vehicles[role_name].mod + ai_training.punishments[role_reinforcement], 0)
	-- 		if type and type_reinforcement then 
	-- 			d.print("punished type:"..type.." | amount punished: "..ai_training.punishments[type_reinforcement], true, 0)
	-- 			g_savedata.constructable_vehicles[role_name][type].mod = math.max(g_savedata.constructable_vehicles[role_name][type].mod + ai_training.punishments[type_reinforcement], 0.05)
	-- 			if strategy_name and strategy_reinforcement then 
	-- 				d.print("punished strategy:"..strategy_name.." | amount punished: "..ai_training.punishments[strategy_reinforcement], true, 0)
	-- 				g_savedata.constructable_vehicles[role_name][type][strategy_name].mod = math.max(g_savedata.constructable_vehicles[role_name][type][strategy_name].mod + ai_training.punishments[strategy_reinforcement], 0.05)
	-- 				if constructable_vehicle_id and vehicle_reinforcement then 
	-- 					d.print("punished vehicle:"..constructable_vehicle_id.." | amount punished: "..ai_training.punishments[vehicle_reinforcement], true, 0)
	-- 					g_savedata.constructable_vehicles[role_name][type][strategy_name][constructable_vehicle_id].mod = math.max(g_savedata.constructable_vehicles[role_name][type][strategy_name][constructable_vehicle_id].mod + ai_training.punishments[vehicle_reinforcement], 0.05)
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- elseif reinforcement_type == REWARD then
	-- 	if role_name and role_reinforcement then
	-- 		d.print("rewarded role:"..role_name.." | amount rewarded: "..ai_training.rewards[role_reinforcement], true, 0)
	-- 		g_savedata.constructable_vehicles[role_name].mod = math.min(g_savedata.constructable_vehicles[role_name].mod + ai_training.rewards[role_reinforcement], 1.5)
	-- 		if type and type_reinforcement then 
	-- 			d.print("rewarded type:"..type.." | amount rewarded: "..ai_training.rewards[type_reinforcement], true, 0)
	-- 			g_savedata.constructable_vehicles[role_name][type].mod = math.min(g_savedata.constructable_vehicles[role_name][type].mod + ai_training.rewards[type_reinforcement], 1.5)
	-- 			if strategy_name and strategy_reinforcement then 
	-- 				d.print("rewarded strategy:"..strategy_name.." | amount rewarded: "..ai_training.rewards[strategy_reinforcement], true, 0)
	-- 				g_savedata.constructable_vehicles[role_name][type][strategy_name].mod = math.min(g_savedata.constructable_vehicles[role_name][type][strategy_name].mod + ai_training.rewards[strategy_reinforcement], 1.5)
	-- 				if constructable_vehicle_id and vehicle_reinforcement then 
	-- 					d.print("rewarded vehicle:"..constructable_vehicle_id.." | amount rewarded: "..ai_training.rewards[vehicle_reinforcement], true, 0)
	-- 					g_savedata.constructable_vehicles[role_name][type][strategy_name][constructable_vehicle_id].mod = math.min(g_savedata.constructable_vehicles[role_name][type][strategy_name][constructable_vehicle_id].mod + ai_training.rewards[vehicle_reinforcement], 1.5)
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end
end

---@param peer_id integer the peer_id of the player who executed the command
---@param role string the role of the vehicle, such as attack, general or defend
---@param type string the vehicle type, such as boat, plane, heli, land or turret
---@param strategy string strategy of the vehicle, such as strafe, bombing or general
---@param constructable_vehicle_id integer the index of the vehicle in the constructable vehicle list
function SpawnModifiers.debug(peer_id, role, type, strategy, constructable_vehicle_id)
	if not constructable_vehicle_id then
		if not strategy then
			if not type then
				d.print("modifier of vehicles with role "..role..": "..g_savedata.constructable_vehicles[role].mod, false, 0, peer_id)
			else
				d.print("modifier of vehicles with role "..role..", with type "..type..": "..g_savedata.constructable_vehicles[role][type].mod, false, 0, peer_id)
			end
		else
			d.print("modifier of vehicles with role "..role..", with type "..type..", with strategy "..strategy..": "..g_savedata.constructable_vehicles[role][type][strategy].mod, false, 0, peer_id)
		end
	else
		d.print("modifier of role "..role..", type "..type..", strategy "..strategy..", with the id of "..constructable_vehicle_id..": "..g_savedata.constructable_vehicles[role][type][strategy][constructable_vehicle_id].mod, false, 0, peer_id)
	end
end

---@return vehicles[] vehicles the top 3 vehicles that it thinks is good at killing the player, and the 3 worst (.best .worst)
function SpawnModifiers.getStats()

	-- get all vehicles and put them in a table
	local all_vehicles = {}
	for role, role_data in pairs(g_savedata.constructable_vehicles) do
		if type(role_data) == "table" then
			for veh_type, veh_data in pairs(g_savedata.constructable_vehicles[role]) do
				if type(veh_data) == "table" then
					for strat, strat_data in pairs(veh_data) do
						if type(strat_data) == "table" then
							g_savedata.constructable_vehicles[role][veh_type][strat].mod = 1
							for _, vehicle_data in pairs(strat_data) do
								if type(vehicle_data) == "table" and vehicle_data.mod then
									table.insert(all_vehicles, {
										mod = vehicle_data.mod,
										name = vehicle_data.name
									})
								end
							end
						end
					end
				end
			end
		end
	end

	-- sort the table from greatest mod value to least
	table.sort(all_vehicles, function(a, b) return a.mod > b.mod end)

	local vehicles = {
		best = {
			all_vehicles[1],
			all_vehicles[2],
			all_vehicles[3]
		},
		worst = {
			all_vehicles[#all_vehicles],
			all_vehicles[#all_vehicles - 1],
			all_vehicles[#all_vehicles - 2]
		}
	}

	return vehicles
end