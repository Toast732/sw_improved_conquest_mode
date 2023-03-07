-- required libraries
require("libraries.addon.script.debugging")
require("libraries.addon.script.matrix")

-- library name
Players = {}

-- shortened library name
pl = Players

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
---@return string steam_id the steam id of the player, nil if not found
function Players.getSteamID(peer_id)
	local player_list = s.getPlayers()
	for peer_index, peer in pairs(player_list) do
		if peer.id == peer_id then
			return tostring(peer.steam_id)
		end
	end
	d.print("(pl.getSteamID) unable to get steam_id for peer_id: "..peer_id, true, 1)
	return nil
end

---@param steam_id string the steam_id of the player you want to get the object ID of
---@return integer object_id the object ID of the player
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1)
		return nil
	end

	if not g_savedata.player_data[steam_id].object_id then
		g_savedata.player_data[steam_id].object_id = s.getPlayerCharacterID(g_savedata.player_data[steam_id].peer_id)
	end

	return g_savedata.player_data[steam_id].object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end