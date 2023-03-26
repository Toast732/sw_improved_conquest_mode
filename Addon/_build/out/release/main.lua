 
--? Copyright 2022 Liam Matthews

--? Licensed under the Apache License, Version 2.0 (the "License");
--? you may not use this file except in compliance with the License.
--? You may obtain a copy of the License at

--?		http://www.apache.org/licenses/LICENSE-2.0

--? Unless required by applicable law or agreed to in writing, software
--? distributed under the License is distributed on an "AS IS" BASIS,
--? WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--? See the License for the specific language governing permissions and
--? limitations under the License.

--! (If gotten from Steam Workshop) LICENSE is in vehicle_0.xml
--! (If gotten from anywhere else) LICENSE is in LICENSE and vehicle_0.xml

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: https://steamcommunity.com/id/Toastery7/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

ADDON_VERSION = "(0.3.2.7)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "ICM"

-- shortened library names
m = matrix
s = server

ISLAND = {
	FACTION = {
		NEUTRAL = "neutral",
		AI = "ai",
		PLAYER = "player"
	}
}

VEHICLE = {
	STATE = {
		PATHING = "pathing", -- follow path
		HOLDING = "holding", -- hold position
		STATIONARY = "stationary" -- used for turrets
	},
	TYPE = {
		BOAT = "boat",
		LAND = "land",
		PLANE = "plane",
		HELI = "heli",
		TURRET = "turret"
	},
	SPEED = {
		BOAT = 8,
		LAND = 10,
		PLANE = 60,
		HELI = 40,
		MULTIPLIERS = {
			LAND = {
				AGGRESSIVE = 1.25,
				NORMAL = 0.9,
				ROAD = 1,
				BRIDGE = 0.7,
				OFFROAD = 0.75
			}
		}
	}
}

CONVOY = {
	MOVING = "moving",
	WAITING = "waiting"
}

debug_types = {
	[-1] = "all",
	[0] = "chat",
	"error",
	"profiler",
	"map",
	"graph_node",
	"driving",
	"vehicle",
	"function",
	"traceback"
}

time = { -- the time unit in ticks, irl time, not in game
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

MAX_SQUAD_SIZE = 3
MIN_ATTACKING_SQUADS = 2
MAX_ATTACKING_SQUADS = 3

TARGET_VISIBILITY_VISIBLE = "visible"
TARGET_VISIBILITY_INVESTIGATE = "investigate"

REWARD = "reward"
PUNISH = "punish"

RESUPPLY_SQUAD_INDEX = 1

CAPTURE_RADIUS = 1500
RESUPPLY_RADIUS = 200
ISLAND_CAPTURE_AMOUNT_PER_SECOND = 1

WAYPOINT_CONSUME_DISTANCE = 100

explosion_depths = {
	plane = -4,
	land = -4,
	heli = -4,
	boat = -17,
	turret = -999
}

DEFAULT_SPAWNING_DISTANCE = 10 -- the fallback option for how far a vehicle must be away from another in order to not collide, highly reccomended to set tag

CRUISE_HEIGHT = 300
built_locations = {}
flag_prefab = nil
is_dlc_weapons = false
g_debug_speed_multiplier = 1
g_air_vehicles_kamikaze = false

debug_mode_blinker = false -- blinks between showing the vehicle type icon and the vehicle command icon on the map

-- please note: this is not machine learning, this works by making a
-- vehicle spawn less or more often, depending on the damage it did
-- compared to the damage it has taken
ai_training = {
	punishments = {
		-0.1,
		-0.2,
		-0.3,
		-0.5,
		-0.7
	},
	rewards = {
		0.1,
		0.2,
		0.3,
		0.5,
		1
	}
}

scout_requirement = time.minute*40

capture_speeds = {
	1,
	1.5,
	1.75
}

g_holding_pattern = {
	{
		x=500, 
		z=500
	},
	{
		x=500, 
		z=-500
	},
	{
		x=-500, 
		z=-500
	},
	{
		x=-500, 
		z=500
	}
}

g_is_air_ready = true
g_is_boats_ready = false
g_count_squads = 0
g_count_attack = 0
g_count_patrol = 0

SQUAD = {
	COMMAND = {
		NONE = "no_command", -- no command
		ATTACK = "attack", -- attack island
		DEFEND = "defend", -- defend island
		INVESTIGATE = "investigate", -- investigate position (player left sight)
		ENGAGE = "engage", -- attack player
		PATROL = "patrol", -- patrol around island
		STAGE = "stage", -- stage attack against island
		RESUPPLY = "resupply", -- resupply ammo
		TURRET = "turret", -- this is a turret
		RETREAT = "retreat", -- not implemented yet, used for retreating
		SCOUT = "scout", -- scout island
		CARGO = "cargo" -- cargo vehicle
	}
}

g_savedata = {
	ai_base_island = nil,
	player_base_island = nil,
	islands = {},
	loaded_islands = {}, -- islands which are loaded
	ai_army = { 
		squadrons = { 
			[RESUPPLY_SQUAD_INDEX] = { 
				command = SQUAD.COMMAND.RESUPPLY, 
				vehicle_type = "", 
				role = "", 
				vehicles = {}, 
				target_island = nil 
			}
		},
		squad_vehicles = {} -- stores which squad the vehicles are assigned to, indexed via the vehicle's id, with this we can get the vehicle we want the data for without needing to check every single enemy ai vehicle
	},
	player_vehicles = {},
	cargo_vehicles = {},
	constructable_vehicles = {},
	seat_states = {},
	vehicle_list = {},
	prefabs = {}, 
	is_attack = false,
	info = {
		version_history = {
			{
				version = ADDON_VERSION,
				ticks_played = 0,
				backup_g_savedata = {}
			}
		},
		addons = {
			default_conquest_mode = false,
			ai_paths = false
		},
		mods = {
			NSO = false
		}
	},
	tick_counter = 0,
	sweep_and_prune = { -- used for sweep and prune, capture detection
		flags = { -- only updates order in oncreate and is_world_create
			x = {},
			z = {}
		},
		ai_pairs = {}
	},
	ai_history = {
		has_defended = 0, -- logs the time in ticks the player attacked at
		defended_charge = 0, -- the charge for it to detect the player is attacking, kinda like a capacitor
		scout_death = -1, -- saves the time the scout plane was destroyed, allows the players some time between each time the scout comes
	},
	ai_knowledge = {
		last_seen_positions = {}, -- saves the last spot it saw each player, and at which time (tick counter)
		scout = {}, -- the scout progress of each island
	},
	player_data = {},
	cache = {
		cargo = {
			island_distances = {
				sea = {},
				land = {},
				air = {}
			},
			best_routes = {}
		}
	},
	cache_stats = {
		reads = 0,
		writes = 0,
		failed_writes = 0,
		resets = 0
	},
	profiler = {
		working = {},
		total = {},
		display = {
			average = {},
			max = {},
			current = {}
		},
		ui_id = nil
	},
	debug = {
		chat = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		error = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		profiler = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		map = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		graph_node = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		driving = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		vehicle = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		["function"] = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true
		},
		traceback = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true,
			stack = {},
			stack_size = 0,
			funct_names = {},
			funct_count = 0
		}
	},
	tick_extensions = {
		cargo_vehicle_spawn = 0
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	}
}

-- libraries
-- required libraries
-- required libraries
--[[


	Library Setup


]]

-- required libraries

-- library name
AddonCommunication = {}

-- shortened library name
ac = AddonCommunication

--[[


	Variables
   

]]

replies_awaiting = {}

--[[


	Classes


]]

--[[


	Functions         


]]

function AddonCommunication.executeOnReply(short_addon_name, message, port, execute_function, count, timeout)
	short_addon_name = short_addon_name or SHORT_ADDON_NAME-- default to this addon's short name
	if not message then
		d.print("(AddonCommunication.executeOnReply) message was left blank!", true, 1)
		return
	end

	port = port or 0

	if not execute_function then
		d.print("(AddonCommunication.executeOnReply) execute_function was left blank!", true, 1)
		return
	end

	count = count or 1

	timeout = timeout or -1

	local expiry = -1
	if timeout ~= -1 then
		expiry = s.getTimeMillisec() + timeout*60
	end

	table.insert(replies_awaiting, {
		short_addon_name = short_addon_name,
		message = message,
		port = port,
		execute_function = execute_function,
		count = count,
		expiry = expiry
	})
end

function AddonCommunication.tick()
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this reply has expired
		if reply.expiry ~= -1 and s.getTimeMillisec() > reply.expiry then
			-- it has expired
			d.print(("A function awaiting a reply of %s from %s has expired."):format(reply.message, reply.short_addon_name), true, 0)
			table.remove(replies_awaiting, reply_index)
		end
	end
end

function AddonCommunication.sendCommunication(message, port)
	if not message then
		d.print("(AddonCommunication.sendCommunication) message was left blank!", true, 1)
		return
	end

	port = port or 0

	-- add this addon's short name to the list
	local prepared_message = ("%s:%s"):format(SHORT_ADDON_NAME, message)

	-- send the message
	s.httpGet(port, prepared_message)
end

function httpReply(port, message)
	-- check if we're waiting to execute a function from this reply
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this is the same port
		if reply.port ~= port then
			goto httpReply_continue_reply
		end

		-- check if the message content is the one we're looking for
		if ("%s:%s"):format(reply.short_addon_name, reply.message) ~= message then
			goto httpReply_continue_reply
		end

		-- this is the one we're looking for!

		-- remove 1 from count
		reply.count = math.max(reply.count - 1, -1)

		-- execute the function
		reply:execute_function()

		-- if count == 0 then remove this from the replies awaiting
		if reply.count == 0 then
			table.remove(replies_awaiting, reply_index)
		end

		break

		::httpReply_continue_reply::
	end
end
-- required libraries
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return number distance the xz distance between the two matrices
function matrix.xzDistance(matrix1, matrix2) -- returns the euclidean distance between two matrixes, ignoring the y axis
	local rx = matrix2[13] - matrix1[13] -- relative x
	local rz = matrix2[15] - matrix1[15] -- relative z
	return math.sqrt(rx*rx + rz*rz)
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = m.multiply(rot_matrix, m.rotationZ(-z))
	return math.atan(rot_matrix[7],rot_matrix[6]), math.atan(rot_matrix[9],rot_matrix[11]), z
end

---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return SWMatrix matrix the multiplied matrix
function matrix.multiplyXZ(matrix1, matrix2)
	local matrix3 = {table.unpack(matrix1)}
	matrix3[13] = matrix3[13] + matrix2[13]
	matrix3[15] = matrix3[15] + matrix2[15]
	return matrix3
end

--# returns the total velocity (m/s) between the two matrices
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@param ticks_between number the ticks between the two matrices
---@return number velocity the total velocity
function matrix.velocity(matrix1, matrix2, ticks_between)
	ticks_between = ticks_between or 1
	local rx = matrix2[13] - matrix1[13] -- relative x
	local ry = matrix2[14] - matrix1[14] -- relative y
	local rz = matrix2[15] - matrix1[15] -- relative z

	-- total velocity
	return math.sqrt(rx*rx+ry*ry+rz*rz) * 60/ticks_between
end

--# returns the acceleration, given 3 matrices. Each matrix must be the same ticks between eachother.
---@param matrix1 SWMatrix the most recent matrix
---@param matrix2 SWMatrix the second most recent matrix
---@param matrix3 SWMatrix the third most recent matrix
---@return number acceleration the acceleration in m/s
function matrix.acceleration(matrix1, matrix2, matrix3, ticks_between)
	local v1 = m.velocity(matrix1, matrix2, ticks_between) -- last change in velocity
	local v2 = m.velocity(matrix2, matrix3, ticks_between) -- change in velocity from ticks_between ago
	-- returns the acceleration
	return (v1-v2)/(ticks_between/60)
end


-- library name
Players = {}

-- shortened library name
pl = Players

---@param player_list Players[] the list of players to check
---@param target_pos Matrix the position that you want to check
---@param min_dist number the minimum distance between the player and the target position
---@param ignore_y boolean if you want to ignore the y level between the two or not
---@return boolean no_players_nearby returns true if theres no players which distance from the target_pos was less than the min_dist
function Players.noneNearby(player_list, target_pos, min_dist, ignore_y)
	local players_clear = true
	for player_index, player in pairs(player_list) do
		if ignore_y and m.xzDistance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		elseif not ignore_y and m.distance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		end
	end
	return players_clear
end

---@param peer_id integer the peer_id of the player you want to get the steam id of
---@return string steam_id the steam id of the player, nil if not found
function Players.getSteamID(peer_id)
	local player_list = s.getPlayers()
	for peer_index, peer in pairs(player_list) do
		if peer.id == peer_id then
			return tostring(peer.steam_id)
		end
	end
	d.print("(pl.getSteamID) unable to get steam_id for peer_id: "..peer_id, true, 1)
	return nil
end

---@param steam_id string the steam_id of the player you want to get the object ID of
---@return integer object_id the object ID of the player
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1)
		return nil
	end

	if not g_savedata.player_data[steam_id].object_id then
		g_savedata.player_data[steam_id].object_id = s.getPlayerCharacterID(g_savedata.player_data[steam_id].peer_id)
	end

	return g_savedata.player_data[steam_id].object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end
-- required libraries

--# check for if none of the inputted variables are nil
---@param print_error boolean if you want it to print an error if any are nil (if true, the second argument must be a name for debugging puposes)
---@param ... any variables to check
---@return boolean none_are_nil returns true of none of the variables are nil or false
function table.noneNil(print_error,...)
	local _ = table.pack(...)
	local none_nil = true
	for variable_index, variable in pairs(_) do
		if print_error and variable ~= _[1] or not print_error then
			if not none_nil then
				none_nil = false
				if print_error then
					d.print("(table.noneNil) a variable was nil! index: "..variable_index.." | from: ".._[1], true, 1)
				end
			end
		end
	end
	return none_nil
end

--# returns the number of elements in the table
---@param t table table to get the size of
---@return number count the size of the table
function table.length(t)
	if not t or type(t) ~= "table" then
		return 0 -- invalid input
	end

	local count = 0

	for _ in pairs(t) do -- goes through each element in the table
		count = count + 1 -- adds 1 to the count
	end

	return count -- returns number of elements
end

-- credit: woe | for this function
function table.tabulate(t,...)
	local _ = table.pack(...)
	t[_[1]] = t[_[1]] or {}
	if _.n>1 then
		table.tabulate(t[_[1]], table.unpack(_, 2))
	end
end

--# function that turns strings into a table (Warning: very picky)
--- @param S string a table in string form
--- @return table T the string turned into a.table
function table.fromString(S)
	local function stringToTable(string_as_table, start_index)
		local T = {}

		local variable = nil
		local str = ""

		local char_offset = 0

		start_index = start_index or 1

		for char_index = start_index, string_as_table:len() do
			char_index = char_index + char_offset

			-- if weve gone through the entire string, accounting for the offset
			if char_index > string_as_table:len() then
				return T, char_index - start_index
			end

			-- the current character to read
			local char = string_as_table:sub(char_index, char_index)

			-- if this is the opening of a table
			if char == "{" then
				local returned_table, chars_checked = stringToTable(string_as_table, char_index + 1)

				if not variable then
					table.insert(T, returned_table)
				else
					T[variable] = returned_table
				end

				char_offset = char_offset + (chars_checked or 0)

				variable = nil

			-- if this is the closing of a table, and a start of another
			elseif string_as_table:sub(char_index, char_index + 2) == "},{" then
				if variable then
					T[variable] = str
				end

				return T, char_index - start_index + 1

			-- if this is a closing of a table.
			elseif char == "}" then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				return T, char_index - start_index

			-- if we're recording the value to set the variable to
			elseif char == "=" then
				variable = str
				str = ""

			-- save the value of the variable
			elseif char == "," then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				str = ""
				variable = ""

			-- write this character if its not a quote
			elseif char ~= "\"" then
				str = str..char
			end
		end
	end

	return table.pack(stringToTable(S, 1))[1]
end

--- Returns the value at the path in _ENV
---@param path string the path we want to get the value at
---@return any value the value at the path, if it reached a nil value in the given path, it will return the value up to that point, and is_success will be false.
---@return boolean is_success if it successfully got the value at the path
function table.getValueAtPath(path)
	if type(path) ~= "string" then
		d.print(("path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return nil, false
	end

	local cur_path
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	if _ENV_NORMAL then
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end

	local cur_path_string = "_ENV"

	for index in string.gmatch(path, "([^%.]+)") do
		if not cur_path[index] then
			d.print(("%s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return cur_path, false
		end

		cur_path = cur_path[index]
	end

	return cur_path, true
end

--- Sets the value at the path in _ENV
---@param path string the path we want to set the value at
---@param set_value any the value we want to set the value of what the path is
---@return boolean is_success if it successfully got the value at the path
function table.setValueAtPath(path, set_value)
	if type(path) ~= "string" then
		d.print(("(table.setValueAtPath) path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return false
	end

	local cur_path = _ENV
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	--[[if _ENV_NORMAL then
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end]]

	local cur_path_string = "_ENV"

	local index_count = 0

	local last_index, got_count = string.countCharInstances(path, "%.")

	last_index = last_index + 1

	if not got_count then
		d.print(("(table.setValueAtPath) failed to get count! path: %s"):format(path))
		return false
	end
	
	for index in string.gmatch(path, "([^%.]+)") do
		index_count = index_count + 1

		if not cur_path[index] then
			d.print(("(table.setValueAtPath) %s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return false
		end

		if index_count == last_index then
			cur_path[index] = set_value

			return true
		end

		cur_path = cur_path[index]
	end

	d.print("(table.setValueAtPath) never reached end of path?", true, 1)
	return false
end

-- a table containing a bunch of functions for making a copy of tables, to best fit each scenario performance wise.
table.copy = {

	iShallow = function(t, __ENV)
		__ENV = __ENV or _ENV
		return {__ENV.table.unpack(t)}
	end,
	shallow = function(t, __ENV)
		__ENV = __ENV or _ENV

		local t_type = __ENV.type(t)

		local t_shallow

		if t_type == "table" then
			for key, value in __ENV.next, t, nil do
				t_shallow[key] = value
			end
		end

		return t_shallow or t
	end,
	deep = function(t, __ENV)

		__ENV = __ENV or _ENV

		local function deepCopy(T)
			local copy = {}
			if __ENV.type(T) == "table" then
				for key, value in __ENV.next, T, nil do
					copy[deepCopy(key)] = deepCopy(value)
				end
			else
				copy = T
			end
			return copy
		end
	
		return deepCopy(t)
	end
}
--[[


	Library Setup


]]

-- required libraries
--[[


	Library Setup


]]

-- required libraries
-- (none)

-- library name
-- (not applicable)

-- shortened library name
-- (not applicable)

--[[


	Variables
   

]]

-- pre-calculated pi*2
math.tau = math.pi*2
-- pre-calculated pi*0.5
math.half_pi = math.pi*0.5

--[[


	Classes


]]

--[[


	Functions         


]]


--- @param x number the number to check if is whole
--- @return boolean is_whole returns true if x is whole, false if not, nil if x is nil
function math.isWhole(x) -- returns wether x is a whole number or not
	return math.tointeger(x)
end

--- if a number is nil, it sets it to 0
--- @param x number the number to check if is nil
--- @return number x the number, or 0 if it was nil
function math.noNil(x)
	return x ~= x and 0 or x
end

--- @param x number the number to clamp
--- @param min number the minimum value
--- @param max number the maximum value
--- @return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return math.noNil(max<x and max or min>x and min or x)
end

--- @param min number the min number
--- @param max number the max number
function math.randomDecimals(min, max)
	return math.random()*(max-min)+min
end

--- Returns a number which is consistant if the params are all consistant
--- @param use_decimals boolean true for if you want decimals, false for whole numbers
--- @param seed number the seed for the random number generator
--- @param min number the min number
--- @param max number the max number
--- @return number seeded_number the random seeded number
function math.seededRandom(use_decimals, seed, min, max)
	local seed = seed or 1
	local min = min or 0
	local max = max or 1

	local seeded_number = 0

	-- generate a random seed
	math.randomseed(seed)

	-- generate a random number with decimals
	if use_decimals then
		seeded_number = math.randomDecimals(min, max)
	else -- generate a whole number
		seeded_number = math.random(math.floor(min), math.ceil(max))
	end

	-- make the random numbers no longer consistant with the seed
	math.randomseed(g_savedata.tick_counter)
	
	-- return the seeded number
	return seeded_number
end

---@param x number the number to wrap
---@param min number the minimum number to wrap around
---@param max number the maximum number to wrap around
---@return number x x wrapped between min and max
function math.wrap(x, min, max) -- wraps x around min and max
	return (x - min) % (max - min) + min
end

---@param t table a table of which you want a winner to be picked from, the index of the elements must be the name of the element, and the value must be a modifier (num) which when larger will increase the chances of it being chosen
---@return string win_name the name of the element which was picked at random
function math.randChance(t)
	local total_mod = 0
	for k, v in pairs(t) do
		total_mod = total_mod + v
	end
	local win_name = ""
	local win_val = 0
	for k, v in pairs(t) do
		local chance = math.randomDecimals(0, v / total_mod)
		-- d.print("chance: "..chance.." chance to beat: "..win_val.." k: "..k, true, 0)
		if chance > win_val then
			win_val = chance
			win_name = k
		end
	end
	return win_name
end


-- library name
Map = {}

-- shortened library name
-- (not applicable)

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

--# draws a search area within the specified radius at the coordinates provided
---@param x number the x coordinate of where the search area will be drawn around (required)
---@param z number the z coordinate of where the search area will be drawn around (required)
---@param radius number the radius of the search area (required)
---@param ui_id integer the ui_id of the search area (required)
---@param peer_id integer the peer_id of the player which you want to draw the search area for (defaults to -1)
---@param label string The text that appears when mousing over the icon. Appears like a title (defaults to "")
---@param hover_label string The text that appears when mousing over the icon. Appears like a subtitle or description (defaults to "")
---@param r integer 0-255, the red value of the search area (defaults to 255)
---@param g integer 0-255, the green value of the search area (defaults to 255)
---@param b integer 0-255, the blue value of the search area (defaults to 255)
---@param a integer 0-255, the alpha value of the search area (defaults to 255)
---@return number x the x coordinate of where the search area was drawn
---@return number z the z coordinate of where the search area was drawn
---@return boolean success if the search area was drawn
function Map.drawSearchArea(x, z, radius, ui_id, peer_id, label, hover_label, r, g, b, a)

	if not x then -- if the x position of the target was not provided
		d.print("(Map.drawSearchArea) x is nil!", true, 1)
		return nil, nil, false
	end

	if not z then -- if the z position of the target was not provided
		d.print("(Map.drawSearchArea) z is nil!", true, 1)
		return nil, nil, false
	end

	if not radius then -- if the radius of the search area was not provided
		d.print("(Map.drawSearchArea) radius is nil!", true, 1)
		return nil, nil, false
	end

	if not ui_id then -- if the ui_id was not provided
		d.print("(Map.drawSearchArea) ui_id is nil!", true, 1)
		return nil, nil, false
	end

	-- default values (if not specified)

	local peer_id = peer_id or -1 -- makes the peer_id default to -1 if not provided (-1 = everybody)

	local label = label or "" -- defaults the label to "" if it was not specified
	local hover_label = hover_label or "" -- defaults the hover_label to "" if it was not specified

	local r = r or 255 -- makes the red colour default to 255 if not provided
	local g = g or 255 -- makes the green colour default to 255 if not provided
	local b = b or 255 -- makes the blue colour default to 255 if not provided
	local a = a or 255 -- makes the alpha default to 255 if not provided

	local angle = math.random() * math.pi * 2 -- gets a random angle to put the search radius focus around
	local dist = math.sqrt(math.randomDecimals(0.1, 0.9)) * radius -- gets a random distance from the target to put the search radius at

	local x_pos = dist * math.sin(angle) + x -- uses the distance and angle to make the x pos of the search radius
	local z_pos = dist * math.cos(angle) + z -- uses the distance and angle to make the z pos of the search radius

	s.addMapObject(peer_id, ui_id, 0, 2, x_pos, z_pos, 0, 0, 0, 0, label, radius, hover_label, r, g, b, a) -- draws the search radius to the map

	return x_pos, z_pos, true -- returns the x pos and z pos of the drawn search radius, and returns true that it was drawn.
end

function Map.addMapCircle(peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines) -- credit to woe
	peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines = peer_id or -1, ui_id or 0, center_matrix or m.translation(0, 0, 0), radius or 500, width or 0.25, r or 255, g or 0, b or 0, a or 255, lines or 16
	local center_x, center_z = center_matrix[13], center_matrix[15]

	local angle_per_line = math.tau/lines

	local last_angle = 0

	for i = 1, lines + 1 do
		local new_angle = angle_per_line*i

		local x1, z1 = center_x+radius*math.cos(last_angle), center_z+radius*math.sin(last_angle)
		local x2, z2 = center_x+radius*math.cos(new_angle), center_z+radius*math.sin(new_angle)
		
		local start_matrix, end_matrix = m.translation(x1, 0, z1), m.translation(x2, 0, z2)
		s.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a)
		last_angle = new_angle
	end
end
---@param str string the string to make the first letter uppercase
---@return string|nil str the string with the first letter uppercase
function string.upperFirst(str)
	if type(str) == "string" then
		return (str:gsub("^%l", string.upper))
	end
	return nil
end

--- @param str string the string the make friendly
--- @param remove_spaces boolean? true for if you want to remove spaces, will also remove all underscores instead of replacing them with spaces
--- @param keep_caps boolean? if you want to keep the caps of the name, false will make all letters lowercase
--- @return string|nil friendly_string friendly string, nil if input_string was not a string
function string.friendly(str, remove_spaces, keep_caps) -- function that replaced underscores with spaces and makes it all lower case, useful for player commands so its not extremely picky

	if not str or type(str) ~= "string" then
		d.print("(string.friendly) str is not a string! type: "..tostring(type(str)).." provided str: "..tostring(str), true, 1)
		return nil
	end

	-- make all lowercase
	
	local friendly_string = not keep_caps and string.lower(str) or str

	-- replace all underscores with spaces
	friendly_string = string.gsub(friendly_string, "_", " ")

	-- if remove_spaces is true, remove all spaces
	if remove_spaces then
		friendly_string = string.gsub(friendly_string, " ", "")
	end

	return friendly_string
end

---@param vehicle_name string the name you want to remove the prefix of
---@param keep_caps boolean? if you want to keep the caps of the name, false will make all letters lowercase
---@return string vehicle_name the vehicle name without its vehicle type prefix
function string.removePrefix(vehicle_name, keep_caps)

	if not vehicle_name then
		d.print("(string.removePrefix) vehicle_name is nil!", true, 1)
		return vehicle_name
	end

	local vehicle_type_prefixes = {
		"BOAT %- ",
		"HELI %- ",
		"LAND %- ",
		"TURRET %- ",
		"PLANE %- "
	}

	-- replaces underscores with spaces
	local vehicle_name = string.gsub(vehicle_name, "_", " ")

	-- remove the vehicle type prefix from the entered vehicle name
	for _, prefix in ipairs(vehicle_type_prefixes) do
		vehicle_name = string.gsub(vehicle_name, prefix, "")
	end

	-- makes the string friendly
	vehicle_name = string.friendly(vehicle_name, false, keep_caps)

	if not vehicle_name then
		d.print("(string.removePrefix) string.friendly() failed, and now vehicle_name is nil!", true, 1)
		return ""
	end

	return vehicle_name
end

--- Returns a string in a format that looks like how the table would be written.
---@param t table the table you want to turn into a string
---@return string str the table but in string form.
function string.fromTable(t)

	if type(t) ~= "table" then
		d.print(("(string.fromTable) t is not a table! type of t: %s t: %s"):format(type(t), t), true, 1)
	end

	local function tableToString(T, S, ind)
		S = S or "{"
		ind = ind or "  "

		local table_length = table.length(T)
		local table_counter = 0

		for index, value in pairs(T) do

			table_counter = table_counter + 1
			if type(index) == "number" then
				S = ("%s\n%s[%s] = "):format(S, ind, tostring(index))
			elseif type(index) == "string" and tonumber(index) and math.isWhole(tonumber(index)) then
				S = ("%s\n%s\"%s\" = "):format(S, ind, index)
			else
				S = ("%s\n%s%s = "):format(S, ind, tostring(index))
			end

			if type(value) == "table" then
				S = ("%s{"):format(S)
				S = tableToString(value, S, ind.."  ")
			elseif type(value) == "string" then
				S = ("%s\"%s\""):format(S, tostring(value))
			else
				S = ("%s%s"):format(S, tostring(value))
			end

			S = ("%s%s"):format(S, table_counter == table_length and "" or ",")
		end

		S = ("%s\n%s}"):format(S, string.gsub(ind, "  ", "", 1))

		return S
	end

	return tableToString(t)
end

--- returns the number of instances of that character in the string
---@param str string the string we are wanting to check
---@param char any the character(s) we are wanting to count for in str, note that this is as a lua pattern
---@return number count the number of instances of char, if there was an error, count will be 0, and is_success will be false
---@return boolean is_success if we successfully got the number of instances of the character
function string.countCharInstances(str, char)

	if type(str) ~= "string" then
		d.print(("(string.countCharInstances) str is not a string! type of str: %s str: %s"):format(type(str), str), true, 1)
		return 0, false
	end

	char = tostring(char)

	local _, count = string.gsub(str, char, "")

	return count, true
end

-- library name
Debugging = {}

-- shortened library name
d = Debugging

--[[


	Variables


]]

--[[


	Classes


]]

--[[


	Functions

]]

---@param message string the message you want to print
---@param requires_debug boolean? if it requires <debug_type> debug to be enabled
---@param debug_id integer? the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id integer? if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_id, peer_id) -- "glorious debug function" - senty, 2022
	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_id, peer_id) or requires_debug and debug_id == 2 and d.getDebug(0, peer_id) or debug_id == 1 and d.getDebug(0, peer_id) then
		local suffix = debug_id == 1 and " Error:" or debug_id == 2 and " Profiler:" or debug_id == 7 and " Function:" or debug_id == 8 and " Traceback:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log(string.format("SW %s %s | %s", SHORT_ADDON_NAME, suffix, string.gsub(message, "\n", " \\n ")))
			else
				debug.log(string.format("SW %s %s | (d.print) message is nil!", SHORT_ADDON_NAME, suffix))
			end
		end
		
		if type(message) == "table" then -- print the message as a table.
			d.printTable(message, requires_debug, debug_id, peer_id)

		elseif requires_debug then -- if this message requires debug to be enabled
			if pl.isPlayer(peer_id) and peer_id then -- if its being sent to a specific peer id
				if d.getDebug(debug_id, peer_id) then -- if this peer has debug enabled
					server.announce(prefix, message, peer_id) -- send it to them
				end
			else
				for _, peer in ipairs(server.getPlayers()) do -- if this is being sent to all players with the debug enabled
					if d.getDebug(debug_id, peer.id) or debug_id == 2 and d.getDebug(0, peer.id) or debug_id == 1 and d.getDebug(0, peer.id) then -- if this player has debug enabled
						server.announce(prefix, message, peer.id) -- send the message to them
					end
				end
			end
		else
			server.announce(prefix, message, peer_id or -1)
		end
	end
end

function Debugging.debugTypeFromID(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

function Debugging.debugIDFromType(debug_type)

	debug_type = string.friendly(debug_type)

	for debug_id, d_type in pairs(debug_types) do
		if debug_type == d_type then
			return debug_id
		end
	end
end

--# prints all data which is in a table (use d.print instead of this)
---@param T table the table of which you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_id integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler)
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.printTable(T, requires_debug, debug_id, peer_id)
	d.print(string.fromTable(T), requires_debug, debug_id, peer_id)
end

---@param debug_id integer the type of debug | 0 = debug | 1 = error | 2 = profiler | 3 = map
---@param peer_id ?integer the peer_id of the player you want to check if they have it enabled, leave blank to check globally
---@return boolean enabled if the specified type of debug is enabled
function Debugging.getDebug(debug_id, peer_id)
	if not peer_id or not pl.isPlayer(peer_id) then -- if any player has it enabled
		if debug_id == -1 then -- any debug
			for _, debug_data in pairs(g_savedata.debug) do
				if debug_data.enabled then 
					return true 
				end
			end
			if g_savedata.debug.chat.enabled or g_savedata.debug.profiler.enabled or g_savedata.debug.map.enabled then
				return true
			end
			return false
		end

		-- make sure this debug type is valid
		if not debug_types[debug_id] then
			d.print("(d.getDebug) debug_type "..tostring(debug_id).." is not a valid debug type!", true, 1)
			return false
		end

		-- check a specific debug
		return g_savedata.debug[debug_types[debug_id]].enabled

	else -- if a specific player has it enabled
		local steam_id = pl.getSteamID(peer_id)
		if steam_id and g_savedata.player_data[steam_id] then -- makes sure the steam id and player data exists
			if debug_id == -1 then -- any debug
				if g_savedata.player_data[steam_id].debug.chat or g_savedata.player_data[steam_id].debug.profiler or g_savedata.player_data[steam_id].debug.map then
					return true
				end
			elseif not debug_id or debug_id == 0 or debug_id == 1 then -- chat debug
				if g_savedata.player_data[steam_id].debug.chat then
					return true
				end
			else
				return g_savedata.player_data[steam_id].debug[d.debugTypeFromID(debug_id)]
			end
		end
	end
	return false
end

function Debugging.handleDebug(debug_type, enabled, peer_id)
	if debug_type == "chat" then
		return (enabled and "Enabled" or "Disabled").." Chat Debug"
	elseif debug_type == "error" then
		return (enabled and "Enabled" or "Disabled").." Error Debug"
	elseif debug_type == "profiler" then
		if not enabled then
			-- remove profiler debug
			s.removePopup(peer_id, g_savedata.profiler.ui_id)

			-- clean all the profiler debug, if its disabled globally
			d.cleanProfilers()
		end

		return (enabled and "Enabled" or "Disabled").." Profiler Debug"
	elseif debug_type == "map" then
		if not enabled then
			-- remove map debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.ui_id)
					s.removeMapLabel(peer_id, vehicle_object.ui_id)
					s.removeMapLine(peer_id, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end
				end
			end

			for island_index, island in pairs(g_savedata.islands) do
				updatePeerIslandMapData(peer_id, island)
			end
			
			updatePeerIslandMapData(peer_id, g_savedata.player_base_island)
			updatePeerIslandMapData(peer_id, g_savedata.ai_base_island)
		end

		return (enabled and "Enabled" or "Disabled").." Map Debug"
	elseif debug_type == "graph_node" then
		local function addNode(ui_id, x, z, node_type, NSO)
			local r = 255
			local g = 255
			local b = 255
			if node_type == "ocean_path" then
				r = 0
				g = 25
				b = 225

				if NSO == 2 then -- darker for non NSO
					b = 200
					g = 50
				elseif NSO == 1 then -- brighter for NSO
					b = 255
					g = 0
				end

			elseif node_type == "land_path" then
				r = 0
				g = 215
				b = 25

				if NSO == 2 then -- darker for non NSO
					g = 150
					b = 50
				elseif NSO == 1 then -- brighter for NSO
					g = 255
					b = 0
				end

			end
			Map.addMapCircle(peer_id, ui_id, m.translation(x, 0, z), 5, 1.5, r, g, b, 255, 3)
		end

		if enabled then
			if not g_savedata.graph_nodes.init_debug then
				g_savedata.graph_nodes.ui_id = s.getMapID()
				g_savedata.graph_nodes.init_debug = true
			end

			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					addNode(g_savedata.graph_nodes.ui_id, x, z, z_data.type, z_data.NSO)
				end
			end
		else
			s.removeMapID(peer_id, g_savedata.graph_nodes.ui_id)
		end

		return (enabled and "Enabled" or "Disabled").." Graph Node Debug"
	elseif debug_type == "driving" then
		if not enabled then
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.driving.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Driving Debug"

	elseif debug_type == "vehicle" then
		if not enabled then
			-- remove vehicle debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removePopup(peer_id, vehicle_object.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Vehicle Debug"
	elseif debug_type == "function" then
		if enabled then
			-- enable function debug (function debug prints debug output whenever a function is called)

			--- cause the game doesn't like it when you use ... for params, and thinks thats only 1 parametre being passed.
			local function callFunction(funct, name, ...)

				--[[
					all functions within this function, other than the one we're wanting to call must be called appended with _ENV_NORMAL
					as otherwise it will cause the function debug to be printed for that function, causing this function to call itself over and over again.
				]]
				
				-- pack the arguments specified into a table
				local args = _ENV_NORMAL.table.pack(...)
				
				-- if no arguments were specified, call the function with no arguments
				if #args == 0 then
					if name == "_ENV.tostring" then
						return "nil"
					elseif name == "_ENV.s.getCharacterData" or name == "_ENV.server.getCharacterData" then
						return nil
					end
					local out = _ENV_NORMAL.table.pack(funct())
					return _ENV_NORMAL.table.unpack(out)
				elseif #args == 1 then -- if only one argument, call the function with only one argument.
					local out = _ENV_NORMAL.table.pack(funct(...))
					return _ENV_NORMAL.table.unpack(out)
				end
				--[[
					if theres two or more arguments, then pack all but the first argument into a table, and then have that as the second param
					this is to trick SW's number of params specified checker, as it thinks just ... is only 1 argument, even if it contains more than 1.
				]]
				local filler = {}
				for i = 2, #args do
					_ENV_NORMAL.table.insert(filler, args[i])
				end
				local out = _ENV_NORMAL.table.pack(funct(..., _ENV_NORMAL.table.unpack(filler)))
				return _ENV_NORMAL.table.unpack(out)
			end

			local function modifyFunction(funct, name)
				d.print(("setting up function %s()..."):format(name), true, 7)
				return (function(...)

					local returned = _ENV_NORMAL.table.pack(callFunction(funct, name, ...))

					-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
					__ENV =  _ENV_NORMAL
					__ENV._ENV_MODIFIED = _ENV
					_ENV = __ENV

					-- pack args into a table
					local args = table.pack(...)

					-- build output string
					local s = ""

					-- add return values
					for i = 1, #returned do
						s = ("%s%s%s"):format(s, returned[i], i ~= #returned and ", " or "")
					end

					-- add the = if theres any returned values, and also add the function name along with ( proceeding it.
					s = ("%s%s%s("):format(s, s ~= "" and " = " or "", name)

					-- add the arguments to the function, add a ", " after the argument if thats not the last argument.
					for i = 1, #args do
						s = ("%s%s%s"):format(s, args[i], i ~= #args and ", " or "")
					end

					-- add ) to the end of the string.
					s = ("%s%s"):format(s, ")")

					-- print the string.
					d.print(s, true, 7)

					-- switch back to modified environment
					_ENV = _ENV_MODIFIED

					-- return the value to the function which called it.
					return _ENV_NORMAL.table.unpack(returned)
				end)
			end
		
			local function setupFunctionsDebug(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}
				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					local type_v = type(v)
					if type_v == "function" then
						-- "inject" debug into the function
						T[k] = modifyFunction(v, ("%s.%s"):format(n, k))
					elseif type_v == "table" then
						-- go through this table looking for functions
						local name = ("%s.%s"):format(n, k)
						T[k] = setupFunctionsDebug(v, name)
					else
						-- just save as a variable
						T[k] = v
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL
					d.print("Completed setting up function debug!", true, 7)
				end

				return T
			end

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupFunctionsDebug(table.copy.deep(_ENV))
		else
			-- revert _ENV to be the non modified _ENV
			_ENV = table.copy.deep(_ENV_NORMAL)
		end
		return (enabled and "Enabled" or "Disabled").." Function Debug"
	elseif debug_type == "traceback" then
		if enabled and not _ENV_NORMAL then
			-- enable traceback debug (function debug prints debug output whenever a function is called)

			_ENV_NORMAL = nil

			_ENV_NORMAL = table.copy.deep(_ENV)

			local g_tb = g_savedata.debug.traceback

			local function removeAndReturn(...)
				g_tb.stack_size = g_tb.stack_size - 1
				return ...
			end
			local function setupFunction(funct, name)
				d.print(("setting up function %s()..."):format(name), true, 8)

				local funct_index = nil

				-- check if this function is already indexed
				if g_tb.funct_names then
					for saved_funct_index = 1, g_tb.funct_count do
						if g_tb.funct_names[saved_funct_index] == name then
							funct_index = saved_funct_index
							break
						end
					end
				end

				-- this function is not yet indexed, so add it to the index.
				if not funct_index then
					g_tb.funct_count = g_tb.funct_count + 1
					g_tb.funct_names[g_tb.funct_count] = name

					funct_index = g_tb.funct_count
				end

				-- return this as the new function
				return (function(...)

					-- increase the stack size before we run the function
					g_tb.stack_size = g_tb.stack_size + 1

					-- add this function to the stack
					g_tb.stack[g_tb.stack_size] = {
						funct_index
					}

					-- if this function was given parametres, add them to the stack
					if ... ~= nil then
						g_tb.stack[g_tb.stack_size][2] = {...}
					end

					--[[ 
						run this function
						if theres no error, it will then be removed from the stack, and then we will return the function's returned value
						if there is an error, it will never be removed from the stack, so we can detect the error.

						we have to do this via a function call, as we need to save the returned value before we return it
						as we have to first remove it from the stack
						we could use table.pack or {}, but that will cause a large increase in the performance impact.
					]]
					return removeAndReturn(funct(...))
				end)
			end
		
			local function setupTraceback(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}

				--[[if n == "_ENV.g_savedata" then
					T = g_savedata
				end]]

				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					if k ~= "_ENV_NORMAL" and k ~= "g_savedata" then
						local type_v = type(v)
						if type_v == "function" then
							-- "inject" debug into the function
							local name = ("%s.%s"):format(n, k)
							T[k] = setupFunction(v, name)
						elseif type_v == "table" then
							-- go through this table looking for functions
							local name = ("%s.%s"):format(n, k)
							T[k] = setupTraceback(v, name)
						else--if not n:match("^_ENV%.g_savedata") then
							-- just save as a variable
							T[k] = v
						end
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL

					T.g_savedata = g_savedata
				end

				return T
			end

			local start_traceback_setup_time = s.getTimeMillisec()

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupTraceback(table.copy.deep(_ENV))

			d.print(("Completed setting up tracebacks! took %ss"):format((s.getTimeMillisec() - start_traceback_setup_time)*0.001), true, 8)

			--onTick = setupTraceback(onTick, "onTick")

			-- add the error checker
			ac.executeOnReply(
				SHORT_ADDON_NAME,
				"DEBUG.TRACEBACK.ERROR_CHECKER",
				0,
				function(self)
					-- if traceback debug has been disabled, then remove ourselves
					if not g_savedata.debug.traceback.enabled then
						self.count = 0

					elseif g_savedata.debug.traceback.stack_size > 0 then
						-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
						__ENV =  _ENV_NORMAL
						__ENV._ENV_MODIFIED = _ENV
						_ENV = __ENV

						d.trace.print()

						_ENV = _ENV_MODIFIED

						g_savedata.debug.traceback.stack_size = 0
					end
				end,
				-1,
				-1
			)

			ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
		elseif not enabled and _ENV_NORMAL then
			-- revert modified _ENV functions to be the non modified _ENV
			--- @param t table the environment thats not been modified, will take all of the functions from this table and put it into the current _ENV
			--- @param mt table the modified enviroment
			--[[local function removeTraceback(t, mt)
				for k, v in _ENV_NORMAL.pairs(t) do
					local v_type = _ENV_NORMAL.type(v)
					-- modified table with this indexed
					if mt[k] then
						if v_type == "table" then
							removeTraceback(v, mt[k])
						elseif v_type == "function" then
							mt[k] = v
						end
					end
				end
				return mt
			end

			_ENV = removeTraceback(_ENV_NORMAL, _ENV)]]

			__ENV = _ENV_NORMAL.table.copy.deep(_ENV_NORMAL, _ENV_NORMAL)
			__ENV.g_savedata = g_savedata
			_ENV = __ENV

			_ENV_NORMAL = nil
		end
		return (enabled and "Enabled" or "Disabled").." Tracebacks"
	end
end

function Debugging.setDebug(debug_id, peer_id, override_state)

	if not peer_id then
		d.print("(Debugging.setDebug) peer_id is nil!", true, 1)
		return "peer_id was nil"
	end

	local player_data

	if peer_id ~= -1 then

		local steam_id = pl.getSteamID(peer_id)

		player_data = g_savedata.player_data[steam_id]

	end

	if not debug_id then
		d.print("(Debugging.setDebug) debug_id is nil!", true, 1)
		return "debug_id was nil"
	end

	local ignore_all = { -- debug types to ignore from enabling and/or disabling with ?impwep debug all
		[-1] = "all",
		[4] = "enable",
		[7] = "enable"
	}

	if not debug_types[debug_id] then
		return "Unknown debug type: "..tostring(debug_id)
	end

	if not player_data and peer_id ~= -1 then
		return "invalid peer_id: "..tostring(peer_id)
	end

	if peer_id == -1 then
		local function setGlobalDebug(debug_id)
			-- set that this debug should or shouldn't be auto enabled whenever a player joins for that player
			g_savedata.debug[debug_types[debug_id]].auto_enable = override_state

			for _, peer in ipairs(s.getPlayers()) do
				d.setDebug(debug_id, peer.id, override_state)
			end
		end

		if debug_id == -1 then
			for _debug_id, _ in pairs(debug_types) do
				setGlobalDebug(_debug_id)
			end

		else
			setGlobalDebug(debug_id)
		end

		return "Enabled "..debug_types[debug_id].." Globally."
	end
	
	if debug_types[debug_id] then
		if debug_id == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if player_data.debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") and override_state ~= true then
					none_true = false
					player_data.debug[debug_type_data] = false
				end
			end

			if none_true and override_state ~= false then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data].enabled = none_true
						player_data.debug[debug_type_data] = none_true
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			else
				d.checkDebug()
				for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "disable") then
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			end
			return (none_true and "Enabled" or "Disabled").." All Debug"
		else

			local debug_type = debug_types[debug_id]

			-- if the override is set, then set to the override.
			if override_state ~= nil then
				player_data.debug[debug_type] = override_state
			else -- if the override is not set, then just toggle the state.
				player_data.debug[debug_type] = not player_data.debug[debug_type]
			end

			-- check if we need to enable or disable the debug's functionality
			if player_data.debug[debug_type] then
				-- enable the debug's functionality
				g_savedata.debug[debug_type].enabled = true
			else
				-- we disabled it, check if we can just disable it's functionality.
				d.checkDebug()
			end

			-- return the handle debug message.
			return d.handleDebug(debug_type, player_data.debug[debug_type], peer_id)
		end
	end
end

function Debugging.checkDebug() -- checks all debugging types to see if anybody has it enabled, if not, disable them to save on performance
	local keep_enabled = {}

	-- check all debug types for all players to see if they have it enabled or disabled
	local player_list = s.getPlayers()
	for _, peer in pairs(player_list) do
		local steam_id = pl.getSteamID(peer.id)
		for debug_type, debug_type_enabled in pairs(g_savedata.player_data[steam_id].debug) do
			-- if nobody's known to have it enabled
			if not keep_enabled[debug_type] then
				-- then set it to whatever this player's value was
				keep_enabled[debug_type] = debug_type_enabled
			end
		end
	end

	-- any debug types that are disabled for all players, we want to disable globally to save on performance
	for debug_type, should_keep_enabled in pairs(keep_enabled) do
		-- if its not enabled for anybody
		if not should_keep_enabled then
			-- disable the debug globally
			g_savedata.debug[debug_type].enabled = should_keep_enabled
		end
	end
end

---@param unique_name string a unique name for the profiler  
function Debugging.startProfiler(unique_name, requires_debug)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
		if unique_name then
			if not g_savedata.profiler.working[unique_name] then
				g_savedata.profiler.working[unique_name] = s.getTimeMillisec()
			else
				d.print("A profiler named "..unique_name.." already exists", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.stopProfiler(unique_name, requires_debug, profiler_group)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
		if unique_name then
			if g_savedata.profiler.working[unique_name] then
				table.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][g_savedata.tick_counter] = s.getTimeMillisec()-g_savedata.profiler.working[unique_name]
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][(g_savedata.tick_counter-60)] = nil
				g_savedata.profiler.working[unique_name] = nil
			else
				d.print("A profiler named "..unique_name.." doesn't exist", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.showProfilers(requires_debug)
	if g_savedata.debug.profiler.enabled then
		if g_savedata.profiler.total then
			if not g_savedata.profiler.ui_id then
				g_savedata.profiler.ui_id = s.getMapID()
			end
			d.generateProfilerDisplayData()

			local debug_message = "Profilers\navg|max|cur (ms)"
			debug_message = d.getProfilerData(debug_message)

			local player_list = s.getPlayers()
			for peer_index, peer in pairs(player_list) do
				if d.getDebug(2, peer.id) then
					s.setPopupScreen(peer.id, g_savedata.profiler.ui_id, "Profilers", true, debug_message, -0.92, 0)
				end
			end
		end
	end
end

function Debugging.getProfilerData(debug_message)
	for debug_name, debug_data in pairs(g_savedata.profiler.display.average) do
		debug_message = ("%s\n--\n%s: %.2f|%.2f|%.2f"):format(debug_message, debug_name, debug_data, g_savedata.profiler.display.max[debug_name], g_savedata.profiler.display.current[debug_name])
	end
	return debug_message
end

function Debugging.generateProfilerDisplayData(t, old_node_name)
	if not t then
		for node_name, node_data in pairs(g_savedata.profiler.total) do
			if type(node_data) == "table" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif type(node_data) == "number" then
				-- average the data over the past 60 ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				for i = 0, 60 do
					valid_ticks = valid_ticks + 1
					data_total = data_total + g_savedata.profiler.total[node_name][(g_savedata.tick_counter-i)]
				end
				g_savedata.profiler.display.average[node_name] = data_total/valid_ticks -- average usage over the past 60 ticks
				g_savedata.profiler.display.max[node_name] = max_node -- max usage over the past 60 ticks
				g_savedata.profiler.display.current[node_name] = g_savedata.profiler.total[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	else
		for node_name, node_data in pairs(t) do
			if type(node_data) == "table" and node_name ~= "timer" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif node_name == "timer" then
				-- average the data over the past 60 ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				local max_node = 0
				for i = 0, 60 do
					if t[node_name] and t[node_name][(g_savedata.tick_counter-i)] then
						valid_ticks = valid_ticks + 1
						-- set max tick time
						if max_node < t[node_name][(g_savedata.tick_counter-i)] then
							max_node = t[node_name][(g_savedata.tick_counter-i)]
						end
						-- set average tick time
						data_total = data_total + t[node_name][(g_savedata.tick_counter-i)]
					end
				end
				g_savedata.profiler.display.average[old_node_name] = data_total/valid_ticks -- average usage over the past 60 ticks
				g_savedata.profiler.display.max[old_node_name] = max_node -- max usage over the past 60 ticks
				g_savedata.profiler.display.current[old_node_name] = t[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	end
end

function Debugging.cleanProfilers() -- resets all profiler data in g_savedata
	if not d.getDebug(2) then
		g_savedata.profiler.working = {}
		g_savedata.profiler.total = {}
		g_savedata.profiler.display = {
			average = {},
			max = {},
			current = {}
		}
		d.print("cleaned all profiler data", true, 2)
	end
end

function Debugging.buildArgs(args)
	local s = ""
	if args then
		local arg_len = table.length(args)
		for i = 1, arg_len do
			local arg = args[i]
			-- tempoarily disabled due to how long it makes the outputs.
			--[[if type(arg) == "table" then
				arg = string.gsub(string.fromTable(arg), "\n", " ")
			end]]
			s = ("%s%s%s"):format(s, arg, i ~= arg_len and ", " or "")
		end
	end
	return s
end

function Debugging.buildReturn(args)
	return d.buildArgs(args)
end

Debugging.trace = {

	print = function()
		local g_tb = _ENV_MODIFIED.g_savedata.debug.traceback

		local str = ""

		if g_tb.stack_size > 0 then
			str = ("Error in function: %s(%s)"):format(g_tb.funct_names[g_tb.stack[g_tb.stack_size][1]], d.buildArgs(g_tb.stack[g_tb.stack_size][2]))
		end

		for stack_index = g_tb.stack_size - 1, 1, -1 do
			str = ("%s\n    Called By: %s(%s)"):format(str, g_tb.funct_names[g_tb.stack[stack_index][1]], d.buildArgs(g_tb.stack[stack_index][2]))
		end

		d.print(str, false, 8)
	end
}
-- required libraries

-- library name
Tags = {}

function Tags.has(tags, tag, decrement)
	if type(tags) ~= "table" then
		d.print("(Tags.has) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
		return false
	end

	if not decrement then
		for tag_index = 1, #tags do
			if tags[tag_index] == tag then
				return true
			end
		end
	else
		for tag_index = #tags, 1, -1 do
			if tags[tag_index] == tag then
				return true
			end 
		end
	end

	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function Tags.getValue(tags, tag, as_string)
	if type(tags) ~= "table" then
		d.print("(Tags.getValue) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
	end

	for k, v in pairs(tags) do
		if string.match(v, tag.."=") then
			if not as_string then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			else
				return tostring(string.gsub(v, tag.."=", ""))
			end
		end
	end
	
	return nil
end


-- library name
SpawningUtils = {}

-- shortened library name
su = SpawningUtils

-- spawn an individual object descriptor from a playlist location
function SpawningUtils.spawnObjectType(spawn_transform, location_index, object_descriptor, parent_vehicle_id)
	local component, is_success = s.spawnAddonComponent(spawn_transform, s.getAddonIndex(), location_index, object_descriptor.index, parent_vehicle_id)
	if is_success then
		return component.id
	else -- then it failed to spawn the addon component
		d.print("(Improved Conquest Mode) Please send this debug info to the discord server:\ncomponent: "..component.."\naddon_index: "..s.getAddonIndex().."\nlocation index: "..location_index, false, 1)
		return nil
	end
end

function SpawningUtils.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, object.transform), location_index, object, parent_vehicle_id)

	-- add object to spawned object tables

	if spawned_object_id ~= nil and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(object.tags, "vehicle_type=wep_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		end
		if Tags.has(object.tags, "vehicle_type=wep_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(object.tags, "vehicle_type=wep_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(object.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(object.tags, "type=dlc_weapons_flag") then
			l_vehicle_type = "flag"
		end

		local l_size = "small"
		for tag_index, tag_object in pairs(object.tags) do
			if string.find(tag_object, "size=") ~= nil then
				l_size = string.sub(tag_object, 6)
			end
		end

		local object_data = { name = object.display_name, type = object.type, id = spawned_object_id, component_id = object.id, vehicle_type = l_vehicle_type, size = l_size }

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

function SpawningUtils.spawnObjects(spawn_transform, location_index, object_descriptors, out_spawned_objects)
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

		su.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end
 -- functions used by the spawn vehicle function -- functions related to getting tags from components inside of mission and environment locations -- functions for addon to addon communication
-- required libraries

-- library name
Cache = {}

---@param location g_savedata.cache[] where to reset the data, if left blank then resets all cache data
---@return boolean success returns true if successfully cleared the cache
function Cache.reset(location) -- resets the cache
	if not location then
		g_savedata.cache = {}
	else
		if g_savedata.cache[location] then
			g_savedata.cache[location] = nil
		else
			if not g_savedata.cache_stats.failed_resets then
				g_savedata.cache_stats.failed_resets = 0
			end
			g_savedata.cache_stats.failed_resets = g_savedata.cache_stats.failed_resets + 1
			d.print("Failed to reset cache data at "..tostring(location)..", this should not be happening!", true, 1)
			return false
		end
	end
	g_savedata.cache_stats.resets = g_savedata.cache_stats.resets + 1
	return true
end

---@param location g_savedata.cache[] where to write the data
---@param data any the data to write at the location
---@return boolean write_successful if writing the data to the cache was successful
function Cache.write(location, data)

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data currently at the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data currently at the cache of "..tostring(location)..": (table)", true, 0)
	end

	g_savedata.cache[location] = data

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data written to the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data written to the cache of "..tostring(location)..": (table)", true, 0)
	end

	if g_savedata.cache[location] == data then
		g_savedata.cache_stats.writes = g_savedata.cache_stats.writes + 1
		return true
	else
		g_savedata.cache_stats.failed_writes = g_savedata.cache_stats.failed_writes + 1
		return false
	end
end

---@param location g_savedata.cache[] where to read the data from
---@return any data the data that was at the location
function Cache.read(location)
	g_savedata.cache_stats.reads = g_savedata.cache_stats.reads + 1
	if type(g_savedata.cache[location]) ~= "table" then
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: "..g_savedata.cache[location], true, 0)
	else
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: (table)", true, 0)
	end
	return g_savedata.cache[location]
end

---@param location g_savedata.cache[] where to check
---@return boolean exists if the data exists at the location
function Cache.exists(location)
	if g_savedata.cache[location] and g_savedata.cache[location] ~= {} and (type(g_savedata.cache[location]) ~= "table" or table.length(g_savedata.cache[location]) > 0) or g_savedata.cache[location] == false then
		d.print("g_savedata.Cache."..location.." exists", true, 0)

		return true
	end
	d.print("g_savedata.Cache."..location.." doesn't exist", true, 0)
	return false
end
 -- functions relating to the custom 
--[[


	Library Setup


]]

-- required libraries
-- required libraries

-- library name
Island = {}

-- shortened library name
is = Island

-- checks if this island can spawn the specified vehicle
---@param island ISLAND the island you want to check if AI can spawn there
---@param selected_prefab selected_prefab[] the selected_prefab you want to check with the island
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
--[[


	Library Setup


]]

-- required libraries

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


-- library name
Compatibility = {}

-- shortened library name
comp = Compatibility

--[[


	Variables
   

]]

--# stores which versions require compatibility updates
local version_updates = {
	"(0.3.0.78)",
	"(0.3.0.79)",
	"(0.3.0.82)",
	"(0.3.1.2)",
	"(0.3.2.2)",
	"(0.3.2.6)"
}

--[[


	Classes


]]

---@class VERSION_DATA
---@field data_version string the version which the data is on currently
---@field version string the version which the mod is on
---@field versions_outdated integer how many versions the data is out of date
---@field is_outdated boolean if the data is outdated compared to the mod
---@field newer_versions table a table of versions which are newer than the current, indexed by index, value as version string

--[[


	Functions         


]]

--# creates version data for the specified version, for use in the version_history table
---@param version string the version you want to create the data on
---@return table version_history_data the data of the version
function Compatibility.createVersionHistoryData(version)

	--[[
		calculate ticks played
	]] 
	local ticks_played = g_savedata.tick_counter

	if g_savedata.info.version_history and #g_savedata.info.version_history > 0 then
		for _, version_data in ipairs(g_savedata.info.version_history) do
			ticks_played = ticks_played - (version_data.ticks_played or 0)
		end
	end

	--[[
		
	]]
	local version_history_data = {
		version = version,
		ticks_played = ticks_played,
		backup_g_savedata = {}
	}

	return version_history_data
end

--# returns g_savedata, a copy of g_savedata which when edited, doesnt actually apply changes to the actual g_savedata, useful for backing up.
function Compatibility.getSavedataCopy()

	--d.print("(comp.getSavedataCopy) getting a g_savedata copy...", true, 0)

	--[[
		credit to Woe (https://canary.discord.com/channels/357480372084408322/905791966904729611/1024355759468839074)

		returns a clone/copy of g_savedata
	]]
	
	local function clone(t)
		local copy = {}
		if type(t) == "table" then
			for key, value in next, t, nil do
				copy[clone(key)] = clone(value)
			end
		else
			copy = t
		end
		return copy
	end

	local copied_g_savedata = clone(g_savedata)
	--d.print("(comp.getSavedataCopy) created a g_savedata copy!", true, 0)

	return copied_g_savedata
end

--# migrates the version system to the new one implemented in 0.3.0.78
---@param overwrite_g_savedata boolean if you want to overwrite g_savedata, usually want to keep false unless you've already got a backup of g_savedata
---@return table migrated_g_savedata
---@return boolean is_success if it successfully migrated the versioning system
function Compatibility.migrateVersionSystem(overwrite_g_savedata)

	d.print("migrating g_savedata...", false, 0)

	--[[
		create a local copy of g_savedata, as changes we make we dont want to be applied to the actual g_savedata
	]]

	local migrated_g_savedata = comp.getSavedataCopy()

	--[[
		make sure that the version_history table doesnt exist
	]]
	if g_savedata.info.version_history then
		-- if it already does, then abort, as the version system is already migrated
		d.print("(comp.migrateVersionSystem) the version system has already been migrated!", true, 1)
		return nil, false
	end

	--[[
		create the version_history table
	]]
	if overwrite_g_savedata then
		g_savedata.info.version_history = {}
	end

	migrated_g_savedata.info.version_history = {}

	--[[
		create the version history data, with the previous version the creation version 
		sadly, we cannot reliably get the last version used for versions 0.3.0.77 and below
		so we have to make this assumption
	]]

	if overwrite_g_savedata then
		table.insert(g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))
	end
	
	table.insert(migrated_g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))

	d.print("migrated g_savedata", false, 0)

	return migrated_g_savedata, true
end

--# returns the version id from the provided version
---@param version string the version you want to get the id of
---@return integer version_id the id of the version
---@return boolean is_success if it found the id of the version
function Compatibility.getVersionID(version)
	--[[
		first, we want to ensure version was provided
		lastly, we want to go through all of the versions stored in the version history, if we find a match, then we return it as the id
		if we cannot find a match, we return nil and false
	]]

	-- ensure version was provided
	if not version then
		d.print("(comp.getVersionID) version was not provided!", false, 1)
		return nil, false
	end

	-- go through all of the versions saved in version_history
	for version_id, version_name in ipairs(g_savedata.info.version_history) do
		if version_name == version then
			return version_id, true
		end
	end

	-- if a version was not found, return nil and false
	return nil, false
end

--# splits a version into 
---@param version string the version you want split
---@return table version [1] = release version, [2] = majour version, [3] = minor version, [4] = commit version
function Compatibility.splitVersion(version) -- credit to woe
	local T = {}

	-- remove ( and )
	version = version:match("[%d.]+")

	for S in version:gmatch("([^%.]*)%.*") do
		T[#T+1] = tonumber(S) or S
	end

	T = {
		T[1], -- release
		T[2], -- majour
		T[3], -- minor
		T[4] -- commit
	}

	return T
end

--# returns the version from the version_id
---@param version_id integer the id of the version
---@return string version the version associated with the id
---@return boolean is_success if it successfully got the version from the id
function Compatibility.getVersion(version_id)

	-- ensure that version_id was specified
	if not version_id then
		d.print("(comp.getVersion) version_id was not provided!", false, 1)
		return nil, false
	end

	-- ensure that it is a number
	if type(version_id) ~= "number" then
		d.print("(comp.getVersion) given version_id was not a number! type: "..type(version_id).." value: "..tostring(version_id), false, 1)
		return nil, false
	end

	local version = g_savedata.info.version_history[version_id] and g_savedata.info.version_history[version_id].version or nil
	return version, version ~= nil
end

--# returns version data about the specified version, or if left blank, the current version
---@param version string the current version, leave blank if want data on current version
---@return VERSION_DATA version_data the data about the version
---@return boolean is_success if it successfully got the version data
function Compatibility.getVersionData(version)

	local version_data = {
		data_version = "",
		is_outdated = false,
		version = "",
		versions_outdated = 0,
		newer_versions = {}
	}

	local copied_g_savedata = comp.getSavedataCopy() -- local copy of g_savedata so any changes we make to it wont affect any backups we may make

	--[[
		first, we want to ensure that the version system is migrated
		second, we want to get the id of the version depending on the given version argument
		third, we want to get the data version
		fourth, we want to count how many versions out of date the data version is from the mod version
		fifth, we want to want to check if the version is outdated
		and lastly, we want to return the data
	]]

	-- (1) check if the version system is not migrated
	if not g_savedata.info.version_history then
		local migrated_g_savedata, is_success = comp.migrateVersionSystem() -- migrate the version data
		if not is_success then
			d.print("(comp.getVersionData) failed to migrate version system. This is probably not good!", false, 1)
			return nil, false
		end

		-- set copied_g_savedata as migrated_g_savedata
		copied_g_savedata = migrated_g_savedata
	end

	-- (2) get version id
	local version_id = version and comp.getVersionID(version) or #copied_g_savedata.info.version_history

	-- (3) get data version
	--d.print("(comp.getVersionData) data_version: "..tostring(copied_g_savedata.info.version_history[version_id].version))
	version_data.data_version = copied_g_savedata.info.version_history[version_id].version

	-- (4) count how many versions out of date the data is

	local current_version = comp.splitVersion(version_data.data_version)

	local ids_to_versions = {
		"Release",
		"Majour",
		"Minor",
		"Commit"
	}

	for _, version_name in ipairs(version_updates) do

		--[[
			first, we want to check if the release version is greater (x.#.#.#)
			if not, second we want to check if the majour version is greater (#.x.#.#)
			if not, third we want to check if the minor version is greater (#.#.x.#)
			if not, lastly we want to check if the commit version is greater (#.#.#.x)
		]]

		local update_version = comp.splitVersion(version_name)

		--[[
			go through each version, and check if its newer than our current version
		]]
		for i = 1, #current_version do
			if not current_version[i] or current_version[i] > update_version[i] then
				--[[
					if theres no commit version for the current version, all versions with the same stable, majour and minor version will be older.
					OR, current version is newer, then dont continue, as otherwise that could trigger a false positive with things like 0.3.0.2 vs 0.3.1.1
				]]
				d.print(("(comp.getVersionData) %s Version %s is older than current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
				break
			elseif current_version[i] < update_version[i] then
				-- current version is older, so we need to migrate data.
				table.insert(version_data.newer_versions, version_name)
				d.print(("Found new %s version: %s current version: %s"):format(ids_to_versions[i], version_name, version_data.data_version), false, 0)
				break
			end

			d.print(("(comp.getVersionData) %s Version %s is the same as current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
		end
	end

	-- count how many versions its outdated
	version_data.versions_outdated = #version_data.newer_versions

	-- (5) check if its outdated
	version_data.is_outdated = version_data.versions_outdated > 0

	return version_data, true
end

--# saves backup of current g_savedata
---@return boolean is_success if it successfully saved a backup of the savedata
function Compatibility.saveBackup()
	--[[
		first, we want to save a current local copy of the g_savedata
		second we want to ensure that the g_savedata.info.version_history table is created
		lastly, we want to save the backup g_savedata
	]]

	-- create local copy of g_savedata
	local backup_g_savedata = comp.getSavedataCopy()

	if not g_savedata.info.version_history then -- if its not created (pre 0.3.0.78)
		d.print("(comp.saveBackup) migrating version system", true, 0)
		local migrated_g_savedata, is_success = comp.migrateVersionSystem(true) -- migrate version system
		if not is_success then
			d.print("(comp.saveBackup) failed to migrate version system. This is probably not good!", false, 1)
			return false
		end

		if not g_savedata.info.version_history then
			d.print("(comp.saveBackup) successfully migrated version system, yet g_savedata doesn't contain the new version system, this is not good!", false, 1)
		end
	end

	local version_data, is_success = comp.getVersionData()
	if version_data.data_version ~= g_savedata.info.version_history[#g_savedata.info.version_history].version then
		--d.print("version_data.data_version: "..tostring(version_data.data_version).."\ng_savedata.info.version_history[#g_savedata.info.version.version_history].version: "..tostring(g_savedata.info.version_history[#g_savedata.info.version_history].version))
		g_savedata.info.version_history[#g_savedata.info.version_history + 1] = comp.createVersionHistoryData()
	end

	-- save backup g_savedata
	g_savedata.info.version_history[#g_savedata.info.version_history].backup_g_savedata = backup_g_savedata

	-- remove g_savedata backups which are from over 2 data updates ago
	local backup_versions = {}
	for version_index, version_history_data in ipairs(g_savedata.info.version_history) do
		if version_history_data.backup_g_savedata.info then
			table.insert(backup_versions, version_index)
		end
	end
	
	if #backup_versions >= 3 then
		d.print("Deleting old backup data...", false, 0)
		for backup_index, backup_version_index in ipairs(backup_versions) do
			d.print("Deleting backup data for "..g_savedata.info.version_history[backup_version_index].version, false, 0)
			backup_versions[backup_index] = nil
			g_savedata.info.version_history[backup_version_index].backup_g_savedata = {}

			if #backup_versions <= 2 then
				d.print("Deleted old backup data.", false, 0)
				break
			end
		end
	end

	return true
end

--# updates g_savedata to be compatible with the mod version, to ensure that worlds are backwards compatible.
function Compatibility.update()

	-- ensure that we're actually outdated before proceeding
	local version_data, is_success = comp.getVersionData()
	if not is_success then
		d.print("(comp.update) failed to get version data! this is probably bad!", false, 1)
		return
	end

	if not version_data.is_outdated then
		d.print("(comp.update) according to version data, the data is not outdated. This is probably not good!", false, 1)
		return
	end

	d.print(SHORT_ADDON_NAME.."'s data is "..version_data.versions_outdated.." version"..(version_data.versions_outdated > 1 and "s" or "").." out of date!", false, 0)

	-- save backup
	local backup_saved = comp.saveBackup()
	if not backup_saved then
		d.print("(comp.update) Failed to save backup. This is probably not good!", false, 1)
		return false
	end

	d.print("Creating new version history for "..version_data.newer_versions[1].."...", false, 0)
	local version_history_data = comp.createVersionHistoryData(version_data.newer_versions[1])
	g_savedata.info.version_history[#g_savedata.info.version_history+1] = version_history_data
	d.print("Successfully created new version history for "..version_data.newer_versions[1]..".", false, 0)

	-- check for 0.3.0.78 changes
	if version_data.newer_versions[1] == "(0.3.0.78)" then
		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1]..", Cleaning up old data...", false, 0)

		-- clean up old data
		g_savedata.info.creation_version = nil
		g_savedata.info.full_reload_versions = nil
		g_savedata.info.awaiting_reload = nil

		-- clean up old player_data
		for steam_id, player_data in pairs(g_savedata.player_data) do
			player_data.timers = nil
			player_data.fully_reloading = nil
			player_data.do_as_i_say = nil
		end		
	elseif version_data.newer_versions[1] == "(0.3.0.79)" then -- 0.3.0.79 changes

		-- update the island data with the proper zones, as previously, the zone system improperly filtered out NSO compatible and incompatible zones
		local spawn_zones = sup.spawnZones()
		local tile_zones = sup.sortSpawnZones(spawn_zones)

		for tile_name, zones in pairs(tile_zones) do
			local island, is_success = Island.getDataFromName(tile_name)
			island.zones = zones
		end

		if g_savedata.info.version_history[1].ticked_played then
			g_savedata.info.version_history.ticks_played = g_savedata.info.version_history.ticked_played
			g_savedata.info.version_history.ticked_played = nil
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.0.82)" then -- 0.3.0.82 changes

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			for vehicle_index, vehicle_object in pairs(squad.vehicles) do
				vehicle_object.transform_history = {}
			end
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	elseif version_data.newer_versions[1] == "(0.3.1.2)" then -- 0.3.1.2 changes

		d.print(("Migrating %s data..."):format(SHORT_ADDON_NAME), false, 0)

		-- check if we've initialised the graph_node debug before
		if g_savedata.graph_nodes.init_debug then

			-- generate a global map id for all graph nodes
			g_savedata.graph_nodes.ui_id = server.getMapID()

			d.print("Cleaning up old data...", false, 0)

			-- go through and remove all of the graph node's map ids from the map
			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					s.removeMapID(-1, z_data.ui_id)
					z_data.ui_id = nil
				end
			end

			-- go through all of the player data and set graph_node debug to false
			for _, player_data in pairs(g_savedata.player_data) do
				player_data.debug.graph_node = false
			end

			-- disable graph_node debug globally
			g_savedata.debug.graph_node = false
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	elseif version_data.newer_versions[1] == "(0.3.2.2)" then -- 0.3.2.2 changes

		local temp_g_savedata_debug = {
			chat = {
				enabled = g_savedata.debug.chat,
				default = false,
				needs_setup_on_reload = false
			},
			error = {
				enabled = g_savedata.debug.error,
				default = false,
				needs_setup_on_reload = false
			},
			profiler = {
				enabled = g_savedata.debug.profiler,
				default = false,
				needs_setup_on_reload = false
			},
			map = {
				enabled = g_savedata.debug.map,
				default = false,
				needs_setup_on_reload = false
			},
			graph_node = {
				enabled = g_savedata.debug.graph_node,
				default = false,
				needs_setup_on_reload = false
			},
			driving = {
				enabled = g_savedata.debug.driving,
				default = false,
				needs_setup_on_reload = false
			},
			vehicle = {
				enabled = g_savedata.debug.vehicle,
				default = false,
				needs_setup_on_reload = false
			},
			["function"] = {
				enabled = false,
				default = false,
				needs_setup_on_reload = true
			},
			traceback = {
				enabled = false,
				default = false,
				needs_setup_on_reload = true,
				stack = {},
				stack_size = 0,
				funct_names = {},
				funct_count = 0
			}
		}

		g_savedata.debug = temp_g_savedata_debug

		for _, player in pairs(g_savedata.player_data) do
			player.debug["function"] = false
			player.debug.traceback = false
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.2.6)" then -- 0.3.2.6 changes

		g_savedata.settings.PAUSE_WHEN_NONE_ONLINE = true

		g_savedata.settings.PERFORMANCE_MODE = true

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	end

	d.print(SHORT_ADDON_NAME.." data is now up to date with "..version_data.newer_versions[1]..".", false, 0)

	-- this means that theres still newer versions
	if #version_data.newer_versions > 1 then
		-- migrate to the next version
		comp.update()
	end

	-- we've finished migrating!
	comp.showSaveMessage()
end

--# prints outdated message and starts update
function Compatibility.outdated()
	-- print that its outdated
	d.print(SHORT_ADDON_NAME.." data is outdated! attempting to automatically update...", false, 0)

	-- start update process
	comp.update()
end

--# verifies that the mod is currently up to date
function Compatibility.verify()
	d.print("verifying if "..SHORT_ADDON_NAME.." data is up to date...", false, 0)
	--[[
		first, check if the versioning system is up to date
	]]
	if not g_savedata.info.version_history then
		-- the versioning system is not up to date
		comp.outdated()
	else
		-- check if we're outdated
		local version_data, is_success = comp.getVersionData()

		if not is_success then
			d.print("(comp.verify) failed to get version data! this is probably bad!", false, 1)
			return
		end

		-- if we're outdated
		if version_data.is_outdated then
			comp.outdated()
		end
	end
end

--# shows the message saying that the addon was fully migrated
function Compatibility.showSaveMessage()
	d.print(SHORT_ADDON_NAME.." Data has been fully migrated!", false, 0)
end
 -- functions used for making the mod backwards compatible -- functions for debugging -- functions for drawing on the map -- custom matrix functions
-- required libraries
-- This library is for controlling or getting things about the Enemy AI.

-- required libraries

-- library name
AI = {}

--- @param vehicle_object vehicle_object the vehicle you want to set the state of
--- @param state string the state you want to set the vehicle to
--- @return boolean success if the state was set
function AI.setState(vehicle_object, state)
	if vehicle_object then
		if state ~= vehicle_object.state.s then
			if state == VEHICLE.STATE.HOLDING then
				vehicle_object.holding_target = vehicle_object.transform
			end
			vehicle_object.state.s = state
		end
	else
		d.print("(AI.setState) vehicle_object is nil!", true, 1)
	end
	return false
end

--# made for use with toggles in buttons (only use for toggle inputs to seats)
---@param vehicle_id integer the vehicle's id that has the seat you want to set
---@param seat_name string the name of the seat you want to set
---@param axis_ws number w/s axis
---@param axis_ad number a/d axis
---@param axis_ud number up down axis
---@param axis_lr number left right axis
---@param ... boolean buttons (1-7) (7 is trigger)
---@return boolean set_seat if the seat was set
function AI.setSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, ...)
	
	if not vehicle_id then
		d.print("(AI.setSeat) vehicle_id is nil!", true, 1)
		return false
	end

	if not seat_name then
		d.print("(AI.setSeat) seat_name is nil!", true, 1)
		return false
	end

	local button = table.pack(...)

	-- sets any nil values to 0 or false
	axis_ws = axis_ws or 0
	axis_ad = axis_ad or 0
	axis_ud = axis_ud or 0
	axis_lr = axis_lr or 0

	for i = 1, 7 do
		button[i] = button[i] or false
	end

	g_savedata.seat_states = g_savedata.seat_states or {}


	if not g_savedata.seat_states[vehicle_id] or not g_savedata.seat_states[vehicle_id][seat_name] then

		g_savedata.seat_states[vehicle_id] = g_savedata.seat_states[vehicle_id] or {}
		g_savedata.seat_states[vehicle_id][seat_name] = {}

		for i = 1, 7 do
			g_savedata.seat_states[vehicle_id][seat_name][i] = false
		end
	end

	for i = 1, 7 do
		if button[i] ~= g_savedata.seat_states[vehicle_id][seat_name][i] then
			g_savedata.seat_states[vehicle_id][seat_name][i] = button[i]
			button[i] = true
		else
			button[i] = false
		end
	end

	s.setVehicleSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, button[1], button[2], button[3], button[4], button[5], button[6], button[7])
	return true
end
-- required libraries

-- library name
SpawnModifiers = {}

-- shortened library name
sm = SpawnModifiers

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
									d.print("setup "..g_savedata.constructable_vehicles[role][veh_type][strat][vehicle_id].location.data.name.." for adaptive AI", true, 0)
								end
							end
						end
					end
					g_savedata.constructable_vehicles[role][veh_type].mod = 1
				end
			end
			g_savedata.constructable_vehicles[role].mod = default_mods[role]
		end
	end
end

---@param is_specified boolean true to specify what vehicle to spawn, false for random
---@param vehicle_list_id any vehicle to spawn if is_specified is true, integer to specify exact vehicle, string to specify the role of the vehicle you want
---@param vehicle_type string the type of vehicle you want to spawn, such as boat, helicopter, plane or land
---@return prefab_data[] prefab_data the vehicle's prefab data
function SpawnModifiers.spawn(is_specified, vehicle_list_id, vehicle_type)
	local sel_role = nil
	local sel_veh_type = nil
	local sel_strat = nil
	local sel_vehicle = nil
	if is_specified == true and type(vehicle_list_id) == "number" and g_savedata.constructable_vehicles then
		sel_role = g_savedata.vehicle_list[vehicle_list_id].role
		sel_veh_type = g_savedata.vehicle_list[vehicle_list_id].vehicle_type
		sel_strat = g_savedata.vehicle_list[vehicle_list_id].strategy
		for vehicle_id, vehicle_object in pairs(g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat]) do
			if not sel_vehicle and vehicle_list_id == g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat][vehicle_id].id then
				sel_vehicle = vehicle_id
			end
		end
		if not sel_vehicle then
			return false
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
				return false
			end
		else -- then use the vehicle type which was selected
			if g_savedata.constructable_vehicles[sel_role] and g_savedata.constructable_vehicles[sel_role][vehicle_type] then -- makes sure it actually exists
				sel_veh_type = vehicle_type
			else
				d.print("There are no vehicles with the role \""..sel_role.."\" and with the type \""..vehicle_type.."\"", true, 1)
				return false
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
			return false
		end
		sel_vehicle = math.randChance(vehicle_chances)
		--d.print("selected vehicle: "..tostring(sel_vehicle), true, 0)
	else
		if g_savedata.constructable_vehicles then
			d.print("unknown arguments for choosing which ai vehicle to spawn.", true, 1)
		else
			d.print("g_savedata.constructable_vehicles is nil! This may be directly after a full reload, if so, ignore this error", true, 1)
		end
		return false
	end
	return g_savedata.constructable_vehicles[sel_role][sel_veh_type][sel_strat][sel_vehicle]
end

---@param role string the role of the vehicle, such as attack, general or defend
---@param type string the vehicle type, such as boat, plane, heli, land or turret
---@param strategy string the strategy of the vehicle, such as strafe, bombing or general
---@param vehicle_list_id integer the index of the vehicle in the vehicle list
---@return integer constructable_vehicle_id the index of the vehicle in the constructable vehicle list, returns nil if not found
function SpawnModifiers.getConstructableVehicleID(role, vehicle_type, strategy, vehicle_list_id)
	local constructable_vehicle_id = nil
	if g_savedata.constructable_vehicles[role] and g_savedata.constructable_vehicles[role][vehicle_type] and g_savedata.constructable_vehicles[role][vehicle_type][strategy] then
		for vehicle_id, vehicle_object in pairs(g_savedata.constructable_vehicles[role][vehicle_type][strategy]) do
			if not constructable_vehicle_id and vehicle_list_id == g_savedata.constructable_vehicles[role][vehicle_type][strategy][vehicle_id].id then
				constructable_vehicle_id = vehicle_id
			end
		end
	else
		d.print("(sm.getContstructableVehicleID) Failed to get constructable vehicle id, role: "..tostring(role)..", type: "..tostring(vehicle_type)..", strategy: "..tostring(strategy)..", vehicle_list_id: "..tostring(vehicle_list_id), true, 1)
	end
	return constructable_vehicle_id -- returns the constructable_vehicle_id, if not found then it returns nil
end

---@param vehicle_name string the name of the vehicle
---@return integer vehicle_list_id the vehicle list id from the vehicle's name, returns nil if not found
function SpawnModifiers.getVehicleListID(vehicle_name)

	if not vehicle_name then
		d.print("(SpawnModifiers.getVehicleListID) vehicle_name is nil!", true, 1)
		return nil
	end

	vehicle_name = string.removePrefix(vehicle_name)

	for vehicle_id, vehicle_object in pairs(g_savedata.vehicle_list) do
		if string.removePrefix(vehicle_object.location.data.name) == vehicle_name then
			return vehicle_id
		end
	end
	return nil
end

---@param reinforcement_type string \"punish\" to make it less likely to spawn, \"reward\" to make it more likely to spawn
---@param role string the role of the vehicle, such as attack, general or defend
---@param role_reinforcement integer how much to reinforce the role of the vehicle, 1-5
---@param type string the vehicle type, such as boat, plane, heli, land or turret
---@param type_reinforcement integer how much to reinforce the type of the vehicle, 1-5
---@param strategy string strategy of the vehicle, such as strafe, bombing or general
---@param strategy_reinforcement integer how much to reinforce the strategy of the vehicle, 1-5
---@param constructable_vehicle_id integer the index of the vehicle in the constructable vehicle list
---@param vehicle_reinforcement integer how much to reinforce the vehicle, 1-5
function SpawnModifiers.train(reinforcement_type, role, role_reinforcement, type, type_reinforcement, strategy, strategy_reinforcement, constructable_vehicle_id, vehicle_reinforcement)
	if reinforcement_type == PUNISH then
		if role and role_reinforcement then
			d.print("punished role:"..role.." | amount punished: "..ai_training.punishments[role_reinforcement], true, 0)
			g_savedata.constructable_vehicles[role].mod = math.max(g_savedata.constructable_vehicles[role].mod + ai_training.punishments[role_reinforcement], 0)
			if type and type_reinforcement then 
				d.print("punished type:"..type.." | amount punished: "..ai_training.punishments[type_reinforcement], true, 0)
				g_savedata.constructable_vehicles[role][type].mod = math.max(g_savedata.constructable_vehicles[role][type].mod + ai_training.punishments[type_reinforcement], 0.05)
				if strategy and strategy_reinforcement then 
					d.print("punished strategy:"..strategy.." | amount punished: "..ai_training.punishments[strategy_reinforcement], true, 0)
					g_savedata.constructable_vehicles[role][type][strategy].mod = math.max(g_savedata.constructable_vehicles[role][type][strategy].mod + ai_training.punishments[strategy_reinforcement], 0.05)
					if constructable_vehicle_id and vehicle_reinforcement then 
						d.print("punished vehicle:"..constructable_vehicle_id.." | amount punished: "..ai_training.punishments[vehicle_reinforcement], true, 0)
						g_savedata.constructable_vehicles[role][type][strategy][constructable_vehicle_id].mod = math.max(g_savedata.constructable_vehicles[role][type][strategy][constructable_vehicle_id].mod + ai_training.punishments[vehicle_reinforcement], 0.05)
					end
				end
			end
		end
	elseif reinforcement_type == REWARD then
		if role and role_reinforcement then
			d.print("rewarded role:"..role.." | amount rewarded: "..ai_training.rewards[role_reinforcement], true, 0)
			g_savedata.constructable_vehicles[role].mod = math.min(g_savedata.constructable_vehicles[role].mod + ai_training.rewards[role_reinforcement], 1.5)
			if type and type_reinforcement then 
				d.print("rewarded type:"..type.." | amount rewarded: "..ai_training.rewards[type_reinforcement], true, 0)
				g_savedata.constructable_vehicles[role][type].mod = math.min(g_savedata.constructable_vehicles[role][type].mod + ai_training.rewards[type_reinforcement], 1.5)
				if strategy and strategy_reinforcement then 
					d.print("rewarded strategy:"..strategy.." | amount rewarded: "..ai_training.rewards[strategy_reinforcement], true, 0)
					g_savedata.constructable_vehicles[role][type][strategy].mod = math.min(g_savedata.constructable_vehicles[role][type][strategy].mod + ai_training.rewards[strategy_reinforcement], 1.5)
					if constructable_vehicle_id and vehicle_reinforcement then 
						d.print("rewarded vehicle:"..constructable_vehicle_id.." | amount rewarded: "..ai_training.rewards[vehicle_reinforcement], true, 0)
						g_savedata.constructable_vehicles[role][type][strategy][constructable_vehicle_id].mod = math.min(g_savedata.constructable_vehicles[role][type][strategy][constructable_vehicle_id].mod + ai_training.rewards[vehicle_reinforcement], 1.5)
					end
				end
			end
		end
	end
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
							for vehicle_id, vehicle_data in pairs(strat_data) do
								if type(vehicle_data) == "table" and vehicle_data.mod then
									table.insert(all_vehicles, {
										mod = vehicle_data.mod,
										prefab_data = vehicle_data
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

-- library name
Pathfinding = {}

-- shortened library name
p = Pathfinding

function Pathfinding.resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		s.removeMapID(-1, v.ui_id)
	end

	vehicle_object.path = {}
end

-- makes the vehicle go to its next path
---@param vehicle_object vehicle_object the vehicle object which is going to its next path
---@return number more_paths the number of paths left
---@return boolean is_success if it successfully went to the next path
function Pathfinding.nextPath(vehicle_object)

	--? makes sure vehicle_object is not nil
	if not vehicle_object then
		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
		return nil, false
	end

	--? makes sure the vehicle_object has paths
	if not vehicle_object.path then
		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	if vehicle_object.path[1] then
		if vehicle_object.path[0] then
			s.removeMapID(-1, vehicle_object.path[0].ui_id)
		end
		vehicle_object.path[0] = {
			x = vehicle_object.path[1].x,
			y = vehicle_object.path[1].y,
			z = vehicle_object.path[1].z,
			ui_id = vehicle_object.path[1].ui_id
		}
		table.remove(vehicle_object.path, 1)
	end

	return #vehicle_object.path, true
end

---@param vehicle_object vehicle_object[] the vehicle you want to add the path for
---@param target_dest SWMatrix the destination for the path
function Pathfinding.addPath(vehicle_object, target_dest)

	-- path tags to exclude
	local exclude = ""

	if g_savedata.info.mods.NSO then
		exclude = "not_NSO" -- exclude non NSO graph nodes
	else
		exclude = "NSO" -- exclude NSO graph nodes
	end

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then 
		AI.setState(vehicle_object, VEHICLE.STATE.STATIONARY)
		return

	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
		local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		-- makes sure only small ships can take the tight areas
		
		if vehicle_object.size ~= "small" then
			exclude = exclude..",tight_area"
		end

		-- calculates route
		local path_list = s.pathfind(path_start_pos, m.translation(target_dest[13], 0, target_dest[15]), "ocean_path", exclude)

		for path_index, path in pairs(path_list) do
			if not path.y then
				path.y = 0
			end
			if path.y > 1 then
				break
			end 
			table.insert(vehicle_object.path, { 
				x = path.x, 
				y = path.y, 
				z = path.z, 
				ui_id = s.getMapID() 
			})
		end
	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
		local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		start_x, start_y, start_z = m.position(vehicle_object.transform)

		local exclude_offroad = false

		local squad_index, squad = Squad.getSquad(vehicle_object.id)
		if squad.command == SQUAD.COMMAND.CARGO then
			for c_vehicle_id, c_vehicle_object in pairs(squad.vehicles) do
				if g_savedata.cargo_vehicles[c_vehicle_id] then
					exclude_offroad = not g_savedata.cargo_vehicles[c_vehicle_id].route_data.can_offroad
					break
				end
			end
		end

		if not vehicle_object.can_offroad or exclude_offroad then
			exclude = exclude..",offroad"
		end

		local vehicle_list_id = sm.getVehicleListID(vehicle_object.name)
		local y_modifier = g_savedata.vehicle_list[vehicle_list_id].vehicle.transform[14]

		local dest_at_vehicle_y = m.translation(target_dest[13], vehicle_object.transform[14], target_dest[15])

		local path_list = s.pathfind(path_start_pos, dest_at_vehicle_y, "land_path", exclude)
		for path_index, path in pairs(path_list) do

			local path_matrix = m.translation(path.x, path.y, path.z)

			local distance = m.distance(vehicle_object.transform, path_matrix)

			if path_index ~= 1 or #path_list == 1 or m.distance(vehicle_object.transform, dest_at_vehicle_y) > m.distance(dest_at_vehicle_y, path_matrix) and distance >= 7 then
				
				if not path.y then
					--d.print("not path.y\npath.x: "..tostring(path.x).."\npath.y: "..tostring(path.y).."\npath.z: "..tostring(path.z), true, 1)
					break
				end

				table.insert(vehicle_object.path, { 
					x =  path.x, 
					y = (path.y + y_modifier), 
					z = path.z, 
					ui_id = s.getMapID() 
				})
			end
		end

		if #vehicle_object.path > 1 then
			-- remove paths which are a waste (eg, makes the vehicle needlessly go backwards when it could just go to the next waypoint)
			local next_path_matrix = m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)
			if m.xzDistance(vehicle_object.transform, next_path_matrix) < m.xzDistance(m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), next_path_matrix) then
				p.nextPath(vehicle_object)
			end
		end
	else
		table.insert(vehicle_object.path, { 
			x = target_dest[13], 
			y = target_dest[14], 
			z = target_dest[15], 
			ui_id = s.getMapID() 
		})
	end
	vehicle_object.path[0] = {
		x = vehicle_object.transform[13],
		y = vehicle_object.transform[14],
		z = vehicle_object.transform[15],
		ui_id = s.getMapID()
	}

	AI.setState(vehicle_object, VEHICLE.STATE.PATHING)
end

-- Credit to woe
function Pathfinding.updatePathfinding()
	local old_pathfind = server.pathfind --temporarily remember what the old function did
	local old_pathfindOcean = server.pathfindOcean
	function server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --permanantly do this new function using the old name.
		local path = old_pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --do the normal old function
		--d.print("(updatePathfinding) getting path y", true, 0)
		return p.getPathY(path) --add y to all of the paths.
	end
	function server.pathfindOcean(matrix_start, matrix_end)
		local path = old_pathfindOcean(matrix_start, matrix_end)
		return p.getPathY(path)
	end
end

local path_res = "%0.1f"

-- Credit to woe
function Pathfinding.getPathY(path)
	if not g_savedata.graph_nodes.init then --if it has never built the node's table
		p.createPathY() --build the table this one time
		g_savedata.graph_nodes.init = true --never build the table again unless you run traverse() manually
	end
	for each in pairs(path) do
		--d.print("(p.getPathY) x: "..((path_res):format(path[each].x)).."\nz: "..((path_res):format(path[each].z)), true, 0)
		if g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)] and g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
		end
	end
	return path --return the path with the added, or not, y values.
end

-- Credit to woe
function Pathfinding.createPathY() --this looks through all env mods to see if there is a "zone" then makes a table of y values based on x and z as keys.

	local isGraphNode = function(tag)
		if tag == "land_path" or tag == "ocean_path" then
			return tag
		end
		return false
	end

	local start_time = s.getTimeMillisec()
	d.print("Creating Path Y...", true, 0)
	local total_paths = 0
	local empty_matrix = m.translation(0, 0, 0)
	for addon_index = 0, s.getAddonCount() - 1 do
		local ADDON_DATA = s.getAddonData(addon_index)
		if ADDON_DATA.location_count and ADDON_DATA.location_count > 0 then
			for location_index = 0, ADDON_DATA.location_count - 1 do
				local LOCATION_DATA = s.getLocationData(addon_index, location_index)
				if LOCATION_DATA.env_mod and LOCATION_DATA.component_count > 0 then
					for component_index = 0, LOCATION_DATA.component_count - 1 do
						local COMPONENT_DATA, getLocationComponentData = s.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then
								local transform_matrix, gotTileTransform = s.getTileTransform(
									empty_matrix, LOCATION_DATA.tile, 100000
								)
								if gotTileTransform then
									local real_transform = matrix.multiplyXZ(COMPONENT_DATA.transform, transform_matrix)
									local x = (path_res):format(real_transform[13])
									local last_tag = COMPONENT_DATA.tags[#COMPONENT_DATA.tags]
									g_savedata.graph_nodes.nodes[x] = g_savedata.graph_nodes.nodes[x] or {}
									g_savedata.graph_nodes.nodes[x][(path_res):format(real_transform[15])] = { 
										y = real_transform[14],
										type = graph_node,
										NSO = last_tag == "NSO" and 1 or last_tag == "not_NSO" and 2 or 0
									}
									total_paths = total_paths + 1
								end
							end
						end
					end
				end
			end
		end
	end
	d.print("Got Y level of all paths\nNumber of nodes: "..total_paths.."\nTime taken: "..(millisecondsSince(start_time)/1000).."s", true, 0)
end
 -- functions for pathfinding -- functions relating to Players -- functions for script/world setup. -- functions relating to their AI
--[[


	Library Setup


]]

-- required libraries
-- required libraries

-- library name
Squad = {}

---@param vehicle_id integer the id of the vehicle you want to get the squad ID of
---@return integer squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---@return squad[] squad the info of the squad, if not found, then returns nil
function Squad.getSquad(vehicle_id) -- input a vehicle's id, and it will return the squad index its from and the squad's data
	local squad_index = g_savedata.ai_army.squad_vehicles[vehicle_id]
	if squad_index then
		local squad = g_savedata.ai_army.squadrons[squad_index]
		if squad then
			return squad_index, squad
		else
			return squad_index, nil
		end
	else
		return nil, nil
	end
end

---@param vehicle_id integer the vehicle's id
---@return vehicle_object vehicle_object the vehicle object, nil if not found
---@return integer squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---@return squad[] squad the info of the squad, if not found, then returns nil
function Squad.getVehicle(vehicle_id) -- input a vehicle's id, and it will return the vehicle_object, the squad index its from and the squad's data

	local squad_index = nil
	local squad = nil

	if not vehicle_id then -- makes sure vehicle id was provided
		d.print("(Squad.getVehicle) vehicle_id is nil!", true, 1)
		return nil, nil, nil
	else
		squad_index, squad = Squad.getSquad(vehicle_id)
	end

	if not squad_index or not squad then -- if we were not able to get a squad index then return nil
		return nil, nil, nil
	end

	if not g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id] then
		d.print("(Squad.getVehicle) failed to get vehicle_object for vehicle with id "..tostring(vehicle_id).." and in a squad with the id of "..tostring(squad_index).." and with the vehicle_type of "..tostring(squad.vehicle_type), true, 1)
	end

	return g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id], squad_index, squad
end

---@param squad_index integer the squad's index which you want to create it under, if not specified it will use the next available index
---@param vehicle_object vehicle_object the vehicle object which is adding to the squad
---@return integer squad_index the index of the squad
---@return boolean squad_created if the squad was successfully created
function Squad.createSquadron(squad_index, vehicle_object)

	local squad_index = squad_index or #g_savedata.ai_army.squadrons + 1

	if not vehicle_object then
		d.print("(Squad.createSquadron) vehicle_object is nil!", true, 1)
		return squad_index, false
	end

	if g_savedata.ai_army.squadrons[squad_index] then
		d.print("(Squad.createSquadron) Squadron "..tostring(squad_index).." already exists!", true, 1)
		return squad_index, false
	end

	g_savedata.ai_army.squadrons[squad_index] = { 
		command = SQUAD.COMMAND.NONE,
		index = squad_index,
		vehicle_type = vehicle_object.vehicle_type,
		role = vehicle_object.role,
		vehicles = {},
		target_island = nil,
		target_players = {},
		target_vehicles = {},
		investigate_transform = nil
	}

	return squad_index, true
end
-- required libraries
-- This library is for the main objectives in Conquest Mode, such as getting the AI's island they want to attack.

--[[


	Library Setup


]]

-- required libraries

-- library name
Objective = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

---@param ignore_scouted boolean true if you want to ignore islands that are already fully scouted
---@return table target_island returns the island which the ai should target
---@return table origin_island returns the island which the ai should attack from
function Objective.getIslandToAttack(ignore_scouted)
	local origin_island = nil
	local target_island = nil
	local target_best_distance = nil

	-- go through all non enemy owned islands
	for island_index, island in pairs(g_savedata.islands) do
		if island.faction ~= ISLAND.FACTION.AI then

			-- go through all enemy owned islands, to check if we should attack from there
			for ai_island_index, ai_island in pairs(g_savedata.islands) do
				if ai_island.faction == ISLAND.FACTION.AI or ignore_scouted and g_savedata.ai_knowledge.scout[island.name].scouted >= scout_requirement then
					if not ignore_scouted or g_savedata.ai_knowledge.scout[island.name].scouted < scout_requirement then
						if not target_island then
							origin_island = ai_island
							target_island = island
							if island.faction == ISLAND.FACTION.PLAYER then
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)/1.5
							else
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)
							end
						elseif island.faction == ISLAND.FACTION.PLAYER then -- if the player owns the island we are checking
							if target_island.faction == ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform) < target_best_distance then -- if the player also owned the island that we detected was the best to attack
								origin_island = ai_island
								target_island = island
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)
							elseif target_island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform)/1.5 < target_best_distance then -- if the player does not own the best match for an attack target so far
								origin_island = ai_island
								target_island = island
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)/1.5
							end
						elseif island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform) < target_best_distance then -- if the player does not own the island we are checking
							origin_island = ai_island
							target_island = island
							target_best_distance = m.xzDistance(ai_island.transform, island.transform)
						end
					end
				end
			end
		end
	end


	if not target_island then
		origin_island = g_savedata.ai_base_island
		for island_index, island in pairs(g_savedata.islands) do
			if island.faction ~= ISLAND.FACTION.AI or ignore_scouted and g_savedata.ai_knowledge.scout[island.name].scouted >= scout_requirement then
				if not ignore_scouted or g_savedata.ai_knowledge.scout[island.name].scouted < scout_requirement then
					if not target_island then
						target_island = island
						if island.faction == ISLAND.FACTION.PLAYER then
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)/1.5
						else
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)
						end
					elseif island.faction == ISLAND.FACTION.PLAYER then
						if target_island.faction == ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform) < target_best_distance then -- if the player also owned the island that we detected was the best to attack
							target_island = island
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)
						elseif target_island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform)/1.5 < target_best_distance then -- if the player does not own the best match for an attack target so far
							target_island = island
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)/1.5
						end
					elseif island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform) < target_best_distance then -- if the player does not own the island we are checking
						target_island = island
						target_best_distance = m.xzDistance(origin_island.transform, island.transform)
					end
				end
			end
		end
	end
	return target_island, origin_island
end


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
				sm.train(PUNISH, "attack", 5) -- we can no longer spawn attack vehicles
				sm.train(PUNISH, "attack", 5)
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
				if is.canSpawn(island, selected_prefab) then
					if not lowest_defenders or island.defenders < lowest_defenders then -- choose the island with the least amount of defence (A)
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
								if m.xzDistance(player_island.transform, selected_spawn_transform) > m.xzDistance(player_island.transform, island_transform) then
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
			selected_spawn = g_savedata.ai_base_island.index
		else
			d.print("(Vehicle.spawn) was unable to find island to spawn at!\nIsland Index: "..selected_spawn.."\nVehicle Type: "..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "").."\nVehicle Role: "..Tags.getValue(selected_prefab.vehicle.tags, "role", true), true, 1)
			return false, "was unable to find island to spawn at"
		end
	end

	local island = g_savedata.ai_base_island.index == selected_spawn and g_savedata.ai_base_island or g_savedata.islands[selected_spawn]

	if not island then
		d.print(("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true)), false, 1)
		return false, ("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true))
	end

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

		if #island.zones.turrets == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no turret spawn zones!"):format(island.name), true, 1)
			return false, ("Island %s has no turret spawn zones!"):format(island.name)
		end

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

		if #unoccupied_zones == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true)), true, 1)
			return false, ("Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true))
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
			main_body = Tags.getValue(selected_prefab.vehicle.tags, "main_body") or 0,
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
			driving = { -- used for driving the vehicle itself, holds special data depending on the vehicle type
				ui_id = s.getMapID()
			},
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

	--[[if vehicle_object.is_killed ~= true and not kill_instantly then
		d.print(debug_prefix.."Vehicle "..tostring(vehicle_id).." is already killed!", true, 1)
		return false
	end]]

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
---@param vehicle_object vehicle_object[] the vehicle data for the first cargo trip
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
					movement_speed = Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed") or VEHICLE.SPEED.BOAT
				elseif vehicle_type == VEHICLE.TYPE.PLANE then
					movement_speed = Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed") or VEHICLE.SPEED.PLANE
				elseif vehicle_type == VEHICLE.TYPE.HELI then
					movement_speed = Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed") or VEHICLE.SPEED.HELI
				elseif vehicle_type == VEHICLE.TYPE.LAND then
					movement_speed = Tags.getValue(vehicle_object.vehicle.tags, "road_speed_normal") or Tags.getValue(vehicle_object.vehicle.tags, "pseudo_speed") or VEHICLE.SPEED.LAND
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
						--
						total_travel_time[first_path_island_index].land = 
						(total_travel_time[first_path_island_index].land or 0) + 
						(first_path_island.distance.land/transport_vehicle.land.movement_speed)
						--
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
									--
									total_travel_time[first_path_island_index][second_path_island_index].land = 
									(total_travel_time[first_path_island_index].land or 0) + 
									(second_path_island.distance.land/transport_vehicle.land.movement_speed)
									--
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
												--
												total_travel_time[first_path_island_index][second_path_island_index][third_path_island_index].land = 
												(total_travel_time[first_path_island_index][second_path_island_index].land or 0) + 
												(third_path_island.distance.land/transport_vehicle.land.movement_speed)
												--
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
	local prefab_data = sm.spawn(true, "cargo", vehicle_type)
	if not prefab_data then
		d.print("(Cargo.getTransportVehicle) prefab_data is nil! vehicle_type: "..tostring(vehicle_type), true, 1)
		return
	else
		prefab_data.name = prefab_data.location.data.name
	end
	return prefab_data
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
				if #island1.zones.land > 0 then
				
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
 -- functions relating to the Convoys and Cargo Vehicles -- functions relating to islands -- functions for the main objectives. -- functions relating to the Adaptive AI -- functions for squads -- functions related to vehicles, and parsing data on them -- custom math functions -- custom string functions -- custom table functions

--[[
		Functions
--]]

function setupRules()
	d.print("Setting up rules...", true, 0)
	--* holds non configurable settings
	--* made to make all the rules to be in one organised consistant place
	RULES = {
		LOGISTICS = { --? for the logistics/cargo AI
			CARGO = { --? cargo specific rules

				transfer_time = time.minute * 3, -- how long it takes to transfer the cargo

				VEHICLES = { --? rules for the vehicles which transport the cargo
					spawn_time = time.minute * 38 -- how long after a cargo vehicle is killed can another be spawned
				},
				ISLANDS = { --? rules for the islands
					max_capacity = 10000 *  g_savedata.settings.CARGO_CAPACITY_MULTIPLIER, -- the max amount of each resource islands can hold
					ai_base_generation = 350 -- the amount of cargo the ai's main base can generate per hour
				}
			},
			CONVOY = { --? convoy specific rules
				min_escorts = 2, -- minimum amount of escorts in a convoy
				max_escorts = 4, -- maximum amount of escorts in a convoy
				base_wait_time = time.second * 45, -- the time a vehicle will wait till it just continues anyways
				boat = { --? rules specific for boats
					min_distance = 50, -- have the one behind stop
					target_distance = 150, -- + spawning distance of both vehicles
					max_distance = 400
				},
				land = { --? rules specific for land vehicles
					min_distance = 15,
					target_distance = 60, -- + spawning distance of both vehicles
					max_distance = 120
				},
				plane = { --? rules specific for planes
					min_distance = 75, -- make the one in front have its target altitude be higher
					target_distance = 250, -- + spawning distance of both vehicles 
					max_distance = 1000 -- lots of buffer space, however, do not wait if one is falling behind
				},
				heli = { --? rules specific for helis
					min_distance = 55, -- make the one behind stop moving so it gives it space
					target_distance = 150, -- + spawning distance of both vehicles
					max_distance = 450 -- have them wait for the one which is behind
				}
			},
			COSTS = {
				RESOURCE_VALUES = { -- how much each litre of resource is worth
					oil = 10, -- non jet or diesel vehicles (turrets, electric vehicles, etc)
					diesel = 10, -- diesel vehicles
					jet_fuel = 10 -- jet vehicles
				}
			}
		},
		SETTINGS = { --? for the settings command
			--[[
			EXAMPLE = { -- the setting variable itself
				min = { -- set to nil to ignore
					value = 0, -- if they're trying to set the setting below or at this value, it will warn them
					message = "This can cause the ai to have 0 health, causing them to be instantly killed"
				}, 
				max = { -- set to nil to ignore
					value = 100, -- if they're trying to set the setting above or at this value, it will warn them
					message = "This can cause the ai to have infinite health, causing them to never be killed"
				},
				input_multiplier = time.minute -- the multiplier for the input, so they can enter in minutes instead of ticks, for example
			}
			]]
			ENEMY_HP_MODIFIER = {
				min = {
					value = 0,
					message = "the AI to have 0 health, causing them to be instantly killed without taking any damage."
				},
				max = nil,
				input_multiplier = 1
			},
			AI_PRODUCTION_TIME_BASE = {
				min = {
					value = 0,
					message = "the AI to produce vehicles instantly, causing a constant tps drop and possibly crashing your game."
				},
				max = nil,
				input_multiplier = time.minute
			},
			CAPTURE_TIME = {
				min = {
					value = 0,
					message = "all of the islands to constantly switch factions, creating a huge tps drop due to the amount of notifcation windows, or for no islands to be capturable, or for all islands to be suddenly given to the player."
				},
				max = nil,
				input_multiplier = time.minute
			},
			ISLAND_COUNT = {
				min = {
					value = 1,
					message = "the addon breaking completely and permanently. There needs to be at least 2 islands, 1 for ai's main base, 1 for your main base, this can cause issues."
				},
				max = {
					value = 22,
					message = "improper calculations and lower performance. There are currently only 21 islands which you can have, setting it above 21 can cause issues."
				},
				input_multiplier = 1
			},
			CARGO_GENERATION_MULTIPLIER = {
				min = {
					value = 0,
					message = "no cargo being generated. If you want to disable cargo, do \"?impwep setting CARGO_MODE false\" instead."
				},
				max = nil,
				input_multiplier = 1
			},
			CARGO_CAPACITY_MULTIPLIER = {
				min = {
					value = 0,
					message = "no cargo being stored or generated at islands. If you want to disable cargo mode, do \"?impwep setting CARGO_MODE false\" instead."
				},
				max = nil,
				input_multiplier = 1
			}
		}
	}
end

function warningChecks(peer_id)
	-- check for if they have the weapons dlc enabled

	if not s.dlcWeapons() then
		d.print("ERROR: it seems you do not have the weapons dlc enabled, or you do not have the weapon dlc, the addon will not function!", false, 1, peer_id)
	end
	
	-- check if they left the default addon enabled
	if g_savedata.info.addons.default_conquest_mode then
		d.print("ERROR: The default addon for conquest mode was left enabled! This will cause issues and bugs! Please create a new world with the default addon disabled!", false, 1, peer_id)
		is_dlc_weapons = false

	elseif not g_savedata.info.addons.ai_paths then
		d.print("ERROR: The AI Paths addon was left disabled! This addon uses it for pathfinding for the ships, you may have issues with the ship's pathfinding! Please make a new world with the \"AI Paths\" Addon enabled", false, 1, peer_id)
	end

	-- if they are in a development verison
	if IS_DEVELOPMENT_VERSION then
		d.print("Hey! Thanks for using and testing a development version! Just note you will very likely experience errors!", false, 0, peer_id)
		--d.print("VERY COOL DEBUG VERSION!", false, 0, peer_id)
	end

	-- get version data, to check if world is outdated
	--[[local version_data, is_success = comp.getVersionData()
	if version_data.is_outdated then
		d.print("ERROR: world seems to be outdated, this shouldn't be possible!", false, 1, peer_id)
		--[[
		if IS_COMPATIBLE_WITH_OLDER_VERSIONS == "FALSE" then
			d.print("WARNING: This world is outdated, and this version has been marked as uncompatible with older worlds! If you encounter any errors, try using \"?impwep full_reload\", however this command is very dangerous, and theres no guarentees it will fix the issue", false, 1, peer_id)
		elseif IS_COMPATIBLE_WITH_OLDER_VERSIONS == "FULL_RELOAD" then
			d.print("WARNING: This world is outdated, and this version has been marked as uncompatible with older worlds! However, this is fixable via ?impwep full_reload (tested).", false, 1, peer_id)
		end
	end]]

	if g_savedata.info.mods.NSO then
		d.print("ICM has automatically detected the use of the NSO mod. ICM has official support for NSO, so things have been moved around and added to give a great experience with NSO.", false, 0, peer_id)
	end
end

-- checkbox settings
local PERFORMANCE_MODE = property.checkbox("Performance Mode (Disables tracebacks.)", "true")
local SINKING_MODE = property.checkbox("Sinking Mode (Ships sink then explode)", "true")
local ISLAND_CONTESTING = property.checkbox("Point Contesting (Factions can block eachothers progress)", "true")
local CARGO_MODE = property.checkbox("Cargo Mode (AI needs to transport resources to make more vehicles)", "true")
local AIR_CRASH_MODE = property.checkbox("Air Crash Mode (Air vehicles explode whenever they crash)", "true")
local PAUSE_WHEN_NONE_ONLINE = property.checkbox("Pause the addon when nobody's online (For dedicated servers - so the AI doesn't keep advancing when people are asleep.)", "true")

function onCreate(is_world_create)

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	-- setup settings
	if not g_savedata.settings then
		g_savedata.settings = {
			PERFORMANCE_MODE = PERFORMANCE_MODE,
			SINKING_MODE = SINKING_MODE,
			CONTESTED_MODE = ISLAND_CONTESTING,
			CARGO_MODE = CARGO_MODE,
			AIR_CRASH_MODE = AIR_CRASH_MODE,
			ENEMY_HP_MODIFIER = property.slider("AI HP Modifier", 0.1, 10, 0.1, 1),
			AI_PRODUCTION_TIME_BASE = property.slider("AI Production Time (Mins)", 1, 60, 1, 15) * 60 * 60,
			CAPTURE_TIME = property.slider("AI Capture Time (Mins) | Player Capture Time (Mins) / 5", 10, 600, 1, 60) * 60 * 60,
			MAX_BOAT_AMOUNT = property.slider("Max amount of AI Ships", 0, 40, 1, 10),
			MAX_LAND_AMOUNT = property.slider("Max amount of AI Land Vehicles", 0, 40, 1, 10),
			MAX_PLANE_AMOUNT = property.slider("Max amount of AI Planes", 0, 40, 1, 10),
			MAX_HELI_AMOUNT = property.slider("Max amount of AI Helicopters", 0, 40, 1, 10),
			MAX_TURRET_AMOUNT = property.slider("Max amount of AI Turrets (Per Island)", 0, 7, 1, 3),
			AI_INITIAL_SPAWN_COUNT = property.slider("AI Initial Spawn Count", 0, 30, 1, 5),
			AI_INITIAL_ISLAND_AMOUNT = property.slider("Starting Amount of AI Bases (not including main bases)", 0, 23, 1, 4),
			ISLAND_COUNT = property.slider("Island Count", 7, 25, 1, 25),
			CARGO_GENERATION_MULTIPLIER = property.slider("Cargo Generation Multiplier (multiplies cargo generated by this)", 0.1, 5, 0.1, 1),
			CARGO_CAPACITY_MULTIPLIER = property.slider("Cargo Capacity Multiplier (multiplier for capacity of each island)", 0.1, 5, 0.1, 1),
			PAUSE_WHEN_NONE_ONLINE = PAUSE_WHEN_NONE_ONLINE,
		}

		g_savedata.debug.traceback.default = not g_savedata.settings.PERFORMANCE_MODE
	end

	comp.verify() -- backwards compatibility check

	is_dlc_weapons = s.dlcWeapons()

	-- checks for Vanilla Conquest Mode addon
	local addon_index, is_success = s.getAddonIndex("DLC Weapons AI")
	if is_success then
		g_savedata.info.addons.default_conquest_mode = true
		is_dlc_weapons = false
	end

	-- checks for AI Paths addon
	local addon_index, is_success = s.getAddonIndex("AI Paths")
	if is_success then
		g_savedata.info.addons.ai_paths = true
	end

	-- check for NSO mod
	local nso_tile, got_nso_tile = s.getTile(m.translation(-8000, 0, -12000))
	g_savedata.info.mods.NSO = got_nso_tile and nso_tile.cost > 0

	warningChecks(-1)

	if is_dlc_weapons then

		s.announce("Loading Script: " .. s.getAddonData((s.getAddonIndex())).name, "Complete, Version: "..ADDON_VERSION, 0)

		setupRules()
		
		p.updatePathfinding()

		d.print("building locations...", true, 0)

		for i in iterPlaylists() do
			for j in iterLocations(i) do
				build_locations(i, j)
			end
		end

		-- reset vehicle list
		g_savedata.vehicle_list = {}

		d.print("building prefabs...", true, 0)

		for i = 1, #built_locations do
			buildPrefabs(i)
		end

		if is_world_create then
			d.print("setting up world...", true, 0)

			d.print("getting y level of all graph nodes...", true, 0)

			--[[ 
				cause createPathY to execute, which will get the y level of all graph nodes
				otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
				instead it looks like its taking a bit longer to create the world.
			]]
			s.pathfind(m.translation(0, 0, 0), m.translation(0, 0, 0), "", "") 

			d.print("setting up spawn zones...", true, 0)

			local spawn_zones = sup.spawnZones()

			-- add them to a list indexed by which island the zone belongs to
			local tile_zones = sup.sortSpawnZones(spawn_zones)

			d.print("populating constructable vehicles with spawning modifiers...", true, 0)

			sm.create()

			local start_island = s.getStartIsland()

			d.print("creating player's main base...", true, 0)

			-- init player base
			local islands = s.getZones("capture")

			-- filter NSO and non NSO exclusive islands
			for island_index, island in pairs(islands) do
				if not g_savedata.info.mods.NSO and Tags.has(island.tags, "NSO") then
					d.print("removed "..island.name.." because it is NSO exclusive", true, 0)
					table.remove(islands, island_index)
				elseif g_savedata.info.mods.NSO and Tags.has(island.tags, "not_NSO") then
					table.remove(islands, island_index)
					d.print("removed "..island.name.." because it's incompatible with NSO", true, 0)
				end
			end

			for island_index, island in ipairs(islands) do

				local island_tile = s.getTile(island.transform)
				if island_tile.name == start_island.name or (island_tile.name == "data/tiles/island_43_multiplayer_base.xml" and g_savedata.player_base_island == nil) then
					if not Tags.has(island, "not_main_base") then
						local flag = s.spawnAddonComponent(m.multiply(island.transform, m.translation(0, 4.55, 0)), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
						---@class PLAYER_ISLAND
						g_savedata.player_base_island = {
							name = island.name,
							index = island_index,
							flag_vehicle = flag,
							transform = island.transform,
							tags = island.tags,
							faction = ISLAND.FACTION.PLAYER,
							is_contested = false,
							capture_timer = g_savedata.settings.CAPTURE_TIME, 
							ui_id = s.getMapID(),
							assigned_squad_index = -1,
							ai_capturing = 0,
							players_capturing = 0,
							defenders = 0,
							is_scouting = false,
							last_defended = 0,
							cargo = {
								oil = 0,
								jet_fuel = 0,
								diesel = 0
							},
							cargo_transfer = {
								oil = 0,
								jet_fuel = 0,
								diesel = 0
							},
							object_type = "island"
						}
						
						-- only break if the island's name is the same as the island the player is starting at
						-- as breaking if its the multiplayer base could cause the player to always start at the multiplayer base in specific scenarios
						if island_tile.name == start_island.name then
							break
						end
					end
				end
			end

			islands[g_savedata.player_base_island.index] = nil

			d.print("creating ai's main base...", true, 0)


			-- get all possible AI base islands and put them into a table along with their distance
			local possible_ai_islands = {}
			for island_index, island in pairs(islands) do
				local distance = m.xzDistance(island.transform, g_savedata.player_base_island.transform)
				if not Tags.has(island.tags, "not_main_base") and not Tags.has(island.tags, "not_main_base_ai") then
					table.insert(possible_ai_islands, {
						distance = distance,
						index = island_index
					})
				end
			end
			-- sort all the islands by distance, greatest to least
			table.sort(possible_ai_islands, function(a, b) return a.distance > b.distance end)

			-- set the ai's main base as a random one of the furthest 25% of the islands
			local ai_base_index = possible_ai_islands[math.random(math.ceil(#possible_ai_islands * 0.25))].index

			-- haha harbour base override go brr
			--[[
			for island_index, island in pairs(islands) do
				if island.name == "Harbour Base" then
					ai_base_index = island_index
					d.print("haha harbour base override go brr", false, 0)
				end
			end
			]]

			d.print("AI base index:"..tostring(ai_base_index), true, 0)

			--* set up ai base

			local ai_island = islands[ai_base_index]

			local island_tile, is_success = s.getTile(ai_island.transform)

			local flag = s.spawnAddonComponent(m.multiply(ai_island.transform, m.translation(0, 4.55, 0)), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
			---@class AI_ISLAND
			g_savedata.ai_base_island = {
				name = ai_island.name,
				index = ai_base_index,
				flag_vehicle = flag,
				transform = ai_island.transform,
				tags = ai_island.tags,
				faction = ISLAND.FACTION.AI,
				is_contested = false,
				capture_timer = 0,
				ui_id = s.getMapID(),
				assigned_squad_index = -1,
				production_timer = 0,
				zones = {
					turrets = {},
					land = {},
					sea = {}
				},
				ai_capturing = 0,
				players_capturing = 0,
				defenders = 0,
				is_scouting = false,
				last_defended = 0,
				cargo = {
					oil = 0,
					jet_fuel = 1500,
					diesel = 1500
				},
				cargo_transfer = {
					oil = 0,
					jet_fuel = 0,
					diesel = 0
				},
				object_type = "island"
			}

			g_savedata.ai_base_island.zones = tile_zones[island_tile.name]

			islands[ai_base_index] = nil

			d.print("setting up remaining neutral islands...", true, 0)

			-- set up remaining neutral islands
			for island_index, island in pairs(islands) do
				local island_tile, is_success = s.getTile(island.transform)

				local flag = s.spawnAddonComponent(m.multiply(island.transform, m.translation(0, 4.55, 0)), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
				---@class ISLAND
				local new_island = {
					name = island.name,
					index = island_index,
					flag_vehicle = flag,
					transform = island.transform,
					tags = island.tags,
					faction = ISLAND.FACTION.NEUTRAL,
					is_contested = false,
					capture_timer = g_savedata.settings.CAPTURE_TIME / 2,
					ui_id = s.getMapID(),
					assigned_squad_index = -1,
					zones = {
						turrets = {},
						land = {},
						sea = {}
					},
					ai_capturing = 0,
					players_capturing = 0,
					defenders = 0,
					is_scouting = false,
					last_defended = 0,
					cargo = {
						oil = 0,
						jet_fuel = 0,
						diesel = 0
					},
					cargo_transfer = {
						oil = 0,
						jet_fuel = 0,
						diesel = 0
					},
					object_type = "island"
				}

				new_island.zones = tile_zones[island_tile.name]

				g_savedata.islands[new_island.index] = new_island
				d.print("Setup island: "..new_island.index.." \""..island.name.."\"", true, 0)

				-- stop creating new islands if we've reached the island limit
				if(#g_savedata.islands >= g_savedata.settings.ISLAND_COUNT) then
					break
				end
			end

			d.print("setting up additional data...")

			-- sets up their positions for sweep and prune
			for island_index, island in pairs(g_savedata.islands) do
				table.insert(g_savedata.sweep_and_prune.flags.x, { 
					island_index = island.index, 
					x = island.transform[13]
				})
				table.insert(g_savedata.sweep_and_prune.flags.z, { 
					island_index = island.index, 
					z = island.transform[15]
				})
			end
			-- sort the islands from least to most by their x coordinate
			table.sort(g_savedata.sweep_and_prune.flags.x, function(a, b) return a.x < b.x end)
			-- sort the islands from least to most by their z coordinate
			table.sort(g_savedata.sweep_and_prune.flags.z, function(a, b) return a.z < b.z end)

			-- sets up scouting data
			for _, island in pairs(g_savedata.islands) do
				table.tabulate(g_savedata.ai_knowledge.scout, island.name)
				g_savedata.ai_knowledge.scout[island.name].scouted = 0
			end

			-- game setup
			for i = 1, g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT do
				if i <= #g_savedata.islands - 2 then
					local t, a = Objective.getIslandToAttack()
					t.capture_timer = 0 -- causes the AI to capture nearest ally
					t.faction = ISLAND.FACTION.AI
					t.cargo = {
						oil = math.random(350, 1000),
						jet_fuel = math.random(350, 1000),
						diesel = math.random(350, 1000)
					}
				end
			end

			d.print("completed setting up world!", true, 0)

			d.print("spawning initial ai vehicles...", true, 0)
				
			for i = 1, g_savedata.settings.AI_INITIAL_SPAWN_COUNT * math.ceil(math.min(math.max(g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT, 1), #g_savedata.islands - 1)/2) do
				v.spawnRetry(nil, nil, true, nil, nil, 5) -- spawn initial ai
			end
			d.print("all initial ai vehicles spawned!")
		else
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(-1, vehicle_object.ui_id)
					s.removeMapLabel(-1, vehicle_object.ui_id)
					s.removeMapLine(-1, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end
				end
			end
			s.removeMapObject(-1, g_savedata.player_base_island.ui_id)
			s.removeMapObject(-1, g_savedata.ai_base_island.ui_id)
		end
	end
	d.print(("%s%.3f%s"):format("World setup complete! took: ", millisecondsSince(world_setup_time)/1000, "s"), true, 0)

	for debug_type, debug_setting in pairs(g_savedata.debug) do
		if (debug_setting.needs_setup_on_reload and debug_setting.enabled) or (is_world_create and debug_setting.default) then
			local debug_id = d.debugIDFromType(debug_type)

			if debug_setting.needs_setup_on_reload then
				d.handleDebug(debug_id, true, 0)
			end

			d.setDebug(debug_id, -1, true)
		end
	end
end

function buildPrefabs(location_index)
	local location = built_locations[location_index]

	-- construct vehicle-character prefab list
	local vehicle_index = #g_savedata.vehicle_list + 1 or 1
	for key, vehicle in pairs(location.objects.vehicles) do

		local prefab_data = {
			location = location, 
			vehicle = vehicle, 
			survivors = {}, 
			fires = {}
		}

		for key, char in pairs(location.objects.survivors) do
			table.insert(prefab_data.survivors, char)
		end

		for key, fire in pairs(location.objects.fires) do
			table.insert(prefab_data.fires, fire)
		end

		
		if Tags.has(vehicle.tags, "vehicle_type=wep_turret") or #prefab_data.survivors > 0 then
			table.insert(g_savedata.vehicle_list, vehicle_index, prefab_data)
			g_savedata.vehicle_list[vehicle_index].role = Tags.getValue(vehicle.tags, "role", true) or "general"
			g_savedata.vehicle_list[vehicle_index].vehicle_type = string.gsub(Tags.getValue(vehicle.tags, "vehicle_type", true), "wep_", "") or "unknown"
			g_savedata.vehicle_list[vehicle_index].strategy = Tags.getValue(vehicle.tags, "strategy", true) or "general"
		end

		--
		--
		-- <<<<<<<<<< get vehicles, and put them into a table, sorted by their directive/role and their type, as well as additional info >>>>>>>>>
		--
		--

		if #prefab_data.survivors > 0 then
			local varient = Tags.getValue(vehicle.tags, "varient")
			if not varient then
				local role = Tags.getValue(vehicle.tags, "role", true) or "general"
				local vehicle_type = string.gsub(Tags.getValue(vehicle.tags, "vehicle_type", true), "wep_", "") or "unknown"
				local strategy = Tags.getValue(vehicle.tags, "strategy", true) or "general"

				table.tabulate(g_savedata.constructable_vehicles, role, vehicle_type, strategy)

				local vehicle_exists = false
				local cv_id = nil

				for constructable_vehicle_id, constructable_vehicle_data in ipairs(g_savedata.constructable_vehicles[role][vehicle_type][strategy]) do
					if constructable_vehicle_data.id == vehicle_index then
						vehicle_exists = true
						cv_id = constructable_vehicle_id
						break
					end
				end

				if not vehicle_exists then
					table.insert(g_savedata.constructable_vehicles[role][vehicle_type][strategy], prefab_data)
				end
				
				g_savedata.constructable_vehicles[role][vehicle_type][strategy][#g_savedata.constructable_vehicles[role][vehicle_type][strategy]].id = vehicle_index
				d.print("set id: "..g_savedata.constructable_vehicles[role][vehicle_type][strategy][#g_savedata.constructable_vehicles[role][vehicle_type][strategy]].id.." | # of vehicles: "..#g_savedata.constructable_vehicles[role][vehicle_type][strategy].." vehicle name: "..g_savedata.constructable_vehicles[role][vehicle_type][strategy][#g_savedata.constructable_vehicles[role][vehicle_type][strategy]].location.data.name, true, 0)
			else
				table.tabulate(g_savedata.constructable_vehicles, varient)
				table.insert(g_savedata.constructable_vehicles["varient"], prefab_data)
			end
		end
	end
end

player_commands = {
	normal = {
		info = {
			short_desc = "prints info about the mod",
			desc = "prints some info about the mod in chat! including version, world creation version, times reloaded, ect. Really helpful if you attach the commands output in bug reports!",
			args = "none",
			example = "?impwep info",
		},
		help = {
			short_desc = "shows a list of all of the commands",
			desc = "shows a list of all of the commands, to learn more about a command, type to commands name after \"help\" to learn more about it",
			args = "[command]",
			example = "?impwep help info",
		}
	},
	admin = {
		reset = {
			short_desc = "reset's the ai's commands",
			desc = "this resets the ai's commands, this is helpful for testing and debugging mostly",
			args = "none",
			example = "?impwep reset",
		},
		speed = {
			short_desc = "lets you change ai's pseudo speed",
			desc = "this allows you to change the multiplier of the ai's pseudo speed, with the arg being the amount to times it by",
			args = "(multiplier)",
			example = "?impwep pseudo_speed 5",
		},
		vreset = {
			short_desc = "lets you reset an ai's state",
			desc = "this lets you reset an ai vehicle's state, such as holding, stationary, ect",
			args = "(vehicle_id)",
			example = "?impwep vreset 655",
		},
		target = {
			short_desc = "lets you change the ai's target",
			desc = "this lets you change what the ai is targeting, so they will attack it instead",
			args = "(vehicle_id)",
			example = "?impwep target 500",
		},
		spawn_vehicle = { -- spawn vehicle
			short_desc = "lets you spawn in an ai vehicle",
			desc = "this lets you spawn in a ai vehicle, if you dont specify one, it will spawn a random ai vehicle, and if you specify \"scout\", it will spawn a scout vehicle if it can spawn. specify x and y to spawn it at a certain location, or \"near\" and then a minimum distance and then a maximum distance",
			args = "[vehicle_id|vehicle_type|\"scout\"] [x & y|\"near\" & min_range & max_range] ",
			example = "?impwep sv Eurofighter\n?impwep sv Eurofighter -500 500\n?impwep sv Eurofighter near 1000 5000\n?impwep sv heli",
		},
		vehicle_list = { -- vehicle list
			short_desc = "prints a list of all vehicles",
			desc = " prints a list of all of the AI vehicles in the addon, also shows their formatted name, which is used in commands",
			args = "none",
			example = "?impwep vehicle_list",
		},
		debug = {
			short_desc = "enables or disables debug mode",
			desc = "lets you toggle debug mode, also shows all the AI vehicles on the map with tons of info. Valid debug types: \"all\", \"chat\", \"error\" \"profiler\", \"map\", \"graph_node\", \"driving\", \"vehicle\" and \"traceback\"",
			args = "(debug_type) [peer_id]",
			example = "?impwep debug all\n?impwep debug map 0",
		},
		st = { -- spawn turret
			short_desc = "spawns a turret at every enemy AI island",
			desc = "spawns a turret at every enemy AI island",
			args = "none",
			example = "?impwep st",
		},
		cp = { -- capture point
			short_desc = "allows you to change who owns a point",
			desc = "allows you to change who owns a specific island",
			args = "(island_name) (\"ai\"|\"neutral\"|\"player\")",
			example = "?impwep cp North_Harbour ai",
		},
		aimod = {
			short_desc = "lets you get an ai's spawning modifier",
			desc = "lets you see what an ai's role, type, strategy or vehicle's spawning modifier is",
			args = "(role) [type] [strategy] [constructable_vehicle_id]",
			example = "?impwep aimod attack heli general 0"
		},
		setmod = {
			short_desc = "lets you change an ai's spawning modifier",
			desc = "lets you change what the ai's role spawning modifier is, does not yet support type, strategy or constructable vehicle id",
			args = "(\"reward\"|\"punish\") (role) (modifier: 1-5)",
			example = "?impwep setmod reward attack 4"
		},
		delete_vehicle = { -- delete vehicle
			short_desc = "lets you delete an ai vehicle",
			desc = "lets you delete an ai vehicle by vehicle id, or all by specifying \"all\", or all vehicles that have been damaged by specifying \"damaged\"",
			args = "(vehicle_id|\"all\"|\"damaged\")",
			example = "?impwep delete_vehicle all"
		},
		teleport = { -- teleport vehicle
			short_desc = "lets you teleport an ai vehicle",
			desc = "lets you teleport an ai vehicle by vehicle id, to the specified x, y and z",
			args = "(vehicle_id) (x) (y) (z)",
			example = "?impwep teleport 50 100 10 -5000"
		},
		si = { -- set scout intel
			short_desc = "lets you set the ai's scout level",
			desc = "lets you set the ai's scout level on a specific island, from 0 to 100 for 0% scouted to 100% scouted",
			args = "(island_name) (0-100)",
			example = "?impwep si North_Harbour 100"
		},
		setting = {
			short_desc = "lets you change or get a specific setting and can get a list of all settings",
			desc = "if you do not input the setting name, it will show a list of all valid settings, if you input a setting name but not a value, it will tell you the setting's current value, if you enter both the setting name and the setting value, it will change that setting to that value",
			args = "[setting_name] [value]",
			example = "?impwep setting MAX_BOAT_AMOUNT 5\n?impwep setting MAX_BOAT_AMOUNT\n?impwep setting"
		},
		ai_knowledge = {
			short_desc = "shows the 3 vehicles it thinks is good against you",
			desc = "shows the 3 vehicles it thinks is good against you, and the 3 that it thinks is weak against you",
			args = "none",
			example = "?impwep ai_knowledge"
		},
		reset_cargo = {
			short_desc = "resets the ai's cargo storages",
			desc = "resets the all island cargo storages to 0 for each resource, leave island blank for all islands, leave cargo_type blank for all resources",
			args = "[island] [cargo_type]",
			example = "?impwep reset_cargo\n?impwep reset_cargo North_Harbour\n?impwep reset_cargo Garrison_Toddy oil"
		},
		debug_cache = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		debug_cargo1 = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		debug_cargo2 = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		clear_cache = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		addon_info = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		vision_reset = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		reset_prefabs = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		debugmigration = {
			short_desc = "",
			desc = "",
			args = "",
			example = ""
		},
		queueconvoy = {
			short_desc = "queues a convoy.",
			desc = "queues a convoy to be sent out, will be sent out once theres not any convoys.",
			args = "",
			example = "?icm queue_convoy"
		},
		airvehicleskamikaze = {
			short_desc = "kamikaze.",
			desc = "forces all air vehicles to have their target coordinates set to the target's position, when they have a target.",
			args = "",
			example = "?icm air_vehicles_kamikaze"
		},
		causeerror = {
			short_desc = "causes an error when the specified function is called.",
			desc = "causes an error when the specified function is called. Useful for debugging the traceback debug, or trying to reproduce an error.",
			args = "<function_name>",
			example = "?icm cause_error math.euclideanDistance"
		}
	},
	host = {}
}

command_aliases = {
	dbg = "debug",
	pseudospeed = "speed",
	sv = "spawnvehicle",
	dv = "deletevehicle",
	kill = "deletevehicle",
	capturepoint = "cp",
	capture = "cp",
	captureisland = "cp",
	spawnturret = "st",
	scoutintel = "si",
	setintel = "si",
	vl = "vehiclelist",
	listvehicles = "vehiclelist",
	tp = "teleport",
	teleport_vehicle = "teleport",
	kamikaze = "airvehicleskamikaze"
}

function onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)

	prefix = string.lower(prefix)

	--? if the command they're entering is not for this addon
	if prefix ~= "?impwep" and prefix ~= "?icm" then
		return
	end

	--? if they didn't enter a command
	if not command then
		d.print("you need to specify a command! use\n\"?impwep help\" to get a list of all commands!", false, 1, peer_id)
		return
	end

	--*---
	--* handle the command the player entered
	--*---

	command = string.friendly(command, true) -- makes the command friendly, removing underscores, spaces and captitals
	local arg = table.pack(...) -- this will supply all the remaining arguments to the function

	--? if dlc_weapons is disabled or the player does not have it (if in singleplayer)
	if not is_dlc_weapons then

		if not full_message:match("-f") then

			--? if vanilla conquest mode was left enabled
			if g_savedata.info.addons.default_conquest_mode then
				d.print("Improved Conquest Mode is disabled as you left Vanilla Conquest Mode enabled! Please create a new world and disable \"DLC Weapons AI\"", false, 1, peer_id)
			end

			d.print("Error: Improved Conquest Mode has been disabled.", false, 1, peer_id)

			return
		end

		d.print("Bypassed addon being disabled!", false, 0, peer_id)

		-- remove -f from the args

		for argument = 1, #arg do
			if arg[argument] == "-f" then
				table.remove(arg, argument)
			end
		end
	end

	--? if this command is an alias
	if command_aliases[command] then
		command = command_aliases[command]
	end

	-- 
	-- commands all players can execute
	--
	if command == "info" then
		d.print("------ Improved Conquest Mode Info ------", false, 0, peer_id)
		d.print("Version: "..ADDON_VERSION, false, 0, peer_id)
		if not g_savedata.info.addons.ai_paths then
			d.print("AI Paths Disabled (will cause ship pathfinding issues)", false, 1, peer_id)
		end

		local version_name, is_success = comp.getVersion(1)
		if not is_success then
			d.print("(command info) failed to get creation version", false, 1)
			return
		end

		local version_data, is_success = comp.getVersionData(version_name)
		if not is_success then
			d.print("(command info) failed to get version data of creation version", false, 1)
			return
		end
		d.print("World Creation Version: "..version_data.data_version, false, 0, peer_id)
		d.print("Times Addon Data has been Updated: "..tostring(#g_savedata.info.version_history and #g_savedata.info.version_history - 1 or 0), false, 0, peer_id)
		if g_savedata.info.version_history and #g_savedata.info.version_history ~= nil and #g_savedata.info.version_history ~= 0 then
			d.print("Version History", false, 0, peer_id)
			for i = 1, #g_savedata.info.version_history do
				local has_backup = g_savedata.info.version_history[i].backup_g_savedata 
				d.print(i..": "..tostring(g_savedata.info.version_history[i].version), false, 0, peer_id)
			end
		end
	end


	--
	-- admin only commands
	--
	if is_admin then
		if command == "reset" then
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
					if squad.command == SQUAD.COMMAND.DEFEND then
						squad.command = SQUAD.COMMAND.NONE
					end
				end
			end
			g_is_air_ready = true
			g_is_boats_ready = false
			g_savedata.is_attack = false
			d.print("reset all squads", false, 0, peer_id)

		elseif command == "speed" then
			d.print("set speed multiplier from "..tostring(g_debug_speed_multiplier).." to "..tostring(arg[1]), false, 0, peer_id)
			g_debug_speed_multiplier = arg[1]

		elseif command == "vreset" then
			s.resetVehicleState(arg[1])

		elseif command == "target" then
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					for i, char in  pairs(vehicle_object.survivors) do
						s.setAITargetVehicle(char.id, arg[1])
					end
				end
			end

		elseif command == "visionreset" then
			d.print("resetting all squad vision data", false, 0, peer_id)
			for squad_index, squad in pairs(g_savedata.squadrons) do
				squad.target_players = {}
				squad.target_vehicles = {}
			end
			d.print("reset all squad vision data", false, 0, peer_id)
			
		elseif command == "spawnvehicle" then --spawn vehicle

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

			if not vehicle_id and arg[1] ~= "scout" and arg[1] ~= "cargo" and not valid_types[string.lower(arg[1])] then
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

				local vehicle_data = nil
				local successfully_spawned = false

				if not valid_types[string.lower(arg[1])] then
					-- they did not specify a type of vehicle to spawn
					successfully_spawned, vehicle_data = v.spawn(vehicle_id, nil, true)
				else
					-- they specified a type of vehicle to spawn
					successfully_spawned, vehicle_data = v.spawn(nil, string.lower(arg[1]), true)
				end
				if successfully_spawned then
					-- if the player didn't specify where to spawn it
					if arg[2] == nil then
						return
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
										v.teleport(vehicle_data.id, new_location)
										d.print("Spawned "..vehicle_data.name.." at x:"..new_location[13].." y:"..new_location[14].." z:"..new_location[15], false, 0, peer_id)
									else
										-- delete vehicle as it was unable to find a valid position
										v.kill(vehicle_data.id, true, true)
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
									v.kill(vehicle_data.id, true, true)
								else
									local player_pos = s.getPlayerPos(peer_id)
									vehicle_data.transform[13] = player_pos[13] + math.random(-math.random(arg[3], arg[4]), math.random(arg[3], arg[4])) -- x
									vehicle_data.transform[14] = vehicle_data.transform[14] * 1.5 -- y
									vehicle_data.transform[15] = player_pos[15] + math.random(-math.random(arg[3], arg[4]), math.random(arg[3], arg[4])) -- z
									v.teleport(vehicle_data.id, vehicle_data.transform)
									d.print("Spawned "..vehicle_data.name.." at x:"..vehicle_data.transform[13].." y:"..vehicle_data.transform[14].." z:"..vehicle_data.transform[15], false, 0, peer_id)
								end
							else
								d.print("your maximum range must be greater or equal to the minimum range!", false, 1, peer_id)
								v.kill(vehicle_data.id, true, true)
							end
						else
							d.print("the minimum range must be at least 150!", false, 1, peer_id)
							v.kill(vehicle_data.id, true, true)
						end
					else
						if tonumber(arg[2]) and tonumber(arg[2]) >= 0 or tonumber(arg[2]) and tonumber(arg[2]) <= 0 then -- the player selected specific coordinates
							if tonumber(arg[3]) and tonumber(arg[3]) >= 0 or tonumber(arg[3]) and tonumber(arg[3]) <= 0 then
								if vehicle_data.vehicle_type == VEHICLE.TYPE.BOAT then
									local new_pos = m.translation(arg[2], 0, arg[3])
									v.teleport(vehicle_data.id, new_pos)
									vehicle_data.transform = new_pos
									d.print("Spawned "..vehicle_data.name.." at x:"..arg[2].." y:0 z:"..arg[3], false, 0, peer_id)
								elseif vehicle_data.vehicle_type == VEHICLE.TYPE.LAND then
									d.print("sorry! but as of now you are unable to specify the coordinates of where to spawn a land vehicle!", false, 1, peer_id)
									v.kill(vehicle_data.id, true, true)
								else -- air vehicle
									local new_pos = m.translation(arg[2], CRUISE_HEIGHT * 1.5, arg[3])
									v.teleport(vehicle_data.id, new_pos)
									vehicle_data.transform = new_pos
									d.print("Spawned "..vehicle_data.name.." at x:"..arg[2].." y:"..(CRUISE_HEIGHT*1.5).." z:"..arg[3], false, 0, peer_id)
								end
							else
								d.print("invalid z coordinate: "..tostring(arg[3]), false, 1, peer_id)
								v.kill(vehicle_data.id, true, true)
							end
						else
							d.print("invalid x coordinate: "..tostring(arg[2]), false, 1, peer_id)
							v.kill(vehicle_data.id, true, true)
						end
					end
				else
					if type(vehicle_data) == "string" then
						d.print("Failed to spawn vehicle! Error:\n"..vehicle_data, false, 1, peer_id)
					else
						d.print("Failed to spawn vehicle!\n(no error code recieved)", false, 1, peer_id)
					end
				end
			end

		elseif command == "teleport" then -- teleport vehicles
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

			local new_transform = matrix.translation(tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4]))

			local is_success = v.teleport(math.tointeger(arg[1]), new_transform)

			if is_success then
				d.print(("Teleported vehicle %s to\nx: %0.1f\ny: %0.1f\nz: %0.1f"):format(arg[1], new_transform[13], new_transform[14], new_transform[15]), false, 0, peer_id)
			else
				d.print(("Failed to teleport vehicle %s!"):format(arg[1]), false, 1, peer_id)
			end

		elseif command == "vehiclelist" then --vehicle list
			d.print("Valid Vehicles:", false, 0, peer_id)
			for vehicle_index, vehicle_object in ipairs(g_savedata.vehicle_list) do
				d.print("\nName: \""..string.removePrefix(vehicle_object.location.data.name, true).."\"\nType: "..(string.gsub(Tags.getValue(vehicle_object.vehicle.tags, "vehicle_type", true), "wep_", ""):gsub("^%l", string.upper)), false, 0, peer_id)
			end


		elseif command == "debug" then

			if not arg[1] then
				d.print("You need to specify a type to debug! valid types are: \"all\" | \"chat\" | \"error\" | \"profiler\" | \"map\" | \"graph_node\" | \"driving\" | \"traceback\"", false, 1, peer_id)
				return
			end

			--* make the debug type arg friendly
			local selected_debug = string.friendly(arg[1], true)

			-- turn the specified debug type into its integer index
			local selected_debug_id = d.debugIDFromType(selected_debug)

			if not selected_debug_id then
				-- unknown debug type
				d.print(("Unknown debug type: %s valid types are: \"all\" | \"chat\" | \"error\" | \"profiler\" | \"map\" | \"graph_node\" | \"driving\" | \"traceback\""):format(tostring(arg[1])), false, 1, peer_id)
				return
			elseif selected_debug_id == 7 then
				d.print("Function debug is currently disabled due to unrecoverable errors.", false, 1, peer_id)
				return
			end

			-- if they specified a player, then toggle it for that specified player
			if arg[2] then
				local player_list = s.getPlayers()
				for _, player in pairs(player_list) do
					if player.id == tonumber(arg[2]) then
						local debug_output = d.setDebug(selected_debug_id, tonumber(arg[2]))
						d.print(s.getPlayerName(peer_id).." "..debug_output.." for you", false, 0, tonumber(arg[2]))
						d.print(debug_output.." for "..s.getPlayerName(tonumber(arg[2])), false, 0, peer_id)
						return
					end
				end
				d.print("unknown peer id: "..arg[2], false, 1, peer_id)
			else -- if they did not specify a player
				local debug_output = d.setDebug(selected_debug_id, peer_id)
				d.print(debug_output, false, 0, peer_id)
			end

		elseif command == "st" then --spawn turret
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


		elseif command == "cp" then --capture point
			if arg[1] and arg[2] then
				local is_island = false
				for island_index, island in pairs(g_savedata.islands) do
					if island.name == string.gsub(arg[1], "_", " ") then
						is_island = true
						if island.faction ~= arg[2] then
							if arg[2] == ISLAND.FACTION.AI or arg[2] == ISLAND.FACTION.NEUTRAL or arg[2] == ISLAND.FACTION.PLAYER then
								captureIsland(island, arg[2], peer_id)
							else
								d.print(arg[2].." is not a valid faction! valid factions: | ai | neutral | player", false, 1, peer_id)
							end
						else
							d.print(island.name.." is already set to "..island.faction..".", false, 1, peer_id)
						end
					end
				end
				if not is_island then
					d.print(arg[1].." is not a valid island! Did you replace spaces with _?", false, 1, peer_id)
				end
			else
				d.print("Invalid Syntax! command usage: ?impwep cp (island_name) (faction)", false, 1, peer_id)
			end

		elseif command == "aimod" then
			if arg[1] then
				sm.debug(peer_id, arg[1], arg[2], arg[3], arg[4])
			else
				d.print("you need to specify which type to debug!", false, 1, peer_id)
			end

		elseif command == "setmod" then
			if arg[1] then
				if arg[1] == "punish" or arg[1] == "reward" then
					if arg[2] then
						if g_savedata.constructable_vehicles[arg[2]] and g_savedata.constructable_vehicles[arg[2]].mod then
							if tonumber(arg[3]) then
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
							else
								d.print("Incorrect syntax! "..arg[3].." has to be a number from 1-5!", false, 1, peer_id)
							end
						else
							d.print("Unknown role: "..arg[2], false, 1, peer_id)
						end
					else
						d.print("You need to specify which role to set!", false, 1, peer_id)
					end
				else
					d.print("Unknown reinforcement type: "..arg[1].." valid reinforcement types: \"punish\" and \"reward\"", false, 1, peer_id)
				end
			else
				d.print("You need to specify wether to punish or reward!", false, 1, peer_id)
			end

		-- arg 1 = id
		elseif command == "deletevehicle" then -- delete vehicle
			if arg[1] then
				if arg[1] == "all" or arg[1] == "damaged" then
					local vehicle_counter = 0
					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if arg[1] ~= "damaged" or arg[1] == "damaged" and vehicle_object.current_damage > 0 then

								-- refund the cargo to the island which was sending the cargo
								Cargo.refund(vehicle_id)

								v.kill(vehicle_id, true, true)
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
					local vehicle_object, _, _ = Squad.getVehicle(tonumber(arg[1]))

					if vehicle_object then

						-- refund the cargo to the island which was sending the cargo
						Cargo.refund(tonumber(arg[1]))

						v.kill(tonumber(arg[1]), true, true)
						d.print("Sucessfully deleted vehicle "..arg[1].." name: "..vehicle_object.name, false, 0, peer_id)
					else
						d.print("Unable to find vehicle with id "..arg[1]..", double check the ID!", false, 1, peer_id)
					end
				end
			else
				d.print("Invalid syntax! You must either choose a vehicle id, or \"all\" to remove all enemy AI vehicles", false, 1, peer_id) 
			end


		-- arg 1: island_name
		-- arg 2: 0 - 100, what scout level in % to set it to
		elseif command == "si" then -- scout island
			if arg[1] then
				if arg[2] then
					if tonumber(arg[2]) then
						if g_savedata.ai_knowledge.scout[string.gsub(arg[1], "_", " ")] then
							g_savedata.ai_knowledge.scout[string.gsub(arg[1], "_", " ")].scouted = (math.clamp(tonumber(arg[2]), 0, 100)/100) * scout_requirement

							-- announce the change to the players
							local name = s.getPlayerName(peer_id)
							s.notify(-1, "(Improved Conquest Mode) Scout Level Changed", name.." set "..arg[2].."'s scout level to "..(g_savedata.ai_knowledge.scout[string.gsub(arg[1], "_", " ")].scouted/scout_requirement*100).."%", 1)
						else
							d.print("Unknown island: "..string.gsub(arg[1], "_", " "), false, 1, peer_id)
						end
					else
						d.print("Arg 2 has to be a number! Unknown value: "..arg[2], false, 1, peer_id)
					end
				else
					d.print("Invalid syntax! you must specify the scout level to set it to (0-100)", false, 1, peer_id)
				end
			else
				d.print("Invalid syntax! you must specify the island and the scout level (0-100) to set it to!", false, 1, peer_id)
			end

		
		-- arg 1: setting name (optional)
		-- arg 2: value (optional)
		elseif command == "setting" then
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
								if RULES.SETTINGS[arg[1]].min and arg[2] <= RULES.SETTINGS[arg[1]].min.value and not g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] then
									
									--* set that they've acknowledged this
									if not g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] then
										g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] = {
											min = true,
											max = false
										}
									else
										g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]].min = true
									end

									d.print("Warning: setting "..arg[1].." to or below "..RULES.SETTINGS[arg[1]].min.value.." can result in "..RULES.SETTINGS[arg[1]].min.message.." Re-enter the command to acknowledge this and proceed anyways.", false, 1, peer_id)
									return
								end

								--? if theres a set maximum, if this input is above or equal to the maximum and if the player did not yet acknowledge this
								if RULES.SETTINGS[arg[1]].max and arg[2] >= RULES.SETTINGS[arg[1]].max.value and not g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] then
									
									--* set that they've acknowledged this
									if not g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] then
										g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]] = {
											min = false,
											max = true
										}
									else
										g_savedata.player_data[pl.getSteamID(peer_id)].acknowledgements[arg[1]].max = true
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
									v.kill(cargo_vehicle.vehicle_data.id, true, true)

									-- reset the squad's command
									local squad_index, _ = Squad.getSquad(cargo_vehicle.vehicle_data.id)
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
		
		elseif command == "aiknowledge" then
			local vehicles = sm.getStats()

			if vehicles.best[1].mod == vehicles.worst[1].mod then
				d.print("the adaptive AI doesn't know anything about you! all vehicles currently have the same chance to spawn.", false, 0, peer_id)
			else
				d.print("Top 3 vehicles the ai thinks is effective against you:", false, 0, peer_id)
				for _, vehicle_data in ipairs(vehicles.best) do
					d.print(_..": "..vehicle_data.prefab_data.location.data.name.." ("..vehicle_data.mod..")", false, 0, peer_id)
				end
				d.print("Bottom 3 vehicles the ai thinks is effective against you:", false, 0, peer_id)
				for _, vehicle_data in ipairs(vehicles.worst) do
					d.print(_..": "..vehicle_data.prefab_data.location.data.name.." ("..vehicle_data.mod..")", false, 0, peer_id)
				end
			end
		
		elseif command == "resetcargo" then
			local was_reset, error = Cargo.reset(is.getDataFromName(arg[1]), string.friendly(arg[2]))
			if was_reset then
				d.print("Reset the cargo storages for all islands", false, 0, peer_id)
			else
				d.print("Cargo failed to reset! error: "..error, false, 1, peer_id)
			end
		
		elseif command == "debugcache" then
			d.print("Cache Writes: "..g_savedata.cache_stats.writes.."\nCache Failed Writes: "..g_savedata.cache_stats.failed_writes.."\nCache Reads: "..g_savedata.cache_stats.reads, false, 0, peer_id)
		elseif command == "debugcargo1" then
			d.print("asking cargo to do things...(get island distance)", false, 0, peer_id)
			for island_index, island in pairs(g_savedata.islands) do
				if island.faction == ISLAND.FACTION.AI then
					Cargo.getIslandDistance(g_savedata.ai_base_island, island)
				end
			end
		elseif command == "debugcargo2" then
			d.print("asking cargo to do things...(get best route)", false, 0, peer_id)
			island_selected = g_savedata.islands[tonumber(arg[1])]
			if island_selected then
				d.print("selected island index: "..island_selected.index, false, 0, peer_id)
				local best_route = Cargo.getBestRoute(g_savedata.ai_base_island, island_selected)
				if best_route[1] then
					d.print("first transportation method: "..best_route[1].transport_method, false, 0, peer_id)
				else
					d.print("unable to find cargo route!", false, 0, peer_id)
				end
				if best_route[2] then
					d.print("second transportation method: "..best_route[2].transport_method, false, 0, peer_id)
				end
				if best_route[3] then
					d.print("third transportation method: "..best_route[3].transport_method, false, 0, peer_id)
				end
			else
				d.print("incorrect island id: "..arg[1], false, 0, peer_id)
			end
		elseif command == "clearcache" then

			d.print("clearing cache", false, 0, peer_id)
			Cache.reset()
			d.print("cache reset", false, 0, peer_id)

		elseif command == "addoninfo" then -- command for debugging things such as why the addon name is broken

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

		elseif command == "resetprefabs" then
			g_savedata.prefabs = {}
			d.print("reset all prefabs", false, 0, peer_id)
		elseif command == "debugmigration" then
			d.print("is migrated? "..tostring(g_savedata.info.version_history ~= nil), false, 0, peer_id)
		elseif command == "queueconvoy" then
			g_savedata.tick_extensions.cargo_vehicle_spawn = RULES.LOGISTICS.CARGO.VEHICLES.spawn_time - g_savedata.tick_counter - 1
			d.print("Updated convoy tick extension so a convoy will spawn when possible.", false, 0, peer_id)
		elseif command == "airvehicleskamikaze" then
			g_air_vehicles_kamikaze = not g_air_vehicles_kamikaze
			d.print(("g_air_vehicles_kamikaze set to %s"):format(tostring(g_air_vehicles_kamikaze)))
		elseif command == "causeerror" then
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
		end
	elseif player_commands.admin[command] then
		d.print("You do not have permission to use "..command..", contact a server admin if you believe this is incorrect.", false, 1, peer_id)
	end

	--
	-- host only commands
	--
	if peer_id == 0 and is_admin then
	elseif player_commands.host[command] then
		d.print("You do not have permission to use "..command..", contact a server admin if you believe this is incorrect.", false, 1, peer_id)
	end
	
	--
	-- help command
	--
	if command == "help" then
		if not arg[1] then -- print a list of all commands
			
			-- player commands
			d.print("All Improved Conquest Mode Commands (PLAYERS)", false, 0, peer_id)
			for command_name, command_info in pairs(player_commands.normal) do 
				if command_info.args ~= "none" then
					d.print("-----\nCommand\n?impwep "..command_name.." "..command_info.args, false, 0, peer_id)
				else
					d.print("-----\nCommand\n?impwep "..command_name, false, 0, peer_id)
				end
				d.print("Short Description\n"..command_info.short_desc, false, 0, peer_id)
			end

			-- admin commands
			if is_admin then 
				d.print("\nAll Improved Conquest Mode Commands (ADMIN)", false, 0, peer_id)
				for command_name, command_info in pairs(player_commands.admin) do
					if command_info.args ~= "none" then
						d.print("-----\nCommand\n?impwep "..command_name.." "..command_info.args, false, 0, peer_id)
					else
						d.print("-----\nCommand\n?impwep "..command_name, false, 0, peer_id)
					end
					d.print("Short Description\n"..command_info.short_desc, false, 0, peer_id)
				end
			end

			-- host only commands
			if peer_id == 0 and is_admin then
				d.print("\nAll Improved Conquest Mode Commands (HOST)", false, 0, peer_id)
				for command_name, command_info in pairs(player_commands.host) do
					if command_info.args ~= "none" then
						d.print("-----\nCommand\n?impwep "..command_name.." "..command_info.args, false, 0, peer_id)
					else
						d.print("-----\nCommand\n?impwep "..command_name, false, 0, peer_id)
					end
					d.print("Short Description\n"..command_info.short_desc.."\n", false, 0, peer_id)
				end
			end

		else -- print data only on the specific command they specified, if it exists
			local command_exists = false
			local has_permission = false
			local command_data = nil
			for permission_level, command_list in pairs(player_commands) do
				for command_name, command_info in pairs(command_list) do
					if command_name == arg[1]then
						command_exists = true
						command_data = command_info
						if
						permission_level == "admin" and is_admin 
						or 
						permission_level == "host" and is_admin and peer_id == 0 
						or
						permission_level == "normal"
						then
							has_permission = true
						end
					end
				end
			end
			if command_exists then -- if the command exists
				if has_permission then -- if they can execute it
					if command_data.args ~= "none" then
						d.print("\nCommand\n?impwep "..arg[1].." "..command_data.args, false, 0, peer_id)
					else
						d.print("\nCommand\n?impwep "..arg[1], false, 0, peer_id)
					end
					d.print("Description\n"..command_data.desc, false, 0, peer_id)
					d.print("Example Usage\n"..command_data.example, false, 0, peer_id)
				else
					d.print("You do not have permission to use \""..arg[1].."\", contact a server admin if you believe this is incorrect.", false, 1, peer_id)
				end
			else
				d.print("unknown command! \""..arg[1].."\" do \"?impwep help\" to get a list of all valid commands!", false, 1, peer_id)
			end
		end
	end

	-- if the command they entered exists
	local is_command = false
	if command_aliases[command] then
		is_command = true
	else
		for permission_level, command_list in pairs(player_commands) do
			if is_command then break end
			for command_name, _ in pairs(command_list) do
				if is_command then break end
				if string.friendly(command_name, true) == command then
					is_command = true
					break
				end
			end
		end
	end

	if not is_command then -- if the command they specified does not exist
		d.print("unknown command! \""..command.."\" do \"?impwep help\" to get a list of all valid commands!", false, 1, peer_id)
	end
end

function onCaptureIsland(island, new_faction, old_faction) -- triggers whenever an island is captured
	-- reset cached cargo best routes
	d.print("Clearing cached cargo best routes", true, 0)
	Cache.reset("cargo_best_routes")
end

function captureIsland(island, override, peer_id)
	local faction_to_set = nil

	if not override then
		if island.capture_timer <= 0 and island.faction ~= ISLAND.FACTION.AI then -- Player Lost Island
			faction_to_set = ISLAND.FACTION.AI
		elseif island.capture_timer >= g_savedata.settings.CAPTURE_TIME and island.faction ~= ISLAND.FACTION.PLAYER then -- Player Captured Island
			faction_to_set = ISLAND.FACTION.PLAYER
		end
	end

	-- set it to the override, otherwise if its supposted to be capped then set it to the specified, otherwise set it to ignore
	faction_to_set = override or faction_to_set or "ignore"

	-- set it to ai
	if faction_to_set == ISLAND.FACTION.AI then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = 0
		island.faction = ISLAND.FACTION.AI
		g_savedata.is_attack = false
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND CAPTURED", "The enemy has captured "..island.name..". (set manually by "..name.." via command)", 3)
		else
			s.notify(-1, "ISLAND CAPTURED", "The enemy has captured "..island.name..".", 3)
		end

		island.is_scouting = false
		g_savedata.ai_knowledge.scout[island.name].scouted = scout_requirement

		sm.train(REWARD, "defend", 4)
		sm.train(PUNISH, "attack", 5)

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad.command == SQUAD.COMMAND.ATTACK or squad.command == SQUAD.COMMAND.STAGE then
				setSquadCommand(squad, SQUAD.COMMAND.NONE) -- free squads from objective
			end
		end
	-- set it to player
	elseif faction_to_set == ISLAND.FACTION.PLAYER then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
		island.faction = ISLAND.FACTION.PLAYER
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND CAPTURED", "Successfully captured "..island.name..". (set manually by "..name.." via command)", 4)
		else
			s.notify(-1, "ISLAND CAPTURED", "Successfully captured "..island.name..".", 4)
		end

		g_savedata.ai_knowledge.scout[island.name].scouted = 0

		sm.train(REWARD, "defend", 1)
		sm.train(REWARD, "attack", 2)

		-- update vehicles looking to resupply
		for vehicle_id, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	-- set it to neutral
	elseif faction_to_set == ISLAND.FACTION.NEUTRAL then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME/2
		island.faction = ISLAND.FACTION.NEUTRAL
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND SET NEUTRAL", "Successfully set "..island.name..". (set manually by "..name.." via command)", 1)
		else
			s.notify(-1, "ISLAND SET NEUTRAL", "Successfully set "..island.name..".", 1)
		end

		island.is_scouting = false
		g_savedata.ai_knowledge.scout[island.name].scouted = 0

		-- update vehicles looking to resupply
		for vehicle_id, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	elseif island.capture_timer > g_savedata.settings.CAPTURE_TIME then -- if its over 100% island capture
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
	elseif island.capture_timer < 0 then -- if its less than 0% island capture
		island.capture_timer = 0
	end
end

function onPlayerJoin(steam_id, name, peer_id)

	if just_migrated then
		comp.showSaveMessage()
	end

	-- create playerdata if it does not already exist
	if not g_savedata.player_data[tostring(steam_id)] then
		g_savedata.player_data[tostring(steam_id)] = {
			peer_id = peer_id,
			name = name,
			object_id = s.getPlayerCharacterID(peer_id),
			debug = {
				chat = false,
				error = false,
				profiler = false,
				map = false,
				graph_node = false,
				driving = false,
				vehicle = false,
				["function"] = false,
				traceback = false
			},
			acknowledgements = {} -- used for settings to confirm that the player knows the side affects of what they're setting the setting to
		}

		-- if its toastey, enable debug for toastery
		-- this is because enabling debug every time I create a new world is annoying, and sometimes theres debug I miss which is only when the world is first created
		if tostring(steam_id) == "76561198258457459" then 
			d.setDebug(0, peer_id) -- enable chat debug
			d.setDebug(3, peer_id) -- enable map debug
			d.print("Enabling debug automatically for you, "..name, false, 0, peer_id)
		end
	end

	-- update the player's peer_id
	g_savedata.player_data[tostring(steam_id)].peer_id = peer_id

	-- update the player's object_id
	g_savedata.player_data[tostring(steam_id)].object_id = s.getPlayerCharacterID(peer_id)

	warningChecks(-1)
	if is_dlc_weapons then
		for island_index, island in pairs(g_savedata.islands) do
			updatePeerIslandMapData(peer_id, island)
		end

		s.removeMapObject(peer_id, g_savedata.ai_base_island.ui_id)
		s.addMapObject(peer_id, g_savedata.ai_base_island.ui_id, 0, 10, g_savedata.ai_base_island.transform[13], g_savedata.ai_base_island.transform[15], 0, 0, 0, 0, g_savedata.ai_base_island.name.." ("..g_savedata.ai_base_island.faction..")", 1, "", 255, 0, 0, 255)

		s.removeMapObject(peer_id, g_savedata.player_base_island.ui_id)
		s.addMapObject(peer_id, g_savedata.player_base_island.ui_id, 0, 10, g_savedata.player_base_island.transform[13], g_savedata.player_base_island.transform[15], 0, 0, 0, 0, g_savedata.player_base_island.name.." ("..g_savedata.player_base_island.faction..")", 1, "", 0, 255, 0, 255)
	end

	for debug_type, debug_data in pairs(g_savedata.debug) do
		if debug_data.auto_enable then
			d.setDebug(d.debugIDFromType(debug_type), peer_id, true)
		end
	end
end

function onVehicleDamaged(vehicle_id, amount, x, y, z, body_id)
	if not is_dlc_weapons then
		return
	end

	local player_vehicle = g_savedata.player_vehicles[vehicle_id]

	if player_vehicle then
		local damage_prev = player_vehicle.current_damage
		player_vehicle.current_damage = player_vehicle.current_damage + amount

		if damage_prev <= player_vehicle.damage_threshold and player_vehicle.current_damage > player_vehicle.damage_threshold then
			player_vehicle.death_pos = player_vehicle.transform
		end
		if amount > 0 then -- checks if it was actual damage and not from the player repairing their vehicle
			-- attempts to estimate which vehicles did the damage, as to not favour the vehicles that are closest
			-- give it to all vehicles within 3000m of the player, and that are targeting the player's vehicle
			local valid_ai_vehicles = {}
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.target_vehicle_id == vehicle_id then -- if the ai vehicle is targeting the vehicle which was damaged
							if m.xzDistance(player_vehicle.transform, vehicle_object.transform) <= 2500 and vehicle_object.state.is_simulating then -- if the ai vehicle is 2500m or less away from the player, and is 
								valid_ai_vehicles[vehicle_id] = vehicle_object
							end
						end
					end
				end
			end
			-- <valid ai> = all the enemy ai vehicles within 3000m of the player, and that are targeting the player
			-- <ai amount> = number of <valid ai>
			--
			-- for all the <valid ai>, add the damage dealt to the player / <ai_amount> to their damage dealt property
			-- this is used to tell if that vehicle, the type of vehicle, its strategy and its role was effective
			for vehicle_id, vehicle_object in pairs(valid_ai_vehicles) do
				vehicle_object.damage_dealt[vehicle_id] = vehicle_object.damage_dealt[vehicle_id] + amount/table.length(valid_ai_vehicles)
			end
		end

	else

		local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

		if vehicle_object and squad_index then

			--d.print(("body_id: %i\ndamage: %s\nmain_body_id: %i"):format(body_id, amount, vehicle_object.main_body), true, 0)

			if body_id == 0 or body_id == vehicle_object.main_body then -- makes sure the damage was on the ai's main body
				if vehicle_object.current_damage == nil then 
					vehicle_object.current_damage = 0 
					d.print("reset damage", true, 0)
				end

				local damage_prev = vehicle_object.current_damage
				vehicle_object.current_damage = vehicle_object.current_damage + amount

				--d.print("current damage: "..vehicle_object.current_damage)

				local enemy_hp = vehicle_object.health * g_savedata.settings.ENEMY_HP_MODIFIER

				if g_savedata.settings.SINKING_MODE then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						enemy_hp = enemy_hp * 2.5
					else
						enemy_hp = enemy_hp * 8
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							enemy_hp = enemy_hp * 10
						end
					end
				end

				if damage_prev <= (enemy_hp * 2) and vehicle_object.current_damage > (enemy_hp * 2) then
					d.print("Killing vehicle "..vehicle_id.." instantly, as the damage it took is over twice its max health", true, 0)
					v.kill(vehicle_id, true)
				elseif damage_prev <= enemy_hp and vehicle_object.current_damage > enemy_hp then
					d.print("Killing vehicle "..vehicle_id.." as it took too much damage", true, 0)
					v.kill(vehicle_id)
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

		-- updates the vehicle's position
		local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)
		if squad_index then
			g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id].transform[13] = x
			g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id].transform[14] = y
			g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id].transform[15] = z
		end
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if not is_dlc_weapons then
		return
	end

	if pl.isPlayer(peer_id) then
		d.print("Player Spawned Vehicle "..vehicle_id, true, 0)

		-- get the mass of it
		local vehicle_data, is_success = s.getVehicleData(vehicle_id)

		local mass = nil

		if is_success then
			mass = vehicle_data.mass
		end

		-- player spawned vehicle
		g_savedata.player_vehicles[vehicle_id] = {
			current_damage = 0, 
			damage_threshold = 100, 
			death_pos = nil, 
			ui_id = s.getMapID(),
			mass = mass
		}
	end
end

function onVehicleDespawn(vehicle_id, peer_id)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id] = nil

			-- make sure to clear this vehicle from all AI
			for _, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.target_vehicles and squad.target_vehicles[vehicle_id] then
					squad.target_vehicles[vehicle_id] = nil

					for _, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.target_vehicle_id then
							vehicle_object.target_vehicle_id = nil
						end
					end
				end
			end
		end
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)
	d.print("(onVehicleDespawn) vehicle_id: "..vehicle_id.." peer_id: "..peer_id, true, 0)
	if squad_index then
		d.print("(onVehicleDespawn) AI vehicle: "..vehicle_object.name.." ("..vehicle_id..")", true, 0)
		cleanVehicle(squad_index, vehicle_id)
	elseif vehicle_object or squad then
		d.print("(onVehicleDespawn) AI vehicle: "..vehicle_id.." does not have a squad index! squad: "..(squad and "exists" or "doesn't exist").." vehicle_object: "..(vehicle_object and "exists" or "doesn't exist"), true, 0)
	end
end

function cleanVehicle(squad_index, vehicle_id)

	local vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id]

	d.print("cleaning vehicle: "..vehicle_id, true, 0)

	s.removeMapObject(-1, vehicle_object.ui_id)
	s.removeMapLabel(-1, vehicle_object.ui_id)
	s.removeMapLine(-1, vehicle_object.ui_id)
	for i = 0, #vehicle_object.path - 1 do
		local waypoint = vehicle_object.path[i]
		if waypoint then
			s.removeMapLine(-1, waypoint.ui_id)
		end
	end

	s.removeMapLine(-1, vehicle_object.driving.ui_id)

	s.removePopup(-1, vehicle_object.ui_id)

	s.removeMapID(-1, vehicle_object.ui_id)
	s.removeMapID(-1, vehicle_object.driving.ui_id)

	-- remove it from the sweep and prune pairs
	g_savedata.sweep_and_prune.ai_pairs[vehicle_id] = nil

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET and vehicle_object.spawnbox_index ~= nil then
		for island_index, island in pairs(g_savedata.islands) do		
			if island.name == vehicle_object.home_island.name then
				island.zones.turrets[vehicle_object.spawnbox_index].is_spawned = false
			end
		end
		-- its from the ai's main base
		if g_savedata.ai_base_island.name == vehicle_object.home_island.name then
			g_savedata.ai_base_island.zones.turrets[vehicle_object.spawnbox_index].is_spawned = false
		end
	end

	for _, survivor in pairs(vehicle_object.survivors) do
		s.despawnObject(survivor.id, true)
	end

	if vehicle_object.fire_id ~= nil then
		s.despawnObject(vehicle_object.fire_id, true)
	end

	g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id] = nil
	g_savedata.ai_army.squad_vehicles[vehicle_id] = nil -- reset squad vehicle list

	if squad_index ~= RESUPPLY_SQUAD_INDEX then
		if table.length(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
			g_savedata.ai_army.squadrons[squad_index] = nil

			for island_index, island in pairs(g_savedata.islands) do
				if island.assigned_squad_index == squad_index then
					island.assigned_squad_index = -1
				end
			end
		end
	end
end

function onVehicleUnload(vehicle_id)
	if not is_dlc_weapons then
		return
	end

	local island, got_island = Island.getDataFromVehicleID(vehicle_id)
	if got_island then
		g_savedata.loaded_islands[island.index] = nil
		return
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	if squad_index and vehicle_object then

		-- reset it's transform history
		vehicle_object.transform_history = {}

		if vehicle_object.is_killed == true then
			cleanVehicle(squad_index, vehicle_id)
		else
			d.print("(onVehicleUnload): set vehicle "..vehicle_id.." pseudo. Name: "..vehicle_object.name, true, 0)
			vehicle_object.state.is_simulating = false
		end
	end
end

function setVehicleKeypads(vehicle_id, vehicle_object, squad)
	local squad_vision = squadGetVisionData(squad)
	local target = nil
	
	if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
		target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj

		local target_vehicle_id = vehicle_object.target_vehicle_id

		if g_savedata.player_vehicles[target_vehicle_id] and not g_savedata.player_vehicles[target_vehicle_id].mass then
			local vehicle_data, is_success = s.getVehicleData(target_vehicle_id)

			if is_success then
				g_savedata.player_vehicles[target_vehicle_id].mass = vehicle_data.mass
			end
		end

		if g_savedata.player_vehicles[target_vehicle_id].mass then -- target vehicle's mass
			s.setVehicleKeypad(vehicle_id, "AI_TARGET_MASS", g_savedata.player_vehicles[target_vehicle_id].mass)
		end

	elseif pl.isPlayer(vehicle_object.target_player_id) and squad_vision.visible_players_map[vehicle_object.target_player_id] then

		target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
		s.setVehicleKeypad(vehicle_id, "AI_TARGET_MASS", 50) -- player's mass

	else
		s.setVehicleKeypad(vehicle_id, "AI_TARGET_MASS", 0) -- no target
	end
	if target then -- set the target's position on keypads
		s.setVehicleKeypad(vehicle_id, "AI_TARGET_X", target.last_known_pos[13])
		s.setVehicleKeypad(vehicle_id, "AI_TARGET_Y", target.last_known_pos[14])
		s.setVehicleKeypad(vehicle_id, "AI_TARGET_Z", target.last_known_pos[15])
	end
end

--[[
function onSpawnAddonComponent(id, name, type, addon_index)
	d.print("(onSpawnAddonComponent) id: "..tostring(id).."\nname: "..tostring(name).."\ntype: "..tostring(type).."\naddon_index: "..tostring(addon_index), true, 0)
end

function onObjectLoad(object_id)
	d.print("(onObjectLoad) object_id: "..object_id, true, 0)
end]]

function onVehicleLoad(vehicle_id)
	-- return if the addon is disabled
	if not is_dlc_weapons then
		return
	end

	-- if this is the players vehicle, get data on it
	if g_savedata.player_vehicles[vehicle_id] ~= nil then
		local player_vehicle_data = s.getVehicleData(vehicle_id)
		if player_vehicle_data.voxels then
			g_savedata.player_vehicles[vehicle_id].damage_threshold = player_vehicle_data.voxels / 4
			g_savedata.player_vehicles[vehicle_id].transform = s.getVehiclePos(vehicle_id)
		end
		return
	end

	-- set tooltips for main islands, and mark the island as loaded
	local island, got_island = Island.getDataFromVehicleID(vehicle_id)
	if got_island then
		g_savedata.loaded_islands[island.index] = true

		if island.index == g_savedata.ai_base_island.index then
			s.setVehicleTooltip(g_savedata.ai_base_island.flag_vehicle.id, "AI Main Base, Cannot be Captured.")
		elseif island.index == g_savedata.player_base_island.index then
			s.setVehicleTooltip(g_savedata.player_base_island.flag_vehicle.id, "Your Main Base, Cannot be Captured by AI.")
		end
		return
	end

	-- check if the ai needs to purchase this vehicle
	local vehicle_object, _, _ = Squad.getVehicle(vehicle_id)

	if vehicle_object then
		d.print("(onVehicleLoad) AI Vehicle Loaded: "..tostring(vehicle_object.name), true, 0)
		local prefab, got_prefab = v.getPrefab(vehicle_object.name)

		if not got_prefab or not prefab.fully_created then
			v.createPrefab(vehicle_id)
		end

		if vehicle_object.costs.buy_on_load then
			local cost, cost_existed, was_purchased = v.purchaseVehicle(vehicle_object.name, vehicle_object.home_island.name, vehicle_object.costs.purchase_type)
			if was_purchased then
				vehicle_object.costs.buy_on_load = false
			elseif vehicle_object.costs.purchase_type == 0 then
				d.print("(onVehicleLoad) unable to afford "..vehicle_object.name..", killing vehicle "..vehicle_id, true, 0)
				v.kill(vehicle_id, true, true)
			end
		end
	end

	-- say the vehicle has loaded
	-- also make sure its not spawning inside another vehicle
	if vehicle_object then
		d.print("(onVehicleLoad) set vehicle simulating: "..vehicle_id, true, 0)
		d.print("(onVehicleLoad) vehicle name: "..vehicle_object.name, true, 0)
		vehicle_object.state.is_simulating = true
		-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
		for checking_squad_index, checking_squad in pairs(g_savedata.ai_army.squadrons) do
			for checking_vehicle_id, checking_vehicle_object in pairs(checking_squad.vehicles) do
				if checking_vehicle_object.id ~= vehicle_id then
					if m.distance(vehicle_object.transform, checking_vehicle_object.transform) < (vehicle_object.spawning_transform.distance or DEFAULT_SPAWNING_DISTANCE) + checking_vehicle_object.spawning_transform.distance then
						if not vehicle_object.path[2] then
							d.print("(onVehicleLoad) cancelling spawning vehicle, due to its proximity to vehicle "..vehicle_id, true, 1)

							-- refund the cargo to the island which was sending the cargo
							Cargo.refund(vehicle_id)

							v.kill(vehicle_id, true, true)
							return
						else
							v.teleport(vehicle_id, m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z))
							break
						end
					end
				end
			end
		end

		--? check if this is a cargo vehicle, if so then set the cargo in its tanks
		if g_savedata.cargo_vehicles[vehicle_id] then
			--* set the cargo in its tanks

			local large_tank_capacity = 703.125

			for tank_set = 1, 3 do
				for tank_id = 0, (vehicle_object.cargo.capacity/large_tank_capacity) - 1 do

					Cargo.setTank(vehicle_id, "RESOURCE_TYPE_"..(tank_set-1).."_"..tank_id, g_savedata.cargo_vehicles[vehicle_id].requested_cargo[tank_set].cargo_type, g_savedata.cargo_vehicles[vehicle_id].requested_cargo[tank_set].amount/(vehicle_object.cargo.capacity/large_tank_capacity), true)
				end
				Cargo.setKeypad(vehicle_id, "RESOURCE_TYPE_"..(tank_set-1), g_savedata.cargo_vehicles[vehicle_id].requested_cargo[tank_set].cargo_type)

				d.print(("set %sL of %s into tank set %i on cargo vehicle %i"):format(g_savedata.cargo_vehicles[vehicle_id].requested_cargo[tank_set].amount, g_savedata.cargo_vehicles[vehicle_id].requested_cargo[tank_set].cargo_type, tank_set, vehicle_id), true, 0)
			end
		end

		if vehicle_object.is_resupply_on_load then
			vehicle_object.is_resupply_on_load = false
			reload(vehicle_id)
		end

		d.print("(onVehicleLoad) #of survivors: "..tostring(#vehicle_object.survivors), true, 0)

		for i, char in pairs(vehicle_object.survivors) do
			if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
				--Gunners
				s.setCharacterSeated(char.id, vehicle_id, "Gunner ".. i)
				local c = s.getCharacterData(char.id)
				if c then
					s.setCharacterData(char.id, c.hp, true, true)
				end
			else
				if i == 1 then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
						s.setCharacterSeated(char.id, vehicle_id, "Captain")
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						s.setCharacterSeated(char.id, vehicle_id, "Driver")
					else
						s.setCharacterSeated(char.id, vehicle_id, "Pilot")
					end
					local c = s.getCharacterData(char.id)
					if c then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
							s.setCharacterData(char.id, c.hp, true, false)
						else
							s.setCharacterData(char.id, c.hp, true, true)
						end
					else
						d.print("(onVehicleLoad) (Non Gunner) Failed to get character data for "..tostring(char.id), true, 1)
					end
				else
					--Gunners
					s.setCharacterSeated(char.id, vehicle_id, "Gunner ".. (i - 1))
					local c = s.getCharacterData(char.id)
					if c then
						s.setCharacterData(char.id, c.hp, true, true)
					else
						d.print("(onVehicleLoad) (Gunner) Failed to get character data for "..tostring(char.id), true, 1)
					end
				end
			end
		end
		refuel(vehicle_id)
	end
end

function tickGamemode()
	d.startProfiler("tickGamemode()", true)

	-- check squad vehicle positions, every 10 seconds
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do -- go through every squad vehicle
		for vehicle_index, vehicle_object in pairs(squad.vehicles) do -- go through every vehicle in that squad
			if isTickID(vehicle_index, time.second*10) then -- every 10 seconds
				local has_island = false
				-- checks to make sure the target vehicle is valid
				if not vehicle_object.is_killed -- makes sure the vehicle isnt dead
					and vehicle_object.role ~= "scout" -- makes sure the vehicle isn't a scout vehicle
					and vehicle_object.role ~= "cargo" -- makes sure the vehicle isn't a cargo vehicle
					and squad.command ~= SQUAD.COMMAND.RESUPPLY -- makes sure the squad isnt resupplying
					then
					
					if squad.target_island then -- makes sure it has a target island
						has_island = true
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.id] = squad.target_island -- sets to check this vehicle with its target island in sweep and prune
					end
				end

				if not has_island then -- if it doesnt have a matching island
					if g_savedata.sweep_and_prune.ai_pairs[vehicle_object.id] then -- checks if it is in the pre_pairs table
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.id] = nil -- removes it from the pre_pairs table
					end
				end
			end
		end
	end

	-- tick capture rates
	local capture_tick_rate = g_savedata.settings.CAPTURE_TIME/400 -- time it takes for it to move 0.25%
	if isTickID(0, capture_tick_rate) then -- ticks the time it should take to move 0.25%
		-- check all ai that are within the capture radius
		for vehicle_id, island in pairs(g_savedata.sweep_and_prune.ai_pairs) do
			local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
			if vehicle_object then

				local capture_radius = island.faction == ISLAND.FACTION.AI and CAPTURE_RADIUS or CAPTURE_RADIUS / 1.5 -- capture radius is normal if the ai owns the island, otherwise its / 1.5

				-- if the ai vehicle is within the capture radius
				-- and the island is not the ai's main island
				-- and the island is not the player's main island
				if m.xzDistance(vehicle_object.transform, island.transform) <= capture_radius and island.index ~= g_savedata.ai_base_island.index and island.index ~= g_savedata.player_base_island.index then
					g_savedata.islands[island.index].ai_capturing = g_savedata.islands[island.index].ai_capturing + 1
				end
			else
				d.print("(tickGamemode) vehicle_object is nil! Vehicle ID: "..tostring(vehicle_id).."\nRemoving from sweep and prune pairs to check", true, 1)
				local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
				--d.print("vehicle existed before? "..tostring(vehicle_object ~= nil), true, 0)
				g_savedata.sweep_and_prune.ai_pairs[vehicle_id] = nil
				local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
				--d.print("vehicle existed after? "..tostring(vehicle_object ~= nil), true, 0)
			end
		end

		-- check all players that are within the capture radius
		for player_index, player in pairs(s.getPlayers()) do -- go through all players
			local player_transform = s.getPlayerPos(player.id)

			local player_x = player_transform[13]
			local player_z = player_transform[15]

			local player_pairs = {
				x = {},
				xz = {},
				data = {
					islands = {},
					players = {}
				}
			}

			-- x axis
			for i = 1, #g_savedata.sweep_and_prune.flags.x do -- for all the flags/capture zones
				local distance = math.abs(player_x-g_savedata.sweep_and_prune.flags.x[i].x) -- gets the x distance between the player and the capture point
				local capture_radius = g_savedata.islands[g_savedata.sweep_and_prune.flags.x[i].island_index].faction == ISLAND.FACTION.PLAYER and CAPTURE_RADIUS / 5 or CAPTURE_RADIUS / 100 -- capture radius / 5 if the player owns the island, otherwise its / 100
				if distance <= capture_radius then -- if they are within the capture radius
					-- get the z coord of the selected island
					local z_coord = nil
					for ii = 1, #g_savedata.sweep_and_prune.flags.z do
						if g_savedata.sweep_and_prune.flags.z[ii].island_index == g_savedata.sweep_and_prune.flags.x[i].island_index then
							z_coord = g_savedata.sweep_and_prune.flags.z[ii].z
							break
						end
					end
					table.insert(player_pairs.x, { -- add them to the pairs in the x table
						peer_id = player.id, 
						island_index = g_savedata.sweep_and_prune.flags.x[i].island_index, 
						z = z_coord, 
						distance = distance
					})
				end
			end

			-- z axis
			for i = 1, #player_pairs.x do
				local distance = math.abs(player_z - player_pairs.x[i].z) -- gets the z distance between the player and the capture point
				local capture_radius = g_savedata.islands[g_savedata.sweep_and_prune.flags.z[i].island_index].faction == ISLAND.FACTION.PLAYER and CAPTURE_RADIUS / 5 or CAPTURE_RADIUS / 100 -- capture radius / 5 if the player owns the island, otherwise its / 100
				if distance <= capture_radius then -- if they are within the capture radius
					table.insert(player_pairs.xz, {
						peer_id = player_pairs.x[i].peer_id,
						island_index = player_pairs.x[i].island_index,
						distance = player_pairs.x[i].distance + distance
					})
				end
			end

			-- clean up, if the player is capturing multiple islands, make them only capture the closest one to them
			-- if the island has multiple people capturing it, add them together into one
			for i = 1, #player_pairs.xz do
				local peer_id = player_pairs.xz[i].peer_id
				if not player_pairs.data.players[peer_id] then -- if this is the only island we know the player is capturing so far
					local island_index = player_pairs.xz[i].island_index
					-- player data
					player_pairs.data.players[peer_id] = {
						island_index = island_index,
						distance = player_pairs.xz[i].distance
					}
					-- island data
					player_pairs.data.islands[island_index] = {}
					player_pairs.data.islands[island_index].number_capturing = (player_pairs.data.islands[island_index].number_capturing or 0) + 1
				else -- if the player has been detected to be capturing multiple islands
					local distance = player_pairs.xz[i].distance
					-- if the distance from this island is less than the island that we checked before
					if player_pairs.data.players[peer_id].distance > distance then
						-- changes old island data
						player_pairs.data.islands[player_pairs.data.players[peer_id].island_index].number_capturing = player_pairs.data.islands[island_index].number_capturing - 1 -- remove 1 from the number capturing that island
						-- updates player data
						player_pairs.data.players[peer_id] = {
							island_index = player_pairs.xz[i].island_index,
							distance = distance
						}
						-- updates new island data
						player_pairs.data.islands[island_index].number_capturing = (player_pairs.data.islands[island_index].number_capturing or 0) + 1
					end
				end
			end

			for island_index, island in pairs(player_pairs.data.islands) do
				g_savedata.islands[island_index].players_capturing = island.number_capturing
			end
		end

		-- tick spawning for ai vehicles (to remove as will be replaced to be dependant on logistics system)
		g_savedata.ai_base_island.production_timer = g_savedata.ai_base_island.production_timer + capture_tick_rate
		if g_savedata.ai_base_island.production_timer > g_savedata.settings.AI_PRODUCTION_TIME_BASE then
			g_savedata.ai_base_island.production_timer = 0

			local spawned, vehicle_data = v.spawn("turret", "turret", false, g_savedata.ai_base_island)
			if not spawned then
				d.print("failed to spawn turret at "..g_savedata.ai_base_island.name.."\nError:\n"..vehicle_data, true, 1)
			end
			
			local spawned, vehicle_data = v.spawn(nil, nil, false, nil, 0)
			if not spawned then
				d.print("failed to spawn vehicle\nError:\n"..vehicle_data, true, 1)
			end
		end

		-- update islands
		for island_index, island in pairs(g_savedata.islands) do

			-- spawn turrets at owned islands (to remove as will be replaced to be dependant on logistics system)
			if island.faction == ISLAND.FACTION.AI and g_savedata.ai_base_island.production_timer == 0 then
				-- check to see if turrets are disabled
				if g_savedata.settings.MAX_TURRET_AMOUNT > 0 then
					local spawned, vehicle_data = v.spawn("turret", "turret", false, island)
					if not spawned then
						d.print("failed to spawn turret at "..island.name.."\nError:\n"..vehicle_data, true, 1)
					end
				end
			end

			-- display new capture data
			if island.players_capturing > 0 and island.ai_capturing > 0 and g_savedata.settings.CONTESTED_MODE then -- if theres ai and players capping, and if contested mode is enabled
				if island.is_contested == false then -- notifies that an island is being contested
					s.notify(-1, "ISLAND CONTESTED", "An island is being contested!", 1)
					island.is_contested = true
				end
			else
				island.is_contested = false
				if island.players_capturing > 0 and g_savedata.settings.CAPTURE_TIME > island.capture_timer then -- tick player progress if theres one or more players capping
					island.capture_timer = island.capture_timer + ((ISLAND_CAPTURE_AMOUNT_PER_SECOND * 5) * capture_speeds[math.min(island.players_capturing, 3)]) * capture_tick_rate

				elseif island.ai_capturing > 0 and 0 < island.capture_timer then -- tick AI progress if theres one or more ai capping
					island.capture_timer = island.capture_timer - (ISLAND_CAPTURE_AMOUNT_PER_SECOND * capture_speeds[math.min(island.ai_capturing, 3)]) * capture_tick_rate
				end
			end

			-- makes sure its within limits
			island.capture_timer = math.clamp(island.capture_timer, 0, g_savedata.settings.CAPTURE_TIME)
			
			-- displays tooltip on vehicle
			local cap_percent = math.floor((island.capture_timer/g_savedata.settings.CAPTURE_TIME) * 100)
			if island.is_contested then -- if the point is contested (both teams trying to cap)
				s.setVehicleTooltip(island.flag_vehicle.id, "Contested: "..cap_percent.."%")
			elseif island.faction ~= ISLAND.FACTION.PLAYER then -- if the player doesn't own the point
				if island.ai_capturing == 0 and island.players_capturing == 0 then -- if nobody is capping the point
					s.setVehicleTooltip(island.flag_vehicle.id, "Capture: "..cap_percent.."%")
				elseif island.ai_capturing == 0 then -- if players are capping the point
					s.setVehicleTooltip(island.flag_vehicle.id, "Capturing: "..cap_percent.."%")
				else -- if ai is capping the point
					s.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
				end
			else -- if the player does own the point
				if island.ai_capturing == 0 and island.players_capturing == 0 or cap_percent == 100 then -- if nobody is capping the point or its at 100%
					s.setVehicleTooltip(island.flag_vehicle.id, "Captured: "..cap_percent.."%")
				elseif island.ai_capturing == 0 then -- if players are capping the point
					s.setVehicleTooltip(island.flag_vehicle.id, "Re-Capturing: "..cap_percent.."%")
				else -- if ai is capping the point
					s.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
				end
			end

			updatePeerIslandMapData(-1, island)

			-- resets amount capping
			island.ai_capturing = 0
			island.players_capturing = 0
			captureIsland(island)
		end
	end


	-- update ai's main base island debug
	if d.getDebug(3) then
		if isTickID(0, 60) then

			local plane_count = 0
			local heli_count = 0
			local army_count = 0
			local land_count = 0
			local boat_count = 0
			local turret_count = 0
		
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET then army_count = army_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then turret_count = turret_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then boat_count = boat_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then plane_count = plane_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then heli_count = heli_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then land_count = land_count + 1 end
				end
			end

			local ai_islands = 1
			for island_index, island in pairs(g_savedata.islands) do
				if island.faction == ISLAND.FACTION.AI then
					ai_islands = ai_islands + 1
				end
			end

			local t, a = Objective.getIslandToAttack()

			local ai_base_island_turret_count = 0
			for turret_zone_index, turret_zone in pairs(g_savedata.ai_base_island.zones.turrets) do
				if turret_zone.is_spawned then ai_base_island_turret_count = ai_base_island_turret_count + 1 end
			end

			local debug_data = ""
			debug_data = debug_data.."--- This Island's Statistics ---\n\n"
			debug_data = debug_data.."Number of Turrets: "..ai_base_island_turret_count.."/"..g_savedata.settings.MAX_TURRET_AMOUNT.."\n"

			-- cargo
			debug_data = debug_data.."\n-- Cargo --\n"

			debug_data = debug_data.."- Cargo Storage -\n"
			debug_data = debug_data..("%s%.1f%s"):format("Oil: ", g_savedata.ai_base_island.cargo.oil, "\n")
			debug_data = debug_data..("%s%.1f%s"):format("Diesel: ", g_savedata.ai_base_island.cargo.diesel, "\n")
			debug_data = debug_data..("%s%.1f%s"):format("Jet Fuel: ", g_savedata.ai_base_island.cargo.jet_fuel, "\n")


			debug_data = debug_data.."\n--- Global Statistics ---\n\n"
			debug_data = debug_data .. "Total AI Vehicles: "..army_count.."/"..(g_savedata.settings.MAX_BOAT_AMOUNT + g_savedata.settings.MAX_HELI_AMOUNT + g_savedata.settings.MAX_PLANE_AMOUNT + g_savedata.settings.MAX_LAND_AMOUNT).."\n"
			debug_data = debug_data .. "Total Sea Vehicles: "..boat_count.."/"..g_savedata.settings.MAX_BOAT_AMOUNT.."\n"
			debug_data = debug_data .. "Total Helicopters: "..heli_count.."/"..g_savedata.settings.MAX_HELI_AMOUNT.."\n"
			debug_data = debug_data .. "Total Planes: "..plane_count.."/"..g_savedata.settings.MAX_PLANE_AMOUNT.."\n"
			debug_data = debug_data .. "Total Land Vehicles: "..land_count.."/"..g_savedata.settings.MAX_LAND_AMOUNT.."\n"
			debug_data = debug_data .. "Total Turrets: "..turret_count.."/"..g_savedata.settings.MAX_TURRET_AMOUNT*ai_islands.."\n"
			debug_data = debug_data .. "\nNumber of Squads: "..g_count_squads.."\n"

			if t then
				debug_data = debug_data .. "Attacking: " .. t.name .. "\n"
			end
			if a then
				debug_data = debug_data .. " Attacking From: " .. a.name
			end
			local player_list = s.getPlayers()
			for peer_index, peer in pairs(player_list) do
				if d.getDebug(3, peer.id) then
					s.removeMapObject(peer.id, g_savedata.ai_base_island.ui_id)
					s.addMapObject(peer.id, g_savedata.ai_base_island.ui_id, 0, 4, g_savedata.ai_base_island.transform[13], g_savedata.ai_base_island.transform[15], 0, 0, 0, 0, g_savedata.ai_base_island.name.."\nAI Base Island\n"..g_savedata.ai_base_island.production_timer.."/"..g_savedata.settings.AI_PRODUCTION_TIME_BASE.."\nIsland Index: "..g_savedata.ai_base_island.index, 1, debug_data, 255, 0, 0, 255)

					s.removeMapObject(peer.id, g_savedata.player_base_island.ui_id)
					s.addMapObject(peer.id, g_savedata.player_base_island.ui_id, 0, 4, g_savedata.player_base_island.transform[13], g_savedata.player_base_island.transform[15], 0, 0, 0, 0, "Player Base Island", 1, debug_data, 0, 255, 0, 255)
				end
			end
		end
	end
	d.stopProfiler("tickGamemode()", true, "onTick()")
end


---@param peer_id integer the id of the player of which you want to update the map data for
---@param island island[] the island you want to update
---@param is_reset boolean if you want it to just reset the map, which will remove the island from the map instead of updating it
function updatePeerIslandMapData(peer_id, island, is_reset)
	if is_dlc_weapons then
		s.removeMapObject(peer_id, island.ui_id)
		if not is_reset then
			local cap_percent = math.floor((island.capture_timer/g_savedata.settings.CAPTURE_TIME) * 100)
			local extra_title = ""
			local r = 75
			local g = 75
			local b = 75
			if island.is_contested then
				r = 255
				g = 255
				b = 0
				extra_title = " CONTESTED"
			elseif island.faction == ISLAND.FACTION.AI then
				r = 255
				g = 0
				b = 0
			elseif island.faction == ISLAND.FACTION.PLAYER then
				r = 0
				g = 255
				b = 0
			end
			if not d.getDebug(3, peer_id) then -- checks to see if the player has debug mode disabled
				s.addMapObject(peer_id, island.ui_id, 0, 9, island.transform[13], island.transform[15], 0, 0, 0, 0, island.name.." ("..island.faction..")"..extra_title, 1, cap_percent.."%", r, g, b, 255)
			else
				if island.transform ~= g_savedata.player_base_island.transform and island.transform ~= g_savedata.ai_base_island.transform then -- makes sure its not trying to update the main islands
					local turret_amount = 0
					for turret_zone_index, turret_zone in pairs(island.zones.turrets) do
						if turret_zone.is_spawned then turret_amount = turret_amount + 1 end
					end
					
					local debug_data = ""
					debug_data = debug_data.."\nScout Progress: "..math.floor(g_savedata.ai_knowledge.scout[island.name].scouted/scout_requirement*100).."%"
					debug_data = debug_data.."\n\nNumber of AI Capturing: "..island.ai_capturing
					debug_data = debug_data.."\nNumber of Players Capturing: "..island.players_capturing
					if island.faction == ISLAND.FACTION.AI then 
						debug_data = debug_data.."\n\nNumber of defenders: "..island.defenders.."\n"
						debug_data = debug_data.."Number of Turrets: "..turret_amount.."/"..g_savedata.settings.MAX_TURRET_AMOUNT.."\n"

						debug_data = debug_data.."\nCargo\n"

						debug_data = debug_data.."\nCargo Storage\n"
						debug_data = debug_data..("%s%.1f%s"):format("Oil: ", island.cargo.oil, "\n")
						debug_data = debug_data..("%s%.1f%s"):format("Diesel: ", island.cargo.diesel, "\n")
						debug_data = debug_data..("%s%.1f%s"):format("Jet Fuel: ", island.cargo.jet_fuel, "\n")
					end

					s.addMapObject(peer_id, island.ui_id, 0, 9, island.transform[13], island.transform[15], 0, 0, 0, 0, island.name.." ("..island.faction..")\nisland.index: "..island.index..extra_title, 1, cap_percent.."%"..debug_data, r, g, b, 255)
				end
			end
		end
	end
end

function getSquadLeader(squad)
	for vehicle_id, vehicle_object in pairs(squad.vehicles) do
		return vehicle_id, vehicle_object
	end
	d.print("warning: empty squad "..squad.vehicle_type.." detected", true, 1)
	return nil
end

function getNearbySquad(transform, override_command)

	local closest_free_squad = nil
	local closest_free_squad_index = -1
	local closest_dist = 999999999

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad.command == SQUAD.COMMAND.NONE
		or squad.command == SQUAD.COMMAND.PATROL
		or override_command then

			local _, squad_leader = getSquadLeader(squad)
			local squad_vehicle_transform = squad_leader.transform
			local distance = m.distance(transform, squad_vehicle_transform)

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
	d.startProfiler("tickAI()", true)
	-- allocate squads to islands
	for island_index, island in pairs(g_savedata.islands) do
		if isTickID(island_index, 60) then
			if island.faction == ISLAND.FACTION.AI then
				if island.assigned_squad_index == -1 then
					local squad, squad_index = getNearbySquad(island.transform)

					if squad ~= nil then
						setSquadCommandDefend(squad, island)
						island.assigned_squad_index = squad_index
					end
				end
			end
		end
		if isTickID(island_index*15, time.minute/4) then -- every 15 seconds, update the amount of vehicles that are defending the base
			island.defenders = 0
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.command == SQUAD.COMMAND.DEFEND or squad.command == SQUAD.COMMAND.TURRET then
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if island.faction == ISLAND.FACTION.AI then
							if m.xzDistance(island.transform, vehicle_object.transform) < 1500 then
								island.defenders = island.defenders + 1
							end
						end
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
				if squad.command ~= SQUAD.COMMAND.SCOUT then
					if squad.command ~= SQUAD.COMMAND.ENGAGE and squad_vision:is_engage() then
						setSquadCommandEngage(squad)
					elseif squad.command ~= SQUAD.COMMAND.INVESTIGATE and squad_vision:is_investigate() then
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
	end

	if isTickID(0, 60) then
		g_count_squads = 0
		g_count_attack = 0
		g_count_patrol = 0

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				if squad.command ~= SQUAD.COMMAND.DEFEND and squad.vehicle_type ~= VEHICLE.TYPE.TURRET then
					g_count_squads = g_count_squads + 1
				end
	
				if squad.command == SQUAD.COMMAND.STAGE or squad.command == SQUAD.COMMAND.ATTACK then
					g_count_attack = g_count_attack + 1
				elseif squad.command == SQUAD.COMMAND.PATROL then
					g_count_patrol = g_count_patrol + 1
				end
			end
		end

		local objective_island, ally_island = Objective.getIslandToAttack()

		if objective_island == nil then
			g_savedata.is_attack = false
		else
			if g_savedata.is_attack == false then
				if g_savedata.constructable_vehicles.attack.mod >= 0.1 then -- if its above the threshold in order to attack
					if g_savedata.ai_knowledge.scout[objective_island.name].scouted >= scout_requirement then
						local boats_ready = 0
						local boats_total = 0
						local air_ready = 0
						local air_total = 0
						local land_ready = 0
						local land_total = 0
						objective_island.is_scouting = false

						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == SQUAD.COMMAND.STAGE then
								local _, squad_leader = getSquadLeader(squad)
								if not squad_leader then
									if squad_index ~= RESUPPLY_SQUAD_INDEX then
										-- delete the squad as its empty
										g_savedata.ai_army.squadrons[squad_index] = nil
										d.print("removed squad: "..tostring(squad_index), true, 0)
									else
										setSquadCommand(squad, SQUAD.COMMAND.RESUPPLY)
									end
									break
								end
								local squad_leader_transform = squad_leader.transform

								if squad.vehicle_type == VEHICLE.TYPE.BOAT then
									boats_total = boats_total + 1

									local air_dist = m.distance(objective_island.transform, ally_island.transform)
									local dist = m.distance(squad_leader_transform, objective_island.transform)
									local air_sea_speed_factor = VEHICLE.SPEED.BOAT/VEHICLE.SPEED.PLANE

									if dist < air_dist * air_sea_speed_factor then
										boats_ready = boats_ready + 1
									end
								elseif squad.vehicle_type == VEHICLE.TYPE.LAND then
									land_total = land_total + 1

									local air_dist = m.distance(objective_island.transform, ally_island.transform)
									local dist = m.distance(squad_leader_transform, objective_island.transform)
									local air_sea_speed_factor = VEHICLE.SPEED.LAND/VEHICLE.SPEED.PLANE

									if dist < air_dist * air_sea_speed_factor then
										land_ready = land_ready + 1
									end
								else
									air_total = air_total + 1

									local dist = m.distance(squad_leader_transform, ally_island.transform)
									if dist < 2000 then
										air_ready = air_ready + 1
									end
								end
							end
						end
						
						-- add more vehicles if we didn't hit the limit
						if (air_total + boats_total) < MAX_ATTACKING_SQUADS then
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.PATROL or squad.command == SQUAD.COMMAND.DEFEND and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and squad.role ~= "defend" then
									if (air_total + boats_total) < MAX_ATTACKING_SQUADS then
										if squad.vehicle_type == VEHICLE.TYPE.BOAT then
											if not Tags.has(objective_island.tags, "no-access=boat") and not Tags.has(ally_island.tags, "no-access=boat") then
												boats_total = boats_total + 1
												setSquadCommandStage(squad, objective_island)
											end
										else
											air_total = air_total + 1
											setSquadCommandStage(squad, ally_island)
										end
									end
								end
							end
						end
						
			
						g_is_air_ready = air_total == 0 or air_ready / air_total >= 0.5
						g_is_boats_ready = Tags.has(ally_island.tags, "no-access=boat") or Tags.has(objective_island.tags, "no-access=boat") or boats_total == 0 or boats_ready / boats_total >= 0.25
						local is_attack = (g_count_attack / g_count_squads) >= 0.25 and g_count_attack >= MIN_ATTACKING_SQUADS and g_is_boats_ready and g_is_air_ready
						
						if is_attack then
							g_savedata.is_attack = is_attack
			
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.STAGE then
									if not Tags.has(objective_island.tags, "no-access=boat") and squad.vehicle_type == VEHICLE.TYPE.BOAT or squad.vehicle_type ~= VEHICLE.TYPE.BOAT then -- makes sure boats can attack that island
										setSquadCommandAttack(squad, objective_island)
									end
								elseif squad.command == SQUAD.COMMAND.ATTACK then
									if squad.target_island.faction == ISLAND.FACTION.AI then
										-- if they are targeting their own island
										squad.target_island = objective_island
									end
								end
							end
						else
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.NONE and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and (air_total + boats_total) < MAX_ATTACKING_SQUADS then
									if squad.vehicle_type == VEHICLE.TYPE.BOAT then -- send boats ahead since they are slow
										if not Tags.has(objective_island.tags, "no-access=boat") then -- if boats can attack that island
											setSquadCommandStage(squad, objective_island)
											boats_total = boats_total + 1
										end
									else
										setSquadCommandStage(squad, ally_island)
										air_total = air_total + 1
									end
								elseif squad.command == SQUAD.COMMAND.STAGE and squad.vehicle_type == VEHICLE.TYPE.BOAT and not Tags.has(objective_island.tags, "no-access=boat") and (air_total + boats_total) < MAX_ATTACKING_SQUADS then
									setSquadCommandStage(squad, objective_island)
									squad.target_island = objective_island
								end
							end
						end
					else -- if they've yet to fully scout the base
						local scout_exists = false
						local not_scouting = false
						local squad_to_set = nil
						if not objective_island.is_scouting then
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								for vehicle_index, vehicle in pairs(squad.vehicles) do
									if vehicle.role == "scout" then
										scout_exists = true
										if squad.command ~= SQUAD.COMMAND.SCOUT then not_scouting = true; squad_to_set = squad_index end
									end
								end
							end
							if not scout_exists then -- if a scout vehicle does not exist
								-- then we want to spawn one, unless its been less than 30 minutes since it was killed
								if g_savedata.ai_history.scout_death == -1 or g_savedata.ai_history.scout_death ~= 0 and g_savedata.tick_counter - g_savedata.ai_history.scout_death >= time.hour / 2 then
									d.print("attempting to spawn scout vehicle...", true, 0)
									local spawned = v.spawn("scout", nil, nil, nil, 3)
									if spawned then
										if g_savedata.ai_history.scout_death == -1 then
											g_savedata.ai_history.scout_death = 0
										end
										d.print("scout vehicle spawned!", true, 0)
										objective_island.is_scouting = true
										for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
											if squad.command == SQUAD.COMMAND.SCOUT then
												setSquadCommandScout(squad)
											end
										end
									else
										d.print("Failed to spawn scout vehicle!", true, 1)
									end
								end
							elseif not_scouting and squad_to_set then -- if the scout was just set to a different command
								-- then we want to set it back to scouting
								setSquadCommandScout(g_savedata.ai_army.squadrons[squad_to_set])
							end
						end
					end
				else -- if they've not hit the threshold to attack
					if objective_island.is_scouting then -- if theres still a scout plane scouting the island
						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == SQUAD.COMMAND.SCOUT then
								squad.target_island = ally_island
								setSquadCommand(squad, SQUAD.COMMAND.DEFEND)
								objective_island.is_scouting = false
							end
						end
					end
				end
			else
				local is_disengage = (g_count_attack / g_count_squads) < 0.25
	
				if is_disengage then
					g_savedata.is_attack = false
	
					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						if squad.command == SQUAD.COMMAND.ATTACK then
							if squad.vehicle_type == VEHICLE.TYPE.BOAT and not Tags.has(objective_island.tags, "no-access=boat") and not Tags.has(ally_island.tags, "no-access=boat") or squad.vehicle_type ~= VEHICLE.TYPE.BOAT then
								setSquadCommandStage(squad, ally_island)
							end
						end
					end
				end
			end
		end

		-- assign squads to patrol
		local allied_islands = getAlliedIslands()

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad.command == SQUAD.COMMAND.NONE then
				if #allied_islands > 0 then
					if (g_count_patrol / g_count_squads) < 0.5 then
						g_count_patrol = g_count_patrol + 1
						setSquadCommandPatrol(squad, allied_islands[math.random(1, #allied_islands)])
					else
						setSquadCommandDefend(squad, allied_islands[math.random(1, #allied_islands)])
					end
				else
					setSquadCommandPatrol(squad, g_savedata.ai_base_island)
				end
			end
		end
	end
	d.stopProfiler("tickAI()", true, "onTick()")
end

function getAlliedIslands()
	local alliedIslandIndexes = {}
	for island_index, island in pairs(g_savedata.islands) do
		if island.faction == ISLAND.FACTION.AI then
			table.insert(alliedIslandIndexes, island)
		end
	end
	return alliedIslandIndexes
end

function getResupplyIsland(ai_vehicle_transform)
	local closest = g_savedata.ai_base_island
	local closest_dist = m.distance(ai_vehicle_transform, g_savedata.ai_base_island.transform)

	for island_index, island in pairs(g_savedata.islands) do
		if island.faction == ISLAND.FACTION.AI then
			local distance = m.distance(ai_vehicle_transform, island.transform)

			if distance < closest_dist then
				closest = island
				closest_dist = distance
			end
		end
	end

	return closest
end

---@param vehicle_object vehicle_object the vehicle to transfer
---@param squad_index number the squad's index that you want to transfer the vehicle to
---@param force boolean if you want to force the vehicle over to the squad, bypassing any limits
function transferToSquadron(vehicle_object, squad_index, force) --* moves a vehicle over to another squad
	if not vehicle_object then
		d.print("(transferToSquadron) vehicle_object is nil!", true, 1)
		return
	end

	if not squad_index then
		local debug_data = ""
		if vehicle_object then
			if vehicle_object.id then
				debug_data = debug_data.." vehicle_id: "..tostring(vehicle_object.id)

				if g_savedata.ai_army.squad_vehicles[vehicle_object.id] then
					debug_data = debug_data.." squad_index: "..tostring(g_savedata.ai_army.squad_vehicles[vehicle_object.id])
				end
			end
		end

			
		d.print("(transferToSquadron) squad_index is nil! debug_data:"..debug_data, true, 1)
		return
	end

	local old_squad_index, old_squad = Squad.getSquad(vehicle_object.id)

	if not old_squad_index then
		d.print("(transferToSquadron) old_squad_index is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
	end

	vehicle_object.previous_squad = old_squad_index

	--? make sure new squad exists
	if not g_savedata.ai_army.squadrons[squad_index] then
		--* create the squad as it doesn't exist
		squad_index, squad_created = Squad.createSquadron(squad_index, vehicle_object)
		if not squad_created then
			d.print("(transferToSquadron) failed to create squad!", true, 1)
		end
	end

	--* add to new squad
	g_savedata.ai_army.squad_vehicles[vehicle_object.id] = squad_index
	g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.id] = vehicle_object

	--* remove from old squad
	if old_squad_index and g_savedata.ai_army.squadrons[old_squad_index] and g_savedata.ai_army.squadrons[old_squad_index].vehicles then
		g_savedata.ai_army.squadrons[old_squad_index].vehicles[vehicle_object.id] = nil
		--? if the squad is now empty then delete the squad and if its not the resupply squad
		if table.length(g_savedata.ai_army.squadrons[old_squad_index].vehicles) == 0 and old_squad_index ~= RESUPPLY_SQUAD_INDEX then
			g_savedata.ai_army.squadrons[old_squad_index] = nil
		end
	end

	--local vehicle_object_test, squad_test, squad_index_test = Squad.getVehicle(vehicle_object.id)
	--d.print("(transferToSquadron) vehicle_object existed after? "..tostring(vehicle_object_test ~= nil), true, 0)

	d.print("(transferToSquadron) Transferred "..vehicle_object.name.."("..vehicle_object.id..") from squadron "..tostring(old_squad_index).." to "..squad_index, true, 0)
end

function addToSquadron(vehicle_object)
	if vehicle_object then
		if not vehicle_object.is_killed then
			local new_squad = nil

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then -- do not automatically add to resupply squadron
					if squad.vehicle_type == vehicle_object.vehicle_type then
						local _, squad_leader = getSquadLeader(squad)
						if squad.vehicle_type ~= VEHICLE.TYPE.TURRET or vehicle_object.home_island.name == squad_leader.home_island.name then
							if vehicle_object.role ~= "scout" and squad.role ~= "scout" and vehicle_object.role ~= "cargo" and squad.role ~= "cargo" then
								if table.length(squad.vehicles) < MAX_SQUAD_SIZE then
									squad.vehicles[vehicle_object.id] = vehicle_object
									g_savedata.ai_army.squad_vehicles[vehicle_object.id] = squad_index
									new_squad = squad
									break
								end
							end
						end
					end
				end
			end

			if new_squad == nil then
				local new_squad_index, squad_created = Squad.createSquadron(nil, vehicle_object)

				new_squad = g_savedata.ai_army.squadrons[new_squad_index]

				new_squad.vehicles[vehicle_object.id] = vehicle_object
				g_savedata.ai_army.squad_vehicles[vehicle_object.id] = new_squad_index
			end

			squadInitVehicleCommand(new_squad, vehicle_object)
			return new_squad
		else
			d.print("(addToSquadron) "..vehicle_object.name.." is killed!", true, 1)
		end
	else
		d.print("(addToSquadron) vehicle_object is nil!", true, 1)
	end
	return nil
end

local squadron_tick_rate = 60

function tickSquadrons()
	d.startProfiler("tickSquadrons()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, squadron_tick_rate) then
			-- clean out-of-action vehicles
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do

				if vehicle_object.is_killed and vehicle_object.death_timer ~= nil then
					vehicle_object.death_timer = vehicle_object.death_timer + 1

					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						if vehicle_object.death_timer >= time.hour/squadron_tick_rate then
							v.kill(vehicle_id, true)
						end
					elseif vehicle_object.role == SQUAD.COMMAND.SCOUT then
						if vehicle_object.death_timer >= (time.minute/4)/squadron_tick_rate then
							v.kill(vehicle_id, true)
						end
					else
						if vehicle_object.death_timer >= math.seededRandom(false, vehicle_id, 8, 90) then -- kill the vehicle after 8 - 90 seconds after dying
							v.kill(vehicle_id, true)
						end
					end
				end

				-- if pilot is incapacitated
				local c = s.getCharacterData(vehicle_object.survivors[1].id)

				--[[
					if npc exists
					and if the npc is incapacitaed or dead
					and if the vehicle its linked to isnt a cargo vehicle
					then kill the vehicle
				]]
				if c and (c.incapacitated or c.dead) and vehicle_object.role ~= SQUAD.COMMAND.CARGO then
					v.kill(vehicle_id)
				end
			end

			-- check if a vehicle needs resupply, removing from current squad and adding to the resupply squad
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if isVehicleNeedsResupply(vehicle_id, "Resupply") then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
							reload(vehicle_id)
						else
							transferToSquadron(g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_id], RESUPPLY_SQUAD_INDEX, true)

							d.print(tostring(vehicle_id).." leaving squad "..tostring(squad_index).." to resupply", true, 0)

							if g_savedata.ai_army.squadrons[squad_index] and table.length(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
								g_savedata.ai_army.squadrons[squad_index] = nil
	
								for _, island in pairs(g_savedata.islands) do
									if island.assigned_squad_index == squad_index then
										island.assigned_squad_index = -1
									end
								end
							end

							if g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].command ~= SQUAD.COMMAND.RESUPPLY then
								g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].command = SQUAD.COMMAND.RESUPPLY
							end

							squadInitVehicleCommand(squad, vehicle_object)
						end
					elseif isVehicleNeedsResupply(vehicle_id, "AI_NO_MORE_MISSILE") then -- if its out of missiles, then kill it
						if not vehicle_object.is_killed then
							v.kill(vehicle_id)
						end
					end
					-- check if the vehicle simply needs to reload from a disconnected ammo belt, barrel or box
					local vehicle_data, is_success = s.getVehicleData(vehicle_id)

					if is_success and vehicle_data.components and vehicle_data.components.guns then
						for gun_index = 1, #vehicle_data.components.guns do
							local gun_data = vehicle_data.components.guns[gun_index]

							-- if this is a gun that might need reloading
							if gun_data.ammo == 0 and (gun_data.name:match("^Ammo %d+$") or (gun_data.name:match("^Gunner %d+$"))) then

								-- the target weapons we can reload from
								local ammo_group = tonumber(table.pack(gun_data.name:gsub("[%a ]+", ""))[1])
								local target_pattern = ("Reserve Ammo %i"):format(ammo_group)
								for reserve_ammo_index = 1, #vehicle_data.components.guns do
									local reserve_ammo_data = vehicle_data.components.guns[reserve_ammo_index]

									-- we can reload from this weapon
									if gun_index ~= reserve_ammo_index and reserve_ammo_data.ammo ~= 0 and reserve_ammo_data.name:match(target_pattern) then
										-- move as much ammo as we can from the reserve ammo to the gun.
										local ammo_to_move = math.min(gun_data.capacity - gun_data.ammo, reserve_ammo_data.ammo)

										-- take that away from the reserve ammo container
										s.setVehicleWeapon(vehicle_id, reserve_ammo_data.pos.x, reserve_ammo_data.pos.y, reserve_ammo_data.pos.z, reserve_ammo_data.ammo - ammo_to_move)
										
										-- move that into the gun
										s.setVehicleWeapon(vehicle_id, gun_data.pos.x, gun_data.pos.y, gun_data.pos.z, gun_data.ammo + ammo_to_move)

										-- if the gun is not at capcity, continue on
										-- otherwise, break.
										if gun_data.ammo + ammo_to_move == gun_data.capacity then
											break
										end
									end
								end
							end
						end
					end
				end
			else
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if (vehicle_object.state.is_simulating and isVehicleNeedsResupply(vehicle_id, "Resupply") == false) or (not vehicle_object.state.is_simulating and vehicle_object.is_resupply_on_load) then
	
						transferToSquadron(vehicle_object, vehicle_object.previous_squad, true)

						d.print(vehicle_id.." resupplied. joining squad", true, 0)
					end
				end
			end

			--* tick behaviour and exit conditions
			if squad.command == SQUAD.COMMAND.CARGO and g_savedata.settings.CARGO_MODE then
				local convoy = {}
				for vehicle_index, vehicle_object in pairs(squad.vehicles) do
					if g_savedata.cargo_vehicles[vehicle_object.id] then
						local n_vehicle_object, n_squad_index, n_squad = Squad.getVehicle(vehicle_object.id)
						g_savedata.cargo_vehicles[vehicle_object.id].vehicle_data = n_vehicle_object
						convoy = g_savedata.cargo_vehicles[vehicle_object.id]
						convoy.vehicle_data = n_vehicle_object
						break
					end
				end

				--? check to see if we have a valid convoy
				if not convoy then
					d.print("breaking as theres no valid convoy!", true, 1)
					goto break_squadron
				end

				--? check to see if we have any escorts
				if #convoy.convoy <= 1 then
					goto break_squadron
				end

				--? check to see if we're on the move
				if convoy.route_status ~= 1 then
					goto break_squadron
				end

				--* handle and calculate the convoy's paths

				-- get which path the cargo vehicle is currently on
				local old_path = convoy.path_data.current_path

				--? check to see if we have any paths for the cargo vehicle
				if #convoy.vehicle_data.path > 0 then
					for i = convoy.path_data.current_path, #convoy.path_data.path do
						--d.print("i: "..i, true, 0)
						i = math.max(i, 1)
						local cargo_vehicle_node = g_savedata.ai_army.squadrons[squad_index].vehicles[convoy.vehicle_data.id].path[1]
						local convoy_node = convoy.path_data.path[i]
						--d.print("c_v_n.x: "..cargo_vehicle_node.x.." c_n.x: "..convoy_node.x.."\nc_v_n.y: "..tostring(cargo_vehicle_node.y).." c_n.y: "..tostring(convoy_node.y).."\nc_v_n.z: "..cargo_vehicle_node.z.." c_n.z: "..convoy_node.z.."\n", true, 0)
						if cargo_vehicle_node.x == convoy_node.x and cargo_vehicle_node.z == convoy_node.z then
							--d.print("current path: "..i, true, 0)
							convoy.path_data.current_path = i
							break
						end
					end
				else
					d.print("there are no convoy paths!", true, 1)
					p.addPath(convoy.vehicle_data, squad.target_island.transform)
				end

				--d.print("old path: "..old_path, true, 0)
				--d.print("new path: "..convoy.path_data.current_path, true, 0)

				--* check and update the convoy's path for all vehicles in the convoy
				--d.print("going through all escorts...", true, 0)
				for convoy_index, vehicle_id in ipairs(convoy.convoy) do
					local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)
					--d.print("convoy_index: "..tostring(convoy_index).." vehicle_id: "..tostring(vehicle_id), true, 0)
					if not vehicle_object then
						d.print("(escort) vehicle_object is nil! vehicle_id: "..tostring(vehicle_id), true, 1)
						goto break_cargo_vehicle
					end

					--? if this is not the cargo vehicle
					if vehicle_object.id ~= convoy.vehicle_data.id then
						--? if the cargo vehicle is on a new path
						if old_path ~= convoy.path_data.current_path then
							--* reset the path
							p.resetPath(vehicle_object)
						end
					end

					--d.print("convoy_index: "..convoy_index, true, 0)
					if convoy.convoy[convoy_index - 1] then -- if theres a vehicle behind this one

						local behind_vehicle_object, behind_squad_index, behind_squad = Squad.getVehicle(convoy.convoy[convoy_index - 1])

						--? if this vehicle is not waiting and the behind vehicle exists
						if behind_vehicle_object and vehicle_object.state.convoy.status ~= CONVOY.WAITING  then
						
							--? check if the vehicle behind needs to catch up, and the vehicle behind is not a plane
							if RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance and vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE then

								--? if the vehicle behind is too far behind
								local behind_too_far = (m.xzDistance(vehicle_object.transform, behind_vehicle_object.transform) >= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance)

								--? if the vehicle behind is waiting
								local behind_waiting = (behind_vehicle_object.state.convoy.status == CONVOY.WAITING and behind_vehicle_object.state.convoy.waiting_for ~= convoy_index)

								if behind_too_far or behind_waiting then
									--? if this vehicle behind us is not ignored for waiting
									if not behind_vehicle_object.state.convoy.ignore_wait then
										-- set us to waiting
										vehicle_object.state.convoy.status = CONVOY.WAITING
										-- set the time that this occured
										vehicle_object.state.convoy.changed_time = g_savedata.tick_counter
										-- set which vehicle we are waiting for
										vehicle_object.state.convoy.waiting_for = convoy_index - 1
										-- set the vehicle's speed to be 0
										vehicle_object.speed.convoy_modifier = -(v.getSpeed(vehicle_object, nil, nil, nil, nil, true))
										-- set why its waiting
										local status_reason = behind_too_far and "waiting_for_behind" or "behind_is_waiting"
										vehicle_object.state.convoy.status_reason = status_reason
									end
								end
							end

							if vehicle_object.state.convoy.status == CONVOY.MOVING then
								--* make it speed up if its falling behind, and the vehicle behind is catching up

								-- the last path this vehicle has
								local last_path = vehicle_object.path[#vehicle_object.path]

								if last_path then

									--d.print("vehicle_object.name: "..vehicle_object.name.."\nbehind_vehicle_object.name: "..behind_vehicle_object.name, true, 0)

									-- the distance from this vehicle to its last path
									local dist = m.xzDistance(vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									-- the distance from the vehicle behind to this vehicles last path
									local behind_dist = m.xzDistance(behind_vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									--d.print("dist: "..dist.."\nbehind_dist: "..behind_dist, true, 0)

									local dist_speed_modifier = 1/math.clamp((behind_dist - dist)/(RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].min_distance*2), 0.5, 1)
									--d.print("dist_speed_modifier: "..dist_speed_modifier, true, 0)

									local vehicle_speed = v.getSpeed(vehicle_object, nil, nil, nil, nil, true)

									vehicle_object.speed.convoy_modifier = ((vehicle_speed * dist_speed_modifier) - vehicle_speed)/1.5

									--d.print("speed: "..(vehicle_object.speed.convoy_modifier), true, 0)
								end
							end
						end
					end

					if convoy.convoy[convoy_index + 1] then -- if theres a vehicle ahead of this one

						local ahead_vehicle_object, ahead_squad_index, ahead_squad = Squad.getVehicle(convoy.convoy[convoy_index + 1])

						if ahead_vehicle_object and vehicle_object.state.convoy.status ~= CONVOY.WAITING then
						
							--? check if the vehicle ahead is getting too far behind
							if RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].min_distance and vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE then

								--? if the vehicle ahead is getting too far behind

								local next_path = ahead_vehicle_object.path[1]

								--d.print("vehicle_type: "..vehicle_object.vehicle_type, true, 0)

								local ahead_too_far = (m.xzDistance(vehicle_object.transform, ahead_vehicle_object.transform) >= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance) and (next_path and (m.xzDistance(ahead_vehicle_object.transform, m.translation(next_path.x, next_path.y, next_path.z)) > m.xzDistance(vehicle_object.transform, m.translation(next_path.x, next_path.y, next_path.z))))

								--? if the vehicle ahead of us is waiting
								local ahead_waiting = (ahead_vehicle_object.state.convoy.status == CONVOY.WAITING and ahead_vehicle_object.state.convoy.waiting_for ~= convoy_index)

								if ahead_too_far or ahead_waiting then
									--? if this vehicle ahead of us is not ignored for waiting
									if not ahead_vehicle_object.state.convoy.ignore_wait then
										-- set us to waiting
										vehicle_object.state.convoy.status = CONVOY.WAITING
										-- set the time that this occured
										vehicle_object.state.convoy.changed_time = g_savedata.tick_counter
										-- set which vehicle we are waiting for
										vehicle_object.state.convoy.waiting_for = convoy_index + 1
										-- set the vehicle's speed to be 0
										vehicle_object.speed.convoy_modifier = -(v.getSpeed(vehicle_object, nil, nil, nil, nil, true))
										-- set why its waiting
										local status_reason = ahead_too_far and "waiting_for_ahead" or "ahead_is_waiting"
										vehicle_object.state.convoy.status_reason = status_reason
									end
								end
							end

							if vehicle_object.state.convoy.status == CONVOY.MOVING then
								--* make it slow down if the vehicle ahead falling behind, and speed up if its falling behind

								-- the last path this vehicle has
								local last_path = ahead_vehicle_object.path[#ahead_vehicle_object.path]

								if last_path then

									-- the distance from this vehicle to its last path
									local dist = m.xzDistance(vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									-- the distance from the vehicle ahead of this vehicles last path
									local ahead_dist = m.xzDistance(ahead_vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									local dist_speed_modifier = 1/math.clamp((ahead_dist - dist)/(RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance/2), 0.5, 1)

									local vehicle_speed = v.getSpeed(vehicle_object, nil, nil, nil, nil, true)

									vehicle_object.speed.convoy_modifier = ((vehicle_speed * dist_speed_modifier) - vehicle_speed)/1.5

									--d.print("speed: "..(vehicle_object.speed.convoy_modifier), true, 0)
								end
							end
						end
					end

					--? if this vehicle is currently waiting
					if vehicle_object.state.convoy.status == CONVOY.WAITING then
						--d.print("vehicle is waiting", true, 0)
						local max_wait_timer = RULES.LOGISTICS.CONVOY.base_wait_time
						--? if we've waited over the max time, or that this vehicle should not be waited 
						local waiting_vehicle_object, waiting_squad_index, waiting_squad = Squad.getVehicle(convoy.convoy[vehicle_object.state.convoy.waiting_for])
						--d.print("waiting for "..(ticksSince(vehicle_object.state.convoy.changed_time)).."t...", true, 0)

						--? if we've waited too long for the vehicle
						local waited_too_long = (ticksSince(vehicle_object.state.convoy.changed_time) > max_wait_timer or waiting_vehicle_object.state.convoy.ignore_wait)

						--? if the vehicle behind has caught up
						local behind_vehicle_object = nil
						local behind_squad_index = nil
						local behind_squad = nil

						if convoy.convoy[convoy_index - 1] then
							behind_vehicle_object, behind_squad_index, behind_squad = Squad.getVehicle(convoy.convoy[convoy_index - 1])
						end

						local behind_caught_up = (vehicle_object.state.convoy.status_reason == "waiting_for_behind" and ((vehicle_object.state.convoy.waiting_for + 1) == convoy_index) and (not behind_vehicle_object or m.xzDistance(vehicle_object.transform, behind_vehicle_object.transform) <= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].target_distance))

						--? if the vehicle behind is no longer waiting
						local behind_no_longer_waiting = (vehicle_object.state.convoy.status_reason == "behind_is_waiting" and (not waiting_vehicle_object or waiting_vehicle_object.state.convoy.status ~= CONVOY.WAITING))

						if waited_too_long or behind_caught_up or behind_no_longer_waiting then
							if waited_too_long then
								-- ignore the vehicle for waiting that we were waiting for
								waiting_vehicle_object.state.convoy.ignore_wait = true
							end
							-- set us to moving
							vehicle_object.state.convoy.status = CONVOY.MOVING
							-- remove the time our status changed
							vehicle_object.state.convoy.changed_time = -1
							-- set that we aren't waiting for anybody
							vehicle_object.state.convoy.waiting_for = 0
							-- remove the speed modifier
							vehicle_object.speed.convoy_modifier = 0
							--? if its not the cargo vehicle
							if vehicle_object.id ~= convoy.vehicle_data.id then
								-- reset the vehicle's path
								p.resetPath(vehicle_object)
							end
							-- reset the vehicle status reason
							vehicle_object.state.convoy.status_reason = ""
						end

					--? pathfind for the vehicle
					elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.BOAT and #vehicle_object.path <= 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and #vehicle_object.path < 1 then
						--d.print("calculating new path!", true, 0)
						--* this vehicle is currently moving

						--* calculate where the vehicle should path to

						cargo_vehicle_index = 1 + math.floor((#convoy.convoy - 1)/2)

						--? this vehicle is not the cargo vehicle
						if vehicle_object.id ~= convoy.vehicle_data.id then

							local target_dist = math.abs(cargo_vehicle_index - convoy_index) * RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].target_distance

							--d.print("target dist: "..target_dist, true, 0)

							local node_to_check = 1

							--? if this vehicle is behind the cargo vehicle
							if convoy_index <= cargo_vehicle_index then
								node_to_check = -1
							end
							
							--* find which node is the best node to target
							local best_node = math.max(convoy.path_data.current_path - node_to_check, 1)
							local next_node = nil
							local total_dist = 0
							local leftover_dist = target_dist
							--d.print("current_path: "..convoy.path_data.current_path.."\nnumber of paths: "..#convoy.path_data.path, true, 0)
							for node = convoy.path_data.current_path, #convoy.path_data.path * node_to_check, node_to_check do
								local p_node = convoy.path_data.path[node-node_to_check] -- last node
								local n_node = convoy.path_data.path[node] -- next node


								--d.print("node: "..node, true, 0)
								--? makes sure previous node and new nodes exist
								if p_node and n_node then

									if node == convoy.path_data.current_path then -- if this is the first path, calculate the distance from the cargo vehicle to its next path
										total_dist = total_dist + m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), convoy.vehicle_data.transform)
									else -- if tis is not the first path, calculate the distance between the paths
										total_dist = total_dist + m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), m.translation(p_node.x, p_node.y, p_node.z))
									end

									--? break if this is over the target distance
									--d.print("total dist: "..total_dist, true, 0)
									if total_dist >= target_dist then
										next_node = node
										leftover_dist = target_dist - (total_dist - m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), m.translation(p_node.x, p_node.y, p_node.z)))
										break
									else
										best_node = node
									end

									
								end
							end
							local t_node = convoy.path_data.path[best_node] -- target node
							if not t_node then
								goto break_cargo_vehicle
							end
							local target_pos = m.translation(t_node.x, t_node.y, t_node.z)

							
							if target_pos then
								--d.print("adding path to destination!", true, 0)
								--! pathfind to the new destination
								p.resetPath(vehicle_object)
								p.addPath(vehicle_object, target_pos)

								--* for the leftover distance, go that far into the node
								--d.print("leftover dist: "..leftover_dist, true, 0)
								if leftover_dist ~= 0 and next_node then
									--d.print("current node: "..convoy.path_data.current_path, true, 0)
									--d.print("best_node: "..best_node.." next_node: "..next_node, true, 0)
									local n_node = convoy.path_data.path[next_node] -- the node we couldn't reach
									--d.print("n_node.x: "..n_node.x.." t_node.x: "..t_node.x, true, 0)
									local angle = math.atan(n_node.x - t_node.x, n_node.z - t_node.z)
									local target_x = t_node.x + (leftover_dist * math.sin(angle))
									local target_z = t_node.z + (leftover_dist * math.cos(angle))

									--d.print("target x: "..target_x.."\ntarget z: "..target_z, true, 0)

									table.insert(vehicle_object.path, #vehicle_object.path+1, {
										x = target_x,
										y = target_pos[14],
										z = target_z
									})
								end

								--* clean up the path
								if #vehicle_object.path >= 2 then

									local nodes_to_remove = {}

									for node = 1, #vehicle_object.path - 1 do

										-- if the vehicle is closer to the node after the next one than the next node
										local node_is_junk = m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[node].x, vehicle_object.path[node].y, vehicle_object.path[node].z)) > m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z))

										-- if the vehicle is closer to the node after the next node than the next node is closer to the node after
										local node_goes_backwards = m.xzDistance(m.translation(vehicle_object.path[node].x, vehicle_object.path[node].y, vehicle_object.path[node].z), m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z)) > m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z))

										if node_is_junk or node_goes_backwards then
											table.insert(nodes_to_remove, node)
										end
									end

									for node = #nodes_to_remove, 1, -1 do
										s.removeMapLine(-1, vehicle_object.path[nodes_to_remove[node]].ui_id)
										table.remove(vehicle_object.path, nodes_to_remove[node])
										--d.print("removed node: "..node, true, 0)
									end
								end
							end
						end
					end
					::break_cargo_vehicle::
				end

				

			elseif squad.command == SQUAD.COMMAND.PATROL then
				local squad_leader_id, squad_leader = getSquadLeader(squad)
				if squad_leader then
					if squad_leader.state.s ~= VEHICLE.STATE.PATHING then -- has finished patrol
						setSquadCommand(squad, SQUAD.COMMAND.NONE)
					end
				else
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						d.print("patrol squad missing leader", true, 1)
						d.print("deleting squad as its empty", true, 1)
						g_savedata.ai_army.squadrons[squad_index] = nil
						setSquadCommand(squad, SQUAD.COMMAND.NONE)
					else
						setSquadCommand(squad, SQUAD.COMMAND.RESUPPLY)
					end
				end
			elseif squad.command == SQUAD.COMMAND.STAGE then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == SQUAD.COMMAND.ATTACK then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == SQUAD.COMMAND.DEFEND then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end

				if squad.target_island == nil then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				elseif squad.target_island.faction ~= ISLAND.FACTION.AI then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			elseif squad.command == SQUAD.COMMAND.RESUPPLY then

				g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].target_island = nil
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if #vehicle_object.path == 0 then
						d.print("resupply mission recalculating target island for: "..vehicle_id, true, 0)
						local ally_island = getResupplyIsland(vehicle_object.transform)
						p.resetPath(vehicle_object)
						p.addPath(vehicle_object, m.multiply(ally_island.transform, m.translation(math.random(-250, 250), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-250, 250))))
					end
					
					if m.distance(g_savedata.ai_base_island.transform, vehicle_object.transform) < RESUPPLY_RADIUS then

						if vehicle_object.state.is_simulating then
							-- resupply ammo
							reload(vehicle_id)
						else
							s.resetVehicleState(vehicle_id)
							vehicle_object.is_resupply_on_load = true
						end
					end

					for island_index, island in pairs(g_savedata.islands) do
						if island.faction == ISLAND.FACTION.AI then
							if m.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS then

								if vehicle_object.state.is_simulating then
									-- resupply ammo
									reload(vehicle_id)
								else
									s.resetVehicleState(vehicle_id)
									vehicle_object.is_resupply_on_load = true
								end
							end
						end
					end
				end

			elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
				-- head to search area

				if squad.investigate_transform then
					local is_all_vehicles_at_search_area = true

					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.state.s ~= VEHICLE.STATE.HOLDING then
							is_all_vehicles_at_search_area = false
						end
					end

					if is_all_vehicles_at_search_area then
						squad.investigate_transform = nil
					end
				else
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			end

			if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then
				local squad_vision = squadGetVisionData(squad)
				local player_counts = {}
				local vehicle_counts = {}
				local function incrementCount(t, index) t[index] = t[index] and t[index] + 1 or 1 end
				local function decrementCount(t, index) t[index] = t[index] and t[index] - 1 or 0 end
				local function getCount(t, index) return t[index] or 0 end

				local function retargetVehicle(vehicle_object, target_player_id, target_vehicle_id)
					-- decrement previous target count
					if pl.isPlayer(vehicle_object.target_player_id) then 
						decrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id then 
						decrementCount(vehicle_counts, vehicle_object.target_vehicle_id) 
					end

					vehicle_object.target_player_id = target_player_id
					vehicle_object.target_vehicle_id = target_vehicle_id

					-- increment new target count
					if pl.isPlayer(vehicle_object.target_player_id) then 
						incrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id then 
						incrementCount(vehicle_counts, vehicle_object.target_vehicle_id) 
					end
				end


				-- vision checking for vehicles to target
				-- TODO: Read into this and make a few modficiations like making the targeting system more intelligent and possibly improve the performance impact
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- check existing target is still visible

					if pl.isPlayer(vehicle_object.target_player_id) and squad_vision:isPlayerVisible(vehicle_object.target_player_id) == false then
						vehicle_object.target_player_id = nil
					elseif vehicle_object.target_vehicle_id and squad_vision:isVehicleVisible(vehicle_object.target_vehicle_id) == false then
						vehicle_object.target_vehicle_id = nil
					end

					-- find targets if not targeting anything

					if not pl.isPlayer(vehicle_object.target_player_id) and not vehicle_object.target_vehicle_id then
						if #squad_vision.visible_players > 0 then
							vehicle_object.target_player_id = squad_vision:getBestTargetPlayerID()
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif #squad_vision.visible_vehicles > 0 then
							vehicle_object.target_vehicle_id = squad_vision:getBestTargetVehicleID()
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					else
						if pl.isPlayer(vehicle_object.target_player_id) then
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif vehicle_object.target_vehicle_id then
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					end
				end

				local squad_vehicle_count = #squad.vehicles
				local visible_target_count = #squad_vision.visible_players + #squad_vision.visible_vehicles
				local vehicles_per_target = math.max(math.floor(squad_vehicle_count / visible_target_count), 1)

				local function isRetarget(target_player_id, target_vehicle_id)
					return (not pl.isPlayer(target_player_id) and not target_vehicle_id) 
						or (pl.isPlayer(target_player_id) and getCount(player_counts, target_player_id) > vehicles_per_target)
						or (target_vehicle_id and getCount(vehicle_counts, target_vehicle_id) > vehicles_per_target)
				end

				-- find vehicles to retarget to visible players

				for visible_player_id, visible_player in pairs(squad_vision.visible_players_map) do
					if getCount(player_counts, visible_player_id) < vehicles_per_target then
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isRetarget(vehicle_object.target_player_id, vehicle_object.target_vehicle_id) then
								retargetVehicle(vehicle_object, visible_player_id, nil)
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
								retargetVehicle(vehicle_object, nil, visible_vehicle_id)
								break
							end
						end
					end
				end

				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- update waypoint and target data

					-- if its targeting a player or a vehicle
					if pl.isPlayer(vehicle_object.target_player_id) or vehicle_object.target_vehicle_id then
						local target_pos = nil
						local target_id = nil
						local target_type = ""
						if pl.isPlayer(vehicle_object.target_player_id) then -- if its targeting a player
							target_pos = squad_vision.visible_players_map[vehicle_object.target_player_id].obj.last_known_pos
							target_id = pl.objectIDFromSteamID(vehicle_object.target_player_id)
							target_type = "character"
						else -- if its targeting a vehicle
							target_pos = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj.last_known_pos
							target_id = vehicle_object.target_vehicle_id
							target_type = "vehicle"
						end


						-- make sure we have a target position and target id
						if target_pos and target_id then

							if g_air_vehicles_kamikaze and (vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or vehicle_object.vehicle_type == VEHICLE.TYPE.HELI) then

								p.resetPath(vehicle_object)
								p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] - 5, target_pos[15]))
								s.setAITarget(vehicle_object.survivors[1].id, m.translation(target_pos[13], target_pos[14] - 5, target_pos[15]))

								if m.xzDistance(vehicle_object.transform, m.translation(target_pos[13], target_pos[14], target_pos[15])) < 100 then
									s.setAIState(vehicle_object.survivors[1].id, 0)
									s.setCharacterData(vehicle_object.survivors[1].id, 1, true, false)
									--d.print("murder.")
								else
									s.setAIState(vehicle_object.survivors[1].id, 2)
								end
								

							elseif #vehicle_object.path < 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE and target_pos[14] <= 50 and vehicle_object.state.is_simulating then -- if we dont have any more paths
								
								-- reset its path
								if #vehicle_object.path < 1 then
									p.resetPath(vehicle_object)
								end

								

								if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then -- if this vehicle is a plane
									if vehicle_object.strategy == "strafing" then -- if the plane has a strategy of strafing
										if target_pos[14] <= 50 and vehicle_object.state.is_simulating then -- if the target's y is below the threshold for detecting its a air vehicle
											local dist_in_front = 870
											local engage_dist = 775
											-- distance from <dist_in_front>m in front of the jet to target
											local in_front_dist = m.xzDistance(target_pos, m.multiply(vehicle_object.transform, m.translation(0, 0, dist_in_front)))

											--[[ debug
											if not g_savedata.temp_ui_id then
												g_savedata.temp_ui_id = s.getMapID()
											end

											local in_front = m.multiply(vehicle_object.transform, m.translation(0, 0, dist_in_front))
											s.removeMapObject(-1, g_savedata.temp_ui_id)
											s.addMapObject(-1, g_savedata.temp_ui_id, 1, 11, in_front[13], in_front[15], 0, 0, 0, 0, "in front", 0, "in front", 255, 255, 0, 255)
											]]
											
											-- distance from jet to target
											local jet_dist = m.xzDistance(target_pos, vehicle_object.transform)

											-- if in front of the jet is closer to the target than the jet is, and its within distance to start the strafe
											if in_front_dist < jet_dist and jet_dist <= engage_dist then
												p.resetPath(vehicle_object)
												p.addPath(vehicle_object, m.translation(target_pos[13], math.max(target_pos[14] + 5, 18), target_pos[15]))
												-- d.print("strafing", true, 0)
												vehicle_object.just_strafed = true
											else
												--[[ debug
												local a = " 1" -- 1 =  jet is closer than infront dist
												if in_front_dist < jet_dist then -- 2 = not within engage dist
													a = " 2"
												end
												d.print("normal"..a)
												]]

												--[[ 
												make the jet go further before it starts to try to turn towards the vehicle again
												this ensures the jet will be able to be facing the target when going overhead
												instead of just circling the player
												]]

												if vehicle_object.just_strafed then

													p.resetPath(vehicle_object)
													
													local roll, yaw, pitch = m.getMatrixRotation(vehicle_object.transform)
													p.addPath(vehicle_object, m.translation(
														target_pos[13] + 1000 * math.sin(yaw), -- x
														target_pos[14] + 160, -- y
														target_pos[15] + 1000 * math.cos(yaw) -- z
													))

													--[[ 
													after it goes straight for a bit after strafing, make it circle back around
													to fly towards the target again
													]]

													p.addPath(vehicle_object, m.translation(
														target_pos[13], 
														target_pos[14] + 160, 
														target_pos[15]
													))

													vehicle_object.just_strafed = false
												end
											end
										else -- if we think its an air vehicle
											p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] + 3, target_pos[15]))
										end
									end
									-- to write: dive bombing
								elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
									p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] + math.max(target_pos[14] + (vehicle_object.id % 5) + 25, 75), target_pos[15]))
								end
							end
								
							for i, char in pairs(vehicle_object.survivors) do
								if target_type == "character" then
									s.setAITargetCharacter(char.id, target_id)
								elseif target_type == "vehicle" then
									s.setAITargetVehicle(char.id, target_id)
								end
	
								if i ~= 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
									if not g_air_vehicles_kamikaze or (vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE and vehicle_object.vehicle_type ~= VEHICLE.TYPE.HELI) then 
										s.setAIState(char.id, 1)
									end
								end
							end
						end
					end
				end

				if squad_vision:is_engage() == false then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			end
		end
		::break_squadron::
	end
	d.stopProfiler("tickSquadrons()", true, "onTick()")
end

function tickVision()
	d.startProfiler("tickVision()", true)
	-- get the ai's vision radius
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 240) then
				local vehicle_transform = vehicle_object.transform
				local weather = s.getWeather(vehicle_transform)
				local clock = s.getTime()
				if vehicle_object.vision.is_radar then
					-- has radar
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.2)) * (0.8 + (math.min(clock.daylight_factor*1.8, 1) * 0.2)) * (1 - (weather.rain * 0.2))
				else
					-- no radar
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.6)) * (0.4 + (math.min(clock.daylight_factor*1.8, 1) * 0.6)) * (1 - (weather.rain * 0.6))
				end
			end
		end
	end

	-- analyse player vehicles
	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then
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
							local distance = m.distance(player_vehicle_transform, vehicle_transform)

							local local_vision_radius = vehicle_object.vision.radius

							if not vehicle_object.vision.is_sonar and player_vehicle_transform[14] < -1 then
								-- if the player is in the water, and the player is below y -1, then reduce the player's sight level depending on the player's depth
								local_vision_radius = local_vision_radius * math.min(0.15 / (math.abs(player_vehicle_transform[14]) * 0.2), 0.15)
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
				if m.distance(player_vehicle.death_pos, player_vehicle_transform) > 500 then
					local player_vehicle_data, is_success = s.getVehicleData(player_vehicle_id)
					player_vehicle.death_pos = nil
					if is_success and player_vehicle_data.voxels then
						player_vehicle.damage_threshold = player_vehicle.damage_threshold + player_vehicle_data.voxels / 10
					end
				end
			end
		end
	end

	-- analyse players
	local player_list = s.getPlayers()
	for player_index, player in pairs(player_list) do
		if isTickID(player_index, 30) then
			local player_steam_id = tostring(player.steam_id)
			if player_steam_id then
				local player_transform = s.getPlayerPos(player.id)
				
				for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						-- reset target visibility state to investigate

						if squad.target_players[player_steam_id] ~= nil then
							squad.target_players[player_steam_id].state = TARGET_VISIBILITY_INVESTIGATE
						end

						-- check if target is visible to any vehicles

						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							local distance = m.distance(player_transform, vehicle_object.transform)

							if distance <= vehicle_object.vision.radius then
								g_savedata.ai_knowledge.last_seen_positions[player_steam_id] = player_transform
								if squad.target_players[player_steam_id] == nil then
									squad.target_players[player_steam_id] = {
										state = TARGET_VISIBILITY_VISIBLE,
										last_known_pos = player_transform,
									}
								else
									local target_player = squad.target_players[player_steam_id]
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

	-- update all of the keypads on the AI vehicles which are loaded
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.state.is_simulating then
				if pl.isPlayer(vehicle_object.target_player_id) or vehicle_object.target_vehicle_id then
					setVehicleKeypads(vehicle_id, vehicle_object, squad)
				end
			end
		end
	end

	d.stopProfiler("tickVision()", true, "onTick()")
end

function tickVehicles()
	d.startProfiler("tickVehicles()", true)
	local vehicle_update_tickrate = 30
	if isTickID(60, 60) then
		debug_mode_blinker = not debug_mode_blinker
	end

	-- save vehicle transform, and update vehicle debug
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do

			if not vehicle_object.state.is_simulating then
				goto continue_tickVehicles_updateTransform
			end

			vehicle_object.transform, is_success = s.getVehiclePos(vehicle_id)

			vehicle_object.transform_history[getTickID(vehicle_id, 120)] = vehicle_object.transform

			if d.getDebug(6) then
				local text = ""

				-- name
				text = text..vehicle_object.name
				
				-- Vehicle ID
				text = text..("\nVehicle ID: %s"):format(vehicle_id)

				local pos_last = vehicle_object.transform_history[getTickID(vehicle_id - 30, 120)]

				if pos_last then
					-- velocity
					local velocity = m.velocity(server.getVehiclePos(vehicle_id), pos_last, 30)

					text = text..("\n\nVel: %0.3f"):format(velocity)

					local pos_second_last = vehicle_object.transform_history[getTickID(vehicle_id - 60, 120)]
					if pos_second_last then
						-- acceleration
						local acceleration = m.acceleration(s.getVehiclePos(vehicle_id), pos_last, pos_second_last, 30)

						text = text..("\nAccel: %0.3f"):format(acceleration)
					end
				end

				for peer_index, peer in pairs(s.getPlayers()) do
					if d.getDebug(6, peer.id) then
						if pos_last then
							s.setPopup(peer.id, vehicle_object.ui_id, "", true, text, 0, 0, 0, 2500, vehicle_id)
						end
					end
				end
			end

			::continue_tickVehicles_updateTransform::
		end
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, vehicle_update_tickrate) then

				-- if air crash mode is enabled
				-- then we want to check if this vehicle is a plane or heli
				-- if it is, we want to see how much its moved
				-- and compare it to the previous time we checked, if its a large difference, then we make it explode.
				if g_savedata.settings.AIR_CRASH_MODE and vehicle_object.state.is_simulating then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then

						-- get its previous positions

						-- position from 30 (vehicle_update_tickrate) ticks ago
						local last_pos = vehicle_object.transform_history[getTickID(vehicle_id - vehicle_update_tickrate, 120)]

						-- position from 60 (vehicle_update_tickrate*2) ticks ago
						local second_last_pos = vehicle_object.transform_history[getTickID(vehicle_id - vehicle_update_tickrate * 2, 120)]

						-- make sure they both exist
						if last_pos and second_last_pos then

							local total_vel_change = math.abs(m.acceleration(vehicle_object.transform, last_pos, second_last_pos, vehicle_update_tickrate))

							--[[
								if its velocity changed too much from the last, then it likely crashed
								as well, if it's position changed too little from previous, then it also likely crashed
							]]

							local total_pos_change = m.distance(second_last_pos, vehicle_object.transform)*(vehicle_update_tickrate*2)/60

							--d.print("Pos change from last: "..(total_pos_change), true, 0)

							if total_vel_change >= 50 or total_pos_change < 0.012 then
								d.print(("Vehicle %s (%i) Crashed! (total_vel_change: %s total_pos_change: %s)"):format(vehicle_object.name, vehicle_id, total_vel_change, total_pos_change), true, 0)
								v.kill(vehicle_id, true)
							end
						end
					end
				end

				-- scout vehicles
				if vehicle_object.role == "scout" then
					local target_island, origin_island = Objective.getIslandToAttack(true)
					if target_island then -- makes sure there is a target island
						if g_savedata.ai_knowledge.scout[target_island.name].scouted < scout_requirement then
							if #vehicle_object.path == 0 then -- if its finishing circling the island
								setSquadCommandScout(squad)
							end
							local attack_target_island, attack_origin_island = Objective.getIslandToAttack()
							if m.xzDistance(vehicle_object.transform, target_island.transform) <= vehicle_object.vision.radius then
								if attack_target_island.name == target_island.name then -- if the scout is scouting the island that the ai wants to attack
									-- scout it normally
									if target_island.faction == ISLAND.FACTION.NEUTRAL then
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate * 4, 0, scout_requirement)
									else
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate, 0, scout_requirement)
									end
								else -- if the scout is scouting an island that the ai is not ready to attack
									-- scout it 4x slower
									if target_island.faction == ISLAND.FACTION.NEUTRAL then
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate, 0, scout_requirement)
									else
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate / 4, 0, scout_requirement)
									end
								end
							end
						end
					else
						setSquadCommandDefend(squad, g_savedata.ai_base_island)
					end
				end

				local modifier = 1
				local tile, got_tile = s.getTile(vehicle_object.transform)
				-- if its not on the ocean tile, make its explosion depth 3x lower, if its a boat
				if got_tile and tile.name ~= "" and vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
					modifier = 3
				end

				-- check if the vehicle has sunk or is under water
				if vehicle_object.transform[14] <= explosion_depths[vehicle_object.vehicle_type]/modifier then
					if vehicle_object.role ~= SQUAD.COMMAND.CARGO then
						v.kill(vehicle_id, true)
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
						else
							d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					else

						-- refund the cargo to the island which was sending the cargo
						Cargo.refund(vehicle_id)

						v.kill(vehicle_id)
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
						else
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					end
					goto continue_vehicle
				end

				local ai_target = nil
				if ai_state ~= 2 then ai_state = 1 end
				local ai_speed_pseudo = (vehicle_object.speed.speed or VEHICLE.SPEED.BOAT) * vehicle_update_tickrate / 60

				if(vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET) then

					if vehicle_object.state.s == VEHICLE.STATE.PATHING then

						ai_speed_pseudo = v.getSpeed(vehicle_object)

						if #vehicle_object.path == 0 then
							AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
						else
							if ai_state ~= 2 then ai_state = 1 end

							ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

							if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then ai_target[14] = 0 end
	
							local vehicle_pos = vehicle_object.transform
							local distance = m.xzDistance(ai_target, vehicle_pos)
	
							if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE and distance < WAYPOINT_CONSUME_DISTANCE * 4 and vehicle_object.role == "scout" or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.HELI or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND and distance < 7 then
								if #vehicle_object.path > 0 then
									p.nextPath(vehicle_object)

									if #vehicle_object.path > 0 then
										ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)
									end

									--[[update the current path the vehicle is on for cargo vehicles
									if vehicle_object.role == SQUAD.COMMAND.CARGO then
										g_savedata.cargo_vehicles[vehicle_id].path_data.current_path = g_savedata.cargo_vehicles[vehicle_id].path_data.current_path + 1
									end
									]]

								elseif vehicle_object.role == "scout" then
									p.resetPath(vehicle_object)
									target_island, origin_island = Objective.getIslandToAttack(true)
									if target_island then
										local holding_route = g_holding_pattern
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[1].x, CRUISE_HEIGHT * 2, holding_route[1].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[2].x, CRUISE_HEIGHT * 2, holding_route[2].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[3].x, CRUISE_HEIGHT * 2, holding_route[3].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[4].x, CRUISE_HEIGHT * 2, holding_route[4].z)))
									end
								elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
									-- if we have reached last waypoint start holding there
									--d.print("set plane "..vehicle_id.." to holding", true, 0)
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and distance < WAYPOINT_CONSUME_DISTANCE then
								if #vehicle_object.path > 0 then
									p.nextPath(vehicle_object)
								else
									-- if we have reached last waypoint start holding there
									--d.print("set boat "..vehicle_id.." to holding", true, 0)
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							end
						end

						if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then 
							if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then
								ai_state = 3
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then
								target_pos = nil
								if pl.isPlayer(vehicle_object.target_player_id) then
									target_pos = s.getPlayerPos(g_savedata.player_data[vehicle_object.target_player_id].peer_id)
								elseif vehicle_object.target_vehicle_id then
									target_pos = s.getVehiclePos(vehicle_object.target_vehicle_id)
								end
								
								if target_pos and target_pos[14] >= 50 then
									ai_state = 2
								else
									ai_state = 1
								end
							end

						end


						refuel(vehicle_id)
					elseif vehicle_object.state.s == VEHICLE.STATE.HOLDING then

						ai_speed_pseudo = (vehicle_object.speed.speed or VEHICLE.SPEED.PLANE) * vehicle_update_tickrate / 60

						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							ai_state = 0
						elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
							local target = nil
							if squad_index ~= RESUPPLY_SQUAD_INDEX then -- makes sure its not resupplying
								local squad_vision = squadGetVisionData(squad)
								if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
									target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj
								elseif pl.isPlayer(vehicle_object.target_player_id) and vehicle_object.target_player_id and squad_vision.visible_players_map[vehicle_object.target_player_id] then
									target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
								end
								if target and m.distance(vehicle_object.transform, target.last_known_pos) > 35 then
									ai_target = target.last_known_pos
									local distance = m.distance(vehicle_object.transform, ai_target)
									local possiblePaths = s.pathfind(vehicle_object.transform, ai_target, "land_path", "")
									local is_better_pos = false
									for path_index, path in pairs(possiblePaths) do
										if m.distance(m.translation(path.x, path.y, path.z), ai_target) < distance then
											is_better_pos = true
										end
									end
									if is_better_pos then
										p.addPath(vehicle_object, ai_target)
										--? if its target is at least 5 metres above sea level and its target is within 35 metres of its final waypoint.
										if ai_target[14] > 5 and m.xzDistance(ai_target, m.translation(vehicle_object.path[#vehicle_object.path].x, 0, vehicle_object.path[#vehicle_object.path].z)) < 35 then
											--* replace its last path be where the target is.
											vehicle_object.path[#vehicle_object.path] = {
												x = ai_target[13],
												y = ai_target[14],
												z = ai_target[15],
												ui_id = vehicle_object.path[#vehicle_object.path].ui_id
											}
										end
									else
										ai_state = 0
									end
								else
									ai_state = 0
								end
							end
						else
							ai_target = m.translation(vehicle_object.holding_target[13] + g_holding_pattern[vehicle_object.holding_index].x, vehicle_object.holding_target[14], vehicle_object.holding_target[15] + g_holding_pattern[vehicle_object.holding_index].z)

							vehicle_object.path[1] = {
								x = ai_target[13],
								y = ai_target[14],
								z = ai_target[15],
								ui_id = (vehicle_object.path[1] and vehicle_object.path[1].ui_id) and vehicle_object.path[1].ui_id or s.getMapID()
							}

							ai_state = 1

							local distance = m.distance(ai_target, vehicle_object.transform)

							if distance < WAYPOINT_CONSUME_DISTANCE then
								vehicle_object.holding_index = 1 + ((vehicle_object.holding_index) % 4);
							end
						end
					end

					--set ai behaviour
					if ai_target ~= nil then
						if vehicle_object.state.is_simulating then
							if not g_air_vehicles_kamikaze or (vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE and vehicle_object.vehicle_type ~= VEHICLE.TYPE.HELI) then 
								s.setAITarget(vehicle_object.survivors[1].id, ai_target)
								s.setAIState(vehicle_object.survivors[1].id, ai_state)
							end
						else
							local exhausted_movement = false
							local pseudo_speed_modifier = 0

							local current_pos = vehicle_object.transform

							while not exhausted_movement do
								local movement_x = ai_target[13] - current_pos[13]
								local movement_y = ai_target[14] - current_pos[14]
								local movement_z = ai_target[15] - current_pos[15]

								local length_xz = math.sqrt((movement_x * movement_x) + (movement_z * movement_z))

								local speed_pseudo = (ai_speed_pseudo * g_debug_speed_multiplier) - pseudo_speed_modifier

								if math.noNil(math.abs(movement_x * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_x)) and math.noNil(math.abs(movement_z * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_z)) or not vehicle_object.path[2] then
									exhausted_movement = true
								end

								movement_x = math.clamp(movement_x * speed_pseudo / length_xz, -math.abs(movement_x), math.abs(movement_x))
								movement_y = math.clamp(movement_y * speed_pseudo / length_xz, -math.abs(movement_y), math.abs(movement_y))
								movement_z = math.clamp(movement_z * speed_pseudo / length_xz, -math.abs(movement_z), math.abs(movement_z))

								local rotation_matrix = m.rotationToFaceXZ(movement_x, movement_z)
								local new_pos = m.multiply(m.translation(current_pos[13] + movement_x, current_pos[14] + movement_y, current_pos[15] + movement_z), rotation_matrix)

								if s.getVehicleLocal(vehicle_id) == false then
									s.setVehiclePos(vehicle_id, new_pos)
									vehicle_object.transform = new_pos

									for npc_index, npc_object in pairs(vehicle_object.survivors) do
										s.setObjectPos(npc_object.id, new_pos)
									end

									if vehicle_object.fire_id ~= nil then
										s.setObjectPos(vehicle_object.fire_id, new_pos)
									end
								end

								if not exhausted_movement then
									p.nextPath(vehicle_object)

									ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

									pseudo_speed_modifier = math.abs(movement_x) + math.abs(movement_y) + math.abs(movement_z)

									current_pos = new_pos
								end
							end
						end
					end
				end

				if d.getDebug(3) then
					local debug_data = ""
					debug_data = debug_data.."Movement State: "..vehicle_object.state.s .. "\n"
					debug_data = debug_data.."Waypoints: "..#vehicle_object.path .."\n\n"
					
					debug_data = debug_data.."Squad: "..squad_index .."\n"
					debug_data = debug_data.."Command: "..squad.command .."\n"
					debug_data = debug_data.."AI State: "..ai_state .. "\n"

					-- cargo data
					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						local cargo_data = g_savedata.cargo_vehicles[vehicle_object.id]
						debug_data = debug_data.."\nOil: "..tostring(vehicle_object.cargo.current.oil).."\n"
						debug_data = debug_data.."Diesel: "..tostring(vehicle_object.cargo.current.diesel).."\n"
						debug_data = debug_data.."Jet Fuel: "..tostring(vehicle_object.cargo.current.jet_fuel).."\n"
						if cargo_data then
							debug_data = debug_data.."Cargo Route Status: "..cargo_data.route_status.."\n"
						end
					end

					if squad.command == SQUAD.COMMAND.CARGO then
						debug_data = debug_data.."Convoy Status: "..tostring(vehicle_object.state.convoy.status)
						if vehicle_object.state.convoy.status == CONVOY.WAITING then
							debug_data = debug_data.." for: "..tostring(vehicle_object.state.convoy.waiting_for)
							debug_data = debug_data.."\nReason: "..tostring(vehicle_object.state.convoy.status_reason).."\n"
						end
					end

					debug_data = debug_data.."\nHome Island: "..vehicle_object.home_island.name.."\n"
					if squad.target_island then 
						debug_data = debug_data.."Target Island: "..squad.target_island.name.."\n" 
					end
					debug_data = debug_data .. "Target Player: "..(vehicle_object.target_player_id and g_savedata.player_data[vehicle_object.target_player_id].name or "nil").."\n"
					debug_data = debug_data .. "Target Vehicle: "..(vehicle_object.target_vehicle_id and vehicle_object.target_vehicle_id or "nil").."\n\n"

					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						local squad_vision = squadGetVisionData(squad)
						debug_data = debug_data .. "squad visible players: " .. #squad_vision.visible_players .."\n"
						debug_data = debug_data .. "squad visible vehicles: " .. #squad_vision.visible_vehicles .."\n"
						debug_data = debug_data .. "squad investigate players: " .. #squad_vision.investigate_players .."\n"
						debug_data = debug_data .. "squad investigate vehicles: " .. #squad_vision.investigate_vehicles .."\n\n"
					end

					local hp = vehicle_object.health * g_savedata.settings.ENEMY_HP_MODIFIER

					if g_savedata.settings.SINKING_MODE then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
							hp = hp * 2.5
						else
							hp = hp * 8
							if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
								hp = hp * 10
							end
						end
					end
					
					debug_data = debug_data .. "hp: " .. (hp - vehicle_object.current_damage) .. " / " .. hp .. "\n"

					local damage_dealt = 0
					for victim_vehicle, damage in pairs(vehicle_object.damage_dealt) do
						damage_dealt = damage_dealt + damage
					end
					debug_data = debug_data.."Damage Dealt: "..damage_dealt.."\n\n"

					debug_data = debug_data.."Base Visiblity Range: "..vehicle_object.vision.base_radius.."\n"
					debug_data = debug_data.."Current Visibility Range: "..vehicle_object.vision.radius.."\n"
					debug_data = debug_data.."Has Radar: "..(vehicle_object.vision.is_radar and "true" or "false").."\n"
					debug_data = debug_data.."Has Sonar: "..(vehicle_object.vision.is_sonar and "true" or "false").."\n\n"

					local ai_speed_pseudo = tostring(v.getSpeed(vehicle_object))

					debug_data = debug_data.."Pseudo Speed: "..ai_speed_pseudo.." m/s\n"
					
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						debug_data = debug_data.."Is Agressive: "..tostring(vehicle_object.is_aggressive).."\n"
						debug_data = debug_data.."Terrain Type: "..tostring(vehicle_object.terrain_type).."\n"
					end

					debug_data = debug_data .. "\nPos: [" .. math.floor(vehicle_object.transform[13]) .. " ".. math.floor(vehicle_object.transform[14]) .. " ".. math.floor(vehicle_object.transform[15]) .. "]\n"
					if ai_target then
						debug_data = debug_data .. "Dest: [" .. math.floor(ai_target[13]) .. " ".. math.floor(ai_target[14]) .. " ".. math.floor(ai_target[15]) .. "]\n"

						local dist_to_dest = m.xzDistance(vehicle_object.transform, ai_target)
						debug_data = debug_data .. "Dist: " .. math.floor(dist_to_dest) .. "m\n"
					end

					if vehicle_object.state.is_simulating then
						debug_data = debug_data .. "\nSIMULATING\n"
						debug_data = debug_data .. "needs resupply: " .. tostring(isVehicleNeedsResupply(vehicle_id, "Resupply")) .. "\n"
					else
						debug_data = debug_data .. "\nPSEUDO\n"
						debug_data = debug_data .. "resupply on load: " .. tostring(vehicle_object.is_resupply_on_load) .. "\n"
					end

					local state_icons = {
						[SQUAD.COMMAND.ATTACK] = 18,
						[SQUAD.COMMAND.STAGE] = 2,
						[SQUAD.COMMAND.ENGAGE] = 5,
						[SQUAD.COMMAND.DEFEND] = 19,
						[SQUAD.COMMAND.PATROL] = 15,
						[SQUAD.COMMAND.TURRET] = 14,
						[SQUAD.COMMAND.RESUPPLY] = 11,
						[SQUAD.COMMAND.SCOUT] = 4,
						[SQUAD.COMMAND.INVESTIGATE] = 6,
						[SQUAD.COMMAND.CARGO] = 17
					}
					local r = 0
					local g = 0
					local b = 225
					local vehicle_icon = debug_mode_blinker and 16 or state_icons[squad.command]
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						r = 55
						g = 255
						b = 125
						vehicle_icon = debug_mode_blinker and 12 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then
						r = 255
						b = 200
						vehicle_icon = debug_mode_blinker and 15 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then
						r = 55
						g = 200
						vehicle_icon = debug_mode_blinker and 13 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
						r = 131
						g = 101
						b = 57
						vehicle_icon = debug_mode_blinker and 14 or state_icons[squad.command]
					end
					if vehicle_object.role == "cargo" then
						local cargo_modifier = 35
						r = math.abs(r - cargo_modifier)
						g = math.abs(g - cargo_modifier)
						b = math.abs(b - cargo_modifier)
					elseif squad.command == SQUAD.COMMAND.CARGO then
						local escort_modifier = 35
						r = math.min(r + escort_modifier, 255)
						g = math.min(g + escort_modifier, 255)
						b = math.min(b + escort_modifier, 255)
					end

					-- the marker type, aka, the icon of the vehicle on the map
					local marker_type = vehicle_icon or 3

					--[[
						the name (title) of the marker when hovered over on the map
						Format:
							<Vehicle Name>
							Vehicle ID: <vehicle_id>
							Vehicle Type: <vehicle_type>
					]]
					local vehicle_name = ("%s\nVehicle ID: %i\nVehicle Type: %s"):format(vehicle_object.name, vehicle_object.id, vehicle_object.vehicle_type)

					s.removeMapLine(-1, vehicle_object.ui_id)
					s.removeMapObject(-1, vehicle_object.ui_id)
					s.removeMapLabel(-1, vehicle_object.ui_id)

					for _, peer in pairs(s.getPlayers()) do
						if d.getDebug(3, peer.id) then

							--[[
								parent it to the vehicle if the player we're drawing it for is the host or if the vehicle is simulating
								as if a vehicle is unloaded, clients will not recieve the vehicle's position from the server, causing it
								to instead be drawn at 0, 0
							]]
							if peer.id == 0 or vehicle_object.state.is_simulating then
								s.addMapObject(peer.id, vehicle_object.ui_id, 1, marker_type, 0, 0, 0, 0, vehicle_id, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
							else -- draw at direct coordinates instead
								s.addMapObject(peer.id, vehicle_object.ui_id, 0, marker_type, vehicle_object[13], vehicle_object[15], 0, 0, 0, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
							end

							if(#vehicle_object.path >= 1) then

								local waypoint_pos_next = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

								-- get colour from angle
								local angle = math.atan(waypoint_pos_next[13] - vehicle_object.transform[13], waypoint_pos_next[15] - vehicle_object.transform[15])/math.tau*math.pi

								local colour_modifier = 25

								local line_r = math.floor(math.clamp(math.clamp(r, 0, 200) + (angle*colour_modifier), 0, 255))
								local line_g = math.floor(math.clamp(math.clamp(g, 0, 200) + (angle*colour_modifier), 0, 255))
								local line_b = math.floor(math.clamp(math.clamp(b, 0, 200) + (angle*colour_modifier), 0, 255))

								s.addMapLine(peer.id, vehicle_object.ui_id, vehicle_object.transform, waypoint_pos_next, 0.5, line_r, line_g, line_b, 200)

								local dest_radius = 5

								-- if this is the only path
								if #vehicle_object.path == 1 then
									--? draw x at the destination
									s.addMapLabel(peer.id, vehicle_object.ui_id, 1, vehicle_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
								end

								for i = 1, #vehicle_object.path - 1 do
									local waypoint = vehicle_object.path[i]
									local waypoint_next = vehicle_object.path[i + 1]

									local waypoint_pos = m.translation(waypoint.x, waypoint.y, waypoint.z)
									local waypoint_pos_next = m.translation(waypoint_next.x, waypoint_next.y, waypoint_next.z)

									local angle = math.atan(waypoint_pos_next[13] - waypoint_pos[13], waypoint_pos_next[15] - waypoint_pos[15])/math.tau*math.pi

									local line_r = math.floor(math.clamp(math.clamp(r, 0, 200) + (angle*colour_modifier), 0, 255))
									local line_g = math.floor(math.clamp(math.clamp(g, 0, 200) + (angle*colour_modifier), 0, 255))
									local line_b = math.floor(math.clamp(math.clamp(b, 0, 200) + (angle*colour_modifier), 0, 255))

									s.removeMapLine(peer.id, waypoint.ui_id)
									s.addMapLine(peer.id, waypoint.ui_id, waypoint_pos, waypoint_pos_next, 0.5, line_r, line_g, line_b, 200)

									-- if this is the last path
									if i == #vehicle_object.path - 1 then
										--? draw x at the destination
										s.addMapLabel(peer.id, vehicle_object.ui_id, 1, vehicle_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
									end
								end
							end
						end
					end
				end
			end
			::continue_vehicle::
		end
	end
	d.stopProfiler("tickVehicles()", true, "onTick()")
end

function tickUpdateVehicleData()
	d.startProfiler("tickUpdateVehicleData()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 30) then
				vehicle_object.transform = s.getVehiclePos(vehicle_id)
			end
		end
	end

	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then
			player_vehicle.transform = s.getVehiclePos(player_vehicle_id)
		end
	end
	d.stopProfiler("tickUpdateVehicleData()", true, "onTick()")
end

function tickModifiers()
	d.startProfiler("tickModifiers()", true)
	if isTickID(g_savedata.tick_counter, time.hour / 2) then -- defence, if the player has attacked within the last 30 minutes, increase defence
		if g_savedata.tick_counter - g_savedata.ai_history.has_defended <= time.hour / 2 and g_savedata.ai_history.has_defended ~= 0 then -- if the last time the player attacked was equal or less than 30 minutes ago
			sm.train(REWARD, "defend", 4)
			sm.train(PUNISH, "attack", 3)
			d.print("players have attacked within the last 30 minutes! increasing defence, decreasing attack!", true, 0)
		end
	end
	if isTickID(g_savedata.tick_counter, time.hour) then -- attack, if the player has not attacked in the last one hour, raise attack
		if g_savedata.tick_counter - g_savedata.ai_history.has_defended > time.hour then -- if the last time the player attacked was more than an hour ago
			sm.train(REWARD, "attack", 3)
			d.print("players have not attacked in the past hour! increasing attack!", true, 0)
		end
	end
	if isTickID(g_savedata.tick_counter, time.hour * 2) then -- defence, if the player has not attacked in the last two hours, then lower defence
		if g_savedata.tick_counter - g_savedata.ai_history.has_defended > time.hour * 2 then -- if the last time the player attacked was more than two hours ago
			sm.train(PUNISH, "defend", 3)
			d.print("players have not attacked in the last two hours! lowering defence!", true, 0)
		end
	end

	-- checks if the player is nearby the ai's controlled islands, works like a capacitor, however the
	-- closer the player is, the faster it will charge up, once it hits its limit, it will then detect that the
	-- player is attacking, and will then use that to tell the ai to increase on defence
	for island_index, island in pairs(g_savedata.islands) do
		if isTickID(island_index * 30, time.minute / 2) then
			if island.faction == ISLAND.FACTION.AI then
				local player_list = s.getPlayers()
				for player_index, player in pairs(player_list) do
					local player_pos = s.getPlayerPos(player.id)
					local player_island_dist = m.xzDistance(player_pos, island.transform)
					if player_island_dist < 1000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 3
					elseif player_island_dist < 2000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 2
					elseif player_island_dist < 3000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 1
					end
					if g_savedata.ai_history.defended_charge >= 6 then
						g_savedata.ai_history.defended_charge = 0
						g_savedata.ai_history.has_defended = g_savedata.tick_counter
						island.last_defended = g_savedata.tick_counter
						d.print(player.name.." has been detected to be attacking "..island.name..", the ai will be raising their defences!", true, 0)
					end
				end
			end
		end
	end
	d.stopProfiler("tickModifiers()", true, "onTick()")
end

--[[ no longer has a use, replaced by automatic migration in 0.3.0.78
function tickOther()
	d.startProfiler("tickOther()", true)
	
	d.stopProfiler("tickOther()", true, "onTick()")
end
-]]

function tickCargo()
	d.startProfiler("tickCargo()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled

		-- ticks cargo production and consumption
		for island_index, island in pairs(g_savedata.islands) do -- at every island
			if isTickID(island.index, time.minute) then -- every minute
				Cargo.produce(island) -- produce cargo
			end
		end

		if isTickID(g_savedata.ai_base_island.index, time.minute) then -- if its the tick for the AI base Island
			Cargo.produce(g_savedata.ai_base_island, RULES.LOGISTICS.CARGO.ISLANDS.ai_base_generation/60)
		end

		-- ticks resupplying islands
		if table.length(g_savedata.cargo_vehicles) ~= 0 then
			g_savedata.tick_extensions.cargo_vehicle_spawn = g_savedata.tick_extensions.cargo_vehicle_spawn + 1
		elseif isTickID(g_savedata.tick_extensions.cargo_vehicle_spawn, RULES.LOGISTICS.CARGO.VEHICLES.spawn_time) then -- attempt to spawn a cargo vehicle
			d.print("attempting to spawn cargo vehicle", true, 0)

			local resupply_island, resupply_weights = Cargo.getBestResupplyIsland()

			if resupply_island then
				d.print("(tickCargo) Island that needs resupply the most: "..resupply_island.name, true, 0)
				local resupplier_island, total_weights = Cargo.getBestResupplierIsland(resupply_weights)
				if resupplier_island then
					d.print("(tickCargo) Island best to resupply the island: "..resupplier_island.name, true, 0)
					local best_route = Cargo.getBestRoute(resupplier_island, resupply_island)
					if not best_route[1] then
						d.print("best route doesnt exist?", true, 1)
					else

						-- parse the route

						d.print("(tickCargo) from island: "..resupplier_island.name, true, 0)
						for route_index, route in ipairs(best_route) do
							d.print("\n(tickCargo) Route Index: "..route_index, true, 0)
							local island, got_island = is.getDataFromIndex(route.island_index)
							d.print("(tickCargo) to island: "..island.name, true, 0)
							if route.transport_method then
								d.print("(tickCargo) with vehicle: "..route.transport_method.name.." | "..route.transport_type, true, 0)
							else
								if route.transport_type then
									d.print("(tickCargo) type: "..route.transport_type, true, 0)
								end
								d.print("(tickCargo) transport method is nil?", true, 1)
								return
							end
						end
						d.print("spawning cargo vehicle...", true, 0)
						local was_spawned, vehicle_data = v.spawnRetry(sm.getVehicleListID(best_route[1].transport_method.name), nil, true, resupplier_island, 1, 20)
						if not was_spawned then
							d.print("Was unable to spawn cargo vehicle! Error: "..vehicle_data, true, 1)
						else
							-- add it to the cargo vehicles list

							local requested_cargo = Cargo.getRequestedCargo(total_weights, vehicle_data)

							-- make sure we dont try to send more than we can transport, recieve or that we have
							for slot, cargo in pairs(requested_cargo) do
								cargo.amount = math.min(cargo.amount, resupplier_island.cargo[cargo.cargo_type], RULES.LOGISTICS.CARGO.ISLANDS.max_capacity - resupply_island.cargo[cargo.cargo_type])
							end


							---@class CARGO_VEHICLE
							g_savedata.cargo_vehicles[vehicle_data.id] = {
								vehicle_data = vehicle_data,
								resupplier_island = resupplier_island,
								resupply_island = resupply_island,
								route_data = best_route,
								route_status = 0,
								requested_cargo = requested_cargo,
								path_data = {
									current_path = 1,
									path = {},
									speed = nil,
									can_offroad = true
								},
								convoy = {},
								search_area = {
									ui_id = s.getMapID(),
									x = nil,
									z = nil
								}
							}

							-- get escorts
							Cargo.getEscorts(vehicle_data, resupplier_island)

							-- get the slowest speed of all of them and if we can offroad
							local squad_index, squad = Squad.getSquad(vehicle_data.id)
							for vehicle_index, vehicle_object in pairs(squad.vehicles) do

								-- getting slowest speed
								local vehicle_speed = v.getSpeed(vehicle_object, true, true)
								if not g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed > vehicle_speed then
									g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed = vehicle_speed
								end

								-- checking if we can offroad
								if not vehicle_object.can_offroad then
									g_savedata.cargo_vehicles[vehicle_data.id].path_data.can_offroad = false
								end
							end
						end
					end
				else
					d.print("(tickCargo) No islands found that can be a resupplier (Potential Error)", true, 0)
				end
			else
				d.print("(tickCargo) No islands found that need resupply (Potential Error)", true, 0)
			end
		end
	end
	d.stopProfiler("tickCargo()", true, "onTick()")
end

function tickIslands()
	d.startProfiler("tickIslands()", true)

	--* go through and set the cargo tanks for each island, to sync the cargo in the script with the cargo on the island
	if g_savedata.settings.CARGO_MODE then
		for island_index, _ in pairs(g_savedata.loaded_islands) do

			if not isTickID(island_index, 15) then
				goto break_island
			end

			local island, got_island = Island.getDataFromIndex(island_index)

			if not got_island then
				d.print("(tickIslands) Island not found! island_index: "..tostring(island_index), true, 1)
				goto break_island
			end

			if island.cargo.oil <= 0 and island.cargo.diesel <= 0 and island.cargo.jet_fuel <= 0 then
				goto break_island
			end

			local fluid_types = {
				oil = 5,
				diesel = 1,
				jet_fuel = 2
			}

			for cargo_type, amount in pairs(island.cargo) do
				local tank_data, got_tank = s.getVehicleTank(island.flag_vehicle.id, cargo_type)
				if got_tank then
					s.setVehicleTank(island.flag_vehicle.id, cargo_type, math.min(tank_data.capacity, island.cargo[cargo_type]), fluid_types[cargo_type])
					island.cargo[cargo_type] = island.cargo[cargo_type] - (math.min(tank_data.capacity, island.cargo[cargo_type]) - tank_data.value)
					s.setVehicleKeypad(island.flag_vehicle.id, cargo_type, island.cargo[cargo_type])
				end
			end

			if g_savedata.islands[island_index] then
				g_savedata.islands[island_index].cargo = island.cargo
			elseif g_savedata.ai_base_island.index == island_index then
				g_savedata.ai_base_island.cargo = island.cargo
			elseif g_savedata.player_base_island.index == island_index then
				g_savedata.player_base_island.cargo = island.cargo
			end

			::break_island::
		end
	end

	d.stopProfiler("tickIslands()", true, "onTick()")
end

local cargo_vehicle_tickrate = time.second/4

function tickCargoVehicles()
	d.startProfiler("tickCargoVehicles()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled
		for cargo_vehicle_index, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
			if isTickID(cargo_vehicle_index, cargo_vehicle_tickrate) then

				local vehicle_object, squad_index, squad = Squad.getVehicle(cargo_vehicle.vehicle_data.id)

				-- temporary backwards compatibility for testing version
				if not cargo_vehicle.search_area then
					cargo_vehicle.search_area = {
						ui_id = s.getMapID(),
						x = nil,
						z = nil
					}
				end

				--* draw a search radius around the cargo vehicle

				local search_radius = 1850

				if not cargo_vehicle.search_area.x or m.xzDistance(vehicle_object.transform, m.translation(cargo_vehicle.search_area.x, 0, cargo_vehicle.search_area.z)) >= search_radius then
					--* remove previous search area
					s.removeMapID(-1, cargo_vehicle.search_area.ui_id)

					--* add new search area
					local x, z, was_drawn = Map.drawSearchArea(vehicle_object.transform[13], vehicle_object.transform[15], search_radius, cargo_vehicle.search_area.ui_id, -1, "Convoy", "An enemy AI convoy has been detected to be within this area.\nFind and prevent the cargo from arriving to its destination.", 0, 210, 50, 255)

					if not was_drawn then
						d.print("(tickCargoVehicles) failed to draw search area for cargo vehicle "..tostring(vehicle_object.id), true, 1)
					else
						cargo_vehicle.search_area.x = x
						cargo_vehicle.search_area.z = z
					end
				end


				--* sync the script's cargo with the true cargo

				--? if the cargo vehicle is simulating and its in the pathing stage
				if cargo_vehicle.vehicle_data.state.is_simulating and cargo_vehicle.route_status == 1 then
					local cargo_data, got_data = Cargo.getTank(cargo_vehicle.vehicle_data.id)
					if got_data then
						cargo_vehicle.requested_cargo = cargo_data

						for cargo_type, _ in pairs(cargo_vehicle.vehicle_data.cargo.current) do
							cargo_vehicle.vehicle_data.cargo.current[cargo_type] = 0
						end

						for slot, cargo in pairs(cargo_data) do
							cargo_vehicle.vehicle_data.cargo.current[cargo.cargo_type] = cargo_vehicle.vehicle_data.cargo.current[cargo.cargo_type] + cargo.amount
						end
					end
				end

				--* tick cargo vehicle behaviour

				--? if the vehicle is in the first stage (loading up with cargo)
				cargo_vehicle.vehicle_data = vehicle_object
				if cargo_vehicle.route_status == 0 then
					local transfer_complete, transfer_complete_reason = Cargo.transfer(cargo_vehicle.vehicle_data, cargo_vehicle.resupplier_island, cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
					if transfer_complete then
						d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
						-- start going on its route
						local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)
						if found_island then
							cargo_vehicle.route_status = 1
							local squad_index, squad = Squad.getSquad(cargo_vehicle.vehicle_data.id)
							squad.target_island = island
							p.addPath(cargo_vehicle.vehicle_data, island.transform)
							table.insert(cargo_vehicle.vehicle_data.path, 1, {
								x = cargo_vehicle.vehicle_data.transform[13],
								y = cargo_vehicle.vehicle_data.transform[14],
								z = cargo_vehicle.vehicle_data.transform[15]
							})
							cargo_vehicle.path_data.path = cargo_vehicle.vehicle_data.path
							g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.id].path = cargo_vehicle.vehicle_data.path
						else
							d.print("(tickCargoVehicles) island not found! Error: "..island, true, 1)
						end
					end
				-- if the cargo vehicle is in the pathing stage
				elseif cargo_vehicle.route_status == 1 then
					local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)

					local distance_thresholds = {
						plane = 1000,
						boat = 850,
						heli = 350,
						land = 150
					}

					if #cargo_vehicle.vehicle_data.path <= 1 or m.xzDistance(island.transform, cargo_vehicle.vehicle_data.transform) < distance_thresholds[(cargo_vehicle.vehicle_data.vehicle_type)] then
						cargo_vehicle.route_status = 2 -- make it unload the cargo
						table.remove(cargo_vehicle.route_data, 1)
						d.print("transferring cargo", true, 0)
					end
				-- if the cargo vehicle is in the transfering stage
				elseif cargo_vehicle.route_status == 2 then
					-- if its transfering to the next vehicle
					if cargo_vehicle.route_data[1] then
						-- spawn it if it doesnt already exist
						local new_cargo_vehicle = nil
						for next_cargo_vehicle_index, next_cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
							if next_cargo_vehicle.vehicle_data.name == cargo_vehicle.route_data[1].transport_method.name then
								new_cargo_vehicle = g_savedata.cargo_vehicles[next_cargo_vehicle.vehicle_data.id]
								break
							end
						end

						if not new_cargo_vehicle then
							-- spawn it as it doesnt exist
							local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)
							local was_spawned, vehicle_data = v.spawnRetry(sm.getVehicleListID(cargo_vehicle.route_data[1].transport_method.name), nil, true, island, 1, 20)
							if not was_spawned then
								d.print("Was unable to spawn cargo vehicle! Error: "..vehicle_data, true, 1)
							else
								-- add it to the cargo vehicles list

								---@class CARGO_VEHICLE
								g_savedata.cargo_vehicles[vehicle_data.id] = {
									vehicle_data = vehicle_data,
									resupplier_island = cargo_vehicle.resupplier_island,
									resupply_island = cargo_vehicle.resupply_island,
									route_data = cargo_vehicle.route_data,
									route_status = 3, -- do nothing
									requested_cargo = cargo_vehicle.requested_cargo,
									path_data = {
										current_path = 1,
										path = {},
										speed = nil,
										can_offroad = true
									},
									convoy = {},
									search_area = {
										ui_id = s.getMapID(),
										x = nil,
										z = nil
									}
								}

								table.remove(g_savedata.cargo_vehicles[vehicle_data.id].route_data, 1)
									

								-- get escorts
								Cargo.getEscorts(vehicle_data, island)

								-- get the slowest speed of all of them and if we can offroad
								local squad_index, squad = Squad.getSquad(vehicle_data.id)
								for vehicle_index, vehicle_object in pairs(squad.vehicles) do

									-- getting slowest speed
									local vehicle_speed = v.getSpeed(vehicle_object, true, true)
									if not g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed > vehicle_speed then
										g_savedata.cargo_vehicles[vehicle_data.id].path_data.speed = vehicle_speed
									end

									-- checking if we can offroad
									if not vehicle_object.can_offroad then
										g_savedata.cargo_vehicles[vehicle_data.id].path_data.can_offroad = false
									end
								end
							end
						else
							-- if it does exist
							local transfer_complete, transfer_complete_reason = Cargo.transfer(new_cargo_vehicle.vehicle_data, cargo_vehicle.vehicle_data, new_cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
							if transfer_complete and not cargo_vehicle.vehicle_data.is_killed then
								d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
								-- kill old cargo vehicle
								v.kill(cargo_vehicle.vehicle_data.id, true) -- kills the vehicle thats now empty

								-- tell new cargo vehicle to go on its route

								local island, found_island = Island.getDataFromIndex(new_cargo_vehicle.route_data[1].island_index)
								if found_island then
									new_cargo_vehicle.route_status = 1
									local _, squad = Squad.getSquad(cargo_vehicle.vehicle_data.id)
									squad.target_island = island
									p.addPath(new_cargo_vehicle.vehicle_data, island.transform)
									new_cargo_vehicle.path_data.path = new_cargo_vehicle.vehicle_data.path
								else
									d.print("(tickCargoVehicles) island not found! Error: "..island, true, 1)
								end
							end
						end
					-- if its transfering to the island which needed the resupply
					else
						local transfer_complete, transfer_complete_reason = Cargo.transfer(cargo_vehicle.resupply_island, cargo_vehicle.vehicle_data, cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
						
						if transfer_complete and not cargo_vehicle.vehicle_data.is_killed then
							d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
							v.kill(cargo_vehicle.vehicle_data.id, true) -- kills the vehicle thats now empty
						end
					end
				end
			end
		end
	end
	d.stopProfiler("tickCargoVehicles()", true, "onTick()")
end

function tickControls()
	d.startProfiler("tickControls()", true, "onTick()")
	local control_started = s.getTimeMillisec()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do

			--? is this vehicle even one we can handle
			if vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
				goto break_control_vehicle
			end

			--? is the vehicle loaded
			if not vehicle_object.state.is_simulating then
				goto break_control_vehicle
			end

			--? is the vehicle killed
			if vehicle_object.is_killed then
				goto break_control_vehicle
			end

			local reaction_time = 3 -- ticks
			--? if this is it's tick (reaction time)
			if not isTickID(vehicle_id, reaction_time) then
				goto break_control_vehicle
			end

			--? is the driver incapcitated, dead or non existant
			local driver_data = s.getCharacterData(vehicle_object.survivors[1].id)
			if not driver_data or driver_data.dead or driver_data.incapacitated then
				goto break_control_vehicle
			end

			--? if the driver is the one who's sitting in the driver seat
			local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_id)
			if not got_vehicle_data then
				goto break_control_vehicle
			end

			for seat_id, seat_data in pairs(vehicle_data.components.seats) do
				if seat_data.name == "Driver" and seat_data.seated_id ~= vehicle_object.survivors[1].id then

					if d.getDebug(5) then
						if vehicle_object.driving.ui_id then
							s.removeMapLine(-1, vehicle_object.driving.ui_id)
						end
					end

					goto break_control_vehicle
				end
			end


			--? we have at least 1 path
			if not vehicle_object.path[1] or (vehicle_object.path[0].x == vehicle_object.path[1].x and vehicle_object.path[0].y == vehicle_object.path[1].y and vehicle_object.path[0].z == vehicle_object.path[1].z) then

				if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
					-- resets seat
					AI.setSeat(vehicle_id, "Driver", 0, 0, 0, 0, false, false, false, false, false, false, false)
				end

				-- removes debug
				if d.getDebug(5) then
					if vehicle_object.driving.ui_id then
						s.removeMapLine(-1, vehicle_object.driving.ui_id)
					end
				end

				goto break_control_vehicle
			end

			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then

				vehicle_object.transform, got_pos = s.getVehiclePos(vehicle_id)
				if not got_pos then
					goto break_control_vehicle
				end

				local reverse_timer_max = math.floor((time.second*10)/reaction_time)

				-- sets driving data if it doesnt exist
				if not vehicle_object.driving.old_pos then
					vehicle_object.driving = {
						old_pos = m.translation(0, 0, 0),
						reverse_timer = reverse_timer_max/2,
						ui_id = vehicle_object.driving.ui_id
					}
				end

				local vehicle_vector = { -- a
					x = vehicle_object.transform[13] - vehicle_object.path[0].x,
					z = vehicle_object.transform[15] - vehicle_object.path[0].z
				}

				local path_vector = { -- b
					x = vehicle_object.path[1].x - vehicle_object.path[0].x,
					z = vehicle_object.path[1].z - vehicle_object.path[0].z
				}

				local path_vector_length = math.sqrt(path_vector.x^2 + path_vector.z^2)

				--d.print("path_vector_length: "..path_vector_length, true, 0)

				local path_progress = math.max(0, (vehicle_vector.x * path_vector.x + vehicle_vector.z * path_vector.z) / path_vector_length)

				local path_vector_normalized = {
					x = path_vector.x / path_vector_length,
					z = path_vector.z / path_vector_length
				}

				--d.print("path_progress: "..path_progress, true, 0)

				local pos_on_path = {
					x = vehicle_object.path[0].x + path_vector_normalized.x * path_progress,
					z = vehicle_object.path[0].z + path_vector_normalized.z * path_progress
				}

				local projected_dist = 20

				local path_projection = math.min(projected_dist, math.sqrt((vehicle_object.path[1].x-pos_on_path.x)^2+(vehicle_object.path[1].z-pos_on_path.z)^2)) -- metres

				--d.print("path_projection: "..path_projection, true, 0)
				if path_projection <= projected_dist/2 then
					p.nextPath(vehicle_object)
					goto break_control_vehicle
				end

				local target_pos = {
					x = vehicle_object.path[0].x + path_vector_normalized.x * (path_progress + path_projection),
					z = vehicle_object.path[0].z + path_vector_normalized.z * (path_progress + path_projection)
				}

				local target_angle = math.atan(target_pos.x - vehicle_object.transform[13], target_pos.z - vehicle_object.transform[15])

				local speed = v.getSpeed(vehicle_object)

				local x_axis, y_axis, z_axis = m.getMatrixRotation(vehicle_object.transform)
				--d.print("y_axis: "..y_axis, true, 0)
				--d.print("target_angle: "..target_angle, true, 0)
				local ad = math.wrap(y_axis - target_angle, -math.pi, math.pi)
				--d.print("ad: "..ad, true, 0)

				-- speed modifier for the upcoming turns (slows down for turns)
				local previous_yaw = math.atan(vehicle_object.path[1].x - vehicle_object.transform[13], vehicle_object.path[1].z - vehicle_object.transform[15])
				local total_dist = m.distance(vehicle_object.transform, m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)) -- the total distance checked so far, used for weight

				local max_dist = 300

				local min_speed = 6.5

				local speed_before = speed

				local next_paths_debug = {}

				for i = 0, #vehicle_object.path-1 do
					local dist = m.distance((i ~= 0 and m.translation(vehicle_object.path[i].x, vehicle_object.path[i].y, vehicle_object.path[i].z) or vehicle_object.transform), m.translation(vehicle_object.path[i + 1].x, vehicle_object.path[i + 1].y, vehicle_object.path[i + 1].z))
					total_dist = total_dist + dist
					--d.print("total_dist: "..total_dist, true, 0)

					local path_yaw = i ~= 0 and math.atan(vehicle_object.path[i+1].x - vehicle_object.path[i].x, vehicle_object.path[i+1].z - vehicle_object.path[i].z) or y_axis
					local yaw_difference = math.wrap(math.abs(previous_yaw - path_yaw), -math.pi, math.pi)

					local yaw_modifier = ((yaw_difference ^ yaw_difference)/4) / (math.max(((total_dist/1.5*(math.max(i, 1)/3))/(max_dist*16))*max_dist/8, 0.3)/3)
					if yaw_difference < 0.21 then
						yaw_modifier = math.max(1, (yaw_modifier - 1) / 12 + 1)
					end

					--d.print("i: "..i.."\nyaw_modifier: "..yaw_modifier, true, 0)

					speed = math.min(speed_before, math.max(speed/yaw_modifier, speed_before/4, min_speed))

					if d.getDebug(5) then
						table.insert(next_paths_debug, {
							origin_x = i ~= 0 and vehicle_object.path[i].x or vehicle_object.transform[13],
							origin_z = i ~= 0 and vehicle_object.path[i].z or vehicle_object.transform[15],
							target_x = vehicle_object.path[i+1].x,
							target_z = vehicle_object.path[i+1].z,
							speed_mult = (math.min(speed_before, math.max(speed/yaw_modifier, speed_before/4, min_speed))-min_speed)/(speed_before-min_speed)
						})
					end

					if total_dist > max_dist or speed/yaw_modifier < speed_before/4 or speed/yaw_modifier < min_speed then
						--d.print("breaking control path loop!", true, 0)
						break
					end

					previous_yaw = path_yaw
				end

				--d.print("speed_result: "..speed, true, 0)

				if m.distance(vehicle_object.driving.old_pos, vehicle_object.transform) < 0.01/(reaction_time/3) and vehicle_object.driving.reverse_timer == 0 then
					vehicle_object.driving.reverse_timer = reverse_timer_max
					--d.print("reversing! distance: "..tostring(m.distance(vehicle_object.driving.old_pos, vehicle_object.transform)), true, 0)
				end

				vehicle_object.driving.reverse_timer = math.max(vehicle_object.driving.reverse_timer - 1, 0)

				-- check if we want to reverse turn
				if math.abs(ad) > math.pi*1.45 then
					ad = -ad * 2
					speed = -speed
				end

				-- we keep this seperate, in case its stuck on a wall behind while reverse turning
				if vehicle_object.driving.reverse_timer >= reverse_timer_max/2 then
					ad = -ad * 2
					speed = -speed
				end

				if speed < 0 then
					speed = speed*0.85
				end

				if v.getTerrainType(vehicle_object.transform) ~= "road" then
					ad = ad * 2 -- double steering sensitivity if we're on a bridge or offroad (attempts to bring us on the road if offroad, and trys to make sure we dont fall off the bridge)
				end

				--d.print("speed: "..speed, true, 0)

				-- set old pos
				vehicle_object.driving.old_pos = vehicle_object.transform

				-- set steering
				--d.print("prev a/d: "..ad, true, 0)
				local ad = math.wrap(-(ad)/3, -math.pi, math.pi)
				--d.print("a/d: "..ad, true, 0)

				AI.setSeat(vehicle_id, "Driver", (speed/vehicle_object.speed.speed)/math.max(1, math.abs(ad)+0.6), ad, 0, 0, true, false, false, false, false, false, false)

				if d.getDebug(5) then
					-- calculate info for debug
					local length = 10
					local y_axis_x = vehicle_object.transform[13] + length * math.sin(y_axis)
					local y_axis_z = vehicle_object.transform[15] + length * math.cos(y_axis)
					local target_angle_x = vehicle_object.transform[13] + length * math.sin(target_angle)
					local target_angle_z = vehicle_object.transform[15] + length * math.cos(target_angle)
					
					local player_list = s.getPlayers()
					s.removeMapLine(-1, vehicle_object.driving.ui_id)
					for peer_index, peer in pairs(player_list) do
						if d.getDebug(5, peer.id) then
							if #next_paths_debug > 0 then
								for i=1, #next_paths_debug do
									-- line that shows the next paths, colour depending on how much the vehicle is slowing down for it, red = very slow, green = none
									s.addMapLine(peer.id, vehicle_object.driving.ui_id, m.translation(next_paths_debug[i].origin_x, 0, next_paths_debug[i].origin_z), m.translation(next_paths_debug[i].target_x, 0, next_paths_debug[i].target_z), 1, math.floor(math.clamp(255*(1-next_paths_debug[i].speed_mult), 0, 255)), math.floor(math.clamp(255*next_paths_debug[i].speed_mult, 0, 255)), 0, 200)
									--d.print("speed_mult: "..next_paths_debug[i].speed_mult, true, 0)
								end
							end
							-- blue line where its driving to
							s.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_pos.x, 0, target_pos.z), 2, 0, 0, 255, 200)

							-- cyan line where its pointing
							s.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(y_axis_x, 0, y_axis_z), 0.5, 0, 255, 255, 200)

							-- yellow line at target angle (where its wanting to go)
							s.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_angle_x, 0, target_angle_z), 0.5, 255, 255, 0, 200)
						end
					end
					
				end
				--d.print("TickID (60): "..((g_savedata.tick_counter + vehicle_id) % 60), true, 0)
			end

			--d.print("Time Taken: "..millisecondsSince(control_started).." | vehicle_id: "..vehicle_id, true, 0)

			::break_control_vehicle::
		end
	end
	d.stopProfiler("tickControls()", true, "onTick()")
end


function onTick()

	if g_savedata.debug.traceback.enabled then
		ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
	end

	if not is_dlc_weapons then
		return
	end
	
	if g_savedata.settings.PAUSE_WHEN_NONE_ONLINE then
		if #s.getPlayers() <= 0 then
			-- addon paused as nobody is online
			return
		end
	end

	g_savedata.tick_counter = g_savedata.tick_counter + 1

	d.startProfiler("onTick()", true)

	tickUpdateVehicleData()
	tickVision()
	tickGamemode()
	tickAI()
	tickSquadrons()
	tickVehicles()
	tickControls() -- ticks custom ai driving
	tickCargoVehicles()
	tickCargo()
	tickIslands()
	tickModifiers()
	-- tickOther()

	d.stopProfiler("onTick()", true, "onTick()")
	d.showProfilers()

	
end

function refuel(vehicle_id)
	-- jet fuel
	local i = 1
	repeat
		local tank_data, success = s.getVehicleTank(vehicle_id, "Jet "..i) -- checks if the next jet fuel container exists
		if success then
			s.setVehicleTank(vehicle_id, "Jet "..i, tank_data.capacity, 2) -- refuel the jet fuel container
		end
		i = i + 1
	until (not success)
	-- diesel
	local i = 1
	repeat
		local tank_data, success = s.getVehicleTank(vehicle_id, "Diesel "..i) -- checks if the next diesel container exists
		if success then
			s.setVehicleTank(vehicle_id, "Diesel "..i, tank_data.capacity, 1) -- refuel the diesel container
		end
		i = i + 1
	until (not success)
	-- batteries
	local i = 1
	repeat
		local batt_data, success = s.getVehicleBattery(vehicle_id, "Battery "..i) -- check if the next battery exists
		if success then
			s.setVehicleBattery(vehicle_id, "Battery "..i, 1) -- charge the battery
		end
		i = i + 1
	until (not success)
end

function reload(vehicle_id, from_storage)
	local i = 1
	repeat
		local ammo, success = s.getVehicleWeapon(vehicle_id, "Ammo "..i) -- get the number of ammo containers to reload
		if success then
			s.setVehicleWeapon(vehicle_id, "Ammo "..i, ammo.capacity) -- reload the ammo container
		end
		i = i + 1
	until (not success)
end

--[[
		Utility Functions
--]]

function build_locations(addon_index, location_index)
	local location_data = s.getLocationData(addon_index, location_index)

	local addon_components = {
		vehicles = {},
		survivors = {},
		objects = {},
		zones = {},
		fires = {}
	}

	local is_valid_location = false

	for object_index, object_data in iterObjects(addon_index, location_index) do

		for tag_index, tag_object in pairs(object_data.tags) do

			if tag_object == "type=dlc_weapons" then
				is_valid_location = true
			end
			if tag_object == "type=dlc_weapons_flag" then
				if object_data.type == "vehicle" then
					flag_prefab = { location_index = location_index, object_index = object_index}
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
		table.insert(built_locations, { location_index = location_index, data = location_data, objects = addon_components} )
	end
end

--------------------------------------------------------------------------------
--
-- VEHICLE HELPERS
--
--------------------------------------------------------------------------------

function isVehicleNeedsResupply(vehicle_id, button_name)
	local button_data, success = s.getVehicleButton(vehicle_id, button_name)
	return success and button_data.on
end

function isVehicleNeedsReload(vehicle_id)
	local needing_reload = false
	local gun_id = 0
	for i=1,6 do
		local needs_reload, is_success_button = s.getVehicleButton(vehicle_id, "AI_RELOAD_AMMO_"..i)
		if needs_reload ~= nil then
			if needs_reload.on and is_success_button then
				needing_reload = true
				gun_id = i
				break
			end
		end
	end
	local returnings = {}
	returnings[1] = needing_reload
	returnings[2] = gun_id
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
	setSquadCommand(squad, SQUAD.COMMAND.PATROL)
end

function setSquadCommandStage(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.STAGE)
end

function setSquadCommandAttack(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.ATTACK)
end

function setSquadCommandDefend(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.DEFEND)
end

function setSquadCommandEngage(squad)
	setSquadCommand(squad, SQUAD.COMMAND.ENGAGE)
end

function setSquadCommandInvestigate(squad, investigate_transform)
	squad.investigate_transform = investigate_transform
	setSquadCommand(squad, SQUAD.COMMAND.INVESTIGATE)
end

function setSquadCommandScout(squad)
	setSquadCommand(squad, SQUAD.COMMAND.SCOUT)
end

function setSquadCommand(squad, command)
	if squad.command ~= command then
		if squad.command ~= SQUAD.COMMAND.SCOUT or squad.command == SQUAD.COMMAND.SCOUT and command == SQUAD.COMMAND.DEFEND then
			if squad.command ~= SQUAD.COMMAND.CARGO then -- never change cargo vehicles being cargo vehicles
				squad.command = command
			
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					squadInitVehicleCommand(squad, vehicle_object)
				end

				if squad.command == SQUAD.COMMAND.NONE then
					resetSquadTarget(squad)
				elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
					squad.target_players = {}
					squad.target_vehicles = {}
				end

				return true
			end
		end
	end

	return false
end

function squadInitVehicleCommand(squad, vehicle_object)
	vehicle_object.target_vehicle_id = nil
	vehicle_object.target_player_id = nil

	if squad.command == SQUAD.COMMAND.PATROL then
		p.resetPath(vehicle_object)

		local patrol_route = {
			{ x=0, z=1000 },
			{ x=1000, z=0 },
			{ x=-0, z=-1000 },
			{ x=-1000, z=0 },
			{ x=0, z=1000}
		}
		local patrol_route_size = math.random(100, 600)/100
		for route_index, route in pairs(patrol_route) do
			patrol_route[route_index].x = patrol_route[route_index].x * patrol_route_size
			patrol_route[route_index].z = patrol_route[route_index].z * patrol_route_size
		end
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[1].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[1].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[2].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[2].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[3].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[3].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[4].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[4].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[5].x, CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), patrol_route[5].z)))
	elseif squad.command == SQUAD.COMMAND.ATTACK then
		-- go to island, once island is captured the command will be cleared
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-100, 100), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-100, 100))))
	elseif squad.command == SQUAD.COMMAND.STAGE then
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.DEFEND then
		-- defend island
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
		-- go to investigate location
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.investigate_transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + (vehicle_object.id % 10 * 20), math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.ENGAGE then
		p.resetPath(vehicle_object)
	elseif squad.command == SQUAD.COMMAND.SCOUT then
		p.resetPath(vehicle_object)
		target_island, origin_island = Objective.getIslandToAttack()
		if target_island then
			d.print("Scout found a target island!", true, 0)
			local holding_route = g_holding_pattern
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[1].x, CRUISE_HEIGHT * 2, holding_route[1].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[2].x, CRUISE_HEIGHT * 2, holding_route[2].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[3].x, CRUISE_HEIGHT * 2, holding_route[3].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[4].x, CRUISE_HEIGHT * 2, holding_route[4].z)))
		else
			d.print("Scout was unable to find a island to target!", true, 1)
		end
	elseif squad.command == SQUAD.COMMAND.RETREAT then
	elseif squad.command == SQUAD.COMMAND.NONE then
	elseif squad.command == SQUAD.COMMAND.TURRET then
		p.resetPath(vehicle_object)
	elseif squad.command == SQUAD.COMMAND.RESUPPLY then
		p.resetPath(vehicle_object)
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

	for steam_id, player_object in pairs(squad.target_players) do
		local player_data = { id = steam_id, obj = player_object }

		if player_object.state == TARGET_VISIBILITY_VISIBLE then
			vision_data.visible_players_map[steam_id] = player_data
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

---@param id integer the tick you want to check that it is
---@param rate integer the total amount of ticks, for example, a rate of 60 means it returns true once every second* (if the tps is not low)
---@return boolean isTick if its the current tick that you requested
function isTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate == 0
end

---@param id integer the tick offset you want to get the id of
---@param rate integer the rate of the tick_id, for example, 60 will result in it going from 1 to 60
---@return integer tick_id The tick ID
function getTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate
end

-- iterator function for iterating over all playlists, skipping any that return nil data
function iterPlaylists()
	local playlist_count = s.getAddonCount()
	local addon_index = 0

	return function()
		local playlist_data = nil
		local index = playlist_count

		while playlist_data == nil and addon_index < playlist_count do
			playlist_data = s.getAddonData(addon_index)
			index = addon_index
			addon_index = addon_index + 1
		end

		if playlist_data ~= nil then
			return index, playlist_data
		else
			return nil
		end
	end
end

-- iterator function for iterating over all locations in a playlist, skipping any that return nil data
function iterLocations(addon_index)
	local playlist_data = s.getAddonData(addon_index)
	local location_count = 0
	if playlist_data ~= nil then location_count = playlist_data.location_count end
	local location_index = 0

	return function()
		local location_data = nil
		local index = location_count

		while not location_data and location_index < location_count do
			location_data = s.getLocationData(addon_index, location_index)
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
function iterObjects(addon_index, location_index)
	local location_data = s.getLocationData(addon_index, location_index)
	local object_count = 0
	if location_data ~= nil then object_count = location_data.component_count end
	local object_index = 0

	return function()
		local object_data = nil
		local index = object_count

		while not object_data and object_index < object_count do
			object_data = s.getLocationComponentData(addon_index, location_index, object_index)
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

--------------------------------------------------------------------------------
--
-- Other
--
--------------------------------------------------------------------------------

---@param start_tick number the time you want to see how long its been since (in ticks)
---@return number ticks_since how many ticks its been since <start_tick>
function ticksSince(start_tick)
	return g_savedata.tick_counter - start_tick
end

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end



