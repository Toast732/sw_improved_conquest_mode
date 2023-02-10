-- required libraries
require("libraries.addon.script.players")
require("libraries.addon.script.map")
require("libraries.utils.tables")

-- library name
Debugging = {}

-- shortened library name
d = Debugging 

---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id) -- "glorious debug function" - senty, 2022

	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log(("SW %s %s | %s"):format(SHORT_ADDON_NAME, suffix, string.gsub(message, "\n", " \\n ")))
			else
				debug.log(("SW %s %s | (d.print) message is nil!"):format(SHORT_ADDON_NAME, suffix))
			end
		end
		
		if type(message) == "table" then -- print the message as a table.
			d.printTable(message, requires_debug, debug_type, peer_id)

		elseif requires_debug then -- if this message requires debug to be enabled
			if pl.isPlayer(peer_id) and peer_id then -- if its being sent to a specific peer id
				if d.getDebug(debug_type, peer_id) then -- if this peer has debug enabled
					s.announce(prefix, message, peer_id) -- send it to them
				end
			else
				for _, peer in ipairs(s.getPlayers()) do -- if this is being sent to all players with the debug enabled
					if d.getDebug(debug_type, peer.id) or debug_type == 2 and d.getDebug(0, peer.id) then -- if this player has debug enabled
						s.announce(prefix, message, peer.id) -- send the message to them
					end
				end
			end
		else
			s.announce(prefix, message, peer_id or -1)
		end
	end
end

function Debugging.debugTypeFromID(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

function Debugging.debugIDFromType(debug_type)
	for debug_id, d_type in ipairs(debug_types) do
		if debug_type == d_type then
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

	local function tableoString(T, S, ind)

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
				S = tableoString(value, S, ind.."  ")
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

	d.print(tableoString(T), requires_debug, debug_type, peer_id)

	--[[for k, v in pairs(t) do

		table_counter = table_counter + 1
		if type(v) == "table" then
			local new_indent = indent.."  "
			d.print(("%s[%s] = {"):format(indent, k), requires_debug, debug_type, peer_id)
			--d.print("Table: "..tostring(k), requires_debug, debug_type, peer_id)
			d.printTable(v, requires_debug, debug_type, peer_id)
		else
			d.print(("%s[%s] = %s%s"):format(indent, tostring(k), tostring(v), table_counter ~= table_length and ",")..tostring(k).." v: "..tostring(v), requires_debug, debug_type, peer_id)
		end
	end

	d.print(("%s}"):format(indent), requires_debug, debug_type, peer_id)]]
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
			if g_savedata.debug.chat or g_savedata.debug.profiler or g_savedata.debug.map then
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
		return g_savedata.debug[debug_types[debug_id]]

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
	end
end

function Debugging.setDebug(debug_id, peer_id)

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
		[4] = "enable"
	}

	
	if debug_types[debug_id] then
		if debug_id == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if player_data.debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
					none_true = false
					player_data.debug[debug_type_data] = false
				end
			end

			if none_true then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data] = none_true
						player_data.debug[debug_type_data] = none_true
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
			player_data.debug[debug_types[debug_id]] = not player_data.debug[debug_types[debug_id]]

			if player_data.debug[debug_types[debug_id]] then
				g_savedata.debug[debug_types[debug_id]] = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[debug_id], player_data.debug[debug_types[debug_id]], peer_id, steam_id)
		end
	else
		return "Unknown debug type: "..tostring(debug_id)
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
				table.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
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