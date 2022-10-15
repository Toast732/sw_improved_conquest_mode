-- required libraries
require("libraries.players")
require("libraries.tables")
require("libraries.map")

-- library name
local Debugging = {}

-- shortened library name
local d = Debugging 

---@param message string the message you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id) -- "glorious debug function" - senty, 2022

	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", IMPROVED_CONQUEST_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log("SW IMPWEP "..suffix.." | "..string.gsub(message, "\n", " \\n "))
			else
				debug.log("SW IMPWEP "..suffix.." | (d.print) message is nil!")
			end
		end
		
		if type(message) == "table" then
			d.printTable(message, requires_debug, debug_type, peer_id)

		elseif requires_debug then
			if pl.isPlayer(peer_id) and peer_id then
				if g_savedata.player_data.is_Debugging.toPlayer then
					s.announce(prefix, message, peer_id)
				end
			else
				local player_list = s.getPlayers()
				for peer_index, player in pairs(player_list) do
					if d.getDebug(debug_type, player.id) or debug_type == 2 and d.getDebug(0, player.id) then
						s.announce(prefix, message, player_id)
					end
				end
			end
		else
			s.announce(prefix, message, peer_id or "-1")
		end
	end
end

--# prints all data which is in a table (use d.print instead of this)
---@param t table the table of which you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler)
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.printTable(t, requires_debug, debug_type, peer_id)
	for k, v in pairs(t) do
		if type(v) == "table" then
			d.print("Table: "..tostring(k), requires_debug, debug_type, peer_id)
			d.printTable(v, requires_debug, debug_type, peer_id)
		else
			d.print("k: "..tostring(k).." v: "..tostring(v), requires_debug, debug_type, peer_id)
		end
	end
end

---@param debug_type integer the type of debug | 0 = debug | 1 = error | 2 = profiler | 3 = map
---@param peer_id ?integer the peer_id of the player you want to check if they have it enabled, leave blank to check globally
---@return boolean enabled if the specified type of debug is enabled
function Debugging.getDebug(debug_type, peer_id)
	if not peer_id or not pl.isPlayer(peer_id) then -- if any player has it enabled
		if debug_type == -1 then -- any debug
			if g_savedata.debug.chat or g_savedata.debug.profiler or g_savedata.debug.map then
				return true
			end
		elseif not debug_type or debug_type == 0 or debug_type == 1 then -- chat debug
			if g_savedata.debug.chat then
				return true
			end
		elseif debug_type == 2 then -- profiler debug
			if g_savedata.debug.profiler then
				return true
			end
		elseif debug_type == 3 then -- map debug
			if g_savedata.debug.map then
				return true
			end
		elseif debug_type == 4 then -- graph node debug
			if g_savedata.debug.graph_node then
				return true
			end
		elseif debug_type == 5 then
			if g_savedata.debug.driving then
				return true
			end
		else
			d.print("(d.getDebug) debug_type "..tostring(debug_type).." is not a valid debug type!", true, 1)
		end
	else -- if a specific player has it enabled
		local steam_id = pl.getSteamID(peer_id)
		if steam_id and g_savedata.player_data[steam_id] then -- makes sure the steam id and player data exists
			if debug_type == -1 then -- any debug
				if g_savedata.player_data[steam_id].debug.chat or g_savedata.player_data[steam_id].debug.profiler or g_savedata.player_data[steam_id].debug.map then
					return true
				end
			elseif not debug_type or debug_type == 0 or debug_type == 1 then -- chat debug
				if g_savedata.player_data[steam_id].debug.chat then
					return true
				end
			elseif debug_type == 2 then -- profiler debug
				if g_savedata.player_data[steam_id].debug.profiler then
					return true
				end
			elseif debug_type == 3 then -- map debug
				if g_savedata.player_data[steam_id].debug.map then
					return true
				end
			elseif debug_type == 4 then -- graph node debug
				if g_savedata.player_data[steam_id].debug.graph_node then
					return true
				end
			elseif debug_type == 5 then
				if g_savedata.player_data[steam_id].debug.driving then
					return true
				end
			else
				d.print("(d.getDebug) debug_type "..tostring(debug_type).." is not a valid debug type! peer_id requested: "..tostring(peer_id), true, 1)
			end
		end
	end
	return false
end

function Debugging.handleDebug(debug_type, enabled, peer_id, steam_id)
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
			Map.addMapCircle(peer_id, ui_id, m.translation(x, 0, z), 5, 1.5, r, g, b, 255, 5)
		end

		if enabled then
			if not g_savedata.graph_nodes.init_debug then
				for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
					for z, z_data in pairs(x_data) do
						z_data.ui_id = s.getMapID()
						addNode(z_data.ui_id, x, z, z_data.type, z_data.NSO)
					end
				end
				g_savedata.graph_nodes.init_debug = true
			else
				for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
					for z, z_data in pairs(x_data) do
						addNode(z_data.ui_id, x, z, z_data.type, z_data.NSO)
					end
				end
			end
		else
			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					s.removeMapID(peer_id, z_data.ui_id)
				end
			end
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
	end
end

function Debugging.setDebug(d_type, peer_id)

	if not peer_id then
		d.print("(Debugging.setDebug) peer_id is nil!", true, 1)
		return "peer_id was nil"
	end

	local steam_id = pl.getSteamID(peer_id)

	if not d_type then
		d.print("(Debugging.setDebug) d_type is nil!", true, 1)
		return "d_type was nil"
	end

	local debug_types = {
		[-1] = "all",
		[0] = "chat",
		[1] = "error",
		[2] = "profiler",
		[3] = "map",
		[4] = "graph_node",
		[5] = "driving"
	}

	local ignore_all = { -- debug types to ignore from enabling and/or disabling with ?impwep debug all
		[-1] = "all",
		[4] = "enable"
	}

	
	if debug_types[d_type] then
		if d_type == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if g_savedata.player_data[steam_id].debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
					none_true = false
					g_savedata.player_data[steam_id].debug[debug_type_data] = false
				end
			end

			if none_true then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data] = none_true
						g_savedata.player_data[steam_id].debug[debug_type_data] = none_true
						d.handleDebug(debug_type_data, none_true, peer_id, steam_id)
					end
				end
			else
				d.checkDebug()
				for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "disable") then
						d.handleDebug(debug_type_data, none_true, peer_id, steam_id)
					end
				end
			end
			return (none_true and "Enabled" or "Disabled").." All Debug"
		else
			g_savedata.player_data[steam_id].debug[debug_types[d_type]] = not g_savedata.player_data[steam_id].debug[debug_types[d_type]]

			if g_savedata.player_data[steam_id].debug[debug_types[d_type]] then
				g_savedata.debug[debug_types[d_type]] = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[d_type], g_savedata.player_data[steam_id].debug[debug_types[d_type]], peer_id, steam_id)
		end
	else
		return "Unknown debug type: "..tostring(d_type)
	end
end

function Debugging.checkDebug() -- checks all debugging types to see if anybody has it enabled, if not, disable them to save on performance
	local keep_enabled = {}

	-- check all debug types for all players to see if they have it enabled or disabled
	local player_list = s.getPlayers()
	for peer_index, peer in pairs(player_list) do
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
			g_savedata.debug[debug_type] = should_keep_enabled
		end
	end
end

---@param unique_name string a unique name for the profiler  
function Debugging.startProfiler(unique_name, requires_debug)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler then
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
	if not requires_debug or requires_debug and g_savedata.debug.profiler then
		if unique_name then
			if g_savedata.profiler.working[unique_name] then
				Tables.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
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
	if g_savedata.debug.profiler then
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