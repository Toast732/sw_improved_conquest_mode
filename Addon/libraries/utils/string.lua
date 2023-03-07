---@param str string the string to make the first letter uppercase
---@return string str the string with the first letter uppercase
function string.upperFirst(str)
	if type(str) == "string" then
		return (str:gsub("^%l", string.upper))
	end
	return nil
end

--- @param str string the string the make friendly
--- @param remove_spaces boolean true for if you want to remove spaces, will also remove all underscores instead of replacing them with spaces
--- @param keep_caps boolean if you want to keep the caps of the name, false will make all letters lowercase
--- @return string friendly_string friendly string, nil if input_string was not a string
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
---@param keep_caps boolean if you want to keep the caps of the name, false will make all letters lowercase
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

	return vehicle_name
end