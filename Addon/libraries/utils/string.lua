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