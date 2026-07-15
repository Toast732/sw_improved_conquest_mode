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
require("libraries.utils.tables")

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