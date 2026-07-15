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