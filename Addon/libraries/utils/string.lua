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