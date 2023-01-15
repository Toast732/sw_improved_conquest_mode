--[[


	Library Setup


]]

s = s or Server

-- required libraries
require("libraries.debugging")
require("libraries.tables")

-- library name
Characters = {}

-- shortened library name
c = Characters

--[[


	Variables
   

]]

Characters.valid_seats = { -- configure to select which are the valid seats, select which seat group.
	enemy_ai = {
		{
			name = "Driver",
			outfit_id = 5,
			is_interactable = true,
			is_ai = false,
			ai_state = 0
		},
		{
			name = "Captain",
			outfit_id = 5,
			is_interactable = true,
			is_ai = true,
			ai_state = 1
		},
		{
			name = "Pilot",
			outfit_id = 5,
			is_interactable = true,
			is_ai = true,
			ai_state = 1
		},
		{
			name = "Gunner %d+",
			outfit_id = 5,
			is_interactable = true,
			is_ai = true,
			ai_state = 1
		}
	}
}

--[[


	Classes


]]

---@class VALID_SEAT
---@field name string a lua pattern of the name of the valid seat
---@field outfit_id SWOutfitTypeEnum the outfit type the character will wear in that seat
---@field is_interactable boolean if the character is interactable
---@field is_ai boolean if the character has AI to use seat controls
---@field ai_state integer the state of the AI

--[[


	Functions         


]]

function Characters.overrides()

	-- populate g_savedata with the table we will be using, 
	Tables.tabulate(g_savedata, "libraries", "characters", "characters_to_seat")

	-- onObjectLoad override
	local old_onObjectLoad = onObjectLoad or function() end
	function onObjectLoad(object_id)
		if g_savedata.libraries.characters.characters_to_seat[object_id] then
			Characters.setIntoSeat(object_id)
		end

		old_onObjectLoad(object_id)
	end

	-- onCharacterSit override
	local old_onCharacterSit = onCharacterSit or function() end
	function onCharacterSit(object_id, vehicle_id, seat_name)
		if g_savedata.libraries.characters.characters_to_seat[object_id] then
			g_savedata.libraries.characters.characters_to_seat[object_id] = nil
			d.print(("(Characters.onCharacterSit) Successfully set object %i into seat %s on vehicle %i"):format(object_id, seat_name, vehicle_id), true, 0)

			if onCharacterPrepared then
				onCharacterPrepared(object_id, vehicle_id, seat_name)
			end
		end

		old_onCharacterSit(object_id, vehicle_id, seat_name)
	end
end

function Characters.setIntoSeat(object_id)
	local seat_char_data = g_savedata.libraries.characters.characters_to_seat[object_id]

	local seat_pos = seat_char_data.seat_data.pos

	s.setCharacterSeated(object_id, seat_char_data.vehicle_id, seat_pos.x, seat_pos.y, seat_pos.z)

	s.setCharacterData(object_id, s.getCharacterData(object_id).hp, seat_char_data.char_config.is_interactable, seat_char_data.char_config.is_ai)
	s.setAIState(object_id, seat_char_data.char_config.ai_state)
	s.setAITargetVehicle(object_id, nil)
end

--# spawns the characters for all of the valid seats on the vehicle, and will later add them to the 
---@param vehicle_id integer the vehicle to spawn the characters for, the vehicle must be loaded in or previously been loaded in.
---@param valid_seats table<integer, VALID_SEAT> the valid seat names along with the outfit_id to use for them, set groups up in characters.lua in the valid_seats variable and then use them here
function Characters.createAndSetCharactersIntoSeat(vehicle_id, valid_seats)
	local vehicle_data, is_success = s.getVehicleData(vehicle_id)

	-- failed to get vehicle data
	if not is_success then
		d.print("(Characters.setupVehicle) failed to get vehicle data for vehicle_id: "..vehicle_id, true, 1)
		return {}, false
	end

	-- vehicle has never loaded
	if not vehicle_data.components then
		d.print(("(Characters.setupVehicle) vehicle_id: %i has not been loaded yet!"):format(vehicle_id), true, 1)
		return {}, false
	end

	-- vehicle has no seats
	if not vehicle_data.components.seats[1] then
		d.print(("(Characters.setupVehicle) vehicle_id: %i has no seats!"):format(vehicle_id), true, 1)
		return {}, false
	end

	-- make sure it's overriding the callback functions
	Characters.overrides()

	local characters = {}

	-- go through all valid seat types, and for each, go through all of the seats, this way the output table is sorted in the order the valid seats table is ordered.
	for valid_seat_id = 1, #valid_seats do
		local valid_seat = valid_seats[valid_seat_id]
		for seat_id = 1, #vehicle_data.components.seats do
			local seat_data = vehicle_data.components.seats[seat_id]
			if string.find(seat_data.name, valid_seat.name) then
				-- this is a valid seat
				local object_id, is_success = s.spawnCharacter(vehicle_data.transform, valid_seat.outfit_id)
				if not is_success then
					d.print(("(Characters.setupVehicle) failed to spawn character for vehicle_id: %i!"):format(vehicle_id), true, 1)
				else 
					s.setCharacterData(object_id, s.getCharacterData(object_id).hp, valid_seat.is_interactable, valid_seat.is_ai)
					s.setAIState(object_id, valid_seat.ai_state)
					s.setAITargetVehicle(object_id, nil)
					table.insert(characters, object_id)
					g_savedata.libraries.characters.characters_to_seat[object_id] = {
						seat_data = seat_data,
						vehicle_id = vehicle_id,
						char_config = valid_seat
					}
				end
			end
		end
	end 

	return characters, true
end