--[[
	
Copyright 2025 Liam Matthews

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Allows a library to easily bind to a callback, so it doesn't have to inject itself into each callback.
]]

-- library name
Binder = {
	bind = {}
}

--[[


	Classes


]]

-- onGroupSpawn
---@alias CallbackOnGroupSpawn fun(group_id: integer, peer_id: integer, x: number, y: number, z: number, group_cost: number)

-- onVehicleLoad
---@alias CallbackOnVehicleLoad fun(vehicle_id: integer)

-- onVehicleUnload
---@alias CallbackOnVehicleUnload fun(vehicle_id: integer)

-- onObjectLoad
---@alias CallbackOnObjectLoad fun(object_id: integer)

-- setupMain
---@alias CallbackSetupMain fun(is_world_create: boolean)

---@alias Callback
---| CallbackOnGroupSpawn
---| CallbackOnVehicleLoad
---| CallbackOnVehicleUnload
---| CallbackOnObjectLoad
---| CallbackSetupMain

---@class BindedCallback
---@field callback Callback the callback to call
---@field priority number the priority of the callback.

--[[


	Variables


]]

---@type table<string, table<integer, BindedCallback>>
binded_callbacks = {
	onGroupSpawn = {},
	onVehicleLoad = {},
	onVehicleUnload = {},
	onObjectLoad = {},
	setupMain = {}
}

--[[


	Functions


]]

---@param callback_name string the name of the callback to bind to.
---@param callback Callback the callback to bind to the callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first.
local function bindCallback(callback_name, callback, priority)

	-- default the priority to 0 if not specified.
	priority = priority or 0

	-- get the list of binds for this callback.
	local binds = binded_callbacks[callback_name]

	-- check if the list exists
	if not binds then
		-- print an error
		d.print(("The callback %s is not a valid callback."):format(callback_name), true, 1)
		return
	end

	-- define the index to insert the callback at.
	local insert_index = 1

	-- find the index to insert the callback at (sorted by priority, goes to behind an existing callback if they share the same priority.)
	for bind_index = 1, #binds do
		-- if the priority is higher than the current bind's priority, break.
		if binds[bind_index].priority > priority then
			break
		end

		-- otherwise, set insert index to above this one.
		insert_index = bind_index + 1
	end

	-- insert the callback at the insert index.
	table.insert(binds, insert_index, 
		{
			callback = callback,
			priority = priority
		}
	)
end

--[[

	onGroupSpawn

]]

--[[
	Inject.
]]

---@diagnostic disable-next-line: undefined-global
old_onGroupSpawn = onGroupSpawn

---@private
function onGroupSpawn(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onGroupSpawn

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onGroupSpawn then
		old_onGroupSpawn(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onGroupSpawn callback.
---@param callback CallbackOnGroupSpawn the callback to bind to the onGroupSpawn callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onGroupSpawn(callback, priority)
	bindCallback(
		"onGroupSpawn",
		callback,
		priority
	)
end

--[[

	onVehicleLoad

]]

--[[
	Inject.
]]

old_onVehicleLoad = onVehicleLoad

---@private
function onVehicleLoad(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onVehicleLoad

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onVehicleLoad then
		old_onVehicleLoad(...)
	end
end


--[[
	Create bind function
]]

--- Function for binding to a the onVehicleLoad callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the onVehicleLoad callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onVehicleLoad(callback, priority)
	bindCallback(
		"onVehicleLoad",
		callback,
		priority
	)
end

--[[

	onVehicleUnload

]]

--[[
	Inject.
]]

old_onVehicleUnload = onVehicleUnload

---@private
function onVehicleUnload(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onVehicleUnload

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onVehicleUnload then
		old_onVehicleUnload(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onVehicleUnload callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the onVehicleUnload callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onVehicleUnload(callback, priority)
	bindCallback(
		"onVehicleUnload",
		callback,
		priority
	)
end


--[[

	onObjectLoad

]]

--[[
	Inject.
]]

old_onObjectLoad = onObjectLoad

---@private
function onObjectLoad(...)

	-- get the list of binds for this callback.
	local binds = binded_callbacks.onObjectLoad

	-- check if the list exists
	if not binds then
		return
	end

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end

	-- call old callback, if it exists
	if old_onObjectLoad then
		old_onObjectLoad(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the onObjectLoad callback.
---@param callback CallbackOnObjectLoad the callback to bind to the onObjectLoad callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.onObjectLoad(callback, priority)
	bindCallback(
		"onObjectLoad",
		callback,
		priority
	)
end

--[[

	setupMain

]]

---@private
function bindedSetupMain(...)
	-- get the list of binds for this callback.
	local binds = binded_callbacks.setupMain

	-- check if the list exists
	if not binds then
		return
	end

	d.print(string.fromTable(binds))

	-- call each callback in order
	for bind_index = 1, #binds do
		binds[bind_index].callback(...)
	end
end

--[[
	Create bind function
]]

--- Function for binding to a the setupMain callback.
---@param callback CallbackOnVehicleLoad the callback to bind to the setupMain callback.
---@param priority integer? the priority of the callback, higher priority callbacks are called first. Defaults to 0.
function Binder.bind.setupMain(callback, priority)
	bindCallback(
		"setupMain",
		callback,
		priority
	)
end