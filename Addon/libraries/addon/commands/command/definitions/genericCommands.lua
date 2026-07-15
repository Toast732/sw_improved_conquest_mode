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

	Registers the default generic commands.

]]

-- Info command
Command.registerCommand(
	"info",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print(("Addon version: %s"):format(ADDON_VERSION), false, 0, peer_id)
	end,
	"none",
	"Prints some info about the addon, such as it's version",
	"Prints some general addon info.",
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
		local comand_name = arg[1]

		-- Define the help reply message
		local help_reply_message = ""

		---@param command Command the command to add to the help menu
		---@param detailed boolean whether or not if the help should be detailed for this command
		---@return string command_help_string the help message for this command
		local function getCommandHelp(command, detailed)
			-- Create the string, starting off with the command's name.
			local command_help_string = command.name

			-- If the help shouldn't be detailed.
			if not detailed then
				-- Add the short description to the string on the same line.
				command_help_string = ("%s - %s"):format(command_help_string, command.short_description)
			-- If the help should be detailed.
			else
				-- Add the full description to the string on the next line.
				command_help_string = ("%s\nDesc: %s"):format(command_help_string, command.description)
			end

			return command_help_string
		end

		-- If the user didn't specify a command, then print all of the commands
		if not comand_name then
			-- Go through all of the prefixes
			for prefix, commands in pairs(commands) do
				-- Go through all of the commands
				for command_name, command in pairs(commands) do
					-- Get it's help message, and add it to the list
					help_reply_message = ("%s\n%s"):format(help_reply_message, getCommandHelp(command, false))
				end
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
	}
)