-- This library is for the main objectives in Conquest Mode, such as getting the AI's island they want to attack.

--[[


	Library Setup


]]

-- required libraries
require("libraries.matrix")

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

---@param ignore_scouted boolean? true if you want to ignore islands that are already fully scouted
---@return table target_island returns the island which the ai should target
---@return table origin_island returns the island which the ai should attack from
function Objective.getIslandToAttack(ignore_scouted)
	local origin_island = nil
	local target_island = nil
	local target_best_distance = nil

	-- go through all non enemy owned islands
	for _, island in pairs(g_savedata.islands) do
		if island.faction ~= ISLAND.FACTION.AI then

			-- go through all enemy owned islands, to check if we should attack from there
			for _, ai_island in pairs(g_savedata.islands) do
				if ai_island.faction == ISLAND.FACTION.AI or ignore_scouted and g_savedata.ai_knowledge.scout[island.name].scouted >= scout_requirement then
					if not ignore_scouted or g_savedata.ai_knowledge.scout[island.name].scouted < scout_requirement then
						if not target_island then
							origin_island = ai_island
							target_island = island
							if island.faction == ISLAND.FACTION.PLAYER then
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)/1.5
							else
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)
							end
						elseif island.faction == ISLAND.FACTION.PLAYER then -- if the player owns the island we are checking
							if target_island.faction == ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform) < target_best_distance then -- if the player also owned the island that we detected was the best to attack
								origin_island = ai_island
								target_island = island
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)
							elseif target_island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform)/1.5 < target_best_distance then -- if the player does not own the best match for an attack target so far
								origin_island = ai_island
								target_island = island
								target_best_distance = m.xzDistance(ai_island.transform, island.transform)/1.5
							end
						elseif island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(ai_island.transform, island.transform) < target_best_distance then -- if the player does not own the island we are checking
							origin_island = ai_island
							target_island = island
							target_best_distance = m.xzDistance(ai_island.transform, island.transform)
						end
					end
				end
			end
		end
	end


	if not target_island then
		origin_island = g_savedata.ai_base_island
		for _, island in pairs(g_savedata.islands) do
			if island.faction ~= ISLAND.FACTION.AI or ignore_scouted and g_savedata.ai_knowledge.scout[island.name].scouted >= scout_requirement then
				if not ignore_scouted or g_savedata.ai_knowledge.scout[island.name].scouted < scout_requirement then
					if not target_island then
						target_island = island
						if island.faction == ISLAND.FACTION.PLAYER then
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)/1.5
						else
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)
						end
					elseif island.faction == ISLAND.FACTION.PLAYER then
						if target_island.faction == ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform) < target_best_distance then -- if the player also owned the island that we detected was the best to attack
							target_island = island
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)
						elseif target_island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform)/1.5 < target_best_distance then -- if the player does not own the best match for an attack target so far
							target_island = island
							target_best_distance = m.xzDistance(origin_island.transform, island.transform)/1.5
						end
					elseif island.faction ~= ISLAND.FACTION.PLAYER and m.xzDistance(origin_island.transform, island.transform) < target_best_distance then -- if the player does not own the island we are checking
						target_island = island
						target_best_distance = m.xzDistance(origin_island.transform, island.transform)
					end
				end
			end
		end
	end
	return target_island, origin_island
end