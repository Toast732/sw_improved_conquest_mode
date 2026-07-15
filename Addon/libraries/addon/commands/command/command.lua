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

require("libraries.utils.string")

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

---@class Command
---@field name string the name of the command
---@field function_to_execute function the function to execute when the command is called, given params are: full_message, peer_id, arg
---@field required_permission defaultCommandPermissions|string the permission this command requires
---@field description string the description of the command
---@field short_description string the short description for this command
---@field examples table<integer, string> the examples of using this command
---@field prefix string the prefix for this command

--[[
-- where all of the registered commands are stored
---@type table<string, command>
local registered_commands = {}
]]

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

	-- call the command
	command_data.function_to_execute(full_message, peer_id, table.pack(...))

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
---@param function_to_execute function the function to execute when the command is called, params are (full_message, peer_id, args)
---@param required_permission defaultCommandPermissions|string the permission required to execute this command.
---@param description string the description of the command
---@param short_description string the shortened description of the command
---@param examples table<integer, string> examples of using the command, prefix and the command will be added to the strings automatically.
---@param unformatted_prefix prefix? the prefix for the command, leave blank to use the addon's short name as the prefix.
function Command.registerCommand(name, function_to_execute, required_permission, description, short_description, examples, unformatted_prefix)
	
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

require("libraries.addon.commands.command.definitions.commandPermissions")
require("libraries.addon.commands.command.definitions.defaultCommandModules")