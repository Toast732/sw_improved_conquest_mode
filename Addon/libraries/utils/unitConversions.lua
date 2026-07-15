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

-- Library Version 0.0.1

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Converts between units.
]]

-- library name
UnitConversions = {}

--[[


	Classes


]]

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

--[[

	Speed Conversions

]]

--[[
	From KM/H
]]

UnitConversions.kilometresPerHour = {}

--- Converts from kilometres per hour to metres per second
---@param kmh number the speed in kilometres per hour
---@return number ms the speed in metres per second
function UnitConversions.kilometresPerHour.toMetresPerSecond(kmh)
	return kmh / 3.6
end

--- Converts from kilometres per hour to miles per hour
---@param kmh number the speed in kilometres per hour
---@return number mph the speed in miles per hour
function UnitConversions.kilometresPerHour.toMilesPerHour(kmh)
	return kmh / 1.609344
end

--- Converts from kilometres per hour to knots
---@param kmh number the speed in kilometres per hour
---@return number knots the speed in knots
function UnitConversions.kilometresPerHour.toKnots(kmh)
	return kmh / 1.852
end

--[[
	From M/S
]]

UnitConversions.metresPerSecond = {}

--- Converts from metres per second to kilometres per hour
---@param ms number the speed in metres per second
---@return number kmh the speed in kilometres per hour
function UnitConversions.metresPerSecond.toKilometresPerHour(ms)
	return ms * 3.6
end

--- Converts from metres per second to miles per hour
---@param ms number the speed in metres per second
---@return number mph the speed in miles per hour
function UnitConversions.metresPerSecond.toMilesPerHour(ms)
	return ms * 2.236936
end

--- Converts from metres per second to knots
---@param ms number the speed in metres per second
---@return number knots the speed in knots
function UnitConversions.metresPerSecond.toKnots(ms)
	return ms * 1.943844
end

--[[
	From MPH
]]

UnitConversions.milesPerHour = {}

--- Converts from miles per hour to kilometres per hour
---@param mph number the speed in miles per hour
---@return number kmh the speed in kilometres per hour
function UnitConversions.milesPerHour.toKilometresPerHour(mph)
	return mph * 1.609344
end

--- Converts from miles per hour to metres per second
---@param mph number the speed in miles per hour
---@return number ms the speed in metres per second
function UnitConversions.milesPerHour.toMetresPerSecond(mph)
	return mph / 2.236936
end

--- Converts from miles per hour to knots
---@param mph number the speed in miles per hour
---@return number knots the speed in knots
function UnitConversions.milesPerHour.toKnots(mph)
	return mph / 1.150779
end

--[[
	From Knots
]]

UnitConversions.knots = {}

--- Converts from knots to kilometres per hour
---@param knots number the speed in knots
---@return number kmh the speed in kilometres per hour
function UnitConversions.knots.toKilometresPerHour(knots)
	return knots * 1.852
end

--- Converts from knots to metres per second
---@param knots number the speed in knots
---@return number ms the speed in metres per second
function UnitConversions.knots.toMetresPerSecond(knots)
	return knots / 1.943844
end

--- Converts from knots to miles per hour
---@param knots number the speed in knots
---@return number mph the speed in miles per hour
function UnitConversions.knots.toMilesPerHour(knots)
	return knots * 1.150779
end
