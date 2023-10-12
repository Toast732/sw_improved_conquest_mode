--[[
	
Copyright 2023 Liam Matthews

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

-- required libraries

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

---@param full_message string the full_message of the player
---@param peer_id integer the peer_id of the player who executed the command
---@param is_admin boolean if the player has admin.
---@param is_auth boolean if the player is authed.
---@param command string the command the player entered
---@param arg table<integer, string> the arguments to the command the player entered.
function Flag.onFlagCommand(full_message, peer_id, is_admin, is_auth, command, arg)
	if command == "flag" then
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
	elseif command == "flags" then
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

-- required libraries (put at bottom to ensure the Flag variable and functions are created before them, but they're still required.)
require("libraries.addon.script.debugging") -- required to print messages
require("libraries.addon.script.players") -- required to get data on players
require("libraries.utils.string") -- required for some of its helpful string functions
require("libraries.utils.tables") -- required for some of its helpful table functions