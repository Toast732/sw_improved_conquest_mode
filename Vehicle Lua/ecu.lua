-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

local M = math

throttle_type = property.getNumber("Throttle Type")

starter_rps = property.getNumber("Starter RPS")
min_rps = property.getNumber("Min RPS")
max_rps = property.getNumber("Max RPS")

afr = property.getNumber("AFR")

cooling_system_temp = property.getNumber("Enabling Cooling System Temp")

half_throttle_temp = property.getNumber("Half Throttle Temp")
shutdown_temp = property.getNumber("Automatic Shutdown Temp")

-- credit for pid function: tajin (https://steamcommunity.com/sharedfiles/filedetails/?id=1800568163)
function pid(p,i,d)
    return{p=p,i=i,d=d,E=0,D=0,I=0,
		run=function(s,sp,pv)
			local E,D,A
			E = sp-pv
			D = E-s.E
			A = math.abs(D-s.D)
			s.E = E
			s.D = D
			s.I = A<E and s.I +E*s.i or s.I*0.5
			return E*s.p +(A<E and s.I or 0) +D*s.d
		end
	}
end

function stopEngine()
	output.setNumber(1, 0) -- 0 fuel throttle
	output.setNumber(2, 0) -- 0 air throttle
	engine_on = false
	-- starter
	output.setNumber(4, 0) 
	output.setBool(1, false)
end

function onTick()

	local throttle_pid = pid(-0.037 + input.getNumber(7), 0.00025 + input.getNumber(8), 0.125052 + input.getNumber(9))

	engine_on = input.getBool(1)
	-- checks if engine is on
	if not engine_on then
		stopEngine()
	end

	local temp = input.getNumber(3)
	-- checks if the engine is overheating
	if temp >= shutdown_temp then
		stopEngine()
	end

	local throttle = input.getNumber(5)

	-- checks if the cooling system should be enabled
	if temp > cooling_system_temp then
		output.setBool(2, true)
	else
		output.setBool(2, false)
	end

	-- by this point, if the engine is off then return
	if not engine_on then
		return
	end

	-- checks if the throttle should be halved
	if temp > half_throttle_temp then
		throttle = throttle / 2
	end

	local rps = input.getNumber(4)

	-- target rps
	local target = throttle+0.8
	
	-- throttle
	if throttle_type == 0 then
		target = M.max(M.abs(max_rps*throttle), min_rps)+0.8
	end

	local air_throttle = M.clamp(throttle_pid:run(target, rps), 0, 1)
	output.setNumber(5, target)
	output.setNumber(1, air_throttle/afr) -- fuel throttle
	output.setNumber(2, air_throttle) -- air throttle

	-- handle clutch
	output.setNumber(3, noNaN(M.sqrt(M.max(rps-min_rps)/max_rps, 0)))

	-- handle starter
	if rps < starter_rps then
		output.setNumber(4, 1)
		output.setBool(1, true)
	else
		output.setNumber(4, 0)
		output.setBool(1, false)
	end
end

---@param x number the number to clamp
---@param min number the minimum value
---@param max number the maximum value
---@return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return noNil(max<x and max or min>x and min or x)
end

function noNil(x)
	return x ~= x and 0 or x
end