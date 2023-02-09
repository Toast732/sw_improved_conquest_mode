-- required libraries
require("libraries.debugging")
require("libraries.matrix")

-- library name
Players = {}

-- shortened library name
pl = Players

--[[


	Variables
   

]]

local debug_auto_enable_levels = {
	function() -- for Authors.
		return true
	end,
	function(player) -- for Contributors and Testers.
		return IS_DEVELOPMENT_VERSION or player:isAdmin()
	end
}

local addon_contributors = {
	["76561198258457459"] = {
		name = "Toastery",
		role = "Author",
		can_auto_enable = debug_auto_enable_levels[1],
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	},
	["76561198263550595"] = {
		name = "Senty",
		role = "Code Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198003337601"] = {
		name = "Woe",
		role = "Code Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198819129091"] = {
		name = "Daimonfire",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197971434564"] = {
		name = "Dorert",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198309605253"] = {
		name = "Eri",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198027912887"] = {
		name = "Outcast",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["71261196730417046"] = {
		name = "Keh",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198113700383"] = {
		name = "Lassi",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198310664934"] = {
		name = "Oh no look who",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198293725845"] = {
		name = "ScriptSauce",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198018200539"] = {
		name = "Sebastiaz",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198094043156"] = {
		name = "Sid V",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198201591123"] = {
		name = "yucky",
		role = "Vehicle Contributor",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198257253907"] = {
		name = "Just Mob",
		role = "Video Producer & Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198837684315"] = {
		name = "Justin",
		role = "Wiki Admin & Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198998166730"] = {
		name = "Baguette Man",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198439973793"] = {
		name = "Cruzer",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198379296867"] = {
		name = "Jayfox2",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198119190014"] = {
		name = "kelpbot",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198101846228"] = {
		name = "mistercynical",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561198094765400"] = {
		name = "Not so cute, but still a monster",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561199051162038"] = {
		name = "SmolShyBoiDavid",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197982256220"] = {
		name = "Tarelius",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},
	["76561197971637605"] = {
		name = "Tom",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	}--[[,
	[""] = {
		name = "Viking Walrus",
		role = "Private Alpha Tester",
		can_auto_enable = debug_auto_enable_levels[2],
		debug = { -- the debug to automatically enable for them

		}
	},]]
}

--[[


	Classes


]]

---@class PLAYER_DATA
---@field name string the name of the player
---@field peer_id integer the peer_id of the player
---@field steam_id string the steam_id of the player, as a string
---@field object_id integer the object_id of the player
---@field debug table<DEBUG_TYPE, boolean> a table of the debugs the player has enabled, indexed by the name of the debug, value being if its enabled or not
---@field acknowledgements table<nil>
---@field updateName function<nil> updates the player's name in player_data with the name they currently have
---@field updatePID function<nil> updates the player's peer_id in player_data with the peer_id they currently have
---@field updateOID function<nil> updates the player's object_id in player_data with the object_id they currently have
---@field getDebug function<DEBUG_ID> returns wether or not the player has the debug with the specified id enabled, set to -1 for any debug enabled
---@field getSWPlayer function<nil> returns the SWPlayer attached to this player.

--[[


	Functions         


]]

function Players.onJoin(steam_id, peer_id)

	if not g_savedata.players.individual_data[steam_id] then -- this player has never joined before

		Players.add(steam_id, peer_id)

	else -- this player has joined before

		local player = Players.dataBySID(steam_id) -- get the player's data

		Players.updateData(player) -- update the player's data
	end
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the OOP functions added
function Players.setupOOP(player)
	-- update name
	function player:updateName()
		self.name = s.getPlayerName(self.peer_id)
	end

	-- update peer_id
	function player:updatePID(peer_id)
		if peer_id then
			self.peer_id = peer_id
		else
			for _, peer in pairs(s.getPlayers()) do
				if tostring(peer.steam_id) == self.steam_id then
					self.peer_id = peer.id
				end
			end
		end
	end

	function player:updateOID()
		self.object_id = s.getPlayerCharacterID(self.peer_id)
	end

	-- checks if the player has this debug type enabled
	function player:getDebug(debug_id)
		if debug_id == -1 then
			-- check for all
			for _, enabled in pairs(self.debug) do
				if enabled then
					-- a debug is enabled
					return true 
				end
			end
			-- no debugs are enabled
			return false
		end

		return self.debug[d.debugTypeFromID(debug_id)]
	end

	function player:setDebug(debug_id, enabled)
		if debug_id == -1 then -- set all debug to the specified state
			for debug_id, enabled in pairs(self.debug) do
				self:setDebug(debug_id, enabled)
			end
		else
			-- get debug type from debug id
			local debug_type = d.debugTypeFromID(debug_id)

			-- set player's debug to be value of enabled
			self.debug[debug_type] = enabled

			-- if we're enabling this debug
			if enabled then
				-- set this debug as true for global, so the addon can start checking who has it enabled.
				g_savedata.debug[debug_type] = true
			else
				-- check if we can globally disable this debug to save on performance
				d.checkDebug()
			end

			-- handle the debug (handles enabling of debugs and such)
			d.handleDebug(debug_type, enabled, self.peer_id, self.steam_id)
		end
	end

	-- returns the SWPlayer, if doesn't exist currently, will return an empty table
	function player:getSWPlayer()
		local player_list = s.getPlayers()
		for peer_index = 1, #player_list do
			local SWPlayer = player_list[peer_index]
			if SWPlayer.steam_id == self.steam_id then
				return SWPlayer, true
			end
		end

		return {}, false
	end

	-- checks if the player is an admin
	function player:isAdmin()
		return self:getSWPlayer().admin
	end

	-- checks if the player is a contributor to the addon
	function player:isContributor()
		return addon_contributors[self.steam_id] ~= nil
	end

	function player:isOnline()
		-- "failure proof" method of checking if the player is online
		-- by going through all online players, as in certain scenarios
		-- only using onPlayerJoin and onPlayerLeave will cause issues.

		return table.pack(self:getSWPlayer())[2]
	end

	return player
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the data updated.
function Players.updateData(player)

	player = Players.setupOOP(player)

	-- update player's online status
	if player:isOnline() then
		g_savedata.players.online[player.peer_id] = player.steam_id
	else
		g_savedata.players.online[player.peer_id] = nil
	end

	-- update their name
	player:updateName()

	-- update their peer_id
	player:updatePID()

	-- update their object_id
	player:updateOID()

	return player
end

function Players.add(steam_id, peer_id)

	player = {
		name = s.getPlayerName(peer_id),
		peer_id = peer_id,
		steam_id = steam_id,
		object_id = s.getPlayerCharacterID(peer_id),
		debug = {},
		acknowledgements = {} -- used for settings to confirm that the player knows the side affects of what they're setting the setting to
	}

	-- populate debug data
	for i = 1, #debug_types do
		player.debug[d.debugTypeFromID(i)] = false
	end

	-- functions for the player

	player = Players.updateData(player)

	g_savedata.players.individual_data[steam_id] = player

	-- enable their selected debug modes by default if they're a addon contributor
	if player:isContributor() then
		local enabled_debugs = {}

		-- enable the debugs they specified
		if addon_contributors[steam_id].can_auto_enable(player) then
			for i = 1, #addon_contributors[steam_id].debug do
				local debug_id = addon_contributors[steam_id].debug[i]
				player:setDebug(debug_id, true)
				table.insert(enabled_debugs, addon_contributors[steam_id].debug[i])
			end
		end

		-- if this contributor has debugs which automatically gets enabled
		if #enabled_debugs > 0 then

			local msg_enabled_debugs = ""

			-- prepare the debug types which were enabled to be put into a message
			msg_enabled_debugs = d.debugTypeFromID(enabled_debugs[1])
			if #enabled_debugs > 1 then
				for i = 2, #enabled_debugs do -- start at position 2, as we've already added the one at positon 1.
					if i == #enabled_debugs then -- if this is the last debug type
						msg_enabled_debugs = ("%s and %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					else
						msg_enabled_debugs = ("%s, %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					end
				end
			end

			d.print(("Automatically enabled %s debug for you, %s, thank you for your contributions!"):format(msg_enabled_debugs, player.name), false, 0, player.peer_id)
		else -- if they have no debugs types that get automatically enabled
			d.print(("Thank you for your contributions, %s!"):format(player.name), false, 0, player.peer_id)
		end
	end

	d.print(("Setup Player %s"):format(player.name), true, 0, -1)
end

---@param steam_id steam_id the steam id of the player which you want to get the data of
---@return PLAYER_DATA player_data the data of the player
function Players.dataBySID(steam_id)
	return g_savedata.players.individual_data[steam_id]
end

---@param peer_id integer the peer id of the player which you want to get the data of
---@return PLAYER_DATA|nil player_data the data of the player, nil if not found
function Players.dataByPID(peer_id)

	local steam_id = Players.getSteamID(peer_id)

	-- ensure we got steam_id
	if not steam_id then 
		return
	end

	-- ensure player's data exists
	if not g_savedata.players.individual_data[steam_id] then
		return
	end

	-- return player's data
	return g_savedata.players.individual_data[steam_id]
end

---@param player_list Players[] the list of players to check
---@param target_pos Matrix the position that you want to check
---@param min_dist number the minimum distance between the player and the target position
---@param ignore_y boolean if you want to ignore the y level between the two or not
---@return boolean no_players_nearby returns true if theres no players which distance from the target_pos was less than the min_dist
function Players.noneNearby(player_list, target_pos, min_dist, ignore_y)
	local players_clear = true
	for player_index, player in pairs(player_list) do
		if ignore_y and m.xzDistance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		elseif not ignore_y and m.distance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		end
	end
	return players_clear
end

---@param peer_id integer the peer_id of the player you want to get the steam id of
---@return string|false steam_id the steam id of the player, false if not found
function Players.getSteamID(peer_id)
	if not g_savedata.players.online[peer_id] then
		-- slower, but reliable fallback method
		for _, peer in ipairs(s.getPlayers()) do
			if peer.id == peer_id then
				return tostring(peer.steam_id)
			end
		end
		return false
	end

	return g_savedata.players.online[peer_id]
end

---@param steam_id string the steam ID of the palyer
---@return integer|nil object_id the object ID of the player, nil if not found
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1, -1, 10)
		return
	end

	local player_data = pl.dataBySID(steam_id)

	if not player_data.object_id then
		player_data.object_id = s.getPlayerCharacterID(player_data.peer_id)
	end

	return player_data.object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end