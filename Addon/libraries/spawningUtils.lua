-- required libraries
require("libraries.debugging")
require("libraries.tags")

-- library name
SpawningUtils = {}

-- shortened library name
su = SpawningUtils

-- spawn an individual object descriptor from a playlist location
function SpawningUtils.spawnObjectType(spawn_transform, addon_index, location_index, object_descriptor, parent_vehicle_id)
	local component, is_success = s.spawnAddonComponent(spawn_transform, addon_index, location_index, object_descriptor.index, parent_vehicle_id)
	if is_success then
		return component.id
	else -- then it failed to spawn the addon component
		d.print("this addon index: "..s.getAddonIndex(), false, 0)
		d.print(("(Improved Conquest Mode) Please send this debug info to the discord server:\ncomponent: %s\naddon_index: %s\nlocation index: %s"):format(component, addon_index, location_index), false, 1)
		return nil
	end
end

function SpawningUtils.spawnObject(spawn_transform, addon_index, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, object.transform), addon_index, location_index, object, parent_vehicle_id)

	-- add object to spawned object tables

	if spawned_object_id ~= nil and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(object.tags, "vehicle_type=wep_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		end
		if Tags.has(object.tags, "vehicle_type=wep_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(object.tags, "vehicle_type=wep_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(object.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(object.tags, "type=dlc_weapons_flag") then
			l_vehicle_type = "flag"
		end

		local object_data = { 
			name = object.display_name, 
			type = object.type, 
			id = spawned_object_id, 
			component_id = object.id, 
			vehicle_type = l_vehicle_type, 
			size = Tags.getValue(object.tags, "size", true) or "small"
		}

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
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