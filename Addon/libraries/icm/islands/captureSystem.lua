--[[
	Capture System - Manages island capture progress, faction changes, and associated events.
	Provides clean separation of capture mechanics from UI/tick logic.
]]

require("libraries.addon.script.debugging")
require("libraries.icm.islands.islandRegistry")

CaptureSystem = {}

-- shortened library name
cs = CaptureSystem

--[[


	Classes


]]

---@class IslandCaptureState
---@field capture_timer number Current capture progress (0 to CAPTURE_TIME)
---@field faction FACTION Current controlling faction
---@field ai_capturing number Number of AI units capturing
---@field players_capturing number Number of players capturing
---@field is_contested boolean Whether AI and players are both capturing
---@field last_faction_change number Timestamp of last faction change (for UI updates)

--[[


    Constants


]]

CAPTURE_TICK_RATE = 60
CAPTURE_SPEEDS = { 1, 1.35, 1.7, 2 }

--[[


	Variables


]]

g_savedata.libraries.capture_system = {
	--- Island dirty flags for UI updates (map, tooltip, etc)
	---@type table<integer, boolean>
	dirty_islands = {},
}

--[[


	Functions - Capture Mechanics

    
]]

---Contains the equation used for calculating the change in capture progress, since its reused so often
---@param capturer_amount integer The amount of units capturing (either player or AI)
---@param game_ticks number
---@param speed number The base speed multiplier (higher for players, lower for AI)
function CaptureSystem.calculateProgressChange(capturer_amount, game_ticks, speed)
	capturer_amount = math.min(capturer_amount, #CAPTURE_SPEEDS)
    return (speed * CAPTURE_SPEEDS[capturer_amount]) * CAPTURE_TICK_RATE * game_ticks
end

---Updates the capture timer for an island based on the amount of ai and players capturing
---@param island ISLAND
---@param ai_count integer Number of AI units capturing
---@param player_count integer Number of players capturing
---@param game_ticks number Tick delta from onTick
function CaptureSystem.updateCaptureTimer(island, ai_count, player_count, game_ticks)
	if not island then
		return
	end

	-- Clamp counts to array bounds
	ai_count = math.min(ai_count, #CAPTURE_SPEEDS)
	player_count = math.min(player_count, #CAPTURE_SPEEDS)

	local old_timer = island.capture_timer
	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME

	-- Apply contested mode logic
	if g_savedata.settings.CONTESTED_MODE and ai_count > 0 and player_count > 0 then
		island.is_contested = true
        CaptureSystem.markDirty(island.index) -- So the tooltip can update stuff like remaining enemys
	else
		island.is_contested = false

		-- Apply capture progress
		if player_count > 0 and CAPTURE_TIME > island.capture_timer then
			island.capture_timer = island.capture_timer + CaptureSystem.calculateProgressChange(player_count, game_ticks, 5)

		elseif ai_count > 0 and 0 < island.capture_timer then
			island.capture_timer = island.capture_timer - CaptureSystem.calculateProgressChange(ai_count, game_ticks, 1)
		end
	end

	-- Make sure its within limits
	island.capture_timer = math.clamp(island.capture_timer, 0, CAPTURE_TIME)

	-- Mark island as needing UI update if timer changed
	if island.capture_timer ~= old_timer then
		CaptureSystem.markDirty(island.index)
	end
end

---Check if island should change faction and apply the change
---@param island ISLAND
---@return FACTION|nil new_faction The faction it changed to, or nil if no change
function CaptureSystem.resolveFactionChange(island)
	if not island then
		return nil
	end

	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME
	local new_faction = nil

	-- Only main bases don't capture
	if island.index == g_savedata.ai_base_island.index or island.index == g_savedata.player_base_island.index then
		return nil
	end

	if island.capture_timer <= 0 and island.faction ~= ISLAND.FACTION.AI then
		new_faction = ISLAND.FACTION.AI
	elseif island.capture_timer >= CAPTURE_TIME and island.faction ~= ISLAND.FACTION.PLAYER then
		new_faction = ISLAND.FACTION.PLAYER
	end

	if new_faction then
		local old_faction = island.faction
		IslandRegistry.setFaction(island, new_faction)
		island.capture_timer = new_faction == ISLAND.FACTION.AI and 0 or CAPTURE_TIME
		CaptureSystem.markDirty(island.index)
		return new_faction
	end

	return nil
end

--[[


	Functions - UI / Status


]]

---Build tooltip text for an island flag based on current capture state
---@param island ISLAND
---@return string tooltip The formatted tooltip text
function CaptureSystem.buildCaptureTooltip(island)
	if not island then
		return ""
	end

	local CAPTURE_TIME = g_savedata.settings.CAPTURE_TIME
	local cap_percent = (island.capture_timer / CAPTURE_TIME) * 100
	local capturing_status = "Revolting" -- Should never happen
	local cp_status = ""

	if island.is_contested then
		capturing_status = "Contested"
		cp_status = "Remove the ${enemy_capturing_count} enemies to resume capturing."
	elseif island.faction ~= ISLAND.FACTION.PLAYER then
		if island.ai_capturing == 0 and island.players_capturing == 0 then
			capturing_status = "Capture"
			cp_status = "Get closer to the capture point to begin capturing."
		elseif island.ai_capturing == 0 then
			capturing_status = "Capturing"
			cp_status = "${time_until_faction_change} until under player control."
		else
			capturing_status = "Losing"
			cp_status = "${time_until_faction_change} until under enemy control."
		end
	else
		if island.ai_capturing == 0 and island.players_capturing == 0 or cap_percent == 100 then
			capturing_status = "Captured"
			cp_status = "Under full player control."
		elseif island.ai_capturing == 0 then
			capturing_status = "Re-Capturing"
			cp_status = "${time_until_faction_change} until under full player control."
		else
			capturing_status = "Losing"
			cp_status = "${time_until_faction_change} until under enemy control."
		end
	end

    -- Add formatting
	local tooltip = ("%s: %0.2f%%\n%s"):format(capturing_status, cap_percent, cp_status)
	
    -- Format in the field enemy_capturing_count
    tooltip = tooltip:setField("enemy_capturing_count", island.ai_capturing)

    -- Format in the field time_until_faction_change
	if tooltip:hasField("time_until_faction_change") then
        -- Calculate the time until the faction changes
		local time_till_faction_change = 0
		local capture_rate = 0

		if island.players_capturing > 0 and g_savedata.settings.CAPTURE_TIME > island.capture_timer then
            capture_rate = CaptureSystem.calculateProgressChange(island.players_capturing, 1, 5)
			time_till_faction_change = (g_savedata.settings.CAPTURE_TIME - island.capture_timer) / capture_rate * CAPTURE_TICK_RATE / 60
		elseif island.ai_capturing > 0 and 0 < island.capture_timer then
            capture_rate = CaptureSystem.calculateProgressChange(island.ai_capturing, 1, 1)
			time_till_faction_change = island.capture_timer / capture_rate * CAPTURE_TICK_RATE / 60
		end

		local formatted_timer = string.formatTime(time_formats.yMdhms, time_till_faction_change, false)
		tooltip = tooltip:setField("time_until_faction_change", formatted_timer, true)
	
        -- Add the capture timer debug if the flag show_capture_timer_debug is enabled
        if g_savedata.flags.show_capture_timer_debug then
            tooltip = tooltip .. (" capture rate:%s time_till_faction_change:%s formatted_time:%s"):format(capture_rate, time_till_faction_change, formatted_timer)
        end
    end

	return tooltip
end

---Mark an island as needing its tooltip updated
---@param island_index integer
function CaptureSystem.markDirty(island_index)
	g_savedata.libraries.capture_system.dirty_islands[island_index] = true
end

---Get and clear dirty flag for an island
---@param island_index integer
---@return boolean is_dirty Whether the island needs UI update
function CaptureSystem.checkAndClearDirty(island_index)
	local is_dirty = g_savedata.libraries.capture_system.dirty_islands[island_index] or false
	g_savedata.libraries.capture_system.dirty_islands[island_index] = nil
	return is_dirty
end

---Clear all dirty flags
function CaptureSystem.clearAllDirty()
	g_savedata.libraries.capture_system.dirty_islands = {}
end

--[[


	Functions - Faction Queries


]]

---Get all islands controlled by a faction
---@param faction FACTION
---@return table<integer, ISLAND>
function CaptureSystem.getIslandsByFaction(faction)
	return IslandRegistry.getFactionMap(faction)
end

---Count islands by faction
---@param faction FACTION
---@return integer count
function CaptureSystem.countIslandsByFaction(faction)
	local map = IslandRegistry.getFactionMap(faction)
	return table.length(map)
end