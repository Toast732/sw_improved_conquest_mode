--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")
require("libraries.icm.island")
require("libraries.addon.script.setup")

-- library name
Compatibility = {}

-- shortened library name
comp = Compatibility

--[[


	Variables
   

]]

--# stores which versions require compatibility updates
local version_updates = {
	"(0.3.0.78)",
	"(0.3.0.79)",
	"(0.3.0.82)",
<<<<<<< HEAD:Addon/libraries/addon/script/compatibility.lua
	"(0.3.1.2)",
	"(0.3.2.2)",
	"(0.3.2.6)",
	"(0.3.2.8)",
	"(0.3.2.9)"
=======
	"(0.3.1.2)"
>>>>>>> main:Addon/libraries/compatibility.lua
}

--[[


	Classes


]]

---@class VERSION_DATA
---@field data_version string the version which the data is on currently
---@field version string the version which the mod is on
---@field versions_outdated integer how many versions the data is out of date
---@field is_outdated boolean if the data is outdated compared to the mod
---@field newer_versions table a table of versions which are newer than the current, indexed by index, value as version string

--[[


	Functions         


]]

--# creates version data for the specified version, for use in the version_history table
---@param version string the version you want to create the data on
---@return table version_history_data the data of the version
function Compatibility.createVersionHistoryData(version)

	--[[
		calculate ticks played
	]] 
	local ticks_played = g_savedata.tick_counter

	if g_savedata.info.version_history and #g_savedata.info.version_history > 0 then
		for _, version_data in ipairs(g_savedata.info.version_history) do
			ticks_played = ticks_played - (version_data.ticks_played or 0)
		end
	end

	--[[
		
	]]
	local version_history_data = {
		version = version,
		ticks_played = ticks_played,
		backup_g_savedata = {}
	}

	return version_history_data
end

--# returns g_savedata, a copy of g_savedata which when edited, doesnt actually apply changes to the actual g_savedata, useful for backing up.
function Compatibility.getSavedataCopy()

	--d.print("(comp.getSavedataCopy) getting a g_savedata copy...", true, 0)

	--[[
		credit to Woe (https://canary.discord.com/channels/357480372084408322/905791966904729611/1024355759468839074)

		returns a clone/copy of g_savedata
	]]
	
	local function clone(t)
		local copy = {}
		if type(t) == "table" then
			for key, value in next, t, nil do
				copy[clone(key)] = clone(value)
			end
		else
			copy = t
		end
		return copy
	end

	local copied_g_savedata = clone(g_savedata)
	--d.print("(comp.getSavedataCopy) created a g_savedata copy!", true, 0)

	return copied_g_savedata
end

--# migrates the version system to the new one implemented in 0.3.0.78
---@param overwrite_g_savedata boolean if you want to overwrite g_savedata, usually want to keep false unless you've already got a backup of g_savedata
---@return table migrated_g_savedata
---@return boolean is_success if it successfully migrated the versioning system
function Compatibility.migrateVersionSystem(overwrite_g_savedata)

	d.print("migrating g_savedata...", false, 0)

	--[[
		create a local copy of g_savedata, as changes we make we dont want to be applied to the actual g_savedata
	]]

	local migrated_g_savedata = comp.getSavedataCopy()

	--[[
		make sure that the version_history table doesnt exist
	]]
	if g_savedata.info.version_history then
		-- if it already does, then abort, as the version system is already migrated
		d.print("(comp.migrateVersionSystem) the version system has already been migrated!", true, 1)
		return nil, false
	end

	--[[
		create the version_history table
	]]
	if overwrite_g_savedata then
		g_savedata.info.version_history = {}
	end

	migrated_g_savedata.info.version_history = {}

	--[[
		create the version history data, with the previous version the creation version 
		sadly, we cannot reliably get the last version used for versions 0.3.0.77 and below
		so we have to make this assumption
	]]

	if overwrite_g_savedata then
		table.insert(g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))
	end
	
	table.insert(migrated_g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))

	d.print("migrated g_savedata", false, 0)

	return migrated_g_savedata, true
end

--# returns the version id from the provided version
---@param version string the version you want to get the id of
---@return integer version_id the id of the version
---@return boolean is_success if it found the id of the version
function Compatibility.getVersionID(version)
	--[[
		first, we want to ensure version was provided
		lastly, we want to go through all of the versions stored in the version history, if we find a match, then we return it as the id
		if we cannot find a match, we return nil and false
	]]

	-- ensure version was provided
	if not version then
		d.print("(comp.getVersionID) version was not provided!", false, 1)
		return nil, false
	end

	-- go through all of the versions saved in version_history
	for version_id, version_name in ipairs(g_savedata.info.version_history) do
		if version_name == version then
			return version_id, true
		end
	end

	-- if a version was not found, return nil and false
	return nil, false
end

--# splits a version into 
---@param version string the version you want split
---@return table version [1] = release version, [2] = majour version, [3] = minor version, [4] = commit version
function Compatibility.splitVersion(version) -- credit to woe
	local T = {}

	-- remove ( and )
	version = version:match("[%d.]+")

	for S in version:gmatch("([^%.]*)%.*") do
		T[#T+1] = tonumber(S) or S
	end

	T = {
		T[1], -- release
		T[2], -- majour
		T[3], -- minor
		T[4] -- commit
	}

	return T
end

--# returns the version from the version_id
---@param version_id integer the id of the version
---@return string version the version associated with the id
---@return boolean is_success if it successfully got the version from the id
function Compatibility.getVersion(version_id)

	-- ensure that version_id was specified
	if not version_id then
		d.print("(comp.getVersion) version_id was not provided!", false, 1)
		return nil, false
	end

	-- ensure that it is a number
	if type(version_id) ~= "number" then
		d.print("(comp.getVersion) given version_id was not a number! type: "..type(version_id).." value: "..tostring(version_id), false, 1)
		return nil, false
	end

	local version = g_savedata.info.version_history[version_id] and g_savedata.info.version_history[version_id].version or nil
	return version, version ~= nil
end

--# returns version data about the specified version, or if left blank, the current version
---@param version string the current version, leave blank if want data on current version
---@return VERSION_DATA version_data the data about the version
---@return boolean is_success if it successfully got the version data
function Compatibility.getVersionData(version)

	local version_data = {
		data_version = "",
		is_outdated = false,
		version = "",
		versions_outdated = 0,
		newer_versions = {}
	}

	local copied_g_savedata = comp.getSavedataCopy() -- local copy of g_savedata so any changes we make to it wont affect any backups we may make

	--[[
		first, we want to ensure that the version system is migrated
		second, we want to get the id of the version depending on the given version argument
		third, we want to get the data version
		fourth, we want to count how many versions out of date the data version is from the mod version
		fifth, we want to want to check if the version is outdated
		and lastly, we want to return the data
	]]

	-- (1) check if the version system is not migrated
	if not g_savedata.info.version_history then
		local migrated_g_savedata, is_success = comp.migrateVersionSystem() -- migrate the version data
		if not is_success then
			d.print("(comp.getVersionData) failed to migrate version system. This is probably not good!", false, 1)
			return nil, false
		end

		-- set copied_g_savedata as migrated_g_savedata
		copied_g_savedata = migrated_g_savedata
	end

	-- (2) get version id
	local version_id = version and comp.getVersionID(version) or #copied_g_savedata.info.version_history

	-- (3) get data version
	--d.print("(comp.getVersionData) data_version: "..tostring(copied_g_savedata.info.version_history[version_id].version))
	version_data.data_version = copied_g_savedata.info.version_history[version_id].version

	-- (4) count how many versions out of date the data is

	local current_version = comp.splitVersion(version_data.data_version)

	local ids_to_versions = {
		"Release",
		"Majour",
		"Minor",
		"Commit"
	}

	for _, version_name in ipairs(version_updates) do

		--[[
			first, we want to check if the release version is greater (x.#.#.#)
			if not, second we want to check if the majour version is greater (#.x.#.#)
			if not, third we want to check if the minor version is greater (#.#.x.#)
			if not, lastly we want to check if the commit version is greater (#.#.#.x)
		]]

		local update_version = comp.splitVersion(version_name)

		--[[
			go through each version, and check if its newer than our current version
		]]
		for i = 1, #current_version do
			if not current_version[i] or current_version[i] > update_version[i] then
				--[[
					if theres no commit version for the current version, all versions with the same stable, majour and minor version will be older.
					OR, current version is newer, then dont continue, as otherwise that could trigger a false positive with things like 0.3.0.2 vs 0.3.1.1
				]]
				d.print(("(comp.getVersionData) %s Version %s is older than current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
				break
			elseif current_version[i] < update_version[i] then
				-- current version is older, so we need to migrate data.
				table.insert(version_data.newer_versions, version_name)
				d.print(("Found new %s version: %s current version: %s"):format(ids_to_versions[i], version_name, version_data.data_version), false, 0)
				break
			end

			d.print(("(comp.getVersionData) %s Version %s is the same as current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
		end
	end

	-- count how many versions its outdated
	version_data.versions_outdated = #version_data.newer_versions

	-- (5) check if its outdated
	version_data.is_outdated = version_data.versions_outdated > 0

	return version_data, true
end

--# saves backup of current g_savedata
---@return boolean is_success if it successfully saved a backup of the savedata
function Compatibility.saveBackup()
	--[[
		first, we want to save a current local copy of the g_savedata
		second we want to ensure that the g_savedata.info.version_history table is created
		lastly, we want to save the backup g_savedata
	]]

	-- create local copy of g_savedata
	local backup_g_savedata = comp.getSavedataCopy()

	if not g_savedata.info.version_history then -- if its not created (pre 0.3.0.78)
		d.print("(comp.saveBackup) migrating version system", true, 0)
		local migrated_g_savedata, is_success = comp.migrateVersionSystem(true) -- migrate version system
		if not is_success then
			d.print("(comp.saveBackup) failed to migrate version system. This is probably not good!", false, 1)
			return false
		end

		if not g_savedata.info.version_history then
			d.print("(comp.saveBackup) successfully migrated version system, yet g_savedata doesn't contain the new version system, this is not good!", false, 1)
		end
	end

	local version_data, is_success = comp.getVersionData()
	if version_data.data_version ~= g_savedata.info.version_history[#g_savedata.info.version_history].version then
		--d.print("version_data.data_version: "..tostring(version_data.data_version).."\ng_savedata.info.version_history[#g_savedata.info.version.version_history].version: "..tostring(g_savedata.info.version_history[#g_savedata.info.version_history].version))
		g_savedata.info.version_history[#g_savedata.info.version_history + 1] = comp.createVersionHistoryData()
	end

	-- save backup g_savedata
	g_savedata.info.version_history[#g_savedata.info.version_history].backup_g_savedata = backup_g_savedata

	-- remove g_savedata backups which are from over 2 data updates ago
	local backup_versions = {}
	for version_index, version_history_data in ipairs(g_savedata.info.version_history) do
		if version_history_data.backup_g_savedata.info then
			table.insert(backup_versions, version_index)
		end
	end
	
	if #backup_versions >= 3 then
		d.print("Deleting old backup data...", false, 0)
		for backup_index, backup_version_index in ipairs(backup_versions) do
			d.print("Deleting backup data for "..g_savedata.info.version_history[backup_version_index].version, false, 0)
			backup_versions[backup_index] = nil
			g_savedata.info.version_history[backup_version_index].backup_g_savedata = {}

			if #backup_versions <= 2 then
				d.print("Deleted old backup data.", false, 0)
				break
			end
		end
	end

	return true
end

--# updates g_savedata to be compatible with the mod version, to ensure that worlds are backwards compatible.
function Compatibility.update()

	-- ensure that we're actually outdated before proceeding
	local version_data, is_success = comp.getVersionData()
	if not is_success then
		d.print("(comp.update) failed to get version data! this is probably bad!", false, 1)
		return
	end

	if not version_data.is_outdated then
		d.print("(comp.update) according to version data, the data is not outdated. This is probably not good!", false, 1)
		return
	end

	d.print(SHORT_ADDON_NAME.."'s data is "..version_data.versions_outdated.." version"..(version_data.versions_outdated > 1 and "s" or "").." out of date!", false, 0)

	-- save backup
	local backup_saved = comp.saveBackup()
	if not backup_saved then
		d.print("(comp.update) Failed to save backup. This is probably not good!", false, 1)
		return false
	end

	d.print("Creating new version history for "..version_data.newer_versions[1].."...", false, 0)
	local version_history_data = comp.createVersionHistoryData(version_data.newer_versions[1])
	g_savedata.info.version_history[#g_savedata.info.version_history+1] = version_history_data
	d.print("Successfully created new version history for "..version_data.newer_versions[1]..".", false, 0)

	-- check for 0.3.0.78 changes
	if version_data.newer_versions[1] == "(0.3.0.78)" then
		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1]..", Cleaning up old data...", false, 0)

		-- clean up old data
		g_savedata.info.creation_version = nil
		g_savedata.info.full_reload_versions = nil
		g_savedata.info.awaiting_reload = nil

		-- clean up old player_data
		for steam_id, player_data in pairs(g_savedata.player_data) do
			player_data.timers = nil
			player_data.fully_reloading = nil
			player_data.do_as_i_say = nil
		end		
	elseif version_data.newer_versions[1] == "(0.3.0.79)" then -- 0.3.0.79 changes

		-- update the island data with the proper zones, as previously, the zone system improperly filtered out NSO compatible and incompatible zones
		local spawn_zones = sup.spawnZones()
		local tile_zones = sup.sortSpawnZones(spawn_zones)

		for tile_name, zones in pairs(tile_zones) do
			local island, is_success = Island.getDataFromName(tile_name)
			island.zones = zones
		end

		if g_savedata.info.version_history[1].ticked_played then
			g_savedata.info.version_history.ticks_played = g_savedata.info.version_history.ticked_played
			g_savedata.info.version_history.ticked_played = nil
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.0.82)" then -- 0.3.0.82 changes

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			for vehicle_index, vehicle_object in pairs(squad.vehicles) do
				vehicle_object.transform_history = {}
			end
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	elseif version_data.newer_versions[1] == "(0.3.1.2)" then -- 0.3.1.2 changes

		d.print(("Migrating %s data..."):format(SHORT_ADDON_NAME), false, 0)

		-- check if we've initialised the graph_node debug before
		if g_savedata.graph_nodes.init_debug then

			-- generate a global map id for all graph nodes
			g_savedata.graph_nodes.ui_id = server.getMapID()

			d.print("Cleaning up old data...", false, 0)

			-- go through and remove all of the graph node's map ids from the map
			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					s.removeMapID(-1, z_data.ui_id)
					z_data.ui_id = nil
				end
			end

			-- go through all of the player data and set graph_node debug to false
			for _, player_data in pairs(g_savedata.player_data) do
				player_data.debug.graph_node = false
			end

			-- disable graph_node debug globally
			g_savedata.debug.graph_node = false
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
<<<<<<< HEAD:Addon/libraries/addon/script/compatibility.lua
	elseif version_data.newer_versions[1] == "(0.3.2.2)" then -- 0.3.2.2 changes

		local temp_g_savedata_debug = {
			chat = {
				enabled = g_savedata.debug.chat,
				default = false,
				needs_setup_on_reload = false
			},
			error = {
				enabled = g_savedata.debug.error,
				default = false,
				needs_setup_on_reload = false
			},
			profiler = {
				enabled = g_savedata.debug.profiler,
				default = false,
				needs_setup_on_reload = false
			},
			map = {
				enabled = g_savedata.debug.map,
				default = false,
				needs_setup_on_reload = false
			},
			graph_node = {
				enabled = g_savedata.debug.graph_node,
				default = false,
				needs_setup_on_reload = false
			},
			driving = {
				enabled = g_savedata.debug.driving,
				default = false,
				needs_setup_on_reload = false
			},
			vehicle = {
				enabled = g_savedata.debug.vehicle,
				default = false,
				needs_setup_on_reload = false
			},
			["function"] = {
				enabled = false,
				default = false,
				needs_setup_on_reload = true
			},
			traceback = {
				enabled = false,
				default = false,
				needs_setup_on_reload = true,
				stack = {},
				stack_size = 0,
				funct_names = {},
				funct_count = 0
			}
		}

		g_savedata.debug = temp_g_savedata_debug

		for _, player in pairs(g_savedata.player_data) do
			player.debug["function"] = false
			player.debug.traceback = false
		end

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.2.6)" then -- 0.3.2.6 changes

		g_savedata.settings.PAUSE_WHEN_NONE_ONLINE = true

		g_savedata.settings.PERFORMANCE_MODE = true

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.2.8)" then -- 0.3.2.8 changes

		g_savedata.settings.CONVOY_FREQUENCY = 38 * time.minute

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)

	elseif version_data.newer_versions[1] == "(0.3.2.9)" then -- 0.3.2.9 changes

		g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER = time.hour

		d.print("Successfully updated "..SHORT_ADDON_NAME.." data to "..version_data.newer_versions[1], false, 0)
	end

	d.print(SHORT_ADDON_NAME.." data is now up to date with "..version_data.newer_versions[1]..".", false, 0)

	-- this means that theres still newer versions
	if #version_data.newer_versions > 1 then
		-- migrate to the next version
		comp.update()
	end

=======
	end

	d.print(SHORT_ADDON_NAME.." data is now up to date with "..version_data.newer_versions[1]..".", false, 0)

	-- this means that theres still newer versions
	if #version_data.newer_versions > 1 then
		-- migrate to the next version
		comp.update()
	end

>>>>>>> main:Addon/libraries/compatibility.lua
	-- we've finished migrating!
	comp.showSaveMessage()
end

--# prints outdated message and starts update
function Compatibility.outdated()
	-- print that its outdated
	d.print(SHORT_ADDON_NAME.." data is outdated! attempting to automatically update...", false, 0)

	-- start update process
	comp.update()
end

--# verifies that the mod is currently up to date
function Compatibility.verify()
	d.print("verifying if "..SHORT_ADDON_NAME.." data is up to date...", false, 0)
	--[[
		first, check if the versioning system is up to date
	]]
	if not g_savedata.info.version_history then
		-- the versioning system is not up to date
		comp.outdated()
	else
		-- check if we're outdated
		local version_data, is_success = comp.getVersionData()

		if not is_success then
			d.print("(comp.verify) failed to get version data! this is probably bad!", false, 1)
			return
		end

		-- if we're outdated
		if version_data.is_outdated then
			comp.outdated()
		end
	end
end

--# shows the message saying that the addon was fully migrated
function Compatibility.showSaveMessage()
	d.print(SHORT_ADDON_NAME.." Data has been fully migrated!", false, 0)
end