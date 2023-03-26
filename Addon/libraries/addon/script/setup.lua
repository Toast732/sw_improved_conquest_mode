--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")
require("libraries.utils.tables")
require("libraries.addon.components.tags")

-- library name
Setup = {}

-- shortened library name
sup = Setup

--[[


	Classes


]]

---@class SPAWN_ZONES
---@field turrets table<number, SWZone> the turret spawn zones
---@field land table<number, SWZone> the land vehicle spawn zones
---@field sea table<number, SWZone> the sea vehicle spawn zones


--[[


	Functions         


]]

--# sets up and returns the spawn zones, used for spawning certain vehicles at, such as boats, turrets and land vehicles
---@return SPAWN_ZONES spawn_zones the table of spawn zones
function Setup.spawnZones()

	local spawn_zones = {
		turrets = s.getZones("turret"),
		land = s.getZones("land_spawn"),
		sea = s.getZones("boat_spawn")
	}

	-- remove any NSO or non_NSO exlcusive zones

	-----
	--* filter NSO and non NSO exclusive islands
	-----

	-- go through all zone types
	for zone_type, zones in pairs(spawn_zones) do
		-- go through all of the zones for this zone type, backwards
		for zone_index = #zones, 1, -1 do
			zone = zones[zone_index]
			if not g_savedata.info.mods.NSO and Tags.has(zone.tags, "NSO") or g_savedata.info.mods.NSO and Tags.has(zone.tags, "not_NSO") then
				table.remove(zones, zone_index)
			end
		end
	end

	return spawn_zones
end

--# returns the tile's name which the zone is on
---@param zone SWZone the zone to get the tile name of
---@return string tile_name the name of the tile which the zone is on
---@return boolean is_success if it successfully got the name of the tile
function Setup.getZoneTileName(zone)
	local tile_data, is_success = server.getTile(zone.transform)
	if not is_success then
		d.print("(sup.getZoneTileName) failed to get the location of zone at: "..tostring(zone.transform[13])..", "..tostring(zone.transform[14])..", "..tostring(zone.transform[15]), true, 1)
		return nil, false
	end

	return tile_data.name, true
end

--# sorts the zones in a table, indexed by the tile name which the zone is on
---@param spawn_zones SPAWN_ZONES the zones to sort, gotten via sup.spawnZones
---@return table tile_zones sorted table of spawn zones
function Setup.sortSpawnZones(spawn_zones)

	local tile_zones = {}

	for zone_type, zones in pairs(spawn_zones) do

		for zone_index, zone in ipairs(zones) do

			local tile_name, is_success = Setup.getZoneTileName(zone)

			if not is_success then
				d.print("(sup.sortSpawnZones) Failed to get name of zone!", true, 1)
				goto sup_sortSpawnZones_continueZone
			end

			table.tabulate(tile_zones, tile_name, zone_type)

			table.insert(tile_zones[tile_name][zone_type], zone)

			::sup_sortSpawnZones_continueZone::
		end
	end

	return tile_zones
end