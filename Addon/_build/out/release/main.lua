 
--[[
	
Copyright 2024 Liam Matthews

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

--! (If gotten from Steam Workshop) LICENSE is in vehicle_0.xml
--! (If gotten from anywhere else) LICENSE is in LICENSE and vehicle_0.xml

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: https://steamcommunity.com/id/Toastery7/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

ADDON_VERSION = "(0.4.0.28)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "ICM"

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field
---@diagnostic disable:inject-field

-- shortened library names
m = matrix
s = server

ISLAND = {
	---@enum FACTION
	FACTION = {
		NEUTRAL = "neutral",
		AI = "ai",
		PLAYER = "player"
	}
}

VEHICLE = {
	---@enum VEHICLE_STATE
	STATE = {
		PATHING = "pathing", -- follow path
		HOLDING = "holding", -- hold position
		STATIONARY = "stationary" -- used for turrets
	},
	---@enum VEHICLE_TYPE
	TYPE = {
		BOAT = "boat",
		LAND = "land",
		PLANE = "plane",
		HELI = "heli",
		TURRET = "turret",
		ANY = "any" -- Used to satisfy type checking in places like the resupply squad
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

---@enum CONVOY_STATE
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
	---@enum SQUAD_COMMAND
	COMMAND = {
		NONE = "no_command", -- no command
		ATTACK = "attack", -- Attacks the island specified in `target_island`
		DEFEND = "defend", -- Defends the island specified in `target_island`
		INVESTIGATE = "investigate", -- Investigates the position specified in `investigate_transform` *(Automatically set from ENGAGE when the player leaves sight)*
		ENGAGE = "engage", -- Engages in combat with the nearest player
		PATROL = "patrol", -- Does a single loop around the island specified in `target_island`, and then resets to no_command
		STAGE = "stage", -- Pathfinds to the island specified in `target_island` in preparation for an attack
		RESUPPLY = "resupply", -- Exclusive to the resupply squad. **Do not use for other squads** 
		TURRET = "turret", -- Used for turrets. Does nothing but counts it as a defender & gives a different map debug icon
		RETREAT = "retreat", -- not implemented yet, used for retreating
		SCOUT = "scout", -- For **Scout Planes Only**. Loops the plane in a circle around the closest unscouted island from the AI. Can only be reassigned to *DEFEND* (Auto when no more islands to scout)
		CARGO = "cargo" -- For **Cargo Vehicles Only**. Once assigned, its impossible to reassign it to another command.
	}
}

addon_setup = false

g_savedata = {
	ai_base_island = nil, ---@type ISLAND
	player_base_island = nil,
	islands = {},
	loaded_islands = {}, -- islands which are loaded
	ai_army = { 
		squadrons = { ---@type table<integer, squadron>
			[RESUPPLY_SQUAD_INDEX] = {
				index = RESUPPLY_SQUAD_INDEX,
				command = SQUAD.COMMAND.RESUPPLY,
				vehicle_type = VEHICLE.TYPE.ANY,
				role = "",
				vehicles = {},
				target_island = nil
			}
		},
		squad_vehicles = {} -- stores which squad the vehicles are assigned to, indexed via the vehicle's id, with this we can get the vehicle we want the data for without needing to check every single enemy ai vehicle
	},
	players = {
		online = {}, -- indexed by peer_id, value is steam_id, to index individual_data
		individual_data = {},
		global_data = {}
	},
	player_vehicles = {}, ---@type table<integer, PLAYER_VEHICLE>
	cargo_vehicles = {}, ---@type table<integer, CARGO_VEHICLE>
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
		},
		setup = false
	},
	tick_counter = 0,
	game_tick_counter = 0,
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
			stack = {}, -- the stack of function calls.
			stack_size = 0, -- the size of the stack, used so we don't actually have to remove things from the stack to save on performance.
			funct_names = {}, -- the names of the functions in the stack, so we can use numberical ids in the stack instead for performance and memory usage.
			funct_count = 0 -- the total number of functions, used to optimise the setup phase for tracebacks.
		}
	},
	tick_extensions = {
		cargo_vehicle_spawn = 0
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	},
	flags = {},
	libraries = {
		capture_point_payments = {
			sleep_tracker = {
				normal = 0,
				total = 0
			},
			last_payout = 0.2916666667
		}
	}
}

-- libraries
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

--- Turns a string into a boolean, returns nil if not possible.
---@param val any the value we want to turn into a boolean
---@return boolean|nil bool the string turned into a boolean, is nil if string is not able to be turned into a boolean
function string.toboolean(val)

	local val_type = type(val)
	
	if val_type == "boolean" then
		-- early out for booleans
		return val
	elseif val_type ~= "string" then
		-- non strings cannot be "true" or "false", so will never return a boolean, so just early out.
		return nil
	end

	local str = string.lower(val)

	-- not convertable, return nil
	if str ~= "true" and str ~= "false" then
		return nil
	end

	-- convert
	return str == "true"
end

--- Turns a value from a string into its proper value, eg: "true" becomes a boolean of true, and ""true"" becomes a string of "true"
---@param val any the value to convert
---@return any parsed_value the converted value
function string.parseValue(val)
	local val_type = type(val)

	-- early out (no need to convert)
	if val_type ~= "string" then
		return val
	end

	-- value as an integer
	local val_int = math.tointeger(val)
	if val_int then return val_int end

	-- value as a number
	local val_num = tonumber(val)
	if val_num then return val_num end

	-- value as a boolean
	local val_bool = string.toboolean(val)
	if val_bool ~= nil then return val_bool end

	-- value as a table
	if val:sub(1, 1) == "{" then
		local val_tab = table.fromString(val)

		if val_tab then return val_tab end
	end

	--[[
		assume its a string
	]]

	-- if it has a " at the start, remove it
	if val:sub(1, 1) == "\"" then
		val = val:sub(2, val:len())
	end

	-- if it has a " at the end, remove it
	local val_len = val:len()
	if val:sub(val_len, val_len) == "\"" then
		val = val:sub(1, val_len - 1)
	end

	-- return the string
	return val
end

-- variables for if you want to account for leap years or not.
local days_in_a_year = 365.25
local days_per_month = days_in_a_year/12

---@class timeFormatUnit -- how to format each unit, use ${plural} to have an s be added if the number is plural.
---@field prefix string the string before the number
---@field suffix string the string after the number

---@alias timeFormatUnits
---| '"millisecond"'
---| '"second"'
---| '"minute"'
---| '"hour"'
---| '"day"'
---| '"week"'
---| '"month"'
---| '"year"'

---@class timeFormat
---@field show_zeros boolean if zeros should be shown, if true, units with a value of 0 will be removed.
---@field time_zero_string string the string to show if the time specified is 0
---@field seperator string the seperator to be put inbetween each unit.
---@field final_seperator string the seperator to put for the space inbetween the last units in the list
---@field largest_first boolean if it should be sorted so the string has the highest unit be put first, set false to have the lowest unit be first.
---@field units table<timeFormatUnits, timeFormatUnit>

time_formats = {
	yMwdhmsMS = {
		show_zeros = false,
		time_zero_string = "less than 1 millisecond",
		seperator = ", ",
		final_seperator = ", and ",
		largest_first = true,
		units = {
			millisecond = {
				prefix = "",
				suffix = " millisecond${plural}"
			},
			second = {
				prefix = "",
				suffix = " second${plural}"
			},
			minute = {
				prefix = "",
				suffix = " minute${plural}"
			},
			hour = {
				prefix = "",
				suffix = " hour${plural}"
			},
			day = {
				prefix = "",
				suffix = " day${plural}"
			},
			week = {
				prefix = "",
				suffix = " week${plural}"
			},
			month = {
				prefix = "",
				suffix = " month${plural}"
			},
			year = {
				prefix = "",
				suffix = " year${plural}"
			}
		}
	},
	yMdhms = {
		show_zeros = false,
		time_zero_string = "less than 1 second",
		seperator = ", ",
		final_seperator = ", and ",
		largest_first = true,
		units = {
			second = {
				prefix = "",
				suffix = " second${plural}"
			},
			minute = {
				prefix = "",
				suffix = " minute${plural}"
			},
			hour = {
				prefix = "",
				suffix = " hour${plural}"
			},
			day = {
				prefix = "",
				suffix = " day${plural}"
			},
			month = {
				prefix = "",
				suffix = " month${plural}"
			},
			year = {
				prefix = "",
				suffix = " year${plural}"
			}
		}
	}
}

---@type table<timeFormatUnits, number> the seconds needed to make up each unit.
local seconds_per_unit = {
	millisecond = 0.001,
	second = 1,
	minute = 60,
	hour = 3600,
	day = 86400,
	week = 604800,
	month = 86400*days_per_month,
	year = 86400*days_in_a_year
}

-- 1 being smallest unit, going up to largest unit
---@type table<integer, timeFormatUnits>
local unit_heiarchy = {
	"millisecond",
	"second",
	"minute",
	"hour",
	"day",
	"week",
	"month",
	"year"
}

---[[@param formatting string the way to format it into time, wrap the following in ${}, overflow will be put into the highest unit available. t is ticks, ms is milliseconds, s is seconds, m is minutes, h is hours, d is days, w is weeks, M is months, y is years. if you want to hide the number if its 0, use : after the time type, and then optionally put the message after that you want to only show if that time unit is not 0, for example, "${s: seconds}", enter "default" to use the default formatting.]]

---@param format timeFormat the format type, check the time_formats table for examples or use one from there.
---@param time number the time in seconds, decimals can be used for milliseconds.
---@param as_game_time boolean? if you want it as in game time, leave false or nil for irl time (yet to be supported)
---@return string formatted_time the time formatted into a more readable string.
function string.formatTime(format, time, as_game_time)
	--[[if formatting == "default" then
		formatting = "${y: years, }${M: months, }${d: days, }${h: hours, }${m: minutes, }${s: seconds, }${ms: milliseconds}"]]

	-- return the time_zero_string if the given time is zero.
	if time == 0 then
		return format.time_zero_string
	end

	local leftover_time = time

	---@class formattedUnit
	---@field unit_string string the string to put for this unit
	---@field unit_name timeFormatUnits the unit's type

	---@type table<integer, formattedUnit>
	local formatted_units = {}

	-- go through all of the units, largest unit to smallest.
	for unit_index = #unit_heiarchy, 1, -1 do
		-- get it's name
		local unit_name = unit_heiarchy[unit_index]

		-- the unit's format data
		local unit_data = format.units[unit_name]

		-- unit data is nil if its not formatted, so just skip if its not in the formatting
		if not unit_data then
			goto next_unit
		end

		-- how many seconds can go into this unit
		local seconds_in_unit =  seconds_per_unit[unit_name]

		-- get the number of this unit from the given time.
		local time_unit_instances = leftover_time/seconds_in_unit

		-- skip this unit if we don't want to show zeros, and this is less than 1.
		if not format.show_zeros and math.abs(time_unit_instances) < 1 then
			goto next_unit
		end

		-- format this unit
		local unit_string = ("%s%0.0f%s"):format(unit_data.prefix, time_unit_instances, unit_data.suffix)

		-- if this unit is not 1, then add an s to where it wants the plurals to be.
		unit_string = unit_string:setField("plural", math.floor(time_unit_instances) == 1 and "" or "s")

		-- add the formatted unit to the formatted units table.
		table.insert(formatted_units, {
			unit_string = unit_string,
			unit_name = unit_name
		} --[[@as formattedUnit]])

		-- subtract the amount of time this unit used up, from the leftover time.
		leftover_time = leftover_time - math.floor(time_unit_instances)*seconds_in_unit

		::next_unit::
	end

	-- theres no formatted units, just put the message for when the time is zero.
	if #formatted_units == 0 then
		return format.time_zero_string
	end

	-- sort the formatted_units table by the way the format wants it sorted.
	table.sort(formatted_units,
		function(a, b)
			return math.xor(
				seconds_per_unit[a.unit_name] < seconds_per_unit[b.unit_name],
				format.largest_first
			)
		end
	)

	local formatted_time = formatted_units[1].unit_string

	local formatted_unit_count = #formatted_units
	for formatted_unit_index = 2, formatted_unit_count do
		if formatted_unit_index == formatted_unit_count then
			formatted_time = formatted_time..format.final_seperator..formatted_units[formatted_unit_index].unit_string
		else
			formatted_time = formatted_time..format.seperator..formatted_units[formatted_unit_index].unit_string
		end
	end

	return formatted_time
end

---# Sets the field in a string
--- for example: <br> 
---> self: "Money: ${money}" <br> field: "money" <br> value: 100 <br> **returns: "Money: 100"**
---
--- <br> This function is almost interchangable with gsub, but first checks if the string matches, which might help with performance in certain scenarios, also doesn't require the user to type the ${}, and can be cleaner to read.
---@param str string the string to set the fields in
---@param field string the field to set
---@param value any the value to set the field to
---@param skip_check boolean|nil if it should skip the check for if the field is in the string.
---@return string str the string with the field set.
function string.setField(str, field, value, skip_check)

	local field_str = ("${%s}"):format(field)
	-- early return, as the field is not in the string.
	if not skip_check and not str:match(field_str) then
		return str
	end

	-- set the field.
	str = str:gsub(field_str, tostring(value))

	return str
end

---# if a string has a field <br>
---
--- Useful for if you dont need to figure out the value to write for the field if it doesn't exist, to help with performance in certain scenarios
---@param str string the string to find the field in.
---@param field string the field to find in the string.
---@return boolean found_field if the field was found.
function string.hasField(str, field)
	return str:match(("${%s}"):format(field))
end

function string:toLiteral(literal_percent)
	if literal_percent then
		return self:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%%%1")
	end

	return self:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end


---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Command system, used to be able to register commands from other scripts within this addon.
	This is to keep this script clean and have the commands that relate to those specific scripts,
	be within those specific scripts.
]]

---@alias commandName string
---@alias prefix string

---@alias defaultCommandPermissions "none"|"auth"|"admin"|"script"|"auth_script"|"admin_script"

---@alias commandFunctionToExecute fun(full_message: string, peer_id: integer, ...)

---@class Command
---@field name string the name of the command
---@field function_to_execute commandFunctionToExecute the function to execute when the command is called, given params are: full_message, peer_id, arg
---@field required_permission defaultCommandPermissions|string the permission this command requires
---@field description string the description of the command
---@field short_description string the short description for this command
---@field examples table<integer, string> the examples of using this command
---@field args string the arguments for this command, eg: "<arg1> [arg2]"
---@field prefix string the prefix for this command

--[[
-- where all of the registered commands are stored
---@type table<string, command>
local registered_commands = {}
]]
command_aliases = {
	dbg = "debug",
	pseudospeed = "speed",
	sv = "spawnvehicle",
	dv = "deletevehicle",
	kill = "deletevehicle",
	cp = "capturepoint",
	capture = "capturepoint",
	captureisland = "capturepoint",
	st = "spawnturret",
	si = "scoutintel",
	setintel = "scoutintel",
	vl = "vehiclelist",
	listvehicles = "vehiclelist",
	tp = "teleport",
	teleport_vehicle = "teleport",
	kamikaze = "airvehicleskamikaze"
}

---@type table<prefix, table<commandName, Command>>
commands = {}

-- where all of the registered permissions are stored.
---@type table<defaultCommandPermissions|string, function>
local registered_command_permissions = {}

Command = {}

-- intercept onCustomCommand calls
local old_onCustomCommand = onCustomCommand
function onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)
	-- avoid error if onCustomCommand is not used anywhere else before.
	if old_onCustomCommand then
		old_onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)
	end

	-- avoid errors if prefix is not specified
	if not prefix then return end

	-- avoid errors if command is not specified
	if not command then return end

	-- make the prefix lowercase
	prefix = prefix:lower()

	-- if the prefix does not pertain to this addon
	if not commands[prefix] then return end

	-- make the command lowercase
	command = command:friendly()

	-- check for command aliases
	if command_aliases[command] then
		command = command_aliases[command]
	end

	-- if the command does not exist for the provided prefix
	if not commands[prefix][command] then return end

	local command_data = commands[prefix][command]

	-- the permission required to execute this command, if the permission is not found, default to admin.
	local command_permission = registered_command_permissions[command_data.required_permission] or registered_command_permissions.admin

	-- if the required permission is not met
	if not command_permission(peer_id) then

		local required_permission_name = registered_command_permissions[command_data.required_permission] and command_data.required_permission or "admin"
		
		if peer_id ~= -1 then
			-- if a player tried executing the command
			d.print(("You require the permission %s to execute this command!"):format(required_permission_name), false, 1, peer_id)
		else
			-- if a script tried to execute the command
			d.print(("A script tried to call the command %s, but it does not privilages to execute this command, as it requires the permission %s"):format(command, required_permission_name), true, 1)
		end

		return
	end

	-- if dlc_weapons is disabled or the player does not have it (if in singleplayer)
	local args = table.pack(...)
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

	-- call the command
	command_data.function_to_execute(full_message, peer_id, args)

	return true
end

---@param prefix prefix? the string of the prefix to use, eg: "ICM" if left nil, uses SHORT_ADDON_NAME instead.
---@return string formatted_prefix the prefix, but formatted properly.
function Command.formatPrefix(prefix)
	prefix = prefix or SHORT_ADDON_NAME

	-- Make the prefix lowercase.
	prefix = prefix:lower()

	-- Add the question mark to the start of the prefix if wasn't already added.
	if prefix:sub(1, 1) ~= "?" then
		prefix = "?"..prefix
	end

	-- return the formatted prefix
	return prefix
end

---# Registers a command
---@param name commandName the name of the command
---@param function_to_execute commandFunctionToExecute the function to execute when the command is called, params are (full_message, peer_id, args)
---@param required_permission defaultCommandPermissions|string the permission required to execute this command.
---@param description string the description of the command
---@param short_description string the shortened description of the command
---@param examples table<integer, string> examples of using the command, prefix and the command will be added to the strings automatically.
---@param args string? the arguments for this command, eg: "<arg1> [arg2]"
---@param unformatted_prefix prefix? the prefix for the command, leave blank to use the addon's short name as the prefix.
function Command.registerCommand(name, function_to_execute, required_permission, description, short_description, examples, args, unformatted_prefix)
	
	-- Format the prefix.
	local prefix = Command.formatPrefix(unformatted_prefix)

	-- make the name friendly
	name = name:friendly() --[[@as string]]

	-- if this command has already been registered.
	if commands[prefix] and commands[prefix][name] then
		d.print(("Attempted to register a duplicate command \"%s\""):format(name), true, 1)
		return
	end
	
	---@type Command
	local command_data = {
		name = name,
		function_to_execute = function_to_execute,
		required_permission = required_permission or "admin",
		description = description or "",
		short_description = short_description or "",
		examples = examples or {},
		args = args or "",
		prefix = prefix
	}

	-- if the table of commands with this prefix does not yet exist, create it.
	commands[prefix] = commands[prefix] or {}

	-- register this command.
	commands[prefix][name] = command_data
end

---@param name string the name of this permission
---@param has_permission function the function to execute, to check if the player has permission (arg1 is peer_id)
function Command.registerPermission(name, has_permission)

	-- if the permission already exists
	if registered_command_permissions[name] then

		--[[
			this can be quite a bad error, so it bypasses debug being disabled.

			for example, library A adds a permission called "mod", for mod authors
			and then after, library B adds a permission called "mod", for moderators of the server
			
			when this fails, any commands library B will now just require the requirements for mod authors
			now you've got issues of mod authors being able to access moderator commands

			so having this always alert is to try to make this issue obvious. as if it was just silent in
			the background, suddenly you've got privilage elevation.
		]]
		d.print(("(Command.registerPermission) Permission level %s is already registered!"):format(name), false, 1)
		return
	end

	registered_command_permissions[name] = has_permission
end

--[[

	Scripts to be put after this one

]]

--[[
	Definitions
]]
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

--[[

	Registers the default command permissions.

]]

-- None Permission
Command.registerPermission(
	"none",
	function()
		return true
	end
)

-- Auth Permission
Command.registerPermission(
	"auth",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Permission
Command.registerPermission(
	"admin",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)

-- Script Permission
Command.registerPermission(
	"script",
	function(peer_id)
		return peer_id == -1
	end
)

-- Auth Script Permission
Command.registerPermission(
	"auth_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Script Permission
Command.registerPermission(
	"admin_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)
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

--[[

	Containts the includes for the default command modules.

]]

-- Adds the generic commands, eg: "info"
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

	Registers the default generic commands.

]]

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
		},
		flag = {
			short_desc = "allows you to set flags or get their value.",
			desc = "allows you to set flags or get their value, which are a more advanced type of setting, which can control things like toggling features, changing behaviours, and just general debug",
			args = "<flag_name> <value>",
			example = "?icm flag sync_tick_rate false, ?icm flag sync_tick_rate"
		},
		flags = {
			short_desc = "allows you to get a list of flags",
			desc = "allows you to get a list of flags, which are a more advanced type of setting, which can control things like toggling features, changing behaviours, and just general debug",
			args = "<flag_name> [tag]",
			example = "?icm flags, ?icm flags feature"
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
		},
		debug = {
			short_desc = "enables or disables debug mode",
			desc = "lets you toggle debug mode, also shows all the AI vehicles on the map with tons of info valid debug types: \"all\", \"chat\", \"profiler\" and \"map\"",
			args = "(debug_type) [peer_id]",
		},
		spawnturret = { -- spawn turret
			short_desc = "spawns a turret at every enemy AI island",
			desc = "spawns a turret at every enemy AI island",
			args = "none",
		},
		capturepoint = { -- capture point
			short_desc = "allows you to change who owns a point",
			desc = "allows you to change who owns a specific island",
			args = "(island_name) (\"ai\"|\"neutral\"|\"player\")",
		},
		aimod = {
			short_desc = "lets you get an ai's spawning modifier",
			desc = "lets you see what an ai's role, type, strategy or vehicle's spawning modifier is",
			args = "(role) [type] [strategy] [constructable_vehicle_id]",
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
		},
		teleport = { -- teleport vehicle
			short_desc = "lets you teleport an ai vehicle",
			desc = "lets you teleport an ai vehicle by vehicle id, to the specified x, y and z",
			args = "(vehicle_id) (x) (y) (z)",
		},
		scoutintel = { -- set scout intel
			short_desc = "lets you set the ai's scout level",
			desc = "lets you set the ai's scout level on a specific island, from 0 to 100 for 0% scouted to 100% scouted",
			args = "(island_name) (0-100)",
		},
		setting = {
			short_desc = "lets you change or get a specific setting and can get a list of all settings",
			desc = "if you do not input the setting name, it will show a list of all valid settings, if you input a setting name but not a value, it will tell you the setting's current value, if you enter both the setting name and the setting value, it will change that setting to that value",
			args = "[setting_name] [value]",
		},
		ai_knowledge = {
			short_desc = "shows the 3 vehicles it thinks is good against you",
			desc = "shows the 3 vehicles it thinks is good against you, and the 3 that it thinks is weak against you",
			args = "none",
		},
		reset_cargo = {
			short_desc = "resets the ai's cargo storages",
			desc = "resets the all island cargo storages to 0 for each resource, leave island blank for all islands, leave cargo_type blank for all resources",
			args = "[island] [cargo_type]",
		},
		queueconvoy = {
			short_desc = "queues a convoy.",
			desc = "queues a convoy to be sent out, will be sent out once theres not any convoys.",
			args = "",
		},
		airvehicleskamikaze = {
			short_desc = "kamikaze.",
			desc = "forces all air vehicles to have their target coordinates set to the target's position, when they have a target.",
			args = "",
		},
		getmemusage = {
			short_desc = "returns memory usage of this addon",
			desc = "returns how much memory the lua environment is using, this requires a modified version of sw which has the base lua functions injected.",
			args = "",
		},
		causeerror = {
			short_desc = "causes an error when the specified function is called.",
			desc = "causes an error when the specified function is called. Useful for debugging the traceback debug, or trying to reproduce an error.",
			args = "<function_name>",
		},
		printtraceback = {
			short_desc = "",
			desc = "",
			args = "",
		},
		execute = {
			short_desc = "allows you to get, set or call global variables.",
			desc = "allows you to get or set global variables, and call global functions with specified arguments.",
			args = "(address)[(\"(\"function_args\")\") value]",
		},
		ignite = {
			short_desc = "allows you to ignite an ai vehicle",
			desc = "allows you to ignite one or many ai vehicles by spawning a fire on them.",
			args = "(vehicle_id)|\"all\" [size]",
		}
	},
	host = {}
}

-- Info command
Command.registerCommand(
	"info",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
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

	end,
	"none",
	"Prints some info about the mod in chat! including version, world creation version, times reloaded, ect. Really helpful if you attach the commands output in bug reports!",
	"Prints some addon info.",
	{""}
)

-- Help command
Command.registerCommand(
	"help",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Get the command that the user wants help for
		local command_name = arg[1]

		-- Define the help reply message
		local help_reply_message = ""

		---@param command Command the command to add to the help menu
		---@param detailed boolean whether or not if the help should be detailed for this command
		---@return string command_help_string the help message for this command
		local function getCommandHelp(command, detailed)
			-- Create the string, starting off with the command's name.
			local command_help_string = "?icm " .. command.name .. " " .. command.args

			-- If the help shouldn't be detailed.
			if not detailed then
				-- Add the short description to the string on the same line.
				command_help_string = ("%s - %s"):format(command_help_string, command.short_description)
			-- If the help should be detailed.
			else
				-- Add the full description to the string on the next line.
				command_help_string = ("%s\nDescription: %s"):format(command_help_string, command.description)

				-- Add the examples to the string
				if command.examples and #command.examples > 0 then
					command_help_string = command_help_string .. "\nExamples:"
					for example_index = 1, #command.examples do
						command_help_string = command_help_string .. "\n?icm "..command.name.." "..command.examples[example_index]
					end
				end
			end

			return command_help_string
		end

		-- If the user didn't specify a command, then print all of the commands
		if not command_name then
			-- Go through all of the prefixes
			for prefix, commands in pairs(commands) do
				-- Go through all of the commands
				for command_name, command in pairs(commands) do
					-- Get it's help message, and add it to the list
					help_reply_message = ("%s\n-----------------------\n%s"):format(help_reply_message, getCommandHelp(command, false))
				end
			end
		else
			--Find the correct command
			local foundCommand = nil
			for prefix, commands in pairs(commands) do
				if commands[command_name] then
					foundCommand = commands[command_name]
					break
				end
			end
			if foundCommand then
				help_reply_message = getCommandHelp(foundCommand, true)
			else
				help_reply_message = "Command \""..tostring(command_name).."\" not found!"
			end
		end

		-- Print the help message
		d.print(help_reply_message, false, 0, peer_id)
	end,
	"none",
	"Prints some info about the addon, such as it's version",
	"Prints some general addon info.",
	{
		"",
		"info"
	},
	"[command]"
)


-- Adds the variable interaction commands, eg: "print_variable", "set_variable"
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
-- required libraries
-- required libraries
--[[


	Library Setup


]]

-- required libraries
--require("libraries.addon.script.debugging")

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

---@class ReplyAwaiting
---@field short_addon_name string the addon's short name of the addon we're trying to listen to, so if we're trying to listen to Improved Conquest Mode, this would be "ICM"
---@field message string the message to listen for, the execute_function will only be called if its an exact match.
---@field port integer the port number, in the range of 0-65535. Calls to port 0 will result in it being called the very next tick.
---@field execute_function fun(self: ReplyAwaiting) the function to execute when the message is received
---@field count integer the number of times the function can be executed, -1 for infinite.
---@field expiry number the time in milliseconds before the function expires, -1 for infinite.

--[[


	Functions         


]]

--- Defines the function and criteria for a reply callback to be executed when a specific message is received.
---@param short_addon_name string the addon's short name of the addon we're trying to listen to, so if we're trying to listen to Improved Conquest Mode, this would be "ICM"
---@param message string the message to listen for, the execute_function will only be called if its an exact match.
---@param port integer the port number, in the range of 0-65535. Calls to port 0 will result in it being called the very next tick.
---@param execute_function fun(self: ReplyAwaiting) the function to execute when the message is received
---@param count integer? the number of times the function can be executed, -1 for infinite (default 1)
---@param timeout number? the time in seconds before the function expires, -1 for infinite (default -1)
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
	return math.type(x) == "integer"
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

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude for 2D distance, include for 3D distance)
---@param y2 number? y coordinate of position 2 (exclude for 2D distance, include for 3D distance)
---@return number distance the euclidean distance between position 1 and position 2
function math.euclideanDistance(x1,x2,z1,z2,y1,y2)
	local rx = x1 - x2
	local rz = z1 - z2

	if y1 == nil or y2 == nil then
		-- 2D distance
		return math.sqrt(rx*rx+rz*rz)
	end

	-- 3D distance
	local ry = y1 - y2
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude to just get yaw, include to get yaw and pitch)
---@param y2 number? y coordinate of position 2 (exclude to just get yaw, include to get yaw and pitch)
---@return number yaw the yaw needed to face position 2 from position 1
---@return number pitch the pitch needed to face position 2 from position 1, will return 0 if y not specified.
function math.angleToFace(x1,x2,z1,z2,y1,y2)

	-- relative x coordinate
	local rx = x1 - x2
	-- relative z coordinate
	local rz = z1 - z2

	local yaw = math.atan(rz, rx) - math.half_pi

	if y1 == nil or y2 == nil then
		return yaw, 0
	end

	-- relative y
	local ry = y1 - y2

	local pitch = -math.atan(ry, math.sqrt(rx * rx + rz * rz))

	return yaw, pitch
end

--- XOR function.
---@param ... any
---@return boolean
function math.xor(...)
	-- packed table of ..., dont have to use table.pack to respect nils, as nil will just be 0 anyways.
	local t = {...}

	-- the true count
	local tc = 0

	-- for each one that is true, add 1 to true count
	for i = 1, #t do
		if t[i] then tc = tc + 1 end
	end

	-- xor can be summarized down to if the number of true inputs modulo 2 is equal to 1, so do that.
	return tc%2==1
end

--- Linear Scale, converts one scale to another scale <br>
--- For example, if x is x_min, then it will output y_min <br>
--- and if x is x_max, then it will output y_max <br>
--- And anywhere inbetween, it will output between the y_min and y_max.
---@param x number the value from the original scale
---@param x_min number the minimum value for x scale
---@param x_max number the maximum value for the x scale
---@param y_min number the value to output from the y scale if x is x_min
---@param y_max number the value to output from the y scale if x is x_max
---@return number y the value from the y scale
function math.linearScale(x, x_min, x_max, y_min, y_max)
	--[[
		Get the scaled x
		for example, if x is 0, x_min is -5, and x_max is 5, then scaled x is 0.5
	]]
	local scaled_x = (x - x_min)/(x_max - x_min)

	--[[
		return the scaled y
		if scaled_x is 0.5, y_min is 10, and y_max is -10, then scaled_y is 0.
	]]
	return (1-scaled_x)*y_min+scaled_x*y_max
end

--- Quadratic Bezier interpolation between 3 points.
---@param last number the previous point
---@param new number the new target point
---@param p1 number the control point
---@param progress number the progress between 0 and 1
---@return number point the point between last and new
function math.quadraticBezier(last, new, p1, progress)
	-- calculate the inverse of the progress
	local inverse_progress = 1-progress

	-- calculate the progress squared
	local progress_squared = progress*progress

	-- calculate the inverse progress squared
	local inverse_progress_squared = inverse_progress*inverse_progress

	-- calculate and return the point.
	return inverse_progress_squared * last + 2 * inverse_progress * progress * p1 + progress_squared * new
end

--- Function for rounding a number.
---@param x number the number to round.
---@param decimal_places number|nil the number of decimal places to round to.
---@return number rounded_x the rounded number.
function math.round(x, decimal_places)
	-- Default the number of decimal places to 0 if unspecified.
	decimal_places = decimal_places or 0

	-- Multiply the number by 10^places, this gives us the number to multiply and divide by to preserve the desired number of decimal places.
	local decimal_multplier = 10^decimal_places

	-- If this is a positive number, use floor and + 0.5
	if x >= 0 then
		-- Round with the number of places. (positive numbers)
		return math.floor(x * decimal_multplier + 0.5) / decimal_multplier
	-- Otherwise, we need to use ceil and -0.5, otherwise, something like -0.5 rounds to 0, instead of -1.
	else
		-- Round with the number of places. (negative numbers)
		return math.ceil(x * decimal_multplier - 0.5) / decimal_multplier
	end
end


---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return number distance the xz distance between the two matrices
function matrix.xzDistance(matrix1, matrix2) -- returns the euclidean distance between two matrixes, ignoring the y axis
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15])
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = matrix.multiply(rot_matrix, matrix.rotationZ(-z))
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
	-- total velocity
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15], matrix1[14], matrix2[14]) * 60/ticks_between
end

--# returns the acceleration, given 3 matrices. Each matrix must be the same ticks between eachother.
---@param matrix1 SWMatrix the most recent matrix
---@param matrix2 SWMatrix the second most recent matrix
---@param matrix3 SWMatrix the third most recent matrix
---@return number acceleration the acceleration in m/s
function matrix.acceleration(matrix1, matrix2, matrix3, ticks_between)
	local v1 = matrix.velocity(matrix1, matrix2, ticks_between) -- last change in velocity
	local v2 = matrix.velocity(matrix2, matrix3, ticks_between) -- change in velocity from ticks_between ago
	-- returns the acceleration
	return (v1-v2)/(ticks_between/60)
end

function matrix.clone(matrix_to_clone)
	return {
		matrix_to_clone[1],
		matrix_to_clone[2],
		matrix_to_clone[3],
		matrix_to_clone[4],
		matrix_to_clone[5],
		matrix_to_clone[6],
		matrix_to_clone[7],
		matrix_to_clone[8],
		matrix_to_clone[9],
		matrix_to_clone[10],
		matrix_to_clone[11],
		matrix_to_clone[12],
		matrix_to_clone[13],
		matrix_to_clone[14],
		matrix_to_clone[15],
		matrix_to_clone[16]
	}
end

--- Returns true if the two matrixes match on all params.
---@param m1 SWMatrix the first matrix
---@param m2 SWMatrix the second matrix
---@return boolean is_equal true if the matrixes are equal
function matrix.equals(m1, m2)
	return
		m1[1] == m2[1] and
		m1[2] == m2[2] and
		m1[3] == m2[3] and
		m1[4] == m2[4] and
		m1[5] == m2[5] and
		m1[6] == m2[6] and
		m1[7] == m2[7] and
		m1[8] == m2[8] and
		m1[9] == m2[9] and
		m1[10] == m2[10] and
		m1[11] == m2[11] and
		m1[12] == m2[12] and
		m1[13] == m2[13] and
		m1[14] == m2[14] and
		m1[15] == m2[15] and
		m1[16] == m2[16]
end

--- Returns true if the two matrixes match on all params. Meant to be used when it's been stored in g_savedata, as this will remove to the last decimal point. on [13], [14], and [15]
---@param m1 SWMatrix the first matrix
---@param m2 SWMatrix the second matrix
---@return boolean is_equal true if the matrixes are equal
function matrix.g_equals(m1, m2)
	-- Most params are just ==, but for 13, 14, and 15, we want to remove to the last decimal for comparison, due to the strange compression/randomisation on the location params.
	return
		m1[1] == m2[1] and
		m1[2] == m2[2] and
		m1[3] == m2[3] and
		m1[4] == m2[4] and
		m1[5] == m2[5] and
		m1[6] == m2[6] and
		m1[7] == m2[7] and
		m1[8] == m2[8] and
		m1[9] == m2[9] and
		m1[10] == m2[10] and
		m1[11] == m2[11] and
		m1[12] == m2[12] and
		math.round(m1[13], 0) == math.round(m2[13], 0) and
		math.round(m1[14], 0) == math.round(m2[14], 0) and
		math.round(m1[15], 0) == math.round(m2[15], 0) and
		m1[16] == m2[16]
		
end


-- library name
Players = {}

-- shortened library name
pl = Players

--[[


	Variables
   

]]

local debug_auto_enable_levels = {
	function() -- for Authors.
		return true
	end,
	function(player) -- for Contributors and Testers.
		return IS_DEVELOPMENT_VERSION or player:isAdmin()
	end
}

local addon_contributors = {
	["76561198258457459"] = {
		name = "Toastery",
		role = "Author",
		can_auto_enable = debug_auto_enable_levels[1],
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	},
	["76561198263550595"] = {
		name = "Senty",
		role = "Code Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198003337601"] = {
		name = "Woe",
		role = "Code Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198819129091"] = {
		name = "Daimonfire",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197971434564"] = {
		name = "Dorert",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198309605253"] = {
		name = "Eri",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198027912887"] = {
		name = "Outcast",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["71261196730417046"] = {
		name = "Keh",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198113700383"] = {
		name = "Lassi",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198310664934"] = {
		name = "Oh no look who",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198293725845"] = {
		name = "ScriptSauce",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198018200539"] = {
		name = "Sebastiaz",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198094043156"] = {
		name = "Sid V",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198201591123"] = {
		name = "yucky",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197971637605"] = {
		name = "Tom",
		role = "Meier Island & Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198257253907"] = {
		name = "Just Mob",
		role = "Video Producer & Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198837684315"] = {
		name = "Justin",
		role = "Wiki Admin & Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198998166730"] = {
		name = "Baguette Man",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198439973793"] = {
		name = "Cruzer",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198379296867"] = {
		name = "Jayfox2",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198119190014"] = {
		name = "kelpbot",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198101846228"] = {
		name = "mistercynical",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198094765400"] = {
		name = "Not so cute, but still a monster",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561199051162038"] = {
		name = "SmolShyBoiDavid",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197982256220"] = {
		name = "Tarelius",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	}--[[,
	[""] = {
		name = "Viking Walrus",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},]]
}

--[[


	Classes


]]

---@class PLAYER_DATA
---@field name string the name of the player
---@field peer_id integer the peer_id of the player
---@field steam_id string the steam_id of the player, as a string
---@field object_id integer the object_id of the player
---@field debug table<DebugType, boolean> a table of the debugs the player has enabled, indexed by the name of the debug, value being if its enabled or not
---@field acknowledgements table<nil>
---@field updateName function<nil> updates the player's name in player_data with the name they currently have
---@field updatePID function<nil> updates the player's peer_id in player_data with the peer_id they currently have
---@field updateOID function<nil> updates the player's object_id in player_data with the object_id they currently have
---@field getDebug function<DebugID> returns wether or not the player has the debug with the specified id enabled, set to -1 for any debug enabled
---@field getSWPlayer function<nil> returns the SWPlayer attached to this player.

--[[


	Functions         


]]

function Players.onJoin(steam_id, peer_id)

	if not g_savedata.players.individual_data[steam_id] then -- this player has never joined before

		Players.add(steam_id, peer_id)

	else -- this player has joined before

		local player = Players.dataBySID(steam_id) -- get the player's data

		Players.updateData(player) -- update the player's data
	end
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the OOP functions added
function Players.setupOOP(player)
	-- update name
	function player:updateName()
		self.name = s.getPlayerName(self.peer_id)
	end

	-- update peer_id
	function player:updatePID(peer_id)
		if peer_id then
			self.peer_id = peer_id
		else
			for _, peer in pairs(s.getPlayers()) do
				if tostring(peer.steam_id) == self.steam_id then
					self.peer_id = peer.id
				end
			end
		end
	end

	function player:updateOID()
		self.object_id = s.getPlayerCharacterID(self.peer_id)
	end

	-- checks if the player has this debug type enabled
	function player:getDebug(debug_id)
		if debug_id == -1 then
			-- check for all
			for _, enabled in pairs(self.debug) do
				if enabled then
					-- a debug is enabled
					return true 
				end
			end
			-- no debugs are enabled
			return false
		end

		return self.debug[d.debugTypeFromID(debug_id)]
	end

	function player:setDebug(debug_id, enabled)
		if debug_id == -1 then -- set all debug to the specified state
			for debug_id, enabled in pairs(self.debug) do
				self:setDebug(debug_id, enabled)
			end
		else
			-- get debug type from debug id
			local debug_type = d.debugTypeFromID(debug_id)

			-- set player's debug to be value of enabled
			self.debug[debug_type] = enabled

			-- if we're enabling this debug
			if enabled then
				-- set this debug as true for global, so the addon can start checking who has it enabled.
				g_savedata.debug[debug_type].enabled = true
			else
				-- check if we can globally disable this debug to save on performance
				d.checkDebug()
			end

			-- handle the debug (handles enabling of debugs and such)
			d.handleDebug(debug_type, enabled, self.peer_id)
		end
	end

	-- returns the SWPlayer, if doesn't exist currently, will return an empty table
	function player:getSWPlayer()
		local player_list = s.getPlayers()
		for peer_index = 1, #player_list do
			local SWPlayer = player_list[peer_index]
			if SWPlayer.steam_id == self.steam_id then
				return SWPlayer, true
			end
		end

		return {}, false
	end

	-- checks if the player is an admin
	function player:isAdmin()
		return self:getSWPlayer().admin
	end

	-- checks if the player is a contributor to the addon
	function player:isContributor()
		return addon_contributors[self.steam_id] ~= nil
	end

	function player:isOnline()
		-- "failure proof" method of checking if the player is online
		-- by going through all online players, as in certain scenarios
		-- only using onPlayerJoin and onPlayerLeave will cause issues.

		return table.pack(self:getSWPlayer())[2]
	end

	return player
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the data updated.
function Players.updateData(player)

	player = Players.setupOOP(player)

	-- update player's online status
	if player:isOnline() then
		g_savedata.players.online[player.peer_id] = player.steam_id
	else
		g_savedata.players.online[player.peer_id] = nil
	end

	-- update their name
	player:updateName()

	-- update their peer_id
	player:updatePID()

	-- update their object_id
	player:updateOID()

	return player
end

function Players.add(steam_id, peer_id)

	player = {
		name = s.getPlayerName(peer_id),
		peer_id = peer_id,
		steam_id = steam_id,
		object_id = s.getPlayerCharacterID(peer_id),
		debug = {},
		acknowledgements = {} -- used for settings to confirm that the player knows the side affects of what they're setting the setting to
	}

	-- populate debug data
	for i = 1, #debug_types do
		player.debug[d.debugTypeFromID(i)] = false
	end

	-- functions for the player

	player = Players.updateData(player)

	g_savedata.players.individual_data[steam_id] = player

	-- enable their selected debug modes by default if they're a addon contributor
	if player:isContributor() then
		local enabled_debugs = {}

		-- enable the debugs they specified
		if addon_contributors[steam_id].can_auto_enable(player) then
			for i = 1, #addon_contributors[steam_id].debug do
				local debug_id = addon_contributors[steam_id].debug[i]
				player:setDebug(debug_id, true)
				table.insert(enabled_debugs, addon_contributors[steam_id].debug[i])
			end
		end

		-- if this contributor has debugs which automatically gets enabled
		if #enabled_debugs > 0 then

			local msg_enabled_debugs = ""

			-- prepare the debug types which were enabled to be put into a message
			msg_enabled_debugs = d.debugTypeFromID(enabled_debugs[1])
			if #enabled_debugs > 1 then
				for i = 2, #enabled_debugs do -- start at position 2, as we've already added the one at positon 1.
					if i == #enabled_debugs then -- if this is the last debug type
						msg_enabled_debugs = ("%s and %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					else
						msg_enabled_debugs = ("%s, %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					end
				end
			end

			d.print(("Automatically enabled %s debug for you, %s, thank you for your contributions!"):format(msg_enabled_debugs, player.name), false, 0, player.peer_id)
		else -- if they have no debugs types that get automatically enabled
			d.print(("Thank you for your contributions, %s!"):format(player.name), false, 0, player.peer_id)
		end
	end

	d.print(("Setup Player %s"):format(player.name), true, 0, -1)
end

---@param steam_id steam_id the steam id of the player which you want to get the data of
---@return PLAYER_DATA player_data the data of the player
function Players.dataBySID(steam_id)
	return g_savedata.players.individual_data[steam_id]
end

---@param peer_id integer the peer id of the player which you want to get the data of
---@return PLAYER_DATA|nil player_data the data of the player, nil if not found
function Players.dataByPID(peer_id)

	local steam_id = Players.getSteamID(peer_id)

	-- ensure we got steam_id
	if not steam_id then 
		return
	end

	-- ensure player's data exists
	if not g_savedata.players.individual_data[steam_id] then
		return
	end

	-- return player's data
	return g_savedata.players.individual_data[steam_id]
end

---@param player_list table<integer, SWPlayer> the list of players to check
---@param target_pos SWMatrix the position that you want to check
---@param min_dist number the minimum distance between the player and the target position
---@param ignore_y boolean if you want to ignore the y level between the two or not
---@return boolean no_players_nearby returns true if theres no players which distance from the target_pos was less than the min_dist
function Players.noneNearby(player_list, target_pos, min_dist, ignore_y)
	local players_clear = true
	for _, player in pairs(player_list) do
		if ignore_y and m.xzDistance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		elseif not ignore_y and m.distance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		end
	end
	return players_clear
end

---@param peer_id integer the peer_id of the player you want to get the steam id of
---@return string|false steam_id the steam id of the player, false if not found
function Players.getSteamID(peer_id)
	if not g_savedata.players.online[peer_id] then
		-- slower, but reliable fallback method
		for _, peer in ipairs(s.getPlayers()) do
			if peer.id == peer_id then
				return tostring(peer.steam_id)
			end
		end
		return false
	end

	return g_savedata.players.online[peer_id]
end

---@param steam_id string the steam ID of the palyer
---@return integer|nil object_id the object ID of the player, nil if not found
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1, -1)
		return
	end

	local player_data = pl.dataBySID(steam_id)

	if not player_data.object_id then
		player_data.object_id = s.getPlayerCharacterID(player_data.peer_id)
	end

	return player_data.object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end
--[[


	Library Setup


]]

-- required libraries

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

--[[ 
	Flag command, used to manage more advanced settings.
	Compliments the settings command, setting command is made to handle less
	complex commands, and ones that should be set on the world's creation.
	While flags are ones that may be set for compatiblity reasons, such as if
	it adding currency rewards is incompatible with another addon on a server,
	the economy module could be disabled via a flag.
]]

-- required libraries -- required to print messages -- required to get data on players -- required for some of its helpful string functions -- required for some of its helpful table functions

g_savedata.flags = {}

-- where all of the registered flags are stored, their current values get stored in g_savedata.flags instead, though.
---@type table<string, BooleanFlag | IntegerFlag | NumberFlag | StringFlag | AnyFlag>
local registered_flags = {}


-- where all of the registered permissions are stored.
local registered_permissions = {}

-- stores the functions for flags
Flag = {}

---@param name string the name of this permission
---@param has_permission function the function to execute, to check if the player has permission (arg1 is peer_id)
function Flag.registerPermission(name, has_permission)

	-- if the permission already exists
	if registered_permissions[name] then

		--[[
			this can be quite a bad error, so it bypasses debug being disabled.

			for example, library A adds a permission called "mod", for mod authors
			and then after, library B adds a permission called "mod", for moderators of the server
			
			when this fails, any commands library B will now just require the requirements for mod authors
			now you've got issues of mod authors being able to access moderator commands

			so having this always alert is to try to make this issue obvious. as if it was just silent in
			the background, suddenly you've got privilage elevation.
		]]
		d.print(("(Flag.registerPermission) Permission level %s is already registered!"):format(name), false, 1)
		return
	end

	registered_permissions[name] = has_permission
end

--# Register a boolean flag, can only be true or false.
---@param name string the name of the flag
---@param default_value boolean the default_value for this flag
---@param tags table<integer, string> a table of tags for this flag, can be used to filter tags for displaying to the user.
---@param read_permission_requirement string the permission required to read this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param write_permission_requirement string the permission required to write to this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param function_to_execute function|nil the function to execute when this value is set. params are (in order): "value, old_value, peer_id", if you do not need to specify a function, just provide nil to avoid extra performance cost of calling an empty function.
---@param description string the description of the flag
function Flag.registerBooleanFlag(name, default_value, tags, read_permission_requirement, write_permission_requirement, function_to_execute, description)
	local function_name = "Flag.registerBooleanFlag"

	-- if this flag has already been registered
	if registered_flags[name] then
		d.print(("(%s) Flag %s already exists!"):format(function_name, name), true, 1)
		return
	end

	---@class BooleanFlag
	local flag = {
		name = name,
		default_value = default_value,
		tags = tags,
		read_permission_requirement = read_permission_requirement,
		write_permission_requirement = write_permission_requirement,
		function_to_execute = function_to_execute,
		flag_type = "boolean"
	}

	registered_flags[name] = flag

	if g_savedata.flags[name] == nil then
		g_savedata.flags[name] = default_value
	end
end

--# Register an integer flag, can only be an integer.
---@param name string the name of the flag
---@param default_value integer the default_value for this flag
---@param tags table<integer, string> a table of tags for this flag, can be used to filter tags for displaying to the user.
---@param read_permission_requirement string the permission required to read this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param write_permission_requirement string the permission required to write to this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param function_to_execute function|nil the function to execute when this value is set. params are (in order): "value, old_value, peer_id", if you do not need to specify a function, just provide nil to avoid extra performance cost of calling an empty function.
---@param description string the description of the flag
---@param min integer|nil the minimum value for the flag (nil for none)
---@param max integer|nil the maximum value for the flag (nil for none)
function Flag.registerIntegerFlag(name, default_value, tags, read_permission_requirement, write_permission_requirement, function_to_execute, description, min, max)
	local function_name = "Flag.registerIntegerFlag"

	-- if this flag has already been registered
	if registered_flags[name] then
		d.print(("(%s) Flag %s already exists!"):format(function_name, name), true, 1)
		return
	end

	---@class IntegerFlag
	local flag = {
		name = name,
		default_value = default_value,
		tags = tags,
		read_permission_requirement = read_permission_requirement,
		write_permission_requirement = write_permission_requirement,
		function_to_execute = function_to_execute,
		flag_type = "integer",
		limit = {
			min = min,
			max = max
		}
	}

	registered_flags[name] = flag

	if g_savedata.flags[name] == nil then
		g_savedata.flags[name] = default_value
	end
end

--# Register an number flag, can only be an number.
---@param name string the name of the flag
---@param default_value number the default_value for this flag
---@param tags table<integer, string> a table of tags for this flag, can be used to filter tags for displaying to the user.
---@param read_permission_requirement string the permission required to read this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param write_permission_requirement string the permission required to write to this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param function_to_execute function|nil the function to execute when this value is set. params are (in order): "value, old_value, peer_id", if you do not need to specify a function, just provide nil to avoid extra performance cost of calling an empty function.
---@param description string the description of the flag
---@param min integer|nil the minimum value for the flag (nil for none)
---@param max integer|nil the maximum value for the flag (nil for none)
function Flag.registerNumberFlag(name, default_value, tags, read_permission_requirement, write_permission_requirement, function_to_execute, description, min, max)
	local function_name = "Flag.registerNumberFlag"

	-- if this flag has already been registered
	if registered_flags[name] then
		d.print(("(%s) Flag %s already exists!"):format(function_name, name), true, 1)
		return
	end

	---@class NumberFlag
	local flag = {
		name = name,
		default_value = default_value,
		tags = tags,
		read_permission_requirement = read_permission_requirement,
		write_permission_requirement = write_permission_requirement,
		function_to_execute = function_to_execute,
		flag_type = "number",
		limit = {
			min = min,
			max = max
		}
	}

	registered_flags[name] = flag

	if g_savedata.flags[name] == nil then
		g_savedata.flags[name] = default_value
	end
end

--# Register a string flag, can only be an string.
---@param name string the name of the flag
---@param default_value string the default_value for this flag
---@param tags table<integer, string> a table of tags for this flag, can be used to filter tags for displaying to the user.
---@param read_permission_requirement string the permission required to read this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param write_permission_requirement string the permission required to write to this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param function_to_execute function|nil the function to execute when this value is set. params are (in order): "value, old_value, peer_id", if you do not need to specify a function, just provide nil to avoid extra performance cost of calling an empty function.
---@param description string the description of the flag
function Flag.registerStringFlag(name, default_value, tags, read_permission_requirement, write_permission_requirement, description, function_to_execute)
	local function_name = "Flag.registerStringFlag"

	-- if this flag has already been registered
	if registered_flags[name] then
		d.print(("(%s) Flag %s already exists!"):format(function_name, name), true, 1)
		return
	end

	---@class StringFlag
	local flag = {
		name = name,
		default_value = default_value,
		tags = tags,
		read_permission_requirement = read_permission_requirement,
		write_permission_requirement = write_permission_requirement,
		function_to_execute = function_to_execute,
		flag_type = "string",
	}

	registered_flags[name] = flag

	if g_savedata.flags[name] == nil then
		g_savedata.flags[name] = default_value
	end
end

--# Register an any flag, can be any value.
---@param name string the name of the flag
---@param default_value any the default_value for this flag
---@param tags table<integer, string> a table of tags for this flag, can be used to filter tags for displaying to the user.
---@param read_permission_requirement string the permission required to read this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param write_permission_requirement string the permission required to write to this flag. Create custom permissions via flag.registerPermission(), defaults are "none", "auth" and "admin"
---@param function_to_execute function|nil the function to execute when this value is set. params are (in order): "value, old_value, peer_id", if you do not need to specify a function, just provide nil to avoid extra performance cost of calling an empty function.
---@param description string the description of the flag
function Flag.registerAnyFlag(name, default_value, tags, read_permission_requirement, write_permission_requirement, function_to_execute, description)
	local function_name = "Flag.registerAnyFlag"

	-- if this flag has already been registered
	if registered_flags[name] then
		d.print(("(%s) Flag %s already exists!"):format(function_name, name), true, 1)
		return
	end

	---@class AnyFlag
	local flag = {
		name = name,
		default_value = default_value,
		tags = tags,
		read_permission_requirement = read_permission_requirement,
		write_permission_requirement = write_permission_requirement,
		function_to_execute = function_to_execute,
		flag_type = "any",
		description = description
	}

	registered_flags[name] = flag

	if g_savedata.flags[name] == nil then
		g_savedata.flags[name] = default_value
	end
end

--[[

	Register Default Permissions

]]

-- None Permission
Flag.registerPermission(
	"none",
	function()
		return true
	end
)

-- Auth Permission
Flag.registerPermission(
	"auth",
	function(peer_id)
		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Permission
Flag.registerPermission(
	"admin",
	function(peer_id)
		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)

Command.registerCommand(
	"flag",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local flag_name = arg[1]

		if not flag_name then
			d.print("You must specify a flag's name! get a list of flags via ?icm flags", false, 1, peer_id)
			return
		end

		local flag = registered_flags[flag_name]

		if not flag then
			d.print(("The flag \"%s\" does not exist! Get a list of flags via ?icm flags"):format(flag_name), false, 1, peer_id)
			return
		end

		-- the player is trying to read the flag
		if not arg[2] then
			-- check if the player has the permission to read the flag
			
			-- if the required read permission does not exist, default it to admin.

			local read_permission = registered_permissions[flag.read_permission_requirement] or registered_permissions["admin"]

			if not read_permission(peer_id) then
				d.print(("You do not have permission to read this flag! You require the permission %s, contact a server admin/owner if you belive this is in mistake."):format(registered_permissions[flag.read_permission_requirement] and flag.read_permission_requirement or "admin"), false, 1, peer_id)
				return
			end

			local flag_value = g_savedata.flags[flag_name]

			if flag.flag_type ~= "string" and flag_value == "nil" then
				flag_value = nil
			end

			-- if the flag's value is a string, format it as a string for display.
			if type(flag_value) == "string" then
				flag_value = ("\"%s\""):format(flag_value)
			end

			d.print(("%s's current value is: %s"):format(flag.name, flag_value), false, 0, peer_id)
		else
			-- the player is trying to set the flag

			local write_permission = registered_permissions[flag.write_permission_requirement] or registered_permissions["admin"]

			if not write_permission(peer_id) then
				d.print(("You do not have permission to write this flag! You require the permission %s, contact a server admin/owner if you belive this is in mistake."):format(registered_permissions[flag.write_permission_requirement] and flag.write_permission_requirement or "admin"), false, 1, peer_id)
				return
			end

			---@type string|nil|boolean|number
			local set_value = table.concat(arg, " ", 2, #arg)
			local original_set_value = set_value

			if flag.flag_type ~= "string" then
				if set_value == "nil" then
					set_value = nil
				end

				-- number and integer flags
				if flag.flag_type == "number" or flag.flag_type == "integer" then
					-- convert to number if number, integer if integer
					set_value = flag.flag_type == "number" and tonumber(set_value) or math.tointeger(set_value)

					-- cannot be converted to number if number, or integer if integer.
					if not set_value then
						d.print(("%s is not a %s! The flag %s requires %s inputs only!"):format(original_set_value, flag.flag_type, flag.name, flag.flag_type), false, 1, peer_id)
						return
					end

					-- check if outside of minimum
					if flag.limit.min and set_value < flag.limit.min then
						d.print(("The flag \"%s\" has a minimum value of %s, your input of %s is too low!"):format(flag.name, flag.limit.min, set_value), false, 1, peer_id)
						return
					end

					-- check if outside of maximum
					if flag.limit.max and set_value > flag.limit.max then
						d.print(("The flag \"%s\" has a maximum value of %s, your input of %s is too high!"):format(flag.name, flag.limit.max, set_value), false, 1, peer_id)
						return
					end
				end

				-- boolean flags
				if flag.flag_type == "boolean" then
					set_value = string.toboolean(set_value)

					if set_value == nil then
						d.print(("The flag \"%s\" requires the input to be a boolean, %s is not a boolean!"):format(flag.name, original_set_value))
					end
				end

				-- any flags
				if flag.flag_type == "any" then

					-- parse the value (turn it into the expected type)
					set_value = string.parseValue(set_value)
				end
			end

			local old_flag_value = g_savedata.flags[flag_name]

			-- set the flag
			g_savedata.flags[flag_name] = set_value

			-- call the function for when the flag is written, if one is specified
			if flag.function_to_execute ~= nil then
				flag.function_to_execute(set_value, old_flag_value, peer_id)
			end

			d.print(("Successfully set the value for the flag \"%s\" to %s"):format(flag.name, set_value), false, 0, peer_id)
		end
	end,
	"none",
	"Used to manage more advanced settings, such as disabling modules.",
	"Used to manage more advanced settings.",
	{"sync_tick_rate false","sync_tick_rate"},
	"<flag_name> [value]"
)

Command.registerCommand(
	"flags",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		if arg[1] then
			d.print("Does not yet support the ability to search for flags, only able to give a full list for now, sorry!", false, 0, peer_id)
			return
		end

		d.print("\n-- Flags --", false, 0, peer_id)

		--TODO: make it sort by tags and filter by tags.

		local flag_list = {}

		-- clones, as we will be modifying them and sorting them for display purposes, and we don't want to modify the actual flags.
		local cloned_registered_flags = table.copy.deep(registered_flags)
		for _, flag in pairs(cloned_registered_flags) do
			table.insert(flag_list, flag)
		end

		-- sort the list for display purposes
		table.sort(flag_list, function(a, b)
			-- if the types are the same, then sort alphabetically by name
			if a.flag_type == b.flag_type then
				return a.name < b.name
			end
		
			-- the types are different, sort alphabetically by type.
			return a.flag_type < b.flag_type
		end)

		local last_type = "none"

		for flag_index = 1, #flag_list do
			local flag = flag_list[flag_index]

			-- print the following flag category, if this is now printing a new category of flags
			if last_type ~= flag.flag_type then
				d.print(("\n--- %s Flags ---"):format(flag.flag_type:upperFirst()), false, 0, peer_id)
				last_type = flag.flag_type
			end

			-- print the flag data
			d.print(("-----\nName: %s\nValue: %s\nTags: %s"):format(flag.name, g_savedata.flags[flag.name], table.concat(flag.tags, ", ")), false, 0, peer_id)
		end
	end,
	"none",
	"Used to list all of the flags which you have permission to read, flags are used for more advanced settings.",
	"Used to list the flags.",
	{"flags"}
)


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

---@alias DebugType
---| "all"
---| "chat"
---| "error"
---| "profiler"
---| "map"
---| "graph_node"
---| "driving"
---| "vehicle"
---| "function"
---| "traceback"

---@alias DebugID integer



--[[


	Functions         


]]

---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id) -- "glorious debug function" - senty, 2022
	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) or debug_type == 1 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or debug_type == 7 and " Function:" or debug_type == 8 and " Traceback:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log(string.format("SW %s %s | %s", SHORT_ADDON_NAME, suffix, --[[string.gsub(]]message--[[, "\n", " \\n ")]]))
			else
				debug.log(string.format("SW %s %s | (d.print) message is nil!", SHORT_ADDON_NAME, suffix))
			end
		end
		
		if type(message) == "table" then -- print the message as a table.
			d.printTable(message, requires_debug, debug_type, peer_id)

		elseif requires_debug then -- if this message requires debug to be enabled
			if pl.isPlayer(peer_id) and peer_id then -- if its being sent to a specific peer id
				if d.getDebug(debug_type, peer_id) then -- if this peer has debug enabled
					server.announce(prefix, message, peer_id) -- send it to them
				end
			else
				for _, peer in ipairs(server.getPlayers()) do -- if this is being sent to all players with the debug enabled
					if d.getDebug(debug_type, peer.id) or debug_type == 2 and d.getDebug(0, peer.id) or debug_type == 1 and d.getDebug(0, peer.id) then -- if this player has debug enabled
						server.announce(prefix, message, peer.id) -- send the message to them
					end
				end
			end
		else
			server.announce(prefix, message, peer_id or -1)
		end
	end

	-- print a traceback if this is a debug error message, and if tracebacks are enabled
	if debug_type == 1 and d.getDebug(8) then
		-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
		__ENV = _ENV_NORMAL
		__ENV._ENV_MODIFIED = _ENV
		_ENV = __ENV

		d.trace.print(_ENV_MODIFIED, requires_debug, peer_id)

		-- swap back to modified environment
		_ENV = _ENV_MODIFIED
		-- Remove _ENV_MODIFIED from env, as it will contain itself over and over, without this, trying to disable tracebacks after, will result in a stack overflow.
		_ENV_MODIFIED = nil
		-- Also remove __ENV, for the same reason as above.
		__ENV = nil
	end
end

function Debugging.debugTypeFromID(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

function Debugging.debugIDFromType(debug_type)

	debug_type = string.friendly(debug_type)

	for debug_id, d_type in pairs(debug_types) do
		if debug_type == string.friendly(d_type) then
			return debug_id
		end
	end
end

--# prints all data which is in a table (use d.print instead of this)
---@param T table the table of which you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler)
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.printTable(T, requires_debug, debug_type, peer_id)
	d.print(string.fromTable(T), requires_debug, debug_type, peer_id)
end

---@param debug_id integer the type of debug | 0 = debug | 1 = error | 2 = profiler | 3 = map
---@param peer_id ?integer the peer_id of the player you want to check if they have it enabled, leave blank to check globally
---@return boolean enabled if the specified type of debug is enabled
function Debugging.getDebug(debug_id, peer_id)
	if not peer_id or not pl.isPlayer(peer_id) then -- if any player has it enabled
		if debug_id == -1 then -- any debug
			for _, enabled in pairs(g_savedata.debug) do
				if enabled then 
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
		local player = pl.dataByPID(peer_id)
		
		-- ensure the data for this player exists
		if not player then
			return false
		end

		if type(player.getDebug) ~= "function" then -- update the OOP functions.
			player = pl.updateData(player)
		end

		return player:getDebug(debug_id)
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
					b = 190
					g = 25
				elseif NSO == 1 then -- brighter for NSO
					b = 255
					g = 100
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
				--d.print(("setting up function %s()..."):format(name), true, 7)
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
				--d.print(("setting up function %s()..."):format(name), true, 8)
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

			g_savedata.foo_bar = true

			--onTick = setupTraceback(onTick, "onTick")

			-- add the error checker
			AddonCommunication.executeOnReply(
				SHORT_ADDON_NAME,
				"DEBUG.TRACEBACK.ERROR_CHECKER",
				0,
				function(self)
					-- if traceback debug has been disabled, then remove ourselves
					if not g_savedata.debug.traceback.enabled then
						self.count = 0

					-- Otherwise, tracebacks are enabled, and the stack is not empty, that means that an error occured, so print the stack.
					elseif g_savedata.debug.traceback.stack_size > 0 then
						-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
						__ENV = _ENV_NORMAL
						__ENV._ENV_MODIFIED = _ENV
						_ENV = __ENV

						-- Print the stack.
						d.trace.print(_ENV_MODIFIED)

						-- swap back to modified environment
						_ENV = _ENV_MODIFIED
						-- Remove _ENV_MODIFIED from env, as it will contain itself over and over, without this, trying to disable tracebacks after, will result in a stack overflow.
						_ENV_MODIFIED = nil
						-- Also remove __ENV, for the same reason as above.
						__ENV = nil

						-- Set stack size to 0.
						g_savedata.debug.traceback.stack_size = 0
					end
				end,
				-1,
				-1
			)

			ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)

			return "Enabled Tracebacks"
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

			--[[d.print("Loading _ENV_NORMAL into _ENV...", true, 0)

			-- Remove _ENV_MODIFIED from _ENV_NORMAL, to prevent potential infinite recursion when creating a deep copy.
			_ENV_NORMAL._ENV_MODIFIED = nil

			__ENV = _ENV_NORMAL.table.copy.deep(_ENV_NORMAL, _ENV_NORMAL, true)
			__ENV.g_savedata = g_savedata
			_ENV = __ENV

			_ENV_NORMAL = nil]]

			--[[
				It seems that i'd have to figure out a system to only rollback functions, but keep variables.
					however, some functions may not exist until after tracebacks are setup, which while would mean that
					they wouldn't have tracebacks injected, would also mean we'd have to figure out if they already exist,
					that way we can carry them over.

				But instead, of making a super complex system, we could just disable tracebacks, and then just get the player to
					reload scripts, which would be much simpler and less prone to bugs.

				So thats the route I took.
			]]

			return "Tracebacks are set to be disabled, You must run \"?reload_scripts\" to finish disabling tracebacks."
		end
	end
end

function Debugging.setDebug(debug_id, peer_id, override_state)

	if not peer_id then
		d.print("(Debugging.setDebug) peer_id is nil!", true, 1)
		return "peer_id was nil"
	end

	local player_data = pl.dataByPID(peer_id)

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
			--[[
				Set the player's debug state.
			]]

			-- Get the debug's name from it's id
			local debug_name = debug_types[debug_id]

			-- If the override state is unspecified, invert the player's current debug option.
			if override_state == nil then
				player_data.debug[debug_name] = not player_data.debug[debug_name]
			-- Otherwise, set the player's debug option to the override_state.
			else
				player_data.debug[debug_name] = override_state
			end
			
			-- if it's enabled for this player
			if player_data.debug[debug_types[debug_id]] then
				-- enable it globally
				g_savedata.debug[debug_types[debug_id]].enabled = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[debug_id], player_data.debug[debug_types[debug_id]], peer_id)
		end
	end
end

function Debugging.checkDebug() -- checks all debugging types to see if anybody has it enabled, if not, disable them to save on performance
	local keep_enabled = {}

	-- check all debug types for all players to see if they have it enabled or disabled
	local player_list = s.getPlayers()
	for _, peer in pairs(player_list) do
		local player_data = pl.dataByPID(peer.id)
		for debug_type, debug_type_enabled in pairs(player_data.debug) do
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
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][(g_savedata.tick_counter-g_savedata.flags.profiler_tick_smoothing)] = nil
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

		-- get the current ms for this profiler instance
		current_ms = g_savedata.profiler.display.current[debug_name]

		-- if current is nil, then don't display.
		if not current_ms then
			goto next_profiler_instance
		end

		debug_message = ("%s\n--\n%s: %.2f|%.2f|%.2f"):format(debug_message, debug_name, debug_data, g_savedata.profiler.display.max[debug_name], g_savedata.profiler.display.current[debug_name])
	
		::next_profiler_instance::
	end
	return debug_message
end

function Debugging.generateProfilerDisplayData(t, old_node_name)
	if not t then
		for node_name, node_data in pairs(g_savedata.profiler.total) do
			if type(node_data) == "table" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif type(node_data) == "number" then
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
					valid_ticks = valid_ticks + 1
					data_total = data_total + g_savedata.profiler.total[node_name][(g_savedata.tick_counter-i)]
				end
				g_savedata.profiler.display.average[node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.current[node_name] = g_savedata.profiler.total[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	else
		for node_name, node_data in pairs(t) do
			if type(node_data) == "table" and node_name ~= "timer" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif node_name == "timer" then
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				local max_node = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
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
				g_savedata.profiler.display.average[old_node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[old_node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
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

			-- wrap in "" if arg is a string
			if type(arg) == "string" then
				arg = ("\"%s\""):format(arg)
			end

			-- only show tables if the traceback_print_tables flag is enabled
			if g_savedata.flags.traceback_print_tables then
				if type(arg) == "table" then
					d.print("debugging.lua random ass debug: "..tostring(arg), false, 0)
					arg = --[[string.gsub(]]string.fromTable(arg)--, "\n", " ")
				end
			end

			s = ("%s%s%s"):format(s, arg, i ~= arg_len and ", " or "")
		end
	end
	return s
end

function Debugging.buildReturn(args)
	return d.buildArgs(args)
end

Debugging.trace = {

	print = function(ENV, requires_debug, peer_id)
		local g_tb = ENV.g_savedata.debug.traceback

		local str = ""

		if g_tb.stack_size > 0 then
			str = ("Error in function: %s(%s)"):format(g_tb.funct_names[g_tb.stack[g_tb.stack_size][1]], d.buildArgs(g_tb.stack[g_tb.stack_size][2]))
		end

		for trace = g_tb.stack_size - 1, 1, -1 do
			str = ("%s\n    Called By: %s(%s)"):format(str, g_tb.funct_names[g_tb.stack[trace][1]], d.buildArgs(g_tb.stack[trace][2]))
		end

		d.print(str, requires_debug or false, 8, peer_id or -1)
	end
}

--[[
Boolean Flags
]]

-- traceback_print_tables, if enabled the tracebacks will print the tables, default disabled as some tables will break the messages and make them massive.
Flag.registerBooleanFlag(
	"traceback_print_tables",
	false,
	{
		"debug",
		"tracebacks"
	},
	"admin",
	"admin",
	nil,
	"if enabled the tracebacks will print the tables, default disabled as some tables will break the messages and make them massive."
)


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
				if variable and variable ~= "" then
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
				if variable and variable ~= "" then
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


---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[

	Registers the default variable interaction commands.

]]

-- Get Variable command
Command.registerCommand(
	"print_variable",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local location_string = arg[1]

		local value_at_path, is_success = table.getValueAtPath(location_string)

		if not is_success then
			d.print(("failed to get value at path %s"):format(location_string), false, 1, peer_id)
			return
		end

		d.print(("value of %s: %s"):format(location_string, string.fromTable(value_at_path)), false, 0, peer_id)
	end,
	"admin",
	"Gets the value of a variable. Automatically converts tables to strings.",
	"Gets the value of a variable.",
	{"g_savedata", "Command", "g_savedata.tick_counter"}
)

-- Set Variable command
Command.registerCommand(
	"set_variable",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local location_string = arg[1]
		local value_to_set_to = arg[2]
		
		local is_success = table.setValueAtPath(location_string, value_to_set_to)

		if not is_success then
			d.print(("failed to set the value at path %s to %s"):format(location_string, value_to_set_to), false, 1, peer_id)
			return
		end

		d.print(("set %s to %s"):format(location_string, value_to_set_to), false, 0, peer_id)
	end,
	"admin",
	"Sets the value of a variable. Allowing you to set the value of a variable.",
	"Sets the value of a variable.",
	{"g_savedata.tick_counter 0", "g_savedata.is_attack false"}
)

-- Print Entry Count command
Command.registerCommand(
	"print_entry_count",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Get the location string from the user's input.
		local location_string = arg[1]

		-- Get the value at the path.
		local value_at_path, is_success = table.getValueAtPath(location_string)

		-- If we failed to get the value at the path, print an error message and return.
		if not is_success then
			d.print(("Failed to get value at path %s"):format(location_string), false, 1, peer_id)
			return
		end

		-- If the value at the path is not a table, print an error message and return.
		if type(value_at_path) ~= "table" then
			d.print(("Value at path %s is not a table"):format(location_string), false, 1, peer_id)
			return
		end

		-- Print the element count of the table.
		d.print(("Entry count of %s: %s"):format(location_string, table.length(value_at_path)), false, 0, peer_id)
	end,
	"admin",
	"Gets the entry count of a table.",
	"Gets the entry count of a table.",
	{"g_savedata", "Command", "g_savedata.tick_counter"}
)


-- Add the ICM specific commands not included in their own libraries
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


 -- the command library -- the flag command library
--[[


	Library Setup


]]

-- required libraries

-- library name
AddonLocationUtils = {}

-- shortened library name
alu = AddonLocationUtils

--[[


	Variables
   

]]

s = s or server

--[[


	Classes


]]

--[[


	Functions         


]]

---# print function just in case debugging.lua is not present.
---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function AddonLocationUtils.print(message, requires_debug, debug_type, peer_id)
	if not d then
		s.announce("alu", tostring(message))
		return
	end

	d.print(message, requires_debug, debug_type, peer_id)
end

---@param addon_index number|table<_, integer>? the target addon index to go through its components, leave nil or -1 for all, specify a table<_, addon_index> for multiple. 
---@param addon_pattern string? the pattern to match the addon name against. leave nil to not care about the addon name. (will be ignored if the addon index is specified)
---@param location_pattern string? the pattern to match the location name against. leave nil to not care about the location name.
---@param component_pattern string? the pattern to match the component name against. leave nil to not care about the component name.
function AddonLocationUtils.getMissionComponents(addon_index, addon_pattern, location_pattern, component_pattern)

	-- set nil addon_index to -1
	addon_index = addon_index or -1

	--[[
		
		make sure parametres are valid

	]]

	local addon_index_type = type(addon_index)

	if addon_index_type ~= "integer" and addon_index_type ~= "table" and addon_index ~= -1 then
		alu.print(("(alu.getMissionComponents) addon_index was specified, however it is not a integer or a table! addon_index: %s"):format(addon_index), true, 1)
		return
	end

	local specified_addon_index = addon_index ~= -1

	if specified_addon_index and addon_index_type == "integer" then
		addon_index = {addon_index}
	end

	if specified_addon_index and addon_index_type == "number" and not s.getAddonData(addon_index) then
		alu.print(("(alu.getMissionComponents) addon_index was specified, however there is not an addon matching this index! addon_index: %s"):format(addon_index), true, 1)
		return
	end

	local components = {}

	---@type table<integer, SWAddonData>
	local addons_to_check = {}
	
	-- create a list of all of the addons to check, with their data as the value
	if not specified_addon_index then
		for i = 0, s.getAddonCount() -1 do
			local addon_data = s.getAddonData(i)
			if addon_data and (not addon_pattern or addon_data.name:match(addon_pattern)) then
				addons_to_check[i] = s.getAddonData(i)
			end
		end
	else
		for i = 0, #addon_index do
			local _addon_index = addon_index[i]
			local addon_data = s.getAddonData(_addon_index)

			if not addon_data then
				alu.print(("(alu.getMissionComponents) addon_index was specified, however there is not an addon matching this index! addon_index: %s"):format(_addon_index), true, 1)
			else
				addons_to_check[i] = addon_data
			end
		end
	end

	-- go through all locations in the addons to check
	for addon_index, addon_data in pairs(addons_to_check) do

		-- go through all locations in this addon
		for location_index = 0, addon_data.location_count - 1 do
			local location_data, is_success = s.getLocationData(addon_index, location_index)

			-- check if this location matches the criteria
			if is_success and (not location_pattern or location_data.name:match(location_pattern)) then

				-- go through all components in this location
				for component_index = 0, location_data.component_count - 1 do
					local component_data, is_success = s.getLocationComponentData(addon_index, location_index, component_index)
					
					-- check if this component matches the criteria
					if is_success and (not component_pattern or component_data.display_name:match(component_pattern)) then
						table.insert(components, component_data)

						local components_table_index = #components
						components[components_table_index].addon_index = addon_index
						components[components_table_index].addon_data = addon_data
						components[components_table_index].location_index = location_index
						components[components_table_index].location_data = location_data
						components[components_table_index].component_index = component_index
					end
				end
			end
		end
	end

	return components
end
 -- functions for addon locations and environment mods
-- required libraries
-- required libraries

-- library name
Tags = {}

--- Checks if a tag exists in a table of tags
--- @param tags table<number, string> a table of tags to search through
--- @param tag string the tag to search for
--- @param decrement boolean|nil whether to search from the end of the table to the start
--- @return boolean has_tag whether the tag was found
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

--- gets the value of the specifed tag, returns nil if tag not found. 
--- Note: **By default it uses tonumber()** on the value, so remember to set the as_string parameter to true if you are getting text
--- @param tags table<number, string> a table of tags to search through
--- @param tag string the tag to search for
--- @param as_string boolean? whether to return the value as a string instead of a number
--- @overload fun(tags: table<number, string>, tag: string, as_string: true): string?
--- @return number? value the value of the tag, nil if not found
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

--- @class SpawnableComponentData
--- @field tags_full                        string
--- @field tags                             table<number, string> The tags on the component
--- @field display_name                     string The display name of the component
--- @field type                             SWAddonComponentDataTypeEnum The type of the component (0 = zone, 1 = object, 2 = character, 3 = vehicle, 4 = flare, 5 = fire, 6 = loot, 7 = button, 8 = animal, 9 = ice, 10 = cargo_zone)
--- @field id                               number The ID of the component from the missions editor e.g. ID_27
--- @field dynamic_object_type              SWObjectTypeEnum The object type of the component (number for pan/character/pot/whatever)
--- @field transform                        SWMatrix The position of the component
--- @field vehicle_parent_component_id      number 
--- @field character_outfit_type            number The character outfit type (See Outfit type)
--- @field component_index                  number the component_index inside of the location

--- adds .component_index to component_data
--- @param component_index number the index of the component, local to each location.
--- @param component_data SWAddonComponentData the data of the component
--- @return SpawnableComponentData component_data component_data but with .component_index = component_index
function SpawningUtils.populateComponentData(component_index, component_data)
	component_data.component_index = component_index

	---@cast component_data -SWAddonComponentData
	return component_data
end

-- spawn an individual object descriptor from a playlist location
--- @param spawn_transform SWMatrix the matrix of where to spawn the component
--- @param addon_index number the index of the addon which contains the component
--- @param location_index number the index of the location which contains the component
--- @param component_data SpawnableComponentData the populated component data of the component
--- @param parent_vehicle_id number? the id of the vehicle, to parent this component to
function SpawningUtils.spawnObjectType(spawn_transform, addon_index, location_index, component_data, parent_vehicle_id)

	if component_data or component_data.component_index then
		local component, is_success = server.spawnAddonComponent(spawn_transform, addon_index, location_index, component_data.component_index, parent_vehicle_id)
		-- if we got is_success and component isn't nil
		if is_success and component then
			-- if it's a group and a valid group_id, return the group_id
			if component.group_id and component.group_id ~= 0 then
				return component.group_id
			-- if it's a object and a valid object_id, return the object_id
			elseif component.object_id and component.object_id ~= 0 then
				return component.object_id
			end
		end
		
		-- then it failed to spawn the addon component
		d.print("this addon index: "..s.getAddonIndex(), false, 0)
		-- turn the component into a string if its a table
		if type(component) == "table" then
			component = string.fromTable(component)
		end
		-- print an error
		d.print(("(Improved Conquest Mode) Failed to spawn addon component! \ncomponent: %s\naddon_index: %s\nlocation index: %s"):format(component, addon_index, location_index), false, 1)
		return nil
	elseif component_data then
		d.print("(su.spawningUtils) component_data.component_index is nil!", true, 1)
		d.print(component_data, true, 1)
	else
		d.print("(su.spawningUtils) component_data is nil!", true, 1)
	end
end

function SpawningUtils.spawnObject(spawn_transform, addon_index, location_index, component_data, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	--d.print(component_data)

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, component_data.transform), addon_index, location_index, component_data, parent_vehicle_id)

	-- add object to spawned object tables

	-- if the id is valid
	if spawned_object_id and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(component_data.tags, "vehicle_type=wep_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(component_data.tags, "type=dlc_weapons_flag") then
			--TODO: Check if this is even used anymore?
			--l_vehicle_type = "flag"
			d.print("(su.spawnObject) Spawned a flag vehicle!", true, 0)
		end

		local object_data = {
			name = component_data.display_name,
			type = component_data.type,
			id = spawned_object_id,
			component_id = component_data.id,
			vehicle_type = l_vehicle_type,
			size = Tags.getValue(component_data.tags, "size", true) or "small"
		}

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
	else
		d.print("(su.spawnObject) Failed to spawn vehicle!", true, 1)
	end

	return nil
end

function SpawningUtils.spawnObjects(spawn_transform, addon_index, location_index, object_descriptors, out_spawned_objects)
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

		su.spawnObject(spawn_transform, addon_index, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end
 -- functions used by the spawn vehicle function -- functions related to getting tags from components inside of mission and environment locations -- functions for addon to addon communication
-- required libraries

-- library name
Cache = {}

---@param location string? where to reset the data, if left blank then resets all cache data
---@return boolean is_success returns true if successfully cleared the cache
function Cache.reset(location) -- resets the cache
	if not location then
		g_savedata.cache = {}
	else
		if g_savedata.cache[location] then
			g_savedata.cache[location] = nil
		--[[else
			if not g_savedata.cache_stats.failed_resets then
				g_savedata.cache_stats.failed_resets = 0
			end
			g_savedata.cache_stats.failed_resets = g_savedata.cache_stats.failed_resets + 1
			d.print("Failed to reset cache data at "..tostring(location)..", this should not be happening!", true, 1)
			return false]]
		end
	end
	g_savedata.cache_stats.resets = g_savedata.cache_stats.resets + 1
	return true
end

---@param location string where to write the data
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

---@param location string where to read the data from
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

---@param location string where to check
---@return boolean exists if the data exists at the location
function Cache.exists(location)
	if g_savedata.cache[location] and g_savedata.cache[location] ~= {} and (type(g_savedata.cache[location]) ~= "table" or table.length(g_savedata.cache[location]) > 0) or g_savedata.cache[location] == false then
		--d.print("g_savedata.Cache."..location.." exists", true, 0)

		return true
	end
	--d.print("g_savedata.Cache."..location.." doesn't exist", true, 0)
	return false
end

-- Define commands related to cache
Command.registerCommand(
	"clearcache",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("clearing cache", false, 0, peer_id)
		Cache.reset()
		d.print("cache reset", false, 0, peer_id)
	end,
	"admin",
	"",
	"",
	{""}
)

Command.registerCommand(
	"debugcache",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("Cache Writes: "..g_savedata.cache_stats.writes.."\nCache Failed Writes: "..g_savedata.cache_stats.failed_writes.."\nCache Reads: "..g_savedata.cache_stats.reads, false, 0, peer_id)
	end,
	"admin",
	"",
	"",
	{""}
)
 -- functions relating to the custom 
--[[


	Library Setup


]]

-- required libraries
--[[


	Library Setup


]]

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
	for _, vehicles_with_role in pairs(g_savedata.constructable_vehicles) do
		if type(vehicles_with_role) == "table" then
			for _, vehicles_with_type in pairs(vehicles_with_role) do
				if type(vehicles_with_type) == "table" then
					for _, vehicles_with_strategy in pairs(vehicles_with_type) do
						if type(vehicles_with_strategy) == "table" then
							for i = 1, #vehicles_with_strategy do
								vehicles_with_strategy[i].variations = {}
								d.print("cleared prefab_data for vehicle "..vehicles_with_strategy[i].name)
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
					---@class FLAG_PREFAB
					flag_prefab = { 
						addon_index = addon_index,
						location_index = location_index,
						component_index = component_index,
						transform = component_data.transform
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
				-- the variation of this vehicle
				local variation = Tags.getValue(component_data.tags, "variation", true) or "normal"

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

						-- update id
						if table.length(constructable_vehicle_data.variations) == 0 then
							constructable_vehicle_data.id = #g_savedata.vehicle_list
						else
							d.print("removing vehicle from vehicle_list with id: "..#g_savedata.vehicle_list, false, 0)
							g_savedata.vehicle_list[#g_savedata.vehicle_list] = nil
						end

						constructable_vehicle_data.variations[variation] = constructable_vehicle_data.variations[variation] or {}

						-- update prefab data
						table.insert(constructable_vehicle_data.variations[variation], prefab_data)

						-- break, as we found a match.
						break
					elseif i == #g_savedata.constructable_vehicles[role][vehicle_type][strategy] then
						-- this vehicle does not exist
						table.insert(g_savedata.constructable_vehicles[role][vehicle_type][strategy], {
							variations = {
								[variation] = {
									prefab_data
								}
							},
							name = location_data.name,
							mod = 1,
							id = #g_savedata.vehicle_list
						})
					end
				end
				d.print(("set id: %i | # of vehicles w same role, type and strategy: %s | name: %s | from addon with index: %i | variation: %s"):format(#g_savedata.vehicle_list, #g_savedata.constructable_vehicles[role][vehicle_type][strategy], location_data.name, addon_index, variation), true, 0)
				::createVehiclePrefabs_continue_component::
			end
			::createVehiclePrefabs_continue_location::
		end

		::createVehiclePrefabs_continue_addon::
	end
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
	"(0.3.2.6)",
	"(0.3.2.8)",
	"(0.3.2.9)",
	"(0.4.0.21)"--[[,
	"(0.4.0.23)"]]
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
---@return table? migrated_g_savedata
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
---@return integer? version_id the id of the version
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
---@return string? version the version associated with the id
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
---@param version string? the current version, leave blank if want data on current version
---@return VERSION_DATA? version_data the data about the version
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
		local migrated_g_savedata, is_success = comp.migrateVersionSystem(false) -- migrate the version data
		if not is_success or migrated_g_savedata == nil then
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
	if version_data == nil or not is_success then
		d.print("(comp.saveBackup) failed to get version data. This is probably not good!", false, 1)
		return false
	end
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
	if not is_success or version_data == nil then
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

	elseif version_data.newer_versions[1] == "(0.3.2.8)" then -- 0.3.2.8 changes

		g_savedata.settings.CONVOY_FREQUENCY = 38 * time.minute

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.2.9)" then -- 0.3.2.9 changes

		g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER = time.hour

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	elseif version_data.newer_versions[1] == "(0.4.0.21)" then -- 0.4.0.21 changes

		-- add flags to g_savedata
		g_savedata.flags = {}

		-- add g_savedata.game_tick_counter
		g_savedata.game_tick_counter = g_savedata.tick_counter

		-- add the capture point payments
		g_savedata.settings.CAPTURE_POINT_PAYMENTS = true
		g_savedata.libraries = {
			capture_point_payments = {
				sleep_tracker = {
					normal = 0,
					total = 0
				},
				last_payout = 0.2916666667
			}
		}
		g_savedata.player_base_island.payroll_multiplier = 1
		for _, capture_point in pairs(g_savedata.islands) do
			capture_point.payroll_multiplier = 1
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	--[[elseif version_data.newer_versions[1] == "(0.4.0.23)" then -- 0.4.0.23 changes

		-- add the g_savedata for vehicleFires
		g_savedata.libraries.vehicle_fires = {
			potential_ai_fires = {}, ---@type table<integer, potentialAIFire>
			ai_vehicles_with_fires = {} ---@type table<integer, AIVehicleWithFire>
		}

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)]]
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

		if not is_success or version_data == nil then
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
--[[


	Library Setup


]]


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


-- library name
Pathfinding = {}

-- shortened library name
p = Pathfinding

--[[


	Variables
   

]]

s = s or server

--[[


	Classes


]]

---@class PathfindPoint3D
---@field x number the x coordinate of the graph node
---@field y number the y coordinate of the graph node
---@field z number the z coordinate of the graph node

--[[


	Functions         


]]

-- Get the pathfinding exclusion tags
---@return "not_NSO"|"NSO" exclude the pathfinding exclusion tags
function Pathfinding.getExclusionTags()
	-- if NSO is enabled, then exclude vanilla only graph nodes.
	if g_savedata.info.mods.NSO then
		return "not_NSO"
	-- otherwise, exclude NSO only graph nodes.
	else
		return "NSO"
	end
end

function Pathfinding.resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		s.removeMapID(-1, v.ui_id)
	end

	vehicle_object.path = {}
end

-- makes the vehicle go to its next path
---@param vehicle_object vehicle_object the vehicle object which is going to its next path
---@return number|nil more_paths the number of paths left, nil if error
---@return boolean is_success if it successfully went to the next path
function Pathfinding.nextPath(vehicle_object)

	--? makes sure vehicle_object is not nil
	if not vehicle_object then
		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
		return nil, false
	end

	--? makes sure the vehicle_object has paths
	if not vehicle_object.path then
		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.group_id), true, 1)
		return nil, false
	end

	if vehicle_object.path[1] then
		s.removeMapID(-1, vehicle_object.path[1].ui_id) --Delete the next paths debug label since it wont be able to be deleted after this
		if vehicle_object.path[0] then
			--s.removeMapID(-1, vehicle_object.path[0].ui_id)
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

---@param vehicle_object vehicle_object the vehicle you want to add the path for
---@param target_dest SWMatrix the destination for the path
---@param translate_forward_distance number? the increment of the distance, used to slowly try moving the vehicle's matrix forwards, if its at a tile's boundery, and its unable to move, used by the function itself, leave undefined.
function Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)

	-- path tags to exclude
	local exclude = Pathfinding.getExclusionTags()

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

		for _, path in pairs(path_list) do
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
		--local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]

			if translate_forward_distance then
				local second_last_path_pos
				if #vehicle_object.path < 2 then
					second_last_path_pos = vehicle_object.transform
				else
					local second_last_path = vehicle_object.path[#vehicle_object.path - 1]
					second_last_path_pos = matrix.translation(second_last_path.x, second_last_path.y, second_last_path.z)
				end

				local yaw, _ = math.angleToFace(second_last_path_pos[13], waypoint_end.x, second_last_path_pos[15], waypoint_end.z)

				path_start_pos = m.translation(waypoint_end.x + translate_forward_distance * math.sin(yaw), waypoint_end.y, waypoint_end.z + translate_forward_distance * math.cos(yaw))
			
				--[[server.addMapLine(-1, vehicle_object.ui_id, m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z), path_start_pos, 1, 255, 255, 255, 255)
			
				d.print("path_start_pos (existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
			end
		else
			path_start_pos = vehicle_object.transform

			if translate_forward_distance then
				path_start_pos = matrix.multiply(vehicle_object.transform, matrix.translation(0, 0, translate_forward_distance))
				--[[server.addMapLine(-1, vehicle_object.ui_id, vehicle_object.transform, path_start_pos, 1, 150, 150, 150, 255)
				d.print("path_start_pos (no existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = vehicle_object.transform
			end
		end

		start_x, start_y, start_z = m.position(vehicle_object.transform)

		local exclude_offroad = false

		local squad_index, squad = Squad.getSquadFromGroup(vehicle_object.group_id)
		if squad and squad.command == SQUAD.COMMAND.CARGO then
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

		--[[
			checks if the vehicle is basically stuck, and if its at a tile border, if it is, 
			try moving matrix forwards slightly, and keep trying till we've got a path, 
			or until we reach a set max distance, to avoid infinite recursion.
		]]

		local max_attempt_distance = 30
		local max_attempt_increment = 5

		translate_forward_distance = translate_forward_distance or 0

		if translate_forward_distance < max_attempt_distance then
			local last_path = vehicle_object.path[#vehicle_object.path]

			-- if theres no last path, just set it as the vehicle's positon.
			if not last_path then
				last_path = {
					x = vehicle_object.transform[13],
					z = vehicle_object.transform[15]
				}
			end

			-- checks if we're within the max_attempt_distance of any tile border
			local tile_x_border_distance = math.abs((last_path.x-250)%1000-250)
			local tile_z_border_distance = math.abs((last_path.z-250)%1000-250)

			if tile_x_border_distance <= max_attempt_distance or tile_z_border_distance <= max_attempt_distance then
				-- increments the translate_forward_distance
				translate_forward_distance = translate_forward_distance + max_attempt_increment

				d.print(("(Pathfinding.addPath) moving the pathfinding start pos forwards by %sm"):format(translate_forward_distance), true, 0)

				Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)
			end
		else
			d.print(("(Pathfinding.addPath) despite moving the pathfinding start pos forward by %sm, pathfinding still failed for vehicle with id %s, aborting to avoid infinite recursion"):format(translate_forward_distance, vehicle_object.group_id), true, 0)
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

	---@return table<integer, PathfindPoint3D> path the path with the added y values
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
		if g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)] and g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
		end
	end
	return path --return the path with the added, or not, y values.
end

-- Credit to woe
function Pathfinding.createPathY() --this looks through all env mods to see if there is a "zone" then makes a table of y values based on x and z as keys.
	--- If the input string is 'land_path' or 'ocean_path', returns the input. If not, returns false
	--- @generic T: string
	--- @param tag T the tag to check
	--- @return false|T
	local isGraphNode = function(tag)
		if tag == "land_path" or tag == "ocean_path" then
			return tag
		end
		return false
	end

	-- indexed by name, this is so we dont have to constantly call server.getTileTransform for the same tiles. 
	local tile_locations = {}

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
						local COMPONENT_DATA = s.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then

								local transform_matrix = tile_locations[LOCATION_DATA.tile]
								if not transform_matrix then
									tile_locations[LOCATION_DATA.tile] = s.getTileTransform(
										empty_matrix,
										LOCATION_DATA.tile,
										100000
									)

									transform_matrix = tile_locations[LOCATION_DATA.tile]
								end

								if transform_matrix then
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

-----------------------------------------
--- Pathfinding Commands / Debuggers  ---
-----------------------------------------

-- path preview (drawn map lines) helpers
local function getOrCreatePathPreviewUIID(peer_id)
	g_savedata.routing = g_savedata.routing or {}
	g_savedata.routing.path_preview_ui_ids = g_savedata.routing.path_preview_ui_ids or {}

	if not g_savedata.routing.path_preview_ui_ids[peer_id] then
		g_savedata.routing.path_preview_ui_ids[peer_id] = s.getMapID()
	end

	return g_savedata.routing.path_preview_ui_ids[peer_id]
end

local function clearPathPreview(peer_id)
	if not g_savedata.routing or not g_savedata.routing.path_preview_ui_ids then
		return
	end

	local ui_id = g_savedata.routing.path_preview_ui_ids[peer_id]
	if ui_id then
		s.removeMapID(peer_id, ui_id)
	end
end

Command.registerCommand(
	"test_path",
	---@param full_message string
	---@param peer_id integer
	---@param arg table
	function(full_message, peer_id, arg)
		-- Usage:
		--   ?impwep test_path <x> <z> [y] [land|ocean]
		-- Examples:
		--   ?impwep test_path 1000 2000
		--   ?impwep test_path 1000 2000 ocean
		--   ?impwep test_path 1000 2000 5 land
		local x = tonumber(arg[1])
		local z = tonumber(arg[2])
		if not x or not z then
			d.print("Invalid syntax! Usage: ?impwep test_path (x) (z) [y] [land|ocean]", false, 1, peer_id)
			return
		end

		local y
		local graph_arg
		if arg[3] ~= nil then
			local y_num = tonumber(arg[3])
			if y_num ~= nil then
				y = y_num
				graph_arg = arg[4]
			else
				graph_arg = arg[3]
			end
		end

		local required_tags = "land_path"
		if graph_arg then
			local g = tostring(graph_arg):lower()
			if g == "land" or g == "land_path" then
				required_tags = "land_path"
			elseif g == "ocean" or g == "ocean_path" then
				required_tags = "ocean_path"
			else
				d.print("Invalid path type! Use land or ocean.", false, 1, peer_id)
				return
			end
		end

		local player_matrix = s.getPlayerPos(peer_id)
		if not player_matrix then
			d.print("Failed to get player position.", false, 1, peer_id)
			return
		end

		local dest_y = y
		if dest_y == nil then
			if required_tags == "ocean_path" then
				dest_y = 0
			else
				dest_y = player_matrix[14]
			end
		end
		local dest_matrix = m.translation(x, dest_y, z)

		-- clear previous preview for this peer
		clearPathPreview(peer_id)
		local ui_id = getOrCreatePathPreviewUIID(peer_id)

		local excluded_tags = Pathfinding.getExclusionTags()
		local path = s.pathfind(player_matrix, dest_matrix, required_tags, excluded_tags)
		if not path or #path == 0 then
			d.print("No path found.", false, 1, peer_id)
			return
		end

		-- draw path as connected lines
		local prev = player_matrix
		for i = 1, #path do
			local node = path[i]
			local node_y = node.y or 0
			local next = m.translation(node.x, node_y, node.z)
			s.addMapLine(peer_id, ui_id, prev, next, 0.35, 0, 200, 255, 200)
			prev = next
		end

		s.addMapLabel(peer_id, ui_id, 2, "Path Preview", x, z)
		d.print(("Drew path preview with %d nodes (%s). Use ?impwep clear_test_path to remove."):format(#path, required_tags), false, 0, peer_id)
	end,
	"admin",
	"Pathfinds from your position to specified coordinates as shows it on the map. Used for debugging purposes.",
	"Draws a temporary pathfinding preview.",
	{"1000 2000", "1000 2000 ocean", "1000 2000 5 land"},
	"(x) (z) [y] [land|ocean]"
)

Command.registerCommand(
	"clear_test_path",
	---@param full_message string
	---@param peer_id integer
	---@param arg table
	function(full_message, peer_id, arg)
		clearPathPreview(peer_id)
		d.print("Cleared path preview.", false, 0, peer_id)
	end,
	"admin",
	"Clears the temporary path preview drawn by path_preview.",
	"Clears the path preview.",
	{""}
)

Command.registerCommand(
	"show_dead_ends",
	function(full_message, peer_id, arg)
		-- ensure graph nodes are built
		if not g_savedata.graph_nodes.init then
			p.createPathY()
			g_savedata.graph_nodes.init = true
		end

		local draw_lines = false
		if arg[1] and string.lower(arg[1]) == "true" then
			draw_lines = true
		end

		d.print("Starting dead end search... This may take a while.", false, 0, peer_id)

		g_savedata.routing = g_savedata.routing or {}
		g_savedata.routing.dead_ends_ui_id = g_savedata.routing.dead_ends_ui_id or s.getMapID()
		
		-- Clear existing
		s.removeMapID(peer_id, g_savedata.routing.dead_ends_ui_id)

		local task_data = {
			peer_id = peer_id,
			nodes_list = {},
			spatial_grid = {},
			grid_cell_size = 400, --Significantly affects the speed, but lower values might fail to detect some long-distance connections
			current_index = 1,
			dead_ends = {},
			ui_id = g_savedata.routing.dead_ends_ui_id,
			processed_count = 0,
			start_time = s.getTimeMillisec(),
			draw_lines = draw_lines,
			ignore_NSO = true,
		}

		-- Build node list and spatial grid
		for x_str, z_table in pairs(g_savedata.graph_nodes.nodes) do
			for z_str, node_data in pairs(z_table) do
				local x = tonumber(x_str)
				local z = tonumber(z_str)
				if x and z and node_data.type == "land_path" then
					if not task_data.ignore_NSO or node_data.NSO ~= 1 then
						local node = {
							x = x,
							y = node_data.y,
							z = z,
							type = node_data.type
						}
						table.insert(task_data.nodes_list, node)
						
						-- Add to grid
						local gx = math.floor(x / task_data.grid_cell_size)
						local gz = math.floor(z / task_data.grid_cell_size)
						task_data.spatial_grid[gx] = task_data.spatial_grid[gx] or {}
						task_data.spatial_grid[gx][gz] = task_data.spatial_grid[gx][gz] or {}
						table.insert(task_data.spatial_grid[gx][gz], node)
					end
				end
			end
		end

		d.print(("Found %d nodes. Processing..."):format(#task_data.nodes_list), false, 0, peer_id)

		eq.queue(
			function() return true end, -- Always execute
			function(self)
				local data = self:getVar(1)
				local max_time_ms = 20 -- Max ms per tick to avoid freezing the game
				local tick_start = s.getTimeMillisec()
				local avoidString = ""
				if data.ignore_NSO then
					avoidString = "NSO"
				else

				end

				while data.current_index <= #data.nodes_list do
					if s.getTimeMillisec() - tick_start > max_time_ms then
						break
					end

					local node = data.nodes_list[data.current_index]
					local neighbors = {}
					
					-- Find candidates in nearby grid cells
					local gx = math.floor(node.x / data.grid_cell_size)
					local gz = math.floor(node.z / data.grid_cell_size)
					
					for ox = -1, 1 do
						for oz = -1, 1 do
							if data.spatial_grid[gx + ox] and data.spatial_grid[gx + ox][gz + oz] then
								for _, target in pairs(data.spatial_grid[gx + ox][gz + oz]) do
									-- Check if same type and not same node
									if target ~= node and target.type == node.type then
										-- Distance check (optional optimization before pathfinding)
										local dist_sq = (node.x - target.x)^2 + (node.z - target.z)^2
										if dist_sq <= data.grid_cell_size^2 then
											-- Pathfind
											local path = s.pathfind(
												m.translation(node.x, node.y, node.z),
												m.translation(target.x, target.y, target.z),
												node.type,
												avoidString
											)
											
											if path and #path >= 2 then
												-- The neighbor is the second node in the path
												local neighbor_node = path[2]
												-- Create a unique key for the neighbor
												local key = (path_res):format(neighbor_node.x) .. "," .. (path_res):format(neighbor_node.z)
												
												if not neighbors[key] then
													neighbors[key] = true
													if data.draw_lines then
														s.addMapLine(data.peer_id, data.ui_id, m.translation(node.x, node.y, node.z), m.translation(neighbor_node.x, neighbor_node.y, neighbor_node.z), 0.5, 130, 0, 80, 100)
													end
												end
											end
										end
									end
								end
							end
						end
					end
					
					-- Count neighbors
					local neighbor_count = 0
					for _ in pairs(neighbors) do neighbor_count = neighbor_count + 1 end
					
					if neighbor_count == 1 then
						table.insert(data.dead_ends, node)
					end

					data.current_index = data.current_index + 1
					data.processed_count = data.processed_count + 1
				end

				-- Check if done
				if data.current_index > #data.nodes_list then
					self.expired = true
					
					-- Report results
					local duration = (s.getTimeMillisec() - data.start_time) / 1000
					d.print(("Finished processing %d nodes in %.1fs."):format(#data.nodes_list, duration), false, 0, data.peer_id)
					d.print(("Found %d dead ends."):format(#data.dead_ends), false, 0, data.peer_id)
					
					-- Draw markers
					if not data.draw_lines then
						s.removeMapID(data.peer_id, data.ui_id)
					end
					for _, node in pairs(data.dead_ends) do
						s.addMapLabel(data.peer_id, data.ui_id, 1, "Dead End", node.x, node.z)
						Map.addMapCircle(data.peer_id, data.ui_id, m.translation(node.x, node.y, node.z), 5, 1, 255, 0, 0, 255)
					end
				elseif data.processed_count % 100 == 0 then
					-- Progress update every 100 nodes
					d.print(("Processed %d/%d nodes..."):format(data.processed_count, #data.nodes_list), false, 0, data.peer_id)
					debug.log(("Processed %d/%d nodes..."):format(data.processed_count, #data.nodes_list))
				end
			end,
			{task_data},
			-1 -- Infinite executions until done
		)
	end,
	"admin",
	"Finds and marks dead end pathfinding nodes (nodes with only 1 connection). If given true as its argument, also draws the connections between close graph_nodes.",
	"Finds dead end nodes.",
	{"true","false"},
	"[true|false]"
)

Command.registerCommand(
	"clear_dead_ends",
	function(full_message, peer_id, arg)
		if g_savedata.routing and g_savedata.routing.dead_ends_ui_id then
			s.removeMapID(peer_id, g_savedata.routing.dead_ends_ui_id)
			d.print("Cleared dead end markers.", false, 0, peer_id)
		else
			d.print("No dead end markers to clear.", false, 0, peer_id)
		end
	end,
	"admin",
	"Clears the dead end markers.",
	"Clears dead end markers.",
	{""}
)


 -- functions for pathfinding -- functions relating to Players
--[[
	
Copyright 2024 Liam Matthews

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
	Provides some functions that make them more safe, for example, if a function would normally return nil, a number or an incomplete table when it errors, instead
	of a table, it would instead return a table with the incomplete fields filled out as empty, used to keep code cleaner and less subject to errors without tons of
	validation.
]]

-- library name
safe_server = {}

--[[


	Classes


]]

--[[


	Variables


]]

--[[


	Functions


]]

---@param vehicle_id integer the vehicle_id to get the loaded data for.
---@return SWVehicleComponentData loaded_vehicle_data the loaded vehicle data for the vehicle
---@return boolean is_success if it ran without error
function safe_server.getVehicleComponents(vehicle_id)
	-- call the normal function
	local loaded_vehicle_data, is_success = server.getVehicleComponents(vehicle_id)

	-- if the data it retuned is not a table, make it a table.
	if type(loaded_vehicle_data) ~= "table" then
		loaded_vehicle_data = {}
	end

	-- populate missing data
	loaded_vehicle_data.voxels = loaded_vehicle_data.voxels or nil
	loaded_vehicle_data.mass = loaded_vehicle_data.mass or nil
	loaded_vehicle_data.characters = loaded_vehicle_data.characters or {}
	loaded_vehicle_data.components = loaded_vehicle_data.components or {}

	return loaded_vehicle_data, is_success
end
 -- safer functions for the server functions. -- functions for script/world setup.
--[[
spatialGrid.lua

Uses Spatial Hashing to add objects to buckets on a 2d grid
Allows for fast lookup of nearby objects by only checking the buckets near the query point instead of every object in the world
]]


--[[


    Library Setup


]]

-- required libraries

SpatialGrid = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

---@alias spatialObjectID number A unique identifier for an object in the spatial grid. (For example a vehicle ID)

---@alias cellKey any
---@alias cellContents table<spatialObjectID, {obj: spatialObjectID, x: number, z: number}>

--[[


	Functions         


]]

--- Creates a new spatial grid
--- @param cell_size number The size of each grid cell. Should be roughly the size of your typical query radius.
function SpatialGrid.new(cell_size)
    ---@class SpatialGrid
    local newGrid = {
        cell_size = cell_size or 500,
        cells = {}, ---@type table<cellKey, cellContents> The grid cells
        object_keys = {}, ---@type table<spatialObjectID, cellKey>
        stats = {count = 0, cells_used = 0},
        frozen = false,  -- Whether the grid is frozen (no more modifications allowed)
        add = SpatialGrid.add,
        remove = SpatialGrid.remove,
        update = SpatialGrid.update,
        isObjectInGrid = SpatialGrid.isObjectInGrid,
        clean = SpatialGrid.clean,
        freeze = SpatialGrid.freeze,
        query = SpatialGrid.query
    }
    return newGrid
end

--- Freezes the grid, preventing you from making any more changes to it.
--- Reduces the grids memory use by removing unneeded data, and allows for query optimizations.
--- Frozen grids can not be unfrozen
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @return FrozenSpatialGrid frozenGrid The frozen grid
function SpatialGrid.freeze(grid)
    -- Remove all empty cells
    SpatialGrid.clean(grid)
    
    -- Since the grid is no longer going to change, we can change the structure to make
    -- querying faster. This changes it to a row/column system so querys can skip rows/columns
    -- which are empty
    local cell_size = grid.cell_size
    local rows = {} ---@type table<integer, table<integer, cellContents>>
    local rowRanges = {} ---@type table<integer, {minCx: integer, maxCx: integer}>
    for _, cell in pairs(grid.cells) do
        -- Convert the cell contents to a list so querying doesn't need to use pairs
        local listCell = {}
        for obj, pos in pairs(cell) do
            table.insert(listCell, {obj=obj, x=pos.x, z=pos.z})
        end

        -- Calculate the cell's row and column
        sampleObject = listCell[1]
        local cx = math.floor(sampleObject.x / cell_size)
        local cz = math.floor(sampleObject.z / cell_size)

        -- Add the cell to its row
        local row = rows[cz]
        if not row then
            row = {}
            rows[cz] = row
            rowRanges[cz] = {minCx = cx, maxCx = cx}
        else
            -- Used in querys to skip rows which don't have any cells in the query range
            rowRanges[cz] = {minCx = math.min(rowRanges[cz].minCx, cx), maxCx = math.max(rowRanges[cz].maxCx, cx)}
        end

        row[cx] = listCell
    end

    ---@class FrozenSpatialGrid
    local frozenGrid = {
        cell_size = cell_size,
        rows = rows,
        rowRanges = rowRanges,
        frozen = true,
        query = SpatialGrid.queryFrozen
    }
    return frozenGrid
end

---  Generates a unique integer key given cell coordinates
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param x number X coordinate
--- @param z number Z coordinate
--- @return cellKey key The unique cell key
function SpatialGrid.getCellKey(grid, x, z)
    local c_x = math.floor(x / grid.cell_size)
    local c_z = math.floor(z / grid.cell_size)
    
    return c_x + (c_z * 1000000)
end

--- Adds an object to the grid
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param obj spatialObjectID The object to track (must be valid table key)
--- @param x number X coordinate
--- @param z number Z coordinate
function SpatialGrid.add(grid, obj, x, z)
    if grid.object_keys[obj] then
        -- If its already in the grid, update instead
        return SpatialGrid.update(grid, obj, x, z)
    end

    local key = SpatialGrid.getCellKey(grid, x, z)
    local cell = grid.cells[key]
    if not cell then
        -- Create new cell if it doesn't exist
        cell = {}
        grid.cells[key] = cell
        grid.stats.cells_used = grid.stats.cells_used + 1
    end
    
    -- Store position for fast distance checks later
    cell[obj] = {obj=obj, x = x, z = z}
    grid.object_keys[obj] = key
    grid.stats.count = grid.stats.count + 1
end

--- Removes an object from the grid
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param obj spatialObjectID The object to remove
function SpatialGrid.remove(grid, obj)
    local key = grid.object_keys[obj]
    if key then
        local cell = grid.cells[key]
        if cell then
            cell[obj] = nil
        end
        grid.object_keys[obj] = nil
        grid.stats.count = grid.stats.count - 1
    end
end

--- Updates an object's position in the grid
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param obj spatialObjectID The object to update
--- @param x number Objects X coordinate
--- @param z number Objects Z coordinate
function SpatialGrid.update(grid, obj, x, z)
    local old_key = grid.object_keys[obj]
    local new_key = SpatialGrid.getCellKey(grid, x, z)

    if not old_key then
        -- Object not in grid yet, add it
        return SpatialGrid.add(grid, obj, x, z)
    end

    -- Check if the object has moved to a new cell
    if old_key ~= new_key then
        -- Remove from the old cell
        if old_key then
            local old_cell = grid.cells[old_key]
            if old_cell then old_cell[obj] = nil end
        end
        
        -- Get the new cell. Create it if it doesn't exist
        local new_cell = grid.cells[new_key]
        if not new_cell then
            new_cell = {}
            grid.cells[new_key] = new_cell
            grid.stats.cells_used = grid.stats.cells_used + 1
        end
        
        -- Add to new cell
        new_cell[obj] = {obj=obj, x = x, z = z}
        grid.object_keys[obj] = new_key
    else
        -- Same cell, just update position data
        local cell = grid.cells[old_key]
        cell[obj].x = x
        cell[obj].z = z
    end
end

--- Checks if an object is in the grid already
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param obj spatialObjectID The object to check
--- @return boolean inGrid True if the object is in the grid, false otherwise
function SpatialGrid.isObjectInGrid(grid, obj)
    return grid.object_keys[obj] ~= nil
end

--- Sets all empty cells to nil to reduce memory usage if needed
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @return integer totalCleaned The total amount of cells cleaned
function SpatialGrid.clean(grid)
    local totalCleaned = 0

    for cellKey, cellContents in pairs(grid.cells) do
        if next(cellContents) == nil then
            grid.cells[cellKey] = nil
            totalCleaned = totalCleaned + 1
        end
    end
    grid.stats.cells_used = math.max(0, grid.stats.cells_used - totalCleaned)
    
    return totalCleaned
end

--- Queries the grid for objects within a radius
--- @param grid SpatialGrid The grid created using SpatialGrid.new()
--- @param x number Center X
--- @param z number Center Z
--- @param radius number Radius to search
--- @return spatialObjectID[] Found of objects found
function SpatialGrid.query(grid, x, z, radius)
    local result = {}
    local result_count = 1
    local cell_size = grid.cell_size
    
    -- Calculate bounds of the cells to check
    local min_x = math.floor((x - radius) / cell_size)
    local max_x = math.floor((x + radius) / cell_size)
    local min_z = math.floor((z - radius) / cell_size)
    local max_z = math.floor((z + radius) / cell_size)
    
    local r_sq = radius * radius
    
    -- Iterate the cells
    for cz = min_z, max_z do
        local z_offset = cz * 1000000
        for cx = min_x, max_x do
            local cell = grid.cells[cx + z_offset]
            
            if cell then
                for obj, pos in pairs(cell) do
                    -- Check exact distance of each item
                    local dx = x - pos.x
                    local dz = z - pos.z
                    if (dx*dx + dz*dz) <= r_sq then
                        result[result_count] = obj
                        result_count = result_count + 1
                    end
                end
            end
        end
    end
    
    return result
end

--- Queries the grid for objects within a radius. Instead of looking up cell keys, this uses rows/columns
--- to only check cells which exist.
--- @param grid FrozenSpatialGrid The grid created using SpatialGrid.new()
--- @param x number Center X
--- @param z number Center Z
--- @param radius number Radius to search
--- @return spatialObjectID[] Found of objects found
function SpatialGrid.queryFrozen(grid, x, z, radius)
    local result = {}
    local result_count = 1
    local cell_size = grid.cell_size
    local rows = grid.rows
    local rowRanges = grid.rowRanges
    
    -- Calculate bounds of the cells to check
    local min_x = math.floor((x - radius) / cell_size)
    local max_x = math.floor((x + radius) / cell_size)
    local min_z = math.floor((z - radius) / cell_size)
    local max_z = math.floor((z + radius) / cell_size)
    
    local r_sq = radius * radius
    
    -- Iterate the cells
    for cz = min_z, max_z do
        local rowRange = rowRanges[cz]
        if rowRange then
            -- Skip if its cx range doesn't intersect with the query range
            if rowRange.maxCx < min_x or rowRange.minCx > max_x then
                goto skipRow
            end

            -- Loop through every cell in the row which is within the query range
            local row = rows[cz]
            for cx, cell in pairs(row) do
                if cx >= min_x and cx <= max_x then
                    for i=1, #cell do
                        local obj_data = cell[i]
                        local dx = x - obj_data.x
                        local dz = z - obj_data.z
                        if (dx * dx + dz * dz) <= r_sq then
                            result[result_count] = obj_data.obj
                            result_count = result_count + 1
                        end
                    end
                end
            end
            ::skipRow::
        end
    end
    
    return result
end
 -- spatial grid functions

ai_vehicles_grid = SpatialGrid.new(1000)
player_vehicles_grid = SpatialGrid.new(1000)
island_grid = SpatialGrid.new(4000):freeze()
 -- spatial grid definitions -- functions relating to their AI
--[[


	Library Setup


]]

---@diagnostic disable: duplicate-doc-field

s = s or server

-- required libraries

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
	table.tabulate(g_savedata, "libraries", "characters", "characters_to_seat")

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

--- @param object_id integer
function Characters.setIntoSeat(object_id)
	local seat_char_data = g_savedata.libraries.characters.characters_to_seat[object_id]

	local object_data = s.getCharacterData(object_id)

	-- ensure that object_data exists
	if object_data then
		local seat_pos = seat_char_data.seat_data.pos

		s.setCharacterSeated(object_id, seat_char_data.vehicle_id, seat_pos.x, seat_pos.y, seat_pos.z)

		s.setCharacterData(object_id, object_data.hp, seat_char_data.char_config.is_interactable, seat_char_data.char_config.is_ai)
		s.setAIState(object_id, seat_char_data.char_config.ai_state)
		s.setAITargetVehicle(object_id, nil)
	else
		d.print(("(Characters.setIntoSeat) Failed to get character data for object %i"):format(object_id), true, 1)
	end
end

--# spawns the characters for all of the valid seats on the vehicle, and will later add them to the 
---@param vehicle_id integer the vehicle to spawn the characters for, the vehicle must be loaded in or previously been loaded in.
---@param valid_seats table<integer, VALID_SEAT> the valid seat names along with the outfit_id to use for them, set groups up in characters.lua in the valid_seats variable and then use them here
function Characters.createAndSetCharactersIntoSeat(vehicle_id, valid_seats)
	local loaded_data, is_success = server.getVehicleComponents(vehicle_id)

	-- failed to get component data
	if not is_success then
		d.print("(Characters.setupVehicle) failed to get loaded data for vehicle_id: "..vehicle_id, true, 1)
		return {}, false
	end

	-- vehicle has never loaded
	if not loaded_data.components then
		d.print(("(Characters.setupVehicle) vehicle_id: %i has not been loaded yet!"):format(vehicle_id), true, 1)
		return {}, false
	end

	-- vehicle has no seats
	if not loaded_data.components.seats[1] then
		d.print(("(Characters.setupVehicle) vehicle_id: %i has no seats!"):format(vehicle_id), true, 1)
		return {}, false
	end

	-- get it's position
	local vehicle_position, is_success = server.getVehiclePos(vehicle_id)

	-- check if we got the position
	if not is_success then
		d.print(("(Characters.setupVehicle) failed to get position for vehicle_id: %i"):format(vehicle_id), true, 1)
		return {}, false
	end

	-- make sure it's overriding the callback functions
	Characters.overrides()

	local characters = {}

	-- go through all valid seat types, and for each, go through all of the seats, this way the output table is sorted in the order the valid seats table is ordered.
	for valid_seat_id = 1, #valid_seats do
		local valid_seat = valid_seats[valid_seat_id]
		for seat_id = 1, #loaded_data.components.seats do
			local seat_data = loaded_data.components.seats[seat_id]
			if string.find(seat_data.name, valid_seat.name) then
				-- this is a valid seat
				local object_id, is_success = s.spawnCharacter(vehicle_position, valid_seat.outfit_id)
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
					d.print(("(Characters.setupVehicle) Successfully spawned character %i for seat %s on vehicle %i"):format(object_id, seat_data.name, vehicle_id), true, 0)
				end
			end
		end
	end

	return characters, true
end
 -- functions for characters, such as setting them into seats.
--[[


	Library Setup


]]

-- required libraries
-- This library is for the main objectives in Conquest Mode, such as getting the AI's island they want to attack.

--[[


	Library Setup


]]

-- required libraries
--[[


	Library Setup


]]
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

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Allows a library to easily bind to a callback, so it doesn't have to inject itself into each callback.
]]

-- library name
Binder = {
	bind = {}
}

--[[


	Classes


]]

-- onGroupSpawn
---@alias CallbackOnGroupSpawn fun(group_id: integer, peer_id: integer, x: number, y: number, z: number, group_cost: number)

-- onVehicleLoad
---@alias CallbackOnVehicleLoad fun(vehicle_id: integer)

-- onVehicleUnload
---@alias CallbackOnVehicleUnload fun(vehicle_id: integer)

-- onObjectLoad
---@alias CallbackOnObjectLoad fun(object_id: integer)

-- setupMain
---@alias CallbackSetupMain fun(is_world_create: boolean)

---@alias Callback
---| CallbackOnGroupSpawn
---| CallbackOnVehicleLoad
---| CallbackOnVehicleUnload
---| CallbackOnObjectLoad
---| CallbackSetupMain

---@class BindedCallback
---@field callback Callback the callback to call
---@field priority number the priority of the callback.

--[[


	Variables


]]

---@type table<string, table<integer, BindedCallback>>
binded_callbacks = {
	onGroupSpawn = {},
	onVehicleLoad = {},
	onVehicleUnload = {},
	onObjectLoad = {},
	setupMain = {}
}

--[[


	Functions


]]

---@param callback_name string the name of the callback to bind to.
---@param callback Callback the callback to bind to the callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first.
local function bindCallback(callback_name, callback, priority)

	-- default the priority to 0 if not specified.
	priority = priority or 0

	-- get the list of binds for this callback.
	local binds = binded_callbacks[callback_name]

	-- check if the list exists
	if not binds then
		-- print an error
		d.print(("The callback %s is not a valid callback."):format(callback_name), true, 1)
		return
	end

	-- define the index to insert the callback at.
	local insert_index = 1

	-- find the index to insert the callback at (sorted by priority, goes to behind an existing callback if they share the same priority.)
	for bind_index = 1, #binds do
		-- if the priority is higher than the current bind's priority, break.
		if binds[bind_index].priority > priority then
			break
		end

		-- otherwise, set insert index to above this one.
		insert_index = bind_index + 1
	end

	-- insert the callback at the insert index.
	table.insert(binds, insert_index, 
		{
			callback = callback,
			priority = priority
		}
	)
end

--[[

	onGroupSpawn

]]

--[[
	Inject.
]]

---@diagnostic disable-next-line: undefined-global
old_onGroupSpawn = onGroupSpawn

---@private
function onGroupSpawn(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onGroupSpawn

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onGroupSpawn then
		old_onGroupSpawn(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onGroupSpawn callback.
---@param callback CallbackOnGroupSpawn the callback to bind to the onGroupSpawn callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onGroupSpawn(callback, priority)
	bindCallback(
		"onGroupSpawn",
		callback,
		priority
	)
end

--[[

	onVehicleLoad

]]

--[[
	Inject.
]]

old_onVehicleLoad = onVehicleLoad

---@private
function onVehicleLoad(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onVehicleLoad

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onVehicleLoad then
		old_onVehicleLoad(...)
	end
end


--[[
	Create bind function
]]

--- Function for binding to a the onVehicleLoad callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the onVehicleLoad callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onVehicleLoad(callback, priority)
	bindCallback(
		"onVehicleLoad",
		callback,
		priority
	)
end

--[[

	onVehicleUnload

]]

--[[
	Inject.
]]

old_onVehicleUnload = onVehicleUnload

---@private
function onVehicleUnload(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onVehicleUnload

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onVehicleUnload then
		old_onVehicleUnload(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onVehicleUnload callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the onVehicleUnload callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onVehicleUnload(callback, priority)
	bindCallback(
		"onVehicleUnload",
		callback,
		priority
	)
end


--[[

	onObjectLoad

]]

--[[
	Inject.
]]

old_onObjectLoad = onObjectLoad

---@private
function onObjectLoad(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onObjectLoad

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onObjectLoad then
		old_onObjectLoad(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onObjectLoad callback.
---@param callback CallbackOnObjectLoad the callback to bind to the onObjectLoad callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onObjectLoad(callback, priority)
	bindCallback(
		"onObjectLoad",
		callback,
		priority
	)
end

--[[

	setupMain

]]

---@private
function bindedSetupMain(...)
	-- get the list of binds for this callback.
	local binds = binded_callbacks.setupMain

	-- check if the list exists
	if not binds then
		return
	end

	d.print(string.fromTable(binds))

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the setupMain callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the setupMain callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.setupMain(callback, priority)
	bindCallback(
		"setupMain",
		callback,
		priority
	)
end

-- library name
IslandRegistry = {}


--[[


	Classes


]]

---@class IslandRegistryData
---@field by_index table<integer, ISLAND>
---@field by_group_id table<integer, ISLAND>
---@field by_name table<string, ISLAND>
---@field by_faction table<FACTION, table<integer, ISLAND>>
---@field by_land_access table<string, table<integer, ISLAND>>

--[[


	Constants


]]

-- Put after the islands are initialized
ISLAND_REGISTRY_SETUP_MAIN_PRIORITY = ISLAND_SETUP_MAIN_PRIORITY + 1

--[[


	Variables


]]

--- @type IslandRegistryData
IslandRegistry.data = {
	by_index = {},
	by_group_id = {},
	by_name = {},
	by_faction = {},
	by_land_access = {}
}

--- @type boolean If the registry has been built
IslandRegistry.ready = false

--[[


	Functions


]]

--- Registers the island in the registry, allowing it to be looked by its index, flag vehicle group id, name, and faction.
--- Also adds the island to the island spatial grid for spatial queries involving islands.
--- @param island ISLAND
function IslandRegistry.registerIsland(island)
	if not island then
		return
	end

	IslandRegistry.data.by_index[island.index] = island

	if island.flag_vehicle and island.flag_vehicle.group_id then
		IslandRegistry.data.by_group_id[island.flag_vehicle.group_id] = island
	end

	IslandRegistry.data.by_name[string.friendly(island.name or "")] = island

	IslandRegistry.data.by_faction[island.faction] = IslandRegistry.data.by_faction[island.faction] or {}
	IslandRegistry.data.by_faction[island.faction][island.index] = island

	local land_access = Tags.getValue(island.tags, "land_access", true) or "none"
	IslandRegistry.data.by_land_access[land_access] = IslandRegistry.data.by_land_access[land_access] or {}
	IslandRegistry.data.by_land_access[land_access][island.index] = island

	-- Also register it in the spatial hash grid
	if not island_grid.frozen then
		---@diagnostic disable-next-line: param-type-mismatch
		SpatialGrid.add(island_grid, island.index, island.transform[13], island.transform[15])
	else
		d.print("(IslandRegistry.registerIsland) island_grid is frozen!", true, 1)
	end
end

--- Changes a islands faction
--- @param island ISLAND
--- @param new_faction FACTION
function IslandRegistry.setFaction(island, new_faction)
	if not island then
		return
	end

	if island.faction == new_faction then
		return
	end

	if IslandRegistry.data.by_faction[island.faction] then
		IslandRegistry.data.by_faction[island.faction][island.index] = nil
	end

	island.faction = new_faction

	IslandRegistry.data.by_faction[new_faction] = IslandRegistry.data.by_faction[new_faction] or {}
	IslandRegistry.data.by_faction[new_faction][island.index] = island
end

--- Rebuilds the entire registry from the island data in g_savedata
function IslandRegistry.rebuild()
	start_time = s.getTimeMillisec()
	IslandRegistry.data = {
		by_index = {},
		by_group_id = {},
		by_name = {},
		by_faction = {},
		by_land_access = {}
	}
	island_grid = SpatialGrid.new(island_grid.cell_size) -- Reset the grid

	if g_savedata.ai_base_island then
		IslandRegistry.registerIsland(g_savedata.ai_base_island)
	end

	if g_savedata.player_base_island then
		IslandRegistry.registerIsland(g_savedata.player_base_island)
	end

	for _, island in pairs(g_savedata.islands or {}) do
		IslandRegistry.registerIsland(island)
	end

	island_grid = island_grid:freeze()

	IslandRegistry.ready = true
end

--- If the registry hasn't been built yet, builds it. Otherwise does nothing
function IslandRegistry.ensureReady()
	if not IslandRegistry.ready then
		IslandRegistry.rebuild()
	end
end

--- @param group_id integer
--- @return ISLAND|nil island
function IslandRegistry.getByGroupID(group_id)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_group_id[group_id]
end

--- @param island_index integer
--- @return ISLAND|nil island
function IslandRegistry.getByIndex(island_index)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_index[island_index]
end

--- @param island_name string
--- @return ISLAND|nil island
function IslandRegistry.getByName(island_name)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_name[string.friendly(island_name or "")]
end

--- Returns a table of all islands controlled by a faction
--- Note: this returns a reference to the actual data. If you need to modify it, make a copy first
--- @param faction FACTION
--- @return table<integer, ISLAND>
function IslandRegistry.getFactionMap(faction)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_faction[faction] or {}
end

--- Returns a table of all islands with the specified land access
--- Note: this returns a reference to the actual data. If you need to modify it, make a copy first
--- @param land_access string
--- @return table<integer, ISLAND>
function IslandRegistry.getLandAccessMap(land_access)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_land_access[land_access] or {}
end

-- Bind rebuild to setupMain
Binder.bind.setupMain(IslandRegistry.rebuild, ISLAND_REGISTRY_SETUP_MAIN_PRIORITY)


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

---Gets the scout progress of an island, and safely returns 0 if there is no scout data for some reason
---Could probobly be moved to a island or scout library
---@param island_name string
---@return number scouted_amount
local function getScoutProgress(island_name)
	local scout_data = g_savedata.ai_knowledge.scout[island_name]
	if not scout_data then
		return 0
	end

	return scout_data.scouted or 0
end

---@param island ISLAND
---@param ignore_scouted boolean? true if you want to ignore islands that are already fully scouted
---@return boolean is_valid_target
local function isValidAttackTarget(island, ignore_scouted)
	if island.faction == ISLAND.FACTION.AI then
		return false
	end

	if ignore_scouted then
		if getScoutProgress(island.name) >= scout_requirement then
			return false
		end
	end

	return true
end

---@param origin_island ISLAND The island the attack would originate from
---@param target_island ISLAND The potential target island being evaluated
---@return number weighted_distance A score representing how desirable this target is, lower is more desirable
local function getAttackScore(origin_island, target_island)
	local distance = m.xzDistance(origin_island.transform, target_island.transform)

	if target_island.faction == ISLAND.FACTION.PLAYER then
		return distance / 1.5
	end

	return distance
end

---@param origin_island ISLAND The island the attack would originate from
---@param current_target ISLAND? The current best target found, or nil if none. Allows the function to be used in a loop to find the best target across multiple origins
---@param current_origin ISLAND? The origin of the current best target given. Only has an effect if current_target is not nil
---@param current_best_score number? The score of the current best target. Only has an effect if current_target is not nil
---@param ignore_scouted boolean? True if you want to ignore islands that are already fully scouted
---@return ISLAND? target_island
---@return ISLAND? origin_island
---@return number? best_score
local function selectBestTargetForOrigin(origin_island, current_target, current_origin, current_best_score, ignore_scouted)
	for _, island in pairs(g_savedata.islands) do
		if isValidAttackTarget(island, ignore_scouted) then
			local attack_score = getAttackScore(origin_island, island)
			if not current_target or attack_score < current_best_score then
				current_target = island
				current_origin = origin_island
				current_best_score = attack_score
			end
		end
	end

	return current_target, current_origin, current_best_score
end

---@param ignore_scouted boolean? true if you want to ignore islands that are already fully scouted
---@return ISLAND? target_island returns the island which the ai should target
---@return ISLAND? origin_island returns the island which the ai should attack from
function Objective.getIslandToAttack(ignore_scouted)
	local origin_island = nil
	local target_island = nil
	local target_best_distance = nil

	-- Pick the best target using all currently AI controlled islands as potential origins.
	local ai_islands = IslandRegistry.getFactionMap("ai")
	for _, ai_island in pairs(ai_islands) do
		target_island, origin_island, target_best_distance = selectBestTargetForOrigin(ai_island, target_island, origin_island, target_best_distance, ignore_scouted)
	end

	return target_island, origin_island
end	
--[[


	Library Setup


]]

-- required libraries

-- library name
Squad = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

---@class squadron
---@field index integer the index of this squadron
---@field command SQUAD_COMMAND the squadron's command
---@field vehicle_type VEHICLE_TYPE the vehicle type this squadron is made up of
---@field role string the role this squadron has
---@field vehicles table<integer, vehicle_object> the vehicles in this squadron
---@field target_island ISLAND? the island this squadron is targetting
---@field target_vehicles table<integer, TargetVehicle>|nil the vehicles this squadron is targetting
---@field target_players table<integer, TargetPlayer>|nil the players this squadron is targetting
---@field investigate_transform SWMatrix|nil the transform this squadron is investigating *(only set when command is INVESTIGATE)*

--[[


	Functions         


]]

---------------------------
--- Squad Lookups
---------------------------

--- given a group_id, returns the squad index its from and the squad's data. returns nil if not in a squad
--- @param group_id integer the id of the group you want to get the squad ID of
--- @return integer|nil squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
--- @return squadron|nil squad the info of the squad, if not found, then returns nil
function Squad.getSquadFromGroup(group_id)
	local squad_index = g_savedata.ai_army.squad_vehicles[group_id]
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

--- given a squad index, returns the squad's data. returns nil if not found
--- @param squad_index integer the index of the squad you want to get
--- @return squadron? squad the info of the squad, if not found, then returns nil
function Squad.getSquadFromIndex(squad_index)
	return g_savedata.ai_army.squadrons[squad_index]
end

---
---	@param group_id integer the group's id
---	@return vehicle_object? vehicle_object the vehicle object, nil if not found
---	@return integer? squad_index the index of the squad the vehicle is with, if the vehicle is invalid, then it returns nil
---	@return squadron? squad the info of the squad, if not found, then returns nil
function Squad.getVehicle(group_id) -- input a group's id, and it will return the vehicle_object, the squad index its from and the squad's data

	local vehicle_object = nil
	local squad_index = nil
	local squad = nil

	if not group_id then -- makes sure vehicle id was provided
		d.print("(Squad.getVehicle) group_id is nil!", true, 1)
		return vehicle_object, squad_index, squad
	else
		squad_index, squad = Squad.getSquadFromGroup(group_id)
	end

	if not squad_index or not squad then -- if we were not able to get a squad index then return nil
		return vehicle_object, squad_index, squad
	end

	vehicle_object = g_savedata.ai_army.squadrons[squad_index].vehicles[group_id]

	if not vehicle_object then
		d.print("(Squad.getVehicle) failed to get vehicle_object for group with id "..tostring(group_id).." and in a squad with the id of "..tostring(squad_index).." and with the vehicle_type of "..tostring(squad.vehicle_type), true, 1)
	end

	return vehicle_object, squad_index, squad
end

---------------------------
--- Squad Management
---------------------------

--- Creates a new squad based off a vehicle_object. **The vehicle will not be automatically added to the squad**, you must manually add it using `Squad.addVehicle`
--- @param squad_index integer? the squad's index which you want to create it under, if not specified it will use the next available index
--- @param vehicle_object vehicle_object the vehicle object which is adding to the squad
--- @return integer squad_index the index of the squad
--- @return boolean squad_created if the squad was successfully created
function Squad.create(squad_index, vehicle_object)

	local squad_index = squad_index or #g_savedata.ai_army.squadrons + 1

	if not vehicle_object then
		d.print("(Squad.create) vehicle_object is nil!", true, 1)
		return squad_index, false
	end

	if g_savedata.ai_army.squadrons[squad_index] then
		d.print("(Squad.create) Squadron "..tostring(squad_index).." already exists!", true, 1)
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

--- Returns the first vehicle in the squad returned by pairs to use as the leader of the squad
--- @param squad squadron
--- @return vehicle_object? vehicle_object nil if the squad is empty
function Squad.getLeader(squad)
	if not squad then
		d.print("(Squad.getLeader) squad is nil!", true, 1)
		return nil
	end

	for _, vehicle_object in pairs(squad.vehicles) do
		return vehicle_object
	end

	-- Squad is empty
	-- Do not try to "fix" by disbanding here, as this can get called while in the processing of creating a squad
	return nil
end

--- Adds a vehicle to the specified squad.
--- @param squad squadron the squad to add the vehicle to
--- @param vehicle_object vehicle_object the vehicle to add to the squad
--- @param force boolean? if you want to force the vehicle into the squad, bypassing the limits defined in `Squad.canJoinSquad`
--- @return boolean success if the addition was successful
function Squad.addVehicle(squad, vehicle_object, force)
	if not squad then
		d.print("(Squad.addVehicle) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.addVehicle) vehicle_object is nil!", true, 1)
		return false
	end
	
	-- Check if the vehicle can join the squad
	if not force and not Squad.canJoinSquad(squad, vehicle_object) then
		return false
	end

	-- Add the vehicle to the squad
	squad.vehicles[vehicle_object.group_id] = vehicle_object
	g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = squad.index

	-- Init the vehicle with the squads current command
	squadInitVehicleCommand(squad, vehicle_object)

	d.print("(Squad.addVehicle) Added vehicle "..tostring(vehicle_object.group_id).." ("..vehicle_object.vehicle_type..") to squad "..tostring(squad.index), true, 0)

	return true
end

--- Removes a vehicle from the specified squad. If this is the last vehicle in the squad, the squad will be automatically disbanded
--- @param squad squadron the squad to remove the vehicle from
--- @param vehicle_object vehicle_object the vehicle to remove from the squad
--- @param is_disbanding boolean? if the vehicle is being removed because the squad is being disbanded. This is used internally to prevent extra disband calls when disbanding
--- @return boolean success if the removal was successful
function Squad.removeVehicle(squad, vehicle_object, is_disbanding)
	if not squad then
		d.print("(Squad.removeVehicle) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.removeVehicle) vehicle_object is nil!", true, 1)
		return false
	end
	if not squad.vehicles or not squad.vehicles[vehicle_object.group_id] then
		d.print("(Squad.removeVehicle) vehicle "..tostring(vehicle_object.group_id).." is not in the specified squad!", true, 1)
		return false
	end

	squad.vehicles[vehicle_object.group_id] = nil

	if g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] == squad.index then
		-- Need to check because this might have already been overwritten if the vehicle is being transferred
		g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = nil
	end

	--? If:
	--? 1. The squad is now empty
	--? 2. The squad is not the resupply squad
	--? Then disband the squad
	if table.length(squad.vehicles) == 0 and squad.index ~= RESUPPLY_SQUAD_INDEX  and not is_disbanding then
		Squad.disband(squad.index, "squad empty")
	end

	d.print("(Squad.removeVehicle) Removed vehicle "..tostring(vehicle_object.group_id).." ("..vehicle_object.vehicle_type..") from squad "..tostring(squad.index), true, 0)
	return true
end

--- Safely disbands/deletes the specified squad
--- @param squad_index integer the squad you want to disband.
--- @param reason string? the reason for disbanding the squad. Doesn't affect the disbanding process at all, just used for debugging
--- @return boolean success if the disband was successful
function Squad.disband(squad_index, reason)
	-- Input Validation
	if type(squad_index) ~= "number" then
		d.print("(Squad.disband) squad_index expected number, got "..type(squad_index), true, 1)
		return false
	end
	if squad_index < 0 or squad_index == RESUPPLY_SQUAD_INDEX then
		d.print("(Squad.disband) squad_index out of bounds: "..tostring(squad_index), true, 1)
		return false
	end

	-- Get the squad to disband
	local squad = Squad.getSquadFromIndex(squad_index)
	if not squad then
		d.print("(Squad.disband) squad with index "..tostring(squad_index).." does not exist!", true, 1)
		return false
	end

	-- Remove all vehicles still inside the squad
	for _, vehicle_object in pairs(squad.vehicles) do
		Squad.removeVehicle(squad, vehicle_object, true)
	end

	-- Delete the squad from the squadrons table
	g_savedata.ai_army.squadrons[squad_index] = nil

	-- Remove all references to this squad from islands
	for island_index, island in pairs(g_savedata.islands) do
		if island.assigned_squad_index == squad_index then
			island.assigned_squad_index = -1
		end
	end

	d.print("(Squad.disband) Disbanded squad "..tostring(squad_index).." for reason: "..(reason or "Unknown"), true, 0)
	return true
end


--- Sets the command for a given squad if its allowed.<br>
--- The third parameter is optional and is used for setting extra variables required by the command. See the overloads at the bottom of the documentation for more information.<br>
--- ### Restrictions which will result in a failure:
--- - Attempting to set a squad to the same command it already has
--- - Attempting to change a scout squad to any command other than defend
--- - Attempting to change a cargo squad *(cargo vehicles are locked as cargo)*
--- @param squad squadron
--- @param command SQUAD_COMMAND
--- @vararg nil
--- @return boolean success if the command was successfully set. If false, then either the parameters are invalid or theres a restriction blocking it
--- @overload fun(squad:squadron, command:"attack"|"stage"|"defend"|"patrol", target_island: ISLAND):boolean
--- @overload fun(squad:squadron, command:"investigate", investigate_transform: SWMatrix):boolean
function Squad.setCommand(squad, command, ...)
	-- Input validation
	if not squad then
		d.print("(Squad.setCommand) squad is nil!", true, 1)
		return false
	end
	if not command then
		d.print("(Squad.setCommand) command is nil!", true, 1)
		return false
	end

	local old_command = squad.command
	if old_command == command then
		return false
	end

	-- Scouts can only be changed to defend
	if old_command == SQUAD.COMMAND.SCOUT and command ~= SQUAD.COMMAND.DEFEND then
		return false
	end

	-- Once in cargo mode, you can never leave it
	if old_command == SQUAD.COMMAND.CARGO then
		return false
	end

	-- The squad is able to be set to the new command
	-- Before setting the new command, first check for extra parameters for the command
	-- Check if theres anything in ...
	local extra_params = {...}
	if #extra_params > 0 then
		-- Decide what to do based on the command
		local COMMAND_PARAM_MAP = {
			[SQUAD.COMMAND.ATTACK] = "target_island",
			[SQUAD.COMMAND.STAGE] = "target_island",
			[SQUAD.COMMAND.DEFEND] = "target_island",
			[SQUAD.COMMAND.PATROL] = "target_island",
			[SQUAD.COMMAND.INVESTIGATE] = "investigate_transform"
		}
		if COMMAND_PARAM_MAP[command] then
			squad[COMMAND_PARAM_MAP[command]] = extra_params[1]
		else
			d.print("(Squad.setCommand) Unhandled extra parameter for command "..tostring(command), true, 1)
		end
	end

	-- Change the squad's command
	squad.command = command

	-- Reinit the squad's vehicles with the new command
	for _, vehicle_object in pairs(squad.vehicles) do
		squadInitVehicleCommand(squad, vehicle_object)
	end

	-- Squad value cleanup ported from the original setSquadronCommand function
	if command == SQUAD.COMMAND.NONE then
		squad.target_island = nil
	elseif command == SQUAD.COMMAND.INVESTIGATE then
		squad.target_players = {}
		squad.target_vehicles = {}
	end
	return true
end

--- Returns whether or not the squad can access a given island
--- @param squad squadron the squad to check
--- @param island ISLAND the island to check
--- @return boolean can_access whether or not the squad can access the island
--- @return boolean is_success whether or not the function executed successfully
function Squad.canAccessIsland(squad, island)
	-- Input validation
	if not squad then
		d.print("(Squad.canAccessIsland) squad is nil!", true, 1)
		return false, false
	end
	if not island then
		d.print("(Squad.canAccessIsland) island is nil!", true, 1)
		return false, false
	end

	if squad.vehicle_type == VEHICLE.TYPE.LAND then
		-- Land vehicles can only access islands they have land access to
		local squad_leader = Squad.getLeader(squad)
		if squad_leader then
			local island_land_access = Tags.getValue(island.tags, "land_access", true)
			local leader_land_access = Tags.getValue(squad_leader.home_island.tags, "land_access", true)
			if island_land_access ~= leader_land_access then
				return false, true
			end
		end
	elseif squad.vehicle_type == VEHICLE.TYPE.BOAT then
		-- Boat vehicles cant get to islands with no_access=boat tags
		if Tags.has(island.tags, "no_access=boat") then
			d.print("(Squad.canAccessIsland) Boat vehicle squad "..tostring(squad.index).." cannot access island "..island.name.." due to no_access=boat tag", true, 0)
			return false, true
		end
	end

	return true, true
end

--- Returns a full list of **AI controlled** islands that the squad can reach 
--- @param squad squadron
--- @param faction FACTION? the faction you want to filter by. If not specified, it will return all islands
function Squad.getReachableIslands(squad, faction)
	-- Input validation
	if not squad then
		d.print("(Squad.getReachableIslands) squad is nil!", true, 1)
		return {}
	end

	local reachable_islands = {}
	for _, island in pairs(g_savedata.islands) do
		if not faction or island.faction == faction then
			local can_access, success = Squad.canAccessIsland(squad, island)
			if success and can_access then
				table.insert(reachable_islands, island)
			end
		end
	end
	return reachable_islands
end

--- @param squad squadron
function Squad.getRandomReachableIsland(squad)
	local reachable_islands = Squad.getReachableIslands(squad, ISLAND.FACTION.AI)
	if #reachable_islands == 0 then
		return nil
	end
	return reachable_islands[math.random(1, #reachable_islands)]
end

---------------------------
--- Vehicle Helpers
---------------------------

--- Checks if a vehicle can join the specified squad
--- @param squad squadron the squad to check
--- @param vehicle_object vehicle_object the vehicle to check
function Squad.canJoinSquad(squad, vehicle_object)
	-- Input validation
	if not squad then
		d.print("(Squad.canJoinSquad) squad is nil!", true, 1)
		return false
	end
	if not vehicle_object then
		d.print("(Squad.canJoinSquad) vehicle_object is nil!", true, 1)
		return false
	end
	
	-- Must be of the same vehicle type
	if squad.vehicle_type ~= vehicle_object.vehicle_type then
		return false
	end
	
	-- Must be of the same role
	if squad.role ~= vehicle_object.role then
		return false
	end
	
	-- Land vehicles must be able be access eachother (ie, a vehicle in arid cant join a squad in sawyer)
	if squad.vehicle_type == VEHICLE.TYPE.LAND then
		-- Get the squad leader, if there is no squad leader then skip this check
		local squad_leader = Squad.getLeader(squad)
		if squad_leader then
			-- Get the land mass that the squad leader is on
			local leader_land_access = Tags.getValue(squad_leader.home_island.tags, "land_access", true)
			local vehicle_land_access = Tags.getValue(vehicle_object.home_island.tags, "land_access", true)
			if leader_land_access ~= vehicle_land_access then
				return false
			end
		end
	end
	
	-- Non scout vehicles cannot join scout squads
	if vehicle_object.role ~= "scout" and squad.role == "scout" then
		return false
	end

	-- Non cargo vehicles cannot join cargo squads
	if vehicle_object.role ~= "cargo" and squad.role == "cargo" then
		return false
	end

	-- Squad can not be full
	if table.length(squad.vehicles) >= MAX_SQUAD_SIZE then
		return false
	end
	return true
end

--- Moves a vehicle from its current squad to another squad
--- @param vehicle_object vehicle_object the vehicle to transfer
--- @param new_squad_index integer the index of the squad to transfer the vehicle to
--- @param force boolean? if you want to force the vehicle over to the squad, bypassing any limits
--- @return boolean success if the transfer was successful
function Squad.transferToSquad(vehicle_object, new_squad_index, force)
	-- Input validation
	if not vehicle_object then
		d.print("(Squad.transferToSquad) vehicle_object is nil!", true, 1)
		return false
	end
	if not new_squad_index then
		d.print("(Squad.transferToSquad) new_squad_index is nil!", true, 1)
		return false
	end

	-- Get its old squad
	local old_squad_index, old_squad = Squad.getSquadFromGroup(vehicle_object.group_id)
	if old_squad_index and old_squad then
		vehicle_object.previous_squad = old_squad_index
	else
		d.print("(Squad.transferToSquad) Warning: Could not get old squad", true, 0)
	end
	
	-- Check if the new squad exists
	local new_squad = Squad.getSquadFromIndex(new_squad_index)
	if not new_squad then
		-- Create the squad if it doesn't already exist
		new_squad_index = Squad.create(new_squad_index, vehicle_object)
		new_squad = Squad.getSquadFromIndex(new_squad_index)
		if not new_squad then
			d.print("(Squad.transferToSquad) failed to create new squad with index "..tostring(new_squad_index), true, 1)
			return false
		end
	end

	-- Add to the new squad
	local added = Squad.addVehicle(new_squad, vehicle_object, force)
	if added and old_squad ~= nil then
		-- Remove from the old squad if it was in one
		if not Squad.removeVehicle(old_squad, vehicle_object) then
			--! Something went wrong, to prevent it from being in multiple squads, remove it form the new one
			d.print("(Squad.transferToSquad) failed to remove vehicle from old squad "..tostring(old_squad_index).."! This should never happen!", true, 1)
			if not Squad.removeVehicle(new_squad, vehicle_object) then
				d.print("(Squad.transferToSquad) Failed to undo changes, possible vehicle duplication inside squads", true, 0)
			end
			return false
		end
	elseif not added then
		d.print("(Squad.transferToSquad) failed to add vehicle to new squad "..tostring(new_squad_index).."!", true, 1)
		return false
	end

	d.print("(Squad.transferToSquad) Transferred "..vehicle_object.name.."("..vehicle_object.group_id..") from squadron "..tostring(old_squad_index).." to "..new_squad_index, true, 0)
	return true
end

--- Returns the best squad for a vehicle to join.
--- The squad must be able to accept the vehicle, and it will only take the smallest squads into consideration.
--- After getting the smallest squads, it will return the closest one to the vehicle.
--- @param vehicle_object vehicle_object the vehicle you want to find a squad for
--- @return squadron? squad the best squad for the vehicle to join, nil if no valid squads were found
function Squad.getBestSquadForVehicle(vehicle_object)
	-- Gets the squads which can be joined and is the smallest in the world
	local canidates = {}
	local smallest_size = math.huge
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		if Squad.canJoinSquad(squad, vehicle_object) then
			if #squad.vehicles < smallest_size then
				smallest_size = #squad.vehicles
				canidates = {}
			end
			table.insert(canidates, squad)
		end
	end

	if #canidates <= 0 then
		return nil
	end

	-- Sort by distance to the vehicle
	local vehicle_transform = vehicle_object.transform
	table.sort(canidates, function(a, b)
		local a_leader = Squad.getLeader(a)
		local b_leader = Squad.getLeader(b)
		if not a_leader then return false end -- Force it to the end if invalid for some reason
		if not b_leader then return true end -- Force it to the end if invalid for some reason
		local a_distance = matrix.xzDistance(vehicle_transform, a_leader.transform)
		local b_distance = matrix.xzDistance(vehicle_transform, b_leader.transform)
		return a_distance < b_distance
	end)

	-- Return the closest canidate
	return canidates[1]
end
---@diagnostic disable: inject-field
-- required libraries


-- library name
Vehicle = {}

-- shortened library name
v = Vehicle

---@alias cost number

---@param vehicle_object vehicle_object the vehicle you want to get the speed of
---@param ignore_terrain_type ?boolean if false or nil, it will include the terrain type in speed, otherwise it will return the offroad speed (only applicable to land vehicles)
---@param ignore_aggressiveness ?boolean if false or nil, it will include the aggressiveness in speed, otherwise it will return the normal speed (only applicable to land vehicles)
---@param terrain_type_override ?string \"road" to override speed as always on road, "offroad" to override speed as always offroad, "bridge" to override the speed always on a bridge (only applicable to land vehicles)
---@param aggressiveness_override ?string \"normal" to override the speed as always normal, "aggressive" to override the speed as always aggressive (only applicable to land vehicles)
---@return number speed the speed of the vehicle, 0 if not found
---@return boolean got_speed if the speed was found
function Vehicle.getTargetSpeed(vehicle_object, ignore_terrain_type, ignore_aggressiveness, terrain_type_override, aggressiveness_override, ignore_convoy_modifier)
	if not vehicle_object then
		d.print("(Vehicle.getTargetSpeed) vehicle_object is nil!", true, 1)
		return 0, false
	end

	local _, squad = Squad.getSquadFromGroup(vehicle_object.group_id)

	if not squad then
		d.print("(Vehicle.getTargetSpeed) squad is nil! vehicle_id: "..tostring(vehicle_object.group_id), true, 1)
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
			local terrain_type

			if ignore_terrain_type then
				terrain_type = terrain_type_override or "ROAD"
			else
				terrain_type = v.getTerrainType(vehicle_object.transform)
			end
			
			local aggressive = aggressiveness_override or not ignore_aggressiveness and squad.command == SQUAD.COMMAND.ENGAGE
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

---@param group_id integer the group id of the vehicle
---@return prefab? prefab the prefab of the vehicle if it was created
---@return boolean was_created if the prefab was created
function Vehicle.createPrefab(group_id)
	if not group_id then
		d.print("(Vehicle.createPrefab) group_id is nil!", true, 1)
		return nil, false
	end

	-- get the main body id
	local vehicle_id = VehicleGroup.getMainVehicle(group_id)

	-- check if vehicle_id is nil
	if not vehicle_id then
		d.print(("(Vehicle.createPrefab) failed to get main body id! group_id: %s"):format(group_id), true, 1)
		return nil, false
	end

	local loaded_data, _ = safe_server.getVehicleComponents(vehicle_id)

	-- commented out cause we dont need the vehicle to be loaded to create the prefab, as we can make it partially if its not loaded.
	--[[if not got_loaded_data then
		d.print("(Vehicle.createPrefab) failed to get loaded vehicle data! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end]]

	local vehicle_object, _, _ = Squad.getVehicle(group_id)

	if not vehicle_object then
		d.print("(Vehicle.createPrefab) failed to get vehicle_object! group_id: "..tostring(group_id), true, 1)
		return nil, false
	end

	-- set the fully created variable
	fully_created = true

	-- if voxels is nil or 0, then set fully_created to false
	if not loaded_data.voxels or loaded_data.voxels == 0 then
		fully_created = false
	end

	-- if mass is nil or 0, then set fully_created to false
	if not loaded_data.mass or loaded_data.mass == 0 then
		fully_created = false
	end

	---@class prefab
	local prefab = {
		voxels = loaded_data.voxels,
		mass = loaded_data.mass,
		powertrain_types = v.getPowertrainTypes(vehicle_object),
		role = vehicle_object.role,
		vehicle_type = vehicle_object.vehicle_type,
		strategy = vehicle_object.strategy,
		fully_created = fully_created
	}

	g_savedata.prefabs[string.removePrefix(vehicle_object.name)] = prefab

	return prefab, true
end

---@param vehicle_name string the name of the vehicle
---@return prefab|nil prefab the prefab data of the vehicle
---@return boolean got_prefab if the prefab data was found
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
---@param just_check boolean? if you just want to check if the vehicle can be afforded, not actually buy it
---@return integer|nil cost the cost of the vehicle
---@return boolean|nil cost_existed if the cost has been calculated yet
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

	return total_spent, cost_existed, cost == 0 or fallback_type == 2 or fallback_type == 3, stat_multiplier
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
		return 0, false, false
	end

	vehicle_name = string.removePrefix(vehicle_name)

	local prefab, got_prefab = v.getPrefab(vehicle_name)

	if not got_prefab or not prefab then
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
---@return powertrain_types? powertrain_types the powertrain type(s) of the vehicle
---@return boolean got_powertrain_type if the powertrain type was found
function Vehicle.getPowertrainTypes(vehicle_object)

	if not vehicle_object then
		d.print("(Vehicle.getPowertrainType) vehicle_object is nil!", true, 1)
		return nil, false
	end

	-- get the vehicle's main body id
	local main_vehicle_id = VehicleGroup.getMainVehicle(vehicle_object.group_id)

	-- check if main_vehicle_id is nil
	if not main_vehicle_id then
		d.print("(Vehicle.getPowertrainType) failed to get main vehicle id! group_id: "..tostring(vehicle_object.group_id), true, 1)
		return nil, false
	end

	local _, got_vehicle_data = s.getVehicleData(main_vehicle_id)

	if not got_vehicle_data then
		d.print("(Vehicle.getPowertrainType) failed to get vehicle data! name: "..tostring(vehicle_object.name).."\nid: "..tostring(vehicle_object.group_id), true, 1)
		return nil, false
	end

	local _, is_jet = s.getVehicleTank(main_vehicle_id, "Jet 1")

	local _, is_diesel = s.getVehicleTank(main_vehicle_id, "Diesel 1")

	---@class powertrain_types
	local powertrain_types = {
		jet_fuel = is_jet,
		diesel = is_diesel,
		oil = (not is_jet and not is_diesel)
	}

	return powertrain_types, true	
end

---@param requested_prefab string|integer|nil vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string? the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean? if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island ISLAND? the island you want it to spawn at
---@param purchase_type integer? 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_object|string vehicle_object the vehicle's data if the the vehicle successfully spawned, otherwise its returns the error code
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
	
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		for _, vehicle_object in pairs(squad.vehicles) do
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
	
	local selected_prefabs = nil

	local spawnbox_index = nil -- turrets

	if vehicle_type == "turret" and specified_island then

		-----
		--* turret spawning
		-----

		local island = specified_island

		-- make sure theres turret spawns on this island
		if (not island.zones.turrets or #island.zones.turrets < 1) then
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

		selected_prefabs = sm.spawn(true, Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true), "turret")

		if not selected_prefabs then
			return false, "was unable to get a turret prefab! turret_type of turret spawn zone: "..tostring(Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true))
		end

	elseif requested_prefab then
		-- *spawning specified vehicle
		d.print(("(Vehicle.spawn is_specified: true, requested_prefab: %s, vehicle_type: %s)"):format(tostring(requested_prefab), tostring(vehicle_type)))
		selected_prefabs = sm.spawn(true, requested_prefab, vehicle_type)
	else
		-- *spawn random vehicle
		selected_prefabs = sm.spawn(false, requested_prefab, vehicle_type)
	end

	if not selected_prefabs then
		d.print("(Vehicle.spawn) Unable to spawn AI vehicle! (prefab not recieved)", true, 1)
		return false, "returned vehicle was nil, prefab "..(requested_prefab and "was" or "was not").." selected"
	end

	--local selected_prefab = selected_prefabs.variations.normal[1]

	-- find a temporary vehicle as we dont know what variation to spawn yet
	local selected_prefab
	for _, prefab_data in pairs(selected_prefabs.variations) do
		selected_prefab = prefab_data[1]
		break
	end

	d.print("(Vehicle.spawn) selected vehicle: "..selected_prefab.location_data.name, true, 0)

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
				if Island.canSpawnPrefab(island, selected_prefab) and (selected_spawn_transform == nil or m.xzDistance(target.transform, island.transform) < m.xzDistance(target.transform, selected_spawn_transform)) then
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
				if Island.canSpawnPrefab(island, selected_prefab) then
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
				for _, player_transform in pairs(g_savedata.ai_knowledge.last_seen_positions) do
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
						for _, player_island in pairs(g_savedata.islands) do
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
				if Island.canSpawnPrefab(island, selected_prefab) then
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
			if Island.canSpawnPrefab(specified_island, selected_prefab) then
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

	-- find the variation of the vehicle we want.

	selected_prefab = selected_prefabs.variations.normal

	for variation_pattern, prefab_data in pairs(selected_prefabs.variations) do
		if variation_pattern ~= "normal" and server.getTile(island.transform).name:match(variation_pattern) then
			selected_prefab = prefab_data
			break
		end
	end

	if not selected_prefab then
		d.print(("Failed to get a variation of the %s to spawn at the island of %s"):format(selected_prefabs.name, island.name))
		return false, ("Failed to get a variation of the %s to spawn at the island of %s"):format(selected_prefabs.name, island.name)
	end

	selected_prefab = selected_prefab[math.random(1, #selected_prefab)]

	local spawn_transform = selected_spawn_transform
	if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") then
		if not island then
			return false, "unable to find island to spawn sea vehicle at!"
		end
		if not island.zones.sea or #island.zones.sea == 0 then
			d.print("(Vehicle.spawn) island has no sea spawn zones but says it can spawn sea vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no sea spawn zones"
		end

		spawn_transform = island.zones.sea[math.random(1, #island.zones.sea)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") then
		if not island.zones.land or #island.zones.land == 0 then
			d.print("(Vehicle.spawn) island has no land spawn zones but says it can spawn land vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no land spawn zones"
		end

		spawn_transform = island.zones.land[math.random(1, #island.zones.land)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_turret") then
		local turret_count = 0
		local unoccupied_zones = {}

		if not island.zones.turrets or #island.zones.turrets == 0 then
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
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if m.distance(spawn_transform, vehicle_object.transform) < (Tags.getValue(selected_prefab.vehicle.tags, "spawning_radius") or DEFAULT_SPAWNING_DISTANCE + vehicle_object.spawning_transform.distance) then
				return false, "spawn location was too close to vehicle "..vehicle_id
			end
		end
	end

	d.print("(Vehicle.spawn) calculating cost of vehicle... (purchase type: "..tostring(purchase_type)..")", true, 0)
	-- check if we can afford the vehicle
	local cost, cost_existed, was_purchased, stats_multiplier = v.purchaseVehicle(string.removePrefix(selected_prefab.location_data.name), island.name, purchase_type, true)

	d.print("(Vehicle.spawn) cost: "..tostring(cost).." Purchase Type: "..purchase_type, true, 0)

	if not was_purchased then
		return false, "was unable to afford vehicle"
	end

	-- spawn objects

	local addon_index = selected_prefab.addon_index

	local spawned_objects = {
		spawned_vehicle = su.spawnObject(spawn_transform, addon_index, selected_prefab.location_index, selected_prefab.vehicle, 0, nil, {}),
		fires = su.spawnObjects(spawn_transform, addon_index, selected_prefab.location_index, selected_prefab.fires, {})
	}

	d.print("(Vehicle.spawn) setting up enemy vehicle: "..selected_prefab.location_data.name, true, 0)

	if spawned_objects.spawned_vehicle ~= nil then

		local home_x, home_y, home_z = m.position(spawn_transform)

		d.print("(Vehicle.spawn) setting vehicle data...", true, 0)
		--d.print("selected_spawn: "..selected_spawn, true, 0)

		---@class vehicle_object
		local vehicle_data = {
			---@type integer
			group_id = spawned_objects.spawned_vehicle.id,
			name = selected_prefab.location_data.name,
			home_island = g_savedata.islands[selected_spawn] or g_savedata.ai_base_island,
			survivors = {},
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
			ui_id = server.getMapID() --[[@as SWUI_ID]],
			vehicle_type = spawned_objects.spawned_vehicle.vehicle_type,
			variation = Tags.getValue(selected_prefab.vehicle.tags, "variation", true) or "normal" --[[@as string]],
			role = Tags.getValue(selected_prefab.vehicle.tags, "role", true) or "general" --[[@as string]],
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
				radius = (Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or 500) * stats_multiplier,
				base_radius = (Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or 500) * stats_multiplier,
				is_radar = Tags.has(selected_prefab.vehicle.tags, "radar") and stats_multiplier >= 0.8,
				is_sonar = Tags.has(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = Tags.getValue(selected_prefab.vehicle.tags, "spawning_radius") or DEFAULT_SPAWNING_DISTANCE
			},
			speed = {
				speed = Tags.getValue(selected_prefab.vehicle.tags, "speed") or 0,
				convoy_modifier = 0
			},
			driving = { -- used for driving the vehicle itself, holds special data depending on the vehicle type
				ui_id = s.getMapID()
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
			---@type string?
			terrain_type = nil,
			is_killed = false,
			just_strafed = true, -- used for fighter jet strafing
			---@type string
			strategy = Tags.getValue(selected_prefab.vehicle.tags, "strategy", true) --[[@as string]] or "general",
			sink_depth = Tags.getValue(selected_prefab.vehicle.tags, "sink_depth") or explosion_depths[spawned_objects.spawned_vehicle.vehicle_type] or -4,
			can_offroad = Tags.has(selected_prefab.vehicle.tags, "can_offroad"),
			is_resupply_on_load = false,
			transform = spawn_transform --[[@as SWMatrix]],
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

		-- Add to a squad
		local squad = Squad.getBestSquadForVehicle(vehicle_data)
		if squad then
			d.print("(Vehicle.spawn) adding vehicle to existing squad: "..squad.index, true, 0)
			Squad.addVehicle(squad, vehicle_data)
		else
			d.print("(Vehicle.spawn) no valid squad found, will create a new squad for vehicle", true, 0)
			local new_squad_index, squad_created = Squad.create(nil, vehicle_data)
			squad = Squad.getSquadFromIndex(new_squad_index)
			if not squad or not squad_created then
				d.print("(Vehicle.spawn) failed to create new squad for vehicle!", true, 1)
				return false, "failed to create new squad for vehicle"
			end
			Squad.addVehicle(squad, vehicle_data)
		end

		-- Set special vehicle commands based on vehicle role
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			Squad.setCommand(squad, SQUAD.COMMAND.SCOUT)
		elseif Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) == "wep_turret" then
			Squad.setCommand(squad, SQUAD.COMMAND.TURRET)

			-- set the zone it spawned at to say that a turret was spawned there
			if g_savedata.islands[selected_spawn] then -- set at their island
				g_savedata.islands[selected_spawn].zones.turrets[spawnbox_index].is_spawned = true
			else -- they spawned at their main base
				g_savedata.ai_base_island.zones.turrets[spawnbox_index].is_spawned = true
			end

		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "cargo" then
			Squad.setCommand(squad, SQUAD.COMMAND.CARGO)
		end

		local prefab, got_prefab = v.getPrefab(selected_prefab.location_data.name)

		if not got_prefab then
			v.createPrefab(spawned_objects.spawned_vehicle.id)
		end

		if cost_existed then
			local _, _, was_purchased = v.purchaseVehicle(string.removePrefix(selected_prefab.location_data.name), (g_savedata.islands[selected_spawn].name or g_savedata.ai_base_island.name), purchase_type)
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
---@param vehicle_type string? the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean? if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island ISLAND? the island you want it to spawn at
---@param purchase_type integer? the way you want to purchase the vehicle 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@param retry_count integer how many times to retry spawning the vehicle if it fails
---@return boolean|nil spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_object|nil vehicle_object the vehicle's data if the the vehicle successfully spawned, otherwise its nil
function Vehicle.spawnRetry(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type, retry_count)
	local spawned = nil
	local vehicle_object = nil
	d.print("(Vehicle.spawnRetry) attempting to spawn vehicle...", true, 0)
	for i = 1, retry_count do
		spawned, vehicle_object = v.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
		if spawned and type(vehicle_object) ~= "string" then
			return spawned, vehicle_object
		else
			d.print("(Vehicle.spawnRetry) Spawning failed, retrying ("..retry_count-i.." attempts remaining)\nError: "..vehicle_object, true, 1)
		end
	end
end

-- teleports a vehicle and all of the characters attached to the vehicle to avoid the characters being left behind
---@param group_id integer the id of the vehicle which to teleport
---@param transform SWMatrix where to teleport the vehicle and characters to
---@return boolean is_success if it successfully teleported all of the vehicles and characters
function Vehicle.teleport(group_id, transform)

	-- make sure vehicle_id is not nil
	if not group_id then
		d.print("(Vehicle.teleport) vehicle_id is nil!", true, 1)
		return false
	end

	-- make sure transform is not nil
	if not transform then
		d.print("(Vehicle.teleport) transform is nil!", true, 1)
		return false
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)

	local none_failed = true

	if not vehicle_object then
		d.print(("(Vehicle.teleport) failed to get vehicle_object! vehicle_id: %s returned squad_index: %s"):format(group_id, squad_index), true, 1)
		return false
	end

	-- set char pos
	for _, object_id in ipairs(vehicle_object.survivors) do
		local is_success = s.setObjectPos(object_id, transform)
		if not is_success then
			d.print("(Vehicle.teleport) failed to set character position! char.id: "..object_id, true, 1)
			none_failed = false
		end
	end

	-- set vehicle pos
	local is_success = s.setGroupPos(group_id, transform)

	if not is_success then
		d.print("(Vehicle.teleport) failed to set vehicle position! vehicle_id: "..group_id, true, 1)
		none_failed = false
	end

	return none_failed
end

---@param vehicle_object vehicle_object the vehicle object you want to kill
---@param kill_instantly boolean? if you want to kill the vehicle instantly, if not, it will despawn it when the vehicle is unloaded, or takes enough damage to explode
---@param force_kill boolean? if you want to forcibly kill the vehicle, if so, it will go without explosions, and will not affect the spawn modifiers. Used for things like ?impwep dv
---@return boolean is_success if it was able to successfully kill the vehicle
function Vehicle.kill(vehicle_object, kill_instantly, force_kill)
	local debug_prefix = "(Vehicle.kill) "

	-- default to false if not specified.
	kill_instantly = kill_instantly ~= nil and kill_instantly or false

	local _, squad_index, squad = Squad.getVehicle(vehicle_object.group_id)

	if not squad then
		d.print(debug_prefix.."Failed to find the squad for group "..tostring(vehicle_object.group_id), true, 1)
		return false
	end

	if not squad_index then
		d.print(debug_prefix.."Failed to get the squad_index for group "..tostring(vehicle_object.group_id), true, 1)
		return false
	end

	if not vehicle_object then
		d.print(debug_prefix.."Failed to get the vehicle_object for group "..tostring(vehicle_object.group_id), true, 1)
		return false
	end

	--[[if vehicle_object.is_killed ~= true and not kill_instantly then
		d.print(debug_prefix.."Vehicle "..tostring(vehicle_id).." is already killed!", true, 1)
		return false
	end]]

	d.print(debug_prefix..vehicle_object.group_id.." from squad "..squad_index.." is out of action", true, 0)

	-- set the vehicle to say its been killed, and set its death_timer to 0.
	vehicle_object.is_killed = true
	vehicle_object.death_timer = 0

	-- clean the cargo vehicle if it is one
	Cargo.clean(vehicle_object.group_id)

	-- if it is a scout vehicle, we want to reset its scouting progress on whatever island it was on
	-- as it lost all of the data as it was killed.
	if vehicle_object.role == "scout" then
		local target_island, _ = Objective.getIslandToAttack(true)
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
					vehicle_object.role, math.clamp(ai_reward_ratio, 1, 2),
					vehicle_object.vehicle_type, math.clamp(ai_reward_ratio, 1, 3), 
					vehicle_object.strategy, math.clamp(ai_reward_ratio, 1, 2), 
					constructable_vehicle_id, math.clamp(ai_reward_ratio, 1, 3)
				)
			else -- if the ai did less damage than the damage it took / 3
				local ai_punish_ratio = (ai_damaged * 0.3333)//ai_damage_dealt
				sm.train(
					PUNISH, 
					vehicle_object.role, math.clamp(ai_punish_ratio, 1, 2),
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
		local is_success = s.despawnVehicleGroup(vehicle_object.group_id, kill_instantly)

		-- despawning failed, panic as maybe we were given the vehicle_id instead.
		if not is_success then
			-- usually not good to use this function, but its used here as a fallback
			local vehicle_data, is_success = server.getVehicleData(vehicle_object.group_id)

			-- if even getting vehicle data failed, panic even more - try to see if we can find an associated group_id.
			if not is_success then
				local actual_group_id = g_savedata.libraries.vehicle_group.translations[vehicle_object.group_id]

				-- if even this failed, just give up.
				if actual_group_id then
					-- try this one instead
					server.despawnVehicleGroup(vehicle_object.group_id, kill_instantly)
				end
			else
				-- we could get vehicle_data, so use the group_id from the vehicle_data
				server.despawnVehicleGroup(vehicle_data.group_id, kill_instantly)
			end
		end
		-- despawn all of the enemy AI NPCs
		for _, object_id in pairs(vehicle_object.survivors) do
			s.despawnObject(object_id, kill_instantly)
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

Command.registerCommand(
	"killvehicle",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg string[] the arguments of the command.
	function(full_message, peer_id, arg)
		group_id = tonumber(arg[1])
		if group_id == nil then
			d.print("(Command.killvehicle) invalid vehicle id given: "..tostring(arg[1]), false, 0, peer_id)
			return
		end
		targetVehicle = Squad.getVehicle(group_id)
		if targetVehicle == nil then
			d.print("(Command.killvehicle) failed to get vehicle with id: "..tostring(arg[1]), false, 0, peer_id)
			return
		end
		-- Optional arguments
		local kill_instantly = false
		if arg[2] ~= nil then
			local lowered_arg = string.lower(arg[2])
			kill_instantly = lowered_arg == "true"
			if lowered_arg ~= "true" and lowered_arg ~= "false" then
				d.print("(Command.killvehicle) Invalid kill_instantly argument: "..tostring(arg[2])..". Valid values are \"true\" or \"false\".", false, 0, peer_id)
				return
			end
		end
		local force_kill = false
		if arg[3] ~= nil then
			local lowered_arg = string.lower(arg[3])
			force_kill = lowered_arg == "true"
			if lowered_arg ~= "true" and lowered_arg ~= "false" then
				d.print("(Command.killvehicle) Invalid force_kill argument: "..tostring(arg[3])..". Valid values are \"true\" or \"false\".", false, 0, peer_id)
				return
			end
		end


		Vehicle.kill(targetVehicle, kill_instantly, force_kill)
	end,
	"admin",
	"Marks a AI vehicle as killed, eventually despawning it. Used primarly for debugging, you may want to use despawnvehicle insteaed.",
	"Marks a AI vehicle as killed, Use 'true' to enable the second and third argument",
	{""},
	"(group_id) kill_instantly? force_kill?"
)

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

---@class ICMRouteSegment
---@field island_index integer the index of the island to travel to
---@field transport_method PREFAB_DATA|{name: string, movement_speed: number} the vehicle prefab to use for transport
---@field transport_type "heli"|"land"|"plane"|"sea" the type of transport



--[[


	Functions         


]]

--- @param group_id integer the vehicle's id you want to clean
function Cargo.clean(group_id) -- cleans the data on the cargo vehicle if it exists
	-- check if it is a cargo vehicle
	for cargo_vehicle_index, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
		d.print("cargo vehicle group id: "..cargo_vehicle.vehicle_data.group_id.."\nRequested id: "..group_id, true, 0)
		if cargo_vehicle.vehicle_data.group_id == group_id then
			d.print("cleaning cargo vehicle", true, 0)

			--* remove the search area from the map
			s.removeMapID(-1, cargo_vehicle.search_area.ui_id)
			g_savedata.cargo_vehicles[group_id] = nil

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
			local squad_index, squad = Squad.getSquadFromGroup(group_id)
			if squad_index and squad then
				-- Can't use Squad.setCommand as it doesn't allow removing the CARGO command
				g_savedata.ai_army.squadrons[squad_index].command = SQUAD.COMMAND.NONE
			end

			-- check if theres a convoy waiting for this convoy
			-- if there is, delete it to avoid a softlock
			if g_savedata.cargo_vehicles[cargo_vehicle_index+1] then
				if g_savedata.cargo_vehicles[cargo_vehicle_index+1].route_status == 3 then
					d.print("(Cargo.clean) convoy vehicle "..tostring(g_savedata.cargo_vehicles[cargo_vehicle_index+1].vehicle_data.group_id).." was waiting for vehicle "..tostring(group_id)..", removing to prevent deadlock.", true, 1)
					local squad_index, squad = Squad.getSquadFromGroup(g_savedata.cargo_vehicles[cargo_vehicle_index+1].vehicle_data.group_id)

					if squad_index then
						v.kill(g_savedata.cargo_vehicles[cargo_vehicle_index+1].vehicle_data, true, true)
					else
						d.print("(Cargo.clean) removal failed, squad_index was nil!", true, 1)
					end
				end
			end


			return
		end
	end

	-- check if its a convoy vehicle
	for _, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
		for convoy_index, convoy_vehicle_id in ipairs(cargo_vehicle.convoy) do
			if group_id == convoy_vehicle_id then
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
	g_savedata.cargo_vehicles[cargo_vehicle.group_id].convoy[1 + math.floor(#possible_escorts/2)] = cargo_vehicle.group_id

	for escort_index, escort in ipairs(possible_escorts) do
		local squad_index, _ = Squad.getSquadFromGroup(cargo_vehicle.group_id)

		if squad_index then
			Squad.transferToSquad(escort, squad_index, true)
			p.resetPath(escort)
			if cargo_vehicle.transform then
				p.addPath(escort, cargo_vehicle.transform)
			else
				d.print("(Cargo.getEscorts) cargo_vehicle.transform is nil!", true, 0)
			end

			-- insert the escorts into the table for the convoy
			if not math.isWhole(escort_index/2) then 
				--* put this vehicle at the front as its index is odd
				g_savedata.cargo_vehicles[cargo_vehicle.group_id].convoy[1 + math.floor(#possible_escorts/2) + math.ceil(escort_index/2)] = escort.group_id
			else
				--* put this vehicle at the back as index is even
				g_savedata.cargo_vehicles[cargo_vehicle.group_id].convoy[(1 + math.floor(#possible_escorts/2)) - math.ceil(escort_index/2)] = escort.group_id
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
	speed_weight = v.getTargetSpeed(cargo_vehicle) - v.getTargetSpeed(escort_vehicle)
	
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

--- Adds up the total amount of cargo a vehicle has in its tanks
--- @param group_id number the group's id
--- @return requestedCargo? cargo the contents of the cargo vehicle's tanks
--- @return boolean got_tanks wether or not we were able to get the tanks
function Cargo.getTank(group_id)

	if not group_id then
		d.print("(Cargo.getTank) vehicle_id is nil!", true, 0)
		return nil, false
	end

	if not g_savedata.cargo_vehicles[group_id] then
		d.print("(Cargo.getTank) "..group_id.." is not a cargo vehicle!", true, 0)
		return nil, false
	end

	---@type requestedCargo
	local cargo = {
		[1] = {
			cargo_type = g_savedata.cargo_vehicles[group_id].requested_cargo[1].cargo_type,
			amount = 0
		},
		[2] = {
			cargo_type = g_savedata.cargo_vehicles[group_id].requested_cargo[2].cargo_type,
			amount = 0
		},
		[3] = {
			cargo_type = g_savedata.cargo_vehicles[group_id].requested_cargo[3].cargo_type,
			amount = 0
		}
	}

	local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)

	if not vehicle_object then
		d.print("(Cargo.getTank) vehicle_object is nil!", true, 0)
		return cargo, false
	end

	local large_tank_capacity = 703.125

	local cargo_tanks_per_set = vehicle_object.cargo.capacity/large_tank_capacity

	--d.print("(Cargo.getTank) cargo_tanks_per_set: "..tonumber(cargo_tanks_per_set), true, 0)

	local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

	-- ensure we got the main_vehicle_id
	if not main_vehicle_id then
		d.print("(Cargo.getTank) main_vehicle_id is nil", true, 1)
		return cargo, false
	end

	for tank_set=0, 2 do
		for tank_index=0, cargo_tanks_per_set-1 do

			local tank_data, got_data = s.getVehicleTank(main_vehicle_id, "RESOURCE_TYPE_"..tank_set.."_"..tank_index)

			if got_data then
				if tank_data.value > 0 then
					cargo[tank_set + 1].amount = cargo[tank_set + 1].amount + tank_data.value
					--[[d.print(("(Cargo.getTank) Got Tank. tank_set: %i tank_index: %i amount in tank: %s"):format(tank_set, tank_index, tank_data.value), true, 0)
				else
					d.print("(Cargo.getTank) Tank is empty.\ntank_set: "..tank_set.." tank_index: "..tank_index, true, 1)]]
				end
			else
				d.print("(Cargo.getTank) Error getting tank data for "..main_vehicle_id.." Tank set: "..tank_set.." Tank index: "..tank_index, true, 1)
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

---@param recipient vehicle_object|ISLAND the island or vehicle object thats getting the cargo
---@param sender vehicle_object|ISLAND the island or vehicle object thats sending the cargo
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

		-- get the sender's main vehicle id
		local main_vehicle_id = VehicleGroup.getMainVehicle(sender.group_id)

		-- Ensure the main_vehicle_id is valid.
		if not main_vehicle_id then
			d.print(("(Cargo.transfer) failed to get main_vehicle_id for sender (group_id: %s), returned main_vehicle_id is nil!"):format(sender.group_id), true, 1)
			return false, "error"
		end

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
					local set_cargo, error_message = Cargo.setTank(main_vehicle_id, "RESOURCE_TYPE_"..(slot-1).."_"..(i-1), cargo.cargo_type, -cargo.amount/sender.cargo.capacity, false)
					if not set_cargo then
						d.print("(Cargo.transfer s) error setting tank: "..error_message, true, 1)
					end
					Cargo.setKeypad(main_vehicle_id, "RESOURCE_TYPE_"..(slot-1), cargo.cargo_type)
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

		-- get the recipient's main vehicle id
		local main_vehicle_id = VehicleGroup.getMainVehicle(recipient.group_id)

		-- Ensure the main_vehicle_id is valid.
		if not main_vehicle_id then
			d.print(("(Cargo.transfer) failed to get main_vehicle_id for recipient (group_id: %s), returned main_vehicle_id is nil!"):format(recipient.group_id), true, 1)
			return false, "error"
		end

		local recipient, _, _ = Squad.getVehicle(recipient.group_id)

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
					local set_cargo, error_message = Cargo.setTank(main_vehicle_id, "RESOURCE_TYPE_"..(slot-1).."_"..(i-1), cargo.cargo_type, cargo.amount/(recipient.cargo.capacity/large_tank_capacity))
					--d.print("(Cargo.transfer r) amount: "..(cargo.amount/(recipient.cargo.capacity/large_tank_capacity)), true, 0)
					if not set_cargo then
						d.print("(Cargo.transfer) error setting tank: "..error_message, true, 1)
					end
					Cargo.setKeypad(main_vehicle_id, "RESOURCE_TYPE_"..(slot-1), cargo.cargo_type)
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
---@param natural_production number? the natural production of this island
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

---@return ISLAND island the island thats best to resupply
---@return ICMResupplyWeights weight the weights of all of the cargo types for the resupply island
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
---@return ICMResupplyWeights weights the weights of all of the cargo types for the resupply island
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

---@param island ISLAND the island you want to get the resupplier weight of
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


---@param cargo_weight ICMResupplyWeights the weight for the cargo trip
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
---@return ICMRouteSegment[] best_route the best route to go from the origin to the destination
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
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.heli = {
			name = "none"
		}
	elseif not transport_vehicle.heli.name then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.heli = {
			name = "unknown"
		}
	end
	if not transport_vehicle.land then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.land = {
			name = "none"
		}
	elseif not transport_vehicle.land.name then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.land = {
			name = "unknown"
		}
	end
	if not transport_vehicle.plane then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.plane = {
			name = "none"
		}
	elseif not transport_vehicle.plane.name then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.plane = {
			name = "unknown"
		}
	end
	if not transport_vehicle.sea then
		---@diagnostic disable-next-line: missing-fields
		transport_vehicle.sea = {
			name = "none"
		}
	elseif not transport_vehicle.sea.name then
		---@diagnostic disable-next-line: missing-fields
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

			if first_route_time > best_route_time or not first_route.island_index then
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

					if second_route_time + first_route_time > best_route_time or not second_route.island_index then
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

							if third_route_time + second_route_time + first_route_time > best_route_time or not third_route.island_index then
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

---@param island1 ISLAND the first island you want to get the distance from
---@param island2 ISLAND the second island you want to get the distance to
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

-- Define commands related to cargo
Command.registerCommand(
	"resetcargo",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local was_reset, error = Cargo.reset(is.getDataFromName(arg[1]), string.friendly(arg[2]))
        if was_reset then
            d.print("Reset the cargo storages for all islands", false, 0, peer_id)
        else
            d.print("Cargo failed to reset! error: "..error, false, 1, peer_id)
        end
	end,
	"admin",
	"resets the all island cargo storages to 0 for each resource, leave island blank for all islands, leave cargo_type blank for all resources",
	"resets the ai's cargo storages",
	{"", "North_Harbour", "Garrison_Toddy oil"},
	"[island] [cargo_type]"
)

-- Queue convoy command
Command.registerCommand(
	"queueconvoy",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		g_savedata.tick_extensions.cargo_vehicle_spawn = RULES.LOGISTICS.CARGO.VEHICLES.spawn_time - g_savedata.tick_counter - 1
		d.print("Updated convoy tick extension so a convoy will spawn when possible.", false, 0, peer_id)
	end,
	"admin",
	"queues a convoy to be sent out, will be sent out once theres not any convoys",
	"queues a convoy",
	{""}
)

Command.registerCommand(
	"convoycooldown",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		local rate = RULES.LOGISTICS.CARGO.VEHICLES.spawn_time
		local offset = g_savedata.tick_extensions.cargo_vehicle_spawn or 0
		local ticks_remaining = (rate - ((g_savedata.tick_counter + offset) % rate)) % rate
		local time_remaining = ticks_remaining / time.second
		if time_remaining > 60 then
			time_remaining = ticks_remaining / time.minute
			d.print("Current convoy cooldown: "..math.ceil(time_remaining).." minutes", false, 0, peer_id)
		else
			d.print("Current convoy cooldown: "..math.ceil(time_remaining).." seconds", false, 0, peer_id)
		end
	end,
	"admin",
	"Prints the time remaining until the next convoy can be sent out",
	"prints the current convoy cooldown",
	{""}
)

Command.registerCommand(
	"debugcargo1",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("asking cargo to do things...(get island distance)", false, 0, peer_id)
        for island_index, island in pairs(g_savedata.islands) do
            if island.faction == ISLAND.FACTION.AI then
                Cargo.getIslandDistance(g_savedata.ai_base_island, island)
            end
        end
	end,
	"admin",
	"Debugging command which has Cargo calculate the distance for every island from the AI base",
	"Debugging command for cargo distance calculations",
	{""}
)

Command.registerCommand(
	"debugcargo2",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print("asking cargo to do things...(get best route)", false, 0, peer_id)
		if arg[1] == nil then
			d.print("Missing island id argument!", false, 0, peer_id)
			return
		end
		if tonumber(arg[1]) == nil then
			d.print("Island ID must be a number!", false, 0, peer_id)
			return
		end
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
	end,
	"admin",
	"Runs Cargo.getBestRoute for the given island id and prints the calculated route",
	"Prints the best cargo route from the AI base to the given island id",
	{""}
)
 -- functions relating to the Convoys and Cargo Vehicles -- functions for the main objectives. -- functions relating to the Adaptive AI -- functions for squads -- functions relating to islands
--[[
	
Copyright 2024 Liam Matthews

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

CapturePointPayments = {}

local payroll_oversleeping_messages = {
	"I'm not paying for your sleeping expenses!",
	"Never heard of using sleeping as a defence before. Neither will your payroll.",
	"The beds are there to fill either patients or the enemies with, not yourself.",
	"Why save lives when you can sleep more than 12 hours a day? To get your payroll, of course."
}

local payroll_payout_messages = {
	"Great job holding the points, I've sent your payroll of $${payout}.",
	"Good work, your payroll of $${payout} has been sent.",
	"Keep up the good work, I've sent you $${payout} for your efforts."
}

---@param game_ticks number the game_ticks given by onTick()
function CapturePointPayments.tick(game_ticks)
	if not g_savedata.settings.CAPTURE_POINT_PAYMENTS then
		return
	end

	CapturePointPayments.incrementSleepTracker(game_ticks)

	local current_date = CapturePointPayments.getDate()

	-- check if its time to do the payroll
	if current_date - g_savedata.libraries.capture_point_payments.last_payout >= g_savedata.flags.capture_point_payroll_frequency then
		
		if CapturePointPayments.getSleepRatio() < g_savedata.flags.capture_point_payroll_sleep_ratio_max then
			server.notify(-1, "Capture Point Payroll", payroll_oversleeping_messages[math.random(1, #payroll_oversleeping_messages)], 7)

			-- reset the sleep tracker for the new week
			CapturePointPayments.resetSleepTracker()

			return
		end

		local payroll_per_island = g_savedata.flags.capture_point_payroll_amount

		-- the player always holds their main base, so give them that amount.
		local pay_amount = payroll_per_island * g_savedata.player_base_island.payroll_multiplier

		for _, capture_point in pairs(g_savedata.islands) do
			if capture_point.faction == ISLAND.FACTION.PLAYER then
				pay_amount = pay_amount + payroll_per_island * capture_point.payroll_multiplier
			end
		end

		local player_currency = server.getCurrency()
		local player_research = server.getResearchPoints()

		server.setCurrency(player_currency + pay_amount, player_research)

		local payout_message = payroll_payout_messages[math.random(1, #payroll_payout_messages)]

		payout_message = payout_message:gsub("${payout}", pay_amount)

		server.notify(-1, "Capture Point Payroll", payout_message, 4)

		-- reset the sleep tracker for the new week
		CapturePointPayments.resetSleepTracker()
	end
end

-- increments the sleep tracker.
---@param game_ticks number the game_ticks given by onTick(), 1 means the player is not sleeping, 400 means the player is sleeping.
function CapturePointPayments.incrementSleepTracker(game_ticks)
	-- increment the number of this tick (game_ticks 400 is sleeping, game_ticks 1 is normal)

	local sleep_tracker = g_savedata.libraries.capture_point_payments.sleep_tracker

	if game_ticks == 1 then
		sleep_tracker.normal = sleep_tracker.normal + 1
	end

	sleep_tracker.total = sleep_tracker.total + game_ticks
end

-- gets the current date, along with the % of the current day
---@return number current_date the current day plus the current day percentage.
function CapturePointPayments.getDate()
	local time_data = server.getTime()

	local total_days = server.getDateValue()

	return total_days + time_data.percent
end

-- resets the sleep tracker
function CapturePointPayments.resetSleepTracker()
	g_savedata.libraries.capture_point_payments.sleep_tracker = {
		normal = 0,
		total = 0
	}

	g_savedata.libraries.capture_point_payments.last_payout = server.getDateValue() + g_savedata.flags.capture_point_payroll_time
end

-- Gets the sleep ratio
---@return number sleep_ratio value of 0-1, if the player has consantly been sleeping, the value will be 0, if the player has never slept, then the value will be 1.
function CapturePointPayments.getSleepRatio()
	local sleep_tracker = g_savedata.libraries.capture_point_payments.sleep_tracker

	return sleep_tracker.normal/sleep_tracker.total
end

--[[


Flag Registers


]]

--[[
Number Flags
]]

--[[
	capture_point_payroll_frequency flag,
	controls the frequency of which you get a payroll for how many capture points you hold in days.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_frequency",
	7,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls the frequency of which you get a payroll for how many capture points you hold in days.",
	nil,
	nil
)

--[[
	capture_point_payroll_frequency flag,
	controls how much money you get per capture point you hold.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_amount",
	700,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls how much money you get per capture point you hold.",
	0,
	nil
)

--[[ 
	capture_point_payroll_frequency flag,
	controls at which time of the day you will recieve the payment, 
	may have strange behaviour when the payroll frequency is less than 1.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_time",
	0.2916666667,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls at which time of the day you will recieve the payment, may have strange behaviour when the payroll frequency is less than 1.",
	0,
	1
)

--[[
	capture_point_payroll_sleep_ratio_max flag,
	controls the minimum amount of time you must've spent not asleep for you to get the payroll.
]]
Flag.registerNumberFlag(
	"capture_point_payroll_sleep_ratio_max",
	0.3,
	{
		"balance",
		"capture points",
		"payroll",
		"no performance impact"
	},
	"normal",
	"admin",
	nil,
	"Controls the minimum amount of time you must've spent not asleep for you to get the payroll.",
	0,
	1
)
 -- controls the payroll system for how many islands you hold. -- optimized island lookups and handles the island_grid
--[[
	Capture System - Manages island capture progress, faction changes, and associated events.
	Provides clean separation of capture mechanics from UI/tick logic.
]]

CaptureSystem = {}

-- shortened library name
cs = CaptureSystem

--[[


	Classes


]]

---@class IslandCaptureState
---@field capture_timer number Current capture progress (0 to CAPTURE_TIME)
---@field faction FACTION Current controlling faction
---@field ai_capturing number Number of AI units capturing
---@field players_capturing number Number of players capturing
---@field is_contested boolean Whether AI and players are both capturing
---@field last_faction_change number Timestamp of last faction change (for UI updates)

--[[


    Constants


]]

CAPTURE_TICK_RATE = 60
CAPTURE_SPEEDS = { 1, 1.35, 1.7, 2 }

--[[


	Variables


]]

g_savedata.libraries.capture_system = {
	--- Island dirty flags for UI updates (map, tooltip, etc)
	---@type table<integer, boolean>
	dirty_islands = {},
}

--[[


	Functions - Capture Mechanics

    
]]

---Contains the equation used for calculating the change in capture progress, since its reused so often
---@param capturer_amount integer The amount of units capturing (either player or AI)
---@param game_ticks number
---@param speed number The base speed multiplier (higher for players, lower for AI)
function CaptureSystem.calculateProgressChange(capturer_amount, game_ticks, speed)
	capturer_amount = math.min(capturer_amount, #CAPTURE_SPEEDS)
    return (speed * CAPTURE_SPEEDS[capturer_amount]) * CAPTURE_TICK_RATE * game_ticks
end

---Updates the capture timer for an island based on the amount of ai and players capturing
---@param island ISLAND
---@param ai_count integer Number of AI units capturing
---@param player_count integer Number of players capturing
---@param game_ticks number Tick delta from onTick
function CaptureSystem.updateCaptureTimer(island, ai_count, player_count, game_ticks)
	if not island then
		return
	end

	-- Clamp counts to array bounds
	ai_count = math.min(ai_count, #CAPTURE_SPEEDS)
	player_count = math.min(player_count, #CAPTURE_SPEEDS)

	local old_timer = island.capture_timer
	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME

	-- Apply contested mode logic
	if g_savedata.settings.CONTESTED_MODE and ai_count > 0 and player_count > 0 then
		island.is_contested = true
        CaptureSystem.markDirty(island.index) -- So the tooltip can update stuff like remaining enemys
	else
		island.is_contested = false

		-- Apply capture progress
		if player_count > 0 and CAPTURE_TIME > island.capture_timer then
			island.capture_timer = island.capture_timer + CaptureSystem.calculateProgressChange(player_count, game_ticks, 5)

		elseif ai_count > 0 and 0 < island.capture_timer then
			island.capture_timer = island.capture_timer - CaptureSystem.calculateProgressChange(ai_count, game_ticks, 1)
		end
	end

	-- Make sure its within limits
	island.capture_timer = math.clamp(island.capture_timer, 0, CAPTURE_TIME)

	-- Mark island as needing UI update if timer changed
	if island.capture_timer ~= old_timer then
		CaptureSystem.markDirty(island.index)
	end
end

---Check if island should change faction and apply the change
---@param island ISLAND
---@return FACTION|nil new_faction The faction it changed to, or nil if no change
function CaptureSystem.resolveFactionChange(island)
	if not island then
		return nil
	end

	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME
	local new_faction = nil

	-- Only main bases don't capture
	if island.index == g_savedata.ai_base_island.index or island.index == g_savedata.player_base_island.index then
		return nil
	end

	if island.capture_timer <= 0 and island.faction ~= ISLAND.FACTION.AI then
		new_faction = ISLAND.FACTION.AI
	elseif island.capture_timer >= CAPTURE_TIME and island.faction ~= ISLAND.FACTION.PLAYER then
		new_faction = ISLAND.FACTION.PLAYER
	end

	if new_faction then
		local old_faction = island.faction
		IslandRegistry.setFaction(island, new_faction)
		island.capture_timer = new_faction == ISLAND.FACTION.AI and 0 or CAPTURE_TIME
		CaptureSystem.markDirty(island.index)
		return new_faction
	end

	return nil
end

--[[


	Functions - UI / Status


]]

---Build tooltip text for an island flag based on current capture state
---@param island ISLAND
---@return string tooltip The formatted tooltip text
function CaptureSystem.buildCaptureTooltip(island)
	if not island then
		return ""
	end

	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME
	local cap_percent = (island.capture_timer / CAPTURE_TIME) * 100
	local capturing_status = "Revolting" -- Should never happen
	local cp_status = ""

	if island.is_contested then
		capturing_status = "Contested"
		cp_status = "Remove the ${enemy_capturing_count} enemies to resume capturing."
	elseif island.faction ~= ISLAND.FACTION.PLAYER then
		if island.ai_capturing == 0 and island.players_capturing == 0 then
			capturing_status = "Capture"
			cp_status = "Get closer to the capture point to begin capturing."
		elseif island.ai_capturing == 0 then
			capturing_status = "Capturing"
			cp_status = "${time_until_faction_change} until under player control."
		else
			capturing_status = "Losing"
			cp_status = "${time_until_faction_change} until under enemy control."
		end
	else
		if island.ai_capturing == 0 and island.players_capturing == 0 or cap_percent == 100 then
			capturing_status = "Captured"
			cp_status = "Under full player control."
		elseif island.ai_capturing == 0 then
			capturing_status = "Re-Capturing"
			cp_status = "${time_until_faction_change} until under full player control."
		else
			capturing_status = "Losing"
			cp_status = "${time_until_faction_change} until under enemy control."
		end
	end

    -- Add formatting
	local tooltip = ("%s: %0.2f%%\n%s"):format(capturing_status, cap_percent, cp_status)
	
    -- Format in the field enemy_capturing_count
    tooltip = tooltip:setField("enemy_capturing_count", island.ai_capturing)

    -- Format in the field time_until_faction_change
	if tooltip:hasField("time_until_faction_change") then
        -- Calculate the time until the faction changes
		local time_till_faction_change = 0
		local capture_rate = 0

		if island.players_capturing > 0 and g_savedata.settings.CAPTURE_TIME > island.capture_timer then
            capture_rate = CaptureSystem.calculateProgressChange(island.players_capturing, 1, 5)
			time_till_faction_change = (g_savedata.settings.CAPTURE_TIME - island.capture_timer) / capture_rate * CAPTURE_TICK_RATE / 60
		elseif island.ai_capturing > 0 and 0 < island.capture_timer then
            capture_rate = CaptureSystem.calculateProgressChange(island.ai_capturing, 1, 1)
			time_till_faction_change = island.capture_timer / capture_rate * CAPTURE_TICK_RATE / 60
		end

		local formatted_timer = string.formatTime(time_formats.yMdhms, time_till_faction_change, false)
		tooltip = tooltip:setField("time_until_faction_change", formatted_timer, true)
	
        -- Add the capture timer debug if the flag show_capture_timer_debug is enabled
        if g_savedata.flags.show_capture_timer_debug then
            tooltip = tooltip .. (" capture rate:%s time_till_faction_change:%s formatted_time:%s"):format(capture_rate, time_till_faction_change, formatted_timer)
        end
    end

	return tooltip
end

---Mark an island as needing its tooltip updated
---@param island_index integer
function CaptureSystem.markDirty(island_index)
	g_savedata.libraries.capture_system.dirty_islands[island_index] = true
end

---Get and clear dirty flag for an island
---@param island_index integer
---@return boolean is_dirty Whether the island needs UI update
function CaptureSystem.checkAndClearDirty(island_index)
	local is_dirty = g_savedata.libraries.capture_system.dirty_islands[island_index] or false
	g_savedata.libraries.capture_system.dirty_islands[island_index] = nil
	return is_dirty
end

---Clear all dirty flags
function CaptureSystem.clearAllDirty()
	g_savedata.libraries.capture_system.dirty_islands = {}
end

--[[


	Functions - Faction Queries


]]

---Get all islands controlled by a faction
---@param faction FACTION
---@return table<integer, ISLAND>
function CaptureSystem.getIslandsByFaction(faction)
	return IslandRegistry.getFactionMap(faction)
end

---Count islands by faction
---@param faction FACTION
---@return integer count
function CaptureSystem.countIslandsByFaction(faction)
	local map = IslandRegistry.getFactionMap(faction)
	return table.length(map)
end
 -- capture progress and faction change logic
--[[
	
Copyright 2024 Liam Matthews

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
	Used to convert a vehicle's id into the group_id without requring to constantly use server.getVehicleData.
]]

-- library name
VehicleGroup = {}

--[[


	Classes


]]

--[[


	Variables


]]

--- Create the g_savedata for this library.
g_savedata = g_savedata or {}
g_savedata.libraries = g_savedata.libraries or {}
g_savedata.libraries.vehicle_group = {
	translations = {}, ---@type table<integer, integer> indexed by vehicle_id, stores the group_id.
	group_to_vehicles = {} ---@type table<integer, table<integer>> indexed by group_id, stores a table of group_ids.
}

--[[


	Functions


]]

---# Stores a group into the translations table <br>
---- Only to be used internally by vehicleGroup.lua, unless you want to make some further optimisations
---@param group_id integer the group_id to store in the translations table.
local function storeGroupID(group_id)

	-- get the vehicle ids associated with this group
	local vehicle_ids = server.getVehicleGroup(group_id)

	-- store all of the vehicle_ids stored in the group into the translations.
	for vehicle_group_index = 1, #vehicle_ids do
		g_savedata.libraries.vehicle_group.translations[vehicle_ids[vehicle_group_index]] = group_id
	end

	g_savedata.libraries.vehicle_group.group_to_vehicles = g_savedata.libraries.vehicle_group.group_to_vehicles or {}
	g_savedata.libraries.vehicle_group.group_to_vehicles[group_id] = vehicle_ids
end

---# Discovers the groupID for the specified vehicle_id and returns it, and also stores it in the translations table. <br>
---- Only to be used internally by vehicleGroup.lua, unless you want to make some further optimisations, as this function can return the id, but it will do so via server.getVehicleData, which nullifies the point of this script if you use this directly.
---@param vehicle_id integer the vehicle_id to find the group_id of.
---@return integer? group_id the group_id associated with the vehicle_id, returns nil if the vehicle_id doesn't have a vehicle associated.
local function findGroupID(vehicle_id)
	-- get the vehicle's data
	local vehicle_data = server.getVehicleData(vehicle_id)

	-- check if we got the data we needed.
	---@diagnostic disable-next-line: undefined-field
	if not vehicle_data or not vehicle_data.group_id then
		return nil
	end

	-- store the vehicles in the translations table
	---@diagnostic disable-next-line: undefined-field
	storeGroupID(vehicle_data.group_id)
	
	-- return the group_id
	---@diagnostic disable-next-line: undefined-field
	return vehicle_data.group_id
end

---@param vehicle_id integer the vehicle_id which you want to convert into group_id.
---@return integer? group_id the group_id associated with the vehicle_id, returns nil if the vehicle_id doesn't have a vehicle associated.
function VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the vehicle_id is a number.
	if type(vehicle_id) ~= "number" then
		return nil
	end

	-- Ensure the vehicle_id is an integer.
	if math.type(vehicle_id) ~= "integer" then
		return nil
	end

	-- get the stored group_id.
	local stored_group_id = g_savedata.libraries.vehicle_group.translations[vehicle_id]

	-- if theres already a stored translation for this vehicle, use that.
	if stored_group_id then
		return stored_group_id
	end

	-- theres not a translation stored for this vehicle yet, so find it and return it.
	return findGroupID(vehicle_id)
end

---# Returns the vehicle_id of the main vehicle in the group.
---@param group_id integer the group_id to get the main vehicle for
---@return integer? vehicle_id the vehicle_id of the main body in that group
function VehicleGroup.getMainVehicle(group_id)
	-- get the vehicles in the group
	local vehicle_ids, is_success = server.getVehicleGroup(group_id)

	if not is_success then
		return nil
	end

	if type(vehicle_ids) ~= "table" then
		return nil
	end

	return vehicle_ids[1]
end

--[[


	Callback Injections


]]

-- store into translation table when a group spawns.
---@diagnostic disable-next-line: undefined-global
local old_onGroupSpawn = onGroupSpawn ---@type function
function onGroupSpawn(group_id, peer_id, x, y, z, group_cost)
	storeGroupID(group_id)

	if old_onGroupSpawn then
		return old_onGroupSpawn(group_id, peer_id, x, y, z, group_cost)
	end
end

--[[
	

	Function Injections


]]

-- Fix server.getVehicleGroup, if it just returns the value, try to get the proper table.<br>
-- It would return junk whenever you gave it a vehjicle_id 
local old_getVehicleGroup = server.getVehicleGroup
function server.getVehicleGroup(group_id)
	local vehicle_ids = old_getVehicleGroup(group_id)

	-- didn't return junk
	if vehicle_ids ~= group_id then
		return vehicle_ids, true
	end

	g_savedata.libraries.vehicle_group.group_to_vehicles = g_savedata.libraries.vehicle_group.group_to_vehicles or {}

	-- returned junk, try to get valid output.
	local real_vehicle_ids = g_savedata.libraries.vehicle_group.group_to_vehicles[group_id]

	-- no valid input found, just return the returned data as a table.
	if not real_vehicle_ids then
		return {vehicle_ids}, false
	end

	-- return the real vehicle ids.
	return real_vehicle_ids, true
end
 -- functions for getting the vehicle group_id from the vehicle_id. -- functions related to vehicles, and parsing data on them
--require("libraries.icm.vehicles.vehicleFires") -- functions for handling fires on the AI vehicles.
--[[


	Library Setup


]]

-- required libraries

-- library name
ExecutionQueue = {}

-- shortened library name
eq = ExecutionQueue

--[[


	Variables
   

]]

s = s or server

queued_executions = {}

--[[


	Classes


]]

--[[


	Functions


]]

---# print function just in case debugging.lua is not present.
---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function ExecutionQueue.print(message, requires_debug, debug_type, peer_id)
	if not d then
		s.announce("alu", tostring(message))
		return
	end

	d.print(message, requires_debug, debug_type, peer_id)
end

function ExecutionQueue.tick()
	local queued_executions_to_remove = {}

	for i = 1, #queued_executions do
		local queued_execution = queued_executions[i]
		queued_execution:tick()

		if queued_execution.expired then
			--[[
				insert at start to ensure that it removes the ones with the greatest indecies first
				otherwise would cause issues where for example, it has to remove index 1 and 2, so it
				removes index 1, but now index 2 is index 1, so when it would go to remove index 2
				it would actually then remove index 3, leaving index 2 to still be there.
			]]
			table.insert(queued_executions_to_remove, 1, i)
		end
	end

	for i = 1, #queued_executions_to_remove do
		table.remove(queued_executions, queued_executions_to_remove[i])
	end
end

-- Queue a function to be called when the condition is true, store variables you may want to use in variable_table, and then index the stored variables in the functions via "self:getVar(variable_index)" and self must be defined as a parametre for the function. NOTE: on reloads, all queued_executions will be deleted, this is because we cannot store functions in g_savedata. If you need it after reloads as well, consider trying to rebuild the queued functions in onCreate().
---@param execute_condition function this function must return true for function_to_execute to be executed.
---@param function_to_execute function this function will be executed when execute_condition is true.
---@param variable_table table? use this table to store variables you'll want to use in execute_condition and/or function_to_execute, index these variables in the functions via "self:getVar(variable_index)", and self must be defined as a parametre for the function.
---@param execute_count integer? the number of times this can be executed, once it hits 0, it will be removed, set to -1 for infinite executions (until reload), defaults to 1
---@param expire_timer number? the number of ticks until it expires, once it hits 0, it will be removed, set to -1 to never expire (until reload), defaults to -1
---@return boolean is_success if it successfully the queued execution
function ExecutionQueue.queue(execute_condition, function_to_execute, variable_table, execute_count, expire_timer)

	if not execute_condition then
		eq.print("(ExecutionQueue) execute_condition is not defined!", true, 1)
		return false
	end

	if type(execute_condition) ~= "function" then
		eq.print(("(ExecutionQueue) execute_condition is not a function! (execute_condition: %s type: %s"):format(tostring(execute_condition), type(execute_condition)), true, 1)
		return false
	end

	if not function_to_execute then
		eq.print("(ExecutionQueue) function_to_execute is not defined!", true, 1)
		return false
	end

	if type(function_to_execute) ~= "function" then
		eq.print(("(ExecutionQueue) function_to_execute is not a function! (function_to_execute: %s type: %s"):format(tostring(function_to_execute), type(function_to_execute)), true, 1)
		return false
	end

	variable_table = variable_table or {}

	local queued_execution = {
		variable_table = variable_table,
		execute_condition = execute_condition,
		function_to_execute = function_to_execute,
		execute_count = execute_count or 1,
		expire_timer = expire_timer or -1,
		expired = false
	}

	function queued_execution:getVar(variable_index)
		return self.variable_table[variable_index]
	end

	function queued_execution:tick()
		-- see if we've met the execution conditions
		if self:execute_condition() then
			-- execute the function
			self:function_to_execute()

			-- decrement execute_count
			self.execute_count = self.execute_count - 1
		end

		-- decrement expire_timer
		self.expire_timer = self.expire_timer - 1

		-- if we're expired/fully used
		if self.execute_count == 0 or self.expire_timer == 0 then
			-- expire self, to be deleted.
			self.expired = true
		end
	end

	table.insert(queued_executions, queued_execution)

	return true
end
 -- functions for queuing functions for conditions to be met. -- custom math functions
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

-- Library Version 0.0.3

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains some code for math on Vector 2s, as in, a 2D vector.
]]

-- library name
Vector2 = {}

--[[


	Classes


]]

---@class Vector2
---@field x number
---@field y number Usually the z axis in disguise.

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for creating a new Vector2
---@param x number
---@param y number
---@return Vector2
function Vector2.new(x, y)
	-- create the vector
	local vector = {
		x = x,
		y = y
	}

	-- return the vector
	return vector
end

--- Function for turning a Matrix into a Vector2 (matrix x becomes vector x, matrix z becomes vector y)
---@param target_matrix SWMatrix
---@param raw_coordinates boolean? whether or not to return the raw coordinates of the matrix (true), or the transformed coordinates (false/nil).
---@return Vector2 vector the vector created from the matrix.
function Vector2.fromMatrix(target_matrix, raw_coordinates)
	-- if raw_coordinates is true
	if raw_coordinates then
		-- return the raw coordinates
		return {
			x = target_matrix[13],
			y = target_matrix[15]
		}
	end

	--* raw coordinates is false, return the transformed coordinates

	-- get transformed coordinates (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local x, _, z = matrix.position(target_matrix)

	-- return the transformed coordinates
	return {
		x = x,
		y = z
	}
end

--- Function for creating a Vector2 from polar coordinates
---@param distance number the distance from the origin
---@param angle number the angle from the origin
---@return Vector2
function Vector2.fromPolar(distance, angle)
	-- create the vector from the polar coordinates
	local vector = {
		x = distance * math.cos(angle),
		y = distance * math.sin(angle)
	}

	-- return the vector
	return vector
end

--- Function for adding two Vector2s
---@param a Vector2
---@param b Vector2
---@return Vector2
function Vector2.add(a, b)
	-- create the added vector
	local vector = {
		x = a.x + b.x,
		y = a.y + b.y
	}

	-- return the vector
	return vector
end

--- Function for getting the euclidean distance
---@param a Vector2
---@param b Vector2
---@return number euclidean_distance euclidean distance between the two 2D vectors.
function Vector2.euclideanDistance(a, b)
	-- get the relative x position
	local rx = a.x - b.x

	-- get the relative y position
	local ry = a.y - b.y

	-- return the distance
	return math.sqrt(rx*rx+ry*ry)
end

--- Function for getting the manhattan distance
---@param a Vector2
---@param b Vector2
---@return number manhattan_distance manhattan distance between the two 2D vectors.
function Vector2.manhattanDistance(a, b)
	-- return the distance
	return (
		math.abs(a.x - b.x) + -- get manhattan distance on x axis
		math.abs(a.y - b.y) -- get manhattan distance on y axis
	)
end

--- Function for getting the angle from vector a to vector b
---@param a Vector2
---@param b Vector2
---@return number angle the angle from vector a to vector b
function Vector2.angleBetween(a, b)
	-- get the relative x position
	local rx = b.x - a.x

	-- get the relative y position
	local ry = b.y - a.y

	-- return the angle
	return math.atan(rx, ry)
end

--- Function for adding two Vector2s.
---@param a Vector2 the first vector to add.
---@param b Vector2 the second vector to add.
---@return Vector2 added_vector the vector created from the addition of the two vectors.
function Vector2.add(a, b)
	-- create the vector
	local added_vector = {
		x = a.x + b.x,
		y = a.y + b.y
	}

	-- return the vector
	return added_vector
end

--- Function for subtracting two Vector2s.
---@param a Vector2 the vector to subtract from.
---@param b Vector2 the vector to subtract.
---@return Vector2 subtracted_vector the vector created from the subtraction of the two vectors.
function Vector2.subtract(a, b)
	-- create the vector
	local subtracted_vector = {
		x = a.x - b.x,
		y = a.y - b.y
	}

	-- return the vector
	return subtracted_vector
end

--- Function for multiplying two Vector2s.
---@param a Vector2 the first vector to multiply.
---@param b Vector2 the second vector to multiply.
---@return Vector2 multiplied_vector the vector created from the multiplication of the two vectors.
function Vector2.multiply(a, b)
	-- create the vector
	local multiplied_vector = {
		x = a.x * b.x,
		y = a.y * b.y
	}

	-- return the vector
	return multiplied_vector
end

--- Function for dividing two Vector2s.
---@param a Vector2 the vector to divide.
---@param b Vector2 the vector to divide by.
---@return Vector2 divided_vector the vector created from the division of the two vectors.
function Vector2.divide(a, b)
	-- create the vector
	local divided_vector = {
		x = a.x / b.x,
		y = a.y / b.y
	}

	-- return the vector
	return divided_vector
end

--- Function for doing a scalar division on a vector.
---@param vector Vector2 the vector to divide.
---@param scalar number the scalar to divide the vector by.
---@return Vector2 divided_vector the vector created from the division of the vector by the scalar.
function Vector2.scalarDivide(vector, scalar)
	-- create the vector
	local divided_vector = {
		x = vector.x / scalar,
		y = vector.y / scalar
	}

	-- return the vector
	return divided_vector
end

--- Function for doing a scalar multiplication on a vector.
---@param vector Vector2 the vector to multiply.
---@param scalar number the scalar to multiply the vector by.
---@return Vector2 multiplied_vector the vector created from the multiplication of the vector by the scalar.
function Vector2.scalarMultiply(vector, scalar)
	-- create the vector
	local multiplied_vector = {
		x = vector.x * scalar,
		y = vector.y * scalar
	}

	-- return the vector
	return multiplied_vector
end

--- Function for doing a dot product on two vectors.
---@param a Vector2 the first vector to use in the dot product
---@param b Vector2 the second vector to use in the dot product
---@return number dot_product the dot product of the two vectors.
function Vector2.dotProduct(a, b)
	-- Calculate and Return the dot product.
	return (
		a.x * b.x
		+ a.y * b.y
	)
end

--- Function for getting the length of a vector
---@param vector Vector2 the vector to get the length of
---@return number length the length of the vector
function Vector2.length(vector)
	return math.sqrt(
		vector.x * vector.x
		+ vector.y * vector.y
	)
end

--- Function for normalising a vector.
---@param vector Vector2 the vector to normalise.
---@return Vector2 normalised_vector the normalised vector
function Vector2.normalise(vector)
	-- Get the length of the vector
	local vector_length = Vector2.length(vector)

	-- Do and return a scalar division on the vector by the vector length.
	return Vector2.scalarDivide(vector, vector_length)
end

--- Function for doing a scalar projection on a Vector2. Projects position onto a line defined by line_start and line_end, for a given maximum distance.
---@param position Vector2 the position to project onto the line.
---@param line_start Vector2 the start position of the line.
---@param line_end Vector2 the end position of the line.
---@param maximum_distance number the maximum projection distance.
---@return Vector2 projected_vector the vector projected onto the line.
---@return number projected_distance the distance the vector was projected forward by.
function Vector2.scalarProjection(position, line_start, line_end, maximum_distance)
	-- Get the position local to the line start
	local position_vector = Vector2.subtract(position, line_start)

	-- Get the line end position local to the line start
	local line_vector = Vector2.subtract(line_end, line_start)

	-- Get a normalised version of the line vector.
	local line_vector_normalised = Vector2.normalise(line_vector)

	-- Get the length of the line vector
	local line_vector_length = Vector2.length(line_vector)

	-- Get the progress of the position along the line vector.
	local position_progress =Vector2.dotProduct( -- Get the dot product
		position_vector,
		line_vector
	) / line_vector_length -- Divide by the length of the vector.

	-- Get the position as if it was on the path.
	local position_on_path = Vector2.add( -- Add the line start and normalised line vector vectors together.
		line_start,
		Vector2.scalarMultiply(
			line_vector_normalised,
			position_progress -- Scalar Multiply by where the position would be if it was along the line.
		)
	)

	-- Calculate the projection distance, by capping it to the line's end.
	local projection_distance = math.min(
		Vector2.euclideanDistance(
			line_end,
			position_on_path
		),
		maximum_distance
	)

	-- Calculate the projected vector
	local projected_vector = Vector2.add( -- Add the line start and normalised line vector vectors together.
		line_start,
		Vector2.scalarMultiply(
			line_vector_normalised,
			position_progress + projection_distance -- Scalar Multiply by the projection distance
		)
	)

	-- Return the projected vector.
	return projected_vector, projection_distance
end

--- Function for linearly interpolating between two Vector2s.
---@param source Vector2 the position to interpolate from.
---@param target Vector2 the position to interpolate to.
---@param alpha number the alpha value to interpolate by. (0 being source, 1 being target, 0.5 being halfway between source and target, though, not limited to 0-1.)
---@return Vector2 interpolated_vector the vector created from the interpolation of the two vectors.
function Vector2.lerp(source, target, alpha)
	-- Get the inverted alpha for multiplying the source.
	local inverted_alpha = 1 - alpha

	-- Create the vector
	local interpolated_vector = Vector2.add(
		Vector2.scalarMultiply(source, inverted_alpha),
		Vector2.scalarMultiply(target, alpha)
	)

	-- Return the vector
	return interpolated_vector
end
 -- custom Vector2 functions
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

-- Library Version 0.0.4

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains some code for math on Vector 3s, as in, a 3D vector.
]]

-- library name
Vector3 = {}

--[[


	Classes


]]

---@class Vector3
---@field x number x axis
---@field y number y axis (up/down)
---@field z number z axis

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for creating a new Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Vector3.new(x, y, z)
	-- create the vector
	local vector = {
		x = x,
		y = y,
		z = z
	}

	-- return the vector
	return vector
end


--- Function for turning a Matrix into a Vector3
---@param target_matrix SWMatrix
---@param raw_coordinates boolean? whether or not to return the raw coordinates of the matrix (true), or the transformed coordinates (false/nil).
---@return Vector3 vector the vector created from the matrix.
function Vector3.fromMatrix(target_matrix, raw_coordinates)
	-- if raw_coordinates is true
	if raw_coordinates then
		-- return the raw coordinates
		return {
			x = target_matrix[13],
			y = target_matrix[14],
			z = target_matrix[15]
		}
	end

	--* raw coordinates is false, return the transformed coordinates

	-- get transformed coordinates (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local x, y, z = matrix.position(target_matrix)

	-- return the transformed coordinates
	return {
		x = x,
		y = y,
		z = z
	}
end

--- Function for turning a Vector3 into a Matrix
---@param target_vector Vector3
---@return SWMatrix matrix the matrix created from the vector.
function Vector3.toMatrix(target_vector)
	-- create and return the matrix
	return {
		1,
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		0,
		0,
		1,
		0,
		target_vector.x,
		target_vector.y,
		target_vector.z,
		1
	}
end

--- Function for getting the euclidean distance
---@param a Vector3
---@param b Vector3
---@return number euclidean_distance euclidean distance between the two 3D vectors.
function Vector3.euclideanDistance(a, b)
	-- get the relative x position
	local rx = a.x - b.x

	-- get the relative y position
	local ry = a.y - b.y

	-- get the relative z position
	local rz = a.z - b.z

	-- return the distance
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

--- Function for getting the manhattan distance
---@param a Vector3
---@param b Vector3
---@return number manhattan_distance manhattan distance between the two 3D vectors.
function Vector3.manhattanDistance(a, b)
	-- return the distance
	return (
		math.abs(a.x - b.x) + -- get manhattan distance on x axis
		math.abs(a.y - b.y) + -- get manhattan distance on y axis
		math.abs(a.z - b.z) -- get manhattan distance on z axis
	)
end

-- Function for adding two Vector3s.
---@param a Vector3 the first vector to add.
---@param b Vector3 the second vector to add.
---@return Vector3 added_vector the vector created from the addition of the two vectors.
function Vector3.add(a, b)
	-- create the vector
	local added_vector = {
		x = a.x + b.x,
		y = a.y + b.y,
		z = a.z + b.z
	}

	-- return the vector
	return added_vector
end

-- Function for subtracting two Vector3s.
---@param a Vector3 the vector to subtract from.
---@param b Vector3 the vector to subtract.
---@return Vector3 subtracted_vector the vector created from the subtraction of the two vectors.
function Vector3.subtract(a, b)
	-- create the vector
	local subtracted_vector = {
		x = a.x - b.x,
		y = a.y - b.y,
		z = a.z - b.z
	}

	-- return the vector
	return subtracted_vector
end

-- Function for multiplying two Vector3s.
---@param a Vector3 the first vector to multiply.
---@param b Vector3 the second vector to multiply.
---@return Vector3 multiplied_vector the vector created from the multiplication of the two vectors.
function Vector3.multiply(a, b)
	-- create the vector
	local multiplied_vector = {
		x = a.x * b.x,
		y = a.y * b.y,
		z = a.z * b.z
	}

	-- return the vector
	return multiplied_vector
end

-- Function for dividing two Vector3s.
---@param a Vector3 the vector to divide.
---@param b Vector3 the vector to divide by.
---@return Vector3 divided_vector the vector created from the division of the two vectors.
function Vector3.divide(a, b)
	-- create the vector
	local divided_vector = {
		x = a.x / b.x,
		y = a.y / b.y,
		z = a.z / b.z
	}

	-- return the vector
	return divided_vector
end

--- Function for doing a scalar multiplication on a vector.
---@param vector Vector3 the vector to multiply.
---@param scalar number the scalar to multiply the vector by.
---@return Vector3 multiplied_vector the vector created from the multiplication of the vector by the scalar.
function Vector3.scalarMultiply(vector, scalar)
	-- create the vector
	local multiplied_vector = {
		x = vector.x * scalar,
		y = vector.y * scalar,
		z = vector.z * scalar
	}

	-- return the vector
	return multiplied_vector
end

--- Function for linearly interpolating between two Vector3s.
---@param source Vector3 the position to interpolate from.
---@param target Vector3 the position to interpolate to.
---@param alpha number the alpha value to interpolate by. (0 being source, 1 being target, 0.5 being halfway between source and target, though, not limited to 0-1.)
---@return Vector3 interpolated_vector the vector created from the interpolation of the two vectors.
function Vector3.lerp(source, target, alpha)
	-- Get the inverted alpha for multiplying the source.
	local inverted_alpha = 1 - alpha

	-- Create the vector
	local interpolated_vector = Vector3.add(
		Vector3.scalarMultiply(source, inverted_alpha),
		Vector3.scalarMultiply(target, alpha)
	)

	-- Return the vector
	return interpolated_vector
end
 -- custom Vector3 functions -- custom string functions -- custom table functions

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
					spawn_time = g_savedata.settings.CONVOY_FREQUENCY -- how long after a cargo vehicle is killed can another be spawned
				},
				ISLANDS = { --? rules for the islands
					max_capacity = 10000 *  g_savedata.settings.CARGO_CAPACITY_MULTIPLIER, -- the max amount of each resource islands can hold
					ai_base_generation = 350 -- the amount of cargo the ai's main base can generate per hour
				}
			},
			CONVOY = { --? convoy specific rules
				min_escorts = 2, -- minimum amount of escorts in a convoy
				max_escorts = 4, -- maximum amount of escorts in a convoy
				base_wait_time = time.minute * 2, -- the time a vehicle will wait till it just continues anyways
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
			},
			CONVOY_FREQUENCY = {
				min = nil,
				max = nil,
				input_multiplier = time.minute
			},
			CARGO_VEHICLE_DESPAWN_TIMER = {
				min = nil,
				max = nil,
				input_multiplier = time.minute
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

--[[ 

	checkbox settings

	seems like really dumb code, but for the checkboxes to be default true, we have to do this strange workaround.
	
	to have it default true, you must wrap true in quotes.
	you also cannot have any commas inside of the text, for checkboxes and sliders, as that will break it
]]

local PERFORMANCE_MODE = property.checkbox("Performance Mode (Disables tracebacks.)", false)
local SINKING_MODE = property.checkbox("Sinking Mode (Ships sink then explode.)", "true")
local ISLAND_CONTESTING = property.checkbox("Point Contesting (Factions block eachothers progress when they're both trying to capture the same point)", "true")
local CARGO_MODE = property.checkbox("Cargo Mode (AI needs to transport resources to make more vehicles.)", "true")
local AIR_CRASH_MODE = property.checkbox("Air Crash Mode (Air vehicles explode whenever they crash.)", "true")
local PAUSE_WHEN_NONE_ONLINE = property.checkbox("Pause the addon when nobody's online (For dedicated servers - so the AI doesn't keep advancing when people are asleep.)", "true")
local CAPTURE_POINT_PAYMENTS = property.checkbox("Capture Point Payments (Get weekly payments for how many capture points you hold.)", "true")

function onCreate(is_world_create)

	-- setup settings
	if not g_savedata.settings then
		g_savedata.settings = {
			PERFORMANCE_MODE = PERFORMANCE_MODE,
			SINKING_MODE = SINKING_MODE,
			CONTESTED_MODE = ISLAND_CONTESTING,
			CARGO_MODE = CARGO_MODE,
			AIR_CRASH_MODE = AIR_CRASH_MODE,
			CAPTURE_POINT_PAYMENTS = CAPTURE_POINT_PAYMENTS,
			ENEMY_HP_MODIFIER = property.slider("AI HP Modifier", 0.1, 10, 0.1, 1),
			AI_PRODUCTION_TIME_BASE = property.slider("AI Production Time (Mins)", 1, 60, 1, 15) * 60 * 60,
			CAPTURE_TIME = property.slider("AI Capture Time (Mins) | Player Capture Time (Mins) / 5", 10, 600, 1, 60) * 60 * 60,
			MAX_BOAT_AMOUNT = property.slider("Max amount of AI Ships", 0, 40, 1, 10),
			MAX_LAND_AMOUNT = property.slider("Max amount of AI Land Vehicles", 0, 40, 1, 10),
			MAX_PLANE_AMOUNT = property.slider("Max amount of AI Planes", 0, 40, 1, 10),
			MAX_HELI_AMOUNT = property.slider("Max amount of AI Helicopters", 0, 40, 1, 10),
			MAX_TURRET_AMOUNT = property.slider("Max amount of AI Turrets (Per island)", 0, 7, 1, 3),
			AI_INITIAL_SPAWN_COUNT = property.slider("AI Initial Spawn Count", 0, 30, 1, 5),
			AI_INITIAL_ISLAND_AMOUNT = property.slider("Percent of Islands which are AI", 0, 100, 1, 20) * 0.01,
			ISLAND_COUNT = property.slider("Percent of Islands that are available", 0, 100, 1,100) * 0.01,
			CARGO_GENERATION_MULTIPLIER = property.slider("Cargo Generation Multiplier (multiplies cargo generated by this)", 0.1, 5, 0.1, 1),
			CARGO_CAPACITY_MULTIPLIER = property.slider("Cargo Capacity Multiplier (multiplier for capacity of each island)", 0.1, 5, 0.1, 1),
			CONVOY_FREQUENCY = property.slider("Cargo Convoy Cooldown (Mins)", 5, 60, 1, 30) * 60 * 60,
			CARGO_VEHICLE_DESPAWN_TIMER = property.slider("Cargo Vehicle Despawn Timer (Mins)", 0, 120, 1, 60) * time.minute,
			PAUSE_WHEN_NONE_ONLINE = PAUSE_WHEN_NONE_ONLINE,
		}

		g_savedata.debug.traceback.default = not g_savedata.settings.PERFORMANCE_MODE
	end

	-- checks for AI Paths addon
	g_savedata.info.addons.ai_paths = table.pack(s.getAddonIndex("AI Paths"))[2]

	c.overrides() -- override some functions

	ac.executeOnReply( -- setup world after 1 tick, to prevent issues with the addon indexes getting mixed up
		SHORT_ADDON_NAME, -- addon we're expecting the reply from
		"onCreate()", -- the message content
		0, -- the port to recieve this from
		function()
			setupMain(is_world_create)
		end, -- function to execute when we get the reply
		1, -- how many times this can be triggered
		20 -- how many seconds to wait till we expire it
	)

	ac.sendCommunication("onCreate()", 0)

	if is_world_create then
		d.print("Setting up ICM for the first time, this may take a few seconds.", false, 0)
	end
end

function setupMain(is_world_create)

	is_dlc_weapons = s.dlcWeapons()

	-- checks for Vanilla Conquest Mode addon
	local _, is_success = s.getAddonIndex("DLC Weapons AI")
	if is_success then
		d.print("setupMain detected DLC Weapons AI at index "..tostring(_))
		g_savedata.info.addons.default_conquest_mode = true
		is_dlc_weapons = false
	end

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	comp.verify() -- backwards compatibility check

	-- check for NSO mod
	local nso_tile, got_nso_tile = s.getTile(m.translation(-8000, 0, -12000))
	g_savedata.info.mods.NSO = got_nso_tile and nso_tile.cost > 0

	warningChecks(-1)

	if is_dlc_weapons then

		setupRules()

		p.updatePathfinding()

		d.print("building locations and prefabs...", true, 0)

		sup.createVehiclePrefabs()

		if is_world_create then
			d.print("setting up world...", true, 0)

			d.print("getting y level of all graph nodes...", true, 0)

			local start_time = s.getTimeMillisec()
			--[[ 
				cause createPathY to execute, which will get the y level of all graph nodes
				otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
				instead it looks like its taking a bit longer to create the world.
			]]
			s.pathfind(m.translation(0, 0, 0), m.translation(0, 0, 0), "", "") 
			d.print("Graph Node Y level setup took: "..(millisecondsSince(start_time)/1000).."s", true, 0)

			d.print("setting up spawn zones...", true, 0)

			start_time = s.getTimeMillisec()
			local spawn_zones = sup.spawnZones()
			-- add them to a list indexed by which island the zone belongs to
			-- local tile_zones = sup.sortSpawnZones(spawn_zones)

			d.print("populating constructable vehicles with spawning modifiers...", true, 0)
			sm.create()
			d.print("Spawning Modifiers population took: "..(millisecondsSince(start_time)/1000).."s", true, 0)

			start_time = s.getTimeMillisec()
			local start_island = s.getStartIsland()

			d.print("creating player's main base...", true, 0)

			-- get all island zones
			local islands = s.getZones("capture")

			-- filter NSO and non NSO exclusive islands
			for island_index, island in pairs(islands) do
				if not g_savedata.info.mods.NSO and Tags.has(island.tags, "NSO") then
					d.print("removed "..island.name.." because it is NSO exclusive", true, 0)
					table.remove(islands, island_index)
				elseif g_savedata.info.mods.NSO and Tags.has(island.tags, "not_NSO") then
					d.print("removed "..island.name.." because it's incompatible with NSO", true, 0)
					table.remove(islands, island_index)
				end
			end
			
			-- setup the player base
			for island_index, island in ipairs(islands) do

				local island_tile = s.getTile(island.transform)
				if island_tile.name == start_island.name or (island_tile.name == "data/tiles/island_43_multiplayer_base.xml" and g_savedata.player_base_island == nil) then
					if not Tags.has(island.tags, "not_main_base") then
						local flag = s.spawnAddonComponent(m.multiply(island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
						g_savedata.player_base_island = Island.createIslandData(
							island,
							island_index,
							ISLAND.FACTION.PLAYER,
							flag,
							g_savedata.settings.CAPTURE_TIME,
							{ oil = 0, jet_fuel = 0, diesel = 0 }
						)
						
						-- only break if the island's name is the same as the island the player is starting at
						-- as breaking if its the multiplayer base could cause the player to always start at the multiplayer base in specific scenarios
						if island_tile.name == start_island.name then
							break
						end
					end
				end
			end

			d.print("Setup Player island: "..g_savedata.player_base_island.index.." \""..g_savedata.player_base_island.name.."\"", true, 0)

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
			local ai_base_index = possible_ai_islands[math.random(math.ceil(#possible_ai_islands * 0.25))].index ---@type integer

			d.print("AI base index:"..tostring(ai_base_index), true, 0)

			--* set up ai base

			local ai_island = islands[ai_base_index]

			--local island_tile, is_success = s.getTile(ai_island.transform)

			local flag = s.spawnAddonComponent(m.multiply(ai_island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
			g_savedata.ai_base_island = Island.createIslandData(
				ai_island,
				ai_base_index,
				ISLAND.FACTION.AI,
				flag,
				0,
				{ oil = 7500, jet_fuel = 7500, diesel = 7500 },
				0
			)

			d.print("Setup AI Base island: "..g_savedata.ai_base_island.index.." \""..g_savedata.ai_base_island.name.."\"", true, 0)

			--g_savedata.ai_base_island.zones = tile_zones[island_tile.name]

			islands[ai_base_index] = nil

			d.print("setting up remaining neutral islands...", true, 0)

			local islands_count = table.length(islands) * g_savedata.settings.ISLAND_COUNT
			local spawned_neutral_islands = 0

			-- set up remaining neutral islands
			for island_index, island in pairs(islands) do
				local flag = s.spawnAddonComponent(m.multiply(island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
				local new_island = Island.createIslandData(
					island,
					island_index,
					ISLAND.FACTION.NEUTRAL,
					flag,
					g_savedata.settings.CAPTURE_TIME / 2,
					{ oil = 0, jet_fuel = 0, diesel = 0 }
				)

				--new_island.zones = tile_zones[island_tile.name]

				g_savedata.islands[new_island.index] = new_island
				spawned_neutral_islands = spawned_neutral_islands + 1
				d.print("Setup neutral island: "..new_island.index.." \""..island.name.."\"", true, 0)

				-- stop creating new islands if we've reached the island limit
				if spawned_neutral_islands >= islands_count then
					break
				end
			end

			d.print("Island initialization took: "..(millisecondsSince(start_time)/1000).."s", true, 0)
			start_time = s.getTimeMillisec()

			-- link the zones to the island which is closest to the zone
			local all_islands = {
				g_savedata.ai_base_island,
				g_savedata.player_base_island
			}

			local islands_by_name = {
				[g_savedata.ai_base_island.name] = g_savedata.ai_base_island,
				[g_savedata.player_base_island.name] = g_savedata.player_base_island
			}

			for _, island in pairs(g_savedata.islands) do
				table.insert(all_islands, island)
				islands_by_name[island.name] = island
			end

			for zone_type, zones in pairs(spawn_zones) do

				for _, zone in ipairs(zones) do

					-- first, check if this zone has a tag indicating which island it belongs to
					if Tags.has(zone.tags, "owner", true) then
						local owner_name = Tags.getValue(zone.tags, "owner", true)

						if not owner_name then
							d.print("zone says it has a owner, but failed to get the name of the owner!", true, 1)
							goto setupMain_setupIslands_setupZones_continue_zone
						end

						-- find the capture point which shares the name of the zone's owner override
						local owner_island = islands_by_name[owner_name]
						if owner_island then
							table.insert(owner_island.zones[zone_type], zone)
							goto setupMain_setupIslands_setupZones_continue_zone
						end
					end
				
					local closest_island = all_islands[1]
					local closest_distance = matrix.xzDistance(zone.transform, closest_island.transform)
					for island_index = 2, #all_islands do
						local island = all_islands[island_index]
						local island_distance = matrix.xzDistance(zone.transform, island.transform)
						if closest_distance > island_distance then
							closest_distance = island_distance
							closest_island = island
						end
					end

					-- add to the island which was closest, if its within 2000m
					if closest_distance <= 2000 then
						table.insert(closest_island.zones[zone_type], zone)
					end

					::setupMain_setupIslands_setupZones_continue_zone::
				end
			end

			d.print("Spawn zone linking took: "..(millisecondsSince(start_time)/1000).."s", true, 0)
						
			d.print("setting up additional data...")
			start_time = s.getTimeMillisec()

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

			-- calculate number of islands to capture
			local islands_to_capture = math.floor(islands_count * g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT)

			-- AI captures set amount of islands
			for i = 1, islands_to_capture do
				local t, _ = Objective.getIslandToAttack()
				t.capture_timer = 0 -- causes the AI to capture nearest ally
				t.faction = ISLAND.FACTION.AI
				t.cargo = {
					oil = math.random(550, 2000),
					jet_fuel = math.random(550, 2000),
					diesel = math.random(550, 2000)
				}
			end

			d.print("Additional data setup took: "..(millisecondsSince(start_time)/1000).."s", true, 0)
			d.print("completed setting up world!", true, 0)

			d.print("spawning initial ai vehicles...", true, 0)
			start_time = s.getTimeMillisec()
			for i = 1, g_savedata.settings.AI_INITIAL_SPAWN_COUNT * math.ceil(math.clamp(g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT, 1, #g_savedata.islands - 1)/2) do
				v.spawnRetry(nil, nil, true, nil, nil, 5) -- spawn initial ai
			end
			d.print("all initial ai vehicles spawned! Took "..(millisecondsSince(start_time)/1000).."s", true, 0)
		else
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for _, vehicle_object in pairs(squad.vehicles) do

					-- Reset map for all of the vehicles
					s.removeMapObject(-1, vehicle_object.ui_id)
					s.removeMapLabel(-1, vehicle_object.ui_id)
					s.removeMapLine(-1, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end

					-- Reset the transform histories.
					vehicle_object.transform_history = {}
				end
			end
			s.removeMapObject(-1, g_savedata.player_base_island.ui_id)
			s.removeMapObject(-1, g_savedata.ai_base_island.ui_id)
		end

		start_time = s.getTimeMillisec()
		bindedSetupMain(is_world_create)
		d.print("bindedSetupMain took: "..(millisecondsSince(start_time)/1000).."s", true, 0)
	end

	g_savedata.info.setup = true
	-- this one will reset every reload/load of the world, this ensures that tracebacks wont be enabled before setupMain is finished.
	addon_setup = true

	for debug_type, debug_setting in pairs(g_savedata.debug) do
		if (debug_setting.needs_setup_on_reload and debug_setting.enabled) or (is_world_create and debug_setting.default) then
			local debug_id = d.debugIDFromType(debug_type)

			if debug_setting.needs_setup_on_reload then
				d.handleDebug(debug_id, true, 0)
			end

			d.setDebug(debug_id, -1, true)
		end
	end

	d.print(("%s%.3f%s"):format("ICM setup complete! took: ", millisecondsSince(world_setup_time)/1000, "s"), true, 0)
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
		IslandRegistry.setFaction(island, ISLAND.FACTION.AI)
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
				Squad.setCommand(squad, SQUAD.COMMAND.NONE) -- free squads from objective
			end
		end
	-- set it to player
	elseif faction_to_set == ISLAND.FACTION.PLAYER then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
		IslandRegistry.setFaction(island, ISLAND.FACTION.PLAYER)
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
		for _, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	-- set it to neutral
	elseif faction_to_set == ISLAND.FACTION.NEUTRAL then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME/2
		IslandRegistry.setFaction(island, ISLAND.FACTION.NEUTRAL)
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
		for _, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	elseif island.capture_timer > g_savedata.settings.CAPTURE_TIME then -- if its over 100% island capture
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
	elseif island.capture_timer < 0 then -- if its less than 0% island capture
		island.capture_timer = 0
	end
end

function onPlayerJoin(steam_id, name, peer_id)

	if not g_savedata.info.setup then
		d.print("Setting up ICM for the first time, this may take a few seconds.", false, 0, peer_id)
	end

	eq.queue(
		function()
			return is_dlc_weapons and addon_setup
		end,
		function(self)

			local peer_id = self:getVar("peer_id")
			local steam_id = self:getVar("steam_id")

			Players.onJoin(steam_id, peer_id)

			warningChecks(peer_id)

			for _, island in pairs(g_savedata.islands) do
				updatePeerIslandMapData(peer_id, island)
			end
	
			s.removeMapObject(peer_id, g_savedata.ai_base_island.ui_id)
			s.addMapObject(peer_id, g_savedata.ai_base_island.ui_id, 0, 10, g_savedata.ai_base_island.transform[13], g_savedata.ai_base_island.transform[15], 0, 0, 0, 0, g_savedata.ai_base_island.name.." ("..g_savedata.ai_base_island.faction..")", 1, "", 255, 0, 0, 255)
	
			s.removeMapObject(peer_id, g_savedata.player_base_island.ui_id)
			s.addMapObject(peer_id, g_savedata.player_base_island.ui_id, 0, 10, g_savedata.player_base_island.transform[13], g_savedata.player_base_island.transform[15], 0, 0, 0, 0, g_savedata.player_base_island.name.." ("..g_savedata.player_base_island.faction..")", 1, "", 0, 255, 0, 255)
		
			local player = Players.dataBySID(steam_id)

			if player then
				for debug_type, debug_data in pairs(g_savedata.debug) do
					if debug_data.auto_enable then
						d.setDebug(d.debugIDFromType(debug_type), peer_id, true)
					end
				end
			end
		end,
		{
			peer_id = peer_id,
			steam_id = tostring(steam_id)
		},
		1,
		-1
	)
end

function onVehicleDamaged(vehicle_id, amount, x, y, z, body_id)
	if not is_dlc_weapons then
		return
	end

	-- get the group_id of this vehicle.
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil.
	if not group_id then
		d.print(("Vehicle %s was damaged, but getting it's group_id failed!"):format(vehicle_id), true, 1)
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
			-- (?) Doesn't do anything if the player is nearby since target_vehicle_id will be nil. Is this intended?
			local valid_ai_vehicles = {}
			local nearby_ai_vehicles = SpatialGrid.query(ai_vehicles_grid, player_vehicle.transform[13], player_vehicle.transform[15], 2500)
			for _, ai_group_id in pairs(nearby_ai_vehicles) do
				local vehicle_object, _, _ = Squad.getVehicle(ai_group_id)
				if vehicle_object and vehicle_object.target_vehicle_id == vehicle_id and vehicle_object.state.is_simulating then
					valid_ai_vehicles[ai_group_id] = vehicle_object
				end
			end

			-- <valid ai> = all the enemy ai vehicles within 3000m of the player, and that are targeting the player
			-- <ai amount> = number of <valid ai>
			--
			-- for all the <valid ai>, add the damage dealt to the player / <ai_amount> to their damage dealt property
			-- this is used to tell if that vehicle, the type of vehicle, its strategy and its role was effective
			local valid_ai_amount = table.length(valid_ai_vehicles)
			for _, vehicle_object in pairs(valid_ai_vehicles) do
				-- ensure that the damage dealt field for this group_id is filled.
				vehicle_object.damage_dealt[group_id] = vehicle_object.damage_dealt[group_id] or 0
				vehicle_object.damage_dealt[group_id] = vehicle_object.damage_dealt[group_id] + amount/valid_ai_amount
			end
		end

	else

		local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)

		if vehicle_object and squad_index then

			--[[VehicleFires.onAIVehicleDamaged(
				vehicle_id,
				{
					x = x,
					y = y,
					z = z
				},
				amount
			)]]

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
					d.print("Killing vehicle "..group_id.." instantly, as the damage it took is over twice its max health", true, 0)
					v.kill(vehicle_object, true)
				elseif damage_prev <= enemy_hp and vehicle_object.current_damage > enemy_hp then
					d.print("Killing vehicle "..group_id.." as it took too much damage", true, 0)
					v.kill(vehicle_object)
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

		local group_id = VehicleGroup.getGroupID(vehicle_id)

		-- Ensure the group_id is not nil
		if not group_id then
			d.print(("Vehicle %s was teleported, but getting it's group_id failed!"):format(vehicle_id), true, 1)
			return
		end

		-- updates the vehicle's position
		local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)
		if squad_index then
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[13] = x
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[14] = y
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[15] = z

			--d.print(("Vehicle %s from group %s was teleported to %0.1fx, %0.1fy, %0.1fz."):format(vehicle_id, group_id, x, y, z), true, 0)
		end
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if not is_dlc_weapons then
		return
	end

	if pl.isPlayer(peer_id) then
		d.print("Player Spawned Vehicle "..vehicle_id, true, 0)

		-- player spawned vehicle
		---@cast vehicle_id number
		---@class PLAYER_VEHICLE
		g_savedata.player_vehicles[vehicle_id] = {
			current_damage = 0,
			damage_threshold = 100,
			death_pos = nil,
			ui_id = server.getMapID() --[[@as SWUI_ID]],
			mass = nil, ---@type number?
			voxels = nil, ---@type number?
			transform = nil, ---@type SWMatrix?
		}

		return
	end
end

function onVehicleDespawn(vehicle_id, peer_id)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id] = nil
			SpatialGrid.remove(player_vehicles_grid, vehicle_id)

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

	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil
	if not group_id then
		d.print(("Vehicle %s was despawned, but getting it's group_id failed!"):format(vehicle_id), true, 1)
		return
	end

	--[[
		Don't despawn the vehicle if the vehicle_id that was despawned, is not the main vehicle_id of this vehicle.
	]]

	-- Get the main vehicle_id.
	local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

	-- ensure we got the main_vehicle_id
	if not main_vehicle_id then
		d.print("(onVehicleDespawn) main_vehicle_id is nil", true, 1)
		return
	end

	-- If the vehicle_ids are not equal, return, as it wasn't the main_vehicle_id which was despawned.
	if main_vehicle_id ~= vehicle_id then
		return
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)
	d.print("(onVehicleDespawn) group_id: "..group_id.." peer_id: "..peer_id, true, 0)
	if vehicle_object and squad_index then
		d.print("(onVehicleDespawn) AI vehicle: "..vehicle_object.name.." ("..group_id..")", true, 0)
		--VehicleFires.onAIVehicleDespawn(vehicle_id)
		cleanVehicle(squad_index, group_id)
	elseif vehicle_object or squad then
		d.print("(onVehicleDespawn) AI vehicle: "..group_id.." does not have a squad index! squad: "..(squad and "exists" or "doesn't exist").." vehicle_object: "..(vehicle_object and "exists" or "doesn't exist"), true, 0)
	end
end

--- @param squad_index integer
--- @param group_id integer
function cleanVehicle(squad_index, group_id)
	-- get the squadron
	local squadron = Squad.getSquadFromIndex(squad_index)

	-- squadron does not exist
	if not squadron then
		d.print(("(cleanVehicle) Squadron %s doesn't exist! Was trying to clean vehicle with group_id %s"):format(squad_index, group_id), true, 1)
		return
	end

	-- get the vehicle_object
	local vehicle_object = squadron.vehicles[group_id]

	if not vehicle_object then
		d.print(("(cleanVehicle) vehicle_object %s doesn't exist! Was trying to clean vehicle from squadron %s"):format(group_id, squad_index), true, 1)
		return
	end

	-- Cleanup the vehicle's map debug
	d.print("cleaning vehicle: "..group_id, true, 0)

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
	g_savedata.sweep_and_prune.ai_pairs[group_id] = nil

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

	-- Remove it from the spatial grid
	SpatialGrid.remove(ai_vehicles_grid, group_id)

	-- Despawn all survivors
	for _, object_id in pairs(vehicle_object.survivors) do
		s.despawnObject(object_id, true)
	end

	-- Despawn all fires
	if vehicle_object.fire_id ~= nil then
		s.despawnObject(vehicle_object.fire_id, true)
	end

	-- Remove the vehicle from its current squad
	Squad.removeVehicle(squadron, vehicle_object)
end

function onVehicleUnload(vehicle_id)
	if not is_dlc_weapons then
		d.print("(onVehicleUnload) is_dlc_weapons is false", true, 0)
		return
	end

	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil
	if not group_id then
		d.print(("Vehicle %s was unloaded, but getting it's group_id failed!"):format(vehicle_id), true, 1)
		return
	end

	local island, got_island = Island.getDataFromGroupID(group_id)
	if got_island and island then
		d.print(("Island %s was unloaded"):format(island.name), true, 0)
		g_savedata.loaded_islands[island.index] = nil
		return
	end

	local vehicle_object, squad_index, _ = Squad.getVehicle(group_id)

	if squad_index and vehicle_object then

		--[[
			Don't mark the vehicle as unloaded if the vehicle_id that was unloaded, is not the main vehicle_id of this vehicle.
		]]

		-- Get the main vehicle_id.
		local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

		-- ensure we got the main_vehicle_id
		if not main_vehicle_id then
			d.print("(onVehicleUnload) main_vehicle_id is nil", true, 1)
			return
		end

		-- If the vehicle_ids are not equal, return, as it wasn't the main_vehicle_id which was despawned.
		if main_vehicle_id ~= vehicle_id then
			return
		end

		-- reset it's transform history
		vehicle_object.transform_history = {}

		if vehicle_object.is_killed == true then
			cleanVehicle(squad_index, group_id)
		else
			d.print("(onVehicleUnload): set vehicle "..group_id.." pseudo. Name: "..vehicle_object.name, true, 0)
			vehicle_object.state.is_simulating = false
		end
	end
end

function setVehicleKeypads(group_id, vehicle_object, squad)
	local squad_vision = squadGetVisionData(squad)
	local target = nil

	local function setKeypad(group_id, keypad_name, value)
		local vehicle_ids = server.getVehicleGroup(group_id)

		if not vehicle_ids then
			d.print(("<line>: Failed to get vehicle group for the group_id: %s"):format(group_id), true, 1)
			return
		end

		if type(vehicle_ids) ~= "table" then
			d.print(("<line>: vehicle_ids is not a table? value: %s type: %s"):format(vehicle_ids, type(vehicle_ids)), true, 1)
			return
		end

		-- Go through each of the vehicles in this group.
		for vehicle_index = 1, #vehicle_ids do
			local vehicle_id = vehicle_ids[vehicle_index]
			-- set the keypad on each vehicle in this group
			server.setVehicleKeypad(vehicle_id, keypad_name, value)
		end
	end

	if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
		target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj

		local target_vehicle_id = vehicle_object.target_vehicle_id

		if g_savedata.player_vehicles[target_vehicle_id].mass then -- target vehicle's mass
			setKeypad(group_id, "AI_TARGET_MASS", g_savedata.player_vehicles[target_vehicle_id].mass)
		end

	elseif pl.isPlayer(vehicle_object.target_player_id) and squad_vision.visible_players_map[vehicle_object.target_player_id] then

		target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
		setKeypad(group_id, "AI_TARGET_MASS", 50) -- player's mass

	else
		setKeypad(group_id, "AI_TARGET_MASS", 0) -- no target
	end
	if target then -- set the target's position on keypads
		setKeypad(group_id, "AI_TARGET_X", target.last_known_pos[13])
		setKeypad(group_id, "AI_TARGET_Y", target.last_known_pos[14])
		setKeypad(group_id, "AI_TARGET_Z", target.last_known_pos[15])
	end
end

--[[function onObjectLoad(object_id)
	local object_data = server.getObjectData(object_id)

	if object_data.object_type == 58 then -- fire
		VehicleFires.onFireSpawn(object_id, object_data)
	end
end]]

--[[
function onSpawnAddonComponent(id, name, type, addon_index)
	d.print("(onSpawnAddonComponent) id: "..tostring(id).."\nname: "..tostring(name).."\ntype: "..tostring(type).."\naddon_index: "..tostring(addon_index), true, 0)
end]]

--[[function onCharacterSit(object_id, vehicle_id, seat_name)
	d.print(("(onCharacterSit) object_id: %i\nvehicle_id: %i\nseat_name: %s"):format(object_id, vehicle_id, seat_name))
end]]

-- called whenever an AI is properly spawned, data set, and set into seat.
function onCharacterPrepared(object_id, vehicle_id, seat_name)

	-- get the group_id this vehicle is in
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- check if we got the group_id
	if not group_id then
		d.print(("(onCharacterPrepared) failed to get group_id for vehicle_id: %s"):format(vehicle_id), true, 0)
		return
	end

	local vehicle_object, _, squad = Squad.getVehicle(group_id)

	-- check if we got the vehicle_object
	if not vehicle_object then
		d.print(("(onCharacterPrepared) failed to get vehicle_object for group_id: %s"):format(group_id), true, 0)
		return
	end

	-- check if we got the squad
	if not squad then
		d.print(("(onCharacterPrepared) failed to get squad for group_id: %s"):format(group_id), true, 0)
		return
	end

	vehicle_object._prepared_survivors = vehicle_object._prepared_survivors or {}
	table.insert(vehicle_object._prepared_survivors, object_id)

	-- if we've prepared all of our survivors
	if #vehicle_object._prepared_survivors == #vehicle_object.survivors then
		vehicle_object._prepared_survivors = nil
		d.print("(onCharacterPrepared) all characters prepared!", true, 0)
		squadInitVehicleCommand(squad, vehicle_object) -- init their commands
	end
end

function onVehicleLoad(vehicle_id)
	-- return if the addon is disabled
	if not is_dlc_weapons then
		return
	end

	-- if this is the players vehicle, get data on it
	if g_savedata.player_vehicles[vehicle_id] ~= nil then
		local player_vehicle_data = s.getVehicleComponents(vehicle_id)
		if player_vehicle_data.voxels then
			g_savedata.player_vehicles[vehicle_id].mass = player_vehicle_data.mass
			g_savedata.player_vehicles[vehicle_id].voxels = player_vehicle_data.voxels
			g_savedata.player_vehicles[vehicle_id].damage_threshold = player_vehicle_data.voxels / 4
			g_savedata.player_vehicles[vehicle_id].transform = s.getVehiclePos(vehicle_id)
		end
		return
	end

	-- get the vehicle's group_id
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	if not group_id then
		return
	end

	-- set tooltips for main islands, and mark the island as loaded
	local island, got_island = Island.getDataFromGroupID(group_id)
	if got_island and island then
		g_savedata.loaded_islands[island.index] = true

		if island.index == g_savedata.ai_base_island.index then
			s.setVehicleTooltip(vehicle_id, "AI Main Base, Cannot be Captured.")
		elseif island.index == g_savedata.player_base_island.index then
			s.setVehicleTooltip(vehicle_id, "Your Main Base, Cannot be Captured by AI.")
		end
		return
	end

	-- check if the ai needs to purchase this vehicle
	local vehicle_object, _, _ = Squad.getVehicle(group_id)

	if vehicle_object then
		d.print("(onVehicleLoad) AI Vehicle Loaded: "..tostring(vehicle_object.name), true, 0)
		local prefab, _ = v.getPrefab(vehicle_object.name)

		if not prefab or not prefab.fully_created then
			v.createPrefab(group_id)
		end 

		if vehicle_object.costs.buy_on_load then
			local _, _, was_purchased = v.purchaseVehicle(vehicle_object.name, vehicle_object.home_island.name, vehicle_object.costs.purchase_type)
			if was_purchased then
				vehicle_object.costs.buy_on_load = false
			elseif vehicle_object.costs.purchase_type == 0 then
				d.print("(onVehicleLoad) unable to afford "..vehicle_object.name..", killing vehicle "..group_id, true, 0)
				v.kill(vehicle_object, true, true)
			end
		end
	end

	-- say the vehicle has loaded
	-- spawn the AI npcs if they've not yet been spawned
	-- and make sure its not spawning inside another vehicle
	if vehicle_object then
		d.print("(onVehicleLoad) set vehicle simulating: "..group_id, true, 0)
		d.print("(onVehicleLoad) vehicle name: "..vehicle_object.name, true, 0)
		vehicle_object.state.is_simulating = true

		if #vehicle_object.survivors == 0 then
			vehicle_object.survivors = c.createAndSetCharactersIntoSeat(vehicle_id, c.valid_seats.enemy_ai)
		end

		local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

		-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
		local vehicles_spawning_distance = vehicle_object.spawning_transform.distance or DEFAULT_SPAWNING_DISTANCE
		local nearby_ai_vehicles = SpatialGrid.query(ai_vehicles_grid, vehicle_object.transform[13], vehicle_object.transform[15], math.max(vehicles_spawning_distance, 200)) --Use a large query radius because we dont know what the other vehicles spawning_distance is
		for _, checking_group_id in pairs(nearby_ai_vehicles) do
			if checking_group_id ~= group_id then
				checking_vehicle_object, _, _ = Squad.getVehicle(checking_group_id)
				if checking_vehicle_object and m.distance(vehicle_object.transform, checking_vehicle_object.transform) < vehicles_spawning_distance + checking_vehicle_object.spawning_transform.distance then
					if not vehicle_object.path[2] then
						d.print("(onVehicleLoad) cancelling spawning vehicle, due to its proximity to vehicle "..group_id, true, 1)

						-- refund the cargo to the island which was sending the cargo
						Cargo.refund(group_id)

						v.kill(vehicle_object, true, true)
						return
					else
						v.teleport(vehicle_object.group_id, m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z))
						break
					end
				end
			end
		end

		--? check if this is a cargo vehicle, if so then set the cargo in its tanks
		if g_savedata.cargo_vehicles[group_id] then
			if main_vehicle_id then
				--* set the cargo in its tanks
				local large_tank_capacity = 703.125

				for tank_set = 1, 3 do
					for tank_id = 0, (vehicle_object.cargo.capacity/large_tank_capacity) - 1 do

						Cargo.setTank(main_vehicle_id, "RESOURCE_TYPE_"..(tank_set-1).."_"..tank_id, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].amount/(vehicle_object.cargo.capacity/large_tank_capacity), true)
					end
					Cargo.setKeypad(main_vehicle_id, "RESOURCE_TYPE_"..(tank_set-1), g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type)

					d.print(("set %sL of %s into tank set %i on cargo vehicle %i"):format(g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].amount, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type, tank_set, group_id), true, 0)
				end
			else
				d.print(("Could not find main_vehicle_id for cargo vehicle! group_id: %s"):format(group_id), true, 1)
			end
		end

		if vehicle_object.is_resupply_on_load then
			vehicle_object.is_resupply_on_load = false
			
			--Reset the vehicle state and reload					
			if main_vehicle_id then
				-- resetVehicleState current issues: it unseats all its crew, and other bodys inside it like missiles or torpedos will fall out or end up glitched inside it.
				-- also only works when the vehicles loaded
				-- s.resetVehicleState(main_vehicle_id)
				reload(main_vehicle_id)
			else
				d.print(("failed to resupply because main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
			end
		end

		d.print("(onVehicleLoad) #of survivors: "..tostring(#vehicle_object.survivors), true, 0)
		refuel(group_id)
	end
end

function tickGamemode(game_ticks)
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
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] = squad.target_island -- sets to check this vehicle with its target island in sweep and prune
					end
				end

				if not has_island then -- if it doesnt have a matching island
					if g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] then -- checks if it is in the pre_pairs table
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] = nil -- removes it from the pre_pairs table
					end
				end
			end
		end
	end

	-- tick capture rates
	if isTickID(0, CAPTURE_TICK_RATE) then -- ticks the time it should take to move 0.25%
		-- check all ai that are within the capture radius
		for group_id, island in pairs(g_savedata.sweep_and_prune.ai_pairs) do
			local vehicle_object, _, _ = Squad.getVehicle(group_id)
			if vehicle_object then

				local capture_radius = island.faction == ISLAND.FACTION.AI and CAPTURE_RADIUS or CAPTURE_RADIUS / 1.5 -- capture radius is normal if the ai owns the island, otherwise its / 1.5

				-- if the ai vehicle is within the capture radius
				-- and the island is not the ai's main island
				-- and the island is not the player's main island
				if m.xzDistance(vehicle_object.transform, island.transform) <= capture_radius and island.index ~= g_savedata.ai_base_island.index and island.index ~= g_savedata.player_base_island.index then
					g_savedata.islands[island.index].ai_capturing = g_savedata.islands[island.index].ai_capturing + 1
				end
			else
				d.print("(tickGamemode) vehicle_object is nil! Group ID: "..tostring(group_id).."\nRemoving from sweep and prune pairs to check", true, 1)
				--local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
				--d.print("vehicle existed before? "..tostring(vehicle_object ~= nil), true, 0)
				g_savedata.sweep_and_prune.ai_pairs[group_id] = nil
				--local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
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
				--[[
					
					! Disabled, as the code would likely error before, as island_index is not defined.
				
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
				]]
				end
			end

			for island_index, island in pairs(player_pairs.data.islands) do
				g_savedata.islands[island_index].players_capturing = island.number_capturing
			end
		end

		-- tick spawning for ai vehicles (to remove as will be replaced to be dependant on logistics system)
		g_savedata.ai_base_island.production_timer = g_savedata.ai_base_island.production_timer + CAPTURE_TICK_RATE * game_ticks
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

			-- Update capture timer based on who's capturing
			local contested_before = island.is_contested
			CaptureSystem.updateCaptureTimer(island, island.ai_capturing, island.players_capturing, game_ticks)

			-- Check if island should change faction and trigger events if it did
			local new_faction = CaptureSystem.resolveFactionChange(island)
			if new_faction then
				captureIsland(island, new_faction, nil)
			end

			-- Notify if it just became contested
			if island.is_contested and not contested_before then
				s.notify(-1, "ISLAND CONTESTED", "An island is being contested!", 1)
				CaptureSystem.markDirty(island.index) -- So the tooltip updates
			end

			-- Build and set tooltip if its changed
			if CaptureSystem.checkAndClearDirty(island.index) then
				local capture_vehicle_tooltip = CaptureSystem.buildCaptureTooltip(island)
				s.setVehicleTooltip(island.flag_vehicle.id, capture_vehicle_tooltip)
			end

			updatePeerIslandMapData(-1, island)

			-- resets amount capping
			island.ai_capturing = 0
			island.players_capturing = 0
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
			if g_savedata.ai_base_island.zones.turrets then
				for _, turret_zone in pairs(g_savedata.ai_base_island.zones.turrets) do
					if turret_zone.is_spawned then ai_base_island_turret_count = ai_base_island_turret_count + 1 end
				end
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
---@param island ISLAND the island you want to update
---@param is_reset boolean? if you want it to just reset the map, which will remove the island from the map instead of updating it
function updatePeerIslandMapData(peer_id, island, is_reset)
	if is_dlc_weapons and g_savedata.info.setup then
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
					if island.zones.turrets then
						for _, turret_zone in pairs(island.zones.turrets) do
							if turret_zone.is_spawned then turret_amount = turret_amount + 1 end
						end
					end
					
					local debug_data = ""
					debug_data = debug_data.."\nScout Progress: "..math.floor(g_savedata.ai_knowledge.scout[island.name].scouted/scout_requirement*100).."%"
					debug_data = debug_data.."\n\nNumber of AI Capturing: "..island.ai_capturing
					debug_data = debug_data.."\nNumber of Players Capturing: "..island.players_capturing
					debug_data = debug_data.."\n\nLand Access:  "..(Tags.getValue(island.tags, "land_access", true) or "None")
					debug_data = debug_data.."\nOcean Access: "..(Tags.getValue(island.tags, "no_access", true) == "boat" and "None" or "Yes")
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

---@param squad squadron the squad to get the leader of.
---@return integer|nil vehicle_id the id of the leader's group, nil upon failure
---@return vehicle_object|nil vehicle_object the squad's leader, nil upon failure
---@deprecated
function getSquadLeader(squad)
	for vehicle_id, vehicle_object in pairs(squad.vehicles) do
		return vehicle_id, vehicle_object
	end
	d.print("warning: empty squad "..squad.vehicle_type.." detected", true, 1)
end

--- Returns the closest squad which either has no command or is patrolling
--- @param transform SWMatrix the position to check from
--- @param override_command boolean? if true, will ignore the squad's current command when searching
--- @return squadron|nil closest_free_squad the closest free squad, nil if none found
--- @return integer closest_free_squad_index the index of the closest free squad, -1 if none found
function getNearbySquad(transform, override_command)

	local closest_free_squad = nil
	local closest_free_squad_index = -1
	local closest_dist = 999999999

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad.command == SQUAD.COMMAND.NONE
		or squad.command == SQUAD.COMMAND.PATROL
		or override_command then

			squad_leader = Squad.getLeader(squad)

			-- ensure we got the squad leader
			if not squad_leader then
				-- skip this squad if we failed to get it.
				goto next_squad
			end

			local squad_vehicle_transform = squad_leader.transform
			local distance = m.distance(transform, squad_vehicle_transform)

			if distance < closest_dist then
				closest_free_squad = squad
				closest_free_squad_index = squad_index
				closest_dist = distance
			end
		end

		::next_squad::
	end

	return closest_free_squad, closest_free_squad_index
end

function tickAI(game_ticks)
	d.startProfiler("tickAI()", true)
	-- allocate squads to islands
	for island_index, island in pairs(g_savedata.islands) do
		if isTickID(island_index, 60) then
			if island.faction == ISLAND.FACTION.AI then
				if island.assigned_squad_index == -1 then
					local squad, squad_index = getNearbySquad(island.transform)

					if squad ~= nil and Squad.canAccessIsland(squad, island) then
						Squad.setCommand(squad, SQUAD.COMMAND.DEFEND, island)
						island.assigned_squad_index = squad_index
						d.print("assigned squad "..squad_index.." to defend "..island.name, true, 0)
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

		-- gather squad counts
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

		-- logic for attacking an island
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
								local squad_leader = Squad.getLeader(squad)
								if not squad_leader then
									if squad_index ~= RESUPPLY_SQUAD_INDEX then
										-- delete the squad as its empty
										Squad.disband(squad_index, "tickAI() empty squad cleanup")
									else
										Squad.setCommand(squad, SQUAD.COMMAND.RESUPPLY)
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
									else
										-- terrible check to ensure the AI doesn't get stuck trying to attack an island which the boats cannot reach, resulting in them never attacking.
										local any_can_path = false
										
										for _, vehicle_object in pairs(squad.vehicles) do
											if #vehicle_object.path > 1 then
												any_can_path = true
												break
											end
										end

										-- cannot reach destination, just say they're ready to avoid soft locking the AI's ability to attack.
										if not any_can_path then
											boats_ready = boats_ready + 1
										end
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
						if (air_total + boats_total + land_total) < MAX_ATTACKING_SQUADS then
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.PATROL or squad.command == SQUAD.COMMAND.DEFEND and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and squad.role ~= "defend" then
									if (air_total + boats_total + land_total) < MAX_ATTACKING_SQUADS then
										if Squad.canAccessIsland(squad, ally_island) and Squad.canAccessIsland(squad, objective_island) then
											if squad.vehicle_type == VEHICLE.TYPE.BOAT then
												boats_total = boats_total + 1
												setSquadCommandStage(squad, objective_island)
											else
												air_total = air_total + 1
												setSquadCommandStage(squad, ally_island)
											end
										end
									end
								end
							end
						end
						
			
						g_is_air_ready = air_total == 0 or air_ready / air_total >= 0.5
						g_is_boats_ready = Tags.has(ally_island.tags, "no-access=boat") or Tags.has(objective_island.tags, "no-access=boat") or boats_total == 0 or boats_ready / boats_total >= 0.25
						local is_attack = (g_count_attack / g_count_squads) >= 0.25 and g_count_attack >= MIN_ATTACKING_SQUADS and g_is_boats_ready and g_is_air_ready
						
						if is_attack then
							-- The AI is now attacking. Set all staging squads to attack!
							g_savedata.is_attack = is_attack
			
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.STAGE then
									if Squad.canAccessIsland(squad, objective_island) then -- makes sure boats can attack that island
										Squad.setCommand(squad, SQUAD.COMMAND.ATTACK, objective_island)
									end
								elseif squad.command == SQUAD.COMMAND.ATTACK then
									if squad.target_island.faction == ISLAND.FACTION.AI then
										-- if they are targeting their own island
										squad.target_island = objective_island
									end
								end
							end
						else
							-- The AI is not yet ready to attack. Set more squads to staging if possible.
							for _, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.NONE and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and (air_total + boats_total + land_total) < MAX_ATTACKING_SQUADS then
									if squad.vehicle_type == VEHICLE.TYPE.BOAT then -- send boats ahead since they are slow
										if not Tags.has(objective_island.tags, "no-access=boat") then -- if boats can attack that island
											Squad.setCommand(squad, SQUAD.COMMAND.STAGE, objective_island)
											boats_total = boats_total + 1
										end
									else
										Squad.setCommand(squad, SQUAD.COMMAND.STAGE, ally_island)
										air_total = air_total + 1
									end
								elseif squad.command == SQUAD.COMMAND.STAGE and squad.vehicle_type == VEHICLE.TYPE.BOAT and not Tags.has(objective_island.tags, "no-access=boat") and (air_total + boats_total + land_total) < MAX_ATTACKING_SQUADS then
									Squad.setCommand(squad, SQUAD.COMMAND.STAGE, objective_island)
									-- Assuming it does this so that if the island changes, it will update. Why only boats?
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
									local spawned, fail_reason = v.spawn("scout", nil, nil, nil, 3)
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
										d.print("Failed to spawn scout vehicle: "..tostring(fail_reason), true, 0)
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
								Squad.setCommand(squad, SQUAD.COMMAND.DEFEND)
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
				local reachable_island = Squad.getRandomReachableIsland(squad)
				if reachable_island ~= nil then
					if (g_count_patrol / g_count_squads) < 0.5 then
						g_count_patrol = g_count_patrol + 1
						d.print("Assigining squad "..squad_index.." to patrol", true, 0)
						setSquadCommandPatrol(squad, reachable_island)
					else
						d.print("Too much patroling so not assigning squad "..squad_index.." to patrol", true, 0)
						setSquadCommandDefend(squad, reachable_island)
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

-- moves a vehicle over to another squad
---@param vehicle_object vehicle_object the vehicle to transfer
---@param squad_index integer the squad's index that you want to transfer the vehicle to
---@param force ?boolean if you want to force the vehicle over to the squad, bypassing any limits
---@depricated
function transferToSquadron(vehicle_object, squad_index, force)
	if not vehicle_object then
		d.print("(transferToSquadron) vehicle_object is nil!", true, 1)
		return
	end

	if not squad_index then
		local debug_data = ""
		if vehicle_object then
			if vehicle_object.group_id then
				debug_data = debug_data.." vehicle_id: "..tostring(vehicle_object.group_id)

				if g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] then
					debug_data = debug_data.." squad_index: "..tostring(g_savedata.ai_army.squad_vehicles[vehicle_object.group_id])
				end
			end
		end

			
		d.print("(transferToSquadron) squad_index is nil! debug_data:"..debug_data, true, 1)
		return
	end

	local old_squad_index, old_squad = Squad.getSquadFromGroup(vehicle_object.group_id)

	if not old_squad_index then
		d.print("(transferToSquadron) old_squad_index is nil! vehicle_id: "..tostring(vehicle_object.group_id), true, 1)
	end

	vehicle_object.previous_squad = old_squad_index

	--? make sure new squad exists
	if not g_savedata.ai_army.squadrons[squad_index] then
		--* create the squad as it doesn't exist
		squad_index, squad_created = Squad.create(squad_index, vehicle_object)
		if not squad_created then
			d.print("(transferToSquadron) failed to create squad!", true, 1)
		end
	end

	--* add to new squad
	g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = squad_index
	g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.group_id] = vehicle_object

	--* remove from old squad
	if old_squad_index and g_savedata.ai_army.squadrons[old_squad_index] and g_savedata.ai_army.squadrons[old_squad_index].vehicles then
		g_savedata.ai_army.squadrons[old_squad_index].vehicles[vehicle_object.group_id] = nil
		--? if the squad is now empty then delete the squad and if its not the resupply squad
		if table.length(g_savedata.ai_army.squadrons[old_squad_index].vehicles) == 0 and old_squad_index ~= RESUPPLY_SQUAD_INDEX then
			g_savedata.ai_army.squadrons[old_squad_index] = nil
		end
	end

	--local vehicle_object_test, squad_test, squad_index_test = Squad.getVehicle(vehicle_object.group_id)
	--d.print("(transferToSquadron) vehicle_object existed after? "..tostring(vehicle_object_test ~= nil), true, 0)

	d.print("(transferToSquadron) Transferred "..vehicle_object.name.."("..vehicle_object.group_id..") from squadron "..tostring(old_squad_index).." to "..squad_index, true, 0)
end

---@deprecated
function addToSquadron(vehicle_object)
	if vehicle_object then
		if not vehicle_object.is_killed then
			local new_squad = nil

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then -- do not automatically add to resupply squadron
					if Squad.addVehicle(squad, vehicle_object, false) then
						new_squad = squad
						break
					end
				end
			end

			if new_squad == nil then
				local new_squad_index, squad_created = Squad.create(nil, vehicle_object)

				new_squad = g_savedata.ai_army.squadrons[new_squad_index]
				Squad.addVehicle(new_squad, vehicle_object, true)
			end

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

function tickSquadrons(game_ticks)
	d.startProfiler("tickSquadrons()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, squadron_tick_rate) then
			-- clean out-of-action vehicles
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do

				if vehicle_object.is_killed and vehicle_object.death_timer ~= nil then
					vehicle_object.death_timer = vehicle_object.death_timer + 1

					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						if vehicle_object.death_timer >= g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER/squadron_tick_rate then
							d.print(("Cargo Vehicle %s has been killed for more than %s minutes, despawning"):format(vehicle_object.name, g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER/time.minute), true, 0)
							v.kill(vehicle_object, true, true)
						end
					elseif vehicle_object.role == SQUAD.COMMAND.SCOUT then
						if vehicle_object.death_timer >= (time.minute/4)/squadron_tick_rate then
							v.kill(vehicle_object, true)
						end
					else
						if vehicle_object.death_timer >= math.seededRandom(false, vehicle_id, 8, 90) then -- kill the vehicle after 8 - 90 seconds after dying
							v.kill(vehicle_object, true)
						end
					end
				end

				-- if pilot is incapacitated
				local c = s.getCharacterData(vehicle_object.survivors[1])

				--[[
					if npc exists
					and if the npc is incapacitaed or dead
					and if the vehicle its linked to isnt a cargo vehicle
					then kill the vehicle
				]]
				if c and (c.incapacitated or c.dead) and vehicle_object.role ~= SQUAD.COMMAND.CARGO and not vehicle_object.is_killed then
					v.kill(vehicle_object)
				end
			end

			-- check if a vehicle needs resupply, removing from current squad and adding to the resupply squad
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				for group_id, vehicle_object in pairs(squad.vehicles) do

					-- Get the main vehicle_id.
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

					-- Ensure we got the main vehicle_id
					if not main_vehicle_id then
						-- skip this vehicle if we failed to get it.
						goto next_vehicle
					end

					-- If this vehicle needs resupply.
					if isVehicleNeedsResupply(main_vehicle_id, "Resupply") then
						-- If this is a turret, then reload it.
						if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
							-- Reload the turret.
							reload(main_vehicle_id)

						-- Otherwise, transfer it to the resupply squad.
						else
							-- transfer the vehicle to the resupply squad
							Squad.transferToSquad(vehicle_object, RESUPPLY_SQUAD_INDEX, true)
							--transferToSquadron(g_savedata.ai_army.squadrons[squad_index].vehicles[group_id], RESUPPLY_SQUAD_INDEX, true)

							-- print a debug message saying it's leaving the squad to resupply.
							d.print(tostring(group_id).." leaving squad "..tostring(squad_index).." to resupply", true, 0)

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
					elseif isVehicleNeedsResupply(main_vehicle_id, "AI_NO_MORE_MISSILE") then -- if its out of missiles, then kill it
						if not vehicle_object.is_killed then
							v.kill(vehicle_object)
						end
					end

					-- check if the vehicle simply needs to reload from a disconnected ammo belt, barrel or box
					local vehicle_component_data, is_success = server.getVehicleComponents(main_vehicle_id)

					if is_success and vehicle_component_data.components and vehicle_component_data.components.guns then
						for gun_index = 1, #vehicle_component_data.components.guns do
							local gun_data = vehicle_component_data.components.guns[gun_index]

							-- if this is a gun that might need reloading
							if gun_data.ammo == 0 and (gun_data.name:match("^Ammo %d+$") or (gun_data.name:match("^Gunner %d+$"))) then

								-- the target weapons we can reload from
								local ammo_group = tonumber(table.pack(gun_data.name:gsub("[%a ]+", ""))[1])
								local target_pattern = ("Reserve Ammo %i"):format(ammo_group)
								for reserve_ammo_index = 1, #vehicle_component_data.components.guns do
									local reserve_ammo_data = vehicle_component_data.components.guns[reserve_ammo_index]

									-- we can reload from this weapon
									if gun_index ~= reserve_ammo_index and reserve_ammo_data.ammo ~= 0 and reserve_ammo_data.name:match(target_pattern) then
										-- move as much ammo as we can from the reserve ammo to the gun.
										local ammo_to_move = math.min(gun_data.capacity - gun_data.ammo, reserve_ammo_data.ammo)

										-- take that away from the reserve ammo container
										server.setVehicleWeapon(main_vehicle_id, reserve_ammo_data.pos.x, reserve_ammo_data.pos.y, reserve_ammo_data.pos.z, reserve_ammo_data.ammo - ammo_to_move)
										
										-- move that into the gun
										server.setVehicleWeapon(main_vehicle_id, gun_data.pos.x, gun_data.pos.y, gun_data.pos.z, gun_data.ammo + ammo_to_move)

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

					::next_vehicle::
				end
			else
				for group_id, vehicle_object in pairs(squad.vehicles) do

					-- Get the main vehicle_id.
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

					-- Ensure we got the main vehicle_id
					if not main_vehicle_id then
						-- skip this vehicle if we failed to get it.
						goto next_vehicle
					end

					if (vehicle_object.state.is_simulating and isVehicleNeedsResupply(main_vehicle_id, "Resupply") == false) or (not vehicle_object.state.is_simulating and vehicle_object.is_resupply_on_load) then
	
						Squad.transferToSquad(vehicle_object, vehicle_object.previous_squad, true)

						d.print(group_id.." resupplied. joining squad", true, 0)
					end
					::next_vehicle::
				end
			end

			--* tick behaviour and exit conditions
			if squad.command == SQUAD.COMMAND.CARGO and g_savedata.settings.CARGO_MODE then
				---@type CARGO_VEHICLE
				local convoy = nil
				for vehicle_index, vehicle_object in pairs(squad.vehicles) do
					if g_savedata.cargo_vehicles[vehicle_object.group_id] then
						local n_vehicle_object, n_squad_index, n_squad = Squad.getVehicle(vehicle_object.group_id)
						g_savedata.cargo_vehicles[vehicle_object.group_id].vehicle_data = n_vehicle_object
						convoy = g_savedata.cargo_vehicles[vehicle_object.group_id]
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
						local cargo_vehicle_node = g_savedata.ai_army.squadrons[squad_index].vehicles[convoy.vehicle_data.group_id].path[1]
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
					if vehicle_object.group_id ~= convoy.vehicle_data.group_id then
						--? if the cargo vehicle is on a new path
						if old_path ~= convoy.path_data.current_path then
							--* reset the path
							p.resetPath(vehicle_object)
						end
					end

					--d.print("convoy_index: "..convoy_index, true, 0)
					if convoy.convoy[convoy_index - 1] then -- if theres a vehicle behind this one

						local behind_vehicle_object, _, _ = Squad.getVehicle(convoy.convoy[convoy_index - 1])

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
										vehicle_object.speed.convoy_modifier = -(v.getTargetSpeed(vehicle_object, nil, nil, nil, nil, true))
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

									local vehicle_speed = v.getTargetSpeed(vehicle_object, nil, nil, nil, nil, true)

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
										vehicle_object.speed.convoy_modifier = -(v.getTargetSpeed(vehicle_object, nil, nil, nil, nil, true))
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

									local vehicle_speed = v.getTargetSpeed(vehicle_object, nil, nil, nil, nil, true)

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
						local waiting_vehicle_object, _, _ = Squad.getVehicle(convoy.convoy[vehicle_object.state.convoy.waiting_for])
						--d.print("waiting for "..(ticksSince(vehicle_object.state.convoy.changed_time)).."t...", true, 0)

						-- ensure we got the waiting vehicle object
						if not waiting_vehicle_object then
							-- skip this vehicle if we failed to get it.
							goto break_cargo_vehicle
						end

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
							if vehicle_object.group_id ~= convoy.vehicle_data.group_id then
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
						if vehicle_object.group_id ~= convoy.vehicle_data.group_id then

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
				local squad_leader = Squad.getLeader(squad)
				if squad_leader then
					if squad_leader.state.s ~= VEHICLE.STATE.PATHING then -- has finished patrol
						d.print("patrol squad leader of squad finished pathing", true, 0)
						Squad.setCommand(squad, SQUAD.COMMAND.NONE)
					end
				else
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						d.print("patrol squad missing leader", true, 1)
						d.print("deleting squad as its empty", true, 1)
						g_savedata.ai_army.squadrons[squad_index] = nil
						Squad.setCommand(squad, SQUAD.COMMAND.NONE)
					else
						Squad.setCommand(squad, SQUAD.COMMAND.RESUPPLY)
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
					Squad.setCommand(squad, SQUAD.COMMAND.NONE)
				elseif squad.target_island.faction ~= ISLAND.FACTION.AI then
					Squad.setCommand(squad, SQUAD.COMMAND.NONE)
				end
			elseif squad.command == SQUAD.COMMAND.RESUPPLY then

				g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].target_island = nil
				for group_id, vehicle_object in pairs(squad.vehicles) do
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)
					
					-- Ensure we got the main_vehicle_id
					if not main_vehicle_id then
						d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
						goto continue_resupply_squad_vehicle
					end

					if #vehicle_object.path == 0 then
						d.print("resupply mission recalculating target island for: "..group_id, true, 0)
						local ally_island = getResupplyIsland(vehicle_object.transform)
						p.resetPath(vehicle_object)
						p.addPath(vehicle_object, m.multiply(ally_island.transform, m.translation(math.random(-250, 250), CRUISE_HEIGHT + (vehicle_object.group_id % 10 * 20), math.random(-250, 250))))
					end
					
					if m.distance(g_savedata.ai_base_island.transform, vehicle_object.transform) < RESUPPLY_RADIUS then

						if vehicle_object.state.is_simulating then
							-- resupply ammo
							reload(main_vehicle_id)
						else
							vehicle_object.is_resupply_on_load = true
						end
					end

					for island_index, island in pairs(g_savedata.islands) do
						if island.faction == ISLAND.FACTION.AI then
							if m.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS then

								if vehicle_object.state.is_simulating then
									-- resupply ammo
									reload(main_vehicle_id)
								else
									vehicle_object.is_resupply_on_load = true
								end
							end
						end
					end
					::continue_resupply_squad_vehicle::
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
					Squad.setCommand(squad, SQUAD.COMMAND.NONE)
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

					local player_data = pl.dataBySID(vehicle_object.target_player_id)

					if player_data or vehicle_object.target_vehicle_id then
						local target_pos = nil
						local target_id = nil
						local target_type = ""
						if player_data then -- if its targeting a player
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
								s.setAITarget(vehicle_object.survivors[1], m.translation(target_pos[13], target_pos[14] - 5, target_pos[15]))

								if m.xzDistance(vehicle_object.transform, m.translation(target_pos[13], target_pos[14], target_pos[15])) < 100 then
									s.setAIState(vehicle_object.survivors[1], 0)
									s.setCharacterData(vehicle_object.survivors[1], 1, true, false)
									--d.print("murder.")
								else
									s.setAIState(vehicle_object.survivors[1], 2)
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
									p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] + math.max(target_pos[14] + (vehicle_object.group_id % 5) + 25, 75), target_pos[15]))
								end
							end
								
							for i, object_id in pairs(vehicle_object.survivors) do
								if target_type == "character" then
									s.setAITargetCharacter(object_id, target_id)
								elseif target_type == "vehicle" then
									s.setAITargetVehicle(object_id, target_id)
								end
	
								if i ~= 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
									if not g_air_vehicles_kamikaze or (vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE and vehicle_object.vehicle_type ~= VEHICLE.TYPE.HELI) then 
										s.setAIState(object_id, 1)
									end
								end
							end
						end
					end
				end

				if squad_vision:is_engage() == false then
					Squad.setCommand(squad, SQUAD.COMMAND.NONE)
				end
			end
		end
		::break_squadron::
	end
	d.stopProfiler("tickSquadrons()", true, "onTick()")
end

function tickVision(game_ticks)
	d.startProfiler("tickVision()", true)
	-- get the ai's vision radius
	
	local clock = s.getTime()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 240) then
				local weather = s.getWeather(vehicle_object.transform)
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
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad_index ~= RESUPPLY_SQUAD_INDEX then
			if isTickID(squad_index, 10) or table.length(squad.target_vehicles) > 0 then
				-- Reset all target visiblity state to investigate, if it is still visible then it will be set again below
				for player_vehicle_id, _ in pairs(squad.target_vehicles) do
					local player_vehicle = g_savedata.player_vehicles[player_vehicle_id]
					if player_vehicle.death_pos == nil then
						squad.target_vehicles[player_vehicle_id].state = TARGET_VISIBILITY_INVESTIGATE
					else
						squad.target_vehicles[player_vehicle_id] = nil
					end
				end

				-- For each squad vehicle, look for targets in range
				for group_id, vehicle_object in pairs(squad.vehicles) do
					local vehicle_transform = vehicle_object.transform
					local local_vision_radius = vehicle_object.vision.radius
					local has_sonar = vehicle_object.vision.is_sonar
					if vehicle_transform == nil then
						goto continue_vision_squad_vehicle
					end
					
					-- Spatial query for player vehicles which are within vision range
					local nearby_player_vehicles = SpatialGrid.query(
						player_vehicles_grid, 
						vehicle_transform[13], 
						vehicle_transform[15], 
						local_vision_radius
					)
					-- Loop over every nearby player vehicle found
					for _, player_vehicle_id in pairs(nearby_player_vehicles) do
						local player_vehicle = g_savedata.player_vehicles[player_vehicle_id]
						if not player_vehicle then goto continue_vision_player_vehicle end

						local player_vehicle_transform = player_vehicle.transform
						local current_vision_radius = local_vision_radius

						if player_vehicle_transform == nil then
							goto continue_vision_player_vehicle
						end

						-- Check if the player vehicle is dead
						if player_vehicle.death_pos ~= nil then
							-- Check if it can be brought back to life (has moved far enough from death position)
							if m.distance(player_vehicle.death_pos, player_vehicle.transform) > 500 then
								-- Can be brought back to life!
								player_vehicle.death_pos = nil
								if player_vehicle.voxels then
									player_vehicle.damage_threshold = player_vehicle.damage_threshold + player_vehicle.voxels / 10
								else
									--If for some reason the voxel data isn't set, still increase the threshold a bit so it doesn't immediately die again
									player_vehicle.damage_threshold = player_vehicle.damage_threshold * 1.3
								end
							else
								goto continue_vision_player_vehicle
							end
						end

						-- Adjust vision radius for conditions specific to the player vehicle
						if not has_sonar and player_vehicle_transform[14] < -1 then
							-- Reduce the player's sight level depending on the player's depth
							current_vision_radius = current_vision_radius * math.min(0.15 / (math.abs(player_vehicle_transform[14]) * 0.2), 0.15)
						end

						-- Check if the player vehicle is still within range after the vision radius adjustments
						local distance = m.distance(player_vehicle_transform, vehicle_transform)
						if distance < current_vision_radius then
							if squad.target_vehicles[player_vehicle_id] == nil then
								---@class TargetVehicle
								squad.target_vehicles[player_vehicle_id] = {
									state = TARGET_VISIBILITY_VISIBLE,
									last_known_pos = player_vehicle_transform
								}
							else
								local target_vehicle = squad.target_vehicles[player_vehicle_id]
								target_vehicle.state = TARGET_VISIBILITY_VISIBLE
								target_vehicle.last_known_pos = player_vehicle_transform
							end
						end
						::continue_vision_player_vehicle::
					end
					::continue_vision_squad_vehicle::
				end
			end
		end
	end

	--[[
	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		local player_vehicle_transform = player_vehicle.transform

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				--Squads targetting this player can bypass the throttling. That way, the target position keypads for AI vehicles stay updated
				if isTickID(squad_index, 20) or (squad.target_vehicles[player_vehicle_id] ~= nil) then
					-- reset target visibility state to investigate

					if squad.target_vehicles[player_vehicle_id] ~= nil then
						if player_vehicle.death_pos == nil then
							squad.target_vehicles[player_vehicle_id].state = TARGET_VISIBILITY_INVESTIGATE
						else
							squad.target_vehicles[player_vehicle_id] = nil
						end
					end

					-- check if target is visible to any vehicles
					for group_id, vehicle_object in pairs(squad.vehicles) do
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
									---@class TargetVehicle
									squad.target_vehicles[player_vehicle_id] = {
										state = TARGET_VISIBILITY_VISIBLE,
										last_known_pos = player_vehicle_transform
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
		end

		if isTickID(player_vehicle_id, 240) then
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
	end--]]

	-- analyse players
	for _, player in ipairs(s.getPlayers()) do
		local player_steam_id = tostring(player.steam_id)
		if player_steam_id then
			local player_transform = s.getPlayerPos(player.id)
			
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					if isTickID(squad_index, 10) or (squad.target_players[player_steam_id] ~= nil) then
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
									---@class TargetPlayer
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
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
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

function tickVehicles(game_ticks)
	d.startProfiler("tickVehicles()", true)
	local vehicle_update_tickrate = 30
	if isTickID(60, 60) then
		debug_mode_blinker = not debug_mode_blinker
	end

	-- save vehicle transform, and update vehicle debug
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do

			if not vehicle_object.state.is_simulating then
				goto continue_tickVehicles_updateTransform
			end

			local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

			-- ensure we got the main_vehicle_id
			if not main_vehicle_id then
				d.print("main_vehicle_id is nil", true, 1)
				goto continue_tickVehicles_updateTransform
			end

			vehicle_object.transform = server.getVehiclePos(main_vehicle_id)

			if not vehicle_object.transform then
				d.print("failed to get vehicle position for vehicle id " .. tostring(main_vehicle_id) .. "(group: "..tostring(group_id)..")", true, 1)
				goto continue_tickVehicles_updateTransform
			end

			vehicle_object.transform_history[getTickID(group_id, 120)] = vehicle_object.transform

			if d.getDebug(6) then
				local text = ""

				-- name
				text = text..vehicle_object.name
				
				-- Group ID
				text = text..("\nGroup ID: %s"):format(group_id)

				local pos_last = vehicle_object.transform_history[getTickID(group_id - 30, 120)]

				if pos_last then
					-- velocity
					local velocity = m.velocity(vehicle_object.transform, pos_last, 30)

					text = text..("\n\nVel: %0.3f"):format(velocity)

					local pos_second_last = vehicle_object.transform_history[getTickID(group_id - 60, 120)]
					if pos_second_last then
						-- acceleration
						local acceleration = m.acceleration(vehicle_object.transform, pos_last, pos_second_last, 30)

						text = text..("\nAccel: %0.3f"):format(acceleration)
					end
				end

				for peer_index, peer in pairs(s.getPlayers()) do
					if d.getDebug(6, peer.id) then
						if pos_last then
							server.setPopup(peer.id, vehicle_object.ui_id, "", true, text, 0, 0, 0, 2500, group_id)
						end
					end
				end
			end

			::continue_tickVehicles_updateTransform::
		end
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(group_id, vehicle_update_tickrate) then

				-- if air crash mode is enabled
				-- then we want to check if this vehicle is a plane or heli
				-- if it is, we want to see how much its moved
				-- and compare it to the previous time we checked, if its a large difference, then we make it explode.
				if g_savedata.settings.AIR_CRASH_MODE and vehicle_object.state.is_simulating then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then

						-- get its previous positions

						-- position from 30 (vehicle_update_tickrate) ticks ago
						local last_pos = vehicle_object.transform_history[getTickID(group_id - vehicle_update_tickrate, 120)]

						-- position from 60 (vehicle_update_tickrate*2) ticks ago
						local second_last_pos = vehicle_object.transform_history[getTickID(group_id - vehicle_update_tickrate * 2, 120)]

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
								d.print(("Vehicle %s (%i) Crashed! (total_vel_change: %s total_pos_change: %s)"):format(vehicle_object.name, group_id, total_vel_change, total_pos_change), true, 0)
								v.kill(vehicle_object, true)
								goto continue_vehicle
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
					modifier = 6
				end

				-- check if the vehicle has sunk or is under water
				if vehicle_object.transform[14] <= vehicle_object.sink_depth/modifier then --explosion_depths[vehicle_object.vehicle_type]/modifier then
					if vehicle_object.role ~= SQUAD.COMMAND.CARGO then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							vehicle_object.sinking_counter = (vehicle_object.sinking_counter or 0) + 1
							if vehicle_object.sinking_counter > 8 then
								v.kill(vehicle_object, true)
								d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
							end
						else
							v.kill(vehicle_object, true)
							d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					else

						-- refund the cargo to the island which was sending the cargo
						Cargo.refund(group_id)

						v.kill(vehicle_object)
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
						else
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					end
					goto continue_vehicle
				else
					vehicle_object.sinking_counter = 0
				end

				-- Handles AI pathing
				local ai_target = nil
				if ai_state ~= 2 then ai_state = 1 end
				local ai_speed_pseudo = (vehicle_object.speed.speed or VEHICLE.SPEED.BOAT) * vehicle_update_tickrate / 60

				if(vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET) then

					if vehicle_object.state.s == VEHICLE.STATE.PATHING then
						
						ai_speed_pseudo = v.getTargetSpeed(vehicle_object)

						if #vehicle_object.path == 0 then
							-- Set to holding if we have no waypoints
							AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
						else
							if ai_state ~= 2 then ai_state = 1 end

							ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

							if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then ai_target[14] = 0 end
	
							local vehicle_pos = vehicle_object.transform
							local distance = m.xzDistance(ai_target, vehicle_pos)
							
							-- Check the distance between the vehicle and its next waypoint to see if we can to consume it
							if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE and distance < WAYPOINT_CONSUME_DISTANCE * 4 and vehicle_object.role == "scout" or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.HELI or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND and distance < 7 then
								p.nextPath(vehicle_object)

								if #vehicle_object.path > 0 then
									ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)
								elseif vehicle_object.role == "scout" then
									p.resetPath(vehicle_object)
									local target_island, origin_island = Objective.getIslandToAttack(true)
									if target_island then
										local holding_route = g_holding_pattern
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[1].x, CRUISE_HEIGHT * 2, holding_route[1].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[2].x, CRUISE_HEIGHT * 2, holding_route[2].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[3].x, CRUISE_HEIGHT * 2, holding_route[3].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[4].x, CRUISE_HEIGHT * 2, holding_route[4].z)))
									end
								elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
									-- if we have reached last waypoint start holding there
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and distance < WAYPOINT_CONSUME_DISTANCE then
								if #vehicle_object.path > 0 then
									p.nextPath(vehicle_object)
								else
									-- if we have reached last waypoint start holding there
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							end

							-- if the target has moved far enough, then we want to add to our path.

							if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND and squad.command == SQUAD.COMMAND.ENGAGE then

								local squad_vision = squadGetVisionData(squad)

								if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
									target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj
								elseif pl.isPlayer(vehicle_object.target_player_id) and vehicle_object.target_player_id and squad_vision.visible_players_map[vehicle_object.target_player_id] then
									target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
								end

								if target and (not target.last_pathfind_pos or m.distance(target.last_known_pos, target.last_pathfind_pos) > 20) then
									target.last_pathfind_pos = target.last_known_pos
									ai_target = target.last_pathfind_pos

									p.resetPath(vehicle_object)

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
								end
							end
						end

						if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then 
							if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then
								ai_state = 3
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then
								target_pos = nil
								if pl.isPlayer(vehicle_object.target_player_id) then
									target_pos = s.getPlayerPos(pl.dataBySID(vehicle_object.target_player_id).peer_id)
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


						refuel(group_id)
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
								s.setAITarget(vehicle_object.survivors[1], ai_target)
								s.setAIState(vehicle_object.survivors[1], ai_state)
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

								local speed_pseudo = (ai_speed_pseudo * g_debug_speed_multiplier * game_ticks) - pseudo_speed_modifier

								if math.noNil(math.abs(movement_x * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_x)) and math.noNil(math.abs(movement_z * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_z)) or not vehicle_object.path[2] then
									exhausted_movement = true
								end

								movement_x = math.clamp(movement_x * speed_pseudo / length_xz, -math.abs(movement_x), math.abs(movement_x))
								movement_y = math.clamp(movement_y * speed_pseudo / length_xz, -math.abs(movement_y), math.abs(movement_y))
								movement_z = math.clamp(movement_z * speed_pseudo / length_xz, -math.abs(movement_z), math.abs(movement_z))

								local rotation_matrix = matrix.rotationToFaceXZ(movement_x, movement_z)
								local new_pos = matrix.multiply(matrix.translation(current_pos[13] + movement_x, current_pos[14] + movement_y, current_pos[15] + movement_z), rotation_matrix)

								local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

								-- Ensure we got the main_vehicle_id
								if not main_vehicle_id then
									d.print("main_vehicle_id is nil", true, 1)
									goto continue_vehicle
								end

								if server.getVehicleLocal(main_vehicle_id) == false then
									-- moves the AI when its in pseudo mode
									local set_pos = server.moveGroup(group_id, new_pos)

									-- if it failed
									if not set_pos then
										d.print(("Failed to set pseudo group pos via group_id for vehicle with group_id: %s"):format(group_id), true, 1)
									end

									vehicle_object.transform = new_pos

									-- draw their new position on the map
									-- Map.addMapCircle(-1, vehicle_object.path[0].ui_id, new_pos, 5, 1, 255, 25, 25, 255, 20)

									for _, object_id in pairs(vehicle_object.survivors) do
										s.setObjectPos(object_id, new_pos)
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

					-- killed data
					if vehicle_object.is_killed then
						debug_data = debug_data.."Killed\n"
						debug_data = debug_data.."Death Timer: "..tostring(vehicle_object.death_timer or nil)
					end

					-- cargo data
					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						local cargo_data = g_savedata.cargo_vehicles[vehicle_object.group_id]
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
					if squad.vehicle_type == VEHICLE.TYPE.LAND then
						debug_data = debug_data .. "Land Mass: "..tostring(Tags.getValue(vehicle_object.home_island.tags, "land_access", true)).."\n"
					end
					debug_data = debug_data .. "Target Player: "..(vehicle_object.target_player_id and pl.dataBySID(vehicle_object.target_player_id).name or "nil").."\n"
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

					local ai_speed_pseudo = tostring(v.getTargetSpeed(vehicle_object))

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
						local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)
						local needsResupply = not main_vehicle_id and "main_vehicle_id not found" or isVehicleNeedsResupply(main_vehicle_id, "Resupply")
						debug_data = debug_data .. "\nSIMULATING\n"
						debug_data = debug_data .. "needs resupply: " .. tostring(needsResupply) .. "\n"
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
							Group ID: <group_id>
							Vehicle Type: <vehicle_type>
					]]
					local vehicle_name = ("%s\nGroup ID: %i\nVehicle Type: %s\nVariation: %s"):format(vehicle_object.name, vehicle_object.group_id, vehicle_object.vehicle_type, vehicle_object.variation or "unknown")

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
								local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

								-- Ensure we got the main_vehicle_id
								if not main_vehicle_id then
									d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
									goto continue_vehicle
								end

								server.addMapObject(peer.id, vehicle_object.ui_id, 1, marker_type, 0, 0, 0, 0, main_vehicle_id, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
							else -- draw at direct coordinates instead
								server.addMapObject(peer.id, vehicle_object.ui_id, 0, marker_type, vehicle_object.transform[13], vehicle_object.transform[15], 0, 0, 0, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
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
									s.addMapLabel(peer.id, vehicle_object.ui_id, 1, group_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
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
										s.addMapLabel(peer.id, vehicle_object.ui_id, 1, group_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
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

function tickUpdateVehicleData(game_ticks)
	--d.startProfiler("tickUpdateVehicleData()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(group_id, 30) then
				local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

				-- Ensure we got the main_vehicle_id
				if not main_vehicle_id then
					d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
					goto continue_vehicle
				end

				vehicle_object.transform = s.getVehiclePos(main_vehicle_id)
			end

			::continue_vehicle::
		end
	end

	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then
			player_vehicle.transform = s.getVehiclePos(player_vehicle_id)
		end
	end
	--d.stopProfiler("tickUpdateVehicleData()", true, "onTick()")
end

function tickModifiers(game_ticks)
	d.startProfiler("tickModifiers()", true)

	if isTickID(0, time.hour / 2) then -- defence, if the player has attacked within the last 30 minutes, increase defence
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended <= time.hour / 2 and g_savedata.ai_history.has_defended ~= 0 then -- if the last time the player attacked was equal or less than 30 minutes ago
			sm.train(REWARD, "defend", 4)
			sm.train(PUNISH, "attack", 3)
			d.print("players have attacked within the last 30 minutes! increasing defence, decreasing attack!", true, 0)
		end
	end
	if isTickID(0, time.hour) then -- attack, if the player has not attacked in the last one hour, raise attack
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended > time.hour then -- if the last time the player attacked was more than an hour ago
			sm.train(REWARD, "attack", 3)
			d.print("players have not attacked in the past hour! increasing attack!", true, 0)
		end
	end
	if isTickID(0, time.hour * 2) then -- defence, if the player has not attacked in the last two hours, then lower defence
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended > time.hour * 2 then -- if the last time the player attacked was more than two hours ago
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

function tickVehicleCleaner()
	--d.startProfiler("tickVehicleCleaner()", true)

	---@param vehicle_object vehicle_object
	---@param squad_index integer
	local function deleteVehicle(vehicle_object, squad_index)
		Vehicle.kill(vehicle_object, true, true)

		cleanVehicle(squad_index, vehicle_object.group_id)

		d.print(("(VehicleCleaner) Automatically Deleted Vehicle %s (%s)."):format(vehicle_object.group_id, vehicle_object.name), true, 1)
		
		--[[
			Add 1 to vehicle cleaner stats
		]]

		-- ensure the table exists
		g_savedata.vehicle_cleaner_cleaned_vehicles = g_savedata.vehicle_cleaner_cleaned_vehicles or 0

		-- add 1 to the stats
		g_savedata.vehicle_cleaner_cleaned_vehicles = g_savedata.vehicle_cleaner_cleaned_vehicles + 1
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for _, vehicle_object in pairs(squad.vehicles) do

			if isTickID(vehicle_object.group_id, 240) then
				local main_vehicle_id = VehicleGroup.getMainVehicle(vehicle_object.group_id)

				-- Delete the vehicle if we failed to get it's main_vehicle_id, as it likely does not exist anymore.
				if not main_vehicle_id then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (failed to get main_vehicle_id), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				local vehicle_pos, is_success = server.getVehiclePos(main_vehicle_id)

				-- if getting their position failed
				if not is_success then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (is_success failed on server.getVehiclePos), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				-- if their matrix does not contain the position values.
				if not vehicle_pos[13] or not vehicle_pos[14] or not vehicle_pos[15] then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (matrix does not contain positions), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				-- if their matrix is at 0, 0, 0
				if
					vehicle_pos[13] == 0 and -- x
					vehicle_pos[14] == 0 and -- y
					vehicle_pos[15] == 0 -- z
					then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (matrix is at 0, 0, 0), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

			end
			::continue::
		end
	end
	--d.stopProfiler("tickVehicleCleaner()", true, "onTick()")
end

--[[ no longer has a use, replaced by automatic migration in 0.3.0.78
function tickOther()
	d.startProfiler("tickOther()", true)
	
	d.stopProfiler("tickOther()", true, "onTick()")
end
-]]

function tickCargo(game_ticks)
	d.startProfiler("tickCargo()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled

		-- ticks cargo production and consumption
		for tick = 1, game_ticks do 
			for island_index, island in pairs(g_savedata.islands) do -- at every island
				if isTickID(island.index + tick, time.minute) then -- every minute
					Cargo.produce(island) -- produce cargo
				end
			end

			if isTickID(g_savedata.ai_base_island.index + tick, time.minute) then -- if its the tick for the AI base Island
				Cargo.produce(g_savedata.ai_base_island, RULES.LOGISTICS.CARGO.ISLANDS.ai_base_generation/60)
			end
		end

		-- ticks resupplying islands
		if table.length(g_savedata.cargo_vehicles) ~= 0 then
			g_savedata.tick_extensions.cargo_vehicle_spawn = g_savedata.tick_extensions.cargo_vehicle_spawn + game_ticks
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
							d.print("(tickCargo) Route Index: "..route_index, true, 0)
							local island, got_island = is.getDataFromIndex(route.island_index)

							-- check if we got the island.
							if not got_island then
								d.print(("(tickCargo) Failed to get the island we're sending the cargo to? island_index: %s"):format(route.island_index), true, 1)
								return
							end

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
						if not was_spawned or vehicle_data == nil then
							d.print("Was unable to spawn cargo vehicle! Error: "..tostring(vehicle_data), true, 1)
						else
							-- add it to the cargo vehicles list

							local requested_cargo = Cargo.getRequestedCargo(total_weights, vehicle_data)

							-- make sure we dont try to send more than we can transport, recieve or that we have
							for slot, cargo in pairs(requested_cargo) do
								cargo.amount = math.min(cargo.amount, resupplier_island.cargo[cargo.cargo_type], RULES.LOGISTICS.CARGO.ISLANDS.max_capacity - resupply_island.cargo[cargo.cargo_type])
							end


							---@class CARGO_VEHICLE
							g_savedata.cargo_vehicles[vehicle_data.group_id] = {
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
							local squad_index, squad = Squad.getSquadFromGroup(vehicle_data.group_id)
							for vehicle_index, vehicle_object in pairs(squad.vehicles) do

								-- getting slowest speed
								d.print("Getting slowest speed for cargo vehicle "..tostring(vehicle_data.group_id), true, 0)
								local vehicle_speed = v.getTargetSpeed(vehicle_object, true, true)
								if not g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed > vehicle_speed then
									g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed = vehicle_speed
								end

								-- checking if we can offroad
								if not vehicle_object.can_offroad then
									g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.can_offroad = false
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

function tickIslands(game_ticks)
	d.startProfiler("tickIslands()", true)

	--* go through and set the cargo tanks for each island, to sync the cargo in the script with the cargo on the island
	if g_savedata.settings.CARGO_MODE then
		for island_index, _ in pairs(g_savedata.loaded_islands) do

			if not isTickID(island_index, 15) then
				goto break_island
			end

			local island, got_island = Island.getDataFromIndex(island_index)

			if island == nil or not got_island then
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

function tickCargoVehicles(game_ticks)
	d.startProfiler("tickCargoVehicles()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled
		for cargo_vehicle_index, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
			if isTickID(cargo_vehicle_index, cargo_vehicle_tickrate) then

				local vehicle_object, squad_index, squad = Squad.getVehicle(cargo_vehicle.vehicle_data.group_id)

				--* draw a search radius around the cargo vehicle

				local search_radius = 1850
				if not cargo_vehicle.search_area.x or m.xzDistance(vehicle_object.transform, m.translation(cargo_vehicle.search_area.x, 0, cargo_vehicle.search_area.z)) >= search_radius then
					--* remove previous search area
					s.removeMapID(-1, cargo_vehicle.search_area.ui_id)

					--* add new search area
					local x, z, was_drawn = Map.drawSearchArea(vehicle_object.transform[13], vehicle_object.transform[15], search_radius, cargo_vehicle.search_area.ui_id, -1, "Convoy", "An enemy AI convoy has been detected to be within this area.\nFind and prevent the cargo from arriving to its destination.", 0, 210, 50, 255)

					if not was_drawn then
						d.print("(tickCargoVehicles) failed to draw search area for cargo vehicle "..tostring(vehicle_object.group_id), true, 1)
					else
						cargo_vehicle.search_area.x = x
						cargo_vehicle.search_area.z = z
					end
				end


				--* sync the script's cargo with the true cargo

				--? if the cargo vehicle is simulating and its in the pathing stage
				if cargo_vehicle.vehicle_data.state.is_simulating and cargo_vehicle.route_status == 1 then
					local cargo_data, got_data = Cargo.getTank(cargo_vehicle.vehicle_data.group_id)
					if got_data and cargo_data then
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
							d.print("(tickCargoVehicles) heading to island: "..island.name..". Route status 0->1", true, 0)
							cargo_vehicle.route_status = 1
							local squad_index, squad = Squad.getSquadFromGroup(cargo_vehicle.vehicle_data.group_id)
							squad.target_island = island
							p.addPath(cargo_vehicle.vehicle_data, island.transform)
							table.insert(cargo_vehicle.vehicle_data.path, 1, {
								x = cargo_vehicle.vehicle_data.transform[13],
								y = cargo_vehicle.vehicle_data.transform[14],
								z = cargo_vehicle.vehicle_data.transform[15]
							})
							cargo_vehicle.path_data.path = cargo_vehicle.vehicle_data.path
							g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.group_id].path = cargo_vehicle.vehicle_data.path
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
						d.print("(tickCargoVehicles) arrived at island: "..island.name..". Route status 1->2 (transferring)", true, 0)
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
							if not was_spawned or not vehicle_data then
								d.print("Was unable to spawn cargo vehicle! Error: "..tostring(vehicle_data), true, 1)
							else
								d.print("spawned new cargo vehicle for transfer: "..vehicle_data.name, true, 0)
								-- add it to the cargo vehicles list

								---@class CARGO_VEHICLE
								g_savedata.cargo_vehicles[vehicle_data.group_id] = {
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

								table.remove(g_savedata.cargo_vehicles[vehicle_data.group_id].route_data, 1)
									

								-- get escorts
								Cargo.getEscorts(vehicle_data, island)

								-- get the slowest speed of all of them and if we can offroad
								local squad_index, squad = Squad.getSquadFromGroup(vehicle_data.group_id)
								for vehicle_index, vehicle_object in pairs(squad.vehicles) do

									-- getting slowest speed
									local vehicle_speed = v.getTargetSpeed(vehicle_object, true, true)
									if not g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed > vehicle_speed then
										g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed = vehicle_speed
									end

									-- checking if we can offroad
									if not vehicle_object.can_offroad then
										g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.can_offroad = false
									end
								end
							end
						else
							-- if it does exist
							local transfer_complete, transfer_complete_reason = Cargo.transfer(new_cargo_vehicle.vehicle_data, cargo_vehicle.vehicle_data, new_cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
							if transfer_complete and not cargo_vehicle.vehicle_data.is_killed then
								d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
								-- kill old cargo vehicle
								v.kill(cargo_vehicle.vehicle_data, true, true) -- kills the vehicle thats now empty

								-- tell new cargo vehicle to go on its route

								local island, found_island = Island.getDataFromIndex(new_cargo_vehicle.route_data[1].island_index)
								if found_island then
									new_cargo_vehicle.route_status = 1
									local _, squad = Squad.getSquadFromGroup(new_cargo_vehicle.vehicle_data.group_id)
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
							d.print("cargo vehicle has completed its route and delivered its cargo to "..cargo_vehicle.resupply_island.name..", removing vehicle.", true, 0)
							v.kill(cargo_vehicle.vehicle_data, true, true) -- kills the vehicle thats now empty
						end
					end
				elseif cargo_vehicle.route_status == 3 then
					-- Do nothing, waiting for transfer from another cargo vehicle

					-- Check if its the only cargo vehicle, if it is then something has gone wrong and it will sit here forever
					if table.length(g_savedata.cargo_vehicles) == 1 then
						d.print("(tickCargoVehicles) cargo vehicle "..tostring(vehicle_object.group_id).." is in route status 3 but is the only cargo vehicle? Removing to prevent deadlock.", true, 1)
						v.kill(cargo_vehicle.vehicle_data, true, true)
					end
				end
			end
		end
	end
	d.stopProfiler("tickCargoVehicles()", true, "onTick()")
end

function tickControls(game_ticks)
	d.startProfiler("tickControls()", true)
	local control_started = s.getTimeMillisec()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do

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
				--d.print("you are dead, no big suprise.")
				goto break_control_vehicle
			end

			local reaction_time = 3 -- ticks
			--? if this is it's tick (reaction time)
			if not isTickID(group_id, reaction_time) then
				--d.print("no react.")
				goto break_control_vehicle
			end

			--? is the driver incapcitated, dead or non existant
			local driver_data = s.getCharacterData(vehicle_object.survivors[1])
			if not driver_data or driver_data.dead or driver_data.incapacitated then
				--d.print("driver not exist, or is dead, or is incapacitated")
				goto break_control_vehicle
			end

			local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

			--? if the driver is the one who's sitting in the driver seat
			local loaded_data, got_loaded_data = s.getVehicleComponents(main_vehicle_id)
			if not got_loaded_data then
				--d.print("not got loaded")
				goto break_control_vehicle
			end

			for seat_id, seat_data in pairs(loaded_data.components.seats) do
				if seat_data.name == "Driver" and seat_data.seated_id ~= vehicle_object.survivors[1] then

					if d.getDebug(5) then
						if vehicle_object.driving.ui_id then
							s.removeMapLine(-1, vehicle_object.driving.ui_id)
							s.removeMapLabel(-1, vehicle_object.driving.ui_id)
						end
					end

					--d.print("character in driver seat is not the driver.")

					goto break_control_vehicle
				end
			end

			-- force it to constantly just go directly towards the player.
			--[[if vehicle_object.target_player_id then
				local squad_vision = squadGetVisionData(squad)

				local target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj

				for i = 1, #vehicle_object.path do
					table.remove(vehicle_object.path, 1)
				end

				vehicle_object.path[0] = {
					x = vehicle_object.transform[13],
					y = vehicle_object.transform[14],
					z = vehicle_object.transform[15],
					ui_id = 95912311 - vehicle_object.group_id
				}

				vehicle_object.path[1] =  {
					x = target.last_known_pos[13],
					y = target.last_known_pos[14],
					z = target.last_known_pos[15],
					ui_id = 95912312 + vehicle_object.group_id
				}
			end]]

			--? we have at least 1 path
			if not vehicle_object.path[1] or (vehicle_object.path[0].x == vehicle_object.path[#vehicle_object.path].x and vehicle_object.path[0].y == vehicle_object.path[#vehicle_object.path].y and vehicle_object.path[0].z == vehicle_object.path[#vehicle_object.path].z) then

				if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
					-- resets seat
					AI.setSeat(group_id, "Driver", 0, 0, 0, 0, false, false, false, false, false, false, false)
				end

				-- removes debug
				if d.getDebug(5) then
					if vehicle_object.driving.ui_id then
						s.removeMapLine(-1, vehicle_object.driving.ui_id)
						s.removeMapLabel(-1, vehicle_object.driving.ui_id)
					end
				end

				--d.print("path no.")

				goto break_control_vehicle
			end

			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then

				vehicle_object.transform, got_pos = s.getVehiclePos(main_vehicle_id)
				if not got_pos then
					--d.print("no got pos :(")
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

				-- close enough to next path, we can go to the next path.
				if path_projection <= projected_dist/2 then
					p.nextPath(vehicle_object)
					goto break_control_vehicle
				end

				local target_pos = {
					x = vehicle_object.path[0].x + path_vector_normalized.x * (path_progress + path_projection),
					z = vehicle_object.path[0].z + path_vector_normalized.z * (path_progress + path_projection)
				}

				-- Angle to the scalar projected target position.
				local target_angle = math.atan(target_pos.x - vehicle_object.transform[13], target_pos.z - vehicle_object.transform[15])

				local speed = v.getTargetSpeed(vehicle_object, true)

				local x_axis, y_axis, z_axis = m.getMatrixRotation(vehicle_object.transform)
				--d.print("y_axis: "..y_axis, true, 0)
				--d.print("target_angle: "..target_angle, true, 0)
				local ad = math.wrap(y_axis - target_angle, -math.pi, math.pi)
				--d.print("ad: "..ad, true, 0)

				-- speed modifier for the upcoming turns (slows down for turns)
				local previous_yaw = math.atan(vehicle_object.path[1].x - vehicle_object.transform[13], vehicle_object.path[1].z - vehicle_object.transform[15])
				local total_dist = m.distance(vehicle_object.transform, m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)) -- the total distance checked so far, used for weight

				local max_dist = 200

				local min_speed = 8

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

				local ws = (speed/vehicle_object.speed.speed)/math.clamp(math.abs(ad)+0.6, 1, 2)

				AI.setSeat(main_vehicle_id, "Driver", ws, ad, 0, 0, true, false, false, false, false, false, false)
				--d.print("I do thing :D")

				if d.getDebug(5) then
					-- calculate info for debug
					local length = 10
					local y_axis_x = vehicle_object.transform[13] + length * math.sin(y_axis)
					local y_axis_z = vehicle_object.transform[15] + length * math.cos(y_axis)
					local target_angle_x = vehicle_object.transform[13] + length * math.sin(target_angle)
					local target_angle_z = vehicle_object.transform[15] + length * math.cos(target_angle)
					
					local player_list = s.getPlayers()
					s.removeMapLine(-1, vehicle_object.driving.ui_id)

					-- remove a bunch of labels, cause it only removes 1 at a time, we just do 10 to be safe, as the function has very little performance impact anyways (2-3ms for 10,000 runs)
					for _ = 1, 10 do
						s.removeMapLabel(-1, vehicle_object.driving.ui_id)
					end

					for _, peer in pairs(player_list) do
						if d.getDebug(5, peer.id) then

							if #next_paths_debug > 0 then
								for i=1, #next_paths_debug do
									-- line that shows the next paths, colour depending on how much the vehicle is slowing down for it, red = very slow, green = none
									s.addMapLine(peer.id, vehicle_object.driving.ui_id, m.translation(next_paths_debug[i].origin_x, 0, next_paths_debug[i].origin_z), m.translation(next_paths_debug[i].target_x, 0, next_paths_debug[i].target_z), 1, math.floor(math.clamp(255*(1-next_paths_debug[i].speed_mult), 0, 255)), math.floor(math.clamp(255*next_paths_debug[i].speed_mult, 0, 255)), 0, 200)
									
									local line_distance = math.euclideanDistance(next_paths_debug[i].origin_x, next_paths_debug[i].target_x, next_paths_debug[i].origin_z, next_paths_debug[i].target_z)

									local to_next_yaw, _ = math.angleToFace(next_paths_debug[i].origin_x, next_paths_debug[i].target_x, next_paths_debug[i].origin_z, next_paths_debug[i].target_z)

									to_next_yaw = to_next_yaw - math.half_pi
									local label_x = next_paths_debug[i].origin_x + (line_distance * 0.65) * math.cos(to_next_yaw)
									local label_z = next_paths_debug[i].origin_z + (line_distance * 0.65) * math.sin(to_next_yaw)
									
									s.addMapLabel(peer.id, vehicle_object.driving.ui_id, 4, "Speed Multiplier: "..next_paths_debug[i].speed_mult, label_x, label_z)
									--d.print("speed_mult: "..next_paths_debug[i].speed_mult, true, 0)
								end
							end
							-- blue line where its driving to
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_pos.x, 0, target_pos.z), 2, 0, 0, 255, 200)

							-- cyan line where its pointing
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(y_axis_x, 0, y_axis_z), 0.5, 0, 255, 255, 200)

							-- yellow line at target angle (where its wanting to go)
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_angle_x, 0, target_angle_z), 0.5, 255, 255, 0, 200)
						
							-- Label at where the vehicle is, displaying the current throttle
							server.addMapLabel(peer.id, vehicle_object.driving.ui_id, 4, "Throttle: "..ws.."\nSteering: "..ad, vehicle_object.transform[13], vehicle_object.transform[15])
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

--[[

	Sanity Ticker

	Will periodically check data for any invalid data (eg: fully_created true for a prefab, when voxels or mass is nil.)

]]

function tickSanity(game_ticks)

	-- Only tick every 5 seconds
	if not isTickID(0, time.second * 5) then
		return
	end

	-- Check all prefabs
	for prefab_id, prefab_data in pairs(g_savedata.prefabs) do

		-- Check if the prefab is fully created
		if prefab_data.fully_created then

			-- Check if the prefab has nil mass
			if not prefab_data.mass then
				d.print("Prefab "..prefab_id.." has nil mass! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has 0 mass
			if prefab_data.mass == 0 then
				d.print("Prefab "..prefab_id.." has 0 mass! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has nil voxels
			if not prefab_data.voxels then
				d.print("Prefab "..prefab_id.." has nil voxels! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has 0 voxels
			if prefab_data.voxels == 0 then
				d.print("Prefab "..prefab_id.." has 0 voxels! But prefab_data.fully_created is true!", true, 1)
			end
		end
	end

end

function tickSpatialGrid(game_ticks)
	d.startProfiler("tickSpatial()", true)

	-- Update AI vehicle positions
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, 10) then
			for _, vehicle_object in pairs(squad.vehicles) do
				SpatialGrid.update(ai_vehicles_grid,vehicle_object.group_id, vehicle_object.transform[13], vehicle_object.transform[15])
			end
		end
	end
	
	-- Update player vehicle positions
	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then -- Matches the transform update rate in tickUpdateVehicleData. Dont change
			SpatialGrid.update(player_vehicles_grid, player_vehicle_id, player_vehicle.transform[13], player_vehicle.transform[15])
		end
	end

	d.stopProfiler("tickSpatial()", true, "onTick()")
end

function onTick(game_ticks)

	game_ticks = game_ticks or 1

	if g_savedata.debug.traceback.enabled then
		ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
	end

	eq.tick()

	if not is_dlc_weapons or not g_savedata.info.setup then
		return
	end

	if g_savedata.settings.PAUSE_WHEN_NONE_ONLINE then
		if #s.getPlayers() <= 0 then
			-- addon paused as nobody is online
			return
		end
	end

	-- if the flag to sync the tick rate with game_ticks is enabled.
	if g_savedata.flags.sync_tick_rate and game_ticks > 1 then
		for _ = 1, game_ticks do
			onTick(1)
		end

		return
	end

	-- if the flag to sync the game speed is enabled, then apply the current tick rate, otherwise, set game ticks to 1.
	game_ticks = g_savedata.flags.sync_game_speed and game_ticks or 1

	g_savedata.tick_counter = g_savedata.tick_counter + 1

	g_savedata.game_tick_counter = g_savedata.game_tick_counter + game_ticks

	d.startProfiler("onTick()", true)

	-- Cleans invalid vehicles, if any vehicles have invalid positions (0, 0, 0) (non existant), they get killed and deleted.
	tickVehicleCleaner()

	tickUpdateVehicleData(game_ticks)
	tickSpatialGrid(game_ticks)
	tickVision(game_ticks)
	tickGamemode(game_ticks)
	tickAI(game_ticks)
	tickSquadrons(game_ticks)
	tickVehicles(game_ticks)
	tickControls(game_ticks) -- ticks custom ai driving
	tickCargoVehicles(game_ticks)
	tickCargo(game_ticks)
	tickIslands(game_ticks)
	tickModifiers(game_ticks)
	CapturePointPayments.tick(game_ticks)
	--VehicleFires.tick(game_ticks)
	-- tickOther()

	-- Check if sanity ticker is enabled
	if g_savedata.flags.sanity_checker then
		-- tick sanity check.
		tickSanity(game_ticks)
	end


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

-- Reloads all ammo containers on a vehicle, by just refilling them. Set the vehicle_id to the id of vehicle you want to reload.
---@param vehicle_id integer the vehicle you want to reload
function reload(vehicle_id)
	--Reload the main ammo containers
	local i = 1
	repeat
		local ammo, success = server.getVehicleWeapon(vehicle_id, "Ammo "..i) -- get the number of ammo containers to reload
		if success then
			server.setVehicleWeapon(vehicle_id, "Ammo "..i, ammo.capacity) -- reload the ammo container
		end
		i = i + 1
	until (not success)

	--Reload any reserve ammo
	local vehicle_component_data, components_is_success = server.getVehicleComponents(vehicle_id)
	local target_pattern = ("^Reserve Ammo %d+$") --Must start with "Reserve Ammo ", then any amount of digits and must end with those digits
	if components_is_success and vehicle_component_data.components and vehicle_component_data.components.guns then
		--If the gun data exists
		for reserve_ammo_index = 1, #vehicle_component_data.components.guns do
			--Loops through all the guns on the vehicle
			local reserve_ammo_data = vehicle_component_data.components.guns[reserve_ammo_index]
			if reserve_ammo_data.ammo == 0 and reserve_ammo_data.name:match(target_pattern) then
				--This is a reserve ammo and its out of ammo. Reload it to capacity
				server.setVehicleWeapon(vehicle_id, reserve_ammo_data.pos.x, reserve_ammo_data.pos.y, reserve_ammo_data.pos.z, reserve_ammo_data.capacity)
			end
		end
	end
end

--------------------------------------------------------------------------------
--
-- VEHICLE HELPERS
--
--------------------------------------------------------------------------------

--- @param vehicle_id integer
--- @param button_name string
--- @return boolean needs_resupply
function isVehicleNeedsResupply(vehicle_id, button_name)
	local button_data, success = s.getVehicleButton(vehicle_id, button_name)
	return success and button_data.on
end

--------------------------------------------------------------------------------
--
-- SQUAD HELPERS
--
--------------------------------------------------------------------------------

--- @param squad squadron
--- @param target_island ISLAND
function setSquadCommandPatrol(squad, target_island)
	squad.target_island = target_island
	Squad.setCommand(squad, SQUAD.COMMAND.PATROL)
end

--- @param squad squadron
--- @param target_island ISLAND
function setSquadCommandStage(squad, target_island)
	squad.target_island = target_island
	Squad.setCommand(squad, SQUAD.COMMAND.STAGE)
end

--- @param squad squadron
--- @param target_island ISLAND
function setSquadCommandAttack(squad, target_island)
	squad.target_island = target_island
	Squad.setCommand(squad, SQUAD.COMMAND.ATTACK)
end

--- @param squad squadron
--- @param target_island ISLAND
function setSquadCommandDefend(squad, target_island)
	squad.target_island = target_island
	Squad.setCommand(squad, SQUAD.COMMAND.DEFEND)
end

--- @param squad squadron
function setSquadCommandEngage(squad)
	Squad.setCommand(squad, SQUAD.COMMAND.ENGAGE)
end

--- @param squad squadron
--- @param investigate_transform SWMatrix
function setSquadCommandInvestigate(squad, investigate_transform)
	squad.investigate_transform = investigate_transform
	Squad.setCommand(squad, SQUAD.COMMAND.INVESTIGATE)
end

--- @param squad squadron
function setSquadCommandScout(squad)
	Squad.setCommand(squad, SQUAD.COMMAND.SCOUT)
end

--- @param squad squadron
--- @param command string
--- @return boolean changed
--- @deprecated
function setSquadCommand(squad, command)
	if squad.command ~= command then
		if squad.command ~= SQUAD.COMMAND.SCOUT or squad.command == SQUAD.COMMAND.SCOUT and command == SQUAD.COMMAND.DEFEND then
			if squad.command ~= SQUAD.COMMAND.CARGO then -- never change cargo vehicles being cargo vehicles
				squad.command = command
			
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					squadInitVehicleCommand(squad, vehicle_object)
				end

				if squad.command == SQUAD.COMMAND.NONE then
					squad.target_island = nil
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

--- @param squad squadron
--- @param vehicle_object vehicle_object
function squadInitVehicleCommand(squad, vehicle_object)
	vehicle_object.target_vehicle_id = nil
	vehicle_object.target_player_id = nil

	local cruise_altitude = CRUISE_HEIGHT + (vehicle_object.group_id % 10 * 20)

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

		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[1].x, cruise_altitude, patrol_route[1].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[2].x, cruise_altitude, patrol_route[2].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[3].x, cruise_altitude, patrol_route[3].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[4].x, cruise_altitude, patrol_route[4].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[5].x, cruise_altitude, patrol_route[5].z)))
		d.print("Vehicle "..vehicle_object.group_id.." set to patrol "..squad.target_island.name..". Path length: "..#vehicle_object.path..", State: "..vehicle_object.state.s, true, 0)
	elseif squad.command == SQUAD.COMMAND.ATTACK then
		-- go to island, once island is captured the command will be cleared
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-100, 100), cruise_altitude, math.random(-100, 100))))
	elseif squad.command == SQUAD.COMMAND.STAGE then
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.DEFEND then
		-- defend island
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
		-- go to investigate location
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.investigate_transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
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

--- @param squad squadron
function squadGetVisionData(squad)
	local vision_data = {
		visible_players_map = {},
		visible_players = {},
		visible_vehicles_map = {},
		visible_vehicles = {},
		investigate_players = {},
		investigate_vehicles = {},

		---@param id number
		---@return boolean
		isPlayerVisible = function(self, id)
			return self.visible_players_map[id] ~= nil
		end,

		---@param id number
		---@return boolean
		isVehicleVisible = function(self, id)
			return self.visible_vehicles_map[id] ~= nil
		end,

		--- Best target?? Its random
		--- @return number
		getBestTargetPlayerID = function(self)
			return self.visible_players[math.random(1, #self.visible_players)].id
		end,

		--- @return number
		getBestTargetVehicleID = function(self)
			return self.visible_vehicles[math.random(1, #self.visible_vehicles)].id
		end,

		--- @return {id: number, obj: TargetPlayer}
		getBestInvestigatePlayer = function(self)
			return self.investigate_players[math.random(1, #self.investigate_players)]
		end,

		--- @return {id: number, obj: TargetVehicle}
		getBestInvestigateVehicle = function(self)
			return self.investigate_vehicles[math.random(1, #self.investigate_vehicles)]
		end,

		--- @return boolean
		is_engage = function(self)
			return #self.visible_players > 0 or #self.visible_vehicles > 0
		end,

		--- @return boolean
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

--[[


Flag Registers


]]

--[[
Boolean Flags
]]

-- sync_game_speed flag, if enabled, 
Flag.registerBooleanFlag(
	"sync_game_speed",
	true,
	{
		"balance",
		"low performance impact"
	},
	"normal",
	"admin",
	nil,
	"Makes it so while sleeping, the AI will move, produce, etc, 400x faster to be inline with how fast time is moving while the player sleeps."
)

-- sync_tick_rate flag, if enabled, executes onTick for the number of times game_tick was specified.
Flag.registerBooleanFlag(
	"sync_tick_rate",
	false,
	{
		"debug",
		"balance",
		"experimental",
		"heavy performance impact"
	},
	"admin",
	"admin",
	nil,
	"Sets if the tick rate of the addon will be synced with the in game ticks, meaning that while sleeping, the addon will execute 400 ticks per tick call, to makeup for the game's speed being x400, Causes massive performance impacts while sleeping, which makes sleeping very slow. Not recommended to use."
)

-- show_capture_timer, if enabled, shows the capture timer on the tooltips for capture vehicles, for debug purposes.
Flag.registerBooleanFlag(
	"show_capture_timer_debug",
	false,
	{
		"debug",
		"internal",
		"capture points"
	},
	"admin",
	"admin",
	nil,
	"If enabled, shows the capture timer on the tooltips for capture vehicles, for debug purposes."
)

--[[
	sanity_checker, 
	when enabled, will periodically check for potential issues with the stored data, eg: prefab marked as fully_created, 
	but does not have voxels or mass filled out.
]]
Flag.registerBooleanFlag(
	"sanity_checker",
	true,
	{
		"debug",
		"internal",
		"medium performance impact"
	},
	"admin",
	"admin",
	nil,
	"When enabled, will periodically check for potential issues with the stored data, eg: prefab marked as fully_created, but does not have voxels or mass filled out."
)

--[[
Integer Flags
]]

-- profiler_tick_smoothing flag, specifies how many ticks to average an track the results for in the profiler.
Flag.registerIntegerFlag(
	"profiler_tick_smoothing",
	60,
	{
		"debug",
		"profiler",
		"low performance impact"
	},
	"admin",
	"admin",
	nil,
	"Controls how many ticks to track for the maximum and average result in the profiler.",
	1,
	nil
)

