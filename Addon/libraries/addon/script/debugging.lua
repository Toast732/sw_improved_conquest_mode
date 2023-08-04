-- required libraries
require("libraries.addon.script.addonCommunication")
require("libraries.addon.script.players")
require("libraries.addon.script.map")

require("libraries.utils.string")
require("libraries.utils.tables")

-- library name
Debugging = {}

-- shortened library name
d = Debugging

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id) -- "glorious debug function" - senty, 2022
	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) or debug_type == 1 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or debug_type == 7 and " Function:" or debug_type == 8 and " Traceback:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log(string.format("SW %s %s | %s", SHORT_ADDON_NAME, suffix, string.gsub(message, "\n", " \\n ")))
			else
				debug.log(string.format("SW %s %s | (d.print) message is nil!", SHORT_ADDON_NAME, suffix))
			end
		end
		
		if type(message) == "table" then -- print the message as a table.
			d.printTable(message, requires_debug, debug_type, peer_id)

		elseif requires_debug then -- if this message requires debug to be enabled
			if pl.isPlayer(peer_id) and peer_id then -- if its being sent to a specific peer id
				if d.getDebug(debug_type, peer_id) then -- if this peer has debug enabled
					server.announce(prefix, message, peer_id) -- send it to them
				end
			else
				for _, peer in ipairs(server.getPlayers()) do -- if this is being sent to all players with the debug enabled
					if d.getDebug(debug_type, peer.id) or debug_type == 2 and d.getDebug(0, peer.id) or debug_type == 1 and d.getDebug(0, peer.id) then -- if this player has debug enabled
						server.announce(prefix, message, peer.id) -- send the message to them
					end
				end
			end
		else
			server.announce(prefix, message, peer_id or -1)
		end
	end

	-- print a traceback if this is a debug error message, and if tracebacks are enabled
	if debug_type == 1 and d.getDebug(8) then
		d.trace.print(_ENV, requires_debug, peer_id)
	end
end

function Debugging.debugTypeFromID(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

function Debugging.debugIDFromType(debug_type)

	debug_type = string.friendly(debug_type)

	for debug_id, d_type in pairs(debug_types) do
		if debug_type == string.friendly(d_type) then
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
	d.print(string.fromTable(T), requires_debug, debug_type, peer_id)
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
			if g_savedata.debug.chat.enabled or g_savedata.debug.profiler.enabled or g_savedata.debug.map.enabled then
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
		return g_savedata.debug[debug_types[debug_id]].enabled

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

function Debugging.handleDebug(debug_type, enabled, peer_id)
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
	elseif debug_type == "function" then
		if enabled then
			-- enable function debug (function debug prints debug output whenever a function is called)

			--- cause the game doesn't like it when you use ... for params, and thinks thats only 1 parametre being passed.
			local function callFunction(funct, name, ...)

				--[[
					all functions within this function, other than the one we're wanting to call must be called appended with _ENV_NORMAL
					as otherwise it will cause the function debug to be printed for that function, causing this function to call itself over and over again.
				]]
				
				-- pack the arguments specified into a table
				local args = _ENV_NORMAL.table.pack(...)
				
				-- if no arguments were specified, call the function with no arguments
				if #args == 0 then
					if name == "_ENV.tostring" then
						return "nil"
					elseif name == "_ENV.s.getCharacterData" or name == "_ENV.server.getCharacterData" then
						return nil
					end
					local out = _ENV_NORMAL.table.pack(funct())
					return _ENV_NORMAL.table.unpack(out)
				elseif #args == 1 then -- if only one argument, call the function with only one argument.
					local out = _ENV_NORMAL.table.pack(funct(...))
					return _ENV_NORMAL.table.unpack(out)
				end
				--[[
					if theres two or more arguments, then pack all but the first argument into a table, and then have that as the second param
					this is to trick SW's number of params specified checker, as it thinks just ... is only 1 argument, even if it contains more than 1.
				]]
				local filler = {}
				for i = 2, #args do
					_ENV_NORMAL.table.insert(filler, args[i])
				end
				local out = _ENV_NORMAL.table.pack(funct(..., _ENV_NORMAL.table.unpack(filler)))
				return _ENV_NORMAL.table.unpack(out)
			end

			local function modifyFunction(funct, name)
				--d.print(("setting up function %s()..."):format(name), true, 7)
				return (function(...)

					local returned = _ENV_NORMAL.table.pack(callFunction(funct, name, ...))

					-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
					__ENV =  _ENV_NORMAL
					__ENV._ENV_MODIFIED = _ENV
					_ENV = __ENV

					-- pack args into a table
					local args = table.pack(...)

					-- build output string
					local s = ""

					-- add return values
					for i = 1, #returned do
						s = ("%s%s%s"):format(s, returned[i], i ~= #returned and ", " or "")
					end

					-- add the = if theres any returned values, and also add the function name along with ( proceeding it.
					s = ("%s%s%s("):format(s, s ~= "" and " = " or "", name)

					-- add the arguments to the function, add a ", " after the argument if thats not the last argument.
					for i = 1, #args do
						s = ("%s%s%s"):format(s, args[i], i ~= #args and ", " or "")
					end

					-- add ) to the end of the string.
					s = ("%s%s"):format(s, ")")

					-- print the string.
					d.print(s, true, 7)

					-- switch back to modified environment
					_ENV = _ENV_MODIFIED

					-- return the value to the function which called it.
					return _ENV_NORMAL.table.unpack(returned)
				end)
			end
		
			local function setupFunctionsDebug(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}
				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					local type_v = type(v)
					if type_v == "function" then
						-- "inject" debug into the function
						T[k] = modifyFunction(v, ("%s.%s"):format(n, k))
					elseif type_v == "table" then
						-- go through this table looking for functions
						local name = ("%s.%s"):format(n, k)
						T[k] = setupFunctionsDebug(v, name)
					else
						-- just save as a variable
						T[k] = v
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL
					d.print("Completed setting up function debug!", true, 7)
				end

				return T
			end

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupFunctionsDebug(table.copy.deep(_ENV))
		else
			-- revert _ENV to be the non modified _ENV
			_ENV = table.copy.deep(_ENV_NORMAL)
		end
		return (enabled and "Enabled" or "Disabled").." Function Debug"
	elseif debug_type == "traceback" then
		if enabled and not _ENV_NORMAL then
			-- enable traceback debug (function debug prints debug output whenever a function is called)

			_ENV_NORMAL = nil

			_ENV_NORMAL = table.copy.deep(_ENV)

			local g_tb = g_savedata.debug.traceback

			local function removeAndReturn(...)
				g_tb.stack_size = g_tb.stack_size - 1
				return ...
			end
			local function setupFunction(funct, name)
				--d.print(("setting up function %s()..."):format(name), true, 8)
				local funct_index = nil

				-- check if this function is already indexed
				if g_tb.funct_names then
					for saved_funct_index = 1, g_tb.funct_count do
						if g_tb.funct_names[saved_funct_index] == name then
							funct_index = saved_funct_index
							break
						end
					end
				end

				-- this function is not yet indexed, so add it to the index.
				if not funct_index then
					g_tb.funct_count = g_tb.funct_count + 1
					g_tb.funct_names[g_tb.funct_count] = name

					funct_index = g_tb.funct_count
				end

				-- return this as the new function
				return (function(...)

					-- increase the stack size before we run the function
					g_tb.stack_size = g_tb.stack_size + 1

					-- add this function to the stack
					g_tb.stack[g_tb.stack_size] = {
						funct_index
					}

					-- if this function was given parametres, add them to the stack
					if ... ~= nil then
						g_tb.stack[g_tb.stack_size][2] = {...}
					end

					--[[ 
						run this function
						if theres no error, it will then be removed from the stack, and then we will return the function's returned value
						if there is an error, it will never be removed from the stack, so we can detect the error.
						we have to do this via a function call, as we need to save the returned value before we return it
						as we have to first remove it from the stack
						we could use table.pack or {}, but that will cause a large increase in the performance impact.
					]]
					return removeAndReturn(funct(...))
				end)
			end
		
			local function setupTraceback(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}

				--[[if n == "_ENV.g_savedata" then
					T = g_savedata
				end]]

				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					if k ~= "_ENV_NORMAL" and k ~= "g_savedata" then
						local type_v = type(v)
						if type_v == "function" then
							-- "inject" debug into the function
							local name = ("%s.%s"):format(n, k)
							T[k] = setupFunction(v, name)
						elseif type_v == "table" then
							-- go through this table looking for functions
							local name = ("%s.%s"):format(n, k)
							T[k] = setupTraceback(v, name)
						else--if not n:match("^_ENV%.g_savedata") then
							-- just save as a variable
							T[k] = v
						end
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL

					T.g_savedata = g_savedata
				end

				return T
			end

			local start_traceback_setup_time = s.getTimeMillisec()

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupTraceback(table.copy.deep(_ENV))

			d.print(("Completed setting up tracebacks! took %ss"):format((s.getTimeMillisec() - start_traceback_setup_time)*0.001), true, 8)

			--onTick = setupTraceback(onTick, "onTick")

			-- add the error checker
			ac.executeOnReply(
				SHORT_ADDON_NAME,
				"DEBUG.TRACEBACK.ERROR_CHECKER",
				0,
				function(self)
					-- if traceback debug has been disabled, then remove ourselves
					if not g_savedata.debug.traceback.enabled then
						self.count = 0

					elseif g_savedata.debug.traceback.stack_size > 0 then
						-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
						__ENV =  _ENV_NORMAL
						__ENV._ENV_MODIFIED = _ENV
						_ENV = __ENV

						d.trace.print(_ENV_MODIFIED)

						_ENV = _ENV_MODIFIED

						g_savedata.debug.traceback.stack_size = 0
					end
				end,
				-1,
				-1
			)

			ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
		elseif not enabled and _ENV_NORMAL then
			-- revert modified _ENV functions to be the non modified _ENV
			--- @param t table the environment thats not been modified, will take all of the functions from this table and put it into the current _ENV
			--- @param mt table the modified enviroment
			--[[local function removeTraceback(t, mt)
				for k, v in _ENV_NORMAL.pairs(t) do
					local v_type = _ENV_NORMAL.type(v)
					-- modified table with this indexed
					if mt[k] then
						if v_type == "table" then
							removeTraceback(v, mt[k])
						elseif v_type == "function" then
							mt[k] = v
						end
					end
				end
				return mt
			end

			_ENV = removeTraceback(_ENV_NORMAL, _ENV)]]

			__ENV = _ENV_NORMAL.table.copy.deep(_ENV_NORMAL, _ENV_NORMAL)
			__ENV.g_savedata = g_savedata
			_ENV = __ENV

			_ENV_NORMAL = nil
		end
		return (enabled and "Enabled" or "Disabled").." Tracebacks"
	end
end

function Debugging.setDebug(debug_id, peer_id, override_state)

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
		[4] = "enable",
		[7] = "enable"
	}

	if not debug_types[debug_id] then
		return "Unknown debug type: "..tostring(debug_id)
	end

	if not player_data and peer_id ~= -1 then
		return "invalid peer_id: "..tostring(peer_id)
	end

	if peer_id == -1 then
		local function setGlobalDebug(debug_id)
			-- set that this debug should or shouldn't be auto enabled whenever a player joins for that player
			g_savedata.debug[debug_types[debug_id]].auto_enable = override_state

			for _, peer in ipairs(s.getPlayers()) do
				d.setDebug(debug_id, peer.id, override_state)
			end
		end

		if debug_id == -1 then
			for _debug_id, _ in pairs(debug_types) do
				setGlobalDebug(_debug_id)
			end

		else
			setGlobalDebug(debug_id)
		end

		return "Enabled "..debug_types[debug_id].." Globally."
	end
	
	if debug_types[debug_id] then
		if debug_id == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if player_data.debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") and override_state ~= true then
					none_true = false
					player_data.debug[debug_type_data] = false
				end
			end

			if none_true and override_state ~= false then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data].enabled = none_true
						player_data.debug[debug_type_data] = none_true
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			else
				d.checkDebug()
				for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "disable") then
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			end
			return (none_true and "Enabled" or "Disabled").." All Debug"
		else
			player_data.debug[debug_types[debug_id]] = override_state == nil and not player_data.debug[debug_types[debug_id]] or override_state

			if player_data.debug[debug_types[debug_id]] then
				g_savedata.debug[debug_types[debug_id]].enabled = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[debug_id], player_data.debug[debug_types[debug_id]], peer_id)
		end
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
			g_savedata.debug[debug_type].enabled = should_keep_enabled
		end
	end
end

---@param unique_name string a unique name for the profiler  
function Debugging.startProfiler(unique_name, requires_debug)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
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
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
		if unique_name then
			if g_savedata.profiler.working[unique_name] then
				table.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][g_savedata.tick_counter] = s.getTimeMillisec()-g_savedata.profiler.working[unique_name]
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][(g_savedata.tick_counter-g_savedata.flags.profiler_tick_smoothing)] = nil
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
	if g_savedata.debug.profiler.enabled then
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
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
					valid_ticks = valid_ticks + 1
					data_total = data_total + g_savedata.profiler.total[node_name][(g_savedata.tick_counter-i)]
				end
				g_savedata.profiler.display.average[node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.current[node_name] = g_savedata.profiler.total[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	else
		for node_name, node_data in pairs(t) do
			if type(node_data) == "table" and node_name ~= "timer" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif node_name == "timer" then
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				local max_node = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
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
				g_savedata.profiler.display.average[old_node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[old_node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
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

function Debugging.buildArgs(args)
	local s = ""
	if args then
		local arg_len = table.length(args)
		for i = 1, arg_len do
			local arg = args[i]
			-- tempoarily disabled due to how long it makes the outputs.
			--[[if type(arg) == "table" then
				arg = string.gsub(string.fromTable(arg), "\n", " ")
			end]]

			-- wrap in "" if arg is a string
			if type(arg) == "string" then
				arg = ("\"%s\""):format(arg)
			end

			s = ("%s%s%s"):format(s, arg, i ~= arg_len and ", " or "")
		end
	end
	return s
end

function Debugging.buildReturn(args)
	return d.buildArgs(args)
end

Debugging.trace = {

	print = function(ENV, requires_debug, peer_id)
		local g_tb = ENV.g_savedata.debug.traceback

		local str = ""

		if g_tb.stack_size > 0 then
			str = ("Error in function: %s(%s)"):format(g_tb.funct_names[g_tb.stack[g_tb.stack_size][1]], d.buildArgs(g_tb.stack[g_tb.stack_size][2]))
		end

		for trace = g_tb.stack_size - 1, 1, -1 do
			str = ("%s\n    Called By: %s(%s)"):format(str, g_tb.funct_names[g_tb.stack[trace][1]], d.buildArgs(g_tb.stack[trace][2]))
		end

		d.print(str, requires_debug or false, 8, peer_id or -1)
	end
}