--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.components.tags")
require("libraries.addon.script.debugging")
require("libraries.addon.script.matrix")
require("libraries.addon.script.pathfinding")

require("libraries.icm.objective")
require("libraries.icm.squad")
require("libraries.icm.vehicle")

require("libraries.utils.math")
require("libraries.utils.tables")

-- library name
Cargo = {}

--[[


	Variables
   

]]

s = s or server

---@type table<integer|SWTankFluidTypeEnum, string>
i_fluid_types = {
	[0] = "fresh water",
	"diesel",
	"jet_fuel",
	"air",
	"exhaust",
	"oil",
	"sea water",
	"steam"
}

---@type table<string, integer|SWTankFluidTypeEnum>
s_fluid_types = {
	["fresh water"] = 0,
	diesel = 1,
	["jet_fuel"] = 2,
	air = 3,
	exhaust = 4,
	oil = 5,
	["sea water"] = 6,
	steam = 7
}

--[[


	Classes


]]

---@class ICMResupplyWeights
---@field oil number the weight for oil
---@field diesel number the weight for diesel
---@field jet_fuel number the weight for jet fuel


--[[


	Functions         


]]

--- @param vehicle_id integer the vehicle's id you want to clean
function Cargo.clean(vehicle_id) -- cleans the data on the cargo vehicle if it exists
	-- check if it is a cargo vehicle
	for cargo_vehicle_index, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
		d.print("cargo vehicle id: "..cargo_vehicle.vehicle_data.id.."\nRequested id: "..vehicle_id, true, 0)
		if cargo_vehicle.vehicle_data.id == vehicle_id then
			d.print("cleaning cargo vehicle", true, 0)

			--* remove the search area from the map
			s.removeMapID(-1, cargo_vehicle.search_area.ui_id)
			g_savedata.cargo_vehicles[vehicle_id] = nil

			-- clear all the island cargo data
			g_savedata.ai_base_island.cargo_transfer = {
				oil = 0,
				diesel = 0,
				jet_fuel = 0
			}

			for _, island in pairs(g_savedata.islands) do
				island.cargo_transfer = {
					oil = 0,
					diesel = 0,
					jet_fuel = 0
				}
			end

			--* check if theres still vehicles in the squad, if so, set the squad's command to none
			local squad_index, squad = Squad.getSquad(vehicle_id)
			if squad_index and squad then
				g_savedata.ai_army.squadrons[squad_index].command = SQUAD.COMMAND.NONE
			end

			-- check if theres a convoy waiting for this convoy
			-- if there is, delete it to avoid a softlock
			if g_savedata.cargo_vehicles[cargo_vehicle_index+1] then
				if g_savedata.cargo_vehicles[cargo_vehicle_index+1].route_status == 3 then
					local squad_index, squad = Squad.getSquad(g_savedata.cargo_vehicles[cargo_vehicle_index+1].vehicle_data.id)

					if squad_index then
						v.kill(g_savedata.cargo_vehicles[cargo_vehicle_index+1].vehicle_data.id, true, true)
					end
				end
			end


			return
		end
	end

	-- check if its a convoy vehicle
	for _, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
		for convoy_index, convoy_vehicle_id in ipairs(cargo_vehicle.convoy) do
			if vehicle_id == convoy_vehicle_id then
				table.remove(cargo_vehicle.convoy, convoy_index)
				return
			end
		end
	end
end

--- @param vehicle_id integer the vehicle's id which has the cargo you want to refund
--- @return boolean refund_successful if the refund was successful
function Cargo.refund(vehicle_id) -- refunds the cargo to the island which was sending the cargo
	if not g_savedata.cargo_vehicles[vehicle_id] then
		d.print("(Cargo.refund) This vehicle is not a cargo vehicle", true, 0)
		return false
	end

	if not g_savedata.cargo_vehicles[vehicle_id].resupplier_island then
		d.print("(Cargo.refund) This vehicle does not have a resupplier island", true, 1)
		return false
	end

	for cargo_id, cargo in ipairs(g_savedata.cargo_vehicles[vehicle_id].requested_cargo) do
		g_savedata.cargo_vehicles[vehicle_id].resupplier_island.cargo[cargo.cargo_type] = g_savedata.cargo_vehicles[vehicle_id].resupplier_island.cargo[cargo.cargo_type] + cargo.amount
		g_savedata.cargo_vehicles[vehicle_id].requested_cargo[cargo_id].amount = 0
	end

	return true
end

---@param cargo_vehicle vehicle_object the cargo vehicle you want to get escorts for
---@param island ISLAND the island to try to spawn escorts at
function Cargo.getEscorts(cargo_vehicle, island) -- gets the escorts for the cargo vehicle

	local possible_escorts = {} -- vehicles which are valid escort options

	-- the commands that the cargo vehicle can take vehicles from to use as escorts
	local transferrable_commands = {
		SQUAD.COMMAND.PATROL,
		SQUAD.COMMAND.DEFEND,
		SQUAD.COMMAND.NONE
	}

	local max_distance = 7500 -- the max distance the vehicle must be to use as an escort

	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		--? if their vehicle type is the same as we're requesting
		if squad.vehicle_type == cargo_vehicle.vehicle_type then
			--? check if they have a command which we can take from
			local valid_command = false
			for _, command in ipairs(transferrable_commands) do
				if command == squad.command then
					valid_command = true
					break
				end
			end

			if valid_command then
				for _, vehicle_object in pairs(squad.vehicles) do
					-- if the vehicle is within range
					if m.xzDistance(cargo_vehicle.transform, vehicle_object.transform) <= max_distance then
						table.insert(possible_escorts, vehicle_object)
					end
				end
			end
		end
	end

	--? if we dont have enough escorts
	if #possible_escorts < RULES.LOGISTICS.CONVOY.min_escorts then
		--* attempt to spawn more escorts
		local escorts_to_spawn = RULES.LOGISTICS.CONVOY.min_escorts - #possible_escorts
		for i = 1, escorts_to_spawn do
			local spawned_vehicle, vehicle_data = v.spawnRetry(nil, cargo_vehicle.vehicle_type, true, island, 2, 5)
			if spawned_vehicle then
				table.insert(possible_escorts, vehicle_data)
				d.print("(Cargo.getEscorts) Spawned escort vehicle", true, 0)
			end
		end
	elseif #possible_escorts > RULES.LOGISTICS.CONVOY.max_escorts then
		for escort_index, escort in pairs(possible_escorts) do
			possible_escorts[escort_index].escort_weight = Cargo.getEscortWeight(cargo_vehicle, escort)
		end

		table.sort(possible_escorts, function(a, b)
			return a.escort_weight > b.escort_weight
		end)

		while #possible_escorts > RULES.LOGISTICS.CONVOY.max_escorts do
			table.remove(possible_escorts, #possible_escorts)
		end
	end

	-- insert the cargo vehicle into the table for the convoy
	g_savedata.cargo_vehicles[cargo_vehicle.id].convoy[1 + math.floor(#possible_escorts/2)] = cargo_vehicle.id

	for escort_index, escort in ipairs(possible_escorts) do
		local squad_index, _ = Squad.getSquad(cargo_vehicle.id)

		if squad_index then
			transferToSquadron(escort, squad_index, true)
			p.resetPath(escort)
			if cargo_vehicle.transform then
				p.addPath(escort, cargo_vehicle.transform)
			else
				d.print("(Cargo.getEscorts) cargo_vehicle.transform is nil!", true, 0)
			end

			-- insert the escorts into the table for the convoy
			if not math.isWhole(escort_index/2) then 
				--* put this vehicle at the front as its index is odd
				g_savedata.cargo_vehicles[cargo_vehicle.id].convoy[1 + math.floor(#possible_escorts/2) + math.ceil(escort_index/2)] = escort.id
			else
				--* put this vehicle at the back as index is even
				g_savedata.cargo_vehicles[cargo_vehicle.id].convoy[(1 + math.floor(#possible_escorts/2)) - math.ceil(escort_index/2)] = escort.id
			end
		end
	end
end

---@param cargo_vehicle vehicle_object the cargo vehicle the escort is escorting
---@param escort_vehicle vehicle_object the escort vehicle you want to get the weight of
---@return number weight the weight of the escort
function Cargo.getEscortWeight(cargo_vehicle, escort_vehicle) --* get the weight of the escort vehicle for use in a convoy
	local weight = 1

	if not cargo_vehicle then
		d.print("(Cargo.getEscortWeight) cargo_vehicle is nil!", true, 1)
		return 0
	end

	if not escort_vehicle then
		d.print("(Cargo.getEscortWeight) escort_vehicle is nil!", true, 1)
		return 0
	end

	-- calculate weight based on difference of speed
	speed_weight = v.getSpeed(cargo_vehicle) - v.getSpeed(escort_vehicle)
	
	--? if the escort vehicle is slower, then make it affect the weight more
	if speed_weight > 0 then
		speed_weight = speed_weight * 1.7
	end

	speed_weight = math.min(math.abs(speed_weight / 25), 0.3)

	weight = weight - speed_weight


	-- calculate weight based on damage of the escort vehicle
	damage_weight = math.min(escort_vehicle.current_damage / 100, 0.6)
	weight = weight - damage_weight

	return weight
end

--- @param vehicle_id number the vehicle's id
--- @return table|nil cargo the contents of the cargo vehicle's tanks
--- @return boolean got_tanks wether or not we were able to get the tanks
function Cargo.getTank(vehicle_id)

	if not vehicle_id then
		d.print("(Cargo.getTank) vehicle_id is nil!", true, 0)
		return nil, false
	end

	if not g_savedata.cargo_vehicles[vehicle_id] then
		d.print("(Cargo.getTank) "..vehicle_id.." is not a cargo vehicle!", true, 0)
		return nil, false
	end

	---@type requestedCargo
	local cargo = {
		[1] = {
			cargo_type = g_savedata.cargo_vehicles[vehicle_id].requested_cargo[1].cargo_type,
			amount = 0
		},
		[2] = {
			cargo_type = g_savedata.cargo_vehicles[vehicle_id].requested_cargo[2].cargo_type,
			amount = 0
		},
		[3] = {
			cargo_type = g_savedata.cargo_vehicles[vehicle_id].requested_cargo[3].cargo_type,
			amount = 0
		}
	}

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	if not vehicle_object then
		d.print("(Cargo.getTank) vehicle_object is nil!", true, 0)
		return cargo, false
	end

	local large_tank_capacity = 703.125

	local cargo_tanks_per_set = vehicle_object.cargo.capacity/large_tank_capacity

	--d.print("(Cargo.getTank) cargo_tanks_per_set: "..tonumber(cargo_tanks_per_set), true, 0)

	for tank_set=0, 2 do
		for tank_index=0, cargo_tanks_per_set-1 do

			local tank_data, got_data = s.getVehicleTank(vehicle_id, "RESOURCE_TYPE_"..tank_set.."_"..tank_index)

			if got_data then
				if tank_data.value > 0 then
					cargo[tank_set + 1].amount = cargo[tank_set + 1].amount + tank_data.value
					--[[d.print(("(Cargo.getTank) Got Tank. tank_set: %i tank_index: %i amount in tank: %s"):format(tank_set, tank_index, tank_data.value), true, 0)
				else
					d.print("(Cargo.getTank) Tank is empty.\ntank_set: "..tank_set.." tank_index: "..tank_index, true, 1)]]
				end
			else
				d.print("(Cargo.getTank) Error getting tank data for "..vehicle_id.." Tank set: "..tank_set.." Tank index: "..tank_index, true, 1)
			end
		end
	end

	return cargo, true
end

---@param vehicle_id integer the id of the vehicle
---@param tank_name string the name of the tank to set
---@param fluid_type string fluid type to set the tank to
---@param amount number what to set the tank to
---@param set_tank boolean? if true then set the tank, if false then just add the amount to the tank
---@return boolean set_successful if the tank was set successfully
---@return string error_message an error message if it was not successfully set
---@return number? excess amount of fluid that was excess
function Cargo.setTank(vehicle_id, tank_name, fluid_type, amount, set_tank)
	local fluid_type = string.lower(fluid_type)
	
	local fluid_id = s_fluid_types[fluid_type]

	-- make sure the fluid type is valid
	if not fluid_id then
		return false, "unknown fluid type "..tostring(fluid_type)
	end

	if set_tank then
		-- set the tank
		s.setVehicleTank(vehicle_id, tank_name, amount, fluid_id)
		return true, "no error"
	else
		-- add the amount to the tank
		local tank_data, got_tank = s.getVehicleTank(vehicle_id, tank_name)

		-- if it got the data check
		if not got_tank then
			return false, "was unable to get the tank data"
		end

		-- fluid type check
		if tank_data.fluid_type ~= fluid_id and tank_data.value >= 1 and tank_data.fluid_type ~= 0 then
			return false, "tank is not the same fluid type, and its not empty | tank's fluid type: "..tank_data.fluid_type.." requested_fluid_type: "..fluid_id.." | tank name: "..tank_name.." tank contents: "..tank_data.value.."L"
		end

		local excess = math.max((tank_data.value + amount) - tank_data.capacity, 0)
		local amount_to_set = math.min(tank_data.value + amount, tank_data.capacity)

		s.setVehicleTank(vehicle_id, tank_name, amount_to_set, fluid_id)

		return true, "no error", excess
	end
end

---@param vehicle_id integer the id of the vehicle
---@param keypad_name string the name of the keypad to set
---@param cargo_type string the type of cargo to set the keypad to
function Cargo.setKeypad(vehicle_id, keypad_name, cargo_type)
	s.setVehicleKeypad(vehicle_id, keypad_name, s_fluid_types[cargo_type])
end

---@param recipient any the island or vehicle object thats getting the cargo
---@param sender any the island or vehicle object thats sending the cargo
---@param requested_cargo requestedCargo the cargo thats going between the sender and recipient
---@param transfer_time number how long the cargo transfer should take
---@param tick_rate number the tick rate
---@return boolean transfer_complete if the transfer is fully completed
---@return string transfer_complete_reason why the transfer completed
function Cargo.transfer(recipient, sender, requested_cargo, transfer_time, tick_rate)

	local large_tank_capacity = 703.125
	local max_island_cargo = RULES.LOGISTICS.CARGO.ISLANDS.max_capacity

	local cargo_to_transfer = {
		oil = 0,
		diesel = 0,
		jet_fuel = 0
	}

	local total_cargo_to_transfer = cargo_to_transfer

	-- calculate total cargo to transfer
	for slot, cargo in pairs(requested_cargo) do
		--d.print("cargo.amount: "..tostring(cargo.amount), true, 0)
		total_cargo_to_transfer[cargo.cargo_type] = cargo_to_transfer[cargo.cargo_type] + cargo.amount
	end

	-- calculate how much cargo to transfer
	for cargo_type, amount in pairs(total_cargo_to_transfer) do
		cargo_to_transfer[cargo_type] = total_cargo_to_transfer[cargo_type] / (transfer_time / tick_rate)
	end

	-- calculate how much cargo to transfer for vehicles
	local vehicle_cargo_to_transfer = {
		[1] = {
			amount = requested_cargo[1].amount / (transfer_time / tick_rate),
			cargo_type = requested_cargo[1].cargo_type
		},
		[2] = {
			amount = requested_cargo[2].amount / (transfer_time / tick_rate),
			cargo_type = requested_cargo[2].cargo_type
		},
		[3] = {
			amount = requested_cargo[3].amount / (transfer_time / tick_rate),
			cargo_type = requested_cargo[3].cargo_type
		},
	}

	-- remove cargo from the sender
	if sender.object_type == "island" then
		-- if the sender is a island

		for cargo_type, amount in pairs(cargo_to_transfer) do
			if amount > 0 then
				sender.cargo[cargo_type] = math.clamp(sender.cargo[cargo_type] - amount, 0, max_island_cargo)
				sender.cargo_transfer[cargo_type] = sender.cargo_transfer[cargo_type] + amount
				if sender.cargo[cargo_type] == 0 then
					return true, "island ran out of "..cargo_type
				end
			end
		end

	elseif sender.object_type == "vehicle" then
		-- if the sender is a vehicle

		-- set the variables
		for cargo_type, amount in pairs(cargo_to_transfer) do
			if amount > 0 then
				sender.cargo.current[cargo_type] = math.max(sender.cargo.current[cargo_type] - amount, 0)
			end
		end

		-- if the vehicle is loaded, then set the tanks
		if sender.state.is_simulating then
			-- set the tanks
			for slot, cargo in ipairs(vehicle_cargo_to_transfer) do
				for i=1, sender.cargo.capacity/large_tank_capacity do
					local set_cargo, error_message = Cargo.setTank(sender.id, "RESOURCE_TYPE_"..(slot-1).."_"..(i-1), cargo.cargo_type, -cargo.amount/sender.cargo.capacity, false)
					if not set_cargo then
						d.print("(Cargo.transfer s) error setting tank: "..error_message, true, 1)
					end
					Cargo.setKeypad(sender.id, "RESOURCE_TYPE_"..(slot-1), cargo.cargo_type)
				end
			end
		end

		-- check if we're finished
		local empty_cargo_types = 0
		for cargo_type, amount in pairs(sender.cargo.current) do
			if amount == 0 then
				empty_cargo_types = empty_cargo_types + 1
			end
		end

		if empty_cargo_types == 3 then
			return true, "done transfer"
		end

	end

	-- give cargo to the recipient
	if recipient.object_type == "island" then
		-- the recipient is a island
		recipient = g_savedata.islands[recipient.index]

		--d.print("island name: "..recipient.name, true, 0)

		for cargo_type, amount in pairs(cargo_to_transfer) do
			if amount > 0 then
				--d.print("adding "..amount, true, 0)
				--d.print("type: "..cargo_type, true, 0)
				recipient.cargo[cargo_type] = recipient.cargo[cargo_type] + amount
				recipient.cargo_transfer[cargo_type] = recipient.cargo_transfer[cargo_type] + amount
			end
		end

		-- check for if its done transferring
		local cargo_types_to_check = #cargo_to_transfer
		for cargo_type, amount in pairs(cargo_to_transfer) do
			if total_cargo_to_transfer[cargo_type] <= recipient.cargo_transfer[cargo_type] then
				cargo_types_to_check = cargo_types_to_check - 1
			end
		end

		if cargo_types_to_check == 0 then
			return true, "done transfer"
		end

	elseif recipient.object_type == "vehicle" then
		-- the recipient is a vehicle

		local recipient, _, _ = Squad.getVehicle(recipient.id)

		if not recipient then
			d.print("(Cargo.transfer) failed to get vehicle_object, returned recipient is nil!")
			return false, "error"
		end

		-- set the variables
		for cargo_type, amount in pairs(cargo_to_transfer) do
			if amount > 0 then
				recipient.cargo.current[cargo_type] = recipient.cargo.current[cargo_type] + amount
				--d.print("cargo type: "..cargo_type.." amount: "..amount, true, 0)
			end
		end

		-- if the vehicle is loaded, then set the tanks
		if recipient.state.is_simulating then
			-- set the tanks
			for slot, cargo in ipairs(vehicle_cargo_to_transfer) do
				for i=1, recipient.cargo.capacity/large_tank_capacity do
					local set_cargo, error_message = Cargo.setTank(recipient.id, "RESOURCE_TYPE_"..(slot-1).."_"..(i-1), cargo.cargo_type, cargo.amount/(recipient.cargo.capacity/large_tank_capacity))
					--d.print("(Cargo.transfer r) amount: "..(cargo.amount/(recipient.cargo.capacity/large_tank_capacity)), true, 0)
					if not set_cargo then
						d.print("(Cargo.transfer r) error setting tank: "..error_message, true, 1)
					end
					Cargo.setKeypad(recipient.id, "RESOURCE_TYPE_"..(slot-1), cargo.cargo_type)
				end
			end
		end

		-- check for if its done transferring
		local cargo_types_to_check = #cargo_to_transfer
		for cargo_type, amount in pairs(cargo_to_transfer) do
			if total_cargo_to_transfer[cargo_type] <= recipient.cargo.current[cargo_type] then
				cargo_types_to_check = cargo_types_to_check - 1
			end
		end

		if cargo_types_to_check == 0 then
			return true, "done transfer"
		end
	end
	
	return false, "transfer incomplete"
end

---@param island ISLAND the island you want to produce the cargo at
---@param natural_production string the natural production of this island
function Cargo.produce(island, natural_production)

	local natural_production = natural_production or 0 -- the ai_base island will produce these resources naturally at this rate per hour

	local cargo = {
		production = {
			oil = (Tags.getValue(island.tags, "oil_production") or 0)/60,
			diesel = (Tags.getValue(island.tags, "diesel_production") or 0)/60,
			jet_fuel = (Tags.getValue(island.tags, "jet_fuel_production") or 0)/60
		},
		consumption = {
			oil = (Tags.getValue(island.tags, "oil_consumption") or 0)/60,
			diesel = (Tags.getValue(island.tags, "diesel_consumption") or 0)/60,
			jet_fuel = (Tags.getValue(island.tags, "jet_fuel_consumption") or 0)/60
		}
	}

	-- multiply the amount produced/consumed by the modifier
	for usage_type, usage_data in pairs(cargo) do
		if type(usage_data) == "table" then
			for resource, amount in pairs(usage_data) do
				cargo[usage_type][resource] = amount * g_savedata.settings.CARGO_GENERATION_MULTIPLIER
			end
		end
	end
	
	-- produce oil
	if cargo.production.oil ~= 0 or natural_production ~= 0 then
		island.cargo.oil = math.clamp(island.cargo.oil + cargo.production.oil + natural_production, 0, RULES.LOGISTICS.CARGO.ISLANDS.max_capacity)
	end
	
	-- produce diesel
	if cargo.production.diesel ~= 0 or natural_production ~= 0 then
		island.cargo.diesel = math.noNil(math.max(0, island.cargo.diesel + math.min((math.min(island.cargo.oil/(cargo.production.jet_fuel+cargo.production.diesel+natural_production/2), 1)*(cargo.production.diesel+(natural_production/2))), RULES.LOGISTICS.CARGO.ISLANDS.max_capacity)))
	end

	-- produce jet fuel
	if cargo.production.jet_fuel ~= 0 or natural_production ~= 0 then
		island.cargo.jet_fuel = math.noNil(math.max(0, island.cargo.jet_fuel + math.min((math.min(island.cargo.oil/(cargo.production.jet_fuel+cargo.production.diesel+natural_production/2), 1)*(cargo.production.jet_fuel+(natural_production/2))), RULES.LOGISTICS.CARGO.ISLANDS.max_capacity)))
	end

	-- consume the oil used to make the jet fuel and diesel
	if cargo.production.jet_fuel ~= 0 or cargo.production.diesel ~= 0 or natural_production ~= 0 then
		island.cargo.oil = island.cargo.oil - (
			(math.min(island.cargo.oil/(cargo.production.jet_fuel+cargo.production.diesel+natural_production/2), 1)*(cargo.production.diesel+natural_production/2)) +
			(math.min(island.cargo.oil/(cargo.production.jet_fuel+cargo.production.diesel+natural_production/2), 1)*(cargo.production.jet_fuel+natural_production/2))
		)
	end
end

---@return island ISLAND the island thats best to resupply
---@return weight weight[] the weights of all of the cargo types for the resupply island
function Cargo.getBestResupplyIsland()

	local island_weights = {}

	for island_index, island in pairs(g_savedata.islands) do
		if island.faction == ISLAND.FACTION.AI then
			table.insert(island_weights, {
				island = island,
				weight = Cargo.getResupplyWeight(island)
			})
		end
	end

	local resupply_island = nil
	local resupply_resource = {
		oil = 0,
		diesel = 0,
		jet_fuel = 0,
		total = 0
	}

	for _, resupply in pairs(island_weights) do
		local total_weight = 0

		for _, weight in pairs(resupply.weight) do
			total_weight = total_weight + weight
		end

		d.print("total weight: "..total_weight.." island name: "..resupply.island.name, true, 0)

		if total_weight > resupply_resource.total then
			resupply_island = resupply.island
			resupply_resource = {
				oil = resupply.weight.oil,
				diesel = resupply.weight.diesel,
				jet_fuel = resupply.weight.jet_fuel,
				total = total_weight
			}
		end
	end

	return resupply_island, resupply_resource
end

---@param resupply_weights ICMResupplyWeights the weights of all of the cargo types for the resupply island
---@return ISLAND island the resupplier island
---@return ICMResupplyWeights resupplier_weights the weights of all the cargo types for the resupplier island, sorted from most to least weight
function Cargo.getBestResupplierIsland(resupply_weights)

	local island_weights = {}

	-- get all island resupplier weights (except for player main base)

	for _, island in pairs(g_savedata.islands) do
		table.insert(island_weights, {
			island = island,
			weight = Cargo.getResupplierWeight(island)
		})
	end

	-- add ai's main base to list
	table.insert(island_weights, {
		island = g_savedata.ai_base_island,
		weight = Cargo.getResupplierWeight(g_savedata.ai_base_island)
	})

	local resupplier_island = nil
	local resupplier_resource = {
		oil = 0,
		diesel = 0,
		jet_fuel = 0,
	}
	local total_resupplier_resource = -1

	for _, resupplier in pairs(island_weights) do
		local total_weight = 0

		for _, weight in pairs(resupplier.weight) do
			total_weight = total_weight + weight
		end

		if total_weight > total_resupplier_resource then
			resupplier_island = resupplier.island
			resupplier_resource = {
				oil = resupplier.weight.oil * resupply_weights.oil,
				diesel = resupplier.weight.diesel * resupply_weights.diesel,
				jet_fuel = resupplier.weight.jet_fuel * resupply_weights.jet_fuel
			}
		end
	end

	table.sort(resupplier_resource, function(a, b) return a < b end)

	return resupplier_island, resupplier_resource
end

---@param island ISLAND the island you want to get the resupply weight of
---@return weight[] weights the weights of all of the cargo types for the resupply island
function Cargo.getResupplyWeight(island) -- get the weight of the island (for resupplying the island)
	-- weight by how much cargo the island has
	local oil_weight = ((RULES.LOGISTICS.CARGO.ISLANDS.max_capacity - island.cargo.oil) / (RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.9)) -- oil
	local diesel_weight = (((RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.5) - island.cargo.diesel)/(RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.45)) -- diesel
	local jet_fuel_weight = (((RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.5) - island.cargo.jet_fuel)/(RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.45)) -- jet fuel

	-- weight by how many vehicles the island has defending
	local weight_modifier = 1 * math.max(5 - island.defenders, 1) -- defenders

	local target_island, origin_island = Objective.getIslandToAttack()
	if origin_island.name == island.name then -- if this island the ai is using to attack from
		weight_modifier = weight_modifier * 1.2 -- increase weight
	end

	weight_modifier = weight_modifier * ((time.hour - island.last_defended) / (time.hour * 3)) -- weight by how long ago the player attacked

	local weight = {
		oil = oil_weight * (Tags.getValue(island.tags, "oil_consumption") and 1 or 0),
		diesel = diesel_weight * weight_modifier * (Tags.getValue(island.tags, "diesel_production") and 0.3 or 1),
		jet_fuel = jet_fuel_weight * weight_modifier * (Tags.getValue(island.tags, "jet_fuel_production") and 0.3 or 1)
	}

	return weight
end

---@param island ISLAND|AI_ISLAND the island you want to get the resupplier weight of
---@return ICMResupplyWeights weights the weights of all of the cargo types for the resupplier island
function Cargo.getResupplierWeight(island) -- get weight of the island (for using it to resupply another island)
	local oil_weight = (island.cargo.oil/(RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.9)) -- oil
	local diesel_weight = (island.cargo.diesel/(RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.45)) -- diesel
	local jet_fuel_weight = (island.cargo.jet_fuel/(RULES.LOGISTICS.CARGO.ISLANDS.max_capacity*0.45)) -- jet fuel

	local controller_weight = 1
	if island.faction == ISLAND.FACTION.NEUTRAL then
		controller_weight = 0.3
	elseif island.faction == ISLAND.FACTION.PLAYER then
		controller_weight = 0.1
	end

	local weight = {
		oil = oil_weight * (Tags.getValue(island.tags, "oil_production") and 1 or 0.2) * controller_weight,
		diesel = diesel_weight * (Tags.getValue(island.tags, "diesel_production") and 1 or 0.2) * controller_weight,
		jet_fuel = jet_fuel_weight * (Tags.getValue(island.tags, "jet_fuel_production") and 1 or 0.2) * controller_weight
	}

	return weight
end

---@param cargo_type string the type of the cargo
---@param amount number the amount of cargo
function Cargo.newRequestedCargoItem(cargo_type, amount)
	---@class requestedCargoItem
	---@field cargo_type string the type of the cargo
	---@field amount number the amount of the cargo
	local requested_cargo_item = {
		cargo_type = cargo_type,
		amount = amount
	}
	return requested_cargo_item
end


---@param cargo_weight weight[] the weight for the cargo trip
---@param vehicle_object vehicle_object the vehicle data for the first cargo trip
---@return requestedCargo requested_cargo the cargo type for each tank set, and the amount for each tank set
function Cargo.getRequestedCargo(cargo_weight, vehicle_object)

	--* requestedCargoItem = {
	--*		 cargo_type = string,
	--*		 amount = number
	--* }
	---@class requestedCargo
	---@field [1] requestedCargoItem
	---@field [2] requestedCargoItem
	---@field [3] requestedCargoItem
	local requested_cargo = {}

	local cargo_config = {}

	-- get the amount of cargo types we will need to resupply
	local valid_cargo_amount = 0
	local valid_cargo_types = {}
	for cargo_type, weight in pairs(cargo_weight) do
		if weight > 0 then
			valid_cargo_amount = valid_cargo_amount + 1
			valid_cargo_types[cargo_type] = weight
		end
	end

	if not math.isWhole(3/valid_cargo_amount) then -- if the amount of valid cargo types is not a whole number
		-- decide which cargo type gets the remaning container
		local highest_weight = nil
		for cargo_type, weight in pairs(valid_cargo_types) do
			if not highest_weight or weight > highest_weight.weight then
				highest_weight = {
					cargo_type = cargo_type,
					weight = valid_cargo_types[cargo_type]
				}
			elseif weight == highest_weight then
				highest_weight = nil
			end
		end

		-- insert them all into a table
		local possible_cargo = {}
		for cargo_type, weight in pairs(valid_cargo_types) do
			table.insert(possible_cargo, {
				cargo_type = cargo_type,
				weight = weight
			})
		end

		-- check if we found the highest weight
		if not highest_weight then
			-- all cargo types have the same weight, use randomness
			-- choose a random one
			possible_cargo[#possible_cargo+1] = possible_cargo[math.random(1, #possible_cargo)]
		else
			possible_cargo[#possible_cargo+1] = highest_weight
			
		end
		cargo_config = possible_cargo
	else
		-- if its a whole number, then split the cargo evenly
		local cargo_slots_per_type = 3/valid_cargo_amount
		for cargo_type, weight in pairs(valid_cargo_types) do
			for i = 1, cargo_slots_per_type do
				table.insert(cargo_config, {
					cargo_type = cargo_type,
					weight = weight
				})
			end
		end
	end


	-- make sure no cargo amounts are nil
	for slot, cargo in pairs(cargo_config) do

		local cargo_capacity = vehicle_object.cargo.capacity
		if type(cargo_capacity) ~= "string" then
			requested_cargo[slot] = Cargo.newRequestedCargoItem(cargo.cargo_type, cargo_capacity)
		end
	end

	-- return the requested cargo
	return requested_cargo
end

---@param origin_island ISLAND the island of which the cargo is coming from
---@param dest_island ISLAND the island of which the cargo is going to
---@return route[] best_route the best route to go from the origin to the destination
function Cargo.getBestRoute(origin_island, dest_island) -- origin = resupplier island | dest = resupply island
	local start_time = s.getTimeMillisec()

	d.print("Calculating Pathfinding route from "..origin_island.name.." to "..dest_island.name, true, 0)

	local best_route = {}

	-- get the vehicles we will be using for the cargo trip
	local transport_vehicle = {
		heli = Cargo.getTransportVehicle("heli"),
		land = Cargo.getTransportVehicle("land"),
		plane = Cargo.getTransportVehicle("plane"),
		sea = Cargo.getTransportVehicle("boat")
	}

	-- checks for all vehicles, and fills in some info to avoid errors if it doesnt exist
	if not transport_vehicle.heli then
		transport_vehicle.heli = {
			name = "none"
		}
	elseif not transport_vehicle.heli.name then
		transport_vehicle.heli = {
			name = "unknown"
		}
	end
	if not transport_vehicle.land then
		transport_vehicle.land = {
			name = "none"
		}
	elseif not transport_vehicle.land.name then
		transport_vehicle.land = {
			name = "unknown"
		}
	end
	if not transport_vehicle.plane then
		transport_vehicle.plane = {
			name = "none"
		}
	elseif not transport_vehicle.plane.name then
		transport_vehicle.plane = {
			name = "unknown"
		}
	end
	if not transport_vehicle.sea then
		transport_vehicle.sea = {
			name = "none"
		}
	elseif not transport_vehicle.sea.name then
		transport_vehicle.sea = {
			name = "unknown"
		}
	end
	


	local first_cache_index = dest_island.index
	local second_cache_index = origin_island.index

	if origin_island.index > dest_island.index then
		first_cache_index = origin_island.index
		second_cache_index = dest_island.index
	end

	-- check if the best route here is already cached
	if Cache.exists("cargo.best_routes["..first_cache_index.."]["..second_cache_index.."]["..transport_vehicle.heli.name.."]["..transport_vehicle.land.name.."]["..transport_vehicle.plane.name.."]["..transport_vehicle.sea.name.."]") then
		------
		-- read data from cache
		------

		best_route = Cache.read("cargo.best_routes["..first_cache_index.."]["..second_cache_index.."]["..transport_vehicle.heli.name.."]["..transport_vehicle.land.name.."]["..transport_vehicle.plane.name.."]["..transport_vehicle.sea.name.."]")
	else
		------
		-- calculate best route (resource intensive)
		------

		--
		-- gets the speed of all of the vehicles we were given
		--
		for vehicle_index, vehicle_object in pairs(transport_vehicle) do
			if vehicle_object.name ~= "none" and vehicle_object.name ~= "unknown" then

				local movement_speed = 0.1
				local vehicle_type = string.gsub(Tags.getValue(vehicle_object.vehicle.tags, "vehicle_type", true), "wep_", "")
				if vehicle_type == VEHICLE.TYPE.BOAT then
					movement_speed = tonumber(Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed")) or VEHICLE.SPEED.BOAT
				elseif vehicle_type == VEHICLE.TYPE.PLANE then
					movement_speed = tonumber(Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed")) or VEHICLE.SPEED.PLANE
				elseif vehicle_type == VEHICLE.TYPE.HELI then
					movement_speed = tonumber(Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed")) or VEHICLE.SPEED.HELI
				elseif vehicle_type == VEHICLE.TYPE.LAND then
					movement_speed = tonumber(Tags.getValue(vehicle_object.vehicle.tags, "road_speed_normal")) or tonumber(Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed")) or VEHICLE.SPEED.LAND
				end

				transport_vehicle[vehicle_index].movement_speed = movement_speed
			end
		end

		local occupier_multiplications = {
			ai = 1,
			neutral = 3,
			player = 500
		}

		local paths = {}

		-- get the first path for all islands
		for island_index, island in pairs(g_savedata.islands) do
			if island.index ~= origin_island.index then -- makes sure its not the origin island

				local distance = Cargo.getIslandDistance(origin_island, island)

				-- calculate the occupier multiplications
				for transport_type, transport_distance in pairs(distance) do
					-- if the distance is not nil
					if transport_distance then
						distance[transport_type] = transport_distance * occupier_multiplications[island.faction]
					end
				end

				paths[island_index] = { island = island, distance = distance }
			end
		end

		-- check it to the ai's main base
		if origin_island.index ~= g_savedata.ai_base_island.index then

			local distance = Cargo.getIslandDistance(origin_island, g_savedata.ai_base_island)

			-- calculate the occupier multiplications
			for transport_type, transport_distance in pairs(distance) do
				-- if the distance is not nil
				if transport_distance then
					distance[transport_type] = transport_distance * occupier_multiplications[ISLAND.FACTION.AI]
				end
			end

			paths[g_savedata.ai_base_island.index] = { 
				island = g_savedata.ai_base_island, 
				distance = distance
			}

		end


		-- get the second path for all islands
		for first_path_island_index, first_path_island in pairs(paths) do
			for island_index, island in pairs(g_savedata.islands) do
				-- makes sure the island we are at is not the destination island, and that we are not trying to go to the island we are at
				if first_path_island.island.index ~= dest_island.index and island_index ~= first_path_island_index then

					local distance = Cargo.getIslandDistance(first_path_island.island, island)

					-- calculate the occupier multiplications
					for transport_type, transport_distance in pairs(distance) do
						-- if the distance is not nil
						if transport_distance then
							distance[transport_type] = transport_distance * occupier_multiplications[island.faction]
						end
					end

					paths[first_path_island_index][island_index] = { island = island, distance = distance }
				end
			end
		end

		-- get the third path for all islands (to destination island)
		for first_path_island_index, first_path_island in pairs(paths) do
			for second_path_island_index, second_path_island in pairs(paths[first_path_island_index]) do
				if second_path_island.island and second_path_island.island.index ~= dest_island.index and dest_island.index ~= first_path_island_index and dest_island.index ~= second_path_island_index then
					
					local distance = Cargo.getIslandDistance(second_path_island.island, dest_island)

					-- calculate the occupier multiplications
					for transport_type, transport_distance in pairs(distance) do
						-- if the distance is not nil
						if transport_distance then
							distance[transport_type] = transport_distance * occupier_multiplications[dest_island.faction]
						end
					end

					paths[first_path_island_index][second_path_island_index][dest_island.index] = { island = dest_island, distance = distance }
				end 
			end
		end

		local total_travel_time = {}

		-- get the total travel times for all the routes
		for first_path_island_index, first_path_island in pairs(paths) do
			--
			-- get the travel time from the origin island to the next one for each vehicle type
			--
			if first_path_island.distance then

				-- create the table with the indexes if it does not yet exist
				if not total_travel_time[first_path_island_index] then
					total_travel_time[first_path_island_index] = {
						heli = 0,
						boat = 0,
						plane = 0,
						land = 0
					}
				end

				if first_path_island.distance.air then
					if transport_vehicle.heli.name ~= "none" and transport_vehicle.heli.name ~= "unknown" then
						if Tags.has(first_path_island.island.tags, "can_spawn=heli") and Tags.has(origin_island.tags, "can_spawn=heli") then
							--
							total_travel_time[first_path_island_index].heli = 
							(total_travel_time[first_path_island_index].heli or 0) + 
							(first_path_island.distance.air/transport_vehicle.heli.movement_speed)
							--
						end
					end
					if transport_vehicle.plane.name ~= "none" and transport_vehicle.plane.name ~= "unknown" then
						if Tags.has(first_path_island.island.tags, "can_spawn=plane") and Tags.has(origin_island.tags, "can_spawn=plane") then
							--
							total_travel_time[first_path_island_index].plane = 
							(total_travel_time[first_path_island_index].plane or 0) + 
							(first_path_island.distance.air/transport_vehicle.plane.movement_speed)
							--
						end
					end
				end
				if first_path_island.distance.land then
					if transport_vehicle.land.name ~= "none" and transport_vehicle.land.name ~= "unknown" then
						if Tags.has(origin_island.tags, "can_spawn=land") then
							--
							total_travel_time[first_path_island_index].land = 
							(total_travel_time[first_path_island_index].land or 0) + 
							(first_path_island.distance.land/transport_vehicle.land.movement_speed)
							--
						end
					end
				end
				if first_path_island.distance.sea then
					if transport_vehicle.sea.name ~= "none" and transport_vehicle.sea.name ~= "unknown" then
						--
						total_travel_time[first_path_island_index].sea = 
						(total_travel_time[first_path_island_index].sea or 0) + 
						(first_path_island.distance.sea/transport_vehicle.sea.movement_speed)
						--
					end
				end

				-- second path islands
				if first_path_island_index ~= dest_island.index then
					for second_path_island_index, second_path_island in pairs(paths[first_path_island_index]) do
						--
						-- get the travel time from the first island to the next one for each vehicle type
						--
						if second_path_island.distance then
							
							-- create the table with the indexes if it does not yet exist
							if not total_travel_time[first_path_island_index][second_path_island_index] then
								total_travel_time[first_path_island_index][second_path_island_index] = {
									heli = 0,
									boat = 0,
									plane = 0,
									land = 0
								}
							end

							if second_path_island.distance.air then
								if transport_vehicle.heli.name ~= "none" and transport_vehicle.heli.name ~= "unknown" then
									if Tags.has(second_path_island.island.tags, "can_spawn=heli") and Tags.has(first_path_island.island.tags, "can_spawn=heli") then
										--
										total_travel_time[first_path_island_index][second_path_island_index].heli = 
										(total_travel_time[first_path_island_index].heli or 0) + 
										(second_path_island.distance.air/transport_vehicle.heli.movement_speed)
										--
									end
								end
								if transport_vehicle.plane.name ~= "none" and transport_vehicle.plane.name ~= "unknown" then
									if Tags.has(second_path_island.island.tags, "can_spawn=plane") and Tags.has(first_path_island.island.tags, "can_spawn=plane") then
										--
										total_travel_time[first_path_island_index][second_path_island_index].plane = 
										(total_travel_time[first_path_island_index].plane or 0) + 
										(second_path_island.distance.air/transport_vehicle.plane.movement_speed)
										--
									end
								end
							end
							if second_path_island.distance.land then
								if transport_vehicle.land.name ~= "none" and transport_vehicle.land.name ~= "unknown" then
									if Tags.has(first_path_island.island.tags, "can_spawn=land") then
										--
										total_travel_time[first_path_island_index][second_path_island_index].land = 
										(total_travel_time[first_path_island_index].land or 0) + 
										(second_path_island.distance.land/transport_vehicle.land.movement_speed)
										--
									end
								end
							end
							if second_path_island.distance.sea then
								if transport_vehicle.sea.name ~= "none" and transport_vehicle.sea.name ~= "unknown" then
									--
									total_travel_time[first_path_island_index][second_path_island_index].sea = 
									(total_travel_time[first_path_island_index].sea or 0) + 
									(second_path_island.distance.sea/transport_vehicle.sea.movement_speed)
									--
								end
							end
							if second_path_island_index ~= dest_island.index then
								for third_path_island_index, third_path_island in pairs(paths[first_path_island_index][second_path_island_index]) do
									--
									-- get the travel time from the second island to the destination for each vehicle type
									--

									-- create the table with the indexes if it does not yet exist
									if not total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index] then
										total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index] = {
											heli = 0,
											boat = 0,
											plane = 0,
											land = 0
										}
									end

									if third_path_island.distance then
										if third_path_island.distance.air then
											if transport_vehicle.heli.name ~= "none" and transport_vehicle.heli.name ~= "unknown" then
												if Tags.has(third_path_island.island.tags, "can_spawn=heli") and Tags.has(second_path_island.island.tags, "can_spawn=heli") then
													--
													total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index].heli = 
													(total_travel_time[first_path_island_index][second_path_island_index].heli or 0) + 
													(third_path_island.distance.air/transport_vehicle.heli.movement_speed)
													--
												end
											end
											if transport_vehicle.plane.name ~= "none" and transport_vehicle.plane.name ~= "unknown" then
												if Tags.has(third_path_island.island.tags, "can_spawn=plane") and Tags.has(second_path_island.island.tags, "can_spawn=plane") then
													--
													total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index].plane = 
													(total_travel_time[first_path_island_index][second_path_island_index].plane or 0) + 
													(third_path_island.distance.air/transport_vehicle.plane.movement_speed)
													--
												end
											end
										end
										if third_path_island.distance.land then
											if transport_vehicle.land.name ~= "none" and transport_vehicle.land.name ~= "unknown" then
												if Tags.has(second_path_island.island.tags, "can_spawn=land") then
													--
													total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index].land = 
													(total_travel_time[first_path_island_index][second_path_island_index].land or 0) + 
													(third_path_island.distance.land/transport_vehicle.land.movement_speed)
													--
												end
											end
										end
										if third_path_island.distance.sea then
											if transport_vehicle.sea.name ~= "none" and transport_vehicle.sea.name ~= "unknown" then
												--
												total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index].sea = 
												(total_travel_time[first_path_island_index][second_path_island_index].sea or 0) + 
												(third_path_island.distance.sea/transport_vehicle.sea.movement_speed)
												--
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
		
		------
		-- get the best route from all of the routes we've gotten
		------

		local best_route_time = time.day

		for first_path_island_index, first_path_island_travel_time in pairs(total_travel_time) do
			if type(first_path_island_travel_time) ~= "table" then
				goto break_first_island
			end

			local first_route_time = time.day
			local first_route = {}
			for transport_type, path_travel_time in pairs(first_path_island_travel_time) do
				if type(path_travel_time) == "number" and path_travel_time ~= 0 then
					if path_travel_time < first_route_time and path_travel_time < best_route_time then
						first_route_time = path_travel_time
						first_route = {
							island_index = first_path_island_index, 
							transport_method = transport_vehicle[transport_type], 
							transport_type = transport_type
						}
					end
				end
			end

			if first_route_time > best_route_time then
				goto break_first_island
			end

			if first_path_island_index == dest_island.index then
				--? currently this is the best route we know of
				best_route_time = first_route_time
				best_route = {
					[1] = first_route
				}
			else
				for second_path_island_index, second_path_island_travel_time in pairs(total_travel_time[first_path_island_index]) do
					if type(second_path_island_travel_time) ~= "table" then
						goto break_second_island
					end

					local second_route_time = time.day
					local second_route = {}
					for transport_type, path_travel_time in pairs(second_path_island_travel_time) do
						if type(path_travel_time) == "number" and path_travel_time ~= 0 then
							if path_travel_time < second_route_time and path_travel_time + first_route_time < best_route_time then
								second_route_time = path_travel_time
								second_route = {
									island_index = second_path_island_index, 
									transport_method = transport_vehicle[transport_type], 
									transport_type = transport_type
								}
							end
						end
					end

					if second_route_time + first_route_time > best_route_time then
						goto break_second_island
					end

					if second_path_island_index == dest_island.index then
						--? currently this is the best route we know of
						best_route_time = second_route_time + first_route_time
						best_route = {
							[1] = first_route,
							[2] = second_route
						}
					else
						for third_path_island_index, third_path_island_travel_time in pairs(total_travel_time[first_path_island_index][second_path_island_index]) do
							if type(third_path_island_travel_time) ~= "table" then
								goto break_third_island
							end

							local third_route_time = time.day
							local third_route = {}
							for transport_type, path_travel_time in pairs(third_path_island_travel_time) do
								if type(path_travel_time) == "number" and path_travel_time ~= 0 then
									if path_travel_time < third_route_time and path_travel_time + first_route_time + second_route_time < best_route_time then
										third_route_time = path_travel_time
										third_route = {
											island_index = third_path_island_index, 
											transport_method = transport_vehicle[transport_type], 
											transport_type = transport_type
										}
									end
								end
							end

							if third_route_time + second_route_time + first_route_time > best_route_time then
								goto break_third_island
							end

							best_route_time = third_route_time + second_route_time + first_route_time
							best_route = {
								[1] = first_route,
								[2] = second_route,
								[3] = third_route
							}

							::break_third_island::
						end
					end
					::break_second_island::
				end
			end
			::break_first_island::
		end

		------
		-- write to cache
		------
		Cache.write("cargo.best_routes["..first_cache_index.."]["..second_cache_index.."]["..transport_vehicle.heli.name.."]["..transport_vehicle.land.name.."]["..transport_vehicle.plane.name.."]["..transport_vehicle.sea.name.."]", best_route)
	end
	d.print("Calculated Best Route! Time taken: "..millisecondsSince(start_time).."ms", true, 0)
	return best_route
end

---@param vehicle_type string the type of vehicle, such as air, boat or land
---@return PREFAB_DATA|nil vehicle_prefab the vehicle to spawn
function Cargo.getTransportVehicle(vehicle_type)
	local prefabs_data = sm.spawn(true, "cargo", vehicle_type)
	if not prefabs_data then
		d.print("(Cargo.getTransportVehicle) prefabs_data is nil! vehicle_type: "..tostring(vehicle_type), true, 1)
		return
	else
		local prefab_data = prefabs_data.variations.normal
		if not prefab_data then
			for _, variation_prefab_data in pairs(prefabs_data) do
				prefab_data = variation_prefab_data
				break
			end
		end

		prefab_data[1].name = prefab_data[1].location_data.name

		return prefab_data[1]
	end
	return prefabs_data
end

---@param island1 ISLAND|AI_ISLAND|PLAYER_ISLAND the first island you want to get the distance from
---@param island2 ISLAND|AI_ISLAND|PLAYER_ISLAND the second island you want to get the distance to
---@return table distance the distance between the first island and the second island | distance.land | distance.sea | distance.air
function Cargo.getIslandDistance(island1, island2)

	local first_cache_index = island2.index
	local second_cache_index = island1.index

	if island1.index > island2.index then
		first_cache_index = island1.index
		second_cache_index = island2.index
	end
	local distance = {
		land = nil,
		sea = nil,
		air = nil
	}

	------
	-- get distance for air vehicles
	------
	--d.print("island1.name: "..island1.name, true, 0)
	--d.print("island2.name: "..island2.name, true, 0)
	if Tags.has(island1.tags, "can_spawn=plane") and Tags.has(island2.tags, "can_spawn=plane") or Tags.has(island1.tags, "can_spawn=heli") and Tags.has(island2.tags, "can_spawn=heli") then
		if Cache.exists("cargo.island_distances.air["..first_cache_index.."]["..second_cache_index.."]") then
			
			-- pull from cache

			distance.air = Cache.read("cargo.island_distances.air["..first_cache_index.."]["..second_cache_index.."]")
		else
			
			-- calculate the distance

			distance.air = m.xzDistance(island1.transform, island2.transform)
			
			-- write to cache

			Cache.write("cargo.island_distances.air["..first_cache_index.."]["..second_cache_index.."]", distance.air)
		end
	end

	------
	-- get distance for sea vehicles
	------
	if Tags.has(island1.tags, "can_spawn=boat") and Tags.has(island2.tags, "can_spawn=boat") then
		if Cache.exists("cargo.island_distances.sea["..first_cache_index.."]["..second_cache_index.."]") then
			
			-- pull from cache
			distance.sea =  Cache.read("cargo.island_distances.sea["..first_cache_index.."]["..second_cache_index.."]")
		else
			
			-- calculate the distance
			
			distance.sea = 0
			local ocean1_transform = s.getOceanTransform(island1.transform, 0, 500)
			local ocean2_transform = s.getOceanTransform(island2.transform, 0, 500)
			if table.noneNil(true, "cargo_distance_sea", ocean1_transform, ocean2_transform) then
				local paths = s.pathfind(ocean1_transform, ocean2_transform, "ocean_path", "tight_area")
				for path_index, path in pairs(paths) do
					if path_index ~= #paths then
						distance.sea = distance.sea + (m.distance(m.translation(path.x, 0, path.z), m.translation(paths[path_index + 1].x, 0, paths[path_index + 1].z)))
					end
				end
			end
			
			-- write to cache
			Cache.write("cargo.island_distances.sea["..first_cache_index.."]["..second_cache_index.."]", distance.sea)
		end
	end

	------
	-- get distance for land vehicles
	------
	if Tags.has(island1.tags, "can_spawn=land") then
		if Tags.getValue(island1.tags, "land_access", true) == Tags.getValue(island2.tags, "land_access", true) then
			if Cache.exists("cargo.island_distances.land["..first_cache_index.."]["..second_cache_index.."]") then
				
				-- pull from cache
				distance.land = Cache.read("cargo.island_distances.land["..first_cache_index.."]["..second_cache_index.."]")
			else
				
				-- calculate the distance

				-- makes sure that theres at least 1 land spawn
				if island1.zones.land and #island1.zones.land > 0 then
				
					distance.land = 0
					local start_transform = island1.zones.land[math.random(1, #island1.zones.land)].transform
					if table.noneNil(true, "cargo_distance_land", start_transform, island2.transform) then
						local paths = s.pathfind(start_transform, island2.transform, "land_path", "")
						for path_index, path in pairs(paths) do
							if path_index ~= #paths then
								distance.land = distance.land + (m.distance(m.translation(path.x, 0, path.z), m.translation(paths[path_index + 1].x, 0, paths[path_index + 1].z)))
							end
						end
					end
					
					-- write to cache
					Cache.write("cargo.island_distances.land["..first_cache_index.."]["..second_cache_index.."]", distance.land)
				end
			end
		end
	end
	return distance
end

---@param island ?ISLAND the island of which you want to reset the cargo of, leave blank for all islands
---@param cargo_type ?string the type of cargo you want to reset, leave blank for all types | "oil", "diesel" or "jet_fuel"
---@return boolean was_reset if it was reset
---@return string error if was_reset is false, it will return an error code, otherwise its "reset"
function Cargo.reset(island, cargo_type)
	if island then
		local is_main_base = (island.index == g_savedata.island.index) and true or false
		if not cargo_type then
			for cargo_type, _ in pairs(island.cargo) do
				if is_main_base then
					g_savedata.ai_base_island.cargo[cargo_type] = 0
				else
					g_savedata.islands[island.index].cargo[cargo_type] = 0
				end
			end
		else
			if is_main_base then
				if g_savedata.ai_base_island.cargo[cargo_type] then
					g_savedata.ai_base_island.cargo[cargo_type] = 0
				else
					return false, "(Cargo.reset) inputted cargo_type doesn't exist! cargo_type: "..cargo_type
				end
			else
				if g_savedata.ai_base_island.cargo[cargo_type] then
					g_savedata.islands[island.index].cargo[cargo_type] = 0
				else
					return false, "(Cargo.reset) inputted cargo_type doesn't exist! cargo_type: "..cargo_type
				end
			end
		end
	else
		if not cargo_type then
			for cargo_type, _ in pairs(g_savedata.ai_base_island.cargo) do
				g_savedata.ai_base_island.cargo[cargo_type] = 0
			end

			for island_index, island in pairs(g_savedata.islands) do
				for cargo_type, _ in pairs(island.cargo) do
					g_savedata.islands[island_index].cargo[cargo_type] = 0
				end
			end
		else
			if g_savedata.ai_base_island.cargo[cargo_type] then
				g_savedata.ai_base_island.cargo[cargo_type] = 0
				for island_index, island in pairs(g_savedata.islands) do
					g_savedata.islands[island_index].cargo[cargo_type] = 0
				end
			else
				return false, "(Cargo.reset) inputted cargo_type doesn't exist! cargo_type: "..cargo_type
			end
		end
	end

	return true, "reset"
end