--[[


	Library Setup


]]

require("libraries.addon.script.debugging")
require("libraries.addon.spatial.spatialGrid")
require("libraries.addon.components.tags")
require("libraries.addon.callbacks.binder.binder")
require("libraries.icm.islands.island")
require("libraries.utils.string")

-- library name
IslandRegistry = {}


--[[


	Classes


]]

---@class IslandRegistryData
---@field by_index table<integer, ISLAND>
---@field by_group_id table<integer, ISLAND>
---@field by_name table<string, ISLAND>
---@field by_faction table<FACTION, table<integer, ISLAND>>
---@field by_land_access table<string, table<integer, ISLAND>>

--[[


	Constants


]]

-- Put after the islands are initialized
ISLAND_REGISTRY_SETUP_MAIN_PRIORITY = ISLAND_SETUP_MAIN_PRIORITY + 1

--[[


	Variables


]]

--- @type IslandRegistryData
IslandRegistry.data = {
	by_index = {},
	by_group_id = {},
	by_name = {},
	by_faction = {},
	by_land_access = {}
}

--- @type boolean If the registry has been built
IslandRegistry.ready = false

--[[


	Functions


]]

--- Registers the island in the registry, allowing it to be looked by its index, flag vehicle group id, name, and faction.
--- Also adds the island to the island spatial grid for spatial queries involving islands.
--- @param island ISLAND
function IslandRegistry.registerIsland(island)
	if not island then
		return
	end

	IslandRegistry.data.by_index[island.index] = island

	if island.flag_vehicle and island.flag_vehicle.group_id then
		IslandRegistry.data.by_group_id[island.flag_vehicle.group_id] = island
	end

	IslandRegistry.data.by_name[string.friendly(island.name or "")] = island

	IslandRegistry.data.by_faction[island.faction] = IslandRegistry.data.by_faction[island.faction] or {}
	IslandRegistry.data.by_faction[island.faction][island.index] = island

	local land_access = Tags.getValue(island.tags, "land_access", true) or "none"
	IslandRegistry.data.by_land_access[land_access] = IslandRegistry.data.by_land_access[land_access] or {}
	IslandRegistry.data.by_land_access[land_access][island.index] = island

	-- Also register it in the spatial hash grid
	if not island_grid.frozen then
		---@diagnostic disable-next-line: param-type-mismatch
		SpatialGrid.add(island_grid, island.index, island.transform[13], island.transform[15])
	else
		d.print("(IslandRegistry.registerIsland) island_grid is frozen!", true, 1)
	end
end

--- Changes a islands faction
--- @param island ISLAND
--- @param new_faction FACTION
function IslandRegistry.setFaction(island, new_faction)
	if not island then
		return
	end

	if island.faction == new_faction then
		return
	end

	if IslandRegistry.data.by_faction[island.faction] then
		IslandRegistry.data.by_faction[island.faction][island.index] = nil
	end

	island.faction = new_faction

	IslandRegistry.data.by_faction[new_faction] = IslandRegistry.data.by_faction[new_faction] or {}
	IslandRegistry.data.by_faction[new_faction][island.index] = island
end

--- Rebuilds the entire registry from the island data in g_savedata
function IslandRegistry.rebuild()
	start_time = s.getTimeMillisec()
	IslandRegistry.data = {
		by_index = {},
		by_group_id = {},
		by_name = {},
		by_faction = {},
		by_land_access = {}
	}
	island_grid = SpatialGrid.new(island_grid.cell_size) -- Reset the grid

	if g_savedata.ai_base_island then
		IslandRegistry.registerIsland(g_savedata.ai_base_island)
	end

	if g_savedata.player_base_island then
		IslandRegistry.registerIsland(g_savedata.player_base_island)
	end

	for _, island in pairs(g_savedata.islands or {}) do
		IslandRegistry.registerIsland(island)
	end

	island_grid = island_grid:freeze()

	IslandRegistry.ready = true
end

--- If the registry hasn't been built yet, builds it. Otherwise does nothing
function IslandRegistry.ensureReady()
	if not IslandRegistry.ready then
		IslandRegistry.rebuild()
	end
end

--- @param group_id integer
--- @return ISLAND|nil island
function IslandRegistry.getByGroupID(group_id)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_group_id[group_id]
end

--- @param island_index integer
--- @return ISLAND|nil island
function IslandRegistry.getByIndex(island_index)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_index[island_index]
end

--- @param island_name string
--- @return ISLAND|nil island
function IslandRegistry.getByName(island_name)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_name[string.friendly(island_name or "")]
end

--- Returns a table of all islands controlled by a faction
--- Note: this returns a reference to the actual data. If you need to modify it, make a copy first
--- @param faction FACTION
--- @return table<integer, ISLAND>
function IslandRegistry.getFactionMap(faction)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_faction[faction] or {}
end

--- Returns a table of all islands with the specified land access
--- Note: this returns a reference to the actual data. If you need to modify it, make a copy first
--- @param land_access string
--- @return table<integer, ISLAND>
function IslandRegistry.getLandAccessMap(land_access)
	IslandRegistry.ensureReady()
	return IslandRegistry.data.by_land_access[land_access] or {}
end

-- Bind rebuild to setupMain
Binder.bind.setupMain(IslandRegistry.rebuild, ISLAND_REGISTRY_SETUP_MAIN_PRIORITY)