-- This library is for the main objectives in Conquest Mode, such as getting the AI's island they want to attack.

--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.matrix")
require("libraries.icm.islands.islandRegistry")

-- library name
Objective = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

---Gets the scout progress of an island, and safely returns 0 if there is no scout data for some reason
---Could probobly be moved to a island or scout library
---@param island_name string
---@return number scouted_amount
local function getScoutProgress(island_name)
	local scout_data = g_savedata.ai_knowledge.scout[island_name]
	if not scout_data then
		return 0
	end

	return scout_data.scouted or 0
end

---@param island ISLAND
---@param ignore_scouted boolean? true if you want to ignore islands that are already fully scouted
---@return boolean is_valid_target
local function isValidAttackTarget(island, ignore_scouted)
	if island.faction == ISLAND.FACTION.AI then
		return false
	end

	if ignore_scouted then
		if getScoutProgress(island.name) >= scout_requirement then
			return false
		end
	end

	return true
end

---@param origin_island ISLAND The island the attack would originate from
---@param target_island ISLAND The potential target island being evaluated
---@return number weighted_distance A score representing how desirable this target is, lower is more desirable
local function getAttackScore(origin_island, target_island)
	local distance = m.xzDistance(origin_island.transform, target_island.transform)

	if target_island.faction == ISLAND.FACTION.PLAYER then
		return distance / 1.5
	end

	return distance
end

---@param origin_island ISLAND The island the attack would originate from
---@param current_target ISLAND? The current best target found, or nil if none. Allows the function to be used in a loop to find the best target across multiple origins
---@param current_origin ISLAND? The origin of the current best target given. Only has an effect if current_target is not nil
---@param current_best_score number? The score of the current best target. Only has an effect if current_target is not nil
---@param ignore_scouted boolean? True if you want to ignore islands that are already fully scouted
---@return ISLAND? target_island
---@return ISLAND? origin_island
---@return number? best_score
local function selectBestTargetForOrigin(origin_island, current_target, current_origin, current_best_score, ignore_scouted)
	for _, island in pairs(g_savedata.islands) do
		if isValidAttackTarget(island, ignore_scouted) then
			local attack_score = getAttackScore(origin_island, island)
			if not current_target or attack_score < current_best_score then
				current_target = island
				current_origin = origin_island
				current_best_score = attack_score
			end
		end
	end

	return current_target, current_origin, current_best_score
end

---@param ignore_scouted boolean? true if you want to ignore islands that are already fully scouted
---@return ISLAND? target_island returns the island which the ai should target
---@return ISLAND? origin_island returns the island which the ai should attack from
function Objective.getIslandToAttack(ignore_scouted)
	local origin_island = nil
	local target_island = nil
	local target_best_distance = nil

	-- Pick the best target using all currently AI controlled islands as potential origins.
	local ai_islands = IslandRegistry.getFactionMap("ai")
	for _, ai_island in pairs(ai_islands) do
		target_island, origin_island, target_best_distance = selectBestTargetForOrigin(ai_island, target_island, origin_island, target_best_distance, ignore_scouted)
	end

	return target_island, origin_island
end	