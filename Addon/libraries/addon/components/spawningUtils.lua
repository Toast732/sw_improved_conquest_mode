-- required libraries
require("libraries.addon.script.debugging")
require("libraries.addon.components.tags")

-- library name
SpawningUtils = {}

-- shortened library name
su = SpawningUtils

--- @class SpawnableComponentData
--- @field tags_full                        string
--- @field tags                             table<number, string> The tags on the component
--- @field display_name                     string The display name of the component
--- @field type                             SWAddonComponentDataTypeEnum The type of the component (0 = zone, 1 = object, 2 = character, 3 = vehicle, 4 = flare, 5 = fire, 6 = loot, 7 = button, 8 = animal, 9 = ice, 10 = cargo_zone)
--- @field id                               number The ID of the component from the missions editor e.g. ID_27
--- @field dynamic_object_type              SWObjectTypeEnum The object type of the component (number for pan/character/pot/whatever)
--- @field transform                        SWMatrix The position of the component
--- @field vehicle_parent_component_id      number 
--- @field character_outfit_type            number The character outfit type (See Outfit type)
--- @field component_index                  number the component_index inside of the location

--- adds .component_index to component_data
--- @param component_index number the index of the component, local to each location.
--- @param component_data SWAddonComponentData the data of the component
--- @return SpawnableComponentData component_data component_data but with .component_index = component_index
function SpawningUtils.populateComponentData(component_index, component_data)
	component_data.component_index = component_index

	---@cast component_data -SWAddonComponentData
	return component_data
end

-- spawn an individual object descriptor from a playlist location
--- @param spawn_transform SWMatrix the matrix of where to spawn the component
--- @param addon_index number the index of the addon which contains the component
--- @param location_index number the index of the location which contains the component
--- @param component_data SpawnableComponentData the populated component data of the component
--- @param parent_vehicle_id number? the id of the vehicle, to parent this component to
function SpawningUtils.spawnObjectType(spawn_transform, addon_index, location_index, component_data, parent_vehicle_id)

	if component_data or component_data.component_index then
		local component, is_success = server.spawnAddonComponent(spawn_transform, addon_index, location_index, component_data.component_index, parent_vehicle_id)
		-- if we got is_success and component isn't nil
		if is_success and component then
			-- if it's a group and a valid group_id, return the group_id
			if component.group_id and component.group_id ~= 0 then
				return component.group_id
			-- if it's a object and a valid object_id, return the object_id
			elseif component.object_id and component.object_id ~= 0 then
				return component.object_id
			end
		end
		
		-- then it failed to spawn the addon component
		d.print("this addon index: "..s.getAddonIndex(), false, 0)
		-- turn the component into a string if its a table
		if type(component) == "table" then
			component = string.fromTable(component)
		end
		-- print an error
		d.print(("(Improved Conquest Mode) Failed to spawn addon component! \ncomponent: %s\naddon_index: %s\nlocation index: %s"):format(component, addon_index, location_index), false, 1)
		return nil
	elseif component_data then
		d.print("(su.spawningUtils) component_data.component_index is nil!", true, 1)
		d.print(component_data, true, 1)
	else
		d.print("(su.spawningUtils) component_data is nil!", true, 1)
	end
end

function SpawningUtils.spawnObject(spawn_transform, addon_index, location_index, component_data, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	--d.print(component_data)

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, component_data.transform), addon_index, location_index, component_data, parent_vehicle_id)

	-- add object to spawned object tables

	-- if the id is valid
	if spawned_object_id and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(component_data.tags, "vehicle_type=wep_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(component_data.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(component_data.tags, "type=dlc_weapons_flag") then
			l_vehicle_type = "flag"
		end

		local object_data = {
			name = component_data.display_name,
			type = component_data.type,
			id = spawned_object_id,
			component_id = component_data.id,
			vehicle_type = l_vehicle_type,
			size = Tags.getValue(component_data.tags, "size", true) or "small"
		}

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
	else
		d.print("(su.spawnObject) Failed to spawn vehicle!", true, 1)
	end

	return nil
end

function SpawningUtils.spawnObjects(spawn_transform, addon_index, location_index, object_descriptors, out_spawned_objects)
	local spawned_objects = {}

	for _, object in pairs(object_descriptors) do
		-- find parent vehicle id if set

		local parent_vehicle_id = 0
		if object.vehicle_parent_component_id > 0 then
			for spawned_object_id, spawned_object in pairs(out_spawned_objects) do
				if spawned_object.type == "vehicle" and spawned_object.component_id == object.vehicle_parent_component_id then
					parent_vehicle_id = spawned_object.id
				end
			end
		end

		su.spawnObject(spawn_transform, addon_index, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end