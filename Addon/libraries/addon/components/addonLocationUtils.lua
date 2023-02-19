--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

-- library name
AddonLocationUtils = {}

-- shortened library name
alu = AddonLocationUtils

--[[


	Variables
   

]]

s = s or server

--[[


	Classes


]]

--[[


	Functions         


]]

---# print function just in case debugging.lua is not present.
---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function AddonLocationUtils.print(message, requires_debug, debug_type, peer_id)
	if not d then
		s.announce("alu", tostring(message))
		return
	end

	d.print(message, requires_debug, debug_type, peer_id)
end

---@param addon_index number|table<_, integer>? the target addon index to go through its components, leave nil or -1 for all, specify a table<_, addon_index> for multiple. 
---@param addon_pattern string? the pattern to match the addon name against. leave nil to not care about the addon name. (will be ignored if the addon index is specified)
---@param location_pattern string? the pattern to match the location name against. leave nil to not care about the location name.
---@param component_pattern string? the pattern to match the component name against. leave nil to not care about the component name.
function AddonLocationUtils.getMissionComponents(addon_index, addon_pattern, location_pattern, component_pattern)

	-- set nil addon_index to -1
	addon_index = addon_index or -1

	--[[
		
		make sure parametres are valid

	]]

	local addon_index_type = type(addon_index)

	if addon_index_type ~= "integer" and addon_index_type ~= "table" and addon_index ~= -1 then
		alu.print(("(alu.getMissionComponents) addon_index was specified, however it is not a integer or a table! addon_index: %s"):format(addon_index), true, 1)
		return
	end

	local specified_addon_index = addon_index ~= -1

	if specified_addon_index and addon_index_type == "integer" then
		addon_index = {addon_index}
	end

	if specified_addon_index and addon_index_type == "number" and not s.getAddonData(addon_index) then
		alu.print(("(alu.getMissionComponents) addon_index was specified, however there is not an addon matching this index! addon_index: %s"):format(addon_index), true, 1)
		return
	end

	local components = {}

	---@type table<integer, SWAddonData>
	local addons_to_check = {}
	
	-- create a list of all of the addons to check, with their data as the value
	if not specified_addon_index then
		for i = 0, s.getAddonCount() -1 do
			local addon_data = s.getAddonData(i)
			if addon_data and (not addon_pattern or addon_data.name:match(addon_pattern)) then
				addons_to_check[i] = s.getAddonData(i)
			end
		end
	else
		for i = 0, #addon_index do
			local _addon_index = addon_index[i]
			local addon_data = s.getAddonData(_addon_index)

			if not addon_data then
				alu.print(("(alu.getMissionComponents) addon_index was specified, however there is not an addon matching this index! addon_index: %s"):format(_addon_index), true, 1)
			else
				addons_to_check[i] = addon_data
			end
		end
	end

	-- go through all locations in the addons to check
	for addon_index, addon_data in pairs(addons_to_check) do

		-- go through all locations in this addon
		for location_index = 0, addon_data.location_count - 1 do
			local location_data, is_success = s.getLocationData(addon_index, location_index)

			-- check if this location matches the criteria
			if is_success and (not location_pattern or location_data.name:match(location_pattern)) then

				-- go through all components in this location
				for component_index = 0, location_data.component_count - 1 do
					local component_data, is_success = s.getLocationComponentData(addon_index, location_index, component_index)
					
					-- check if this component matches the criteria
					if is_success and (not component_pattern or component_data.display_name:match(component_pattern)) then
						table.insert(components, component_data)

						local components_table_index = #components
						components[components_table_index].addon_index = addon_index
						components[components_table_index].addon_data = addon_data
						components[components_table_index].location_index = location_index
						components[components_table_index].location_data = location_data
						components[components_table_index].component_index = component_index
					end
				end
			end
		end
	end

	return components
end